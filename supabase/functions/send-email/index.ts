import { Resend } from 'https://esm.sh/resend@3.2.0';
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
console.log('Branded Email Trigger Function started!');
serve(async (req)=>{
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders
    });
  }
  const resend = new Resend(Deno.env.get("RESEND_API_KEY"));
  try {
    const { to, subject, body, recipient_name } = await req.json();
    // ✅ Logic to handle either an array or a comma-delimited string
    let recipients = [];
    if (Array.isArray(to)) {
      recipients = to;
    } else if (typeof to === 'string') {
      // Split by comma and clean up whitespace
      recipients = to.split(',').map((email)=>email.trim()).filter((email)=>email.length > 0);
    }
    // Safety check to ensure we actually have recipients
    if (recipients.length === 0) {
      throw new Error("Recipient list is empty. 'to' must be a list or comma-separated string.");
    }
    const greetingName = recipient_name ? recipient_name : 'there';
    const htmlBody = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #ddd; border-radius: 10px; background-color: #212529; color: #fff;">
        <div style="text-align: center; margin-bottom: 20px; background-color: #2c313a; padding: 20px; border-radius: 8px;">
          <h1 style="font-size: 24px; color: #76C74A; margin-top: 10px; margin-bottom: 0;">CoachSmart</h1>
          <p style="font-size: 14px; color: #bbb; font-weight: 300; letter-spacing: 0.2em; margin-top: 5px;">COACHING MADE SIMPLE</p>
        </div>
        <div style="background-color: #2c313a; padding: 20px; border-radius: 8px;">
          <p style="font-size: 16px; color: #fff;">Hi ${greetingName},</p>
          <h2 style="font-size: 20px; color: #76C74A; margin-top: 10px; margin-bottom: 10px;">${subject}</h2>
          <div style="font-size: 16px; color: #fff; line-height: 1.5;">
            ${body}
          </div>
          <p style="font-size: 14px; color: #bbb; margin-top: 20px; border-top: 1px solid #444; padding-top: 15px;">
            To take action, please log onto the CoachSmart app. We can't wait to see you there!
          </p>
        </div>
        <div style="text-align: center; margin-top: 20px; color: #bbb; font-size: 12px;">
          This is an automated message from CoachSmart. Please do not reply.
        </div>
      </div>
    `;
    // ✅ Resend sends to the array (Batching multiple parents automatically)
    const { data, error } = await resend.emails.send({
      from: "CoachSmart <no-reply@coachsmart.app>",
      to: recipients,
      subject: subject,
      html: htmlBody
    });
    if (error) throw error;
    return new Response(JSON.stringify(data), {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (error) {
    console.error('Email sending failed:', error);
    return new Response(JSON.stringify({
      error: error.message
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
});
