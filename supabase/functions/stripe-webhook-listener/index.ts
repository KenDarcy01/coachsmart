// Supabase Edge Function: stripe-webhook-listener
// This function receives and validates webhooks from Stripe and extracts metadata,
// then UPSERTS a new payment record for tracking payment status history, including full details,
// including fees, net amount, and tax amount.
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
  const WEBHOOK_SECRET = Deno.env.get('STRIPE_WEBHOOK_SECRET');
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
      // Using constructEventAsync for Deno compatibility and robust signature check
      event = await stripe.webhooks.constructEventAsync(body, signature, WEBHOOK_SECRET);
    } catch (err) {
      // Invalid signature
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
    // Initialize financial tracking variables (use session's total as the initial gross amount)
    let grossAmount = session.amount_total;
    let feeAmount = 0;
    let netAmount = session.amount_total;
    let taxAmount = 0; // Initialize tax amount
    switch(event.type){
      // --- SUCCESS EVENTS ---
      case 'checkout.session.completed':
      case 'checkout.session.async_payment_succeeded':
        paymentStatus = 'confirmed';
        logMessage = 'Payment successful/succeeded. Payment confirmed.';
        break;
      // --- FAILURE/EXPIRATION EVENTS ---
      case 'checkout.session.expired':
      case 'checkout.session.async_payment_failed':
        paymentStatus = event.type === 'checkout.session.expired' ? 'expired' : 'failed';
        logMessage = `Payment status updated to ${paymentStatus}.`;
        break;
      default:
        // Ignore all other events
        console.log(`Ignoring event type: ${event.type}`);
        return new Response(JSON.stringify({
          received: true,
          ignored: true
        }), {
          status: 200
        });
    }
    // --- Logic Common to All Handled Events (Processing) ---
    // CRITICAL: Expand both 'line_items' AND 'payment_intent' for full data retrieval
    const fullSession = await stripe.checkout.sessions.retrieve(session.id, {
      expand: [
        'line_items',
        'payment_intent'
      ]
    });
    // Safely cast fullSession to include expanded objects
    const fullSessionWithExpanded = fullSession;
    const appEventId = fullSession.metadata?.app_event_id;
    const appUserId = fullSession.client_reference_id;
    // --- DATA EXTRACTION ---
    const session_id = fullSession.id;
    let eventTitle = null;
    // 1. Extract Event Title
    if (fullSessionWithExpanded.line_items && fullSessionWithExpanded.line_items.data && fullSessionWithExpanded.line_items.data.length > 0) {
      eventTitle = fullSessionWithExpanded.line_items.data[0].description;
    }
    // 2. Extract Total Tax Amount
    if (fullSessionWithExpanded.total_details && fullSessionWithExpanded.total_details.amount_tax !== undefined) {
      taxAmount = fullSessionWithExpanded.total_details.amount_tax;
    }
    // 3. LOGIC TO FIND NET AMOUNT & FEES (Only runs for confirmed payments)
    if (paymentStatus === 'confirmed' && fullSessionWithExpanded.payment_intent && typeof fullSessionWithExpanded.payment_intent !== 'string') {
      const paymentIntent = fullSessionWithExpanded.payment_intent;
      // Use the latest_charge ID from the Payment Intent
      if (paymentIntent.latest_charge && typeof paymentIntent.latest_charge === 'string') {
        const chargeId = paymentIntent.latest_charge;
        try {
          // a. Retrieve the Charge object, EXPANDING the Balance Transaction
          // This replaces the second API call and avoids the 'retrieve' error on stripe.balance.transactions
          const charge = await stripe.charges.retrieve(chargeId, {
            expand: [
              'balance_transaction'
            ]
          });
          // b. Check if the balance_transaction was successfully expanded into an object
          if (charge.balance_transaction && typeof charge.balance_transaction !== 'string') {
            const balanceTransaction = charge.balance_transaction;
            // c. Update the financial tracking variables
            grossAmount = balanceTransaction.amount; // Total customer paid (Authoritative Gross)
            feeAmount = balanceTransaction.fee;
            netAmount = balanceTransaction.net; // The amount after fees
            console.log(`[Fee/Net Success] Gross: ${grossAmount}, Fee: ${feeAmount}, Net: ${netAmount}`);
          } else {
            console.warn(`[Fee/Net Warning] Charge ${chargeId} missing Balance Transaction details (not expanded or missing).`);
          }
        } catch (chargeError) {
          // Error should now be "Failed to retrieve Charge" (top-level resource)
          console.error(`[Fee/Net Error] Failed to retrieve Charge: ${chargeError.message}`);
        // Continue execution with amount_total from session and null/zero fees
        }
      } else {
        console.warn('[Fee/Net Warning] Could not find latest_charge on Payment Intent.');
      }
    }
    // -------------------------
    // CRITICAL VALIDATION: Ensure we have the necessary IDs from the metadata
    if (!appEventId || !appUserId) {
      console.error(`Received session ${session.id} missing app IDs. Type: ${event.type}`);
      return new Response(JSON.stringify({
        error: 'Missing internal app IDs in metadata'
      }), {
        status: 400
      });
    }
    // 4. Database UPSERT: Create or Update the payment record
    const { error: dbError } = await supabase.from('event_user_payment').upsert({
      payment_status: paymentStatus,
      event_id: appEventId,
      user_id: appUserId,
      // Fields for upsert/update
      stripe_session_id: session_id,
      amount_paid: grossAmount,
      event_title: eventTitle,
      // FINANCIAL FIELDS (All in cents/smallest currency unit):
      fee_amount: feeAmount,
      net_amount: netAmount,
      gross_amount: grossAmount,
      tax_amount: taxAmount // TAX FIELD
    }, {
      onConflict: 'stripe_session_id' // Specify the column with the unique constraint
    });
    if (dbError) {
      console.error('Database UPSERT failed:', dbError.message);
      // Return 500 status code to signal Stripe to retry the webhook
      return new Response(JSON.stringify({
        error: 'Database upsert failed'
      }), {
        status: 500
      });
    }
    // 5. Log the successful validation and database insertion/update
    console.log(`[DB UPSERT SUCCESS] ${logMessage}. Session ID: ${session_id}. Gross: ${grossAmount}, Net: ${netAmount}, Tax: ${taxAmount}.`);
    // 6. Return success to Stripe
    return new Response(JSON.stringify({
      received: true,
      status: 'validated and processed'
    }), {
      status: 200
    });
  } catch (error) {
    console.error('General Webhook Handler Error:', error.message);
    // Return 500 status code to signal Stripe to retry the webhook
    return new Response(JSON.stringify({
      error: 'Internal Server Error'
    }), {
      status: 500
    });
  }
});
