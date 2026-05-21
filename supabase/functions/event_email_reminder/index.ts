import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.44.0';
import { Resend } from 'https://esm.sh/resend@3.2.0';
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
// This is the content of the _shared/cors.ts file.
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
console.log('Event Email Reminder Edge Function started!');
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
  // Check for the correct method
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
    const { event_id: raw_event_id } = await req.json();
    const event_id = Number(raw_event_id);
    // Check for a valid event ID
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
    console.log(`Received event_id: ${event_id}`);
    // Call the PostgreSQL function to get the list of unresponded attendees.
    const { data, error } = await supabaseClient.rpc('get_unresponded_events', {
      event_id_param: event_id
    });
    if (error) {
      console.error('Database query failed:', error);
      return new Response(JSON.stringify({
        error: 'Database query failed'
      }), {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    console.log('Data returned from get_unresponded_events:', data);
    if (data.length > 0) {
      const uniqueAttendeesByEmail = new Map();
      for (const attendee of data){
        uniqueAttendeesByEmail.set(attendee.email, attendee);
      }
      const attendees = Array.from(uniqueAttendeesByEmail.values());
      console.log(`Found ${attendees.length} unique attendees to email.`);
      // Create an array to hold all email objects for the batch request
      const emailsToSend = [];
      for (const attendee of attendees){
        const eventDateObj = new Date(attendee.event_date_time);
        const eventDate = !isNaN(eventDateObj.getTime()) ? eventDateObj.toLocaleDateString('en-US', {
          weekday: 'long',
          year: 'numeric',
          month: 'long',
          day: 'numeric',
          hour: 'numeric',
          minute: 'numeric'
        }) : 'Date not available';
        const subject = `${attendee.team_name || 'CoachSmart'}: ${attendee.event_title || 'Upcoming Event'}`;
        const htmlBody = `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #ddd; border-radius: 10px; background-color: #212529; color: #fff;">
            <div style="text-align: center; margin-bottom: 20px; background-color: #2c313a; padding: 20px; border-radius: 8px;">
              <h1 style="font-size: 24px; color: #76C74A; margin-top: 10px; margin-bottom: 0;">CoachSmart</h1>
              <p style="font-size: 14px; color: #bbb; font-weight: 300; letter-spacing: 0.2em; margin-top: 5px;">COACHING MADE SIMPLE</p>
            </div>
            <div style="background-color: #2c313a; padding: 20px; border-radius: 8px;">
              <p style="font-size: 16px; color: #fff;">Hi ${attendee.first_name || 'there'},</p>
              <p style="font-size: 16px; color: #fff;">This is a friendly reminder to respond to ${attendee.member_first_name}'s upcoming event:</p>
              <h2 style="font-size: 20px; color: #76C74A; margin: 10px 0;">${attendee.event_title || 'Event Details'}</h2>
              <p style="font-size: 16px; color: #bbb;"><strong>Date & Time:</strong> ${eventDate}</p>
              <p style="font-size: 16px; color: #fff;">To help us finalise the team(s), please log onto the CoachSmart app and respond for the event. We can't wait to see you there!</p>
            </div>
            <div style="text-align: center; margin-top: 20px; color: #bbb; font-size: 12px;">
              This is an automated message. Please do not reply.
            </div>
          </div>
        `;
        emailsToSend.push({
          from: 'CoachSmart <noreply@coachsmart.app>',
          to: [
            attendee.email
          ],
          subject: subject,
          html: htmlBody
        });
      }
      try {
        // Send all emails in a single batch request
        const result = await resend.batch.send(emailsToSend);
        console.log('Resend batch API response:', result.data);
        return new Response(JSON.stringify({
          message: `${attendees.length} members reminded`,
          data: result.data
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
      console.log('No unresponded attendees found for this event.');
      return new Response(JSON.stringify({
        message: 'No unresponded attendees found.'
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
