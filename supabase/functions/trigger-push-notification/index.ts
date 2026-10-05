import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.4';
import { SignJWT, importPKCS8 } from 'https://esm.sh/jose@5.4.1';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
Deno.serve(async (req)=>{
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  console.log("--- Webhook Triggered ---");
  try {
    const payload = await req.json();
    const record = payload.record;
    if (!record) {
      console.error("No record found in payload.");
      throw new Error('No record found');
    }

    // Skip if not a push notification or already delivered
    if (record.delivery_method === 'email') {
      console.log(`Skipping email-only notification ${record.id}`);
      return new Response(JSON.stringify({ skipped: 'email' }), { status: 200, headers: corsHeaders });
    }
    if (record.is_delivered === true) {
      console.log(`Notification ${record.id} already delivered — skipping`);
      return new Response(JSON.stringify({ skipped: 'already_delivered' }), { status: 200, headers: corsHeaders });
    }

    const supabaseClient = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '');

    // 1. Fetch User FCM Token
    const { data: userData, error: userError } = await supabaseClient
      .from('users')
      .select('fcm_token')
      .eq('user_id', record.recipient_user_id)
      .maybeSingle();
    if (userError || !userData?.fcm_token) {
      console.log(`FCM Token not found for user: ${record.recipient_user_id}`);
      return new Response(JSON.stringify({ error: 'Token not found' }), { status: 200, headers: corsHeaders });
    }

    // 2. Badge count (unread notifications for this user)
    const { count } = await supabaseClient
      .from('notifications')
      .select('*', { count: 'exact', head: true })
      .eq('recipient_user_id', record.recipient_user_id)
      .eq('is_read', false);
    const finalBadgeCount = count !== null ? count : 1;

    // 3. Firebase Auth
    const saJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
    if (!saJson) throw new Error("FIREBASE_SERVICE_ACCOUNT secret is missing");
    const sa = JSON.parse(saJson);
    const importedKey = await importPKCS8(sa.private_key.replace(/\\n/g, '\n'), 'RS256');
    const jwt = await new SignJWT({
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + 3600
    }).setProtectedHeader({ alg: 'RS256', typ: 'JWT' }).sign(importedKey);
    const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt
      })
    });
    const { access_token } = await tokenRes.json();

    // 4. Build FCM message (title/body from push_title/push_body columns)
    const notifTitle = record.push_title || record.app_title || 'CoachSmart';
    const notifBody  = record.push_body  || record.app_body  || '';

    // Parse eventID from link_page for FlutterFlow deep-link routing
    const nativeLinkPage = record.link_page ?? '';
    const eventIdMatch = nativeLinkPage.match(/eventID=(\d+)/);
    const eventId = eventIdMatch ? eventIdMatch[1] : '';

    const fcmRes = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${access_token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: {
          token: userData.fcm_token,
          notification: { title: notifTitle, body: notifBody },
          data: {
            initialPageName: 'EventDetails',
            parameterData: JSON.stringify({ eventID: eventId, fromSearch: 'false' }),
            notification_id: record.id?.toString() || '',
            link_page: nativeLinkPage
          },
          apns: {
            payload: {
              aps: {
                alert: { title: notifTitle, body: notifBody },
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
            notification: {
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
              sound: 'default'
            }
          }
        }
      })
    });
    const result = await fcmRes.json();
    console.log("FCM result:", JSON.stringify(result));

    if (fcmRes.ok) {
      // Mark delivered so the cron doesn't re-process this row
      await supabaseClient
        .from('notifications')
        .update({ is_delivered: true })
        .eq('id', record.id);
      console.log(`✅ Delivered and marked is_delivered=true for notification ${record.id}`);
    } else {
      console.error(`❌ FCM error for notification ${record.id}:`, result.error?.message);
    }

    return new Response(JSON.stringify(result), { status: 200, headers: corsHeaders });
  } catch (err) {
    console.error("Edge Function Error:", err.message);
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: corsHeaders });
  }
});
