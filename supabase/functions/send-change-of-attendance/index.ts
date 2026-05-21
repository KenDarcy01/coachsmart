import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.44.0';
import { Resend } from 'https://esm.sh/resend@3.2.0';
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
// This is the content of the _shared/cors.ts file.
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
console.log('Group Mail Sender Edge Function started!');
serve(async (req)=>{
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders
    });
  }
  // 1. Initialize Supabase client
  const supabaseClient = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '', {
    auth: {
      persistSession: false
    }
  });
  // 2. Initialize Resend client
  const resend = new Resend(Deno.env.get('RESEND_API_KEY'));
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({
      error: 'Method not allowed'
    }), {
      status: 405,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
  let body;
  let rawBody;
  try {
    // Read body as raw text first for better debugging on JSON errors
    rawBody = await req.text();
    console.log('Received raw request body:', rawBody);
    // Attempt to parse the raw body
    body = JSON.parse(rawBody);
  } catch (error) {
    console.error('JSON Parsing Error:', error);
    return new Response(JSON.stringify({
      error: 'Invalid JSON payload received. Ensure all string values (especially p_body) are properly quoted and escaped (e.g., replace newlines with \\n).',
      details: error.message
    }), {
      status: 400,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
  try {
    // 3. Parse the new payload structure (p_emails is removed)
    const { p_event_id: raw_event_id, p_member_id: memberId, p_subject, p_body } = body;
    const event_id = Number(raw_event_id);
    const changing_member_id = Number(memberId);
    // 4. Validate input parameters
    if (!event_id || typeof event_id !== 'number' || isNaN(event_id) || event_id <= 0) {
      return new Response(JSON.stringify({
        error: 'p_event_id must be a valid positive number'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    // Validation for single changing member ID
    if (!changing_member_id || typeof changing_member_id !== 'number' || isNaN(changing_member_id) || changing_member_id <= 0) {
      return new Response(JSON.stringify({
        error: 'p_member_id must be a valid positive number.'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    if (!p_subject || typeof p_subject !== 'string' || p_subject.trim() === '') {
      return new Response(JSON.stringify({
        error: 'p_subject must be a non-empty string'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    if (!p_body || typeof p_body !== 'string' || p_body.trim() === '') {
      return new Response(JSON.stringify({
        error: 'p_body must be a non-empty string'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    console.log(`Received event_id: ${event_id}, subject: ${p_subject}`);
    // 5. Fetch required event details, including related event_code and event_type
    const { data: eventData, error: eventError } = await supabaseClient.from('events').select(`
        team_id, 
        event_title, 
        event_date_time_2,
        event_codes(event_code),
        event_types(event_type)
      `).eq('event_id', event_id).single();
    if (eventError || !eventData || !eventData.team_id || !eventData.event_date_time_2) {
      console.error('Failed to fetch required event details (team, date, or event missing):', eventError);
      return new Response(JSON.stringify({
        error: 'Event not found or essential details (team_id, date) are missing.'
      }), {
        status: 404,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    const team_id = eventData.team_id;
    const raw_event_date_time_2 = eventData.event_date_time_2;
    // --- LOGIC FOR EVENT TITLE FALLBACK ---
    let event_title = eventData.event_title;
    // Check if the event_title is null or empty after trimming
    if (!event_title || String(event_title).trim() === '') {
      const code = eventData.event_codes?.event_code || '';
      const type = eventData.event_types?.event_type || '';
      const fallbackTitle = `${code} ${type}`.trim();
      if (fallbackTitle) {
        event_title = fallbackTitle;
        console.log(`Event title was empty. Using fallback title: ${event_title}`);
      } else {
        // If even the fallback is empty, we must fail the request.
        console.error('Event title is empty and required fallback data (code/type) is also missing.');
        return new Response(JSON.stringify({
          error: 'Event title is missing and could not be generated from event_code/event_type.'
        }), {
          status: 400,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json'
          }
        });
      }
    }
    // ---------------------------------
    // 6. Fetch the team name
    const { data: teamData, error: teamError } = await supabaseClient.from('teams').select('team_name').eq('team_id', team_id).single();
    if (teamError || !teamData) {
      console.error('Failed to fetch team details:', teamError);
      return new Response(JSON.stringify({
        error: 'Team not found or database error while fetching team name'
      }), {
        status: 404,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    const team_name = teamData.team_name;
    // 7. Fetch member details (first name, last name) for the single member whose status changed
    const { data: memberData, error: memberError } = await supabaseClient.from('members').select('first_name, last_name').eq('member_id', changing_member_id).single();
    // Determine the full name once before the loop
    let fullName = 'A member';
    if (!memberError && memberData) {
      const firstName = memberData.first_name || '';
      const lastName = memberData.last_name || '';
      const combinedName = `${firstName} ${lastName}`.trim();
      if (combinedName) {
        fullName = combinedName;
      }
    } else {
      console.error('Failed to fetch changing member details. Using default name:', memberError);
    }
    // Format the event date/time to match the requested output: "Thursday October 12 2025 at 14:00"
    let formattedDateTime = '';
    try {
      // event_date_time_2 is timestamp without time zone, assuming it's UTC or parsable locally
      const eventDateTime = new Date(raw_event_date_time_2);
      const days = [
        'Sunday',
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday'
      ];
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
      ];
      const dayName = days[eventDateTime.getDay()];
      const monthName = months[eventDateTime.getMonth()];
      const dayOfMonth = eventDateTime.getDate();
      const year = eventDateTime.getFullYear();
      // Use padStart for 2-digit hours and minutes
      const hours = String(eventDateTime.getHours()).padStart(2, '0');
      const minutes = String(eventDateTime.getMinutes()).padStart(2, '0');
      formattedDateTime = `${dayName} ${monthName} ${dayOfMonth} ${year} at ${hours}:${minutes}`;
    } catch (e) {
      console.error("Error formatting event date:", e);
      // Fallback in case of parsing error
      formattedDateTime = `(Error: ${raw_event_date_time_2})`;
    }
    // 8. Fetch all admin emails (role_id = 7) for the given team_id
    const ADMIN_ROLE_ID = 7;
    const { data: adminUsersData, error: adminUsersError } = await supabaseClient.from('member_team_link').select(`
      members!inner(
        user_id,
        users!inner(
          email_address
        )
      ),
      member_team_role_link!inner(
        role_id
      )
    `).eq('team_id', team_id).eq('member_team_role_link.role_id', ADMIN_ROLE_ID);
    let recipientEmails = [];
    if (adminUsersError) {
      console.error('Failed to fetch admin emails:', adminUsersError);
    } else if (adminUsersData) {
      recipientEmails = adminUsersData.map((link)=>link.members?.users?.email_address).filter((email)=>typeof email === 'string' && email.trim() !== '');
    }
    if (recipientEmails.length === 0) {
      console.log('No admin members found for this team to send notification to.');
      return new Response(JSON.stringify({
        error: 'No admin members found for this team to send notification to.'
      }), {
        status: 404,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    if (recipientEmails.length > 0) {
      const emailsToSend = [];
      // 9. Iterate over the recipient emails (all will use the same content)
      for (const recipientEmail of recipientEmails){
        // CONSTRUCT THE FULL MESSAGE: [Name] [p_body] for the event: [Title] on [Date]
        const eventInfo = ` for the event: ${event_title} on ${formattedDateTime}`;
        const emailContent = `${fullName} ${p_body}${eventInfo}`;
        // Use the generic subject passed in
        const emailSubject = `${team_name || 'Your Team'}: ${p_subject}`;
        // Prepare the full HTML body
        const htmlBody = `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #ddd; border-radius: 10px; background-color: #212529; color: #fff;">
            <div style="text-align: center; margin-bottom: 20px; background-color: #2c313a; padding: 20px; border-radius: 8px;">
              <h1 style="font-size: 24px; color: #76C74A; margin-top: 10px; margin-bottom: 0;">CoachSmart</h1>
              <p style="font-size: 14px; color: #bbb; font-weight: 300; letter-spacing: 0.2em; margin-top: 5px;">COACHING MADE SIMPLE</p>
            </div>
            <div style="background-color: #2c313a; padding: 20px; border-radius: 8px;">
              <div style="background-color: #343a40; padding: 15px; border-radius: 6px; border-left: 3px solid #76C74A; margin-top: 20px;">
                <p style="font-size: 16px; color: #fff; white-space: pre-wrap;">${emailContent}</p>
              </div>
            </div>
            <div style="text-align: center; margin-top: 20px; color: #bbb; font-size: 12px;">
              This is an automated message. Please do not reply.
            </div>
          </div>
        `;
        emailsToSend.push({
          from: 'CoachSmart <noreply@coachsmart.app>',
          to: [
            recipientEmail
          ],
          subject: emailSubject,
          html: htmlBody
        });
      }
      // 10. Send the batch of emails
      try {
        const result = await resend.batch.send(emailsToSend);
        console.log('Resend batch API response:', result.data);
        // Prepare the verification data for the response and console log
        const responseData = {
          message: `Successfully sent ${emailsToSend.length} notification emails.`,
          // ** Return the list of intended recipients for verification **
          recipients: recipientEmails,
          // ** Also return the prepared email details for checking the content **
          prepared_emails: emailsToSend.map((e)=>({
              to: e.to,
              subject: e.subject,
              // Show the personalized content block
              content_start: e.html.substring(e.html.indexOf('<p'), e.html.indexOf('</p>') + 4)
            }))
        };
        // Log to console for debugging/logging, as requested
        console.log('Verification data for sent emails:', JSON.stringify(responseData, null, 2));
        return new Response(JSON.stringify(responseData), {
          status: 200,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json'
          }
        });
      } catch (sendError) {
        console.error('Error sending emails via Resend batch API:', sendError);
        const errorMessage = sendError?.message || 'Unknown Resend error.';
        return new Response(JSON.stringify({
          error: 'Failed to send one or more emails.',
          details: errorMessage,
          recipients_attempted: recipientEmails
        }), {
          status: 500,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json'
          }
        });
      }
    } else {
      // This block is for cases where no recipients are found (handled in step 8)
      console.log('No recipients determined for email.');
      return new Response(JSON.stringify({
        message: 'No recipients determined for email.'
      }), {
        status: 200,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
  } catch (error) {
    console.error('An unexpected error occurred:', error);
    // Ensure error.message is safely retrieved and is a string
    const errorMessage = error?.message || 'Unknown unexpected error.';
    return new Response(JSON.stringify({
      error: 'An unexpected error occurred during processing',
      details: errorMessage
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
});
