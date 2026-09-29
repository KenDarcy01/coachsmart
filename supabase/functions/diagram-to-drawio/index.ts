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

const PROMPT = `You are an expert at converting handwritten or hand-drawn diagrams into draw.io (mxGraph) XML.

Analyse the image carefully and produce valid draw.io XML that faithfully recreates the diagram.

Rules:
- Output ONLY the raw mxGraphModel XML — no markdown, no code fences, no explanation
- Start your response with exactly: <mxGraphModel
- Use vertex="1" cells for shapes/nodes and edge="1" cells for arrows/connections
- Preserve approximate positions, sizes, labels, and shapes from the original
- For GAA coaching diagrams: players are circles (ellipse style), cones are triangles (triangle style), arrows show movement/passes
- Use sensible x/y coordinates based on the image layout (treat image as roughly 800x600)
- Every edge must have source and target attributes pointing to valid cell ids
- Include mxCell id="0" and id="1" parent="0" as the two root cells

Example structure:
<mxGraphModel><root><mxCell id="0"/><mxCell id="1" parent="0"/><mxCell id="2" value="Player 1" style="ellipse;whiteSpace=wrap;html=1;" vertex="1" parent="1"><mxGeometry x="100" y="100" width="40" height="40" as="geometry"/></mxCell></root></mxGraphModel>`;

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

    // Extract mxGraphModel XML robustly
    let xml = rawText.trim();
    if (xml.startsWith("```")) {
      xml = xml.replace(/^```[a-z]*\n?/, "").replace(/\n?```$/, "").trim();
    }
    const modelMatch = xml.match(/<mxGraphModel[\s\S]*<\/mxGraphModel>/);
    if (modelMatch) {
      xml = modelMatch[0];
    } else if (xml.includes("<mxCell")) {
      xml = `<mxGraphModel><root><mxCell id="0"/><mxCell id="1" parent="0"/>${xml}</root></mxGraphModel>`;
    } else {
      return new Response(JSON.stringify({ error: "Could not extract mxGraphModel from response", raw: rawText }), {
        status: 422,
        headers: { ...corsHeaders, "content-type": "application/json" },
      });
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
