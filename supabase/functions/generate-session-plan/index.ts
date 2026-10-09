// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";
const GEMINI_URL   = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ── Gemini caller ─────────────────────────────────────────────────────────────
async function callGemini(apiKey: string, systemPrompt: string, parts: any[]): Promise<string> {
  const body = JSON.stringify({
    system_instruction: { parts: [{ text: systemPrompt }] },
    contents: [{ parts }],
    generationConfig: { maxOutputTokens: 8192, temperature: 0.4, responseMimeType: "application/json" },
  });
  let res: Response | null = null, errText = "";
  for (let attempt = 1; attempt <= 3; attempt++) {
    res = await fetch(`${GEMINI_URL}?key=${apiKey}`, {
      method: "POST", headers: { "Content-Type": "application/json" }, body,
    });
    if (res.ok) break;
    errText = await res.text();
    const retryable = res.status === 503 || res.status === 429;
    console.warn(`Gemini attempt ${attempt} failed (${res.status}):`, errText.slice(0, 200));
    if (!retryable || attempt === 3) break;
    await new Promise(r => setTimeout(r, attempt * 1500));
  }
  if (!res!.ok) throw new Error(`Gemini API error ${res!.status}: ${errText.slice(0, 200)}`);
  const data = await res!.json();
  const text = (data.candidates?.[0]?.content?.parts?.[0]?.text || "").trim();
  if (!text) throw new Error(`Gemini returned empty response`);
  return text;
}

// ── Revise-plan prompt ────────────────────────────────────────────────────────
const REVISE_PLAN_PROMPT = `You are an expert GAA (Gaelic Athletic Association) coaching assistant helping a coach refine an existing training session plan.

Make ONLY the changes the feedback asks for — do not rewrite or regenerate anything from scratch. Keep the coach's language, descriptions, and structure where it is already good.

Rules:
- If timing is adjusted, redistribute durations so they still sum to total_duration_mins exactly
- Keep all game_name values exactly as they are (do not rename drills)
- If the feedback is vague (e.g. "more time on passing"), apply it sensibly
- If the request is impossible, set "_refusal" to a short explanation; otherwise "_refusal" must be null

Return ONLY valid JSON matching EXACTLY this schema — no markdown fences, no explanation:
{
  "session_title": "string",
  "session_objective": "string",
  "total_duration_mins": number,
  "pre_session": null | { "duration_mins": number, "description": "string" },
  "warm_up": { "duration_mins": number, "description": "string", "coaching_points": ["string"] },
  "station_setup": null | "string",
  "drills": [{ "game_name": "string", "duration_mins": number, "description": "string", "coaching_points": ["string"], "variation": "string | null" }],
  "cool_down": { "duration_mins": number, "description": "string" },
  "post_session": null | { "duration_mins": number, "description": "string" },
  "_refusal": null | "string"
}`;

// ── System prompt ─────────────────────────────────────────────────────────────
const SESSION_PLAN_PROMPT = `You are an expert GAA (Gaelic Athletic Association) coaching assistant.

Generate a structured training session plan in JSON matching EXACTLY this schema.
Return ONLY valid JSON — no markdown fences, no explanation, nothing before or after the JSON.

{
  "session_title": "string (3–8 words describing the session theme)",
  "session_objective": "string (1–2 sentences: what skill or quality players will develop — NO weather information)",
  "total_duration_mins": number,
  "pre_session": null | {
    "duration_mins": number,
    "description": "string — activity before the warm-up (e.g. team briefing, video review, tactical talk)"
  },
  "warm_up": null | {
    "duration_mins": number,
    "description": "string (how to run the warm-up with this group)",
    "coaching_points": ["string"]
  },
  "station_setup": null | "string — one paragraph explaining how to split the group across the stations and the rotation interval (populate only when Drill mode is STATION ROTATION; must be null when SEQUENTIAL)",
  "drills": [
    {
      "game_name": "string (use the exact game name from the input)",
      "duration_mins": number,
      "description": "string (how to run this game with the given player count)",
      "coaching_points": ["string — 2 to 4 short, actionable coaching cues"],
      "variation": "string or null"
    }
  ],
  "cool_down": null | {
    "duration_mins": number,
    "description": "string"
  },
  "post_session": null | {
    "duration_mins": number,
    "description": "string — activity after the cool-down (e.g. team meeting, debrief, match review)"
  },
  "_refusal": null | "string — a short plain-language explanation of why this request cannot be fulfilled"
}

Rules:
- (pre_session?.duration_mins ?? 0) + (warm_up?.duration_mins ?? 0) + all drills duration_mins + (cool_down?.duration_mins ?? 0) + (post_session?.duration_mins ?? 0) must equal total_duration_mins exactly
- pre_session must be null unless the coach explicitly requests such an activity
- post_session must be null unless the coach explicitly requests a team meeting, debrief, or similar activity in their session notes
- warm_up must be null unless a warm-up game is provided in the context OR the coach's session notes explicitly request a warm-up or warm-up activity; if a game IS provided, use it and allocate at least 10 minutes; if requested in notes without a game, describe a short generic warm-up (e.g. light jog, dynamic stretching, ball handling) of at least 5 minutes
- cool_down must be null unless a cool-down game is provided in the context OR the coach's session notes explicitly request a cool-down, warm-down, or stretch; if a game IS provided, use it and allocate at least 5 minutes; if requested in notes without a game, describe a short generic cool-down (e.g. light jog, static stretching) of at least 5 minutes
- Use the games in the ORDER given — do not reorder them
- Use the EXACT game name from the input in each drill — do not paraphrase or rename
- Adapt each drill to the given player count; note modifications if needed
- Coaching points must be short and actionable
- Use the sport code supplied in the context throughout — never mix football and hurling/camogie language; if the code is Football use football terminology only; if Hurling/Camogie use sliotar/hurl and never mention football
- CRITICAL: Weather is provided for context only — do NOT include weather data or weather text ANYWHERE in the output JSON, not in session_objective, not in descriptions, not in coaching_points, not anywhere. Weather is shown separately.
- Do NOT include player count adjustment notes; adapt the description directly for the given numbers
- When Drill mode is STATION ROTATION: populate "station_setup" with a single paragraph describing how to split the group across the stations and the rotation interval; describe each drill as the station activity only — do NOT repeat split or rotation instructions inside individual drill descriptions; warm-up and cool-down descriptions must address the full group collectively
- When Drill mode is SEQUENTIAL: "station_setup" must be null; describe each drill for the full group performing it together
- If the coach's feedback asks to include a game that is NOT in the provided games list, set "_refusal" to a short explanation and keep all other fields at sensible defaults (do not change the existing plan)
- If the request is physically impossible (e.g., would require more time than the session allows), set "_refusal" to explain why
- If the request is reasonable and achievable, always attempt it and leave "_refusal" as null
- When an existing plan is provided under "EXISTING PLAN TO REVISE", treat it as the base — keep everything that the feedback does not ask to change, and modify only what is explicitly requested. Preserve game names, order and structure unless the feedback changes them`;

// ── Weather text stripper (safety net for Gemini non-compliance) ──────────────
function stripWeatherFromObjective(text: string): string {
  if (!text) return text;
  return text
    .split('\n')
    .map(line => {
      if (/^Weather:/i.test(line.trim())) return '';
      const idx = line.search(/\.\s+Weather:/i);
      if (idx !== -1) return line.slice(0, idx + 1).trim();
      return line;
    })
    .filter(l => l.trim() !== '')
    .join('\n')
    .trim();
}

// ── Weather helpers ───────────────────────────────────────────────────────────
function parseLatLng(pin: string | null): { lat: number; lng: number } | null {
  if (!pin) return null;
  let m: RegExpMatchArray | null;
  m = pin.match(/@(-?\d+\.\d+),(-?\d+\.\d+)/);   if (m) return { lat: +m[1], lng: +m[2] };
  m = pin.match(/[?&]q=(-?\d+\.\d+),(-?\d+\.\d+)/); if (m) return { lat: +m[1], lng: +m[2] };
  m = pin.match(/[?&]ll=(-?\d+\.\d+),(-?\d+\.\d+)/); if (m) return { lat: +m[1], lng: +m[2] };
  m = pin.match(/^(-?\d+\.\d+),\s*(-?\d+\.\d+)$/); if (m) return { lat: +m[1], lng: +m[2] };
  return null;
}

async function geocodeName(name: string): Promise<{ lat: number; lng: number } | null> {
  try {
    const res = await fetch(`https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(name)}&count=1&language=en&format=json`);
    if (!res.ok) return null;
    const d = await res.json();
    const r = d.results?.[0];
    return r ? { lat: r.latitude, lng: r.longitude } : null;
  } catch { return null; }
}

async function fetchWeather(
  locationPin: string | null, locationName: string | null,
  eventDateTime: string | null, county: string | null,
  eventType: string | null,
): Promise<{ summary: string; temp_c: number; precip_pct: number; wind_kmh: number } | null> {
  if (!eventDateTime) return null;
  const eventDate = new Date(eventDateTime);
  const daysAhead = (eventDate.getTime() - Date.now()) / (1000 * 60 * 60 * 24);
  if (daysAhead < -1 || daysAhead > 16) return null;

  let coords = parseLatLng(locationPin);
  if (!coords && locationName) coords = await geocodeName(locationName);
  if (!coords && county)       coords = await geocodeName(`${county}, Ireland`);
  if (!coords) return null;

  try {
    const res = await fetch(
      `https://api.open-meteo.com/v1/forecast?latitude=${coords.lat}&longitude=${coords.lng}` +
      `&hourly=temperature_2m,precipitation_probability,windspeed_10m&timezone=Europe%2FDublin&forecast_days=16`
    );
    if (!res.ok) return null;
    const d = await res.json();
    const targetHour = eventDate.toISOString().slice(0, 13);
    const idx = (d.hourly?.time || []).findIndex((t: string) => t.startsWith(targetHour));
    if (idx === -1) return null;
    const temp   = Math.round(d.hourly.temperature_2m[idx] ?? 10);
    const precip = Math.round(d.hourly.precipitation_probability[idx] ?? 0);
    const wind   = Math.round(d.hourly.windspeed_10m[idx] ?? 0);

    const isFootball = /football/i.test(eventType ?? "");

    const cues: string[] = [];

    // Cold / hot
    if      (temp < 5)  cues.push("very cold — warm base layers and windproofs essential");
    else if (temp < 10) cues.push("cold — warm layers recommended");
    else if (temp < 15) cues.push("cool — light layers advised");

    if (temp >= 20 && precip < 30) cues.push("warm — bring extra water and wear sunscreen");

    // Rain (sport-specific)
    if (precip >= 70) {
      cues.push(isFootball
        ? "heavy rain likely — waterproofs required, football gloves essential"
        : "heavy rain likely — waterproofs required");
    } else if (precip >= 40) {
      cues.push(isFootball
        ? "rain likely — football gloves recommended, waterproofs advised"
        : "rain possible — waterproofs recommended");
    }

    // Wind
    if      (wind >= 50) cues.push("very windy — adjust kicking drills");
    else if (wind >= 30) cues.push("breezy conditions");

    const summary = `${temp}°C · ${precip}% rain · ${wind}km/h wind` +
      (cues.length ? ` — ${cues.join(", ")}` : " — good conditions for training");
    return { summary, temp_c: temp, precip_pct: precip, wind_kmh: wind };
  } catch { return null; }
}

// ── Member counting — all team/squad members (fallback) ───────────────────────
async function countMembers(sb: any, teamId: number, squadId: number | null) {
  let playerCount = 0, coachCount = 0;

  async function countFromMemberList(memberRows: any[]) {
    for (const m of memberRows) {
      const levels: number[] = ((m.member_team_role_link || []) as any[])
        .map((r: any) => r.roles?.role_level)
        .filter((v: any) => v != null);
      if (levels.includes(30)) coachCount++;
      else playerCount++;
    }
  }

  if (squadId) {
    const { data: squadLinks } = await sb
      .from("member_squad_link")
      .select("member_id")
      .eq("squad_id", squadId);
    const memberIds = (squadLinks || []).map((s: any) => s.member_id);
    if (memberIds.length > 0) {
      const { data: members } = await sb
        .from("member_team_link")
        .select("member_id, member_team_role_link!inner(roles!inner(role_level))")
        .eq("team_id", teamId).eq("status", "active").in("member_id", memberIds);
      await countFromMemberList(members || []);
    }
  } else {
    const { data: members } = await sb
      .from("member_team_link")
      .select("member_id, member_team_role_link!inner(roles!inner(role_level))")
      .eq("team_id", teamId).eq("status", "active");
    await countFromMemberList(members || []);
  }

  if (playerCount === 0 && coachCount === 0) playerCount = 15;
  return { playerCount, coachCount };
}

// ── Member counting — accepted attendees only (primary) ───────────────────────
async function countAcceptedAttendees(sb: any, eventId: number, teamId: number, squadId: number | null) {
  const { data: attendance } = await sb
    .from("event_attendance")
    .select("member_id, response_id, created_at")
    .eq("event_id", eventId);

  if (attendance && attendance.length > 0) {
    // Deduplicate: keep the latest response per member
    const latestByMember = new Map<string, { response_id: number; created_at: string }>();
    for (const a of attendance) {
      const existing = latestByMember.get(a.member_id);
      if (!existing || a.created_at > existing.created_at) {
        latestByMember.set(a.member_id, { response_id: a.response_id, created_at: a.created_at });
      }
    }
    const acceptedIds = [...latestByMember.entries()]
      .filter(([, v]) => v.response_id === 3)
      .map(([mid]) => mid);

    if (acceptedIds.length > 0) {
      const { data: members } = await sb
        .from("member_team_link")
        .select("member_id, member_team_role_link!inner(roles!inner(role_level))")
        .eq("team_id", teamId).eq("status", "active").in("member_id", acceptedIds);

      let playerCount = 0, coachCount = 0;
      for (const m of members || []) {
        const levels: number[] = ((m.member_team_role_link || []) as any[])
          .map((r: any) => r.roles?.role_level).filter((v: any) => v != null);
        if (levels.includes(30)) coachCount++;
        else playerCount++;
      }
      if (playerCount > 0 || coachCount > 0) return { playerCount, coachCount };
    }
  }

  // No attendance responses yet — fall back to total team/squad count
  return countMembers(sb, teamId, squadId);
}

// ── Handler ───────────────────────────────────────────────────────────────────
serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json();
    const { action, event_id, user_id, duration_mins = 60, game_ids, feedback, existing_plan, plan_id, plan_json, rotate_stations = true, player_count: bodyPlayerCount, session_notes } = body;

    if (!user_id) {
      return new Response(JSON.stringify({ error: "user_id is required" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const SUPABASE_URL     = Deno.env.get("SUPABASE_URL")!;
    const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

    // ── get_game: return full details for a single game ───────────────────────
    if (action === "get_game") {
      const { game_id } = body;
      if (!game_id) return new Response(JSON.stringify({ error: "game_id required" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
      const [{ data: game, error: gameErr }, { data: noteRow }] = await Promise.all([
        sb.from("games")
          .select("game_id, game_name, game_image, game_setup, game_how_to_play, game_variations, game_teaching_points, game_details_image")
          .eq("game_id", game_id)
          .single(),
        sb.from("game_coach_notes")
          .select("notes")
          .eq("game_id", game_id)
          .eq("user_id", user_id)
          .maybeSingle(),
      ]);
      if (gameErr || !game) return new Response(JSON.stringify({ error: "Game not found" }), {
        status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
      return new Response(JSON.stringify({ game, coach_note: noteRow?.notes ?? null }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ── save_coach_note: upsert a coach's personal note for a game ────────────
    if (action === "save_coach_note") {
      const { game_id, note } = body;
      if (!game_id) return new Response(JSON.stringify({ error: "game_id required" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
      const { error: upsertErr } = await sb.from("game_coach_notes")
        .upsert({ user_id, game_id, notes: note ?? "" }, { onConflict: "user_id,game_id" });
      if (upsertErr) return new Response(JSON.stringify({ error: upsertErr.message }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
      return new Response(JSON.stringify({ ok: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ── Fetch event + team + club (only when event_id provided) ─────────────────
    let clubData: Record<string, any> = {};
    let squad: Record<string, any> | null = null;
    let teamId: number | null = null;
    let teamName: string | null = null;
    let teamFemale = false;
    let eventLocationPin: any = null;
    let eventLocationName: string | null = null;
    let eventDateTime: string | null = null;
    let eventDetails: string | null = null;
    let eventSquadId: number | null = null;
    let eventTypeStr: string | null = null;
    let eventCodeStr: string | null = null;
    let eventTitle: string | null = null;

    if (event_id) {
      const { data: event, error: eventErr } = await sb
        .from("events")
        .select(`
          event_id, event_title, event_date_time, event_details,
          location_pin, location_name, squad_id, team_id,
          teams!events_team_id_fkey(
            team_id, team_name, team_female,
            clubs!teams_club_id_fkey(
              club_id, club_name, crest, county,
              primary_colour, secondary_colour, third_colour
            )
          ),
          squads!events_squad_id_fkey(squad_name, grade),
          event_types!events_event_type_id_fkey(event_type),
          event_codes!events_event_code_id_fkey(event_code)
        `)
        .eq("event_id", event_id)
        .single();

      if (eventErr || !event) return new Response(JSON.stringify({ error: "Event not found" }), {
        status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });

      clubData          = (event.teams as any)?.clubs || {};
      squad             = (event.squads as any) || null;
      teamId            = (event.teams as any)?.team_id ?? event.team_id;
      teamName          = (event.teams as any)?.team_name ?? null;
      teamFemale        = (event.teams as any)?.team_female === true;
      eventTypeStr      = (event as any).event_types?.event_type ?? null;
      eventCodeStr      = (event as any).event_codes?.event_code ?? null;
      eventLocationPin  = event.location_pin;
      eventLocationName = event.location_name || null;
      eventDateTime     = event.event_date_time;
      eventDetails      = event.event_details?.trim() || null;
      eventSquadId      = event.squad_id ?? null;
      eventTitle        = event.event_title || null;
    }

    function applyCamogie(s: string | null): string | null {
      if (!s || !teamFemale) return s;
      return s.replace(/\bHurling\b/g, 'Camogie').replace(/\bhurling\b/g, 'camogie');
    }

    // Branding from user's default_club
    const { data: userRow } = await sb.from("users").select("default_club").eq("user_id", user_id).maybeSingle();
    let branding: Record<string, any>;
    if (userRow?.default_club) {
      const { data: uClub } = await sb
        .from("clubs")
        .select("club_name, crest, primary_colour, secondary_colour, third_colour")
        .eq("club_id", userRow.default_club)
        .maybeSingle();
      branding = {
        club_id:          userRow.default_club,
        club_name:        uClub?.club_name        || clubData.club_name || "",
        crest:            uClub?.crest            || clubData.crest || null,
        primary_colour:   uClub?.primary_colour   || clubData.primary_colour || "#87C232",
        secondary_colour: uClub?.secondary_colour || null,
        third_colour:     uClub?.third_colour     || null,
      };
    } else {
      branding = {
        club_id:          clubData.club_id ?? null,
        club_name:        clubData.club_name        || "",
        crest:            clubData.crest            || null,
        primary_colour:   clubData.primary_colour   || "#87C232",
        secondary_colour: clubData.secondary_colour || null,
        third_colour:     clubData.third_colour     || null,
      };
    }

    const eventMeta = event_id ? {
      title:         eventTitle || "Training Session",
      date_time:     eventDateTime,
      location_name: eventLocationName,
      team_name:     teamName,
      event_type:    applyCamogie(eventTypeStr),
      event_code:    applyCamogie(eventCodeStr),
    } : null;

    // ── GET: return existing active plan + favourites list ────────────────────
    if (action === "get") {
      const planPromise = event_id
        ? sb.from("session_plans")
            .select("plan_id, plan_json, created_at")
            .eq("event_id", event_id)
            .eq("is_active", true)
            .order("created_at", { ascending: false })
            .limit(1)
            .maybeSingle()
        : Promise.resolve({ data: null });

      const [planResult, favResult] = await Promise.all([
        planPromise,
        sb.from("user_game_link")
          .select("position, games!inner(game_id, game_name, game_image, game_code)")
          .eq("user_id", user_id)
          .order("position"),
      ]);

      // Filter by event code if known; fall back to all when no match
      let favRows = (favResult.data || []);
      if (eventCodeStr) {
        const code = eventCodeStr.toLowerCase();
        const filtered = favRows.filter((f: any) => {
          const codes: string[] = (f.games?.game_code || []).map((c: string) => c.toLowerCase());
          return codes.length === 0 || codes.some(c => code.includes(c) || c.includes(code));
        });
        if (filtered.length > 0) favRows = filtered;
      }

      const favourites = favRows.map((f: any) => ({
        game_id:    f.games.game_id,
        game_name:  f.games.game_name,
        game_image: f.games.game_image || null,
        game_code:  f.games.game_code  || [],
        position:   f.position,
      }));

      return new Response(JSON.stringify({
        plan_id:        planResult.data?.plan_id  ?? null,
        plan:           planResult.data?.plan_json ?? null,
        branding,
        event:          eventMeta,
        squad_name:     squad?.squad_name ?? null,
        has_favourites: favourites.length > 0,
        favourites,
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // ── GET_CLUB_PLANS: plans shared with the user's club ────────────────────
    if (action === "get_club_plans") {
      const { data: cmRows } = await sb.from("user_member_link").select("member_id").eq("user_id", user_id);
      const cmIds = (cmRows || []).map((r: any) => r.member_id);
      if (cmIds.length === 0) return new Response(JSON.stringify({ plans: [] }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
      const { data: ctLinks } = await sb.from("member_team_link").select("teams!inner(club_id)").in("member_id", cmIds);
      const cIds = [...new Set((ctLinks || []).map((r: any) => r.teams?.club_id).filter(Boolean))];
      if (cIds.length === 0) return new Response(JSON.stringify({ plans: [] }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
      const { data: plans, error: cpErr } = await sb
        .from("session_plans")
        .select("plan_id, session_title, created_at, created_by")
        .in("club_id", cIds)
        .eq("is_active", true)
        .is("event_id", null)
        .order("created_at", { ascending: false })
        .limit(50);
      if (cpErr) return new Response(JSON.stringify({ error: cpErr.message }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
      const creatorIds = [...new Set((plans || []).map((p: any) => p.created_by).filter(Boolean))];
      const creatorMap: Record<string, string> = {};
      if (creatorIds.length > 0) {
        const { data: cm2 } = await sb.from("members").select("user_id, first_name, last_name").in("user_id", creatorIds);
        for (const m of (cm2 || [])) {
          if (m.user_id) creatorMap[m.user_id] = [m.first_name, m.last_name].filter(Boolean).join(" ") || "Unknown Coach";
        }
      }
      return new Response(JSON.stringify({
        plans: (plans || []).map((p: any) => ({
          plan_id:       p.plan_id,
          session_title: p.session_title || "Untitled Plan",
          created_at:    p.created_at,
          created_by:    creatorMap[p.created_by] ?? "Unknown Coach",
          is_own:        p.created_by === user_id,
        })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // ── SET_PLAN_CLUB: share/unshare a library plan with the user's club ──────
    if (action === "set_plan_club") {
      const { plan_id: setPlanId, shared } = body;
      if (!setPlanId) return new Response(JSON.stringify({ error: "plan_id required" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
      const { data: planRow } = await sb
        .from("session_plans").select("plan_id").eq("plan_id", setPlanId).eq("created_by", user_id).maybeSingle();
      if (!planRow) return new Response(JSON.stringify({ error: "Plan not found" }), {
        status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
      let newClubId: number | null = null;
      if (shared) {
        const { data: userRow } = await sb.from("users").select("default_club").eq("user_id", user_id).maybeSingle();
        if (userRow?.default_club) {
          newClubId = userRow.default_club;
        } else {
          const { data: scMRows } = await sb.from("user_member_link").select("member_id").eq("user_id", user_id);
          const scMIds = (scMRows || []).map((r: any) => r.member_id);
          if (scMIds.length > 0) {
            const { data: scTLinks } = await sb.from("member_team_link").select("teams!inner(club_id)").in("member_id", scMIds).limit(1);
            newClubId = (scTLinks?.[0] as any)?.teams?.club_id ?? null;
          }
        }
      }
      await sb.from("session_plans").update({ club_id: newClubId }).eq("plan_id", setPlanId);
      return new Response(JSON.stringify({ ok: true, club_id: newClubId }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ── GET_USER_PLANS: return user's saved plan library (no event-linked plans) ─
    if (action === "get_user_plans") {
      const { data: plans, error: plansErr } = await sb
        .from("session_plans")
        .select("plan_id, session_title, created_at")
        .eq("created_by", user_id)
        .eq("is_active", true)
        .is("event_id", null)           // library only — exclude plans attached to specific events
        .order("created_at", { ascending: false })
        .limit(50);

      if (plansErr) return new Response(JSON.stringify({ error: plansErr.message }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });

      const result = (plans || []).map(p => ({
        plan_id:       p.plan_id,
        session_title: p.session_title || "Untitled Plan",
        created_at:    p.created_at,
      }));

      return new Response(JSON.stringify({ plans: result }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ── GET_PLAN: load a single plan by plan_id ───────────────────────────────
    if (action === "get_plan") {
      const { plan_id: loadId } = body;
      if (!loadId) return new Response(JSON.stringify({ error: "plan_id required" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
      const { data: planRow, error: planErr } = await sb
        .from("session_plans")
        .select("plan_id, plan_json, session_title, event_id")
        .eq("plan_id", loadId)
        .eq("created_by", user_id)
        .single();
      if (planErr || !planRow) return new Response(JSON.stringify({ error: "Plan not found" }), {
        status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
      return new Response(JSON.stringify({
        plan_id:       planRow.plan_id,
        plan:          planRow.plan_json,
        session_title: planRow.session_title,
        event_id:      planRow.event_id ?? null,
        branding,
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // ── ATTACH_PLAN: copy a library plan as the active plan for an event ─────
    if (action === "attach_plan") {
      if (!event_id) return new Response(JSON.stringify({ error: "event_id required" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });

      // Resolve plan_json: use provided value or load from DB by plan_id
      let sourcePlanJson = plan_json as any;
      if (!sourcePlanJson && plan_id) {
        // Own plan first
        let { data: planRow } = await sb
          .from("session_plans")
          .select("plan_json, club_id")
          .eq("plan_id", plan_id)
          .eq("created_by", user_id)
          .maybeSingle();

        if (!planRow) {
          // Club plan — verify user belongs to same club
          const { data: apCmRows } = await sb.from("user_member_link").select("member_id").eq("user_id", user_id);
          const apMIds = (apCmRows || []).map((r: any) => r.member_id);
          if (apMIds.length > 0) {
            const { data: apTLinks } = await sb.from("member_team_link").select("teams!inner(club_id)").in("member_id", apMIds);
            const apCIds = [...new Set((apTLinks || []).map((r: any) => r.teams?.club_id).filter(Boolean))];
            if (apCIds.length > 0) {
              const { data: cpRow } = await sb
                .from("session_plans")
                .select("plan_json")
                .eq("plan_id", plan_id)
                .in("club_id", apCIds)
                .maybeSingle();
              if (cpRow) planRow = cpRow;
            }
          }
        }

        if (!planRow) return new Response(JSON.stringify({ error: "Plan not found or access denied" }), {
          status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
        sourcePlanJson = planRow.plan_json;
      }

      if (!sourcePlanJson) return new Response(JSON.stringify({ error: "plan_id or plan_json required" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });

      // Enrich the generic template with event-specific context
      const enriched: Record<string, any> = { ...sourcePlanJson };

      if (teamId) {
        const { playerCount, coachCount } = await countAcceptedAttendees(sb, event_id, teamId, eventSquadId);
        enriched.player_count = playerCount;
        enriched.coach_count  = coachCount;
      }

      const attachWeather = await fetchWeather(
        eventLocationPin, eventLocationName, eventDateTime,
        (clubData as any).county ?? null, eventTypeStr,
      );
      if (attachWeather) enriched.weather = attachWeather;

      if (eventDateTime) enriched.date_time = eventDateTime;
      if (teamName)      enriched.team_name  = teamName;
      if (eventTitle)    enriched.session_title = eventTitle;

      const attachTitle: string = enriched.session_title || "Training Session";
      await sb.from("session_plans").update({ is_active: false }).eq("event_id", event_id);
      const { data: saved, error: attachErr } = await sb
        .from("session_plans")
        .insert({ event_id, created_by: user_id, plan_json: enriched, session_title: attachTitle, is_active: true })
        .select("plan_id").single();
      if (attachErr) return new Response(JSON.stringify({ error: attachErr.message }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
      return new Response(JSON.stringify({ ok: true, plan_id: saved?.plan_id ?? null, plan_json: enriched }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ── UPDATE_PLAN: save edited plan_json ────────────────────────────────────
    if (action === "update_plan") {
      if (!plan_id || !plan_json) return new Response(JSON.stringify({ error: "plan_id and plan_json required" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
      const upTitle: string = (plan_json as any)?.session_title || undefined;
      const { error: upErr } = await sb.from("session_plans")
        .update({ plan_json, ...(upTitle ? { session_title: upTitle } : {}) })
        .eq("plan_id", plan_id)
        .eq("created_by", user_id);
      if (upErr) return new Response(JSON.stringify({ error: upErr.message }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
      return new Response(JSON.stringify({ ok: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ── REVISE_PLAN: apply coach feedback to existing plan ───────────────────
    if (action === "revise_plan") {
      if (!existing_plan || !feedback?.trim()) {
        return new Response(JSON.stringify({ error: "existing_plan and feedback are required" }), {
          status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const apiKey = Deno.env.get("GEMINI_API_KEY");
      if (!apiKey) return new Response(JSON.stringify({ error: "GEMINI_API_KEY not configured" }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });

      function buildPlanText(plan: any): string {
        const sections: string[] = [];
        sections.push(`Session title: ${plan.session_title}`);
        sections.push(`Session objective: ${plan.session_objective}`);
        sections.push(`Total duration: ${plan.total_duration_mins} mins`);
        if (plan.pre_session) {
          sections.push(`Pre-session (${plan.pre_session.duration_mins} mins):\n${plan.pre_session.description}`);
        }
        const wu = plan.warm_up;
        if (wu) {
          const pts = (wu.coaching_points || []).map((p: string) => `• ${p}`).join('\n');
          sections.push(`Warm-up (${wu.duration_mins} mins):\n${wu.description}${pts ? '\nCoaching points:\n' + pts : ''}`);
        }
        if (plan.station_setup) sections.push(`Station setup: ${plan.station_setup}`);
        for (let i = 0; i < (plan.drills || []).length; i++) {
          const d = plan.drills[i];
          const pts = (d.coaching_points || []).map((p: string) => `• ${p}`).join('\n');
          let s = `Drill ${i + 1}: ${d.game_name} (${d.duration_mins} mins):\n${d.description}`;
          if (pts) s += `\nCoaching points:\n${pts}`;
          if (d.variation) s += `\nVariation: ${d.variation}`;
          sections.push(s);
        }
        const cd = plan.cool_down;
        if (cd) sections.push(`Cool-down (${cd.duration_mins} mins):\n${cd.description}`);
        if (plan.post_session) {
          sections.push(`Post-session (${plan.post_session.duration_mins} mins):\n${plan.post_session.description}`);
        }
        return sections.join('\n\n');
      }

      const inputText = buildPlanText(existing_plan) + `\n\nCoach feedback: ${feedback.trim()}`;

      let planJson: any;
      try {
        const raw = await callGemini(apiKey, REVISE_PLAN_PROMPT, [{ text: inputText }]);
        planJson = JSON.parse(raw.replace(/^```json\s*/i, "").replace(/\s*```$/i, "").trim());
      } catch (err) {
        console.error("revise_plan Gemini failed:", err);
        return new Response(JSON.stringify({ error: "AI revision failed", detail: String(err).slice(0, 200) }), {
          status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      if (planJson._refusal) {
        return new Response(JSON.stringify({ refusal: planJson._refusal, branding, event: eventMeta ?? null }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // Restore game_image only — do NOT override content fields (description,
      // coaching_points, setup, variation) because Gemini just revised those.
      const { data: revFavLinks } = await sb
        .from("user_game_link")
        .select(`position, games!inner(game_name, game_image)`)
        .eq("user_id", user_id)
        .order("position");

      const imgByName: Record<string, string | null> = {};
      for (const f of (revFavLinks || [])) {
        const g = (f as any).games;
        if (g?.game_name) imgByName[g.game_name] = g.game_image ?? null;
      }

      for (const drill of (planJson.drills || [])) {
        if (drill.game_name in imgByName) drill.game_image = imgByName[drill.game_name];
      }
      if (planJson.warm_up?.game_name in imgByName) planJson.warm_up.game_image = imgByName[planJson.warm_up.game_name];
      if (planJson.cool_down?.game_name in imgByName) planJson.cool_down.game_image = imgByName[planJson.cool_down.game_name];

      // Gemini doesn't output game_name / game_image / game_video for warm_up or cool_down.
      // Inherit them from existing_plan so they survive revisions.
      if (planJson.warm_up && (existing_plan as any)?.warm_up) {
        const ep = (existing_plan as any).warm_up;
        if (planJson.warm_up.game_name  == null) planJson.warm_up.game_name  = ep.game_name  ?? null;
        if (planJson.warm_up.game_image == null) planJson.warm_up.game_image = ep.game_image ?? null;
        if (planJson.warm_up.game_video == null) planJson.warm_up.game_video = ep.game_video ?? null;
      }
      if (planJson.cool_down && (existing_plan as any)?.cool_down) {
        const ep = (existing_plan as any).cool_down;
        if (planJson.cool_down.game_name  == null) planJson.cool_down.game_name  = ep.game_name  ?? null;
        if (planJson.cool_down.game_image == null) planJson.cool_down.game_image = ep.game_image ?? null;
        if (planJson.cool_down.game_video == null) planJson.cool_down.game_video = ep.game_video ?? null;
      }

      // Save revised plan — event-linked plans deactivate old version first;
      // favourites plans always insert as a new library entry (Option B: keep history)
      const sessionTitle: string = planJson.session_title || "Training Session";
      let savedPlanId: string | null = null;
      if (event_id) {
        await sb.from("session_plans").update({ is_active: false }).eq("event_id", event_id);
        const { data: saved } = await sb
          .from("session_plans")
          .insert({ event_id, created_by: user_id, plan_json: planJson, session_title: sessionTitle, is_active: true })
          .select("plan_id").single();
        savedPlanId = saved?.plan_id ?? null;
      } else {
        // Favourites revision — caller saves explicitly via save_plan; return unsaved draft
        savedPlanId = null;
      }

      return new Response(JSON.stringify({
        plan_id:    savedPlanId,
        plan:       planJson,
        branding,
        event:      eventMeta ?? null,
        squad_name: squad?.squad_name ?? null,
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // ── SAVE_PLAN (favourites explicit save) ─────────────────────────────────
    if (action === "save_plan") {
      const { plan_json: planJsonToSave } = body;
      if (!planJsonToSave) return new Response(JSON.stringify({ error: "plan_json required" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
      const saveTitle: string = planJsonToSave.session_title || "Training Session";
      const { data: saved, error: saveErr } = await sb
        .from("session_plans")
        .insert({ created_by: user_id, plan_json: planJsonToSave, session_title: saveTitle, is_active: true })
        .select("plan_id").single();
      if (saveErr) return new Response(JSON.stringify({ error: "Failed to save: " + saveErr.message }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
      return new Response(JSON.stringify({ ok: true, plan_id: saved?.plan_id ?? null }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ── INTERPRET_VOICE: clean raw speech transcript via AI ──────────────────
    if (action === "interpret_voice") {
      const { transcript, context } = body;
      if (!transcript?.trim()) return new Response(JSON.stringify({ error: "transcript required" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
      const apiKey = Deno.env.get("GEMINI_API_KEY");
      if (!apiKey) return new Response(JSON.stringify({ error: "GEMINI_API_KEY not configured" }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
      const isNotes = context === "session_notes";
      const sysPrompt = isNotes
        ? `You are a GAA coaching assistant. A coach has spoken session notes via voice. Preserve EVERY specific instruction they mentioned — do not summarise, merge, or omit any requirement. Remove only filler words and speech artefacts. Do not add any information the coach did not say. Return ONLY valid JSON: {"interpreted": "<full clear paraphrase with all instructions intact>"}`
        : `You are a GAA coaching assistant. A coach has spoken an instruction to revise their training session plan. Return ONLY valid JSON: {"interpreted": "single clear specific instruction, removing filler words and speech artefacts"}. Do not add any information the coach did not say.`;
      try {
        const raw = await callGemini(apiKey, sysPrompt, [{ text: `Coach said: "${transcript.trim()}"` }]);
        let interpreted: string;
        try {
          const parsed = JSON.parse(raw.replace(/^```json\s*/i, "").replace(/\s*```$/i, "").trim());
          interpreted = parsed.interpreted || String(parsed);
        } catch {
          interpreted = raw.replace(/^["'`]|["'`]$/g, "").trim();
        }
        return new Response(JSON.stringify({ interpreted }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      } catch {
        return new Response(JSON.stringify({ error: "Interpretation failed" }), {
          status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    // ── GENERATE ──────────────────────────────────────────────────────────────
    if (action !== "generate") return new Response(JSON.stringify({ error: "Unknown action" }), {
      status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) return new Response(JSON.stringify({ error: "GEMINI_API_KEY not configured" }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

    // Fetch all favourite games
    const { data: allFavLinks } = await sb
      .from("user_game_link")
      .select(`position, games!inner(game_id, game_name, game_image, game_code, game_type, game_setup, game_how_to_play, game_variations, game_teaching_points, game_video)`)
      .eq("user_id", user_id)
      .order("position");

    if (!allFavLinks || allFavLinks.length === 0) {
      return new Response(JSON.stringify({
        error: "no_favourites",
        message: "No favourite games found. Add some in the Games Library first.",
        branding, event: eventMeta,
      }), { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }


    // Filter + reorder by game_ids if provided (from intro screen selection/ordering)
    let favLinks = allFavLinks;
    if (game_ids && Array.isArray(game_ids) && game_ids.length > 0) {
      const idOrder = game_ids.map(Number);
      favLinks = idOrder
        .map(id => allFavLinks!.find((f: any) => f.games?.game_id === id))
        .filter(Boolean) as typeof allFavLinks;
      if (!favLinks || favLinks.length === 0) favLinks = allFavLinks;
    }

    // Filter by event code if known; fall back to all when no match
    if (eventCodeStr && favLinks) {
      const code = eventCodeStr.toLowerCase();
      const filtered = favLinks.filter((f: any) => {
        const codes: string[] = (f.games?.game_code || []).map((c: string) => c.toLowerCase());
        return codes.length === 0 || codes.some((c: string) => code.includes(c) || c.includes(code));
      });
      if (filtered.length > 0) favLinks = filtered;
    }

    // Coach notes
    const gameIds = favLinks.map((f: any) => f.games?.game_id).filter(Boolean);
    const { data: notes } = await sb
      .from("game_coach_notes")
      .select("game_id, notes")
      .eq("user_id", user_id)
      .in("game_id", gameIds);
    const notesByGame: Record<number, string> = {};
    for (const n of notes || []) notesByGame[n.game_id] = n.notes;

    // Member counts — use accepted attendees if event is known, body param if provided, else null (library plan)
    let playerCount: number | null, coachCount: number | null;
    if (event_id && teamId) {
      ({ playerCount, coachCount } = await countAcceptedAttendees(sb, event_id, teamId, eventSquadId));
    } else if (bodyPlayerCount != null) {
      playerCount = bodyPlayerCount;
      coachCount  = 0;
    } else {
      playerCount = null;
      coachCount  = null;
    }

    // Weather — only when we have event context
    const weather = event_id
      ? await fetchWeather(eventLocationPin, eventLocationName, eventDateTime, (clubData as any).county ?? null, eventTypeStr)
      : null;

    // Separate warmup/cooldown games from drill games
    const warmupGame = favLinks.find((f: any) =>
      ((f.games?.game_type || []) as string[]).some((t: string) => /^(warmup|warm.?up)$/i.test(t))
    );
    const cooldownGame = favLinks.find((f: any) =>
      ((f.games?.game_type || []) as string[]).some((t: string) => /^(cooldown|cool.?down)$/i.test(t))
    );
    const drillGames = favLinks.filter((f: any) => f !== warmupGame && f !== cooldownGame);

    function buildGameText(f: any): string {
      const g = f.games, note = notesByGame[g.game_id];
      return [
        `Game: ${g.game_name}`,
        g.game_setup?.trim()           ? `Setup: ${g.game_setup.trim()}` : null,
        g.game_how_to_play?.trim()     ? `How to play: ${g.game_how_to_play.trim()}` : null,
        g.game_variations?.trim()      ? `Variations: ${g.game_variations.trim()}` : null,
        g.game_teaching_points?.trim() ? `Teaching points: ${g.game_teaching_points.trim()}` : null,
        note?.trim()                   ? `Coach's personal notes: ${note.trim()}` : null,
      ].filter(Boolean).join("\n");
    }

    const gamesText = drillGames.map(buildGameText).join("\n\n---\n\n");

    // Build Gemini prompt
    const context = [
      `Session duration: ${duration_mins} minutes`,
      playerCount != null ? `Players: ${playerCount}` : null,
      coachCount  != null ? `Coaches/managers: ${coachCount}` : null,
      rotate_stations
        ? `Drill mode: STATION ROTATION — players are split into groups across the drill stations; not everyone does the same activity at once; each group rotates through all stations at equal time intervals; warm-up and cool-down are collective activities for the full group`
        : `Drill mode: SEQUENTIAL — all players perform each drill together before moving to the next`,
      squad?.squad_name ? `Squad: ${squad.squad_name}${(squad as any).grade ? ` (${(squad as any).grade})` : ""}` : null,
      (() => {
        const code = (eventCodeStr || "").toLowerCase();
        // Female + hurling = camogie; female + football = ladies football (still football)
        if (code.includes("camogie") || (teamFemale && code.includes("hurling")))
          return `Sport code: Camogie — always write "Camogie" not "Hurling", use "hurl" or "camán" for the stick, "sliotar" for the ball; never reference football or Gaelic football`;
        if (code.includes("hurling"))
          return `Sport code: Hurling — always write "hurling" not "football", use "hurl" for the stick, "sliotar" for the ball; never reference football or Gaelic football`;
        if (code.includes("football") || code.includes("ladies") || code.includes("lgfa"))
          return `Sport code: Gaelic Football — always write "football" not "hurling", use football terminology throughout (hand-pass, kick-pass, scoring); never reference hurling, sliotar, or hurl`;
        // No code — fall back to gender as last resort
        if (teamFemale)
          return `Sport code: Camogie — always write "Camogie" not "Hurling", use "hurl" or "camán" for the stick, "sliotar" for the ball`;
        return null;
      })(),
      weather ? `Weather forecast (for context only — do NOT include in plan text): ${weather.summary}` : null,
      (session_notes?.trim() || eventDetails) ? `Coach's session notes: ${session_notes?.trim() || eventDetails}` : null,
      feedback?.trim() ? `\nCoach's feedback — apply these changes to the plan:\n${feedback.trim()}` : null,
      (feedback?.trim() && existing_plan) ? `\nEXISTING PLAN TO REVISE:\n${JSON.stringify(existing_plan, null, 2)}` : null,
      warmupGame ? `\nWarm-up game — allocate at least 10 minutes for the warm_up section:\n${buildGameText(warmupGame)}` : null,
      cooldownGame ? `\nCool-down game — allocate at least 5 minutes for the cool_down section:\n${buildGameText(cooldownGame)}` : null,
      drillGames.length > 0 ? `\nGames to use as drills (in this order):\n\n${gamesText}` : null,
    ].filter(Boolean).join("\n");

    console.log("Generating — players:", playerCount, "coaches:", coachCount, "games:", favLinks.length, "duration:", duration_mins);

    let planJson: any;
    try {
      const raw = await callGemini(apiKey, SESSION_PLAN_PROMPT, [{ text: context }]);
      planJson = JSON.parse(raw.replace(/^```json\s*/i, "").replace(/\s*```$/i, "").trim());
    } catch (err) {
      console.error("Gemini failed:", err);
      return new Response(JSON.stringify({ error: "AI generation failed", detail: String(err).slice(0, 200) }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // If Gemini declined the request, return refusal without saving a new plan
    if (planJson._refusal) {
      return new Response(JSON.stringify({ refusal: planJson._refusal, branding, event: eventMeta ?? null }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Strip weather from session_objective (safety net for Gemini non-compliance)
    if (planJson.session_objective) {
      planJson.session_objective = stripWeatherFromObjective(planJson.session_objective);
    }

    // Build lookup of DB game data by name
    const gameByName: Record<string, any> = {};
    for (const f of favLinks) {
      const g = (f as any).games;
      if (g?.game_name) gameByName[g.game_name] = g;
    }

    function parseCoachingPoints(text: string): string[] {
      return text.split(/\n|(?:^|\s)[•·–\-]\s/)
        .map((s: string) => s.replace(/^[•·–\-]\s*/, '').trim())
        .filter((s: string) => s.length > 2);
    }

    // Override drill content with exact DB text; add images; strip AI fields
    for (const drill of (planJson.drills || [])) {
      const g = gameByName[drill.game_name];
      drill.game_image = g?.game_image ?? null;
      drill.game_video = g?.game_video?.trim() || null;
      if (g) {
        drill.setup      = g.game_setup?.trim() || null;
        if (g.game_how_to_play?.trim()) drill.description = g.game_how_to_play.trim();
        if (g.game_teaching_points?.trim()) drill.coaching_points = parseCoachingPoints(g.game_teaching_points);
        drill.variation = g.game_variations?.trim() || null;
      }
      delete drill.player_count_note;
    }

    // Enforce: null out warmup/cooldown if no game was provided (safety net for Gemini non-compliance)
    if (!warmupGame)   planJson.warm_up   = null;
    if (!cooldownGame) planJson.cool_down = null;

    // Override warm-up with exact DB text when a warmup game was selected
    if (warmupGame && planJson.warm_up) {
      const g = warmupGame.games;
      planJson.warm_up.game_name  = g.game_name;
      planJson.warm_up.game_image = g.game_image || null;
      planJson.warm_up.game_video = g.game_video?.trim() || null;
      planJson.warm_up.setup      = g.game_setup?.trim() || null;
      if (g.game_how_to_play?.trim()) planJson.warm_up.description = g.game_how_to_play.trim();
      if (g.game_teaching_points?.trim()) planJson.warm_up.coaching_points = parseCoachingPoints(g.game_teaching_points);
      planJson.warm_up.variation  = g.game_variations?.trim() || null;
    }

    // Override cool-down with exact DB text when a cooldown game was selected
    if (cooldownGame && planJson.cool_down) {
      const g = cooldownGame.games;
      planJson.cool_down.game_name  = g.game_name;
      planJson.cool_down.game_image = g.game_image || null;
      planJson.cool_down.game_video = g.game_video?.trim() || null;
      planJson.cool_down.setup      = g.game_setup?.trim() || null;
      if (g.game_how_to_play?.trim()) planJson.cool_down.description = g.game_how_to_play.trim();
      if (g.game_teaching_points?.trim()) planJson.cool_down.coaching_points = parseCoachingPoints(g.game_teaching_points);
      planJson.cool_down.variation  = g.game_variations?.trim() || null;
    }

    if (playerCount != null) planJson.player_count = playerCount;
    if (coachCount  != null) planJson.coach_count  = coachCount;
    if (weather) planJson.weather = weather;

    // Save plan — event-linked: deactivate old then insert; favourites: insert new library entry
    const genSessionTitle: string = planJson.session_title || "Training Session";
    let savedPlanId: string | null = null;
    if (event_id) {
      await sb.from("session_plans").update({ is_active: false }).eq("event_id", event_id);
      const { data: saved, error: saveErr } = await sb
        .from("session_plans")
        .insert({ event_id, created_by: user_id, plan_json: planJson, session_title: genSessionTitle, is_active: true })
        .select("plan_id")
        .single();

      if (saveErr) {
        console.error("Save failed:", saveErr);
        return new Response(JSON.stringify({ error: "Failed to save plan: " + saveErr.message }), {
          status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      savedPlanId = saved.plan_id;
    } else {
      // Favourites — caller saves explicitly via save_plan; return unsaved draft
      savedPlanId = null;
    }

    return new Response(JSON.stringify({
      plan_id:    savedPlanId,
      plan:       planJson,
      branding,
      event:      eventMeta ?? null,
      squad_name: squad?.squad_name ?? null,
    }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

  } catch (err: any) {
    console.error("generate-session-plan error:", err);
    return new Response(JSON.stringify({ error: err.message ?? "Unexpected error" }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
