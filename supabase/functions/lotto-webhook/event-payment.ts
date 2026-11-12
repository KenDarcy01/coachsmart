// deno-lint-ignore-file no-explicit-any
// Event payments made on a team's own Stripe account (team Stripe Connect,
// 2026-11-12; before that, briefly, the club's account). Stripe
// sends those to this Connect endpoint, not to stripe-webhook-listener-V2,
// so they are recorded here the same way: one confirmed
// event_user_member_payment row per player, with the fee and net split
// evenly between them.
import { stripe } from "../_shared/stripe-connect.ts";

export function isEventPayment(session: any) {
  return !!session?.metadata?.app_event_id && !session?.metadata?.lotto_id;
}

export async function recordEventPayment(sb: any, session: any, account: string | null) {
  if (session.payment_status !== "paid" && session.payment_status !== "no_payment_required") return;
  const full = await stripe("GET", `/checkout/sessions/${session.id}`, { expand: ["line_items", "payment_intent"] }, account);
  const meta = full.metadata || {};
  let memberIds: number[] = [];
  try {
    const v = JSON.parse(meta.member_ids || "[]");
    memberIds = Array.isArray(v) ? v.map(Number).filter(Number.isInteger) : [];
  } catch (_) { /* bad metadata */ }
  const unitPrice = parseInt(meta.unit_price || "0", 10);
  if (!meta.app_event_id || !full.client_reference_id || !memberIds.length || unitPrice <= 0) {
    console.error(`event payment ${session.id}: missing ids or price`);
    return;
  }
  // The account must be the event's team's own account.
  const { data: ev } = await sb.from("events").select("teams(stripe_account_id)")
    .eq("event_id", Number(meta.app_event_id)).maybeSingle();
  if (!account || (ev as any)?.teams?.stripe_account_id !== account) {
    console.error(`event payment ${session.id}: account ${account} is not the team's`);
    return;
  }

  let fee = 0, net = full.amount_total || 0;
  const tax = full.total_details?.amount_tax || 0;
  const pi = typeof full.payment_intent === "string" ? null : full.payment_intent;
  if (pi?.latest_charge) {
    try {
      const charge = await stripe("GET", `/charges/${pi.latest_charge}`, { expand: ["balance_transaction"] }, account);
      const bt = charge.balance_transaction;
      if (bt && typeof bt !== "string") {
        fee = bt.fee; net = bt.net;
      }
    } catch (e) {
      console.warn(`event payment ${session.id}: fee lookup failed`, (e as Error).message);
    }
  }

  const n = memberIds.length;
  const rows = memberIds.map((memberId) => ({
    payment_status: "confirmed",
    event_id: Number(meta.app_event_id),
    user_id: full.client_reference_id,
    member_id: memberId,
    stripe_session_id: full.id,
    stripe_payment_intent_id: pi?.id || null,
    stripe_account_id: account,
    amount_paid: unitPrice,
    event_title: full.line_items?.data?.[0]?.description || null,
    fee_amount: Math.round(fee / n),
    net_amount: Math.round(net / n),
    gross_amount: unitPrice,
    tax_amount: Math.round(tax / n),
  }));
  // Never turn a refunded row back into a paid one (Stripe can resend).
  const { data: doneRows } = await sb.from("event_user_member_payment")
    .select("member_id").eq("stripe_session_id", full.id).in("payment_status", ["refunded", "refunding"]);
  const done = new Set((doneRows || []).map((r: any) => Number(r.member_id)));
  const toWrite = rows.filter((r) => !done.has(r.member_id));
  if (!toWrite.length) return;
  const { error } = await sb.from("event_user_member_payment").upsert(toWrite, { onConflict: "stripe_session_id, member_id" });
  if (error) throw new Error("event payment upsert failed: " + error.message);
}

// A whole charge refunded in the team's Stripe dashboard: mark its rows.
export async function markChargeRefunded(sb: any, charge: any, account: string | null) {
  if (charge?.refunded !== true || !charge.payment_intent) return;
  const pi = typeof charge.payment_intent === "string" ? charge.payment_intent : charge.payment_intent.id;
  const list = await stripe("GET", "/checkout/sessions", { payment_intent: pi, limit: 5 }, account);
  const ids = (list.data || []).map((s: any) => s.id);
  if (!ids.length) return;
  await sb.from("event_user_member_payment")
    .update({ payment_status: "refunded", refunded_at: new Date().toISOString(), stripe_payment_intent_id: pi })
    .in("stripe_session_id", ids).eq("payment_status", "confirmed");
}

// A connected account changed (sign-up finished, details due, disabled):
// keep the team's cached state in step. Lotto (club) accounts are ignored.
export async function syncTeamAccount(sb: any, account: any) {
  if (!account?.id) return;
  const { data: team } = await sb.from("teams").select("team_id, stripe_ready_at, stripe_approved_at")
    .eq("stripe_account_id", account.id).maybeSingle();
  if (!team) return;
  const ready = !!account.charges_enabled;
  const now = new Date().toISOString();
  await sb.from("teams").update({
    stripe_charges_enabled: ready,
    stripe_payouts_enabled: !!account.payouts_enabled,
    stripe_details_submitted: !!account.details_submitted,
    stripe_updated_at: now,
    ...(ready && !team.stripe_ready_at ? { stripe_ready_at: now } : {}),
  }).eq("team_id", team.team_id);
  if (ready && !team.stripe_approved_at) {
    try { await notifyStripeReady(sb, team.team_id); } catch (e) { console.error("notifyStripeReady", (e as Error).message); }
  }
}


// ── Tell Ken a team's Stripe account is ready for his approval ───────────────
// Once per account (teams.stripe_notified_at), with a link to his approvals
// page (webviews/stripe-approvals.html, his login only).
const APPROVER_EMAIL = "ken.darcy@gmail.com";
const APPROVALS_PAGE = "https://coachsmart.app/webviews/stripe-approvals.html";

export async function notifyStripeReady(sb: any, teamId: number) {
  const { data: claimed } = await sb.from("teams").update({ stripe_notified_at: new Date().toISOString() })
    .eq("team_id", teamId).is("stripe_notified_at", null).is("stripe_approved_at", null)
    .select("team_id, team_name, stripe_connected_by, clubs(club_name)");
  const t = claimed?.[0];
  if (!t) return;
  let who = "";
  if (t.stripe_connected_by) {
    const { data: u } = await sb.from("users").select("first_name, last_name, email_address")
      .eq("user_id", t.stripe_connected_by).maybeSingle();
    if (u) who = [[u.first_name, u.last_name].filter(Boolean).join(" "), u.email_address].filter(Boolean).join(", ");
  }
  const esc = (s: unknown) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]!));
  const team = `${t.team_name || "A team"}${t.clubs?.club_name ? ` (${t.clubs.club_name})` : ""}`;
  const link = `${APPROVALS_PAGE}?team=${t.team_id}`;
  const html = `<div style="font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;max-width:480px;margin:0 auto;padding:16px;color:#1B2333">
<h2 style="font-size:19px;margin:0 0 12px">${esc(team)} is ready to take payments</h2>
<p style="margin:0 0 8px">The team has finished its Stripe setup${who ? `. Set up by ${esc(who)}` : ""}.</p>
<p style="margin:0 0 18px">Its payments stay off until you approve it.</p>
<p style="margin:0"><a href="${esc(link)}" style="display:inline-block;background:#87c232;color:#14181b;font-weight:700;text-decoration:none;padding:13px 22px;border-radius:12px">Review and approve</a></p>
</div>`;
  const key = Deno.env.get("RESEND_API_KEY");
  if (!key) { console.error("notifyStripeReady: RESEND_API_KEY not set"); return; }
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: "Bearer " + key, "Content-Type": "application/json" },
    body: JSON.stringify({
      from: "CoachSmart <no-reply@coachsmart.app>", to: [APPROVER_EMAIL],
      subject: `Approve payments: ${team}`, html,
    }),
  });
  if (!res.ok) console.error("notifyStripeReady email", res.status, await res.text());
}
