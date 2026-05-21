// Supabase Edge Function: stripe-webhook-listener
// This function receives and validates webhooks from Stripe and extracts metadata,
// then UPSERTS a new payment record for tracking payment status history for each member.
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import Stripe from 'https://esm.sh/stripe@14.1.0';
// Reintroducing Supabase client for database interaction
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
// ----------------------------------------------------------------------
// ENVIRONMENT VARIABLE REQUIREMENTS (Must be set in Supabase Secrets)
// 1. SUPABASE_URL: The URL for your Supabase project.
// 2. SUPABASE_SERVICE_ROLE_KEY: The secret key for server-side access (grants full database access).
// 3. STRIPE_SECRET_KEY: Used to fetch full session details.
// 4. STRIPE_WEBHOOK_SECRET: Used to verify the webhook signature (starts with 'whsec_...').
// ----------------------------------------------------------------------
// Initialize Supabase Client
const supabase = createClient(Deno.env.get('SUPABASE_URL'), Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'));
// Initialize Stripe Client with the Secret Key
const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY'), {
  apiVersion: '2023-10-16'
});
serve(async (req)=>{
  // ⚠️ NOTE: The environment variable name was changed here from STRIPE_WEBHOOK_SECRET to STRIPE_WEBHOOK_LISTENER_SECRET_V2
  const WEBHOOK_SECRET = Deno.env.get('STRIPE_WEBHOOK_LISTENER_SECRET_V2');
  if (!WEBHOOK_SECRET) {
    return new Response(JSON.stringify({
      error: 'Stripe Webhook Secret not configured.'
    }), {
      status: 500
    });
  }
  try {
    const signature = req.headers.get('stripe-signature');
    if (!signature) {
      return new Response(JSON.stringify({
        error: 'Missing Stripe signature.'
      }), {
        status: 400
      });
    }
    const body = await req.text();
    let event;
    // 1. Construct the event object and verify signature
    try {
      event = await stripe.webhooks.constructEventAsync(body, signature, WEBHOOK_SECRET);
    } catch (err) {
      console.error(`Webhook signature verification failed: ${err.message}`);
      return new Response(JSON.stringify({
        error: 'Invalid signature'
      }), {
        status: 400
      });
    }
    // 2. Determine action based on event type
    const session = event.data.object;
    let paymentStatus;
    let logMessage;
    // Initialize financial tracking variables
    let grossAmount = session.amount_total;
    let feeAmount = 0;
    let netAmount = session.amount_total;
    let taxAmount = 0;
    // 🛠️ FIX 1: Initialize stripePaymentIntentId outside the conditional block
    let stripePaymentIntentId = null;
    switch(event.type){
      case 'checkout.session.completed':
      case 'checkout.session.async_payment_succeeded':
        paymentStatus = 'confirmed';
        logMessage = 'Payment successful/succeeded. Payment confirmed.';
        break;
      case 'checkout.session.expired':
      case 'checkout.session.async_payment_failed':
        paymentStatus = event.type === 'checkout.session.expired' ? 'expired' : 'failed';
        logMessage = `Payment status updated to ${paymentStatus}.`;
        break;
      default:
        console.log(`Ignoring event type: ${event.type}`);
        return new Response(JSON.stringify({
          received: true,
          ignored: true
        }), {
          status: 200
        });
    }
    // --- Logic Common to All Handled Events (Processing) ---
    const fullSession = await stripe.checkout.sessions.retrieve(session.id, {
      expand: [
        'line_items',
        'payment_intent'
      ]
    });
    const fullSessionWithExpanded = fullSession;
    const appEventId = fullSession.metadata?.app_event_id;
    const appUserId = fullSession.client_reference_id;
    // 🚨 NEW METADATA EXTRACTION
    const unitPriceString = fullSession.metadata?.unit_price;
    const memberIdsJson = fullSession.metadata?.member_ids;
    // --- DATA EXTRACTION ---
    const session_id = fullSession.id;
    let eventTitle = null;
    let memberIds = [];
    let unitPrice = 0;
    // 1. Extract Event Title
    if (fullSessionWithExpanded.line_items && fullSessionWithExpanded.line_items.data && fullSessionWithExpanded.line_items.data.length > 0) {
      eventTitle = fullSessionWithExpanded.line_items.data[0].description;
    }
    // 2. Extract Unit Price and Member IDs
    if (unitPriceString) {
      unitPrice = parseInt(unitPriceString, 10);
    }
    if (memberIdsJson) {
      try {
        memberIds = JSON.parse(memberIdsJson);
        if (!Array.isArray(memberIds)) memberIds = [];
      } catch (e) {
        console.error('Failed to parse member_ids JSON from metadata:', e.message);
        memberIds = [];
      }
    }
    // 3. Extract Total Tax Amount
    if (fullSessionWithExpanded.total_details && fullSessionWithExpanded.total_details.amount_tax !== undefined) {
      taxAmount = fullSessionWithExpanded.total_details.amount_tax;
    }
    // 4. LOGIC TO FIND NET AMOUNT & FEES (Only runs for confirmed payments)
    if (paymentStatus === 'confirmed' && fullSessionWithExpanded.payment_intent && typeof fullSessionWithExpanded.payment_intent !== 'string') {
      const paymentIntent = fullSessionWithExpanded.payment_intent;
      // 🛠️ FIX 2: Use the correctly scoped variable and assign the ID
      stripePaymentIntentId = paymentIntent.id;
      // Use the latest_charge ID from the Payment Intent
      if (paymentIntent.latest_charge && typeof paymentIntent.latest_charge === 'string') {
        const chargeId = paymentIntent.latest_charge;
        try {
          const charge = await stripe.charges.retrieve(chargeId, {
            expand: [
              'balance_transaction'
            ]
          });
          if (charge.balance_transaction && typeof charge.balance_transaction !== 'string') {
            const balanceTransaction = charge.balance_transaction;
            grossAmount = balanceTransaction.amount;
            feeAmount = balanceTransaction.fee;
            netAmount = balanceTransaction.net;
            console.log(`[Fee/Net Success] Gross: ${grossAmount}, Fee: ${feeAmount}, Net: ${netAmount}`);
          } else {
            console.warn(`[Fee/Net Warning] Charge ${chargeId} missing Balance Transaction details (not expanded or missing).`);
          }
        } catch (chargeError) {
          console.error(`[Fee/Net Error] Failed to retrieve Charge: ${chargeError.message}`);
        }
      } else {
        console.warn('[Fee/Net Warning] Could not find latest_charge on Payment Intent.');
      }
    }
    // -------------------------
    // CRITICAL VALIDATION: Ensure we have the necessary IDs from the metadata
    if (!appEventId || !appUserId || memberIds.length === 0 || unitPrice <= 0) {
      console.error(`Received session ${session.id} missing required app IDs, member IDs, or unit price. Type: ${event.type}`);
      return new Response(JSON.stringify({
        error: 'Missing internal app IDs, member IDs, or unit price in metadata/payload'
      }), {
        status: 400
      });
    }
    // 5. Database UPSERT: Create or Update the payment record for EACH member
    // Calculate the per-member financial splits (assuming equal split for fees/net/tax)
    const totalMembers = memberIds.length;
    const feePerMember = Math.round(feeAmount / totalMembers);
    const netPerMember = Math.round(netAmount / totalMembers);
    const taxPerMember = Math.round(taxAmount / totalMembers);
    const grossPerMember = unitPrice; // This is the authoritative gross amount per member
    const insertData = memberIds.map((memberId)=>({
        payment_status: paymentStatus,
        event_id: appEventId,
        user_id: appUserId,
        member_id: memberId,
        // Fields for upsert/update
        stripe_session_id: session_id,
        // stripePaymentIntentId is now safely defined (null or ID)
        stripe_payment_intent_id: stripePaymentIntentId,
        amount_paid: grossPerMember,
        event_title: eventTitle,
        // FINANCIAL FIELDS (All in cents/smallest currency unit):
        fee_amount: feePerMember,
        net_amount: netPerMember,
        gross_amount: grossPerMember,
        tax_amount: taxPerMember
      }));
    // Perform the batch UPSERT into the new table
    const { error: dbError } = await supabase.from('event_user_member_payment').upsert(insertData, {
      onConflict: 'stripe_session_id, member_id'
    });
    if (dbError) {
      console.error('Database UPSERT failed:', dbError.message);
      return new Response(JSON.stringify({
        error: 'Database upsert failed'
      }), {
        status: 500
      });
    }
    // 6. Log the successful validation and database insertion/update
    console.log(`[DB UPSERT SUCCESS] ${logMessage}. Session ID: ${session_id}. Records created: ${totalMembers}.`);
    // 7. Return success to Stripe
    return new Response(JSON.stringify({
      received: true,
      status: 'validated and processed'
    }), {
      status: 200
    });
  } catch (error) {
    console.error('General Webhook Handler Error:', error.message);
    return new Response(JSON.stringify({
      error: 'Internal Server Error'
    }), {
      status: 500
    });
  }
});
