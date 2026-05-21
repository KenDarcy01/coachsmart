import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.4';
import { SignJWT, importPKCS8 } from 'https://esm.sh/jose@5.4.1';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
Deno.serve(async (req)=>{
  if (req.method === 'OPTIONS') return new Response('ok', {
    headers: corsHeaders
  });
  console.log("🚀 --- BATCH PUSH START (Smart Summary Mode) ---");
  try {
    const supabaseClient = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '');
    // 1. Fetch notifications that haven't been delivered yet
    const { data: unsentNotifications, error: fetchError } = await supabaseClient.from('notifications').select('*').eq('is_delivered', false).limit(200);
    if (fetchError) {
      console.error("❌ Database Fetch Error:", fetchError);
      throw fetchError;
    }
    if (!unsentNotifications || unsentNotifications.length === 0) {
      console.log("Zero notifications to process.");
      return new Response(JSON.stringify({
        message: 'Zero notifications to process'
      }), {
        headers: corsHeaders
      });
    }
    // 2. Group by user
    const userGroups = unsentNotifications.reduce((acc, note)=>{
      const uid = note.recipient_user_id;
      if (!acc[uid]) acc[uid] = [];
      acc[uid].push(note);
      return acc;
    }, {});
    const userIds = Object.keys(userGroups);
    // 3. Get FCM tokens
    const { data: users, error: userError } = await supabaseClient.from('users').select('user_id, fcm_token').in('user_id', userIds);
    if (userError) throw userError;
    // 4. Firebase Auth Setup
    const saJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
    if (!saJson) throw new Error("Missing FIREBASE_SERVICE_ACCOUNT secret");
    const sa = JSON.parse(saJson);
    const importedKey = await importPKCS8(sa.private_key.replace(/\\n/g, '\n'), 'RS256');
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
    // 5. Send Loop with Batch Logic
    await Promise.all(users.map(async (user)=>{
      if (!user.fcm_token) return;
      // Get accurate badge count for the app icon
      const { count: liveUnreadCount } = await supabaseClient.from('notifications').select('*', {
        count: 'exact',
        head: true
      }).eq('recipient_user_id', user.user_id).eq('is_read', false);
      const userNotes = userGroups[user.user_id];
      const latestNote = userNotes[userNotes.length - 1];
      const isBatch = userNotes.length > 1;
      // AMENDMENT: Conditional Notification Payload
      // If > 1 message, Title only. If 1 message, Title + Body.
      const notificationPayload = isBatch ? {
        title: `You have ${userNotes.length} new updates`
      } : {
        title: latestNote.title,
        body: latestNote.body
      };
      const fcmResponse = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${access_token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          message: {
            token: user.fcm_token,
            notification: notificationPayload,
            apns: {
              payload: {
                aps: {
                  badge: liveUnreadCount ?? 0,
                  sound: "default",
                  "content-available": 1
                }
              }
            },
            data: {
              link_page: latestNote.link_page || "",
              is_batch: isBatch.toString()
            }
          }
        })
      });
      if (!fcmResponse.ok) {
        console.error(`❌ FCM Error for ${user.user_id}:`, await fcmResponse.text());
      }
    }));
    // 6. Mark as Delivered
    const processedIds = unsentNotifications.map((n)=>n.id);
    await supabaseClient.from('notifications').update({
      is_delivered: true
    }).in('id', processedIds);
    console.log("🏁 --- BATCH PUSH COMPLETE ---");
    return new Response(JSON.stringify({
      status: 'Done',
      processed: processedIds.length
    }), {
      headers: corsHeaders
    });
  } catch (err) {
    console.error("🚨 CRITICAL ERROR:", err.message);
    return new Response(JSON.stringify({
      error: err.message
    }), {
      status: 500,
      headers: corsHeaders
    });
  }
});
