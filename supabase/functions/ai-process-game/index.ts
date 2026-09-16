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

// ── Call 1: interpret the drill, clean the text, produce a precise spatial description ──
const TEXT_PROMPT = `You are a GAA (Gaelic Athletic Association) coaching assistant.
Process the coaching drill and return a JSON object with exactly these fields:

- game_name: Short clear drill name, 3-6 words
- game_setup: Setup instructions. Each point on its own line. Include number of players, equipment (cones, balls), and pitch area dimensions.
- game_how_to_play: Numbered step-by-step instructions. Each step on its own line. Clear, concise, coach-friendly.
- game_variations: 2-3 progressions to increase or decrease difficulty. Each on its own line.
- game_teaching_points: 3-5 key coaching cues — what to watch for and emphasise. Each on its own line.
- spatial_description: A precise overhead-view description of the drill layout for diagram purposes.
  Write it as a clear, unambiguous spatial narrative:
  - Describe each player's starting position using compass-style language: top-centre, middle-left, bottom-right etc.
  - Describe each cone's position the same way.
  - Then describe every movement: who passes to whom, who runs where, in sequence.
  - Be explicit: "Player 1 starts at the top-centre holding the ball. Player 2 is at the middle-left.
    Player 3 is at the middle-right. Two cones are placed at the bottom-left and bottom-right.
    Player 1 hand-passes to Player 2. Player 2 runs towards the bottom-left cone."
  - Do not describe tactics or teaching points here — only positions and movements.`;

// ── Call 0: suitability check for uploaded documents ─────────────────────
const SUITABILITY_PROMPT = `You are a GAA coaching content moderator. A coach has uploaded a document to convert into a structured game or drill record.

Review the content and decide: does this document contain a GAA or sports coaching game, drill, or session plan?

Return ONLY this JSON:
{
  "suitable": true,
  "reason": "one sentence explaining your decision",
  "title_hint": "name of the main game or drill if identifiable, otherwise null"
}

A document IS suitable if it contains:
- A specific game or drill with setup instructions or rules
- A training session plan with coaching activities
- An exercise with objectives or teaching points
- Session notes that describe how to run games or drills

A document is NOT suitable if it is:
- An invoice, receipt, contract or financial document
- A personal letter, email or chat log unrelated to coaching
- A fixture list, results sheet, or squad list with no drill content
- A general presentation unrelated to sports or coaching
- Entirely off-topic

Set "suitable": false and explain in "reason" if not suitable.`;

// ── Call 2: translate the precise spatial description into a zone layout ──
const LAYOUT_PROMPT = `You are converting a GAA drill spatial description into a structured zone layout JSON.

Zone grid — use ONLY these exact zone keys (3 columns × 5 rows on a portrait pitch):
  tl  tc  tr    ← top row
  ul  uc  ur    ← upper-middle row
  ml  mc  mr    ← middle row
  ll  lc  lr    ← lower-middle row
  bl  bc  br    ← bottom row

Return ONLY this JSON structure (nothing else):
{
  "players": [ { "id": 1, "zone": "tc", "label": "1" }, ... ],
  "cones":   [ { "id": 1, "zone": "bl" }, ... ],
  "moves":   [ { "from": "p1", "to": "p2", "type": "pass" }, ... ]
}

Rules:
- Player ids are integers starting at 1. Cone ids are integers starting at 1.
- moves.from and moves.to use prefix "p" for players (p1, p2...) and "c" for cones (c1, c2...)
- move type must be exactly one of: "pass", "kick", "run"
- Spread players across the full pitch — avoid clustering in the centre zones
- Every player and cone mentioned in the description must appear in the output`;

// ── Shared Gemini caller with retry ──────────────────────────────────────────

async function callGemini(
  apiKey: string,
  systemPrompt: string,
  parts: any[],
  jsonMode = true,
): Promise<string> {
  const body = JSON.stringify({
    system_instruction: { parts: [{ text: systemPrompt }] },
    contents: [{ parts }],
    generationConfig: {
      maxOutputTokens: 8192,
      temperature: 0.3,
      ...(jsonMode ? { responseMimeType: "application/json" } : {}),
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

  if (!res!.ok) {
    console.error("Gemini API error:", errText);
    throw new Error(`Gemini API error ${res!.status}: ${errText.slice(0, 200)}`);
  }

  const data = await res!.json();
  const text = (data.candidates?.[0]?.content?.parts?.[0]?.text || "").trim();

  if (!text) {
    const reason = data.candidates?.[0]?.finishReason || "unknown";
    throw new Error(`Gemini returned empty response (finishReason: ${reason})`);
  }

  return text;
}

function parseJson(raw: string): any {
  const cleaned = raw
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();
  return JSON.parse(cleaned);
}

// ── Handler ───────────────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const {
      image_base64, image_mime_type, description, game_type, game_age, game_name,
      document_text, document_base64, document_mime_type,
    } = body;

    const isDocMode = !!(document_text || document_base64);

    if (!isDocMode && !description?.trim() && !image_base64) {
      return new Response(JSON.stringify({ error: "Provide a description, image, or document" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) {
      return new Response(JSON.stringify({ error: "GEMINI_API_KEY not configured" }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ── Document mode: suitability check first ────────────────────────────────
    let docTitleHint: string | null = null;
    if (isDocMode) {
      const suitParts: any[] = [];
      if (document_base64 && document_mime_type) {
        suitParts.push({ inline_data: { mime_type: document_mime_type, data: document_base64 } });
        suitParts.push({ text: "Review this document for coaching suitability." });
      } else {
        suitParts.push({ text: `Document content:\n\n${document_text}` });
      }

      let suitResult: any = { suitable: true };
      try {
        const raw = await callGemini(apiKey, SUITABILITY_PROMPT, suitParts);
        suitResult = parseJson(raw);
      } catch (err) {
        console.warn("Suitability check failed — proceeding:", err);
      }

      if (!suitResult.suitable) {
        return new Response(
          JSON.stringify({
            success: false,
            suitable: false,
            reason: suitResult.reason || "This document does not appear to contain a coaching game or drill.",
          }),
          { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }
      docTitleHint = suitResult.title_hint || null;
    }

    // ── Build Call 1 parts ────────────────────────────────────────────────────
    const contextText = [
      (docTitleHint || game_name?.trim()) ? `Drill name (suggestion): ${docTitleHint || game_name!.trim()}` : null,
      game_type?.trim()   ? `Game type: ${game_type.trim()}` : null,
      game_age?.length    ? `Age group: ${(Array.isArray(game_age) ? game_age : [game_age]).join(", ")}` : null,
      !isDocMode && description?.trim() ? `Coach's notes:\n${description.trim()}` : null,
      isDocMode && document_text ? `Document content:\n${document_text}` : null,
    ].filter(Boolean).join("\n");

    const call1Parts: any[] = [];
    if (!isDocMode && image_base64 && image_mime_type) {
      call1Parts.push({ inline_data: { mime_type: image_mime_type, data: image_base64 } });
    }
    if (isDocMode && document_base64 && document_mime_type) {
      call1Parts.push({ inline_data: { mime_type: document_mime_type, data: document_base64 } });
    }
    call1Parts.push({ text: contextText || "Process this coaching drill." });

    // ── Call 1: clean text + spatial description ──────────────────────────────
    let call1Result: any;
    try {
      const raw = await callGemini(apiKey, TEXT_PROMPT, call1Parts);
      call1Result = parseJson(raw);
    } catch (err) {
      console.error("Call 1 failed:", err);
      return new Response(JSON.stringify({ error: "AI processing failed", detail: String(err).slice(0, 200) }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ── Call 2: spatial description → zone layout ─────────────────────────────
    let diagramLayout: any = null;
    const spatialDesc = call1Result.spatial_description?.trim();

    if (spatialDesc) {
      try {
        const raw = await callGemini(apiKey, LAYOUT_PROMPT, [{ text: spatialDesc }]);
        diagramLayout = parseJson(raw);
      } catch (err) {
        // Non-fatal — return the text fields without a diagram rather than failing
        console.warn("Call 2 (layout) failed:", err);
      }
    }

    const result = {
      game_name:            call1Result.game_name            || "",
      game_setup:           call1Result.game_setup           || "",
      game_how_to_play:     call1Result.game_how_to_play     || "",
      game_variations:      call1Result.game_variations       || "",
      game_teaching_points: call1Result.game_teaching_points  || "",
      diagram_layout:       diagramLayout,
    };

    return new Response(JSON.stringify({ success: true, data: result }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (err) {
    console.error("ai-process-game error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
