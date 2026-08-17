import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.44.0';
import { Resend } from 'https://esm.sh/resend@3.2.0';
import { SignJWT, importPKCS8 } from 'https://esm.sh/jose@5.4.1';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
Deno.serve(async (req)=>{
  if (req.method === 'OPTIONS') return new Response('ok', {
    headers: corsHeaders
  });
  const supabaseClient = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '');
  const resend = new Resend(Deno.env.get('RESEND_API_KEY'));
  try {
    console.log('🚀 Starting Notification Job...');
    const { data: notifications, error: fetchError } = await supabaseClient.from('notifications').select('*, users:recipient_user_id(user_id, email_address, fcm_token, first_name)').eq('is_delivered', false).limit(100);
    if (fetchError) throw new Error(`Database Fetch Error: ${fetchError.message}`);
    if (!notifications?.length) {
      console.log('⚪ No pending notifications found.');
      return new Response(JSON.stringify({
        message: 'Nothing to process'
      }), {
        headers: corsHeaders
      });
    }
    console.log(`📬 Found ${notifications.length} notification(s) to process`);
    let pushNotes = notifications.filter((n)=>n.delivery_method === 'push');
    let emailNotes = notifications.filter((n)=>n.delivery_method === 'email');
    const processedIds = [];
    const emailDeliveredIds = [];
    const deadTokens = [];
    // -------------------------------------------------------------------------
    // SECTION A: PUSH NOTIFICATIONS (FCM + APNS)
    // -------------------------------------------------------------------------
    if (pushNotes.length > 0) {
      const saJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
      const sa = JSON.parse(saJson);
      const accessToken = await getFcmAccessToken(sa);
      const userPushGroups = groupBy(pushNotes, 'recipient_user_id');

      // Pre-fetch true unread counts so the APNS badge reflects total DB unread, not just batch size
      const pushUserIds = Object.keys(userPushGroups);
      const { data: unreadRows } = await supabaseClient
        .from('notifications')
        .select('recipient_user_id')
        .in('recipient_user_id', pushUserIds)
        .eq('is_read', false);
      const unreadCountMap: Record<string, number> = {};
      (unreadRows || []).forEach((row) => {
        unreadCountMap[row.recipient_user_id] = (unreadCountMap[row.recipient_user_id] || 0) + 1;
      });

      await Promise.all(Object.entries(userPushGroups).map(async ([userId, notes])=>{
        const user = notes[0].users;
        if (!user?.fcm_token) {
          console.warn(`⚠️ No FCM token for ${user?.email_address || userId} — failing over to email`);
          emailNotes.push(...notes);
          return;
        }
        const isBatch = notes.length > 1;
        const displayTitle = notes[0].push_title;
        const displayBody = isBatch ? `You have ${notes.length} new updates from ${notes[0].push_title}.` : notes[0].push_body;
        const latestNote = notes[0];
        const nativeLinkPage = latestNote.link_page ?? '';
        // Parse eventID from link_page for FlutterFlow's parameterData
        const eventIdMatch = nativeLinkPage.match(/eventID=(\d+)/);
        const eventId = eventIdMatch ? eventIdMatch[1] : '';
        console.log(`📱 Native link: ${nativeLinkPage} | eventId: ${eventId}`);
        try {
          const fcmMessage = {
            message: {
              token: user.fcm_token,
              notification: {
                title: displayTitle,
                body: displayBody
              },
              data: {
                // FlutterFlow's own deep link format.
                // On cold start FlutterFlow reads these fields during
                // initialisation and navigates directly to EventDetails
                // bypassing the auth redirect to HomePage.
                initialPageName: 'EventDetails',
                parameterData: JSON.stringify({
                  eventID: eventId,
                  fromSearch: 'false'
                }),
                // Our fields — used by onMessageOpenedApp for backgrounded
                // tap and by the banner tap handler
                notification_id: latestNote.id.toString(),
                link_page: nativeLinkPage
              },
              apns: {
                payload: {
                  aps: {
                    alert: {
                      title: displayTitle,
                      body: displayBody
                    },
                    sound: 'default',
                    badge: unreadCountMap[userId] ?? notes.length,
                    'content-available': 1,
                    'mutable-content': 1,
                    // FlutterFlow uses this category for iOS cold start routing
                    category: 'FLUTTER_NOTIFICATION_CLICK'
                  }
                },
                headers: {
                  'apns-priority': '10',
                  'apns-push-type': 'alert'
                }
              },
              android: {
                priority: 'high',
                notification: {
                  click_action: 'FLUTTER_NOTIFICATION_CLICK',
                  sound: 'default'
                }
              }
            }
          };
          const res = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
            method: 'POST',
            headers: {
              Authorization: `Bearer ${accessToken}`,
              'Content-Type': 'application/json'
            },
            body: JSON.stringify(fcmMessage)
          });
          const resultJson = await res.json();
          if (res.ok) {
            console.log(`✅ Push delivered to: ${user.email_address} | notification_id=${latestNote.id} | eventId=${eventId}`);
            notes.forEach((n)=>processedIds.push(n.id));
          } else {
            console.error(`❌ FCM Error for ${user.email_address}:`, resultJson.error?.message);
            if (resultJson.error?.status === 'UNREGISTERED' || resultJson.error?.status === 'NOT_FOUND') {
              deadTokens.push(user.user_id);
            }
            emailNotes.push(...notes);
          }
        } catch (e) {
          console.error(`🚨 Network error for FCM:`, e.message);
          emailNotes.push(...notes);
        }
      }));
    }
    // -------------------------------------------------------------------------
    // SECTION B: EMAIL NOTIFICATIONS
    // HTML is generated at send time from app_title / app_body.
    // Event data is fetched from the DB to build a structured event card.
    // -------------------------------------------------------------------------
    if (emailNotes.length > 0) {
      const uniqueEmailNotes = Array.from(new Map(emailNotes.map((n) => [n.id, n])).values());

      const validEmailNotes = uniqueEmailNotes.filter((n) => {
        if (!n.users?.email_address) {
          console.warn(`⚠️ No email address for recipient ${n.recipient_user_id} — skipping`);
          return false;
        }
        if (processedIds.includes(n.id)) {
          console.log(`⏭️ Notification ${n.id} already processed via push — skipping email`);
          return false;
        }
        return true;
      });

      // Batch-fetch event data for all notifications that reference an event via link_page
      const eventIds = [
        ...new Set(
          validEmailNotes
            .map((n) => { const m = n.link_page?.match(/eventID=(\d+)/); return m ? parseInt(m[1]) : null; })
            .filter(Boolean)
        ),
      ];
      const eventDataMap = new Map();
      if (eventIds.length > 0) {
        const { data: eventsData } = await supabaseClient
          .from('events')
          .select('event_id, event_title, event_date_time, opposition, event_codes(event_code), event_types(event_type)')
          .in('event_id', eventIds);
        (eventsData || []).forEach((ev) => {
          const dt = new Date(ev.event_date_time);
          const formattedDate = dt.toLocaleString('en-IE', {
            timeZone: 'Europe/Dublin',
            weekday: 'long',
            day: 'numeric',
            month: 'long',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit',
            hour12: true,
          });
          // Build title: use event_title if set, otherwise fall back to "EventCode EventType"
          const baseTitle = ev.event_title
            || [ev.event_codes?.event_code, ev.event_types?.event_type].filter(Boolean).join(' ')
            || 'Event';
          const eventDisplayTitle = ev.opposition ? `${baseTitle} vs. ${ev.opposition}` : baseTitle;
          eventDataMap.set(ev.event_id, { eventDisplayTitle, formattedDate });
        });
      }

      const logoUrl = 'https://gyfporsbdftvtakdvukt.supabase.co/storage/v1/object/sign/coachsmartimages/CoachSmart%20Logo%20Transparent.png?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV82OTA4NmRkYy01MWQ3LTQ1NzUtYWYwMC1mZjQxYmMyNDU2YWMiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJjb2FjaHNtYXJ0aW1hZ2VzL0NvYWNoU21hcnQgTG9nbyBUcmFuc3BhcmVudC5wbmciLCJpYXQiOjE3NzQ2MDYzOTksImV4cCI6MjYzODYwNjM5OX0.20yMzSYnG08kYjMK6cmGMvwA6VPGvm9_yHG-CmEfSIs';

      const emailsToSend = validEmailNotes.map((n) => {
        const firstName = n.users?.first_name || 'there';
        const title = n.app_title || 'Notification';
        const body = n.app_body || '';

        const eventIdMatch = n.link_page?.match(/eventID=(\d+)/);
        const eventIdNum = eventIdMatch ? parseInt(eventIdMatch[1]) : null;
        const eventData = eventIdNum ? eventDataMap.get(eventIdNum) : null;

        // Detect notification type from title to choose badge and intro phrasing
        const titleLower = title.toLowerCase();
        const bodyLower = body.toLowerCase();
        const isReminder = titleLower.includes('reminder') || titleLower.includes('response');
        const introText = isReminder ? `${title} for the following event:` : `${title}:`;

        let badgeLabel: string;
        let badgeColor: string;
        if (isReminder) {
          badgeLabel = 'ACTION REQUIRED';
          badgeColor = '#87C232';
        } else if (titleLower.startsWith('attendance accepted')) {
          badgeLabel = 'ACCEPTED';
          badgeColor = '#87C232';
        } else if (titleLower.startsWith('attendance declined')) {
          badgeLabel = 'DECLINED';
          badgeColor = '#e05252';
        } else if (titleLower.startsWith('change of attendance')) {
          if (bodyLower.includes('to accepted')) {
            badgeLabel = 'DECLINED → ACCEPTED';
            badgeColor = '#87C232';
          } else if (bodyLower.includes('to declined')) {
            badgeLabel = 'ACCEPTED → DECLINED';
            badgeColor = '#e05252';
          } else {
            badgeLabel = 'ATTENDANCE CHANGED';
            badgeColor = '#888888';
          }
        } else if (titleLower.includes('not approved')) {
          badgeLabel = 'NOT APPROVED';
          badgeColor = '#e05252';
        } else if (titleLower.includes('approved')) {
          badgeLabel = 'APPROVED';
          badgeColor = '#87C232';
        } else if (titleLower.includes('access request')) {
          badgeLabel = 'ACCESS REQUEST';
          badgeColor = '#4a9eff';
        } else if (titleLower.includes('join request') || titleLower.includes('join')) {
          badgeLabel = 'JOIN REQUEST';
          badgeColor = '#4a9eff';
        } else {
          badgeLabel = 'ATTENDANCE UPDATE';
          badgeColor = '#4a9eff';
        }
        const displayBody = isReminder
          ? 'Please open the CoachSmart app and respond for this event so that your team can finalise their plans. Thank you!'
          : body;

        const eventCardHtml = eventData
          ? `<table width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 20px 0;"><tr><td style="background:#2c313a;border-left:4px solid #87C232;padding:16px 18px;border-radius:0 8px 8px 0;"><p style="margin:0 0 6px 0;color:#e7ebee;font-size:16px;font-weight:700;font-family:Arial,Helvetica,sans-serif;">${eventData.eventDisplayTitle}</p><p style="margin:0;color:#87C232;font-size:13px;font-family:Arial,Helvetica,sans-serif;">${eventData.formattedDate}</p></td></tr></table>`
          : '';

        const badgeHtml = `<table width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 16px 0;"><tr><td><span style="display:inline-block;background:${badgeColor};color:#fff;font-size:10px;font-weight:700;letter-spacing:2px;padding:5px 12px;border-radius:4px;font-family:Arial,Helvetica,sans-serif;">${badgeLabel}</span></td></tr></table>`;

        const html = `<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>CoachSmart</title></head><body style="margin:0;padding:0;background-color:#111418;font-family:Arial,Helvetica,sans-serif;"><table width="100%" cellpadding="0" cellspacing="0" style="padding:40px 20px;"><tr><td align="center"><table width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background-color:#212529;border-radius:16px;overflow:hidden;border:1px solid #3a3f4b;"><tr><td style="background-color:#1E222B;padding:28px 24px;text-align:center;border-bottom:3px solid #87C232;"><table cellpadding="0" cellspacing="0" style="margin:0 auto;"><tr><td style="padding-right:16px;vertical-align:middle;"><img src="${logoUrl}" alt="CoachSmart" width="80" style="display:block;height:auto;border:0;"></td><td style="vertical-align:middle;text-align:left;"><p style="margin:0;font-size:26px;font-weight:900;letter-spacing:2.5px;line-height:1;font-family:Arial,Helvetica,sans-serif;"><span style="color:#c8ccd0;">COACH</span><span style="color:#87C232;">SMART</span></p><p style="margin:5px 0 0 0;font-size:9px;font-weight:700;letter-spacing:4px;color:#87C232;font-family:Arial,Helvetica,sans-serif;">COACHING&nbsp;&nbsp;MADE&nbsp;&nbsp;SIMPLE</p></td></tr></table></td></tr><tr><td style="padding:28px 28px 24px;"><p style="margin:0 0 20px 0;font-size:15px;color:#e7ebee;font-family:Arial,Helvetica,sans-serif;">Hi ${firstName},</p><p style="margin:0 0 20px 0;font-size:15px;color:#e7ebee;font-family:Arial,Helvetica,sans-serif;">${introText}</p>${eventCardHtml}${badgeHtml}<p style="margin:0;font-size:14px;color:#a3a3a3;line-height:1.6;font-family:Arial,Helvetica,sans-serif;">${displayBody}</p></td></tr><tr><td style="padding:16px 28px;border-top:1px solid #3a3f4b;text-align:center;"><p style="margin:0 0 4px 0;font-size:11px;color:#555;letter-spacing:1.5px;font-family:Arial,Helvetica,sans-serif;">COACHSMART &middot; COACHING MADE SIMPLE</p><p style="margin:0;font-size:11px;color:#444;font-family:Arial,Helvetica,sans-serif;">You received this because you are a member of a CoachSmart team.</p></td></tr></table></td></tr></table></body></html>`;

        console.log(`📧 Sending email for notification ${n.id} | to=${n.users.email_address}`);
        return {
          _id: n.id,
          from: 'CoachSmart <noreply@coachsmart.app>',
          to: [n.users.email_address],
          subject: title,
          html,
        };
      });

      if (emailsToSend.length > 0) {
        for (let i = 0; i < emailsToSend.length; i += 100) {
          const chunk = emailsToSend.slice(i, i + 100);
          const resendPayload = chunk.map(({ _id, ...rest }) => rest);
          const { error: emailError } = await resend.batch.send(resendPayload);
          if (!emailError) {
            console.log(`✉️ Sent batch of ${chunk.length} email(s) ✓`);
            chunk.forEach((e) => { processedIds.push(e._id); emailDeliveredIds.push(e._id); });
          } else {
            console.error('❌ Resend Batch Error:', emailError);
          }
        }
      } else {
        console.log('⚪ No valid emails to send after filtering');
      }
    }
    // -------------------------------------------------------------------------
    // SECTION C: FINAL DATABASE UPDATES
    // -------------------------------------------------------------------------
    if (processedIds.length > 0) {
      const { error: updateError } = await supabaseClient.from('notifications').update({
        is_delivered: true
      }).in('id', processedIds);
      if (updateError) {
        console.error('❌ Final Update Error:', updateError.message);
      } else {
        console.log(`✅ Marked ${processedIds.length} notification(s) as is_delivered=true`);
      }
    }
    if (emailDeliveredIds.length > 0) {
      const { error: emailMethodError } = await supabaseClient
        .from('notifications')
        .update({ delivery_method: 'email' })
        .in('id', emailDeliveredIds);
      if (emailMethodError) {
        console.error('❌ delivery_method update error:', emailMethodError.message);
      } else {
        console.log(`📝 Updated delivery_method to email for ${emailDeliveredIds.length} notification(s)`);
      }
    }
    if (deadTokens.length > 0) {
      await supabaseClient.from('users').update({
        fcm_token: null
      }).in('user_id', deadTokens);
      console.log(`🧹 Cleared ${deadTokens.length} invalid FCM token(s)`);
    }
    return new Response(JSON.stringify({
      status: 'Success',
      processed: processedIds.length
    }), {
      status: 200,
      headers: corsHeaders
    });
  } catch (error) {
    console.error('🚨 CRITICAL ERROR:', error.message);
    return new Response(JSON.stringify({
      error: error.message
    }), {
      status: 500,
      headers: corsHeaders
    });
  }
});
// ---------------------------------------------------------------------------
// HELPERS
// ---------------------------------------------------------------------------
function groupBy(arr, key) {
  return arr.reduce((acc, obj)=>{
    const k = obj[key];
    if (!acc[k]) acc[k] = [];
    acc[k].push(obj);
    return acc;
  }, {});
}
async function getFcmAccessToken(sa) {
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
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt
    })
  });
  const data = await res.json();
  return data.access_token;
}
