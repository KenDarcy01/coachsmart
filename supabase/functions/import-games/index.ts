// deno-lint-ignore-file no-explicit-any
// Import games from a coach's document (Word, PowerPoint or PDF).
//
// POST { kind: "pdf"|"docx"|"pptx", filename, text?, pdf_base64?, pictures?: [{base64, mimeType}],
//        allowed: { types[], ages[], codes[], skills[] } }
// -> { games: [{ game_name, game_type, game_age[], game_code[], game_skill[], game_setup, game_how_to_play,
//               game_variations, game_teaching_points, game_video, picture, drawing }], document_title }
//
// The browser unzips Word/PowerPoint (webviews/cs-doc-extract.js) and sends the text with picture
// markers plus the pictures; a PDF is sent whole. Each game comes back with the fields of the
// games table, the index of the picture that shows it (-1 if none) and "drawing": a precise
// description of the layout, which diagram-to-drawio turns into our diagram. Nothing is saved
// here: the coach reviews every game first (Ken, 2026-11-02).
//
// Signed-in users with users.ai_features only (spends Anthropic credit).
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";
const MODEL = Deno.env.get("IMPORT_MODEL") ?? "claude-fable-5-1";
const EFFORT = Deno.env.get("IMPORT_EFFORT") ?? "xhigh";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (b: unknown, status = 200) => new Response(JSON.stringify(b), { status, headers: { ...cors, "content-type": "application/json" } });

const strArr = (vals: string[]) => ({ type: "array", items: vals.length ? { type: "string", enum: vals } : { type: "string" } });

function schema(allowed: { types: string[]; ages: string[]; codes: string[]; skills: string[] }) {
  return {
    type: "object",
    properties: {
      document_title: { type: "string" },
      games: {
        type: "array",
        items: {
          type: "object",
          properties: {
            game_name: { type: "string" },
            game_type: allowed.types.length ? { type: "string", enum: allowed.types } : { type: "string" },
            game_age: strArr(allowed.ages),
            game_code: strArr(allowed.codes),
            game_skill: strArr(allowed.skills),
            game_setup: { type: "string" },
            game_how_to_play: { type: "string" },
            game_variations: { type: "string" },
            game_teaching_points: { type: "string" },
            game_video: { type: "string" },
            picture: { type: "integer" },
            drawing: { type: "string" },
            source_text: { type: "string" },
          },
          required: ["game_name", "game_type", "game_age", "game_code", "game_skill", "game_setup", "game_how_to_play",
                     "game_variations", "game_teaching_points", "game_video", "picture", "drawing", "source_text"],
          additionalProperties: false,
        },
      },
    },
    required: ["document_title", "games"],
    additionalProperties: false,
  };
}

const PROMPT = (a: { types: string[]; ages: string[]; codes: string[]; skills: string[] }, kind: string, nPics: number) => `
This is a GAA coach's training document (a session plan, drill deck or playbook for Gaelic football, hurling or camogie). Find every game, drill or exercise in it and turn each one into a record for the club's games library. Coaches will review every record before it is saved.

WHAT COUNTS AS A GAME
Each separate drill, game, warm-up or exercise with its own setup or rules is one record, in the order they appear. Do not split one drill into several records because it has stages or progressions (those go in variations). Leave out things that are not drills: timetables, equipment lists, admin notes, the session's overall aims. A short warm-up with real content is a record; a line like "5 min jog" on its own is not.

FIELDS (write for another coach; plain, practical, specific to the code; keep the coach's own words where they are clear)
- game_name: the drill's name as written; if it has none, a short descriptive name.
- game_type: one of ${a.types.join(", ")}.
- game_age: age groups it suits, from ${a.ages.join(", ")}. Use any age, year of birth or team named in the document (for example "2009 girls" in a 2024 document are about U16). If nothing says, pick the ages the drill clearly suits, or leave it empty.
- game_code: from ${a.codes.join(", ")}. Hurling and camogie share drills, so a hurling/camogie drill gets both unless the document is clearly only one. Football drills get Football.
- game_skill: from ${a.skills.join(", ")}; only the main skills the drill works on (empty if none fit).
- game_setup: area size, players, equipment, starting positions.
- game_how_to_play: how it runs, step by step, one step per line.
- game_variations: progressions and variations, one per line ("" if none).
- game_teaching_points: the coaching points the document gives, one per line. If it gives none, add 2-3 short, sensible ones that follow directly from the drill.
- game_video: a video link given for this drill ("" if none).
- picture: ${nPics ? `the number of the picture (0 to ${nPics - 1}) that shows this drill's layout, from the [PICTURE n] markers; -1 if none does. A photo of players or a logo is not a layout.` : "-1 (there are no separate pictures)."}
- source_text: this drill's own words from the document, copied exactly (its whole section, including any layout detail; for PowerPoint include its SHAPES lines). Used to check the diagram.
- drawing: a precise description of the drill's layout for a diagram, as if telling someone exactly what to draw: the area and its size and shape, where each player, team, cone, ball, goal or wall is (use left/right/top/bottom or the 0-1000 grid if SHAPES are given), and every run, pass and shot as an arrow from where to where, with player numbers or letters. Use two teams (attackers and defenders) where the drill has opposition. Draw one clear example of the main drill only (for example one group of 4, not all 6 groups; never the variations or progressions). If there is a picture, describe what it shows, read with the text.

${kind === "pptx" ? "This came from PowerPoint. === SLIDE n === starts each slide. SHAPES lists the shapes drawn on a slide on a 0-1000 grid (x across, y down): ovals and circles are usually players (their text is the number), triangles are cones, lines with arrows are runs (solid) or passes (dashed). NOTES are the speaker notes and often hold the coaching detail.\n" : ""}${kind === "docx" ? "This came from Word. Tables are written row by row with cells separated by |.\n" : ""}In hurling and camogie never say "kick"; say strike, pass or score. Write in Irish/British English.

document_title: the document's title or a short description of it.`;

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const body = await req.json();
    const kind = String(body.kind || "");
    if (!["pdf", "docx", "pptx"].includes(kind)) return json({ error: "Unsupported file" }, 400);

    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
    const jwt = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
    const { data: { user } } = await sb.auth.getUser(jwt);
    if (!user) return json({ error: "Please sign in again" }, 401);
    const { data: me } = await sb.from("users").select("ai_features").eq("user_id", user.id).maybeSingle();
    if (!me?.ai_features) return json({ error: "AI features are not turned on for this account" }, 403);

    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) return json({ error: "ANTHROPIC_API_KEY secret not set" }, 500);

    const list = (v: any) => Array.isArray(v) ? v.map(String).filter(Boolean).slice(0, 40) : [];
    const allowed = {
      types: list(body.allowed?.types), ages: list(body.allowed?.ages),
      codes: list(body.allowed?.codes), skills: list(body.allowed?.skills),
    };
    const pictures: { base64: string; mimeType: string }[] = Array.isArray(body.pictures)
      ? body.pictures.filter((p: any) => p && typeof p.base64 === "string" && /^image\/(png|jpeg|gif|webp)$/.test(p.mimeType)).slice(0, 20)
      : [];

    const content: any[] = [];
    if (kind === "pdf") {
      if (typeof body.pdf_base64 !== "string" || !body.pdf_base64) return json({ error: "pdf_base64 is required" }, 400);
      content.push({ type: "document", source: { type: "base64", media_type: "application/pdf", data: body.pdf_base64 } });
    } else {
      const text = String(body.text || "").slice(0, 150000);
      if (!text.trim()) return json({ error: "The document has no text I can read" }, 422);
      pictures.forEach((p, i) => {
        content.push({ type: "text", text: `PICTURE ${i}:` });
        content.push({ type: "image", source: { type: "base64", media_type: p.mimeType, data: p.base64 } });
      });
      content.push({ type: "text", text: `DOCUMENT (${String(body.filename || "").slice(0, 120)}):\n${text}` });
    }
    content.push({ type: "text", text: PROMPT(allowed, kind, kind === "pdf" ? 0 : pictures.length) });

    // Fable can think for 2-3 minutes on a long document, and the gateway drops a request that sends
    // nothing for 150s. So the answer is streamed: a space every 10s keeps it open, then the JSON
    // (JSON.parse ignores the leading spaces). Errors after this point arrive as { error } with 200.
    const work = async (): Promise<Response> => {
      const started = Date.now();
      const res = await fetch(ANTHROPIC_URL, {
        method: "POST",
        headers: { "x-api-key": apiKey, "anthropic-version": "2023-06-01", "content-type": "application/json" },
        body: JSON.stringify({
          model: MODEL,
          max_tokens: 32000,
          thinking: { type: "adaptive" },
          output_config: { effort: EFFORT, format: { type: "json_schema", schema: schema(allowed) } },
          messages: [{ role: "user", content }],
        }),
      });
      if (!res.ok) {
        const t = await res.text();
        console.error("import-games: Anthropic", res.status, t.slice(0, 500));
        return json({ error: `AI error ${res.status}`, detail: t.slice(0, 300) }, 502);
      }
      const data = await res.json();
      console.log("import-games:", MODEL, EFFORT, kind, "stop", data?.stop_reason, "usage", JSON.stringify(data?.usage), "ms", Date.now() - started);
      if (data?.stop_reason === "refusal") return json({ error: "The AI declined to read this document" }, 422);
      const raw = (data?.content ?? []).filter((c: any) => c.type === "text").map((c: any) => c.text).join("");
      let out: any;
      try { out = JSON.parse(raw); } catch (_) { return json({ error: "Could not read the AI's answer", stop_reason: data?.stop_reason }, 502); }
      const games = (out.games || []).map((g: any) => ({ ...g, picture: Number.isInteger(g.picture) && g.picture >= 0 && g.picture < pictures.length ? g.picture : -1 }));
      return json({ document_title: out.document_title || "", games });
    };
    const enc = new TextEncoder();
    const stream = new ReadableStream({
      async start(ctrl) {
        const beat = setInterval(() => { try { ctrl.enqueue(enc.encode(" ")); } catch (_) { /* closed */ } }, 10000);
        try {
          const r = await work();
          ctrl.enqueue(enc.encode(await r.text()));
        } catch (e: any) {
          console.error("import-games:", e?.message);
          ctrl.enqueue(enc.encode(JSON.stringify({ error: e?.message ?? "Unexpected error" })));
        } finally { clearInterval(beat); ctrl.close(); }
      },
    });
    return new Response(stream, { headers: { ...cors, "content-type": "application/json" } });
  } catch (e: any) {
    console.error("import-games:", e?.message);
    return json({ error: e?.message ?? "Unexpected error" }, 500);
  }
});
