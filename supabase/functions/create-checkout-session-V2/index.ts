// Supabase Edge Function: create-checkout-session-V2
// Makes the Stripe Checkout session for an event payment (one line for the
// players being paid for). Called by the live app (FlutterFlow) and v3.
//
// Reworked 2026-11-11 (thread "Check payments on the v3 screens"):
// - The price comes from events.payment_amount, never from the phone. The
//   amount and unitPrice the app sends are ignored.
// - Players who are already paid for, by anyone, are left out. If nobody is
//   left the answer is 409 { error: 'already_paid' }.
// - A checkout still open for the same players is closed first, so two open
//   checkouts can't both be paid. One that was just paid (webhook not in yet)
//   counts as paid.
// - Each checkout is logged as 'pending' rows in event_user_member_payment;
//   the webhook turns them into 'confirmed'. Every reader ignores 'pending'.
// - Team Stripe Connect (2026-11-12): when the team has its own Stripe
//   account that can take payments (teams.stripe_account_id, set up through
//   team-stripe), the checkout is made on the team's account so the money goes
//   straight to the team. Those payments are recorded by the Connect webhook
//   (lotto-webhook). The club account (clubs.stripe_account_id) is the lotto's
//   and is never used for team payments. A team that has never had a ready
//   account but has payments on (the teams from before Connect) stays on the
//   CoachSmart account; any other team can't take payments until it connects.
// The answer adds memberIds, unitPrice and amount next to checkoutUrl.
import { serve } from 'https://deno.land/std@0.208.0/http/server.ts';
import Stripe from 'https://esm.sh/stripe@13.11.0?no-dts&no-std';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};

function reply(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders }
  });
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders, status: 204 });
  if (req.method !== 'POST') return reply({ error: 'Method not allowed' }, 405);

  try {
    const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
      auth: { persistSession: false }
    });

    const payload = await req.json();
    const { appEventId, appUserId, productName, appSuccessUrl, appCancelUrl, memberIds } = payload;
    if (!appEventId || typeof appEventId !== 'number' || !Number.isInteger(appEventId) ||
        !appUserId || typeof appSuccessUrl !== 'string' || !appSuccessUrl ||
        typeof appCancelUrl !== 'string' || !appCancelUrl ||
        !Array.isArray(memberIds) || memberIds.length === 0 ||
        memberIds.some((id: unknown) => typeof id !== 'number' || !Number.isInteger(id))) {
      return reply({ error: 'Missing or invalid required payload fields.' }, 400);
    }

    // The signed-in user, when the app sends a user token; the payload's
    // appUserId otherwise (older app builds).
    let userId = String(appUserId);
    const token = (req.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '');
    if (token) {
      const { data } = await sb.auth.getUser(token);
      if (data?.user?.id) userId = data.user.id;
    }

    // The event sets the price.
    const { data: ev, error: evErr } = await sb
      .from('events')
      .select('event_id, team_id, payment_required, payment_amount, status, teams(payments, stripe_account_id, stripe_ready_at)')
      .eq('event_id', appEventId)
      .maybeSingle();
    if (evErr) throw new Error(evErr.message);
    if (!ev) return reply({ error: 'Event not found.' }, 404);
    if (ev.status === 'cancelled') return reply({ error: 'This event is cancelled.' }, 400);
    const unitPrice = Number(ev.payment_amount) || 0;
    if (!ev.payment_required || unitPrice < 50) {
      return reply({ error: 'This event does not take payments.' }, 400);
    }

    const wanted = [...new Set(memberIds as number[])];

    // Already paid for, by anyone.
    const { data: rows, error: payErr } = await sb
      .from('event_user_member_payment')
      .select('member_id, payment_status, stripe_session_id, created_at')
      .eq('event_id', appEventId)
      .in('member_id', wanted)
      .in('payment_status', ['confirmed', 'pending']);
    if (payErr) throw new Error(payErr.message);
    const paid = new Set<number>();
    for (const r of rows || []) if (r.payment_status === 'confirmed') paid.add(Number(r.member_id));

    // Checkouts still open for these players: a paid one counts as paid, an
    // open one is closed so it can't be paid as well.
    const team = (ev as any).teams || {};
    const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY');
    if (!stripeSecretKey) throw new Error('STRIPE_SECRET_KEY environment variable is not set.');
    const stripe = new Stripe(stripeSecretKey, { apiVersion: '2023-10-16' });
    const teamAccount: string | null = team.stripe_account_id || null;
    const openSessions = new Set<string>();
    // Stripe closes a checkout after 24 hours, so older ones can be skipped.
    const dayAgo = Date.now() - 25 * 3600 * 1000;
    for (const r of rows || []) {
      if (r.payment_status === 'pending' && r.stripe_session_id && !paid.has(Number(r.member_id)) &&
          new Date(r.created_at).getTime() > dayAgo) {
        openSessions.add(r.stripe_session_id);
      }
    }
    for (const sid of openSessions) {
      const acct = await sessionAccount(stripe, sid, teamAccount);
      if (!acct.session) continue;
      const s = acct.session;
      const ids: number[] = safeIds(s.metadata?.member_ids);
      if (s.status === 'complete' && (s.payment_status === 'paid' || s.payment_status === 'no_payment_required')) {
        ids.forEach((id) => paid.add(id));
      } else if (s.status === 'open') {
        try {
          await stripe.checkout.sessions.expire(sid, acct.account ? { stripeAccount: acct.account } : undefined);
        } catch (e) {
          console.warn(`Could not close checkout ${sid}: ${(e as Error).message}`);
        }
      }
    }

    const toPay = wanted.filter((id) => !paid.has(id));
    if (toPay.length === 0) return reply({ error: 'already_paid' }, 409);
    const amount = unitPrice * toPay.length;

    // The team's own Stripe account when it can take payments.
    let account: string | null = null;
    if (teamAccount) {
      try {
        const a = await stripe.accounts.retrieve(teamAccount);
        if (a.charges_enabled) account = teamAccount;
      } catch (e) {
        console.warn(`Team account ${teamAccount} not usable: ${(e as Error).message}`);
      }
    }
    // CoachSmart never holds a team's money: only the teams from before
    // Connect (payments on, never had a ready account) fall back to it.
    if (!account && !(team.payments && !team.stripe_ready_at)) {
      return reply({ error: 'This team has not set up payments yet.' }, 409);
    }

    const sep = appSuccessUrl.includes('?') ? '&' : '?';
    const title = typeof productName === 'string' && productName.trim() ? productName.trim() : 'Event payment';
    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      line_items: [{
        price_data: { currency: 'eur', product_data: { name: title }, unit_amount: amount },
        quantity: 1
      }],
      metadata: {
        app_event_id: String(appEventId),
        unit_price: String(unitPrice),
        member_ids: JSON.stringify(toPay),
        ...(account ? { stripe_account: account } : {})
      },
      client_reference_id: userId,
      success_url: `${appSuccessUrl}${sep}stripeSessionId={CHECKOUT_SESSION_ID}`,
      cancel_url: appCancelUrl
    }, account ? { stripeAccount: account } : undefined);

    // Log the open checkout; the webhook confirms these rows.
    const { error: insErr } = await sb.from('event_user_member_payment').upsert(
      toPay.map((memberId) => ({
        payment_status: 'pending',
        event_id: appEventId,
        user_id: userId,
        member_id: memberId,
        stripe_session_id: session.id,
        stripe_checkout_url: session.url,
        stripe_account_id: account,
        amount_paid: unitPrice,
        gross_amount: unitPrice,
        event_title: title
      })),
      { onConflict: 'stripe_session_id, member_id', ignoreDuplicates: true }
    );
    if (insErr) console.warn('Pending rows not saved:', insErr.message);

    return reply({ checkoutUrl: session.url, memberIds: toPay, unitPrice, amount });
  } catch (error) {
    console.error('Execution error:', (error as Error).message);
    return reply({ error: 'Failed to create Checkout Session', details: (error as Error).message }, 500);
  }
});

function safeIds(json: unknown): number[] {
  try {
    const v = JSON.parse(String(json ?? '[]'));
    return Array.isArray(v) ? v.map(Number).filter(Number.isInteger) : [];
  } catch {
    return [];
  }
}

// Find a checkout on the CoachSmart account or, failing that, the team's.
async function sessionAccount(stripe: any, sid: string, teamAccount: string | null) {
  try {
    return { session: await stripe.checkout.sessions.retrieve(sid), account: null };
  } catch (_) { /* not on the platform account */ }
  if (teamAccount) {
    try {
      return { session: await stripe.checkout.sessions.retrieve(sid, {}, { stripeAccount: teamAccount }), account: teamAccount };
    } catch (_) { /* not found */ }
  }
  return { session: null, account: null };
}
