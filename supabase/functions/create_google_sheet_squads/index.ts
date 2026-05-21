import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import postgres from "https://deno.land/x/postgresjs@v3.3.3/mod.js";
import { z } from "https://deno.land/x/zod@v3.21.4/mod.ts";
const RequestSchema = z.object({
  event_id: z.coerce.string(),
  user_email: z.string().email(),
  match_squad_id: z.coerce.string()
});
const jsonReplacer = (_key, value)=>{
  return typeof value === 'bigint' ? value.toString() : value;
};
const APPS_SCRIPT_URL = "https://script.google.com/macros/s/AKfycbzWAvz64fn4Sp3zX3N3glpzIrWUOHmjf11csbmXoAydvRTKae9tR-9JpMZawZgeGeKPzg/exec";
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const DATABASE_URL = Deno.env.get("SUPABASE_DB_URL");
const sql = postgres(DATABASE_URL, {
  prepare: false
});
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
  console.log("--- STARTING EXPORT PROCESS ---");
  try {
    const body = await request.json();
    const { event_id, user_email, match_squad_id } = RequestSchema.parse(body);
    console.log("[STEP 1/4] Querying Database...");
    const rows = await sql`
      SELECT
        vms.squad_name,
        vms.role_name_plural,
        vms.full_member_name,
        vms.role_list_seq,
        vms.team_name,
        vms.event_title,
        vms.formatted_event_date_time,
        vms.squad_list_seq,
        ec.event_code,
        et.event_type,
        e.opposition,
        t.team_female
      FROM public.view_match_squads AS vms
      INNER JOIN public.events e ON vms.event_id = e.event_id
      INNER JOIN public.teams t ON e.team_id = t.team_id
      LEFT JOIN public.event_codes ec ON e.event_code_id = ec.code_id
      LEFT JOIN public.event_types et ON e.event_type_id = et.event_type_id
      WHERE vms.event_id = ${event_id}
        AND vms.match_squad_id = ${match_squad_id}
      ORDER BY vms.squad_list_seq ASC, vms.full_member_name ASC
    `;
    if (rows.length === 0) {
      console.error("[ERROR] No database rows returned.");
      return new Response(JSON.stringify({
        error: "No data found."
      }), {
        status: 404
      });
    }
    const firstRow = rows[0];
    // Logic: Camogie Swap
    let displayCode = firstRow.event_code || "";
    if (displayCode === "Hurling" && (firstRow.team_female === "YES" || firstRow.team_female === true)) {
      displayCode = "Camogie";
    }
    let displayTitle = firstRow.event_title;
    const baseFallback = `${displayCode} ${firstRow.event_type || ""}`.trim();
    if (!displayTitle || displayTitle.trim() === "") {
      displayTitle = baseFallback || "Event";
    }
    if (firstRow.event_type === "Match" && firstRow.opposition?.trim()) {
      displayTitle = `${displayTitle} - ${firstRow.opposition.trim()}`;
    }
    const sheetTitle = `Teams - ${firstRow.team_name} (${displayTitle}) - ${firstRow.formatted_event_date_time}`;
    // --- Data Organization ---
    const organizedData = new Map();
    const squadSequences = new Map();
    const assignedMembers = new Set();
    for (const row of rows){
      const { squad_name, role_name_plural, full_member_name, role_list_seq, squad_list_seq } = row;
      if (!squad_name || !full_member_name) continue;
      if (squad_list_seq !== null) squadSequences.set(squad_name, squad_list_seq);
      if (squad_name !== "No Team") assignedMembers.add(full_member_name);
      if (!organizedData.has(squad_name)) organizedData.set(squad_name, new Map());
      const squadMap = organizedData.get(squad_name);
      if (!squadMap.has(role_name_plural)) {
        squadMap.set(role_name_plural, {
          members: new Set(),
          seq: role_list_seq
        });
      }
      squadMap.get(role_name_plural).members.add(full_member_name);
    }
    const squadNames = Array.from(organizedData.keys());
    const sortedSquads = [
      ...squadNames.filter((n)=>n !== "No Team").sort((a, b)=>(squadSequences.get(a) || 999) - (squadSequences.get(b) || 999) || a.localeCompare(b)),
      ...squadNames.filter((n)=>n === "No Team")
    ];
    const dataForSheet = [];
    for (const squadName of sortedSquads){
      dataForSheet.push([
        "",
        squadName
      ]);
      const rolesMap = organizedData.get(squadName);
      const roles = Array.from(rolesMap.keys()).map((name)=>({
          name,
          seq: rolesMap.get(name).seq
        })).sort((a, b)=>a.seq - b.seq);
      for (const role of roles){
        let members = Array.from(rolesMap.get(role.name).members);
        if (squadName === "No Team") members = members.filter((m)=>!assignedMembers.has(m));
        if (members.length > 0) {
          dataForSheet.push([
            "",
            role.name
          ]);
          members.sort().forEach((m)=>dataForSheet.push([
              "",
              m
            ]));
        }
      }
    }
    // --- Google Apps Script Handoff ---
    const appsScriptResponse = await fetch(APPS_SCRIPT_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        title: sheetTitle,
        data: dataForSheet
      }, jsonReplacer)
    });
    const appsScriptResult = await appsScriptResponse.json();
    const sheetUrl = appsScriptResult.url;
    // --- Restored Branded Resend Email ---
    const emailHtml = `
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
                    <p style="margin: 0 0 20px;">Your team squads for <b>${sheetTitle}</b> have been successfully exported to Google Sheets.</p>
                    <p style="margin: 25px 0 10px; text-align: center;">
                        <a href="${sheetUrl || '#'}" style="background-color: #87C232; color: #1E222B; padding: 12px 25px; text-decoration: none; border-radius: 6px; display: inline-block; font-weight: bold; font-family: Arial, sans-serif; font-size: 16px;">View Team Sheet</a>
                    </p>
                    <p style="margin-top: 30px; font-size: 14px; color: #b0b0b0; text-align: center;">Copy this clean link to share:</p>
                    <div style="word-break: break-all; font-family: monospace; background-color: #0d1117; color: #87C232; padding: 15px; border: 1px solid #87C232; border-radius: 4px; margin-top: 10px; font-size: 14px; overflow-wrap: break-word; text-align: center;">${sheetUrl || 'Link processing...'}</div>
                </td></tr></table>
            </td></tr>
            <tr><td align="center" style="padding: 30px 0 10px; color: #b0b0b0; font-family: Arial, sans-serif; font-size: 12px;">
                <p style="margin: 0;">Thanks,<br/>The CoachSmart Team</p>
            </td></tr>
        </table></td></tr>
    </table>
</body>
</html>`;
    await fetch("https://api.resend.com/emails", {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${RESEND_API_KEY}`
      },
      body: JSON.stringify({
        from: 'CoachSmart <noreply@coachsmart.app>',
        to: user_email,
        subject: sheetTitle,
        html: emailHtml
      })
    });
    return new Response(JSON.stringify({
      status: 'success',
      sheetUrl
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
