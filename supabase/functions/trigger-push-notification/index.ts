import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.4';
import { SignJWT, importPKCS8 } from 'https://esm.sh/jose@5.4.1';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
Deno.serve(async (req)=>{
  // Handle CORS pre-flight
  if (req.method === 'OPTIONS') return new Response('ok', {
    headers: corsHeaders
  });
  console.log("--- Webhook Triggered ---");
  try {
    const payload = await req.json();
    // Webhooks send the row data inside 'record'
    const record = payload.record;
    if (!record) {
      console.error("No record found in payload. Check Webhook configuration.");
      throw new Error('No record found');
    }
    const supabaseClient = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '');
    // 1. Fetch User FCM Token
    const { data: userData, error: userError } = await supabaseClient.from('users').select('fcm_token').eq('user_id', record.recipient_user_id).maybeSingle();
    if (userError || !userData?.fcm_token) {
      console.log(`FCM Token not found for user: ${record.recipient_user_id}`);
      return new Response(JSON.stringify({
        error: 'Token not found'
      }), {
        status: 200,
        headers: corsHeaders
      });
    }
    // 2. Dynamic Badge Count Logic
    const { count } = await supabaseClient.from('notifications').select('*', {
      count: 'exact',
      head: true
    }).eq('recipient_user_id', record.recipient_user_id).eq('is_read', false);
    const finalBadgeCount = count !== null ? count : 1;
    // 3. Firebase Authentication
    const saJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
    if (!saJson) throw new Error("FIREBASE_SERVICE_ACCOUNT secret is missing");
    const sa = JSON.parse(saJson);
    const pKey = sa.private_key.replace(/\\n/g, '\n');
    const importedKey = await importPKCS8(pKey, 'RS256');
    const jwt = await new SignJWT({
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + 3600
    }).setProtectedHeader({
      alg: 'RS256',
      typ: 'JWT'
    }).sign(importedKey);
    const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt
      })
    });
    const { access_token } = await tokenRes.json();
    // 4. Send FCM Message with Badge
    const fcmRes = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${access_token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        message: {
          token: userData.fcm_token,
          notification: {
            title: record.title || "New Notification",
            body: record.body || ""
          },
          apns: {
            payload: {
              aps: {
                badge: finalBadgeCount,
                sound: "default"
              }
            }
          },
          // Adding record data so the app knows which notification this is
          data: {
            notification_id: record.id?.toString() || "",
            link_page: record.link_page || ""
          }
        }
      })
    });
    const result = await fcmRes.json();
    console.log("FCM Success:", JSON.stringify(result));
    return new Response(JSON.stringify(result), {
      status: 200,
      headers: corsHeaders
    });
  } catch (err) {
    console.error("Edge Function Error:", err.message);
    return new Response(JSON.stringify({
      error: err.message
    }), {
      status: 500,
      headers: corsHeaders
    });
  }
});
