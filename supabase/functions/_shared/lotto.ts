// deno-lint-ignore-file no-explicit-any
// Shared club lotto logic for the `lotto` and `lotto-webhook` edge functions.
// Money is taken on the club's own Stripe Connect account (direct charges), so
// every Stripe call carries the Stripe-Account header.

import { clubStripeAccount as acct, stripe } from "./stripe-connect.ts";
export { clubStripeAccount as acct, stripe, verifyStripeSignature } from "./stripe-connect.ts";

export const PAGE_BASE = "https://coachsmart.app/lotto/";
export const MAX_LINES = 10;

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

export function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export function euro(cents: number) {
  const v = (cents || 0) / 100;
  return "€" + (Number.isInteger(v) ? v.toLocaleString("en-IE") : v.toLocaleString("en-IE", { minimumFractionDigits: 2, maximumFractionDigits: 2 }));
}

// Price for one week: as many bundles as fit, the rest at the single-line price.
export function priceFor(cfg: any, lines: number) {
  const b = cfg.bundle_lines;
  if (b > 1 && cfg.bundle_price_cents > 0) {
    return Math.floor(lines / b) * cfg.bundle_price_cents + (lines % b) * cfg.line_price_cents;
  }
  return lines * cfg.line_price_cents;
}

export function displayName(name: string) {
  const parts = String(name || "").trim().split(/\s+/).filter(Boolean);
  if (!parts.length) return "A player";
  if (parts.length === 1) return parts[0];
  return parts[0] + " " + parts[parts.length - 1][0].toUpperCase() + ".";
}

// ── Dublin time ───────────────────────────────────────────────────────────────
const dublinFmt = new Intl.DateTimeFormat("en-GB", {
  timeZone: "Europe/Dublin", year: "numeric", month: "2-digit", day: "2-digit",
  hour: "2-digit", minute: "2-digit", second: "2-digit", hourCycle: "h23", weekday: "short",
});
const WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

function dublinParts(d: Date) {
  const p: Record<string, string> = {};
  for (const x of dublinFmt.formatToParts(d)) p[x.type] = x.value;
  return { y: +p.year, m: +p.month, d: +p.day, h: +p.hour, mi: +p.minute, s: +p.second, wd: WEEKDAYS.indexOf(p.weekday) };
}

function dublinOffsetMs(d: Date) {
  const p = dublinParts(d);
  return Date.UTC(p.y, p.m - 1, p.d, p.h, p.mi, p.s) - Math.floor(d.getTime() / 1000) * 1000;
}

function dublinToUtc(y: number, m: number, d: number, h: number, mi: number) {
  const guess = Date.UTC(y, m - 1, d, h, mi);
  const off = dublinOffsetMs(new Date(guess - dublinOffsetMs(new Date(guess))));
  return new Date(guess - off);
}

// First draw time strictly after `after`, from the club's weekday and Dublin time.
export function nextDrawAt(cfg: any, after: Date) {
  const [hh, mm] = String(cfg.draw_time || "21:00").split(":").map(Number);
  for (let i = 0; i <= 8; i++) {
    const p = dublinParts(new Date(after.getTime() + i * 86400000));
    if (p.wd !== cfg.draw_weekday) continue;
    const at = dublinToUtc(p.y, p.m, p.d, hh, mm);
    if (at.getTime() > after.getTime()) return at;
  }
  throw new Error("Could not work out the next draw");
}

export function salesCloseFor(cfg: any, drawAt: Date) {
  return new Date(drawAt.getTime() - cfg.sales_close_minutes * 60000);
}

// The oldest draw not yet published; creates the next one from the schedule if none.
export async function ensureOpenDraw(sb: any, cfg: any) {
  const { data: open } = await sb.from("lotto_draws").select("*")
    .eq("lotto_id", cfg.lotto_id).eq("status", "open").order("draw_at").limit(1).maybeSingle();
  if (open) return open;
  const { data: last } = await sb.from("lotto_draws").select("draw_at")
    .eq("lotto_id", cfg.lotto_id).order("draw_at", { ascending: false }).limit(1).maybeSingle();
  const now = new Date();
  const after = last && new Date(last.draw_at) > now ? new Date(last.draw_at) : now;
  const drawAt = nextDrawAt(cfg, after);
  await sb.from("lotto_draws").upsert({
    lotto_id: cfg.lotto_id, draw_at: drawAt.toISOString(), sales_close_at: salesCloseFor(cfg, drawAt).toISOString(),
  }, { onConflict: "lotto_id,draw_at", ignoreDuplicates: true });
  const { data } = await sb.from("lotto_draws").select("*")
    .eq("lotto_id", cfg.lotto_id).eq("status", "open").order("draw_at").limit(1).maybeSingle();
  return data;
}

// ── Tickets and payments ──────────────────────────────────────────────────────
export async function loadLotto(sb: any, lottoId: number) {
  const { data } = await sb.from("lotto_clubs").select("*, clubs(club_name, crest, primary_colour, secondary_colour, stripe_account_id)")
    .eq("lotto_id", lottoId).maybeSingle();
  return data;
}

export function clubName(cfg: any) {
  return cfg?.clubs?.club_name || "Club";
}

// A weekly ticket's paid weeks are its payment rows (one per paid invoice).
async function recountWeekly(sb: any, ticketId: number) {
  const { count } = await sb.from("lotto_payments").select("payment_id", { count: "exact", head: true }).eq("ticket_id", ticketId);
  await sb.from("lotto_tickets").update({ weeks_paid: count || 0 }).eq("ticket_id", ticketId);
}

export async function recordInvoice(sb: any, ticket: any, invoice: any) {
  if (!invoice?.id || invoice.status !== "paid") return;
  await sb.from("lotto_payments").upsert({
    lotto_id: ticket.lotto_id, ticket_id: ticket.ticket_id, amount_cents: invoice.amount_paid ?? 0,
    kind: invoice.billing_reason === "subscription_create" ? "checkout" : "renewal",
    stripe_ref: invoice.id, paid_at: new Date((invoice.status_transitions?.paid_at || invoice.created || Date.now() / 1000) * 1000).toISOString(),
  }, { onConflict: "stripe_ref", ignoreDuplicates: true });
  await recountWeekly(sb, ticket.ticket_id);
}

// Marks a pending ticket paid from its Checkout Session. Safe to call many times;
// returns true only the first time (so the confirmation email goes once).
export async function confirmCheckout(sb: any, cfg: any, session: any) {
  const ticketId = Number(session?.metadata?.ticket_id);
  if (!ticketId || session.payment_status !== "paid") return { ticket: null, first: false };
  const { data: ticket } = await sb.from("lotto_tickets").select("*").eq("ticket_id", ticketId).eq("lotto_id", cfg.lotto_id).maybeSingle();
  if (!ticket) return { ticket: null, first: false };

  const subId = typeof session.subscription === "string" ? session.subscription : session.subscription?.id;
  const { data: claimed } = await sb.from("lotto_tickets").update({
    status: "active", paid_at: new Date().toISOString(),
    weeks_paid: ticket.plan === "weeks" ? ticket.weeks_bought : Math.max(ticket.weeks_paid, 1),
    stripe_subscription_id: subId || null,
  }).eq("ticket_id", ticketId).eq("status", "pending").select("*").maybeSingle();

  if (ticket.plan === "weeks") {
    await sb.from("lotto_payments").upsert({
      lotto_id: cfg.lotto_id, ticket_id: ticketId, amount_cents: session.amount_total ?? 0,
      kind: "checkout", stripe_ref: session.id,
    }, { onConflict: "stripe_ref", ignoreDuplicates: true });
  } else if (session.invoice) {
    const invoiceId = typeof session.invoice === "string" ? session.invoice : session.invoice.id;
    const invoice = await stripe("GET", `/invoices/${invoiceId}`, null, acct(cfg));
    await recordInvoice(sb, ticket, invoice);
  }
  const fresh = claimed || (await sb.from("lotto_tickets").select("*").eq("ticket_id", ticketId).maybeSingle()).data;
  if (claimed) await sendConfirmation(sb, cfg, fresh).catch(e => console.error("confirmation email", e));
  return { ticket: fresh, first: !!claimed };
}

// Before a draw: settle recent unpaid checkouts and weekly renewals straight from
// Stripe, so the draw is right even if a webhook was missed.
export async function syncWithStripe(sb: any, cfg: any) {
  if (!acct(cfg)) return;
  const since = new Date(Date.now() - 3 * 86400000).toISOString();
  const { data: pending } = await sb.from("lotto_tickets").select("*")
    .eq("lotto_id", cfg.lotto_id).eq("status", "pending").gte("created_at", since).not("stripe_checkout_session_id", "is", null);
  const { data: weekly } = await sb.from("lotto_tickets").select("*")
    .eq("lotto_id", cfg.lotto_id).eq("plan", "weekly").eq("status", "active").not("stripe_subscription_id", "is", null);

  const jobs: (() => Promise<void>)[] = [];
  for (const t of pending || []) jobs.push(async () => {
    const s = await stripe("GET", `/checkout/sessions/${t.stripe_checkout_session_id}`, null, acct(cfg));
    await confirmCheckout(sb, cfg, s);
  });
  for (const t of weekly || []) jobs.push(async () => {
    const list = await stripe("GET", "/invoices", { subscription: t.stripe_subscription_id, status: "paid", limit: 100 }, acct(cfg));
    for (const inv of list.data || []) await recordInvoice(sb, t, inv);
    const sub = await stripe("GET", `/subscriptions/${t.stripe_subscription_id}`, null, acct(cfg));
    if (sub.status === "canceled") {
      await sb.from("lotto_tickets").update({ status: "cancelled", cancelled_at: new Date().toISOString() })
        .eq("ticket_id", t.ticket_id).eq("status", "active");
    }
  });
  for (let i = 0; i < jobs.length; i += 8) {
    await Promise.all(jobs.slice(i, i + 8).map(j => j().catch(e => console.error("stripe sync", e))));
  }
}

// ── Email (Resend) ────────────────────────────────────────────────────────────
export async function sendEmails(msgs: any[]) {
  const key = Deno.env.get("RESEND_API_KEY");
  if (!key || !msgs.length) return;
  for (let i = 0; i < msgs.length; i += 100) {
    const res = await fetch("https://api.resend.com/emails/batch", {
      method: "POST",
      headers: { Authorization: "Bearer " + key, "Content-Type": "application/json" },
      body: JSON.stringify(msgs.slice(i, i + 100)),
    });
    if (!res.ok) console.error("resend batch", res.status, await res.text());
  }
}

export function fromLine(cfg: any) {
  const name = `${clubName(cfg)} Lotto`.replace(/[<>"]/g, "");
  return `${name} <no-reply@coachsmart.app>`;
}

export function esc(s: unknown) {
  return String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]!));
}

export function colours(cfg: any) {
  return {
    primary: cfg.colour_primary || cfg.clubs?.primary_colour || "#1B3A6B",
    accent: cfg.colour_accent || cfg.clubs?.secondary_colour || "#ED1B2E",
  };
}

export function ballsHtml(nums: number[], hit: number[] = [], bg = "#1B3A6B", hitBg = "#ED1B2E") {
  return nums.map(n => `<span style="display:inline-block;width:32px;height:32px;line-height:32px;border-radius:16px;text-align:center;font-weight:700;font-size:14px;color:#fff;margin-right:6px;background:${hit.includes(n) ? hitBg : bg}">${n}</span>`).join("");
}

export function emailShell(cfg: any, title: string, inner: string, link: string, linkText: string) {
  const c = colours(cfg);
  return `<!doctype html><html><body style="margin:0;background:#F5F6FB;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#1B2333">
<div style="max-width:520px;margin:0 auto;padding:16px">
<div style="background:${c.primary};color:#fff;border-radius:14px 14px 0 0;padding:18px;border-bottom:5px solid ${c.accent}">
${cfg.clubs?.crest ? `<img src="${esc(cfg.clubs.crest)}" width="40" height="40" style="vertical-align:middle;margin-right:10px" alt="">` : ""}
<span style="font-size:20px;font-weight:700;vertical-align:middle">${esc(clubName(cfg))} ${esc(cfg.lotto_name)}</span></div>
<div style="background:#fff;border-radius:0 0 14px 14px;padding:18px">
<h2 style="margin:0 0 12px;font-size:18px;color:${c.primary}">${esc(title)}</h2>
${inner}
<p style="margin:20px 0 4px"><a href="${esc(link)}" style="display:inline-block;background:${c.accent};color:#fff;text-decoration:none;font-weight:700;padding:11px 18px;border-radius:10px">${esc(linkText)}</a></p>
</div>
<p style="font-size:11px;color:#5B6478;text-align:center;line-height:1.5">${esc(cfg.licence_text || "")}<br>18+ only. Payments go directly to ${esc(clubName(cfg))}. Powered by CoachSmart.</p>
</div></body></html>`;
}

async function sendConfirmation(sb: any, cfg: any, ticket: any) {
  const { data: player } = await sb.from("lotto_players").select("*").eq("player_id", ticket.player_id).maybeSingle();
  if (!player) return;
  const draw = await ensureOpenDraw(sb, cfg);
  const lines: number[][] = ticket.lines || [];
  const link = `${PAGE_BASE}${cfg.slug}?t=${player.token}`;
  const when = draw ? new Date(draw.draw_at) : null;
  const firstDraw = when && new Date(ticket.paid_at || Date.now()) >= new Date(draw.sales_close_at) ? nextDrawAt(cfg, when) : when;
  const plan = ticket.plan === "weekly"
    ? `Every week, ${euro(ticket.price_cents)} a week. Stop any time from the link below.`
    : `${ticket.weeks_bought} ${ticket.weeks_bought === 1 ? "week" : "weeks"}.`;
  const inner = `<p style="margin:0 0 12px">Thanks ${esc(player.name.split(" ")[0])}, your lines are in.</p>
${lines.map(l => `<div style="padding:6px 0;border-top:1px solid #E3E7F0">${ballsHtml(l, [], colours(cfg).primary)}</div>`).join("")}
<p style="margin:12px 0 0;font-size:14px">${esc(plan)}</p>
${firstDraw ? `<p style="margin:6px 0 0;font-size:14px">First draw: ${esc(fmtDate(firstDraw))}. Jackpot ${esc(euro(cfg.jackpot_cents))}.</p>` : ""}`;
  await sendEmails([{
    from: fromLine(cfg), to: [player.email], reply_to: cfg.contact_email || undefined,
    subject: `You're in the ${clubName(cfg)} Lotto`,
    html: emailShell(cfg, "You're in", inner, link, "See your tickets"),
  }]);
}

export function fmtDate(d: Date) {
  return d.toLocaleString("en-IE", { weekday: "long", day: "numeric", month: "long", hour: "numeric", minute: "2-digit", timeZone: "Europe/Dublin" });
}
