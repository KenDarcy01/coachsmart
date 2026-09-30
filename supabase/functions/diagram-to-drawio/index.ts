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

Analyse the image carefully and produce valid draw.io XML using these EXACT visual rules:

OUTPUT FORMAT:
- Output ONLY raw XML — no markdown fences, no explanation, nothing before or after the XML
- Start your response with exactly: <mxGraphModel background="#2E7D32"
- Include mxCell id="0" and id="1" parent="0" as the two root cells

CANVAS SIZE — MATCH THE CONTENT:
- Analyse the overall shape of the content in the image and choose the canvas that best fits:
  - SQUARE drill (content roughly equal width and height): width=600, height=600
  - PORTRAIT pitch (content taller than wide — e.g. full pitch with goals at top and bottom): width=500, height=700
  - LANDSCAPE pitch (content wider than tall — e.g. half-pitch or sideline view): width=720, height=480
- Set background="#2E7D32" on the mxGraphModel element and use the chosen width/height for the background rectangle.
- PADDING: all shapes and arrow endpoints must stay at least 60px from every edge. Safe area is x: 60 to (width−60), y: 60 to (height−60).
- Scale all positions from the original image proportionally to fill the chosen canvas.

PLAYERS (circles):
- Ellipse, width=46, height=46
- Home team: style="ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=15;fontStyle=1;fillColor=#C62828;gradientColor=#EF5350;gradientDirection=north;strokeColor=#B71C1C;shadow=1;fontColor=#ffffff;"
- Away team (same number = opposite team): style="ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=15;fontStyle=1;fillColor=#1565C0;gradientColor=#42A5F5;gradientDirection=north;strokeColor=#0D47A1;shadow=1;fontColor=#ffffff;"
- If only one team visible, use home (red) style for all.

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

ARROWS / MOVEMENT LINES — SMART STRAIGHT vs CURVED:
- Examine each line in the original image carefully before choosing a style:
  - STRAIGHT LINE: if the line in the image appears straight or nearly straight (less than a noticeable arc), use NO waypoints and NO curved style: edgeStyle=none;html=1;endArrow=block;endFill=1;strokeColor=#ffffff;strokeWidth=2.5;
  - SIMPLE CURVE (C-shape): the line bends in ONE direction only — use curved=1 with 1–2 intermediate waypoints: edgeStyle=none;curved=1;html=1;endArrow=block;endFill=1;strokeColor=#ffffff;strokeWidth=2.5;
  - S-CURVE / WAVE (sinusoidal): the line changes direction at least once mid-path, creating an S-shape, wave, or weave — use curved=1 with 5–8 intermediate waypoints spaced evenly along the full path, placing a waypoint at every peak, trough, and inflection point. More waypoints produce smoother rendered curves. Same style as simple curve: edgeStyle=none;curved=1;html=1;endArrow=block;endFill=1;strokeColor=#ffffff;strokeWidth=2.5;
  - DASHED (ball pass/kick): edgeStyle=none;html=1;endArrow=open;endFill=0;dashed=1;dashPattern=8 4;strokeColor=#ffffff;strokeWidth=2.5;
- All edges are floating (NO source or target attributes). Use sourcePoint and targetPoint in mxGeometry.
- Start/end points must be ~18px away from shape edges — arrows must not touch circles or triangles.
- CONES AND CIRCLES ARE OBSTACLES: arrows must NEVER pass through or overlap any cone or circle.
  - If an arrow travels TO a cone or circle, end it 5px from the shape's edge.
  - If an arrow passes NEAR a cone or circle but does not target it, route the arrow AROUND the shape with at least 5px clearance — add waypoints to steer clear. An arrow that crosses over a shape is always wrong.

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
        max_tokens: 8192,
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

    return new Response(JSON.stringify({ xml }), {
      headers: { ...corsHeaders, "content-type": "application/json" },
    });
  } catch (e: any) {
    return new Response(JSON.stringify({ error: e.message ?? "Unexpected error" }), {
      status: 500,
      headers: { ...corsHeaders, "content-type": "application/json" },
    });
  }
});
