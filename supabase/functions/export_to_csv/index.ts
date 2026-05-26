import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import postgres from "https://deno.land/x/postgresjs@v3.3.3/mod.js";
import { Resend } from 'https://esm.sh/resend@3.2.0';
import { z } from "https://deno.land/x/zod@v3.21.4/mod.ts";
import { encodeBase64 } from "https://deno.land/std@0.203.0/encoding/base64.ts";
const RequestSchema = z.object({
  event_id: z.coerce.string(),
  user_email: z.string().email(),
  match_squad_id: z.coerce.string()
});
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const DATABASE_URL = Deno.env.get("SUPABASE_DB_URL");
const sql = postgres(DATABASE_URL, {
  prepare: false
});
const resend = new Resend(RESEND_API_KEY);
// --- UTILITY: ARRAY TO CSV ---
function arrayToCsv(data) {
  const rows = data.map((row)=>{
    return row.map((field)=>{
      const value = field === null || field === undefined ? '' : field.toString();
      return `"${value.replace(/"/g, '""')}"`;
    }).join(',');
  });
  return '\uFEFF' + rows.join('\n');
}
const getEmailHtml = (sheetTitle)=>`
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="margin: 0; padding: 0; background-color: #f7fafc; font-family: Arial, sans-serif;">
    <table border="0" cellpadding="0" cellspacing="0" width="100%" style="table-layout: fixed; background-color: #1E222B; padding: 20px 0;">
        <tr><td align="center"><table border="0" cellpadding="0" cellspacing="0" width="600" style="max-width: 600px; background-color: #1E222B;">
            <tr><td align="center" style="padding: 20px 0;">
                <h1 style="margin: 0; font-size: 28px; color: #87C232; font-family: Arial, sans-serif; font-weight: bold;">CoachSmart</h1>
                <p style="margin: 5px 0 0; font-size: 14px; color: #ffffff; font-family: Arial, sans-serif; letter-spacing: 1px;">COACHING MADE SIMPLE</p>
            </td></tr>
            <tr><td bgcolor="#1E222B" style="padding: 40px 30px; border-radius: 8px;">
                <table border="0" cellpadding="0" cellspacing="0" width="100%"><tr><td style="color: #ffffff; font-family: Arial, sans-serif; font-size: 16px; line-height: 1.5;">
                    <p style="margin: 0 0 20px;">Hi there,</p>
                    <p style="margin: 0 0 20px;">Your team squads report for <b>${sheetTitle}</b> has been successfully exported and is attached as a <b>CSV</b> file.</p>
                </td></tr></table>
            </td></tr>
            <tr><td align="center" style="padding: 30px 0 10px; color: #b0b0b0; font-family: Arial, sans-serif; font-size: 12px;">
                <p style="margin: 0;">Thanks,<br/>The CoachSmart Team</p>
            </td></tr>
        </table></td></tr>
    </table>
</body>
</html>`;
const handler = async (request)=>{
  if (request.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization"
      }
    });
  }
  console.log("--- STARTING CSV EXPORT ---");
  try {
    const body = await request.json();
    const { event_id, user_email, match_squad_id } = RequestSchema.parse(body);
    // 1. Database Retrieval
    console.log("[STEP 1/4] Fetching data and constructing title...");
    const rows = await sql`
      SELECT
        s.squad_name, r.role_name_plural,
        (m.first_name || ' ' || m.last_name) AS full_member_name,
        r.role_list_seq, sq_team.team_name, e.event_title,
        to_char(e.event_date_time, 'Month DD, YYYY HH:MI AM') AS formatted_event_date_time,
        s.squad_list_seq, ec.event_code, et.event_type, e.opposition, ev_team.team_female
      FROM public.match_squad_details msd
      JOIN public.match_squads ms ON msd.match_squad_id = ms.match_squad_id
      JOIN public.members m ON msd.member_id = m.member_id
      JOIN public.roles r ON msd.role_id = r.role_id
      JOIN public.events e ON ms.event_id = e.event_id
      LEFT JOIN public.squads s ON msd.squad_id = s.squad_id
      LEFT JOIN public.teams sq_team ON s.team_id = sq_team.team_id
      INNER JOIN public.teams ev_team ON e.team_id = ev_team.team_id
      LEFT JOIN public.event_codes ec ON e.event_code_id = ec.code_id
      LEFT JOIN public.event_types et ON e.event_type_id = et.event_type_id
      WHERE ms.event_id = ${event_id} AND ms.match_squad_id = ${match_squad_id}
      ORDER BY s.squad_list_seq ASC, (m.first_name || ' ' || m.last_name) ASC
    `;
    if (!rows.length) throw new Error("No data found.");
    const firstRow = rows[0];
    // Camogie Swap Logic
    let displayCode = firstRow.event_code || "";
    if (displayCode === "Hurling" && (firstRow.team_female === "YES" || firstRow.team_female === true)) {
      displayCode = "Camogie";
      console.log("[INFO] Female team detected for Hurling. Using 'Camogie' in title.");
    }
    let displayTitle = firstRow.event_title || `${displayCode} ${firstRow.event_type || ""}`.trim();
    if (firstRow.event_type === "Match" && firstRow.opposition?.trim()) {
      displayTitle = `${displayTitle} - ${firstRow.opposition.trim()}`;
    }
    const reportTitle = `Teams - ${firstRow.team_name} (${displayTitle}) - ${firstRow.formatted_event_date_time}`;
    console.log(`[INFO] Final Report Title: ${reportTitle}`);
    // 2. Data Organization (Same as before)
    const organizedData = new Map();
    const squadSequences = new Map();
    const assignedMembers = new Set();
    for (const row of rows){
      const { squad_name, full_member_name, role_name_plural, role_list_seq, squad_list_seq } = row;
      if (!squad_name || !full_member_name) continue;
      if (squad_list_seq !== null) squadSequences.set(squad_name, squad_list_seq);
      if (squad_name !== "No Team") assignedMembers.add(full_member_name);
      if (!organizedData.has(squad_name)) organizedData.set(squad_name, new Map());
      const squadMap = organizedData.get(squad_name);
      if (!squadMap.has(role_name_plural)) squadMap.set(role_name_plural, {
        members: new Set(),
        seq: role_list_seq
      });
      squadMap.get(role_name_plural).members.add(full_member_name);
    }
    const squadNames = Array.from(organizedData.keys());
    const sortedSquads = [
      ...squadNames.filter((n)=>n !== "No Team").sort((a, b)=>(squadSequences.get(a) || 999) - (squadSequences.get(b) || 999) || a.localeCompare(b)),
      ...squadNames.filter((n)=>n === "No Team")
    ];
    const dataForCsv = [
      [
        reportTitle
      ]
    ];
    for (const squadName of sortedSquads){
      dataForCsv.push([], [
        squadName
      ]);
      const roles = Array.from(organizedData.get(squadName).keys()).map((name)=>({
          name,
          seq: organizedData.get(squadName).get(name).seq
        })).sort((a, b)=>a.seq - b.seq);
      for (const role of roles){
        let members = Array.from(organizedData.get(squadName).get(role.name).members);
        if (squadName === "No Team") members = members.filter((m)=>!assignedMembers.has(m));
        if (members.length > 0) {
          dataForCsv.push([], [
            role.name
          ]);
          members.sort().forEach((m)=>dataForCsv.push([
              m
            ]));
        }
      }
    }
    // 3. Encoding
    const csvString = arrayToCsv(dataForCsv);
    const csvBytes = new TextEncoder().encode(csvString);
    const base64Csv = encodeBase64(csvBytes);
    const fileName = `${reportTitle.replace(/[\\/:"*?<>|]/g, '-')}.csv`;
    // 4. Send Email
    await resend.emails.send({
      from: 'CoachSmart <noreply@coachsmart.app>',
      to: [
        user_email
      ],
      subject: reportTitle,
      html: getEmailHtml(reportTitle),
      attachments: [
        {
          filename: fileName,
          content: base64Csv
        }
      ]
    });
    return new Response(JSON.stringify({
      status: 'success',
      reportTitle
    }), {
      status: 200,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Content-Type": "application/json"
      }
    });
  } catch (err) {
    console.error(`[CRITICAL ERROR] ${err.message}`);
    return new Response(JSON.stringify({
      error: err.message
    }), {
      status: 500,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Content-Type": "application/json"
      }
    });
  }
};
serve(handler);
