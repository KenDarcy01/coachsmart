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
const LOGO_URL = 'https://gyfporsbdftvtakdvukt.supabase.co/storage/v1/object/sign/coachsmartimages/CoachSmart%20Logo%20Transparent.png?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV82OTA4NmRkYy01MWQ3LTQ1NzUtYWYwMC1mZjQxYmMyNDU2YWMiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJjb2FjaHNtYXJ0aW1hZ2VzL0NvYWNoU21hcnQgTG9nbyBUcmFuc3BhcmVudC5wbmciLCJpYXQiOjE3NzQ2MDYzOTksImV4cCI6MjYzODYwNjM5OX0.20yMzSYnG08kYjMK6cmGMvwA6VPGvm9_yHG-CmEfSIs';
const getEmailHtml = (sheetTitle, firstName)=>`<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>CoachSmart</title></head><body style="margin:0;padding:0;background-color:#111418;font-family:Arial,Helvetica,sans-serif;"><table width="100%" cellpadding="0" cellspacing="0" style="padding:40px 20px;"><tr><td align="center"><table width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background-color:#212529;border-radius:16px;overflow:hidden;border:1px solid #3a3f4b;"><tr><td style="background-color:#1E222B;padding:28px 24px;text-align:center;border-bottom:3px solid #87C232;"><table cellpadding="0" cellspacing="0" style="margin:0 auto;"><tr><td style="padding-right:16px;vertical-align:middle;"><img src="${LOGO_URL}" alt="CoachSmart" width="80" style="display:block;height:auto;border:0;"></td><td style="vertical-align:middle;text-align:left;"><p style="margin:0;font-size:26px;font-weight:900;letter-spacing:2.5px;line-height:1;font-family:Arial,Helvetica,sans-serif;"><span style="color:#c8ccd0;">COACH</span><span style="color:#87C232;">SMART</span></p><p style="margin:5px 0 0 0;font-size:9px;font-weight:700;letter-spacing:4px;color:#87C232;font-family:Arial,Helvetica,sans-serif;">COACHING&nbsp;&nbsp;MADE&nbsp;&nbsp;SIMPLE</p></td></tr></table></td></tr><tr><td style="padding:28px 28px 24px;"><p style="margin:0 0 20px 0;font-size:15px;color:#e7ebee;font-family:Arial,Helvetica,sans-serif;">Hi ${firstName},</p><p style="margin:0 0 12px 0;font-size:15px;color:#e7ebee;font-family:Arial,Helvetica,sans-serif;">Your squad sheet has been exported successfully and is attached as an <strong>XLSX</strong> file.</p><p style="margin:0 0 24px 0;font-size:16px;font-weight:700;color:#e7ebee;font-family:Arial,Helvetica,sans-serif;">${sheetTitle}</p></td></tr><tr><td style="padding:16px 28px;border-top:1px solid #3a3f4b;text-align:center;"><p style="margin:0 0 4px 0;font-size:11px;color:#555;letter-spacing:1.5px;font-family:Arial,Helvetica,sans-serif;">COACHSMART &middot; COACHING MADE SIMPLE</p><p style="margin:0;font-size:11px;color:#444;font-family:Arial,Helvetica,sans-serif;">You received this because you are a member of a CoachSmart team.</p></td></tr></table></td></tr></table></body></html>`;
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
    const userNameRows = await sql`
      SELECT m.first_name FROM public.users u
      JOIN public.user_member_link uml ON u.user_id = uml.user_id
      JOIN public.members m ON uml.member_id = m.member_id
      WHERE u.email_address = ${user_email} AND m.status != 'deleted' LIMIT 1
    `;
    const firstName = userNameRows?.[0]?.first_name || 'there';
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
      html: getEmailHtml(reportTitle, firstName),
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
