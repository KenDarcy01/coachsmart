// Supabase Edge Function: create-checkout-session
// This function handles the secure communication with the Stripe API
// and logs the checkout attempt to the database.
import { serve } from 'https://deno.land/std@0.208.0/http/server.ts';
import Stripe from 'https://esm.sh/stripe@13.11.0?no-dts&no-std';
// NEW: Import the Supabase client
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
// ----------------------------------------------------------------------
// ⚠️ ENVIRONMENT VARIABLE REQUIREMENTS
// This function requires the following Supabase Secrets:
// 1. 'STRIPE_SECRET_KEY'
// 2. 'SUPABASE_URL' (Your project's URL)
// 3. 'SUPABASE_SERVICE_ROLE_KEY' (Your project's service_role key)
// ----------------------------------------------------------------------
// Define CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
serve(async (req)=>{
  // ... (CORS and Method Check remain the same) ...
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
  let supabaseClient;
  try {
    // 1. Initialize Stripe
    const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY');
    if (!stripeSecretKey) {
      throw new Error('STRIPE_SECRET_KEY environment variable is not set.');
    }
    stripe = new Stripe(stripeSecretKey, {
      apiVersion: '2023-10-16'
    });
    // 2. Initialize Supabase Client
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!supabaseUrl || !supabaseServiceRoleKey) {
      throw new Error('SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY environment variable is not set.');
    }
    supabaseClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
        detectSessionInUrl: false
      }
    });
    // 3. Receive and Parse Input
    const payload = await req.json();
    console.log('Received Payload:', payload);
    // 🚨 UPDATED: appBaseUrl removed, replaced by appSuccessUrl and appCancelUrl 
    const { appEventId, appUserId, productName, amount, appSuccessUrl, appCancelUrl } = payload;
    // 4. Basic Input Validation
    // 🚨 UPDATED: Validation check for the new URL fields
    if (!appEventId || !appUserId || !productName || !amount || !appSuccessUrl || !appCancelUrl || typeof appEventId !== 'number' || !Number.isInteger(appEventId) || typeof amount !== 'number' || !Number.isInteger(amount) || amount < 50 || typeof appSuccessUrl !== 'string' || typeof appCancelUrl !== 'string') {
      return new Response(JSON.stringify({
        error: 'Missing or invalid required payload fields (appSuccessUrl and appCancelUrl are now required).'
      }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders
        }
      });
    }
    // Determine the query separator for the success URL (in case it already has parameters)
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
      metadata: {
        app_event_id: String(appEventId)
      },
      client_reference_id: appUserId,
      // 🚨 UPDATED: Use the specific URLs passed in the payload
      success_url: `${appSuccessUrl}${successUrlSeparator}stripeSessionId={CHECKOUT_SESSION_ID}`,
      cancel_url: appCancelUrl
    });
    console.log('Generated Checkout URL:', session.url);
    // 6. Create a record in your database
    // Target table: public.event_user_payment
    const { error: dbError } = await supabaseClient.from('event_user_payment') // <-- Confirmed table name
    .insert({
      event_id: appEventId,
      user_id: appUserId,
      event_title: productName,
      amount_paid: amount,
      stripe_session_id: session.id,
      stripe_checkout_url: session.url // Mapped: session.url -> stripe_checkout_url
    });
    if (dbError) {
      // 🚨 CRITICAL DEBUGGING STEP 🚨: Log the full error object
      console.error('Database insertion error (FULL OBJECT):', JSON.stringify(dbError, null, 2));
      // Log the message as well, just in case
      console.error('Database insertion error (Message):', dbError.message);
    // The function continues to return the Stripe URL even if the DB insert fails.
    }
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
    if (error.message.includes('STRIPE_SECRET_KEY') || error.message.includes('SUPABASE_')) {
      errorMessage = 'Server configuration error: A required key is missing.';
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
