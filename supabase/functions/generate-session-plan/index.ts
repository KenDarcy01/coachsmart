// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

// Requires GEMINI_API_KEY set as a Supabase secret.
// Model is read from GEMINI_MODEL secret (defaults to gemini-2.5-flash).
const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";
const GEMINI_URL   = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ── Gemini caller with retry ──────────────────────────────────────────────────
async function callGemini(apiKey: string, systemPrompt: string, parts: any[]): Promise<string> {
  const body = JSON.stringify({
    system_instruction: { parts: [{ text: systemPrompt }] },
    contents: [{ parts }],
    generationConfig: {
      maxOutputTokens: 4096,
      temperature: 0.4,
      responseMimeType: "application/json",
    },
  });

  let res: Response | null = null;
  let errText = "";

  for (let attempt = 1; attempt <= 3; attempt++) {
    res = await fetch(`${GEMINI_URL}?key=${apiKey}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body,
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
  if (!text) throw new Error(`Gemini returned empty response (finishReason: ${data.candidates?.[0]?.finishReason || "unknown"})`);
  return text;
}

// ── Session plan system prompt ────────────────────────────────────────────────
const SESSION_PLAN_PROMPT = `You are an expert GAA (Gaelic Athletic Association) coaching assistant.

Generate a structured training session plan in JSON matching EXACTLY this schema.
Return ONLY valid JSON — no markdown fences, no explanation, nothing before or after the JSON.

{
  "session_title": "string (3–8 words describing the session theme)",
  "session_objective": "string (1–2 sentences: what skill or quality players will develop)",
  "total_duration_mins": number,
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
      "player_count_note": "string or null (note if count needs adjustment, otherwise null)",
      "coaching_points": ["string — 2 to 4 short, actionable coaching cues"],
      "variation": "string or null"
    }
  ],
  "cool_down": {
    "duration_mins": number,
    "description": "string"
  }
}

Rules:
- warm_up.duration_mins + all drills duration_mins + cool_down.duration_mins must equal total_duration_mins exactly
- Order drills from simplest to most complex — build progressively
- Use the EXACT game name from the input in each drill — do not paraphrase or rename
- Adapt each drill to the given player count; note modifications if needed
- Coaching points must be short and actionable (what to watch for, what to emphasise)
- Use GAA language: "football" for football code, "sliotar" and "hurl" for hurling/camogie
- If weather is poor, include appropriate warm-up modifications in the description
- Warm-up must be at least 10 minutes; cool-down at least 5 minutes`;

// ── Weather helpers ───────────────────────────────────────────────────────────
function parseLatLng(pin: string | null): { lat: number; lng: number } | null {
  if (!pin) return null;
  let m: RegExpMatchArray | null;
  // @lat,lng — Google Maps standard
  m = pin.match(/@(-?\d+\.\d+),(-?\d+\.\d+)/);
  if (m) return { lat: +m[1], lng: +m[2] };
  // ?q=lat,lng
  m = pin.match(/[?&]q=(-?\d+\.\d+),(-?\d+\.\d+)/);
  if (m) return { lat: +m[1], lng: +m[2] };
  // ll=lat,lng — Apple Maps
  m = pin.match(/[?&]ll=(-?\d+\.\d+),(-?\d+\.\d+)/);
  if (m) return { lat: +m[1], lng: +m[2] };
  // bare lat,lng string
  m = pin.match(/^(-?\d+\.\d+),\s*(-?\d+\.\d+)$/);
  if (m) return { lat: +m[1], lng: +m[2] };
  return null;
}

async function geocodeName(name: string): Promise<{ lat: number; lng: number } | null> {
  try {
    const res = await fetch(
      `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(name)}&count=1&language=en&format=json`
    );
    if (!res.ok) return null;
    const d = await res.json();
    const r = d.results?.[0];
    return r ? { lat: r.latitude, lng: r.longitude } : null;
  } catch { return null; }
}

async function fetchWeather(
  locationPin: string | null,
  locationName: string | null,
  eventDateTime: string | null,
  county: string | null,
): Promise<{ summary: string; temp_c: number; precip_pct: number; wind_kmh: number } | null> {
  if (!eventDateTime) return null;

  const eventDate = new Date(eventDateTime);
  const daysAhead = (eventDate.getTime() - Date.now()) / (1000 * 60 * 60 * 24);
  if (daysAhead < -1 || daysAhead > 16) return null;

  // Try coords from location_pin → geocode location_name → geocode county (Ireland fallback)
  let coords = parseLatLng(locationPin);
  if (!coords && locationName) coords = await geocodeName(locationName);
  if (!coords && county)       coords = await geocodeName(`${county}, Ireland`);
  if (!coords) return null;

  try {
    const res = await fetch(
      `https://api.open-meteo.com/v1/forecast` +
      `?latitude=${coords.lat}&longitude=${coords.lng}` +
      `&hourly=temperature_2m,precipitation_probability,windspeed_10m` +
      `&timezone=Europe%2FDublin&forecast_days=16`
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

// ── Handler ───────────────────────────────────────────────────────────────────
serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json();
    const { action, event_id, user_id, duration_mins = 60 } = body;

    if (!event_id || !user_id) {
      return new Response(JSON.stringify({ error: "event_id and user_id are required" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const SUPABASE_URL      = Deno.env.get("SUPABASE_URL")!;
    const SERVICE_ROLE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

    // ── Fetch event + team + club ─────────────────────────────────────────────
    const { data: event, error: eventErr } = await sb
      .from("events")
      .select(`
        event_id, event_title, event_date_time, event_details,
        location_pin, location_name, squad_id, team_id,
        teams!events_team_id_fkey(
          team_id, team_name,
          clubs!teams_club_id_fkey(
            club_id, club_name, crest, county,
            primary_colour, secondary_colour, third_colour
          )
        ),
        squads!events_squad_id_fkey(squad_name, grade)
      `)
      .eq("event_id", event_id)
      .single();

    if (eventErr || !event) {
      return new Response(JSON.stringify({ error: "Event not found" }), {
        status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const club  = (event.teams as any)?.clubs || {};
    const squad = (event.squads as any) || null;

    const branding = {
      club_name:        club.club_name        || "",
      crest:            club.crest            || null,
      primary_colour:   club.primary_colour   || "#87C232",
      secondary_colour: club.secondary_colour || null,
      third_colour:     club.third_colour     || null,
    };

    const eventMeta = {
      title:         event.event_title    || "Training Session",
      date_time:     event.event_date_time,
      location_name: event.location_name  || null,
    };

    // ── GET: return existing active plan ──────────────────────────────────────
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
          .select("*", { count: "exact", head: true })
          .eq("user_id", user_id),
      ]);

      return new Response(JSON.stringify({
        plan_id:        planResult.data?.plan_id  ?? null,
        plan:           planResult.data?.plan_json ?? null,
        branding,
        event:          eventMeta,
        squad_name:     squad?.squad_name ?? null,
        has_favourites: (favResult.count ?? 0) > 0,
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // ── GENERATE ──────────────────────────────────────────────────────────────
    if (action !== "generate") {
      return new Response(JSON.stringify({ error: "action must be 'get' or 'generate'" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) {
      return new Response(JSON.stringify({ error: "GEMINI_API_KEY not configured" }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Fetch favourite games (including image URL for display)
    const { data: favLinks } = await sb
      .from("user_game_link")
      .select(`
        position,
        games!inner(
          game_id, game_name, game_image,
          game_setup, game_how_to_play, game_variations, game_teaching_points
        )
      `)
      .eq("user_id", user_id)
      .order("position");

    if (!favLinks || favLinks.length === 0) {
      return new Response(JSON.stringify({
        error: "no_favourites",
        message: "No favourite games found. Add some in the Games Library first.",
        branding, event: eventMeta,
      }), { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // Fetch coach notes for these games
    const gameIds = favLinks.map((f: any) => f.games?.game_id).filter(Boolean);
    const { data: notes } = await sb
      .from("game_coach_notes")
      .select("game_id, notes")
      .eq("user_id", user_id)
      .in("game_id", gameIds);

    const notesByGame: Record<number, string> = {};
    for (const n of notes || []) notesByGame[n.game_id] = n.notes;

    // Count players (role_level = 10) and coaches (role_level = 30) on this team/squad
    const teamId = (event.teams as any)?.team_id ?? event.team_id;
    let memberQuery: any = sb
      .from("member_team_link")
      .select("member_id, member_team_role_link!inner(roles!inner(role_level))")
      .eq("team_id", teamId)
      .eq("status", "active");
    if (event.squad_id) memberQuery = memberQuery.eq("squad_id", event.squad_id);

    const { data: members } = await memberQuery;
    let playerCount = 0, coachCount = 0;
    for (const m of members || []) {
      const levels: number[] = ((m.member_team_role_link || []) as any[])
        .map((r: any) => r.roles?.role_level)
        .filter((v: any) => v !== null && v !== undefined);
      if (levels.includes(30)) coachCount++;
      else playerCount++; // role_level 10 = player, or unset = assume player
    }
    if (playerCount === 0 && coachCount === 0) playerCount = 15;

    // Fetch weather — fallback chain: location_pin → location_name → club county
    const weather = await fetchWeather(
      event.location_pin,
      event.location_name,
      event.event_date_time,
      club.county ?? null,
    );

    // Build Gemini prompt context
    const gamesText = favLinks.map((f: any) => {
      const g    = f.games;
      const note = notesByGame[g.game_id];
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
      weather ? `Weather forecast: ${weather.summary}` : null,
      event.event_details?.trim() ? `Coach's session notes: ${event.event_details.trim()}` : null,
      `\nFavourite games to include in this session:\n\n${gamesText}`,
    ].filter(Boolean).join("\n");

    console.log("Generating session plan — players:", playerCount, "coaches:", coachCount, "games:", favLinks.length);

    let planJson: any;
    try {
      const raw = await callGemini(apiKey, SESSION_PLAN_PROMPT, [{ text: context }]);
      planJson = JSON.parse(raw.replace(/^```json\s*/i, "").replace(/\s*```$/i, "").trim());
    } catch (err) {
      console.error("Gemini generation failed:", err);
      return new Response(JSON.stringify({ error: "AI generation failed", detail: String(err).slice(0, 200) }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Enrich drills with game images by matching on exact game name
    const imageByName: Record<string, string | null> = {};
    for (const f of favLinks) {
      const g = (f as any).games;
      if (g?.game_name) imageByName[g.game_name] = g.game_image || null;
    }
    for (const drill of (planJson.drills || [])) {
      drill.game_image = imageByName[drill.game_name] ?? null;
    }

    // Attach context metadata so the template can display them when loading from DB
    planJson.player_count = playerCount;
    planJson.coach_count  = coachCount;
    if (weather) planJson.weather = weather;

    // Deactivate previous plans for this event, then save the new one
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
      plan_id:        saved.plan_id,
      plan:           planJson,
      branding,
      event:          eventMeta,
      squad_name:     squad?.squad_name ?? null,
      has_favourites: true,
    }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

  } catch (err: any) {
    console.error("generate-session-plan error:", err);
    return new Response(JSON.stringify({ error: err.message ?? "Unexpected error" }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
