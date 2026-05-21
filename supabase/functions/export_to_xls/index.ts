import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import postgres from "https://deno.land/x/postgresjs@v3.3.3/mod.js";
import { Resend } from 'https://esm.sh/resend@3.2.0';
import ExcelJS from 'https://esm.sh/exceljs@4.4.0';
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
const ROLE_STYLE = {
  fill: {
    type: 'pattern',
    pattern: 'solid',
    fgColor: {
      argb: 'FFE0E0E0'
    }
  },
  font: {
    name: 'Arial',
    bold: true,
    color: {
      argb: 'FF000000'
    }
  }
};
const TEAM_COLOR_MAP = {
  'RED TEAM': {
    fgColor: {
      argb: 'FFFF0000'
    },
    fontColor: 'FFFFFFFF'
  },
  'BLUE TEAM': {
    fgColor: {
      argb: 'FF0000FF'
    },
    fontColor: 'FFFFFFFF'
  },
  'NAVY TEAM': {
    fgColor: {
      argb: 'FF000080'
    },
    fontColor: 'FFFFFFFF'
  },
  'GREEN TEAM': {
    fgColor: {
      argb: 'FF008000'
    },
    fontColor: 'FFFFFFFF'
  },
  'PURPLE TEAM': {
    fgColor: {
      argb: 'FF800080'
    },
    fontColor: 'FFFFFFFF'
  },
  'BLACK TEAM': {
    fgColor: {
      argb: 'FF000000'
    },
    fontColor: 'FFFFFFFF'
  },
  'DEFAULT': {
    fgColor: {
      argb: 'FF1E222B'
    },
    fontColor: 'FFFFFFFF'
  }
};
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
                    <p style="margin: 0 0 20px;">Your team squads report for <b>${sheetTitle}</b> has been successfully exported and is attached to this email as an <b>XLSX</b> file.</p>
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
  console.log("--- STARTING XLSX EXPORT ---");
  try {
    const body = await request.json();
    const { event_id, user_email, match_squad_id } = RequestSchema.parse(body);
    // 1. Database Retrieval (Including team_female join)
    console.log("[STEP 1/5] Fetching data & constructing title...");
    const rows = await sql`
      SELECT
        vms.squad_name, vms.role_name_plural, vms.full_member_name, vms.role_list_seq,
        vms.team_name, vms.event_title, vms.formatted_event_date_time, vms.squad_list_seq,
        ec.event_code, et.event_type, e.opposition, t.team_female
      FROM public.view_match_squads AS vms
      INNER JOIN public.events e ON vms.event_id = e.event_id
      INNER JOIN public.teams t ON e.team_id = t.team_id
      LEFT JOIN public.event_codes ec ON e.event_code_id = ec.code_id
      LEFT JOIN public.event_types et ON e.event_type_id = et.event_type_id
      WHERE vms.event_id = ${event_id} AND vms.match_squad_id = ${match_squad_id}
      ORDER BY vms.squad_list_seq ASC, vms.full_member_name ASC
    `;
    if (!rows.length) throw new Error("No data found for the selected IDs.");
    const firstRow = rows[0];
    // --- Title & Camogie Swap Logic ---
    let displayCode = firstRow.event_code || "";
    if (displayCode === "Hurling" && (firstRow.team_female === "YES" || firstRow.team_female === true)) {
      displayCode = "Camogie";
      console.log("[INFO] Female team detected for Hurling. Swapping title to Camogie.");
    }
    let displayTitle = firstRow.event_title || `${displayCode} ${firstRow.event_type || ""}`.trim();
    if (firstRow.event_type === "Match" && firstRow.opposition?.trim()) {
      displayTitle = `${displayTitle} - ${firstRow.opposition.trim()}`;
    }
    const reportTitle = `Teams - ${firstRow.team_name} (${displayTitle}) - ${firstRow.formatted_event_date_time}`;
    console.log(`[INFO] Report Title: ${reportTitle}`);
    // 2. Data Organization
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
    // 3. XLSX Generation
    const workbook = new ExcelJS.Workbook();
    const worksheet = workbook.addWorksheet('Squads Report');
    worksheet.getColumn(1).width = 40;
    for (const squadName of sortedSquads){
      const teamRow = worksheet.addRow([
        squadName
      ]);
      const teamCell = teamRow.getCell(1);
      const teamStyle = TEAM_COLOR_MAP[squadName.toUpperCase()] || TEAM_COLOR_MAP['DEFAULT'];
      teamCell.fill = {
        type: 'pattern',
        pattern: 'solid',
        fgColor: teamStyle.fgColor
      };
      teamCell.font = {
        name: 'Arial',
        bold: true,
        color: {
          argb: teamStyle.fontColor
        }
      };
      const roles = Array.from(organizedData.get(squadName).keys()).map((name)=>({
          name,
          seq: organizedData.get(squadName).get(name).seq
        })).sort((a, b)=>a.seq - b.seq);
      for (const role of roles){
        let members = Array.from(organizedData.get(squadName).get(role.name).members);
        if (squadName === "No Team") members = members.filter((m)=>!assignedMembers.has(m));
        if (members.length > 0) {
          const roleRow = worksheet.addRow([
            role.name
          ]);
          roleRow.getCell(1).fill = ROLE_STYLE.fill;
          roleRow.getCell(1).font = ROLE_STYLE.font;
          members.sort().forEach((m)=>worksheet.addRow([
              m
            ]));
        }
      }
    }
    // 4. Encoding
    const buffer = await workbook.xlsx.writeBuffer();
    const base64Xlsx = encodeBase64(new Uint8Array(buffer));
    const fileName = `${reportTitle.replace(/[\\/:"*?<>|]/g, '-')}.xlsx`;
    // 5. Send Email
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
          content: base64Xlsx
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
