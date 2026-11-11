// deno-lint-ignore-file no-explicit-any
// Event payments made on a club's own Stripe account (2026-11-11). Stripe
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

// A whole charge refunded in the club's Stripe dashboard: mark its rows.
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
