// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// Requires GEMINI_API_KEY set as a Supabase secret:
//   supabase secrets set GEMINI_API_KEY=AIza...

// Model is read from a Supabase secret so it can be updated without a code deploy.
// To change: supabase secrets set GEMINI_MODEL=gemini-x.y-flash && supabase functions deploy ai-process-game
const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-3.6-flash";
const GEMINI_URL   = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SYSTEM_PROMPT = `You are a GAA (Gaelic Athletic Association) coaching assistant. Process the coaching drill and return a JSON object with exactly these fields:

- game_name: Short clear drill name, 3-6 words
- game_setup: Setup instructions. Each point on its own line. Include number of players, equipment (cones, balls), and pitch area dimensions.
- game_how_to_play: Numbered step-by-step instructions. Each step on its own line. Clear, concise, coach-friendly.
- game_variations: 2-3 progressions to increase or decrease difficulty. Each on its own line.
- game_teaching_points: 3-5 key coaching cues — what to watch for and emphasise. Each on its own line.
- diagram_layout: A JSON object describing player positions, cones, and movement using the zone grid below. Do NOT generate SVG — the app renders the diagram from this data.

Zone grid (use these exact keys — 3 columns × 5 rows on a portrait pitch):
  tl  tc  tr    ← top row
  ul  uc  ur    ← upper-middle row
  ml  mc  mr    ← middle row
  ll  lc  lr    ← lower-middle row
  bl  bc  br    ← bottom row

diagram_layout structure:
{
  "players": [ { "id": 1, "zone": "tc", "label": "1" }, ... ],
  "cones":   [ { "id": 1, "zone": "bl" }, ... ],
  "moves":   [ { "from": "p1", "to": "p2", "type": "pass" }, ... ]
}

Rules:
- Player ids are integers starting at 1. Cone ids are integers starting at 1.
- moves.from / moves.to use prefix "p" for players (p1, p2...) and "c" for cones (c1, c2...)
- move type must be one of: "pass", "kick", "run"
- Spread players across the full pitch — avoid clustering everyone in the centre
- Include enough moves to clearly show the drill flow
- If the drill has a starting player in possession, place them at the top (tl/tc/tr)

Example (triangle passing drill, 3 players):
{
  "players": [{"id":1,"zone":"tc","label":"1"},{"id":2,"zone":"ml","label":"2"},{"id":3,"zone":"mr","label":"3"}],
  "cones": [],
  "moves": [{"from":"p1","to":"p2","type":"pass"},{"from":"p2","to":"p3","type":"pass"},{"from":"p3","to":"p1","type":"pass"}]
}`;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const { image_base64, image_mime_type, description, game_type, game_age, game_name } = body;

    if (!description?.trim() && !image_base64) {
      return new Response(JSON.stringify({ error: "Provide a description or image" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) {
      return new Response(JSON.stringify({ error: "GEMINI_API_KEY not configured" }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const contextText = [
      game_name?.trim()  ? `Drill name (suggestion): ${game_name.trim()}` : null,
      game_type?.trim()  ? `Game type: ${game_type.trim()}` : null,
      game_age?.length   ? `Age group: ${(Array.isArray(game_age) ? game_age : [game_age]).join(", ")}` : null,
      description?.trim() ? `Coach's notes:\n${description.trim()}` : null,
    ].filter(Boolean).join("\n");

    const parts: any[] = [];

    if (image_base64 && image_mime_type) {
      parts.push({ inline_data: { mime_type: image_mime_type, data: image_base64 } });
    }

    parts.push({ text: contextText || "Process this coaching drill and create a clean diagram." });

    const geminiBody = JSON.stringify({
      system_instruction: { parts: [{ text: SYSTEM_PROMPT }] },
      contents: [{ parts }],
      generationConfig: {
        maxOutputTokens: 8192,
        temperature: 0.3,
        responseMimeType: "application/json",
      },
    });

    // Retry up to 3 times on transient errors (503 overload, 429 rate limit)
    let geminiRes: Response | null = null;
    let errText = "";
    for (let attempt = 1; attempt <= 3; attempt++) {
      geminiRes = await fetch(`${GEMINI_URL}?key=${apiKey}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: geminiBody,
      });
      if (geminiRes.ok) break;
      errText = await geminiRes.text();
      const retryable = geminiRes.status === 503 || geminiRes.status === 429;
      console.warn(`Gemini attempt ${attempt} failed (${geminiRes.status}):`, errText.slice(0, 200));
      if (!retryable || attempt === 3) break;
      await new Promise(r => setTimeout(r, attempt * 1500));
    }

    if (!geminiRes!.ok) {
      console.error("Gemini API error:", errText);
      return new Response(JSON.stringify({ error: "AI processing failed", detail: errText.slice(0, 200) }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const geminiData = await geminiRes!.json();
    const rawText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text || "";

    if (!rawText) {
      const reason = geminiData.candidates?.[0]?.finishReason || "unknown";
      console.error("Empty Gemini response. Finish reason:", reason, JSON.stringify(geminiData).slice(0, 300));
      return new Response(JSON.stringify({ error: "AI returned empty response", reason }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // responseMimeType: "application/json" means rawText should already be valid JSON,
    // but strip fences defensively in case the model wraps it anyway.
    const jsonText = rawText
      .replace(/^```json\s*/i, "")
      .replace(/^```\s*/i, "")
      .replace(/\s*```$/i, "")
      .trim();

    let parsed: any;
    try {
      parsed = JSON.parse(jsonText);
    } catch {
      console.error("JSON parse failed. Raw:", jsonText.slice(0, 600));
      return new Response(
        JSON.stringify({ error: "AI returned invalid JSON", raw: jsonText.slice(0, 400) }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(JSON.stringify({ success: true, data: parsed }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (err) {
    console.error("ai-process-game error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
