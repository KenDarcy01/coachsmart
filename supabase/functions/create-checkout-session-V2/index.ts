// Supabase Edge Function: create-checkout-session
// This function handles the secure communication with the Stripe API
// and logs the checkout attempt to the database for each member.
import { serve } from 'https://deno.land/std@0.208.0/http/server.ts';
import Stripe from 'https://esm.sh/stripe@13.11.0?no-dts&no-std';
// NOTE: Supabase client is no longer imported or initialized
// ----------------------------------------------------------------------
// ⚠️ ENVIRONMENT VARIABLE REQUIREMENTS
// This function now only requires:
// 1. 'STRIPE_SECRET_KEY'
// ----------------------------------------------------------------------
// Define CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
serve(async (req)=>{
  // CORS and Method Check
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: corsHeaders,
      status: 204
    });
  }
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
    stripe = new Stripe(stripeSecretKey, {
      apiVersion: '2023-10-16'
    });
    // 3. Receive and Parse Input
    const payload = await req.json();
    console.log('Received Payload:', payload);
    // Destructure payload including new fields
    const { appEventId, appUserId, productName, amount, appSuccessUrl, appCancelUrl, unitPrice, memberIds } = payload;
    // 4. Basic Input Validation
    if (!appEventId || !appUserId || !productName || !amount || !appSuccessUrl || !appCancelUrl || typeof appEventId !== 'number' || !Number.isInteger(appEventId) || typeof amount !== 'number' || !Number.isInteger(amount) || amount < 50 || typeof appSuccessUrl !== 'string' || typeof appCancelUrl !== 'string' || typeof unitPrice !== 'number' || !Number.isInteger(unitPrice) || unitPrice < 0 || !Array.isArray(memberIds) || memberIds.length === 0 || memberIds.some((id)=>typeof id !== 'number' || !Number.isInteger(id))) {
      return new Response(JSON.stringify({
        error: 'Missing or invalid required payload fields. Check appSuccessUrl, appCancelUrl, unitPrice (integer >= 0), and memberIds (non-empty array of integers).'
      }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders
        }
      });
    }
    // Determine the query separator for the success URL
    const successUrlSeparator = appSuccessUrl.includes('?') ? '&' : '?';
    // 5. Create the Stripe Checkout Session
    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      line_items: [
        {
          price_data: {
            currency: 'eur',
            product_data: {
              name: productName
            },
            unit_amount: amount
          },
          quantity: 1
        }
      ],
      // Metadata is CRITICAL for post-payment processing via webhook
      metadata: {
        app_event_id: String(appEventId),
        unit_price: String(unitPrice),
        member_ids: JSON.stringify(memberIds) // Array passed as JSON string
      },
      client_reference_id: appUserId,
      success_url: `${appSuccessUrl}${successUrlSeparator}stripeSessionId={CHECKOUT_SESSION_ID}`,
      cancel_url: appCancelUrl
    });
    console.log('Generated Checkout URL:', session.url);
    // 6. Database Insert Logic REMOVED - all payment logging is now handled by the webhook listener.
    // 7. Return the full Session URL to the client
    return new Response(JSON.stringify({
      checkoutUrl: session.url
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        ...corsHeaders
      }
    });
  } catch (error) {
    // General Error handling
    console.error('Execution error:', error.message);
    let errorMessage = 'Failed to create Checkout Session';
    if (error.message.includes('STRIPE_SECRET_KEY')) {
      errorMessage = 'Server configuration error: Stripe key is missing.';
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
  }
});
