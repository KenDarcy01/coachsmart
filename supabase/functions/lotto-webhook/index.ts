// deno-lint-ignore-file no-explicit-any
// Stripe Connect webhook for the club lotto. Set up in Stripe as a Connect
// endpoint ("events on connected accounts") pointing at this function, with:
//   checkout.session.completed, checkout.session.async_payment_succeeded,
//   invoice.paid, customer.subscription.deleted
// Requires: LOTTO_STRIPE_WEBHOOK_SECRET (the endpoint's signing secret).
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { acct, confirmCheckout, json, loadLotto, recordInvoice, verifyStripeSignature } from "../_shared/lotto.ts";

serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const secret = Deno.env.get("LOTTO_STRIPE_WEBHOOK_SECRET");
  if (!secret) return json({ error: "Webhook secret not set" }, 500);

  const body = await req.text();
  if (!(await verifyStripeSignature(body, req.headers.get("Stripe-Signature") || "", secret))) {
    return json({ error: "Bad signature" }, 400);
  }
  const event = JSON.parse(body);
  const obj = event.data?.object || {};
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

  try {
    if (event.type === "checkout.session.completed" || event.type === "checkout.session.async_payment_succeeded") {
      const cfg = await lottoFor(sb, obj.metadata?.lotto_id, event.account);
      if (cfg) await confirmCheckout(sb, cfg, obj);
    } else if (event.type === "invoice.paid") {
      const subId = typeof obj.subscription === "string" ? obj.subscription : obj.subscription?.id
        || obj.parent?.subscription_details?.subscription;
      const ticket = subId ? await ticketForSub(sb, subId) : null;
      // The first invoice is recorded when the checkout is confirmed.
      if (ticket && ticket.status !== "pending") {
        const cfg = await lottoFor(sb, ticket.lotto_id, event.account);
        if (cfg) await recordInvoice(sb, ticket, obj);
      }
    } else if (event.type === "customer.subscription.deleted") {
      const ticket = await ticketForSub(sb, obj.id);
      if (ticket && ticket.status === "active") {
        await sb.from("lotto_tickets").update({
          status: ticket.draws_entered >= ticket.weeks_paid ? "ended" : "cancelled", cancelled_at: new Date().toISOString(),
        }).eq("ticket_id", ticket.ticket_id).eq("status", "active");
      }
    }
  } catch (e) {
    console.error("lotto-webhook", event.type, e);
    return json({ error: (e as Error).message }, 500);
  }
  return json({ received: true });
});

// The lotto must belong to the connected account the event came from.
async function lottoFor(sb: any, lottoId: any, account: string | undefined) {
  if (!lottoId) return null;
  const cfg = await loadLotto(sb, Number(lottoId));
  if (!cfg || !account || acct(cfg) !== account) return null;
  return cfg;
}

async function ticketForSub(sb: any, subId: string) {
  const { data } = await sb.from("lotto_tickets").select("*").eq("stripe_subscription_id", subId).maybeSingle();
  return data;
}
