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

const PROMPT = `You are an expert at converting handwritten or hand-drawn GAA (Gaelic Athletic Association) coaching diagrams into draw.io (mxGraph) XML.

Analyse the image carefully and produce valid draw.io XML using these EXACT visual rules:

OUTPUT FORMAT:
- Output ONLY raw XML — no markdown fences, no explanation, nothing before or after the XML
- Start your response with exactly: <mxGraphModel background="#4CAF50"
- Include mxCell id="0" and id="1" parent="0" as the two root cells

BACKGROUND:
- Set background="#4CAF50" on the mxGraphModel element (grass green)
- Add a large filled rectangle as the FIRST cell covering the full diagram area:
  style="fillColor=#4CAF50;strokeColor=none;" vertex="1"

PLAYERS (circles/blobs):
- Render each player as an ellipse, width=44, height=44
- Style base: ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=14;fontStyle=1;
- TEAM COLOURS — this is critical: if two players share the same number or label, one belongs to each team. Alternate red vs blue to tell them apart.
  - Home team / first team seen: fillColor=#CC0000;fontColor=#ffffff;strokeColor=#990000;
  - Away team / opponent (same number as a home player): fillColor=#1565C0;fontColor=#ffffff;strokeColor=#0D47A1;
  - If only one team visible, use red for all players.

CONES (triangles):
- Render each cone as a triangle, width=30, height=30
- Style: triangle;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#555555;

ARROWS / MOVEMENT LINES:
- Use floating edges (NO source or target attributes on the mxCell)
- Position each edge's start point ~20px away from the edge of the origin shape, and end point ~20px away from the edge of the destination shape — arrows must NOT touch or overlap any circle or triangle
- Use an Array of mxPoint inside mxGeometry to define the path: <mxGeometry relative="1" as="geometry"><Array as="points"><mxPoint x="..." y="..."/></Array></mxGeometry>
- The edge cell's mxGeometry must also include sourcePoint and targetPoint as child elements: <mxPoint x="..." y="..." as="sourcePoint"/> and <mxPoint x="..." y="..." as="targetPoint"/>
- Arrow styles:
  - Player run (solid): edgeStyle=none;html=1;endArrow=block;endFill=1;strokeColor=#ffffff;strokeWidth=2;
  - Ball pass (dashed): edgeStyle=none;html=1;endArrow=open;endFill=0;dashed=1;strokeColor=#ffffff;strokeWidth=2;
  - If unsure, use the solid run style

COORDINATES:
- Map the image layout onto an 800×600 coordinate space
- Place the background rectangle at x=0, y=0, width=800, height=600

EXAMPLE STRUCTURE:
<mxGraphModel background="#4CAF50"><root>
<mxCell id="0"/>
<mxCell id="1" parent="0"/>
<mxCell id="2" value="" style="fillColor=#4CAF50;strokeColor=none;" vertex="1" parent="1"><mxGeometry x="0" y="0" width="800" height="600" as="geometry"/></mxCell>
<mxCell id="3" value="1" style="ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=14;fontStyle=1;fillColor=#CC0000;fontColor=#ffffff;strokeColor=#990000;" vertex="1" parent="1"><mxGeometry x="378" y="50" width="44" height="44" as="geometry"/></mxCell>
<mxCell id="4" value="1" style="ellipse;whiteSpace=wrap;html=1;aspect=fixed;fontSize=14;fontStyle=1;fillColor=#1565C0;fontColor=#ffffff;strokeColor=#0D47A1;" vertex="1" parent="1"><mxGeometry x="378" y="300" width="44" height="44" as="geometry"/></mxCell>
<mxCell id="5" value="" style="edgeStyle=none;html=1;endArrow=block;endFill=1;strokeColor=#ffffff;strokeWidth=2;" edge="1" parent="1"><mxGeometry relative="1" as="geometry"><mxPoint x="400" y="114" as="sourcePoint"/><mxPoint x="400" y="280" as="targetPoint"/></mxGeometry></mxCell>
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
    const rawText: string = claudeData?.content?.[0]?.text ?? "";

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
