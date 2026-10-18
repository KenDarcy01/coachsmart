// deno-lint-ignore-file no-explicit-any
// Club lotto: public ticket page, checkout on the club's Stripe Connect account,
// and the club admin's settings and draw.
//
// Public actions (anon key): page, checkout, stop
// Admin actions (signed-in user listed in lotto_admins): admin_load, admin_save,
//   admin_preview, admin_publish, admin_export, admin_add_admin
//
// Requires: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, STRIPE_SECRET_KEY, RESEND_API_KEY.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  acct, ballsHtml, clubName, colours, confirmCheckout, corsHeaders, displayName, emailShell, ensureOpenDraw, esc, euro,
  fmtDate, fromLine, json, MAX_LINES, nextDrawAt, PAGE_BASE, priceFor, salesCloseFor, sendEmails, stripe,
  syncWithStripe,
} from "../_shared/lotto.ts";

const PUBLIC_FIELDS = [
  "slug", "lotto_name", "status", "pool_size", "pick_count", "line_price_cents", "bundle_lines", "bundle_price_cents",
  "draw_weekday", "draw_time", "jackpot_cents", "match3_prize_cents", "lucky_dip_count", "lucky_dip_prize_cents",
  "licence_text", "contact_email",
];

const EDITABLE: Record<string, (v: any) => any> = {
  lotto_name: v => String(v ?? "").trim().slice(0, 60) || "Club Lotto",
  status: v => (["setup", "live", "paused"].includes(v) ? v : bad("Unknown status")),
  pool_size: v => int(v, 10, 60),
  pick_count: v => int(v, 3, 6),
  line_price_cents: v => int(v, 50, 10000),
  bundle_lines: v => int(v, 0, 10),
  bundle_price_cents: v => int(v, 0, 100000),
  draw_weekday: v => int(v, 0, 6),
  draw_time: v => (/^([01]\d|2[0-3]):[0-5]\d$/.test(String(v)) ? String(v) : bad("Draw time should look like 21:00")),
  sales_close_minutes: v => int(v, 0, 2880),
  jackpot_cents: v => int(v, 0, 3000000),
  jackpot_start_cents: v => int(v, 0, 3000000),
  rollover_cents: v => int(v, 0, 300000),
  match3_prize_cents: v => int(v, 0, 300000),
  lucky_dip_count: v => int(v, 0, 20),
  lucky_dip_prize_cents: v => int(v, 0, 300000),
  licence_text: v => String(v ?? "").trim().slice(0, 200) || null,
  contact_email: v => {
    const s = String(v ?? "").trim();
    if (!s) return null;
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s) ? s : bad("Contact email doesn't look right");
  },
  stripe_account_id: v => {
    const s = String(v ?? "").trim();
    if (!s) return null;
    return /^acct_[A-Za-z0-9]+$/.test(s) ? s : bad("Stripe account ID should start with acct_");
  },
};

class UserError extends Error {}
function bad(msg: string): never { throw new UserError(msg); }
function int(v: any, min: number, max: number) {
  const n = Number(v);
  if (!Number.isInteger(n) || n < min || n > max) bad(`Value ${v} should be a whole number from ${min} to ${max}`);
  return n;
}

function validLines(cfg: any, lines: any): number[][] {
  if (!Array.isArray(lines) || !lines.length) bad("Pick at least one line");
  if (lines.length > MAX_LINES) bad(`Up to ${MAX_LINES} lines at a time`);
  return lines.map((l: any) => {
    if (!Array.isArray(l) || l.length !== cfg.pick_count) bad(`Each line needs ${cfg.pick_count} numbers`);
    const nums = l.map(Number);
    if (nums.some((n: number) => !Number.isInteger(n) || n < 1 || n > cfg.pool_size)) bad(`Numbers go from 1 to ${cfg.pool_size}`);
    if (new Set(nums).size !== nums.length) bad("A line can't repeat a number");
    return nums.sort((a: number, b: number) => a - b);
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
  try {
    const body = await req.json().catch(() => ({}));
    const action = String(body.action || "");
    if (action.startsWith("admin_")) return await admin(req, sb, action, body);
    if (action === "page") return await page(sb, body);
    if (action === "checkout") return await checkout(sb, body);
    if (action === "stop") return await stop(sb, body);
    return json({ error: "Unknown action" }, 400);
  } catch (e) {
    if (e instanceof UserError) return json({ error: e.message }, 400);
    console.error("lotto", e);
    return json({ error: (e as Error).message || "Something went wrong" }, 500);
  }
});

async function lottoBySlug(sb: any, slug: any) {
  const s = String(slug || "").toLowerCase();
  if (!/^[a-z0-9-]{2,40}$/.test(s)) bad("Lotto not found");
  const { data } = await sb.from("lotto_clubs").select("*, clubs(club_name, crest, primary_colour, secondary_colour, stripe_account_id)")
    .eq("slug", s).maybeSingle();
  if (!data) bad("Lotto not found");
  return data;
}

function publicCfg(cfg: any) {
  const out: any = {};
  for (const k of PUBLIC_FIELDS) out[k] = cfg[k];
  out.club_name = clubName(cfg);
  out.crest = cfg.clubs?.crest || null;
  out.colours = colours(cfg);
  out.can_pay = !!acct(cfg);
  return out;
}

// Which draw a ticket bought now goes into.
function buyingFor(cfg: any, open: any) {
  if (!open) return null;
  const now = new Date();
  if (now < new Date(open.sales_close_at)) return { draw_at: open.draw_at, sales_close_at: open.sales_close_at, closed_for_current: false };
  const next = nextDrawAt(cfg, new Date(open.draw_at));
  return { draw_at: next.toISOString(), sales_close_at: salesCloseFor(cfg, next).toISOString(), closed_for_current: true };
}

async function lastResults(sb: any, lottoId: number) {
  const { data: d } = await sb.from("lotto_draws").select("draw_id, draw_at, numbers, jackpot_cents, jackpot_won, next_jackpot_cents")
    .eq("lotto_id", lottoId).eq("status", "published").order("draw_at", { ascending: false }).limit(1).maybeSingle();
  if (!d) return null;
  const { data: w } = await sb.from("lotto_winners").select("kind, prize_cents, display_name").eq("draw_id", d.draw_id).order("prize_cents", { ascending: false });
  return { ...d, winners: w || [] };
}

// ── page ──────────────────────────────────────────────────────────────────────
async function page(sb: any, body: any) {
  const cfg = await lottoBySlug(sb, body.slug);
  const open = await ensureOpenDraw(sb, cfg);

  // Back from Stripe: confirm straight away rather than waiting for the webhook.
  let paid: any = null;
  let token = body.token ? String(body.token) : "";
  if (body.paid && acct(cfg) && /^cs_[A-Za-z0-9_]+$/.test(String(body.paid))) {
    const session = await stripe("GET", `/checkout/sessions/${body.paid}`, null, acct(cfg));
    const { ticket } = await confirmCheckout(sb, cfg, session);
    if (ticket) {
      const { data: p } = await sb.from("lotto_players").select("token").eq("player_id", ticket.player_id).maybeSingle();
      token = p?.token || token;
      paid = { lines: ticket.lines, plan: ticket.plan, weeks: ticket.weeks_bought, price_cents: ticket.price_cents };
    } else if (session.status === "open" || session.payment_status === "unpaid") {
      paid = { pending: true };
    }
  }

  const { data: teamRows } = await sb.from("teams").select("team_id, team_name").eq("club_id", cfg.club_id).order("team_name");
  const teamIds = (teamRows || []).map((t: any) => t.team_id);
  const { data: activeLinks } = teamIds.length
    ? await sb.from("member_team_link").select("team_id").in("team_id", teamIds).eq("status", "active")
    : { data: [] };
  const activeTeams = new Set((activeLinks || []).map((l: any) => l.team_id));
  const teams = (teamRows || []).filter((t: any) => activeTeams.has(t.team_id) && t.team_name);

  const results = await lastResults(sb, cfg.lotto_id);
  const me = token ? await playerView(sb, cfg, token, results) : null;

  return json({
    success: true,
    data: { lotto: publicCfg(cfg), buying_for: buyingFor(cfg, open), results, teams, me, paid },
  });
}

async function playerView(sb: any, cfg: any, token: string, results: any) {
  if (!/^[0-9a-f-]{36}$/i.test(token)) return null;
  const { data: player } = await sb.from("lotto_players").select("*").eq("token", token).eq("lotto_id", cfg.lotto_id).maybeSingle();
  if (!player) return null;
  const { data: tickets } = await sb.from("lotto_tickets")
    .select("ticket_id, lines, plan, weeks_bought, weeks_paid, draws_entered, status, price_cents, team_id, teams(team_name)")
    .eq("player_id", player.player_id).in("status", ["active", "cancelled"]).order("ticket_id", { ascending: false });
  let lastEntries: any[] = [];
  let lastPrizes: any[] = [];
  if (results) {
    const [{ data: e }, { data: w }] = await Promise.all([
      sb.from("lotto_entries").select("numbers, matches").eq("draw_id", results.draw_id).eq("player_id", player.player_id).order("entry_id"),
      sb.from("lotto_winners").select("kind, prize_cents").eq("draw_id", results.draw_id).eq("player_id", player.player_id),
    ]);
    lastEntries = e || [];
    lastPrizes = w || [];
  }
  return {
    name: player.name, email: player.email, token: player.token,
    tickets: (tickets || []).map((t: any) => ({
      ticket_id: t.ticket_id, lines: t.lines, plan: t.plan, status: t.status, price_cents: t.price_cents,
      weeks_left: Math.max(0, t.weeks_paid - t.draws_entered), team_name: t.teams?.team_name || null,
    })),
    last_entries: lastEntries, last_prizes: lastPrizes,
  };
}

// ── checkout ──────────────────────────────────────────────────────────────────
async function checkout(sb: any, body: any) {
  const cfg = await lottoBySlug(sb, body.slug);
  if (cfg.status === "paused") bad("The lotto is paused at the moment");
  if (cfg.status !== "live" && !body.preview) bad("The lotto isn't open yet");
  if (!acct(cfg)) bad("Card payments aren't set up yet");

  const lines = validLines(cfg, body.lines);
  const plan = body.plan === "weekly" ? "weekly" : "weeks";
  const weeks = plan === "weekly" ? 1 : int(body.weeks ?? 1, 1, 12);
  const name = String(body.name ?? "").trim().slice(0, 80);
  const email = String(body.email ?? "").trim().toLowerCase().slice(0, 120);
  const phone = String(body.phone ?? "").trim().slice(0, 30) || null;
  if (name.length < 2) bad("Please add your name");
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) bad("Please check your email address");
  if (body.agree18 !== true) bad("You need to be 18 or over to play");

  let teamId: number | null = null;
  if (body.team_id) {
    const { data: t } = await sb.from("teams").select("team_id").eq("team_id", Number(body.team_id)).eq("club_id", cfg.club_id).maybeSingle();
    teamId = t?.team_id ?? null;
  }

  const { data: existing } = await sb.from("lotto_players").select("*").eq("lotto_id", cfg.lotto_id).ilike("email", email).maybeSingle();
  let player = existing;
  if (player) {
    await sb.from("lotto_players").update({ name, phone: phone ?? player.phone }).eq("player_id", player.player_id);
  } else {
    const { data, error } = await sb.from("lotto_players").insert({ lotto_id: cfg.lotto_id, email, name, phone }).select("*").single();
    if (error) throw error;
    player = data;
  }

  const price = priceFor(cfg, lines.length);
  const { data: ticket, error: tErr } = await sb.from("lotto_tickets").insert({
    lotto_id: cfg.lotto_id, player_id: player.player_id, lines, team_id: teamId, plan, weeks_bought: weeks,
    price_cents: price, agreed_18_at: new Date().toISOString(),
  }).select("*").single();
  if (tErr) throw tErr;

  const base = PAGE_BASE + cfg.slug + (body.preview ? "?preview=1&" : "?");
  const label = `${clubName(cfg)} ${cfg.lotto_name}: ${lines.length} ${lines.length === 1 ? "line" : "lines"}`;
  const meta = { ticket_id: String(ticket.ticket_id), lotto_id: String(cfg.lotto_id) };
  const params: any = {
    mode: plan === "weekly" ? "subscription" : "payment",
    customer_email: email,
    success_url: base + "paid={CHECKOUT_SESSION_ID}",
    cancel_url: PAGE_BASE + cfg.slug + (body.preview ? "?preview=1" : ""),
    metadata: meta,
    line_items: [{
      quantity: 1,
      price_data: {
        currency: "eur",
        unit_amount: plan === "weekly" ? price : price * weeks,
        product_data: { name: plan === "weekly" ? `${label}, every week` : `${label}, ${weeks} ${weeks === 1 ? "week" : "weeks"}` },
        ...(plan === "weekly" ? { recurring: { interval: "week" } } : {}),
      },
    }],
  };
  if (plan === "weekly") params.subscription_data = { metadata: meta };
  else params.payment_intent_data = { metadata: meta, description: label };

  const session = await stripe("POST", "/checkout/sessions", params, acct(cfg));
  await sb.from("lotto_tickets").update({ stripe_checkout_session_id: session.id }).eq("ticket_id", ticket.ticket_id);
  return json({ success: true, data: { url: session.url } });
}

// ── stop weekly play ──────────────────────────────────────────────────────────
async function stop(sb: any, body: any) {
  const cfg = await lottoBySlug(sb, body.slug);
  const token = String(body.token || "");
  if (!/^[0-9a-f-]{36}$/i.test(token)) bad("Link not recognised");
  const { data: player } = await sb.from("lotto_players").select("player_id").eq("token", token).eq("lotto_id", cfg.lotto_id).maybeSingle();
  if (!player) bad("Link not recognised");
  const { data: t } = await sb.from("lotto_tickets").select("*").eq("ticket_id", Number(body.ticket_id)).eq("player_id", player.player_id).maybeSingle();
  if (!t || t.plan !== "weekly") bad("Ticket not found");
  if (t.status === "active" && t.stripe_subscription_id) {
    await stripe("DELETE", `/subscriptions/${t.stripe_subscription_id}`, null, acct(cfg)).catch((e) => {
      if (!/No such subscription|canceled/i.test(e.message)) throw e;
    });
  }
  const ended = t.draws_entered >= t.weeks_paid;
  await sb.from("lotto_tickets").update({ status: ended ? "ended" : "cancelled", cancelled_at: new Date().toISOString() })
    .eq("ticket_id", t.ticket_id).in("status", ["active", "pending"]);
  return json({ success: true });
}

// ── admin ─────────────────────────────────────────────────────────────────────
async function admin(req: Request, sb: any, action: string, body: any) {
  const jwt = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  const { data: { user } } = await sb.auth.getUser(jwt);
  if (!user) return json({ error: "Please sign in again" }, 401);

  const { data: mine } = await sb.from("lotto_admins").select("lotto_id").eq("user_id", user.id);
  const ids = (mine || []).map((r: any) => r.lotto_id);
  if (!ids.length) return json({ error: "You're not a lotto admin for any club" }, 403);
  const lottoId = body.lotto_id ? Number(body.lotto_id) : ids[0];
  if (!ids.includes(lottoId)) return json({ error: "You're not an admin for this lotto" }, 403);

  const { data: cfg } = await sb.from("lotto_clubs").select("*, clubs(club_name, crest, primary_colour, secondary_colour, stripe_account_id)").eq("lotto_id", lottoId).single();

  if (action === "admin_load") return json({ success: true, data: await adminView(sb, cfg, ids) });

  if (action === "admin_save") {
    const patch: any = {};
    for (const [k, v] of Object.entries(body.settings || {})) if (EDITABLE[k]) patch[k] = EDITABLE[k](v);
    if (patch.status === "live" && !("stripe_account_id" in patch ? patch.stripe_account_id : acct(cfg))) bad("Add the club's Stripe account before going live");
    // The Stripe account belongs to the club (shared with membership), not the lotto.
    if ("stripe_account_id" in patch) {
      const { error } = await sb.from("clubs").update({ stripe_account_id: patch.stripe_account_id }).eq("club_id", cfg.club_id);
      if (error) throw error;
      delete patch.stripe_account_id;
    }
    patch.updated_at = new Date().toISOString();
    const { data: saved, error } = await sb.from("lotto_clubs").update(patch).eq("lotto_id", lottoId)
      .select("*, clubs(club_name, crest, primary_colour, secondary_colour, stripe_account_id)").single();
    if (error) throw error;
    // A new draw day or time moves the open draw.
    if ("draw_weekday" in patch || "draw_time" in patch || "sales_close_minutes" in patch) {
      const open = await ensureOpenDraw(sb, saved);
      if (open) {
        const at = nextDrawAt(saved, new Date());
        await sb.from("lotto_draws").update({ draw_at: at.toISOString(), sales_close_at: salesCloseFor(saved, at).toISOString() })
          .eq("draw_id", open.draw_id).eq("status", "open");
      }
    }
    return json({ success: true, data: await adminView(sb, saved, ids) });
  }

  if (action === "admin_preview" || action === "admin_publish") {
    const draw = await ensureOpenDraw(sb, cfg);
    const numbers = validLines(cfg, [body.numbers])[0];
    if (new Date() < new Date(draw.sales_close_at)) bad(`Sales are open until ${fmtDate(new Date(draw.sales_close_at))}`);
    await syncWithStripe(sb, cfg);
    const outcome = await workOutDraw(sb, cfg, draw, numbers);
    if (action === "admin_preview") return json({ success: true, data: summarise(cfg, outcome) });
    await publish(sb, cfg, draw, numbers, outcome, user.id);
    return json({ success: true, data: await adminView(sb, (await sb.from("lotto_clubs").select("*, clubs(club_name, crest, primary_colour, secondary_colour, stripe_account_id)").eq("lotto_id", lottoId).single()).data, ids) });
  }

  if (action === "admin_export") return json({ success: true, data: { csv: await exportCsv(sb, cfg, Number(body.draw_id)) } });

  if (action === "admin_add_admin") {
    const email = String(body.email || "").trim().toLowerCase();
    const { data: u } = await sb.from("users").select("user_id").ilike("email_address", email).maybeSingle();
    if (!u) bad("No CoachSmart account with that email");
    await sb.from("lotto_admins").upsert({ lotto_id: lottoId, user_id: u.user_id }, { onConflict: "lotto_id,user_id", ignoreDuplicates: true });
    return json({ success: true, data: await adminView(sb, cfg, ids) });
  }

  return json({ error: "Unknown action" }, 400);
}

async function adminView(sb: any, cfg: any, ids: number[]) {
  const open = await ensureOpenDraw(sb, cfg);
  const { data: prev } = await sb.from("lotto_draws").select("draw_at").eq("lotto_id", cfg.lotto_id).eq("status", "published")
    .order("draw_at", { ascending: false }).limit(1).maybeSingle();

  // Sales since the last draw, and lines/players lined up for the open one.
  let q = sb.from("lotto_payments").select("amount_cents, lotto_tickets(team_id, teams(team_name))").eq("lotto_id", cfg.lotto_id);
  if (prev) q = q.gt("paid_at", prev.draw_at);
  const { data: pays } = await q;
  const byTeam: Record<string, number> = {};
  let sales = 0;
  for (const p of pays || []) {
    sales += p.amount_cents;
    const t = p.lotto_tickets?.teams?.team_name || "No team";
    byTeam[t] = (byTeam[t] || 0) + p.amount_cents;
  }
  const eligible: any[] = open ? await eligibleTickets(sb, cfg, open) : [];
  const lines = eligible.reduce((n, t) => n + (t.lines?.length || 0), 0);
  const players = new Set(eligible.map(t => t.player_id)).size;

  let stripeStatus: any = { connected: false };
  if (acct(cfg)) {
    try {
      const a = await stripe("GET", `/accounts/${acct(cfg)}`);
      stripeStatus = { connected: true, charges_enabled: !!a.charges_enabled, name: a.business_profile?.name || a.settings?.dashboard?.display_name || null };
    } catch (e) {
      stripeStatus = { connected: false, error: (e as Error).message };
    }
  }

  const { data: past } = await sb.from("lotto_draws").select("draw_id, draw_at, numbers, jackpot_cents, jackpot_won, next_jackpot_cents, totals")
    .eq("lotto_id", cfg.lotto_id).eq("status", "published").order("draw_at", { ascending: false }).limit(12);

  const { data: lottos } = await sb.from("lotto_clubs").select("lotto_id, slug, clubs(club_name)").in("lotto_id", ids);
  const { data: admins } = await sb.from("lotto_admins").select("user_id").eq("lotto_id", cfg.lotto_id);
  const { data: adminUsers } = admins?.length
    ? await sb.from("users").select("first_name, last_name, email_address").in("user_id", admins.map((a: any) => a.user_id))
    : { data: [] };

  const { clubs: _c, ...settings } = cfg;
  settings.stripe_account_id = acct(cfg);
  return {
    lotto: { ...settings, club_name: clubName(cfg), crest: cfg.clubs?.crest || null, page_url: PAGE_BASE + cfg.slug },
    lottos: (lottos || []).map((l: any) => ({ lotto_id: l.lotto_id, slug: l.slug, club_name: l.clubs?.club_name })),
    admins: (adminUsers || []).map((u: any) => ({ name: [u.first_name, u.last_name].filter(Boolean).join(" "), email: u.email_address })),
    stripe: stripeStatus,
    draw: open ? { draw_id: open.draw_id, draw_at: open.draw_at, sales_close_at: open.sales_close_at, can_draw: new Date() >= new Date(open.sales_close_at) } : null,
    stats: { sales_cents: sales, lines, players, by_team: Object.entries(byTeam).map(([team, cents]) => ({ team, cents })).sort((a, b) => b.cents - a.cents) },
    past: past || [],
  };
}

async function eligibleTickets(sb: any, cfg: any, draw: any) {
  const { data } = await sb.from("lotto_tickets").select("ticket_id, player_id, lines, weeks_paid, draws_entered, plan, status, paid_at")
    .eq("lotto_id", cfg.lotto_id).in("status", ["active", "cancelled"]).lt("paid_at", draw.sales_close_at);
  return (data || []).filter((t: any) => t.draws_entered < t.weeks_paid);
}

function randomInt(n: number) {
  const a = new Uint32Array(1);
  crypto.getRandomValues(a);
  return a[0] % n;
}

async function workOutDraw(sb: any, cfg: any, draw: any, numbers: number[]) {
  const tickets = await eligibleTickets(sb, cfg, draw);
  const entries: any[] = [];
  for (const t of tickets) {
    (t.lines || []).forEach((line: number[], i: number) => {
      entries.push({ ticket_id: t.ticket_id, player_id: t.player_id, line_no: i + 1, numbers: line, matches: line.filter(n => numbers.includes(n)).length });
    });
  }
  const jackpotLines = entries.filter(e => e.matches === cfg.pick_count);
  const match3Lines = entries.filter(e => e.matches === cfg.pick_count - 1);
  return { tickets, entries, jackpotLines, match3Lines, players: new Set(entries.map(e => e.player_id)).size };
}

function split(total: number, n: number) {
  return n ? Math.floor(total / n) : 0;
}

function summarise(cfg: any, o: any) {
  const won = o.jackpotLines.length > 0;
  return {
    lines: o.entries.length, players: o.players,
    jackpot_cents: cfg.jackpot_cents, jackpot_winners: o.jackpotLines.length,
    jackpot_each_cents: split(cfg.jackpot_cents, o.jackpotLines.length),
    next_jackpot_cents: won ? cfg.jackpot_start_cents : cfg.jackpot_cents + cfg.rollover_cents,
    match3_winners: cfg.match3_prize_cents ? o.match3Lines.length : 0,
    match3_each_cents: cfg.match3_prize_cents ? split(cfg.match3_prize_cents, o.match3Lines.length) : 0,
    lucky_dips: Math.min(cfg.lucky_dip_count, o.players), lucky_dip_prize_cents: cfg.lucky_dip_prize_cents,
  };
}

async function publish(sb: any, cfg: any, draw: any, numbers: number[], o: any, userId: string) {
  const s = summarise(cfg, o);
  // Claim the draw first so a double tap can't publish it twice.
  const { data: claimed } = await sb.from("lotto_draws").update({
    status: "published", numbers, jackpot_cents: cfg.jackpot_cents, jackpot_won: s.jackpot_winners > 0,
    next_jackpot_cents: s.next_jackpot_cents, published_at: new Date().toISOString(), published_by: userId,
  }).eq("draw_id", draw.draw_id).eq("status", "open").select("draw_id").maybeSingle();
  if (!claimed) bad("This draw has already been published");

  for (let i = 0; i < o.entries.length; i += 500) {
    const { error } = await sb.from("lotto_entries").insert(o.entries.slice(i, i + 500).map((e: any) => ({ ...e, draw_id: draw.draw_id })));
    if (error) throw error;
  }

  const playerIds = [...new Set(o.entries.map((e: any) => e.player_id))] as number[];
  const { data: players } = playerIds.length
    ? await sb.from("lotto_players").select("player_id, name, email, token").in("player_id", playerIds)
    : { data: [] };
  const pById = new Map((players || []).map((p: any) => [p.player_id, p]));

  const winners: any[] = [];
  for (const e of o.jackpotLines) winners.push({ kind: "jackpot", prize_cents: s.jackpot_each_cents, player_id: e.player_id, ticket_id: e.ticket_id });
  if (cfg.match3_prize_cents) for (const e of o.match3Lines) winners.push({ kind: "match3", prize_cents: s.match3_each_cents, player_id: e.player_id, ticket_id: e.ticket_id });
  // Lucky dips: random lines (so more lines, more chances), one prize per player.
  const pool = [...o.entries];
  const dipped = new Set<number>();
  while (dipped.size < s.lucky_dips && pool.length) {
    const e = pool.splice(randomInt(pool.length), 1)[0];
    if (dipped.has(e.player_id)) continue;
    dipped.add(e.player_id);
    winners.push({ kind: "lucky_dip", prize_cents: cfg.lucky_dip_prize_cents, player_id: e.player_id, ticket_id: e.ticket_id });
  }
  const winnerRows = winners.map(w => ({ ...w, draw_id: draw.draw_id, display_name: displayName((pById.get(w.player_id) as any)?.name) }));
  if (winnerRows.length) {
    const { error } = await sb.from("lotto_winners").insert(winnerRows);
    if (error) throw error;
  }

  if (o.tickets.length) {
    const { error } = await sb.rpc("lotto_use_week", { p_ticket_ids: o.tickets.map((t: any) => t.ticket_id) });
    if (error) throw error;
  }

  const { data: pays } = await sb.from("lotto_payments").select("amount_cents").eq("lotto_id", cfg.lotto_id)
    .lte("paid_at", draw.sales_close_at);
  const totals = {
    lines: s.lines, players: s.players, jackpot_winners: s.jackpot_winners, match3_winners: s.match3_winners,
    prizes_cents: winnerRows.reduce((n, w) => n + w.prize_cents, 0),
    all_time_sales_cents: (pays || []).reduce((n: number, p: any) => n + p.amount_cents, 0),
  };
  await sb.from("lotto_draws").update({ totals }).eq("draw_id", draw.draw_id);
  await sb.from("lotto_clubs").update({ jackpot_cents: s.next_jackpot_cents, updated_at: new Date().toISOString() }).eq("lotto_id", cfg.lotto_id);
  const fresh = { ...cfg, jackpot_cents: s.next_jackpot_cents };
  await ensureOpenDraw(sb, fresh);

  await sendResults(fresh, draw, numbers, o.entries, winnerRows, pById, s).catch(e => console.error("results email", e));
}

const KIND_LABEL: Record<string, string> = { jackpot: "Jackpot", match3: "Match 3", lucky_dip: "Lucky dip" };

async function sendResults(cfg: any, draw: any, numbers: number[], entries: any[], winners: any[], pById: Map<any, any>, s: any) {
  const c = colours(cfg);
  const winnersHtml = winners.length
    ? winners.map(w => `<div style="display:flex;justify-content:space-between;padding:6px 0;border-top:1px solid #E3E7F0;font-size:14px"><span>${KIND_LABEL[w.kind]} · ${esc(w.display_name)}</span>&nbsp;<b>${euro(w.prize_cents)}</b></div>`).join("")
    : `<p style="font-size:14px;margin:0">No winners this week.</p>`;
  const headline = s.jackpot_winners
    ? `The jackpot of ${euro(s.jackpot_cents)} was won!`
    : `No jackpot winner. Next week's jackpot is ${euro(s.next_jackpot_cents)}.`;

  const byPlayer = new Map<number, any[]>();
  for (const e of entries) byPlayer.set(e.player_id, [...(byPlayer.get(e.player_id) || []), e]);
  const msgs: any[] = [];
  for (const [pid, mine] of byPlayer) {
    const p = pById.get(pid);
    if (!p?.email) continue;
    const myWins = winners.filter(w => w.player_id === pid);
    const inner = `<div style="text-align:center;margin:4px 0 10px">${ballsHtml(numbers, numbers, c.accent, c.accent)}</div>
<p style="text-align:center;font-size:15px;margin:0 0 14px"><b>${esc(headline)}</b></p>
${myWins.length ? `<p style="background:#E9F6DA;border-radius:10px;padding:10px;font-size:15px;margin:0 0 14px">Congratulations, you won ${myWins.map(w => `${euro(w.prize_cents)} (${KIND_LABEL[w.kind]})`).join(" and ")}! The club will be in touch.</p>` : ""}
<p style="font-weight:700;margin:0 0 4px;color:${c.primary}">Your lines</p>
${mine.map(e => `<div style="padding:6px 0;border-top:1px solid #E3E7F0">${ballsHtml(e.numbers, numbers, c.primary, c.accent)} <span style="font-size:13px;color:#5B6478">${e.matches} ${e.matches === 1 ? "match" : "matches"}</span></div>`).join("")}
<p style="font-weight:700;margin:16px 0 4px;color:${c.primary}">Winners</p>${winnersHtml}`;
    msgs.push({
      from: fromLine(cfg), to: [p.email], reply_to: cfg.contact_email || undefined,
      subject: `${clubName(cfg)} Lotto results: ${numbers.join(" ")}`,
      html: emailShell(cfg, `Results for ${fmtDate(new Date(draw.draw_at))}`, inner, `${PAGE_BASE}${cfg.slug}?t=${p.token}`, "Play again"),
    });
  }
  await sendEmails(msgs);
}

function csvCell(v: any) {
  const s = String(v ?? "");
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

async function exportCsv(sb: any, cfg: any, drawId: number) {
  const { data: draw } = await sb.from("lotto_draws").select("*").eq("draw_id", drawId).eq("lotto_id", cfg.lotto_id).maybeSingle();
  if (!draw) bad("Draw not found");
  const { data: entries } = await sb.from("lotto_entries").select("ticket_id, line_no, numbers, matches, lotto_players(name, email)")
    .eq("draw_id", drawId).order("ticket_id").order("line_no");
  const { data: winners } = await sb.from("lotto_winners").select("kind, prize_cents, ticket_id, lotto_players(name, email)").eq("draw_id", drawId);
  const rows = [
    [`${clubName(cfg)} ${cfg.lotto_name}`, fmtDate(new Date(draw.draw_at)), `Numbers ${(draw.numbers || []).join(" ")}`, `Jackpot ${euro(draw.jackpot_cents)}`],
    [],
    ["Winners"], ["Prize", "Amount", "Name", "Email", "Ticket"],
    ...(winners || []).map((w: any) => [KIND_LABEL[w.kind], (w.prize_cents / 100).toFixed(2), w.lotto_players?.name, w.lotto_players?.email, w.ticket_id]),
    [],
    ["Entries"], ["Ticket", "Line", "Numbers", "Matches", "Name", "Email"],
    ...(entries || []).map((e: any) => [e.ticket_id, e.line_no, e.numbers.join(" "), e.matches, e.lotto_players?.name, e.lotto_players?.email]),
  ];
  return rows.map(r => r.map(csvCell).join(",")).join("\n");
}
