// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// Requires ANTHROPIC_API_KEY set as a Supabase secret:
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";
const MODEL = "claude-opus-5-5";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const PROMPT = `You are an expert at converting handwritten or hand-drawn GAA (Gaelic Athletic Association) coaching diagrams into polished draw.io (mxGraph) XML.

PRE-SCAN — TITLE AND INSTRUCTIONS (do this before anything else):
1. TITLE: Look for a written title or heading — typically larger text, underlined, or placed prominently above or outside the diagram area. If found, this is the game name. It is NOT a diagram element; do NOT render it as a text node in the XML.
2. INSTRUCTIONS: Look for any written notes, rules, or descriptions around or below the diagram (e.g. "Split into groups of 4", "First team to score wins", "Players start at cones"). These are coaching instructions. Do NOT render them as text nodes in the XML. DO use them as context to inform how you draw the diagram — they may clarify arrow directions, player starting positions, or movement patterns.
3. Output format: your response must begin with exactly this line:
   GAME_NAME: <the title if found, or leave blank if none>
   Then on the next line, start the mxGraphModel XML.

CRITICAL — COMPLETENESS RULE:
Scan the ENTIRE image from top to bottom before you begin writing XML. Every single circle, cone, arrow and pitch marking you can see MUST appear in the output — including elements near the halfway line or at the far end of the pitch. Do NOT stop generating until every element from the original image is represented. Missing even one player, football or coach is an error.

STEP 1 — BEFORE ANYTHING ELSE, SCAN THE IMAGE FOR THESE THREE THINGS IN ORDER:

① TRAINING WALL: Is there a rectangle labelled "Wall" or "WALL"? If yes, it MUST be the first vertex you output — place it at the top of the canvas before any other element. Do not skip it.

② EVERY CIRCLE — classify each one by label:
Each circle must be classified by reading its label. This classification is MANDATORY and OVERRIDES any assumption about team colour or position on the pitch.

  • Circle label is EMPTY or contains only a small dot → FOOTBALL
    fillColor=#ffffff (WHITE), strokeColor=#555555, width=24, height=24, value=""
    *** A football is ALWAYS white. Never red, never blue, never black. ***

  • Circle label is the letter C (or c) → COACH
    fillColor=#1a1a1a (BLACK), strokeColor=#000000, width=46, height=46, value="C"
    *** A coach circle is ALWAYS black with white text. Never red or blue. ***

  • Circle label is a NUMBER → PLAYER
    Use visual judgment to decide HOME (red) or AWAY (blue):
    - If all players clearly form one team's formation spread across the pitch → all HOME (red)
    - If players appear in opponent pairs drawn close together, assign HOME (red) to one and AWAY (blue) to the other
    - GAA convention: player 3 marks player 12 (3+12=15), 6 marks 9 (6+9=15), 7 marks 8, etc.
      If you see pairs drawn side by side where the numbers sum to 15, they are opponents.
    - In drills, the same number may appear twice (two circles labelled "4") — they are drill opponents.
    - When in doubt, default to all HOME (red).

Apply this in strict order: empty/dot → white football · "C" → black coach · number → red/blue player.

③ TRIANGLES: Count every triangle — each is a cone. Note their positions.

Do not skip any of ①②③.

STEP 2 — OUTPUT FORMAT:
- First line: GAME_NAME: <title or blank> (as described in PRE-SCAN above)
- Second line onwards: raw XML only — no markdown fences, no explanation
- Start the XML with exactly: <mxGraphModel background="#2E7D32"
- Include mxCell id="0" and id="1" parent="0" as the two root cells

STEP 3 — CANVAS SIZE:
- SQUARE drill (content roughly equal width and height): width=600, height=600
- PORTRAIT pitch (content taller than wide): width=500, height=700
- LANDSCAPE pitch (content wider than tall): width=720, height=480
- Set background="#2E7D32" on the mxGraphModel element and use the chosen width/height for the background rectangle.
- PADDING: all shapes and arrow endpoints must stay at least 60px from every edge.
- Scale all positions from the original image proportionally to fill the chosen canvas.

STEP 4 — FULL STYLE DEFINITIONS (use these exact strings):

FOOTBALL (empty circle / dot):
  style="ellipse;whiteSpace=wrap;html=1;aspect=fixed;fillColor=#ffffff;strokeColor=#555555;shadow=0;"

COACH (letter C):
  style="ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=15;fontStyle=1;fillColor=#1a1a1a;gradientColor=#3a3a3a;gradientDirection=north;strokeColor=#000000;shadow=1;fontColor=#ffffff;"

PLAYER home (red):
  style="ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=15;fontStyle=1;fillColor=#C62828;gradientColor=#EF5350;gradientDirection=north;strokeColor=#B71C1C;shadow=1;fontColor=#ffffff;"

PLAYER away (blue):
  style="ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=15;fontStyle=1;fillColor=#1565C0;gradientColor=#42A5F5;gradientDirection=north;strokeColor=#0D47A1;shadow=1;fontColor=#ffffff;"

CONES (triangles):
- Triangle, width=28, height=32, direction=north (MANDATORY)
- Style: triangle;direction=north;whiteSpace=wrap;html=1;fillColor=#FF6D00;gradientColor=#FFAB40;gradientDirection=north;strokeColor=#E65100;shadow=1;
- Cones are orange with gradient and shadow — this is how real GAA training cones look.

GAA GOALPOSTS (H shapes):
- If you see a shape that looks like the letter "H" — two vertical uprights connected by a horizontal crossbar — output it as a single GOALPOST vertex. Do NOT draw it as individual lines or rectangles.
- Style: gaa_goalpost;whiteSpace=wrap;html=1;
- Geometry: x/y = top-left corner of the H. width = distance between the outer edges of the two uprights. height = full height from the top of the uprights down to the implied ground level (include the goal area below the crossbar — total height should be roughly 1.8× the height of the uprights above the crossbar).
- Typical size on a full pitch: width=90–130, height=70–100. Scale to match the drawn H proportionally.
- The crossbar in the drawn H sits at approximately 55% down from the top of the shape.
- There may be 0, 1, or 2 goalposts in a diagram (at one or both ends of the pitch). A goalpost at the top of a portrait pitch has y near the top padding; one at the bottom has y near the bottom padding.
- GOALPOSTS ARE OBSTACLES: arrows must route around them with at least 5px clearance.

PITCH LINES — MUST BE IDENTIFIED BEFORE MOVEMENT LINES:
- A pitch line is a long straight line that spans the full width (or full length) of the playing area and separates zones. Examples: the end line, 14m line, 21m line, 45m line, 65m line, halfway line, sidelines.
- Pitch lines have NO arrowhead and NO dash. Output them as: edgeStyle=none;html=1;endArrow=none;endFill=0;strokeColor=#ffffff;strokeWidth=1.5;opacity=50;
- DO NOT mistake pitch lines for movement arrows. If a line spans the full width with no clear start/end player, it is a pitch line.

TRAINING WALL (rectangle labelled "Wall" or "WALL"):
- A physical wall used in hurling/camogie training — players stand in front of it and strike the sliotar against it. It is always a wide, shallow rectangle spanning most of the playing width, placed at the top (or occasionally the bottom) of the diagram.
- Scan for it BEFORE drawing any arrows — arrows targeting the wall must end at its edge.
- Style: rounded=0;whiteSpace=wrap;html=1;fillColor=#455A64;strokeColor=#B0BEC5;strokeWidth=3;fontColor=#ffffff;fontSize=16;fontStyle=1;
- Geometry: span most of the canvas width (typically 80–90% of canvas width), height=44. Position flush with or just inside the top padding.
- value="WALL"
- THE WALL IS AN OBSTACLE: all arrows directed toward it must end 8px from its bottom edge. No arrow may pass through or behind it.

PITCH ARCS (curved pitch markings — also endArrow=none, same style as pitch lines):
- SMALL D-ARC: the small semicircle directly in front of the goal (~13m radius). Always present when a goalpost is shown.
- CENTRE CIRCLE / MIDFIELD ARC: the arc at the centre of the pitch.
- 2-POINTER ARC: a larger sweeping arc further out from the goal than the D-arc. This is a GAA-specific marking and may not always be present. If you see two concentric arcs in front of a goalpost — a smaller inner one (the D) and a larger outer one — the outer arc is the 2-pointer arc. Output both.
All arcs: curved edges with endArrow=none;endFill=0;strokeColor=#ffffff;strokeWidth=1.5;opacity=50;

ARROWS / MOVEMENT LINES — SMART STRAIGHT vs CURVED:
- Examine each line in the original image carefully before choosing a style:
  - STRAIGHT LINE: if the line in the image appears straight or nearly straight (less than a noticeable arc), use NO waypoints and NO curved style: edgeStyle=none;html=1;endArrow=block;endFill=1;strokeColor=#ffffff;strokeWidth=2.5;
  - SIMPLE CURVE (C-shape): the line bends in ONE direction only — use curved=1 with 1–2 intermediate waypoints: edgeStyle=none;curved=1;html=1;endArrow=block;endFill=1;strokeColor=#ffffff;strokeWidth=2.5;
  - S-CURVE / WAVE (sinusoidal): the line changes direction at least once mid-path, creating an S-shape, wave, or weave — use curved=1 with 3–5 intermediate waypoints spaced evenly along the full path, placing a waypoint at every peak, trough, and inflection point. Same style as simple curve: edgeStyle=none;curved=1;html=1;endArrow=block;endFill=1;strokeColor=#ffffff;strokeWidth=2.5;
  - DASHED WITH ARROW (ball pass/kick — rendered in yellow): edgeStyle=none;html=1;endArrow=open;endFill=0;dashed=1;dashPattern=8 4;strokeColor=#FFD700;strokeWidth=2.5;
  - DASHED WITHOUT ARROW: do not use — all dashed movement lines must have an arrowhead.
- All edges are floating (NO source or target attributes). Use sourcePoint and targetPoint in mxGeometry.
- Start/end points must be ~18px away from shape edges — arrows must not touch circles or triangles.
- CONES AND CIRCLES ARE OBSTACLES: arrows must NEVER pass through or overlap any cone or circle.
  - If an arrow travels TO a cone or circle, end it 10px from the shape's edge.
  - If an arrow passes NEAR a cone or circle but does not target it, route the arrow AROUND the shape with at least 10px clearance — add waypoints to steer clear. An arrow that crosses over a shape is always wrong.

STEP 5 — UNRECOGNISED OR AMBIGUOUS SHAPES (FALLBACK RULE):
If a drawn shape does not match any symbol defined above, DO NOT skip it. Use your visual reasoning to infer what it most likely represents in a GAA coaching context, then render it using the closest available style. Common examples:
  - Matchstick person, stick figure, or human outline → PLAYER (home red style, value="?")
  - Cone drawn in 3D, as a solid wedge, funnel, or chevron → CONE (triangle style)
  - Rectangle or shape with a written label → render as a labelled zone using:
      style="rounded=0;whiteSpace=wrap;html=1;fillColor=#37474F;opacity=80;strokeColor=#90A4AE;strokeWidth=2;fontColor=#ffffff;fontSize=13;fontStyle=1;"
      Use the written label as the value. Examples:
        "Zone A", "Box", "Grid", "Channel" → training area markers
        Any other written word or phrase → render as a labelled rectangle at its drawn position
  - Unlabelled rectangle or shaded box → area marker: style="rounded=0;whiteSpace=wrap;html=1;fillColor=#ffffff;opacity=12;strokeColor=#ffffff;strokeWidth=1.5;" value=""
  - Cross or X mark → position marker: style="text;html=1;fontColor=#ffffff;fontSize=18;fontStyle=1;" value="✕"
  - Handwritten text or number not inside any circle → text label: style="text;html=1;fontColor=#ffffff;fontSize=13;fontStyle=0;"
  - Any other identifiable drawn shape → output the best matching mxGraph shape at its approximate position
Every element visible in the sketch MUST appear in the output — never silently drop anything.

STEP 6 — HURLING AND CAMOGIE ARE THE SAME DRILL:
If the sketch contains hurling-specific elements — drawn hurls or camáns (long stick shapes), sliotars (small ball, typically not a GAA football), wall-ball setups, or any other hurling equipment — the drill applies equally to camogie. In that case, add a single small text label in the bottom-right corner of the canvas:
  style="text;html=1;align=right;verticalAlign=bottom;strokeColor=none;fillColor=none;fontColor=#FFD700;fontSize=11;fontStyle=1;"
  value="Hurling · Camogie"
  x = canvas_width - 160, y = canvas_height - 28, width=150, height=20
Do not add this label for football-only drills.

EDGE LABELS — NEVER ON THE LINE:
- Leave value="" on every edge cell.
- For each labelled arrow, create a SEPARATE text vertex placed 5px to the side of the arrow's midpoint:
  style="text;html=1;align=left;verticalAlign=middle;strokeColor=none;fillColor=none;fontColor=#ffffff;fontSize=12;fontStyle=1;"
  width=120, height=20. Offset perpendicular to the line direction, never overlapping it.

EXAMPLE STRUCTURE:
<mxGraphModel background="#2E7D32"><root>
<mxCell id="0"/>
<mxCell id="1" parent="0"/>
<mxCell id="2" value="" style="fillColor=#2E7D32;strokeColor=none;" vertex="1" parent="1"><mxGeometry x="0" y="0" width="600" height="600" as="geometry"/></mxCell>
<mxCell id="3" value="2" style="ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=15;fontStyle=1;fillColor=#C62828;gradientColor=#EF5350;gradientDirection=north;strokeColor=#B71C1C;shadow=1;fontColor=#ffffff;" vertex="1" parent="1"><mxGeometry x="277" y="80" width="46" height="46" as="geometry"/></mxCell>
<mxCell id="4" value="" style="triangle;direction=north;whiteSpace=wrap;html=1;fillColor=#FF6D00;gradientColor=#FFAB40;gradientDirection=north;strokeColor=#E65100;shadow=1;" vertex="1" parent="1"><mxGeometry x="286" y="70" width="28" height="32" as="geometry"/></mxCell>
<mxCell id="5" value="" style="edgeStyle=none;html=1;endArrow=block;endFill=1;strokeColor=#ffffff;strokeWidth=2.5;" edge="1" parent="1"><mxGeometry relative="1" as="geometry"><mxPoint x="300" y="144" as="sourcePoint"/><mxPoint x="300" y="290" as="targetPoint"/></mxGeometry></mxCell>
<mxCell id="6" value="Solo" style="text;html=1;align=left;verticalAlign=middle;strokeColor=none;fillColor=none;fontColor=#ffffff;fontSize=12;fontStyle=1;" vertex="1" parent="1"><mxGeometry x="308" y="212" width="120" height="20" as="geometry"/></mxCell>
</root></mxGraphModel>`;

const STYLE_FOOTBALL = `ellipse;whiteSpace=wrap;html=1;aspect=fixed;fillColor=#ffffff;strokeColor=#555555;shadow=0;`;
const STYLE_COACH    = `ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=15;fontStyle=1;fillColor=#1a1a1a;gradientColor=#3a3a3a;gradientDirection=north;strokeColor=#000000;shadow=1;fontColor=#ffffff;`;
const STYLE_HOME     = `ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=15;fontStyle=1;fillColor=#C62828;gradientColor=#EF5350;gradientDirection=north;strokeColor=#B71C1C;shadow=1;fontColor=#ffffff;`;
const STYLE_AWAY     = `ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=15;fontStyle=1;fillColor=#1565C0;gradientColor=#42A5F5;gradientDirection=north;strokeColor=#0D47A1;shadow=1;fontColor=#ffffff;`;

// Rewrite every ellipse cell's style based purely on its value attribute.
// The model reads labels correctly but consistently picks wrong colours — fix deterministically here.
function fixCircleStyles(xml: string): string {
  return xml.replace(/<mxCell\b[^>]+>/g, (tag) => {
    if (!/\bstyle="[^"]*\bellipse\b/.test(tag)) return tag; // not an ellipse, skip

    const m = tag.match(/\bvalue="([^"]*)"/);
    const value = (m ? m[1] : "").trim();

    let newStyle: string | null = null;
    if (value === "" || value === "." || value === "·" || value === "•") {
      newStyle = STYLE_FOOTBALL; // empty / dot → white football
    } else if (!/^\d+$/.test(value)) {
      newStyle = STYLE_COACH;    // any non-numeric label (C, Coach, etc.) → black coach
    }
    // pure numbers = players — leave style as-is

    if (newStyle === null) return tag;
    return tag.replace(/\bstyle="[^"]*"/, `style="${newStyle}"`);
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { image_base64, media_type } = await req.json();

    if (!image_base64 || !media_type) {
      return new Response(JSON.stringify({ error: "image_base64 and media_type are required" }), {
        status: 400,
        headers: { ...corsHeaders, "content-type": "application/json" },
      });
    }

    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) {
      return new Response(JSON.stringify({ error: "ANTHROPIC_API_KEY secret not set" }), {
        status: 500,
        headers: { ...corsHeaders, "content-type": "application/json" },
      });
    }

    const claudeRes = await fetch(ANTHROPIC_URL, {
      method: "POST",
      headers: {
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 16000,
        messages: [
          {
            role: "user",
            content: [
              {
                type: "image",
                source: { type: "base64", media_type, data: image_base64 },
              },
              { type: "text", text: PROMPT },
            ],
          },
        ],
      }),
    });

    if (!claudeRes.ok) {
      const errText = await claudeRes.text();
      return new Response(JSON.stringify({ error: `Anthropic API error ${claudeRes.status}`, detail: errText }), {
        status: 502,
        headers: { ...corsHeaders, "content-type": "application/json" },
      });
    }

    const claudeData = await claudeRes.json();
    console.log("Claude stop_reason:", claudeData?.stop_reason);
    console.log("Claude content blocks:", JSON.stringify(claudeData?.content?.map((c: any) => ({ type: c.type, len: c.text?.length }))));

    // Extract text from the first text-type content block
    const rawText: string = (claudeData?.content ?? [])
      .filter((c: any) => c.type === "text")
      .map((c: any) => c.text ?? "")
      .join("") ?? "";

    // Extract game name from the GAME_NAME: prefix line (if present)
    let gameName: string | null = null;
    const gameNameMatch = rawText.match(/^GAME_NAME:\s*(.+?)[\r\n]/m);
    if (gameNameMatch && gameNameMatch[1].trim()) {
      gameName = gameNameMatch[1].trim();
    }

    // Extract mxGraphModel XML — multiple fallback strategies
    let xml = rawText.trim();

    // Strip XML declaration if present
    xml = xml.replace(/^<\?xml[^?]*\?>\s*/i, "");

    // Strip markdown code fences (``` or ~~~, with optional language tag)
    xml = xml.replace(/^(`{3,}|~{3,})[a-z]*\n?/i, "").replace(/\n?(`{3,}|~{3,})$/i, "").trim();

    // Strategy 1: find <mxGraphModel...>...</mxGraphModel>
    const fullMatch = xml.match(/<mxGraphModel[\s\S]*?<\/mxGraphModel>/);
    if (fullMatch) {
      xml = fullMatch[0];
    } else {
      // Strategy 2: <mxGraphModel present but closing tag missing (truncation) — close it
      const openMatch = xml.match(/<mxGraphModel[\s\S]*/);
      if (openMatch) {
        xml = openMatch[0];
        if (!xml.includes("</root>")) xml += "</root>";
        if (!xml.endsWith("</mxGraphModel>")) xml += "</mxGraphModel>";
      } else if (xml.includes("<mxCell")) {
        // Strategy 3: bare mxCell content — wrap it
        xml = `<mxGraphModel background="#4CAF50"><root><mxCell id="0"/><mxCell id="1" parent="0"/>${xml}</root></mxGraphModel>`;
      } else {
        // Nothing recognisable — return raw so the UI can show it
        return new Response(JSON.stringify({ error: "Could not extract mxGraphModel from response", raw: rawText }), {
          status: 422,
          headers: { ...corsHeaders, "content-type": "application/json" },
        });
      }
    }

    // Post-process: enforce correct ellipse styles by value — never trust the model's colour choice.
    const xmlBefore = xml;
    xml = fixCircleStyles(xml);
    console.log("fixCircleStyles changed:", xml !== xmlBefore, "| coach cells:", (xml.match(/fillColor=#1a1a1a/g) || []).length, "| football cells:", (xml.match(/fillColor=#ffffff/g) || []).length);

    return new Response(JSON.stringify({ xml, game_name: gameName }), {
      headers: { ...corsHeaders, "content-type": "application/json" },
    });
  } catch (e: any) {
    return new Response(JSON.stringify({ error: e.message ?? "Unexpected error" }), {
      status: 500,
      headers: { ...corsHeaders, "content-type": "application/json" },
    });
  }
});
