// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// Requires ANTHROPIC_API_KEY set as a Supabase secret:
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SYSTEM_PROMPT = `You are a GAA (Gaelic Athletic Association) coaching assistant. Process the coaching drill and return ONLY a valid JSON object — no markdown fences, no explanation, just raw JSON.

The JSON must have exactly these fields:
{
  "game_name": "Short clear drill name, 3-6 words",
  "game_setup": "Setup instructions. Each point on its own line. Include number of players, equipment (cones, balls), and pitch area dimensions.",
  "game_how_to_play": "Numbered step-by-step instructions. Each step on its own line. Clear, concise, coach-friendly.",
  "game_variations": "2-3 progressions to increase or decrease difficulty. Each on its own line.",
  "game_teaching_points": "3-5 key coaching cues — what to watch for and emphasise. Each on its own line.",
  "diagram_svg": "A complete inline SVG string for the drill diagram. See SVG rules below."
}

SVG rules for diagram_svg:
- Use ONLY single quotes for all SVG attribute values to avoid JSON escaping (e.g., viewBox='0 0 320 400')
- Overall: <svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 320 400' width='320' height='400'>
- Pitch: dark green rectangle (#2c5f2e) with rounded corners (rx=6), white border stroke
- Optional white dashed lines for pitch zones (goal line, midfield etc) if relevant
- Players: white-filled circles r=13, dark border (#1a1a1a) stroke-width=1.5, dark number inside font-size=11 font-family=sans-serif text-anchor=middle dominant-baseline=central
- Run arrows: dashed lines stroke=#555555 stroke-dasharray=5,3, with arrowhead marker (dark grey fill)
- Pass/kick arrows: solid lines stroke=#5cb85c stroke-width=2, with arrowhead marker (green fill)
- Cones: small orange (#f07023) rotated squares (use <rect transform='rotate(45,...)'> or <polygon>)
- Define arrowhead markers in <defs> section
- Add a small legend at bottom (y=375-395): dashed line = run, solid green = pass, orange square = cone
- Keep it simple, clean, readable at 320px width on mobile`;

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

    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) {
      return new Response(JSON.stringify({ error: "ANTHROPIC_API_KEY not configured" }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const contextLines = [
      game_name?.trim()  ? `Drill name (suggestion): ${game_name.trim()}` : null,
      game_type?.trim()  ? `Game type: ${game_type.trim()}` : null,
      game_age?.length   ? `Age group: ${(Array.isArray(game_age) ? game_age : [game_age]).join(", ")}` : null,
      description?.trim() ? `Coach's notes:\n${description.trim()}` : null,
    ].filter(Boolean).join("\n");

    const contentParts: any[] = [];

    if (image_base64 && image_mime_type) {
      contentParts.push({
        type: "image",
        source: { type: "base64", media_type: image_mime_type, data: image_base64 },
      });
    }

    contentParts.push({
      type: "text",
      text: contextLines || "Process this coaching drill and create a clean diagram.",
    });

    const anthropicRes = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: "claude-sonnet-4-6",
        max_tokens: 4096,
        system: SYSTEM_PROMPT,
        messages: [{ role: "user", content: contentParts }],
      }),
    });

    if (!anthropicRes.ok) {
      const errText = await anthropicRes.text();
      console.error("Anthropic API error:", errText);
      return new Response(JSON.stringify({ error: "AI processing failed", detail: errText.slice(0, 200) }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const anthropicData = await anthropicRes.json();
    const rawText = (anthropicData.content?.[0]?.text || "").trim();

    // Strip markdown fences if Claude wrapped the output anyway
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
