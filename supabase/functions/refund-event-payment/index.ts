// deno-lint-ignore-file no-explicit-any
// refund-event-payment (2026-11-11): a team admin refunds one player's event
// payment from the app. Body { paymentId } (event_user_member_payment row).
// - Caller must be signed in and an admin of the event's team (is_event_admin).
// - Refunds that row's amount through Stripe on the account the payment was
//   made on (CoachSmart's, or the team's own Connect account). When a parent
//   paid for several players in one checkout, only this player's share goes
//   back. Stripe keeps its fee.
// - The row becomes 'refunded' (refund_id, refunded_at, refunded_by), so the
//   player is back on Not paid, and the payer gets a notification.
// Answers { success: true, amount } or { error } with 4xx/5xx.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { stripe } from "../_shared/stripe-connect.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json", ...cors } });
const euro = (c: number) => "€" + (c / 100).toFixed(2);

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const auth = req.headers.get("Authorization") || "";
  const sb = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
  const { data: who } = await sb.auth.getUser(auth.replace(/^Bearer\s+/i, ""));
  const userId = who?.user?.id;
  if (!userId) return json({ error: "Please sign in again." }, 401);

  let paymentId = 0;
  try {
    paymentId = Number((await req.json()).paymentId);
  } catch (_) { /* bad body */ }
  if (!Number.isInteger(paymentId) || paymentId <= 0) return json({ error: "Missing paymentId." }, 400);

  const { data: row } = await sb.from("event_user_member_payment")
    .select("payment_id, event_id, member_id, user_id, payment_status, amount_paid, stripe_session_id, stripe_payment_intent_id, stripe_account_id, event_title")
    .eq("payment_id", paymentId).maybeSingle();
  if (!row) return json({ error: "Payment not found." }, 404);

  // Admin of the event's team, checked as the caller.
  const asUser = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    auth: { persistSession: false },
    global: { headers: { Authorization: auth } },
  });
  const { data: isAdmin } = await asUser.rpc("is_event_admin", { p_event_id: row.event_id });
  if (isAdmin !== true) return json({ error: "Only team admins can refund." }, 403);

  if (row.payment_status === "refunded") return json({ error: "This payment is already refunded." }, 409);
  if (row.payment_status !== "confirmed") return json({ error: "This payment can't be refunded." }, 409);
  const amount = Number(row.amount_paid) || 0;
  if (amount <= 0) return json({ error: "Nothing to refund." }, 400);

  // Claim the row so a double tap can't refund twice.
  const { data: claimed } = await sb.from("event_user_member_payment")
    .update({ payment_status: "refunding" })
    .eq("payment_id", paymentId).eq("payment_status", "confirmed").select("payment_id");
  if (!claimed?.length) return json({ error: "This payment is already being refunded." }, 409);

  try {
    const { data: ev } = await sb.from("events")
      .select("event_id, team_id, teams(team_name, stripe_account_id)").eq("event_id", row.event_id).maybeSingle();
    // The account the payment was made on: the team's own Stripe account
    // (team Stripe Connect, 2026-11-12) or the CoachSmart account.
    const teamAccount: string | null = row.stripe_account_id || (ev as any)?.teams?.stripe_account_id || null;
    const found = await findPaymentIntent(row, teamAccount);
    if (!found) throw new Error("Could not find this payment in Stripe.");

    const refund = await stripe("POST", "/refunds", {
      payment_intent: found.pi,
      amount,
      reason: "requested_by_customer",
      metadata: { payment_id: String(paymentId), member_id: String(row.member_id), event_id: String(row.event_id) },
    }, found.account);

    await sb.from("event_user_member_payment").update({
      payment_status: "refunded",
      refund_id: refund.id,
      refunded_at: new Date().toISOString(),
      refunded_by: userId,
      stripe_payment_intent_id: found.pi,
    }).eq("payment_id", paymentId);

    await notifyPayer(sb, row, (ev as any)?.team_id ?? null, (ev as any)?.teams?.team_name || "", amount);
    return json({ success: true, amount });
  } catch (e) {
    await sb.from("event_user_member_payment").update({ payment_status: "confirmed" })
      .eq("payment_id", paymentId).eq("payment_status", "refunding");
    console.error("refund-event-payment", paymentId, (e as Error).message);
    return json({ error: (e as Error).message || "The refund failed." }, 502);
  }
});

// The payment intent and the Stripe account it lives on.
async function findPaymentIntent(row: any, teamAccount: string | null) {
  const accounts: (string | null)[] = row.stripe_account_id
    ? [row.stripe_account_id]
    : [null, ...(teamAccount ? [teamAccount] : [])];
  for (const account of accounts) {
    try {
      if (row.stripe_payment_intent_id) {
        const pi = await stripe("GET", `/payment_intents/${row.stripe_payment_intent_id}`, null, account);
        return { pi: pi.id as string, account };
      }
      if (row.stripe_session_id) {
        const s = await stripe("GET", `/checkout/sessions/${row.stripe_session_id}`, null, account);
        const pi = typeof s.payment_intent === "string" ? s.payment_intent : s.payment_intent?.id;
        if (pi) return { pi: pi as string, account };
      }
    } catch (_) { /* not on this account */ }
  }
  return null;
}

async function notifyPayer(sb: any, row: any, teamId: number | null, teamName: string, amount: number) {
  try {
    const [{ data: user }, { data: member }] = await Promise.all([
      sb.from("users").select("fcm_token").eq("user_id", row.user_id).maybeSingle(),
      sb.from("members").select("first_name").eq("member_id", row.member_id).maybeSingle(),
    ]);
    const name = member?.first_name || "your player";
    const what = (row.event_title || "the event").trim();
    await sb.from("notifications").insert({
      recipient_user_id: row.user_id,
      team_id: teamId,
      event_id: row.event_id,
      link_page: "Notifications",
      is_delivered: false,
      is_read: false,
      delivery_method: user?.fcm_token ? "push" : "email",
      created_at: new Date().toISOString(),
      push_title: teamName ? `${teamName}: Refund` : "Refund",
      push_body: `${euro(amount)} refunded for ${name} for ${teamName ? `${teamName}, ` : ""}${what}.`,
      app_title: `Refund for ${name}`,
      app_body: `${euro(amount)} refunded for ${name} for ${teamName ? `${teamName}, ` : ""}${what}. It goes back to the card you paid with, usually within 5 to 10 days.`,
      action: null,
    });
  } catch (e) {
    console.warn("refund notification failed", (e as Error).message);
  }
}

