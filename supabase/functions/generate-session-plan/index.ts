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
    generationConfig: { maxOutputTokens: 4096, temperature: 0.4, responseMimeType: "application/json" },
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
  "warm_up": {
    "duration_mins": number,
    "description": "string (how to run the warm-up with this group)",
    "coaching_points": ["string"]
  },
  "drills": [
    {
      "game_name": "string (use the exact game name from the input)",
      "duration_mins": number,
      "description": "string (how to run this game with the given player count)",
      "coaching_points": ["string — 2 to 4 short, actionable coaching cues"],
      "variation": "string or null"
    }
  ],
  "cool_down": {
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
- (pre_session?.duration_mins ?? 0) + warm_up.duration_mins + all drills duration_mins + cool_down.duration_mins + (post_session?.duration_mins ?? 0) must equal total_duration_mins exactly
- pre_session and post_session must be null unless the coach explicitly requests such an activity
- Use the games in the ORDER given — do not reorder them
- Use the EXACT game name from the input in each drill — do not paraphrase or rename
- Adapt each drill to the given player count; note modifications if needed
- Coaching points must be short and actionable
- Use GAA language: "football" for football code, "sliotar" and "hurl" for hurling/camogie
- CRITICAL: Weather is provided for context only — do NOT include weather data or weather text ANYWHERE in the output JSON, not in session_objective, not in descriptions, not in coaching_points, not anywhere. Weather is shown separately.
- Do NOT include player count adjustment notes; adapt the description directly for the given numbers
- Warm-up must be at least 10 minutes; cool-down at least 5 minutes
- If the coach's feedback asks to include a game that is NOT in the provided games list, set "_refusal" to a short explanation and keep all other fields at sensible defaults (do not change the existing plan)
- If the request is physically impossible (e.g., would require more time than the session allows), set "_refusal" to explain why
- If the request is reasonable and achievable, always attempt it and leave "_refusal" as null`;

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
    const cues: string[] = [];
    if      (temp < 5)     cues.push("very cold — base layers and gloves essential");
    else if (temp < 10)    cues.push("cold — warm layers and gloves recommended");
    else if (temp < 15)    cues.push("cool — light layers advised");
    if      (precip >= 70) cues.push("heavy rain likely — waterproofs required");
    else if (precip >= 40) cues.push("rain possible — waterproofs recommended");
    if      (wind >= 50)   cues.push("very windy — adjust kicking drills");
    else if (wind >= 30)   cues.push("breezy conditions");
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
    const { action, event_id, user_id, duration_mins = 60, game_ids, feedback, plan_id, plan_json } = body;

    if (!event_id || !user_id) {
      return new Response(JSON.stringify({ error: "event_id and user_id are required" }), {
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
      const { data: game, error: gameErr } = await sb
        .from("games")
        .select("game_id, game_name, game_image, game_setup, game_how_to_play, game_variations, game_teaching_points, game_details_image")
        .eq("game_id", game_id)
        .single();
      if (gameErr || !game) return new Response(JSON.stringify({ error: "Game not found" }), {
        status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
      return new Response(JSON.stringify({ game }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // ── Fetch event + team + club ─────────────────────────────────────────────
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

    const club       = (event.teams as any)?.clubs || {};
    const squad      = (event.squads as any) || null;
    const teamId     = (event.teams as any)?.team_id ?? event.team_id;
    const teamName   = (event.teams as any)?.team_name ?? null;
    const teamFemale = (event.teams as any)?.team_female === true;
    const eventType  = (event as any).event_types?.event_type ?? null;
    const eventCode  = (event as any).event_codes?.event_code ?? null;

    function applyCamogie(s: string | null): string | null {
      if (!s || !teamFemale) return s;
      return s.replace(/\bHurling\b/g, 'Camogie').replace(/\bhurling\b/g, 'camogie');
    }

    // Branding from user's default_club (not the event's club chain)
    const { data: userRow } = await sb.from("users").select("default_club").eq("user_id", user_id).maybeSingle();
    let branding: Record<string, any>;
    if (userRow?.default_club) {
      const { data: uClub } = await sb
        .from("clubs")
        .select("club_name, crest, primary_colour, secondary_colour, third_colour")
        .eq("club_id", userRow.default_club)
        .maybeSingle();
      branding = {
        club_name:        uClub?.club_name        || club.club_name || "",
        crest:            uClub?.crest            || club.crest || null,
        primary_colour:   uClub?.primary_colour   || club.primary_colour || "#87C232",
        secondary_colour: uClub?.secondary_colour || null,
        third_colour:     uClub?.third_colour     || null,
      };
    } else {
      branding = {
        club_name:        club.club_name        || "",
        crest:            club.crest            || null,
        primary_colour:   club.primary_colour   || "#87C232",
        secondary_colour: club.secondary_colour || null,
        third_colour:     club.third_colour     || null,
      };
    }
    const eventMeta = {
      title:         event.event_title    || "Training Session",
      date_time:     event.event_date_time,
      location_name: event.location_name  || null,
      team_name:     teamName,
      event_type:    applyCamogie(eventType),
      event_code:    applyCamogie(eventCode),
    };

    // ── GET: return existing active plan + favourites list ────────────────────
    if (action === "get") {
      const [planResult, favResult] = await Promise.all([
        sb.from("session_plans")
          .select("plan_id, plan_json, created_at")
          .eq("event_id", event_id)
          .eq("is_active", true)
          .order("created_at", { ascending: false })
          .limit(1)
          .maybeSingle(),
        sb.from("user_game_link")
          .select("position, games!inner(game_id, game_name, game_image)")
          .eq("user_id", user_id)
          .order("position"),
      ]);

      const favourites = (favResult.data || []).map((f: any) => ({
        game_id:    f.games.game_id,
        game_name:  f.games.game_name,
        game_image: f.games.game_image || null,
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

    // ── UPDATE_PLAN: save edited plan_json ────────────────────────────────────
    if (action === "update_plan") {
      if (!plan_id || !plan_json) return new Response(JSON.stringify({ error: "plan_id and plan_json required" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
      const { error: upErr } = await sb.from("session_plans")
        .update({ plan_json })
        .eq("plan_id", plan_id)
        .eq("created_by", user_id);
      if (upErr) return new Response(JSON.stringify({ error: upErr.message }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
      return new Response(JSON.stringify({ ok: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
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
      .select(`position, games!inner(game_id, game_name, game_image, game_setup, game_how_to_play, game_variations, game_teaching_points)`)
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
        .map(id => allFavLinks.find((f: any) => f.games?.game_id === id))
        .filter(Boolean) as typeof allFavLinks;
      if (favLinks.length === 0) favLinks = allFavLinks;
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

    // Member counts — accepted attendees only, squad-aware fallback
    const { playerCount, coachCount } = await countAcceptedAttendees(sb, event_id, teamId, event.squad_id ?? null);

    // Weather
    const weather = await fetchWeather(event.location_pin, event.location_name, event.event_date_time, club.county ?? null);

    // Build Gemini prompt
    const gamesText = favLinks.map((f: any) => {
      const g = f.games, note = notesByGame[g.game_id];
      return [
        `Game: ${g.game_name}`,
        g.game_setup?.trim()           ? `Setup: ${g.game_setup.trim()}` : null,
        g.game_how_to_play?.trim()     ? `How to play: ${g.game_how_to_play.trim()}` : null,
        g.game_variations?.trim()      ? `Variations: ${g.game_variations.trim()}` : null,
        g.game_teaching_points?.trim() ? `Teaching points: ${g.game_teaching_points.trim()}` : null,
        note?.trim()                   ? `Coach's personal notes: ${note.trim()}` : null,
      ].filter(Boolean).join("\n");
    }).join("\n\n---\n\n");

    const context = [
      `Session duration: ${duration_mins} minutes`,
      `Players: ${playerCount}`,
      `Coaches/managers: ${coachCount}`,
      squad?.squad_name ? `Squad: ${squad.squad_name}${squad.grade ? ` (${squad.grade})` : ""}` : null,
      teamFemale ? `Sport code: Camogie — use "Camogie" not "Hurling", "hurl/camán" for the stick, "sliotar" for the ball` : null,
      weather ? `Weather forecast (for context only — do NOT include in plan text): ${weather.summary}` : null,
      event.event_details?.trim() ? `Coach's session notes: ${event.event_details.trim()}` : null,
      feedback?.trim() ? `\nCoach's feedback on the previous plan (please address this):\n${feedback.trim()}` : null,
      `\nGames to use (in this order):\n\n${gamesText}`,
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
      return new Response(JSON.stringify({ refusal: planJson._refusal, branding, event: eventMeta }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Strip weather from session_objective (safety net for Gemini non-compliance)
    if (planJson.session_objective) {
      planJson.session_objective = stripWeatherFromObjective(planJson.session_objective);
    }

    // Enrich drills with game images; strip unwanted fields
    const imageByName: Record<string, string | null> = {};
    for (const f of favLinks) {
      const g = (f as any).games;
      if (g?.game_name) imageByName[g.game_name] = g.game_image || null;
    }
    for (const drill of (planJson.drills || [])) {
      drill.game_image = imageByName[drill.game_name] ?? null;
      delete drill.player_count_note;
    }

    planJson.player_count = playerCount;
    planJson.coach_count  = coachCount;
    if (weather) planJson.weather = weather;

    // Save (deactivate old plans first)
    await sb.from("session_plans").update({ is_active: false }).eq("event_id", event_id);
    const { data: saved, error: saveErr } = await sb
      .from("session_plans")
      .insert({ event_id, created_by: user_id, plan_json: planJson, is_active: true })
      .select("plan_id")
      .single();

    if (saveErr) {
      console.error("Save failed:", saveErr);
      return new Response(JSON.stringify({ error: "Failed to save plan: " + saveErr.message }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({
      plan_id:    saved.plan_id,
      plan:       planJson,
      branding,
      event:      eventMeta,
      squad_name: squad?.squad_name ?? null,
    }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

  } catch (err: any) {
    console.error("generate-session-plan error:", err);
    return new Response(JSON.stringify({ error: err.message ?? "Unexpected error" }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
