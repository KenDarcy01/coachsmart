import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.4';
import { SignJWT, importPKCS8 } from 'https://esm.sh/jose@5.4.1';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
Deno.serve(async (req)=>{
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method Not Allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
  try {
    const payload = await req.json();
    const record = payload.record;
    if (!record) throw new Error('No record found in the request payload.');

    const userId = record.recipient_user_id;

    // Skip email-only or already-delivered rows
    if (record.delivery_method === 'email') {
      return new Response(JSON.stringify({ skipped: 'email' }), { status: 200, headers: corsHeaders });
    }
    if (record.is_delivered === true) {
      return new Response(JSON.stringify({ skipped: 'already_delivered' }), { status: 200, headers: corsHeaders });
    }

    // Use push_title/push_body (not the legacy title/body columns which don't exist)
    const title = record.push_title || record.app_title;
    const body  = record.push_body  || record.app_body  || '';

    if (!userId || !title) {
      return new Response(JSON.stringify({ error: 'Missing required fields' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    const supabaseClient = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '');

    // Fetch FCM token
    const { data: userData, error: userError } = await supabaseClient
      .from('users').select('fcm_token').eq('user_id', userId).maybeSingle();
    if (userError || !userData?.fcm_token) {
      return new Response(JSON.stringify({ error: 'FCM token not found' }), { status: 200, headers: corsHeaders });
    }

    // Badge count
    const { count } = await supabaseClient
      .from('notifications').select('*', { count: 'exact', head: true })
      .eq('recipient_user_id', userId).eq('is_read', false);
    const finalBadgeCount = count !== null ? count : 1;

    // Firebase Auth
    const firebaseServiceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
    if (!firebaseServiceAccountJson) throw new Error('FIREBASE_SERVICE_ACCOUNT secret is missing');
    const serviceAccount = JSON.parse(firebaseServiceAccountJson);
    const importedPrivateKey = await importPKCS8(serviceAccount.private_key.replace(/\\n/g, '\n'), 'RS256');
    const now = Math.floor(Date.now() / 1000);
    const jwt = await new SignJWT({
      iss: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600
    }).setProtectedHeader({ alg: 'RS256', typ: 'JWT' }).sign(importedPrivateKey);

    const accessTokenResponse = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: jwt })
    });
    const { access_token } = await accessTokenResponse.json();

    // Deep-link data
    const nativeLinkPage = record.link_page ?? '';
    const eventIdMatch = nativeLinkPage.match(/eventID=(\d+)/);
    const eventId = eventIdMatch ? eventIdMatch[1] : '';

    const fcmResponse = await fetch(`https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${access_token}` },
      body: JSON.stringify({
        message: {
          token: userData.fcm_token,
          notification: { title, body },
          data: {
            initialPageName: 'EventDetails',
            parameterData: JSON.stringify({ eventID: eventId, fromSearch: 'false' }),
            notification_id: record.id?.toString() || '',
            link_page: nativeLinkPage
          },
          apns: {
            payload: {
              aps: {
                alert: { title, body },
                sound: 'default',
                badge: finalBadgeCount,
                'content-available': 1,
                'mutable-content': 1,
                category: 'FLUTTER_NOTIFICATION_CLICK'
              }
            },
            headers: { 'apns-priority': '10', 'apns-push-type': 'alert' }
          },
          android: {
            priority: 'high',
            notification: { click_action: 'FLUTTER_NOTIFICATION_CLICK', sound: 'default' }
          }
        }
      })
    });
    const fcmResult = await fcmResponse.json();

    if (fcmResponse.ok) {
      await supabaseClient.from('notifications').update({ is_delivered: true }).eq('id', record.id);
    }

    return new Response(JSON.stringify({ success: true, fcm: fcmResult }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});
