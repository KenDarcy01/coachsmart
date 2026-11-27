// deno-lint-ignore-file no-explicit-any
// AI usage log (Ken 2026-11-27: "AI spend per day" in the nightly health report).
//
// aiFetch() is a drop-in for fetch() on calls to Gemini or Anthropic. It
// returns the same Response untouched, and in the background reads the token
// counts from a copy of the answer and saves one row in public.ai_usage with
// an estimated cost. Logging can never break or slow the feature: every
// failure is swallowed.

// USD per million tokens. Estimates for the report; check against the bills.
const PRICES: Record<string, { in: number; out: number; audioIn?: number }> = {
  "gemini-2.5-flash": { in: 0.30, out: 2.50, audioIn: 1.00 },
  "gemini-2.5-flash-lite": { in: 0.10, out: 0.40, audioIn: 0.30 },
  "gemini-2.5-pro": { in: 1.25, out: 10.0 },
  "claude-fable-5-1": { in: 10, out: 50 },
  "claude-fable-5-2": { in: 10, out: 50 },
};

function priceFor(model: string) {
  if (PRICES[model]) return PRICES[model];
  const k = Object.keys(PRICES).sort((a, b) => b.length - a.length).find((p) => model.startsWith(p));
  return k ? PRICES[k] : null;
}

function modelFromUrl(url: string): string {
  const m = url.match(/models\/([^:/?]+)/);
  return m ? m[1] : "";
}

async function record(feature: string, url: string, init: RequestInit | undefined, res: Response) {
  try {
    const j: any = await res.json();
    let provider = "", model = "", input = 0, output = 0, audioIn = 0, cacheRead = 0, cacheWrite = 0;
    if (url.includes("anthropic.com")) {
      provider = "anthropic";
      model = String(j?.model || "");
      if (!model) { try { model = JSON.parse(String(init?.body || "{}")).model || ""; } catch { /* */ } }
      input = Number(j?.usage?.input_tokens || 0);
      output = Number(j?.usage?.output_tokens || 0);
      cacheRead = Number(j?.usage?.cache_read_input_tokens || 0);
      cacheWrite = Number(j?.usage?.cache_creation_input_tokens || 0);
    } else {
      provider = "google";
      model = String(j?.modelVersion || modelFromUrl(url));
      const u = j?.usageMetadata || {};
      input = Number(u.promptTokenCount || 0);
      output = Number(u.candidatesTokenCount || 0) + Number(u.thoughtsTokenCount || 0);
      for (const d of u.promptTokensDetails || []) if (d?.modality === "AUDIO") audioIn += Number(d.tokenCount || 0);
    }
    const p = priceFor(model);
    const cost = p
      ? ((input - audioIn) * p.in + audioIn * (p.audioIn ?? p.in) + output * p.out + cacheRead * p.in * 0.1 + cacheWrite * p.in * 1.25) / 1e6
      : null;
    const base = Deno.env.get("SUPABASE_URL");
    const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!base || !key) return;
    await fetch(`${base}/rest/v1/ai_usage`, {
      method: "POST",
      headers: { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json", Prefer: "return=minimal" },
      body: JSON.stringify({
        feature, provider, model,
        input_tokens: input + cacheRead + cacheWrite, output_tokens: output,
        cost_usd: cost === null ? null : Math.round(cost * 1e6) / 1e6,
      }),
    });
  } catch (_) { /* never let logging affect the feature */ }
}

export async function aiFetch(feature: string, url: string, init?: RequestInit): Promise<Response> {
  const res = await fetch(url, init);
  if (res.ok) {
    const p = record(feature, url, init, res.clone());
    try { (globalThis as any).EdgeRuntime?.waitUntil?.(p); } catch { /* */ }
  }
  return res;
}
