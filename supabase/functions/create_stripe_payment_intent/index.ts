import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.10.0";
import Stripe from "https://esm.sh/stripe@17.2.0?target=es2020";
// --- START: INITIALIZATION AND ENVIRONMENT CHECK ---
const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY");
if (!STRIPE_SECRET_KEY) {
  throw new Error("STRIPE_SECRET_KEY environment variable is not set.");
}
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
if (!SUPABASE_URL) {
  throw new Error("SUPABASE_URL environment variable is not set.");
}
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
if (!SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error("SUPABASE_SERVICE_ROLE_KEY environment variable is not set.");
}
// Initialize Stripe client
const stripe = new Stripe(STRIPE_SECRET_KEY, {
  apiVersion: "2023-10-16"
});
// Initialize Supabase Admin client
const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
console.log("[INIT] Function initialization complete. Ready to serve requests.");
// --- END: INITIALIZATION AND ENVIRONMENT CHECK ---
/**
 * Helper to handle CORS preflight OPTIONS requests.
 */ function handleCors(req) {
  const headers = new Headers({
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"
  });
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers
    });
  }
  headers.set("Access-Control-Allow-Origin", "*");
  return headers;
}
serve(async (req)=>{
  // CRITICAL LOGGING: Immediately log that the function handler was executed.
  console.log(`[HIT] Request received. Method: ${req.method}`);
  const headers = handleCors(req);
  // 1. Handle CORS Preflight Request
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers
    });
  }
  // 2. Main Logic: Only proceed for POST requests
  if (req.method !== "POST") {
    return new Response(JSON.stringify({
      error: "Method not allowed. Use POST."
    }), {
      status: 405,
      headers
    });
  }
  let body;
  try {
    // Attempt to parse the body as JSON
    body = await req.json();
    console.log("[PARSE] Body successfully parsed as JSON.");
  } catch (parseError) {
    console.error("[CRITICAL] Failed to parse request body as JSON or body was malformed:", parseError);
    return new Response(JSON.stringify({
      error: "Invalid JSON body provided. Ensure Content-Type: application/json is set."
    }), {
      status: 400,
      headers: {
        ...headers,
        "Content-Type": "application/json"
      }
    });
  }
  try {
    // Destructure body after successful parsing
    const { amount, currency, appEventId, appUserId, productName } = body;
    // --- INPUT VALIDATION & TYPE CHECKING ---
    if (!amount || typeof amount !== 'number' || !Number.isInteger(amount) || amount <= 0) {
      return new Response(JSON.stringify({
        error: "Invalid 'amount'. Must be a positive integer in cents."
      }), {
        status: 400,
        headers
      });
    }
    if (!currency || typeof currency !== 'string' || currency.length !== 3) {
      return new Response(JSON.stringify({
        error: "Invalid 'currency'. Must be a 3-letter string."
      }), {
        status: 400,
        headers
      });
    }
    // Assume appEventId and appUserId are strings (TEXT/VARCHAR)
    if (!appEventId || typeof appEventId !== 'string' || !appUserId || typeof appUserId !== 'string' || !productName || typeof productName !== 'string') {
      return new Response(JSON.stringify({
        error: "Missing or invalid required string parameters (appEventId, appUserId, productName)."
      }), {
        status: 400,
        headers
      });
    }
    // --- END INPUT VALIDATION ---
    // LOGGING: 1. Log received parameters
    console.log(`[REQUEST] Received payment request for Event ID: ${appEventId}, User ID: ${appUserId}, Amount: ${amount} ${currency}`);
    // 3. Create a unique payment record (status: pending) in event_user_payment
    const { data: booking, error: bookingError } = await supabaseAdmin.from('event_user_payment').insert({
      event_id: appEventId,
      user_id: appUserId,
      amount_paid: amount,
      payment_status: 'pending' // Initial status
    }).select() // We MUST select the row back to get the auto-generated ID
    .single();
    if (bookingError) {
      console.error("Supabase Payment Record Creation Error:", bookingError);
      return new Response(JSON.stringify({
        error: `Database error: Failed to create pending payment record. Detail: ${bookingError.message}`
      }), {
        status: 500,
        headers
      });
    }
    // CRITICAL DEFENSIVE CHECK: Ensure the inserted row object and its ID are available
    // FIX: Checking for 'payment_id' as confirmed by the user, instead of 'id'.
    if (!booking || !booking.payment_id) {
      console.error("Supabase Payment Record Creation Error: Insert returned no data or missing payment_id. CHECK TABLE SCHEMA: Ensure the 'payment_id' column is the PRIMARY KEY and is set to GENERATE an ID (e.g., identity or gen_random_uuid()).");
      return new Response(// Since the insert appears to have worked (based on your prior log), but no ID was returned, 
      // we stop here and throw a 500. This is almost always a schema issue preventing the ID from being returned.
      JSON.stringify({
        error: `Database error: Insert returned no payment_id in the response. Check 'payment_id' column configuration.`
      }), {
        status: 500,
        headers
      });
    }
    // Use the ID directly, coercing it to string for Stripe metadata later
    const bookingId = booking.payment_id; // FIX: Use the actual primary key property: payment_id
    console.log(`[SUPABASE] Successfully created pending booking record with ID: ${bookingId}`);
    // 4. Create Stripe Payment Intent
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount,
      currency: currency,
      automatic_payment_methods: {
        enabled: true
      },
      // IMPORTANT: Use metadata to attach the Supabase booking ID for webhook tracking
      metadata: {
        booking_id: String(bookingId),
        app_event_id: appEventId,
        user_id: appUserId,
        product_name: productName
      }
    });
    if (!paymentIntent.client_secret) {
      throw new Error("Stripe failed to return client_secret.");
    }
    console.log(`[STRIPE] Successfully created Payment Intent ID: ${paymentIntent.id}. Booking ID attached: ${bookingId}`);
    // 5. Update the payment record with the Payment Intent ID
    const { error: updateError } = await supabaseAdmin.from('event_user_payment').update({
      stripe_payment_intent_id: paymentIntent.id
    })// FIX: The query must filter by the correct primary key column: 'payment_id'
    .eq('payment_id', bookingId);
    if (updateError) {
      console.error("Supabase Payment Record Update Error (Non-critical):", updateError);
    } else {
      console.log(`[SUPABASE] Successfully updated booking ID ${bookingId} with PI ID: ${paymentIntent.id}`);
    }
    // 6. Return the client_secret to the Flutter app
    console.log(`[RESPONSE] Returning client_secret for PI ID: ${paymentIntent.id}. Status 200.`);
    return new Response(JSON.stringify({
      client_secret: paymentIntent.client_secret
    }), {
      status: 200,
      headers: {
        ...headers,
        "Content-Type": "application/json"
      }
    });
  } catch (error) {
    console.error("Function Error (Caught in main try/catch):", error.message);
    return new Response(JSON.stringify({
      error: error.message
    }), {
      status: 500,
      headers: {
        ...headers,
        "Content-Type": "application/json"
      }
    });
  }
});
