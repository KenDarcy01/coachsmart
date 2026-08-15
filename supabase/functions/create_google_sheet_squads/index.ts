import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import postgres from "https://deno.land/x/postgresjs@v3.3.3/mod.js";
import { z } from "https://deno.land/x/zod@v3.21.4/mod.ts";

const RequestSchema = z.object({
  event_id: z.coerce.string(),
  user_email: z.string().email(),
  match_squad_id: z.coerce.string(),
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
    { updateDimensionProperties: { range: { sheetId: 0, dimension: "COLUMNS", startIndex: 1, endIndex: 2 }, properties: { pixelSize: 240 }, fields: "pixelSize" } },
  ];

  for (let i = 0; i < rowMetas.length; i++) {
    const { type, squadName } = rowMetas[i];
    const rowRange = { sheetId: 0, startRowIndex: i, endRowIndex: i + 1, startColumnIndex: 1, endColumnIndex: 2 };

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

    // ── STEP 1: DB query + Google auth in parallel ────────────────────────
    console.log("[STEP 1/3] Querying database and getting Google token...");
    const clientEmail = Deno.env.get("GOOGLE_CLIENT_EMAIL");
    const privateKey  = Deno.env.get("GOOGLE_PRIVATE_KEY")?.replace(/\\n/g, "\n");
    if (!clientEmail || !privateKey) throw new Error("Missing GOOGLE_CLIENT_EMAIL or GOOGLE_PRIVATE_KEY");

    const [rows, adminRows, googleToken] = await Promise.all([
      sql`
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
      `,
      sql`
        SELECT DISTINCT u.email_address
        FROM public.events e
        JOIN public.member_team_link mtl      ON e.team_id = mtl.team_id AND mtl.status = 'active'
        JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN public.roles r                    ON mtrl.role_id = r.role_id AND r.role_grade = 100
        JOIN public.members m                  ON mtl.member_id = m.member_id AND m.status != 'deleted'
        JOIN public.user_member_link uml       ON m.member_id = uml.member_id
        JOIN public.users u                    ON uml.user_id = u.user_id
        WHERE e.event_id = ${event_id}
          AND u.email_address IS NOT NULL
          AND u.email_address != ''
      `,
      getGoogleAccessToken(clientEmail, privateKey),
    ]);

    const adminEmails = adminRows.map((r: { email_address: string }) => r.email_address);

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

    // ── STEP 2: Create sheet + write data ────────────────────────────────
    console.log("[STEP 2/3] Creating spreadsheet and writing data...");
    const { spreadsheetId, spreadsheetUrl } = await createSpreadsheet(googleToken, sheetTitle);
    await writeSheetValues(googleToken, spreadsheetId, dataForSheet);

    // ── STEP 3: Format + share + email in parallel ────────────────────────
    console.log("[STEP 3/3] Formatting, sharing and sending email...");

    const logoUrl = 'https://gyfporsbdftvtakdvukt.supabase.co/storage/v1/object/sign/coachsmartimages/CoachSmart%20Logo%20Transparent.png?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV82OTA4NmRkYy01MWQ3LTQ1NzUtYWYwMC1mZjQxYmMyNDU2YWMiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJjb2FjaHNtYXJ0aW1hZ2VzL0NvYWNoU21hcnQgTG9nbyBUcmFuc3BhcmVudC5wbmciLCJpYXQiOjE3NzQ2MDYzOTksImV4cCI6MjYzODYwNjM5OX0.20yMzSYnG08kYjMK6cmGMvwA6VPGvm9_yHG-CmEfSIs';
    const emailHtml = `<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>CoachSmart</title></head><body style="margin:0;padding:0;background-color:#111418;font-family:Arial,Helvetica,sans-serif;"><table width="100%" cellpadding="0" cellspacing="0" style="padding:40px 20px;"><tr><td align="center"><table width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background-color:#212529;border-radius:16px;overflow:hidden;border:1px solid #3a3f4b;"><tr><td style="background-color:#1E222B;padding:28px 24px;text-align:center;border-bottom:3px solid #87C232;"><table cellpadding="0" cellspacing="0" style="margin:0 auto;"><tr><td style="padding-right:16px;vertical-align:middle;"><img src="${logoUrl}" alt="CoachSmart" width="80" style="display:block;height:auto;border:0;"></td><td style="vertical-align:middle;text-align:left;"><p style="margin:0;font-size:26px;font-weight:900;letter-spacing:2.5px;line-height:1;font-family:Arial,Helvetica,sans-serif;"><span style="color:#c8ccd0;">COACH</span><span style="color:#87C232;">SMART</span></p><p style="margin:5px 0 0 0;font-size:9px;font-weight:700;letter-spacing:4px;color:#87C232;font-family:Arial,Helvetica,sans-serif;">COACHING&nbsp;&nbsp;MADE&nbsp;&nbsp;SIMPLE</p></td></tr></table></td></tr><tr><td style="padding:28px 28px 24px;"><p style="margin:0 0 20px 0;font-size:15px;color:#e7ebee;font-family:Arial,Helvetica,sans-serif;">Hi there,</p><p style="margin:0 0 24px 0;font-size:15px;color:#e7ebee;font-family:Arial,Helvetica,sans-serif;">Your team squads for <strong>${sheetTitle}</strong> have been successfully exported to Google Sheets.</p><p style="margin:0 0 24px 0;text-align:center;"><a href="${spreadsheetUrl}" style="background-color:#87C232;color:#1E222B;padding:12px 28px;text-decoration:none;border-radius:6px;display:inline-block;font-weight:bold;font-size:16px;font-family:Arial,Helvetica,sans-serif;">View Team Sheet</a></p><p style="margin:0 0 10px 0;font-size:14px;color:#a3a3a3;text-align:center;font-family:Arial,Helvetica,sans-serif;">Copy this link to share:</p><div style="word-break:break-all;font-family:monospace;background-color:#0d1117;color:#87C232;padding:15px;border:1px solid #87C232;border-radius:4px;font-size:14px;text-align:center;">${spreadsheetUrl}</div></td></tr><tr><td style="padding:16px 28px;border-top:1px solid #3a3f4b;text-align:center;"><p style="margin:0 0 4px 0;font-size:11px;color:#555;letter-spacing:1.5px;font-family:Arial,Helvetica,sans-serif;">COACHSMART &middot; COACHING MADE SIMPLE</p><p style="margin:0;font-size:11px;color:#444;font-family:Arial,Helvetica,sans-serif;">You received this because you are a member of a CoachSmart team.</p></td></tr></table></td></tr></table></body></html>`;

    // Grant writer to calling user + all team admins (deduped)
    const editors = [...new Set([user_email, ...adminEmails])];

    await Promise.all([
      applyFormatting(googleToken, spreadsheetId, rowMetas),
      ...editors.map(email => shareFile(googleToken, spreadsheetId, "user", "writer", email)),
      shareFile(googleToken, spreadsheetId, "anyone", "reader"),
      fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${RESEND_API_KEY}` },
        body: JSON.stringify({
          from: "CoachSmart <noreply@coachsmart.app>",
          to: user_email,
          subject: sheetTitle,
          html: emailHtml,
        }),
      }),
    ]);

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
