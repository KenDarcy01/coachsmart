import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import postgres from "https://deno.land/x/postgresjs@v3.3.3/mod.js";
import { z } from "https://deno.land/x/zod@v3.21.4/mod.ts";

const RequestSchema = z.object({
  event_id: z.coerce.string(),
  user_email: z.string().email(),
  match_squad_id: z.coerce.string()
});

const jsonReplacer = (_key: string, value: unknown) =>
  typeof value === 'bigint' ? value.toString() : value;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization"
};

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const DATABASE_URL  = Deno.env.get("SUPABASE_DB_URL");

const sql = postgres(DATABASE_URL!, { prepare: false });

// ---------------------------------------------------------------------------
// Google OAuth token via service account (same pattern as FCM)
// ---------------------------------------------------------------------------

function pemToBinary(pem: string): ArrayBuffer {
  const base64 = pem
    .trim()
    .split("\n")
    .filter(l => !l.includes("BEGIN") && !l.includes("END"))
    .join("");
  const binary = atob(base64);
  const buf = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) buf[i] = binary.charCodeAt(i);
  return buf.buffer;
}

async function getGoogleAccessToken(clientEmail: string, privateKey: string): Promise<string> {
  const now  = Math.floor(Date.now() / 1000);
  const header  = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss:   clientEmail,
    scope: "https://www.googleapis.com/auth/spreadsheets https://www.googleapis.com/auth/drive",
    aud:   "https://oauth2.googleapis.com/token",
    iat:   now,
    exp:   now + 3600,
  };

  const enc = (obj: unknown) =>
    btoa(JSON.stringify(obj)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');

  const unsigned = `${enc(header)}.${enc(payload)}`;

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToBinary(privateKey),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", cryptoKey, new TextEncoder().encode(unsigned));
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');

  const jwt = `${unsigned}.${sigB64}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!tokenRes.ok) {
    const text = await tokenRes.text();
    throw new Error(`Google token exchange failed (${tokenRes.status}): ${text}`);
  }
  const { access_token } = await tokenRes.json();
  return access_token;
}

// ---------------------------------------------------------------------------
// Sheets helpers
// ---------------------------------------------------------------------------

async function createSpreadsheet(token: string, title: string): Promise<{ spreadsheetId: string; spreadsheetUrl: string }> {
  const res = await fetch("https://sheets.googleapis.com/v4/spreadsheets", {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ properties: { title } }),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Sheets create failed (${res.status}): ${text}`);
  }
  const { spreadsheetId, spreadsheetUrl } = await res.json();
  return { spreadsheetId, spreadsheetUrl };
}

async function writeSheetValues(token: string, spreadsheetId: string, values: unknown[][]): Promise<void> {
  const res = await fetch(
    `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}/values/A1?valueInputOption=RAW`,
    {
      method: "PUT",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ values }, jsonReplacer),
    }
  );
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Sheets write failed (${res.status}): ${text}`);
  }
}

async function shareFile(token: string, fileId: string, type: string, role: string, emailAddress?: string): Promise<void> {
  const body: Record<string, string> = { type, role };
  if (emailAddress) body.emailAddress = emailAddress;

  const params = new URLSearchParams({ sendNotificationEmail: "false" });
  const res = await fetch(
    `https://www.googleapis.com/drive/v3/files/${fileId}/permissions?${params}`,
    {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify(body),
    }
  );
  if (!res.ok) {
    const text = await res.text();
    console.warn(`Share (${type}/${role}) failed (${res.status}): ${text}`);
  }
}

// ---------------------------------------------------------------------------
// Formatting
// ---------------------------------------------------------------------------

type RGB = { red: number; green: number; blue: number };

const SQUAD_BG: Record<string, RGB> = {
  blue:   { red: 0.051, green: 0.278, blue: 0.812 },
  red:    { red: 0.800, green: 0.000, blue: 0.000 },
  green:  { red: 0.204, green: 0.659, blue: 0.325 },
  black:  { red: 0.200, green: 0.200, blue: 0.200 },
  purple: { red: 0.612, green: 0.153, blue: 0.690 },
  orange: { red: 1.000, green: 0.596, blue: 0.000 },
  yellow: { red: 1.000, green: 0.922, blue: 0.231 },
  white:  { red: 0.850, green: 0.850, blue: 0.850 },
};
const DEFAULT_SQUAD_BG: RGB = { red: 0.118, green: 0.133, blue: 0.169 }; // #1E222B
const LIGHT_TEXT_COLORS = new Set(["yellow", "orange", "white"]);

function getSquadColor(squadName: string): { bg: RGB; darkText: boolean } {
  const lower = squadName.toLowerCase();
  for (const [key, bg] of Object.entries(SQUAD_BG)) {
    if (lower.includes(key)) return { bg, darkText: LIGHT_TEXT_COLORS.has(key) };
  }
  return { bg: DEFAULT_SQUAD_BG, darkText: false };
}

async function applyFormatting(
  token: string,
  spreadsheetId: string,
  rowMetas: Array<{ type: "squad" | "role" | "member"; squadName: string }>
): Promise<void> {
  const ROLE_BG: RGB  = { red: 0.851, green: 0.851, blue: 0.851 };
  const WHITE: RGB    = { red: 1, green: 1, blue: 1 };
  const BLACK: RGB    = { red: 0, green: 0, blue: 0 };

  const requests: unknown[] = [
    // Column A narrow indent, column B wide content
    { updateDimensionProperties: { range: { sheetId: 0, dimension: "COLUMNS", startIndex: 0, endIndex: 1 }, properties: { pixelSize: 20 }, fields: "pixelSize" } },
    { updateDimensionProperties: { range: { sheetId: 0, dimension: "COLUMNS", startIndex: 1, endIndex: 2 }, properties: { pixelSize: 300 }, fields: "pixelSize" } },
  ];

  for (let i = 0; i < rowMetas.length; i++) {
    const { type, squadName } = rowMetas[i];
    const rowRange = { sheetId: 0, startRowIndex: i, endRowIndex: i + 1, startColumnIndex: 0, endColumnIndex: 5 };

    if (type === "squad") {
      const { bg, darkText } = getSquadColor(squadName);
      requests.push({
        repeatCell: {
          range: rowRange,
          cell: { userEnteredFormat: { backgroundColor: bg, textFormat: { bold: true, fontSize: 11, foregroundColor: darkText ? BLACK : WHITE } } },
          fields: "userEnteredFormat(backgroundColor,textFormat)",
        },
      });
    } else if (type === "role") {
      requests.push({
        repeatCell: {
          range: rowRange,
          cell: { userEnteredFormat: { backgroundColor: ROLE_BG, textFormat: { bold: true, fontSize: 10 } } },
          fields: "userEnteredFormat(backgroundColor,textFormat)",
        },
      });
    }
  }

  const res = await fetch(
    `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}:batchUpdate`,
    {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ requests }),
    }
  );
  if (!res.ok) {
    const text = await res.text();
    console.warn(`Sheet formatting failed (${res.status}): ${text}`);
  }
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

const handler = async (request: Request): Promise<Response> => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  console.log("--- STARTING EXPORT PROCESS ---");

  try {
    const body = await request.json();
    const { event_id, user_email, match_squad_id } = RequestSchema.parse(body);

    // ── STEP 1: Database ──────────────────────────────────────────────────
    console.log("[STEP 1/4] Querying database...");
    const rows = await sql`
      SELECT
        s.squad_name, r.role_name_plural,
        (m.first_name || ' ' || m.last_name) AS full_member_name,
        r.role_list_seq, sq_team.team_name, e.event_title,
        to_char(e.event_date_time, 'Month DD, YYYY HH:MI AM') AS formatted_event_date_time,
        s.squad_list_seq, ec.event_code, et.event_type, e.opposition, ev_team.team_female
      FROM public.match_squad_details msd
      JOIN public.match_squads ms ON msd.match_squad_id = ms.match_squad_id
      JOIN public.members m       ON msd.member_id = m.member_id
      JOIN public.roles r         ON msd.role_id = r.role_id
      JOIN public.events e        ON ms.event_id = e.event_id
      LEFT JOIN public.squads s         ON msd.squad_id = s.squad_id
      LEFT JOIN public.teams sq_team    ON s.team_id = sq_team.team_id
      INNER JOIN public.teams ev_team   ON e.team_id = ev_team.team_id
      LEFT JOIN public.event_codes ec   ON e.event_code_id = ec.code_id
      LEFT JOIN public.event_types et   ON e.event_type_id = et.event_type_id
      WHERE ms.event_id = ${event_id}
        AND ms.match_squad_id = ${match_squad_id}
      ORDER BY s.squad_list_seq ASC, (m.first_name || ' ' || m.last_name) ASC
    `;

    if (rows.length === 0) {
      return new Response(JSON.stringify({ error: "No data found." }), {
        status: 404,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    // ── Build sheet title ─────────────────────────────────────────────────
    const first = rows[0];
    let displayCode = first.event_code || "";
    if (displayCode === "Hurling" && (first.team_female === "YES" || first.team_female === true)) {
      displayCode = "Camogie";
    }
    let displayTitle = first.event_title;
    const baseFallback = `${displayCode} ${first.event_type || ""}`.trim();
    if (!displayTitle || displayTitle.trim() === "") displayTitle = baseFallback || "Event";
    if (first.event_type === "Match" && first.opposition?.trim()) {
      displayTitle = `${displayTitle} - ${first.opposition.trim()}`;
    }
    const sheetTitle = `Teams - ${first.team_name} (${displayTitle}) - ${first.formatted_event_date_time}`;

    // ── Organise rows into squads → roles → members ───────────────────────
    const organizedData  = new Map<string, Map<string, { members: Set<string>; seq: number }>>();
    const squadSequences = new Map<string, number>();
    const assignedMembers = new Set<string>();

    for (const row of rows) {
      const { squad_name, role_name_plural, full_member_name, role_list_seq, squad_list_seq } = row;
      if (!squad_name || !full_member_name) continue;
      if (squad_list_seq !== null) squadSequences.set(squad_name, squad_list_seq);
      if (squad_name !== "No Team") assignedMembers.add(full_member_name);
      if (!organizedData.has(squad_name)) organizedData.set(squad_name, new Map());
      const squadMap = organizedData.get(squad_name)!;
      if (!squadMap.has(role_name_plural)) squadMap.set(role_name_plural, { members: new Set(), seq: role_list_seq });
      squadMap.get(role_name_plural)!.members.add(full_member_name);
    }

    const squadNames = Array.from(organizedData.keys());
    const sortedSquads = [
      ...squadNames.filter(n => n !== "No Team").sort((a, b) =>
        (squadSequences.get(a) ?? 999) - (squadSequences.get(b) ?? 999) || a.localeCompare(b)
      ),
      ...squadNames.filter(n => n === "No Team"),
    ];

    const dataForSheet: string[][] = [];
    const rowMetas: Array<{ type: "squad" | "role" | "member"; squadName: string }> = [];

    for (const squadName of sortedSquads) {
      dataForSheet.push(["", squadName]);
      rowMetas.push({ type: "squad", squadName });

      const rolesMap = organizedData.get(squadName)!;
      const roles = Array.from(rolesMap.keys())
        .map(name => ({ name, seq: rolesMap.get(name)!.seq }))
        .sort((a, b) => a.seq - b.seq);
      for (const role of roles) {
        let members = Array.from(rolesMap.get(role.name)!.members);
        if (squadName === "No Team") members = members.filter(m => !assignedMembers.has(m));
        if (members.length > 0) {
          dataForSheet.push(["", role.name]);
          rowMetas.push({ type: "role", squadName });
          members.sort().forEach(m => {
            dataForSheet.push(["", m]);
            rowMetas.push({ type: "member", squadName });
          });
        }
      }
    }

    // ── STEP 2: Google auth ───────────────────────────────────────────────
    console.log("[STEP 2/4] Getting Google access token...");
    const clientEmail = Deno.env.get("GOOGLE_CLIENT_EMAIL");
    const privateKey  = Deno.env.get("GOOGLE_PRIVATE_KEY")?.replace(/\\n/g, "\n");
    if (!clientEmail || !privateKey) throw new Error("Missing GOOGLE_CLIENT_EMAIL or GOOGLE_PRIVATE_KEY");
    const googleToken = await getGoogleAccessToken(clientEmail, privateKey);

    // ── STEP 3: Create sheet + write data ─────────────────────────────────
    console.log("[STEP 3/4] Creating spreadsheet and writing data...");
    const { spreadsheetId, spreadsheetUrl } = await createSpreadsheet(googleToken, sheetTitle);
    await writeSheetValues(googleToken, spreadsheetId, dataForSheet);
    await applyFormatting(googleToken, spreadsheetId, rowMetas);

    // Share: requesting user gets writer access; anyone with the link can view
    await shareFile(googleToken, spreadsheetId, "user",   "writer", user_email);
    await shareFile(googleToken, spreadsheetId, "anyone", "reader");

    console.log("[STEP 4/4] Sending email to", user_email);

    // ── STEP 4: Email ─────────────────────────────────────────────────────
    const emailHtml = `
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="margin:0;padding:0;background-color:#f7fafc;font-family:Arial,sans-serif;">
  <table border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color:#1E222B;padding:20px 0;">
    <tr><td align="center"><table border="0" cellpadding="0" cellspacing="0" width="600" style="max-width:600px;background-color:#1E222B;">
      <tr><td align="center" style="padding:20px 0;">
        <h1 style="margin:0;font-size:28px;color:#87C232;font-family:Arial,sans-serif;font-weight:bold;">CoachSmart</h1>
        <p style="margin:5px 0 0;font-size:14px;color:#ffffff;letter-spacing:1px;">COACHING MADE SIMPLE</p>
      </td></tr>
      <tr><td style="padding:40px 30px;border-radius:8px;">
        <p style="color:#ffffff;font-size:16px;line-height:1.5;margin:0 0 20px;">Hi there,</p>
        <p style="color:#ffffff;font-size:16px;line-height:1.5;margin:0 0 20px;">
          Your team squads for <b>${sheetTitle}</b> have been successfully exported to Google Sheets.
        </p>
        <p style="margin:25px 0 10px;text-align:center;">
          <a href="${spreadsheetUrl}" style="background-color:#87C232;color:#1E222B;padding:12px 25px;text-decoration:none;border-radius:6px;display:inline-block;font-weight:bold;font-size:16px;">View Team Sheet</a>
        </p>
        <p style="margin-top:30px;font-size:14px;color:#b0b0b0;text-align:center;">Copy this link to share:</p>
        <div style="word-break:break-all;font-family:monospace;background-color:#0d1117;color:#87C232;padding:15px;border:1px solid #87C232;border-radius:4px;margin-top:10px;font-size:14px;text-align:center;">${spreadsheetUrl}</div>
        <p style="margin-top:30px;font-size:14px;color:#b0b0b0;text-align:center;">Thanks,<br/>The CoachSmart Team</p>
      </td></tr>
    </table></td></tr>
  </table>
</body>
</html>`;

    await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: "CoachSmart <noreply@coachsmart.app>",
        to: user_email,
        subject: sheetTitle,
        html: emailHtml,
      }),
    });

    console.log("--- EXPORT COMPLETE ---");

    return new Response(JSON.stringify({ status: "success", sheetUrl: spreadsheetUrl }), {
      status: 200,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });

  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`[CRITICAL ERROR] ${msg}`);
    return new Response(JSON.stringify({ error: msg }), {
      status: 500,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
};

serve(handler);
