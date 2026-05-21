// Supabase Edge Function: get-checkout-session-details
// This function securely fetches the details of a Stripe Checkout Session
// using the session ID provided by the client after a successful payment.
import { serve } from 'https://deno.land/std@0.208.0/http/server.ts';
import Stripe from 'https://esm.sh/stripe@13.11.0?no-dts&no-std';
// ----------------------------------------------------------------------
// ⚠️ ENVIRONMENT VARIABLE REQUIREMENTS
// This function requires the following Supabase Secret:
// 1. 'STRIPE_SECRET_KEY'
// ----------------------------------------------------------------------
// Define CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
serve(async (req)=>{
  console.log('--- Starting get-checkout-session-details execution ---'); // LOG START
  // Handle CORS preflight request
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: corsHeaders,
      status: 204
    });
  }
  // Enforce POST method
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({
      error: 'Method not allowed'
    }), {
      status: 405,
      headers: {
        'Content-Type': 'application/json',
        ...corsHeaders
      }
    });
  }
  let stripe;
  try {
    // 1. Initialize Stripe
    const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY');
    if (!stripeSecretKey) {
      throw new Error('STRIPE_SECRET_KEY environment variable is not set.');
    }
    console.log('Step 1: Stripe initialized successfully.'); // LOG 1
    stripe = new Stripe(stripeSecretKey, {
      apiVersion: '2023-10-16'
    });
    // 2. Receive and Parse Input
    const payload = await req.json();
    const { sessionId } = payload;
    console.log(`Step 2: Received payload. Session ID to check: ${sessionId}`); // LOG 2
    // 3. Basic Input Validation
    if (!sessionId || typeof sessionId !== 'string' || sessionId.trim() === '') {
      console.error('Step 3: Validation Failed. Missing or invalid sessionId.');
      return new Response(JSON.stringify({
        error: 'Missing or invalid required payload field: sessionId.'
      }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders
        }
      });
    }
    // 4. Retrieve the Stripe Checkout Session
    // We expand 'line_items' and 'payment_intent' to get full transaction details
    const session = await stripe.checkout.sessions.retrieve(sessionId, {
      expand: [
        'line_items',
        'payment_intent'
      ]
    });
    console.log(`Step 4: Stripe Session Retrieved. Status: ${session.payment_status}`); // LOG 4
    // 5. Check if the session was successful
    if (session.payment_status !== 'paid') {
      console.warn(`Step 5: Payment status is NOT 'paid'. Actual status: ${session.payment_status}`);
      return new Response(JSON.stringify({
        error: 'Payment not successful for this session.',
        payment_status: session.payment_status,
        session_id: session.id
      }), {
        status: 402,
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders
        }
      });
    }
    console.log('Step 5: Payment status confirmed as "paid". Proceeding to extract details.'); // LOG 5
    // 6. Extract key details to return to the client
    const sessionDetails = {
      sessionId: session.id,
      paymentStatus: session.payment_status,
      amountTotal: session.amount_total,
      currency: session.currency,
      customerId: session.customer,
      clientReferenceId: session.client_reference_id,
      appEventId: session.metadata?.app_event_id,
      // Line Items: Extract product name and amount from the line item
      product: session.line_items?.data?.[0]?.description,
      // Payment Intent ID
      paymentIntentId: typeof session.payment_intent === 'string' ? session.payment_intent : session.payment_intent?.id
    };
    // 7. Return session details
    console.log('Step 7: Successfully returning session details to client.'); // LOG 7
    return new Response(JSON.stringify(sessionDetails), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        ...corsHeaders
      }
    });
  } catch (error) {
    // General Error handling
    console.error('Execution error:', error.message);
    let errorMessage = 'Failed to retrieve Checkout Session details.';
    if (error.message.includes('No such checkout.session')) {
      errorMessage = 'Invalid or non-existent session ID.';
      console.error('Error Type: 404 - Session Not Found.');
      return new Response(JSON.stringify({
        error: errorMessage,
        details: error.message
      }), {
        status: 404,
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders
        }
      });
    }
    return new Response(JSON.stringify({
      error: errorMessage,
      details: error.message
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        ...corsHeaders
      }
    });
  } finally{
    console.log('--- get-checkout-session-details execution finished ---'); // LOG END
  }
});
