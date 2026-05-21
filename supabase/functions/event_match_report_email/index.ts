import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.44.0';
import { Resend } from 'https://esm.sh/resend@3.2.0';
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
// This is the content of the _shared/cors.ts file.
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
console.log('Event Match Report Email Edge Function started!');
serve(async (req)=>{
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders
    });
  }
  // Initialize Supabase client
  const supabaseClient = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '', {
    auth: {
      persistSession: false
    }
  });
  // Initialize Resend client with API key from environment variables
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
  try {
    // Read the request body as text first to log it for debugging
    const rawBody = await req.text();
    console.log('Received raw request body:', rawBody);
    // Parse the JSON from the raw body
    const { p_event_id: raw_event_id, p_report_id: raw_report_id } = JSON.parse(rawBody);
    const event_id = Number(raw_event_id);
    const report_id = Number(raw_report_id);
    // Validate input parameters
    if (!event_id || typeof event_id !== 'number' || isNaN(event_id) || event_id <= 0) {
      return new Response(JSON.stringify({
        error: 'event_id must be a valid positive number'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    if (!report_id || typeof report_id !== 'number' || isNaN(report_id) || report_id <= 0) {
      return new Response(JSON.stringify({
        error: 'report_id must be a valid positive number'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    console.log(`Received event_id: ${event_id} and report_id: ${report_id}`);
    // Fetch the match report
    const { data: reportData, error: reportError } = await supabaseClient.from('match_reports').select('match_report, user_id').eq('id', report_id).single();
    if (reportError || !reportData) {
      console.error('Failed to fetch match report:', reportError);
      return new Response(JSON.stringify({
        error: 'Match report not found'
      }), {
        status: 404,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    const matchReportText = reportData.match_report;
    // Fetch the event to get the team ID, title, and date
    const { data: eventData, error: eventError } = await supabaseClient.from('events').select('team_id, event_title, event_date_time').eq('event_id', event_id).single();
    if (eventError || !eventData) {
      console.error('Failed to fetch event details:', eventError);
      return new Response(JSON.stringify({
        error: 'Event not found'
      }), {
        status: 404,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    const team_id = eventData.team_id;
    const event_title = eventData.event_title;
    const event_date = eventData.event_date_time;
    // Get the name of the user who submitted the report
    const { data: submitterData, error: submitterError } = await supabaseClient.from('users').select('first_name, last_name').eq('user_id', reportData.user_id).single();
    const submitterName = submitterData ? `${submitterData.first_name || ''} ${submitterData.last_name || ''}`.trim() : 'A user';
    if (submitterError) {
      console.error('Failed to fetch submitter details:', submitterError);
    }
    // Get the team name for the email subject
    const { data: teamData, error: teamError } = await supabaseClient.from('teams').select('team_name').eq('team_id', team_id).single();
    if (teamError || !teamData) {
      console.error('Failed to fetch team details:', teamError);
      return new Response(JSON.stringify({
        error: 'Team not found'
      }), {
        status: 404,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    const team_name = teamData.team_name;
    // Find all users who are admins (role_id = 7) for this team
    const { data: adminMemberLinks, error: adminMemberLinksError } = await supabaseClient.from('member_team_role_link').select(`
        member_team_link!inner(
          members!inner(
            user_id
          )
        )
      `).eq('role_id', 7).eq('member_team_link.team_id', team_id);
    if (adminMemberLinksError) {
      console.error('Failed to fetch admin member links:', adminMemberLinksError);
      return new Response(JSON.stringify({
        error: 'Database query failed for admins'
      }), {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    const uniqueAdminUserIds = new Set();
    if (adminMemberLinks && adminMemberLinks.length > 0) {
      for (const link of adminMemberLinks){
        if (link.member_team_link?.members?.user_id) {
          uniqueAdminUserIds.add(link.member_team_link.members.user_id);
        }
      }
    }
    const adminsToEmail = [];
    if (uniqueAdminUserIds.size > 0) {
      const { data: adminsData, error: adminsError } = await supabaseClient.from('users').select('email_address, first_name').in('user_id', Array.from(uniqueAdminUserIds));
      if (adminsError) {
        console.error('Failed to fetch user data for admins:', adminsError);
        return new Response(JSON.stringify({
          error: 'Failed to retrieve admin user data.'
        }), {
          status: 500,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json'
          }
        });
      }
      adminsToEmail.push(...adminsData);
    }
    console.log(`Found ${adminsToEmail.length} unique admins to email.`);
    const formatEventDate = (dateString)=>{
      if (!dateString) return 'Date not available';
      const date = new Date(dateString);
      const options = {
        year: 'numeric',
        month: 'long',
        day: 'numeric',
        hour: 'numeric',
        minute: 'numeric',
        hour12: true
      };
      return new Intl.DateTimeFormat('en-US', options).format(date);
    };
    const formattedDate = formatEventDate(event_date);
    if (adminsToEmail.length > 0) {
      const emailsToSend = [];
      const intendedRecipients = [];
      for (const admin of adminsToEmail){
        const subject = `Match Report for ${team_name || 'Your Team'}: ${event_title || 'Event'}`;
        const htmlBody = `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #ddd; border-radius: 10px; background-color: #212529; color: #fff;">
            <div style="text-align: center; margin-bottom: 20px; background-color: #2c313a; padding: 20px; border-radius: 8px;">
              <h1 style="font-size: 24px; color: #76C74A; margin-top: 10px; margin-bottom: 0;">CoachSmart</h1>
              <p style="font-size: 14px; color: #bbb; font-weight: 300; letter-spacing: 0.2em; margin-top: 5px;">COACHING MADE SIMPLE</p>
            </div>
            <div style="background-color: #2c313a; padding: 20px; border-radius: 8px;">
              <p style="font-size: 16px; color: #fff;">Hi ${admin.first_name || 'there'},</p>
              <p style="font-size: 16px; color: #fff;">Here is the match report for the recent event (${event_title || 'Match Report'}) on ${formattedDate}, submitted by ${submitterName || 'A user'}:</p>
              <div style="background-color: #343a40; padding: 15px; border-radius: 6px; border-left: 3px solid #76C74A; margin-top: 20px;">
                <p style="font-size: 16px; color: #fff; white-space: pre-wrap;">${matchReportText}</p>
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
            admin.email_address
          ],
          subject: subject,
          html: htmlBody
        });
        intendedRecipients.push(admin.email_address);
      }
      try {
        const result = await resend.batch.send(emailsToSend);
        console.log('Resend batch API response:', result.data);
        return new Response(JSON.stringify({
          message: `${adminsToEmail.length} admin members emailed with match report`,
          recipients: intendedRecipients
        }), {
          status: 200,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json'
          }
        });
      } catch (sendError) {
        console.error('Batch email sending failed:', sendError);
        return new Response(JSON.stringify({
          error: 'Failed to send all emails in batch.',
          details: sendError.message
        }), {
          status: 500,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json'
          }
        });
      }
    } else {
      console.log('No admin members and no team owner found to email.');
      return new Response(JSON.stringify({
        message: 'No admin members and no team owner found to email.'
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
    return new Response(JSON.stringify({
      error: 'An unexpected error occurred',
      details: error.message
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
});
