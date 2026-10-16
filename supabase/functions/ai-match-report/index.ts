// deno-lint-ignore-file no-explicit-any
// Match report webview (webviews/match-report.html).
//
// Actions (all need the caller's JWT, and the caller must be on the event's team):
//   load   { event_id }                      → event, team, squads, ai flag
//   draft  { event_id, transcript, ... }     → { report }  AI tidies the coach's spoken report
//   revise { event_id, report, changes, ... }→ { report }  AI applies spoken/typed additions or corrections
//   save   { event_id, report, squad_id, opposition } → inserts into match_reports and
//          triggers event_match_report_email so the team's admins get it as before.
//
// draft and revise also need users.ai_features (see get_my_ai_features).
// Requires GEMINI_API_KEY; GEMINI_MODEL is optional (same secrets as ai-process-game).
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";
const GEMINI_URL   = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });

// Keep the coach's own words; a club newsletter version may come later.
const DRAFT_PROMPT = `You are helping a GAA (Gaelic Athletic Association) coach write up a match report.
The coach spoke the report out loud and it was converted to text, so it has speech artefacts.

Tidy it up while keeping it the coach's own report:
- Keep the coach's words, voice and point of view (first person stays first person). Do not rewrite it as a newspaper article.
- Remove filler words, false starts, repetition and speech artefacts. Fix grammar and punctuation.
- Fix obvious mis-hearings of GAA terms (e.g. points, goals, wides, frees, 45s, sideline, puck-out, kick-out, hurley, sliotar), player names that appear more than once, and the opposition's name if it was given.
- Keep EVERY fact, score, name, minute, opinion and coaching observation the coach mentioned. Do not summarise or drop anything.
- Do not add anything the coach did not say. Never invent scores, names or events.
- Break it into short paragraphs in the order the coach spoke.

Return ONLY valid JSON: {"report": "<the tidied report>"}`;

const REVISE_PROMPT = `You are helping a GAA (Gaelic Athletic Association) coach edit their match report.
You get the current report and the coach's additions or corrections (often spoken, so they may contain speech artefacts).

- Apply every correction exactly where it belongs in the report.
- Add new information where it fits best in the existing flow.
- If the coach asks to remove something, remove it.
- Leave everything else in the report word for word as it is. Do not restyle, shorten or summarise the rest.
- Keep the coach's voice. Do not add anything the coach did not say. Never invent scores or names.

Return ONLY valid JSON: {"report": "<the full updated report>"}`;

async function callGemini(apiKey: string, systemPrompt: string, userText: string): Promise<string> {
  const body = JSON.stringify({
    system_instruction: { parts: [{ text: systemPrompt }] },
    contents: [{ parts: [{ text: userText }] }],
    generationConfig: { maxOutputTokens: 8192, temperature: 0.2, responseMimeType: "application/json" },
  });

  let res: Response | null = null;
  let errText = "";
  for (let attempt = 1; attempt <= 3; attempt++) {
    res = await fetch(`${GEMINI_URL}?key=${apiKey}`, { method: "POST", headers: { "Content-Type": "application/json" }, body });
    if (res.ok) break;
    errText = await res.text();
    console.warn(`Gemini attempt ${attempt} failed (${res.status}):`, errText.slice(0, 200));
    if (!(res.status === 503 || res.status === 429) || attempt === 3) break;
    await new Promise(r => setTimeout(r, attempt * 1500));
  }
  if (!res!.ok) throw new Error(`Gemini API error ${res!.status}`);

  const data = await res!.json();
  const text = (data.candidates?.[0]?.content?.parts?.[0]?.text || "").trim();
  if (!text) throw new Error(`Gemini returned empty response (${data.candidates?.[0]?.finishReason || "unknown"})`);

  const cleaned = text.replace(/^```json\s*/i, "").replace(/^```\s*/i, "").replace(/\s*```$/i, "").trim();
  try {
    const parsed = JSON.parse(cleaned);
    if (typeof parsed?.report === "string" && parsed.report.trim()) return parsed.report.trim();
  } catch { /* fall through */ }
  throw new Error("Gemini returned an unexpected format");
}

async function loadReports(sb: any, eventId: number, squads: { squad_id: number; squad_name: string }[]) {
  const { data: rows } = await sb.from("match_reports")
    .select("id, created_at, user_id, match_report, squad_id, opposition")
    .eq("event_id", eventId).order("created_at", { ascending: false });
  if (!rows?.length) return [];
  const userIds = [...new Set(rows.map((r: any) => r.user_id).filter(Boolean))];
  const { data: users } = userIds.length
    ? await sb.from("users").select("user_id, first_name, last_name").in("user_id", userIds)
    : { data: [] };
  const names = new Map((users || []).map((u: any) => [u.user_id, `${u.first_name || ""} ${u.last_name || ""}`.trim()]));
  return rows.map((r: any) => ({
    id: r.id,
    created_at: r.created_at,
    author: names.get(r.user_id) || "Unknown",
    squad_name: squads.find(s => s.squad_id === r.squad_id)?.squad_name ?? null,
    opposition: r.opposition,
    report: r.match_report || "",
  }));
}

function matchContext(ev: any, teamName: string, squadName: string | null, opposition: string | null): string {
  const date = ev.event_date_time
    ? new Date(ev.event_date_time).toLocaleDateString("en-IE", { weekday: "long", day: "numeric", month: "long", year: "numeric", timeZone: "Europe/Dublin" })
    : "";
  return [
    `Team: ${teamName}${squadName ? ` (${squadName})` : ""}`,
    opposition ? `Opposition: ${opposition}` : null,
    ev.event_title ? `Match: ${ev.event_title}` : null,
    date ? `Date: ${date}` : null,
  ].filter(Boolean).join("\n");
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const body = await req.json();
    const { action } = body;
    const eventId = Number(body.event_id);
    if (!eventId) return json({ error: "event_id required" }, 400);

    const SUPABASE_URL     = Deno.env.get("SUPABASE_URL")!;
    const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

    // ── Caller ──
    const jwt = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
    const { data: { user }, error: userErr } = await sb.auth.getUser(jwt);
    if (userErr || !user) return json({ error: "Please sign in again" }, 401);

    // ── Event, and the caller must be on its team ──
    const { data: ev } = await sb.from("events")
      .select("event_id, event_title, event_date_time, opposition, home_away, squad_id, team_id")
      .eq("event_id", eventId).maybeSingle();
    if (!ev) return json({ error: "Match not found" }, 404);

    // Active memberships on the event's team, and the caller's highest role level there
    // (same rule as get_user_home_events).
    const { data: links } = await sb.from("user_member_link").select("member_id")
      .eq("user_id", user.id).eq("status", "active");
    const memberIds = (links || []).map((l: any) => l.member_id).filter(Boolean);
    const { data: teamLinks } = memberIds.length
      ? await sb.from("member_team_link").select("member_team_id")
          .eq("team_id", ev.team_id).eq("status", "active").in("member_id", memberIds)
      : { data: [] as any[] };
    const memberTeamIds = (teamLinks || []).map((l: any) => l.member_team_id);
    if (!memberTeamIds.length) return json({ error: "You're not on this team" }, 403);

    const { data: roleRows } = await sb.from("member_team_role_link")
      .select("roles!inner(role_level)").in("member_team_id", memberTeamIds);
    const roleLevel = Math.max(0, ...(roleRows || []).map((r: any) => Number(r.roles?.role_level) || 0));

    const [{ data: team }, { data: squads }, { data: me }] = await Promise.all([
      sb.from("teams").select("team_name").eq("team_id", ev.team_id).maybeSingle(),
      sb.from("squads").select("squad_id, squad_name, squad_list_seq").eq("team_id", ev.team_id)
        .order("squad_list_seq", { ascending: true, nullsFirst: false }).order("squad_name"),
      sb.from("users").select("ai_features").eq("user_id", user.id).maybeSingle(),
    ]);
    const teamName = team?.team_name || "";
    const aiEnabled = me?.ai_features === true;
    const squadList = (squads || []).map((s: any) => ({ squad_id: s.squad_id, squad_name: s.squad_name }));

    const squadId = body.squad_id == null || body.squad_id === "" ? null : Number(body.squad_id);
    if (squadId !== null && !squadList.some(s => s.squad_id === squadId)) {
      return json({ error: "That squad isn't on this team" }, 400);
    }
    // One squad on the team: that's the squad. More than one: the coach must pick.
    const effectiveSquadId = squadId ?? (squadList.length === 1 ? squadList[0].squad_id : null);
    const squadName = squadList.find(s => s.squad_id === effectiveSquadId)?.squad_name ?? null;
    const opposition = typeof body.opposition === "string" && body.opposition.trim() ? body.opposition.trim().slice(0, 120) : null;

    // ── LOAD ──
    if (action === "load") {
      return json({
        success: true,
        data: {
          event: {
            event_id: ev.event_id, event_title: ev.event_title, event_date_time: ev.event_date_time,
            home_away: ev.home_away,
          },
          team_name: teamName,
          squads: squadList,
          ai_enabled: aiEnabled,
          // Earlier reports for this match: management (role level 100+) only, as in FlutterFlow.
          reports: roleLevel >= 100 ? await loadReports(sb, eventId, squadList) : null,
        },
      });
    }

    // ── DRAFT / REVISE ──
    if (action === "draft" || action === "revise") {
      if (!aiEnabled) return json({ error: "AI features are not switched on for your account" }, 403);
      const apiKey = Deno.env.get("GEMINI_API_KEY");
      if (!apiKey) return json({ error: "GEMINI_API_KEY not configured" }, 500);
      const context = matchContext(ev, teamName, squadName, opposition);

      if (action === "draft") {
        const transcript = String(body.transcript || "").trim();
        if (!transcript) return json({ error: "Nothing was recorded" }, 400);
        const report = await callGemini(apiKey, DRAFT_PROMPT, `${context}\n\nWhat the coach said:\n"""${transcript}"""`);
        return json({ success: true, data: { report } });
      }

      const current = String(body.report || "").trim();
      const changes = String(body.changes || "").trim();
      if (!changes) return json({ error: "Nothing was recorded" }, 400);
      const report = await callGemini(apiKey, REVISE_PROMPT,
        `${context}\n\nCurrent report:\n"""${current}"""\n\nCoach's additions or corrections:\n"""${changes}"""`);
      return json({ success: true, data: { report } });
    }

    // ── SAVE ──
    if (action === "save") {
      const report = String(body.report || "").trim();
      if (!report) return json({ error: "The match report is empty" }, 400);
      if (!opposition) return json({ error: "Please enter the opposition" }, 400);
      if (squadList.length > 1 && effectiveSquadId === null) return json({ error: "Please select a squad" }, 400);

      const { data: row, error: insErr } = await sb.from("match_reports").insert({
        event_id: eventId, user_id: user.id, match_report: report, squad_id: effectiveSquadId, opposition,
      }).select("id").single();
      if (insErr || !row) {
        console.error("match_reports insert failed:", insErr);
        return json({ error: "Could not save the report" }, 500);
      }

      // Same email to the team's admins as the FlutterFlow page sends.
      let emailed = false;
      try {
        const res = await fetch(`${SUPABASE_URL}/functions/v1/event_match_report_email`, {
          method: "POST",
          headers: { "Content-Type": "application/json", "Authorization": `Bearer ${SERVICE_ROLE_KEY}` },
          body: JSON.stringify({ p_event_id: eventId, p_report_id: row.id }),
        });
        emailed = res.ok;
        if (!res.ok) console.error("event_match_report_email failed:", res.status, (await res.text()).slice(0, 300));
      } catch (e) {
        console.error("event_match_report_email error:", e);
      }

      return json({ success: true, data: { id: row.id, emailed } });
    }

    return json({ error: `Unknown action: ${action}` }, 400);
  } catch (err) {
    console.error("ai-match-report error:", err);
    return json({ error: (err as Error).message || "Something went wrong" }, 500);
  }
});
