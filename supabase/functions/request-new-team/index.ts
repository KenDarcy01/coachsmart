// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { Resend } from "https://esm.sh/resend@3.2.0";

// Requires:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY  (auto-provided in edge functions)
//   RESEND_API_KEY                           (already set for send-email)
//   TEAM_REQUEST_NOTIFY_EMAIL                (set via: supabase secrets set TEAM_REQUEST_NOTIFY_EMAIL=ken@coachsmart.app)

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { name, club_name, county, email, notes } = await req.json();

    if (!name?.trim() || !club_name?.trim() || !county?.trim() || !email?.trim()) {
      return new Response(
        JSON.stringify({ error: "name, club_name, county and email are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email.trim())) {
      return new Response(
        JSON.stringify({ error: "Invalid email address" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ── Insert the request using service role (bypasses RLS) ──────────────────
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { error: dbError } = await supabase.from("team_requests").insert({
      name:      name.trim(),
      club_name: club_name.trim(),
      county:    county.trim(),
      email:     email.trim().toLowerCase(),
      notes:     notes?.trim() || null,
    });

    if (dbError) {
      console.error("DB insert failed:", dbError);
      return new Response(
        JSON.stringify({ error: "Could not save request" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ── Send notification email to admin ──────────────────────────────────────
    const notifyEmail = Deno.env.get("TEAM_REQUEST_NOTIFY_EMAIL") || "ken@coachsmart.app";
    const resend = new Resend(Deno.env.get("RESEND_API_KEY"));

    const notesRow = notes?.trim()
      ? `<tr>
           <td style="padding:10px 14px;color:#9ca3af;font-size:14px;border-bottom:1px solid #374151;white-space:nowrap;vertical-align:top">Notes</td>
           <td style="padding:10px 14px;color:#f9fafb;font-size:14px;border-bottom:1px solid #374151">${escHtml(notes.trim())}</td>
         </tr>`
      : "";

    const html = `<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/></head>
<body style="margin:0;padding:0;background:#0f1117;font-family:Arial,Helvetica,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#0f1117;padding:32px 16px">
    <tr><td align="center">
      <table width="100%" cellpadding="0" cellspacing="0" style="max-width:560px">

        <!-- Header -->
        <tr><td style="background:#1a1f2e;border-radius:12px 12px 0 0;padding:28px 32px;text-align:center;border-bottom:3px solid #87C232">
          <div style="font-size:26px;font-weight:800;color:#87C232;letter-spacing:-0.5px">CoachSmart</div>
          <div style="font-size:11px;color:#6b7280;letter-spacing:2px;margin-top:4px;text-transform:uppercase">Coaching Made Simple</div>
        </td></tr>

        <!-- Alert stripe -->
        <tr><td style="background:#87C232;padding:10px 32px">
          <div style="font-size:13px;font-weight:700;color:#111418;letter-spacing:0.5px;text-transform:uppercase">New Team Setup Request</div>
        </td></tr>

        <!-- Body -->
        <tr><td style="background:#1a1f2e;padding:28px 32px">
          <p style="margin:0 0 20px;font-size:15px;color:#d1d5db;line-height:1.6">
            A coach has requested a new team setup through the CoachSmart app. Their details are below.
          </p>

          <!-- Details table -->
          <table width="100%" cellpadding="0" cellspacing="0" style="background:#111827;border-radius:8px;overflow:hidden;border:1px solid #374151">
            <tr>
              <td style="padding:10px 14px;color:#9ca3af;font-size:14px;border-bottom:1px solid #374151;white-space:nowrap;vertical-align:top">Name</td>
              <td style="padding:10px 14px;color:#f9fafb;font-size:14px;font-weight:600;border-bottom:1px solid #374151">${escHtml(name.trim())}</td>
            </tr>
            <tr>
              <td style="padding:10px 14px;color:#9ca3af;font-size:14px;border-bottom:1px solid #374151;white-space:nowrap">Club</td>
              <td style="padding:10px 14px;color:#f9fafb;font-size:14px;font-weight:600;border-bottom:1px solid #374151">${escHtml(club_name.trim())}</td>
            </tr>
            <tr>
              <td style="padding:10px 14px;color:#9ca3af;font-size:14px;border-bottom:1px solid #374151;white-space:nowrap">County</td>
              <td style="padding:10px 14px;color:#f9fafb;font-size:14px;border-bottom:1px solid #374151">${escHtml(county.trim())}</td>
            </tr>
            <tr>
              <td style="padding:10px 14px;color:#9ca3af;font-size:14px;${notesRow ? 'border-bottom:1px solid #374151;' : ''}white-space:nowrap">Email</td>
              <td style="padding:10px 14px;font-size:14px;${notesRow ? 'border-bottom:1px solid #374151;' : ''}"><a href="mailto:${escHtml(email.trim())}" style="color:#60a5fa">${escHtml(email.trim())}</a></td>
            </tr>
            ${notesRow}
          </table>

          <p style="margin:24px 0 0;font-size:14px;color:#6b7280;line-height:1.6">
            Reply directly to <a href="mailto:${escHtml(email.trim())}" style="color:#87C232">${escHtml(email.trim())}</a> once their team is set up and their code is ready.
          </p>
        </td></tr>

        <!-- Footer -->
        <tr><td style="background:#111418;border-radius:0 0 12px 12px;padding:20px 32px;text-align:center;border-top:1px solid #374151">
          <div style="font-size:12px;color:#4b5563">This is an automated notification from CoachSmart · Do not reply to this email</div>
        </td></tr>

      </table>
    </td></tr>
  </table>
</body>
</html>`;

    const { error: emailError } = await resend.emails.send({
      from:    "CoachSmart <no-reply@coachsmart.app>",
      to:      [notifyEmail],
      subject: `New Team Request — ${club_name.trim()}, ${county.trim()}`,
      html,
    });

    if (emailError) {
      // Request is already saved — log the email failure but still return success
      console.error("Notification email failed:", emailError);
    }

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );

  } catch (err) {
    console.error("request-new-team error:", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});

function escHtml(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}
