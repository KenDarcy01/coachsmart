import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.4';
import { SignJWT, importPKCS8 } from 'https://esm.sh/jose@5.4.1';
// 1. Define CORS headers to fix the 405 and pre-flight errors
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
Deno.serve(async (req)=>{
  // 2. Handle the OPTIONS request (Pre-flight check)
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders
    });
  }
  // 3. Only allow POST for actual processing
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({
      error: 'Method Not Allowed'
    }), {
      status: 405,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
  try {
    const payload = await req.json();
    // 4. Webhook Mapping: Supabase sends the new row inside 'record'
    // This looks for 'recipient_user_id' from your notifications table
    const record = payload.record;
    if (!record) {
      throw new Error('No record found in the request payload.');
    }
    const userId = record.recipient_user_id;
    const title = record.title;
    const body = record.body;
    const data = {
      link_page: record.link_page || "",
      notification_id: record.id?.toString() || ""
    };
    if (!userId || !title || !body) {
      return new Response(JSON.stringify({
        error: 'Missing required fields'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    const supabaseClient = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '');
    // 5. Fetch the User's FCM Token
    const { data: userData, error: userError } = await supabaseClient.from('users').select('fcm_token').eq('user_id', userId).maybeSingle();
    if (userError || !userData?.fcm_token) {
      // Returning 200 so the Webhook doesn't retry indefinitely if a user has no token
      return new Response(JSON.stringify({
        error: 'FCM token not found'
      }), {
        status: 200,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    // 6. Calculate the real badge count (unread notifications)
    const { count } = await supabaseClient.from('notifications').select('*', {
      count: 'exact',
      head: true
    }).eq('recipient_user_id', userId).eq('is_read', false);
    const finalBadgeCount = count !== null ? count : 1;
    // 7. Firebase Authentication
    const firebaseServiceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
    const serviceAccount = JSON.parse(firebaseServiceAccountJson || '{}');
    const privateKeyString = serviceAccount.private_key.replace(/\\n/g, '\n');
    const importedPrivateKey = await importPKCS8(privateKeyString, 'RS256');
    const now = Math.floor(Date.now() / 1000);
    const jwt = await new SignJWT({
      iss: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600
    }).setProtectedHeader({
      alg: 'RS256',
      typ: 'JWT'
    }).sign(importedPrivateKey);
    const accessTokenResponse = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt
      })
    });
    const { access_token } = await accessTokenResponse.json();
    // 8. Construct FCM Message
    const fcmMessage = {
      message: {
        token: userData.fcm_token,
        notification: {
          title,
          body
        },
        apns: {
          payload: {
            aps: {
              badge: finalBadgeCount,
              sound: "default"
            }
          }
        },
        data: data
      }
    };
    const fcmResponse = await fetch(`https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${access_token}`
      },
      body: JSON.stringify(fcmMessage)
    });
    const fcmResult = await fcmResponse.json();
    return new Response(JSON.stringify({
      success: true,
      fcm: fcmResult
    }), {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  } catch (error) {
    return new Response(JSON.stringify({
      error: error.message
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
});
