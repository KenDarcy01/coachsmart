import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import postgres from "https://deno.land/x/postgresjs@v3.3.3/mod.js";
import { Resend } from 'https://esm.sh/resend@3.2.0';
import ExcelJS from 'https://esm.sh/exceljs@4.4.0';
import { z } from "https://deno.land/x/zod@v3.21.4/mod.ts";
import { encodeBase64 } from "https://deno.land/std@0.203.0/encoding/base64.ts";
const RequestSchema = z.object({
  p_team_id: z.coerce.number(),
  user_email: z.string().email()
});
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const DATABASE_URL = Deno.env.get("SUPABASE_DB_URL");
const sql = postgres(DATABASE_URL, {
  prepare: false
});
const resend = new Resend(RESEND_API_KEY);
const HEADER_STYLE = {
  fill: {
    type: 'pattern',
    pattern: 'solid',
    fgColor: {
      argb: 'FF1E222B'
    }
  },
  font: {
    name: 'Arial',
    bold: true,
    color: {
      argb: 'FFFFFFFF'
    }
  }
};
const getEmailHtml = (teamName)=>`
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"></head>
<body style="margin: 0; padding: 20px; background-color: #1E222B; font-family: Arial, sans-serif;">
    <table border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 600px; margin: auto;">
        <tr><td style="background-color: #2D323E; padding: 40px 20px; border-radius: 8px 8px 0 0; text-align: center; border-bottom: 10px solid #1E222B;">
            <h1 style="margin: 0; font-size: 28px; color: #87C232; font-weight: bold;">CoachSmart</h1>
            <p style="margin: 10px 0 0; font-size: 14px; color: #ffffff; letter-spacing: 2px; text-transform: uppercase;">COACHING MADE SIMPLE</p>
        </td></tr>
        <tr><td style="background-color: #2D323E; padding: 30px; border-radius: 0 0 8px 8px;">
            <div style="background-color: #1E222B; border-left: 4px solid #87C232; padding: 25px; border-radius: 4px;">
                <p style="margin: 0; color: #ffffff; font-size: 16px; line-height: 1.6;">
                    The full team member list and squad assignments for <b>${teamName}</b> has been successfully exported and is attached to this email as an <b>XLSX</b> file.
                </p>
            </div>
            <p style="margin-top: 30px; margin-bottom: 0; text-align: center; color: #b0b0b0; font-size: 12px;">
                This is an automated message. Please do not reply.
            </p>
        </td></tr>
    </table>
</body>
</html>`;
serve(async (req)=>{
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "Content-Type"
      }
    });
  }
  try {
    const { p_team_id, user_email } = RequestSchema.parse(await req.json());
    // 1. Fetch team info including the team_female flag
    const teamInfo = await sql`SELECT team_name, club_id, team_female FROM public.teams WHERE team_id = ${p_team_id}`;
    if (!teamInfo.length) throw new Error("Team not found.");
    const { team_name, club_id, team_female } = teamInfo[0];
    // 2. Fetch codes and apply the name swap logic for the Excel Headers
    const teamCodes = await sql`
      SELECT ec.code_id, 
             CASE 
               WHEN ${team_female} = true AND ec.event_code = 'Hurling' THEN 'Camogie'
               ELSE ec.event_code 
             END as event_code
      FROM public.event_codes ec
      JOIN public.club_code_link ccl ON ec.code_id = ccl.code_id
      WHERE ccl.club_id = ${club_id} AND ec.code_id != 1
      ORDER BY ec.event_code ASC
    `;
    const members = await sql`
      WITH member_roles AS (
        SELECT 
          m.member_id, m.first_name, m.last_name, r.role_name, r.role_level,
          ROW_NUMBER() OVER(PARTITION BY m.member_id ORDER BY r.role_level ASC) as rn
        FROM public.members m
        JOIN public.member_team_link mtl ON m.member_id = mtl.member_id
        JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN public.roles r ON mtrl.role_id = r.role_id
        WHERE mtl.team_id = ${p_team_id}
      ),
      member_squads AS (
        SELECT msl.member_id, msl.code_id, s.squad_name
        FROM public.member_squad_link msl
        JOIN public.squads s ON msl.squad_id = s.squad_id
        WHERE msl.team_id = ${p_team_id} AND msl.code_id != 1
      )
      SELECT 
        mr.first_name, mr.last_name, mr.role_name, mr.role_level,
        (SELECT json_object_agg(code_id, squad_name) FROM member_squads ms WHERE ms.member_id = mr.member_id) as squads
      FROM member_roles mr
      WHERE mr.rn = 1
      ORDER BY mr.role_level ASC, mr.first_name ASC
    `;
    const workbook = new ExcelJS.Workbook();
    const worksheet = workbook.addWorksheet('Team List');
    // The event_code in dynamicCols now reflects "Camogie" where appropriate
    const dynamicCols = teamCodes.map((c)=>({
        header: c.event_code,
        key: `c_${c.code_id}`,
        width: 20
      }));
    worksheet.columns = [
      {
        header: 'Member Name',
        key: 'name',
        width: 35
      },
      {
        header: 'Role',
        key: 'role',
        width: 20
      },
      ...dynamicCols
    ];
    const headerRow = worksheet.getRow(1);
    headerRow.eachCell((cell)=>{
      cell.fill = HEADER_STYLE.fill;
      cell.font = HEADER_STYLE.font;
    });
    members.forEach((m)=>{
      const rowData = {
        name: `${m.first_name} ${m.last_name}`,
        role: m.role_name
      };
      teamCodes.forEach((code)=>{
        rowData[`c_${code.code_id}`] = m.squads?.[code.code_id] || '-';
      });
      worksheet.addRow(rowData);
    });
    const buffer = await workbook.xlsx.writeBuffer();
    const base64Xlsx = encodeBase64(new Uint8Array(buffer));
    const fileName = `${team_name.replace(/\s+/g, '_')}_Team_List.xlsx`;
    await resend.emails.send({
      from: 'CoachSmart <noreply@coachsmart.app>',
      to: [
        user_email
      ],
      subject: `Team List Export - ${team_name}`,
      html: getEmailHtml(team_name),
      attachments: [
        {
          filename: fileName,
          content: base64Xlsx
        }
      ]
    });
    return new Response(JSON.stringify({
      status: 'success'
    }), {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Content-Type": "application/json"
      }
    });
  } catch (err) {
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
});
