// deno-lint-ignore-file no-explicit-any
// Stripe Connect helpers shared by club payments (lotto now, membership next).
// Each club has one connected account, clubs.stripe_account_id, and charges are
// made directly on it by sending the Stripe-Account header.

// The club's connected account from a row that joined clubs(stripe_account_id).
export function clubStripeAccount(row: any): string | null {
  return row?.clubs?.stripe_account_id || row?.stripe_account_id || null;
}

// ── Stripe (REST, form-encoded) ───────────────────────────────────────────────
function stripeKey() {
  const k = Deno.env.get("STRIPE_SECRET_KEY");
  if (!k) throw new Error("Stripe key is not set");
  return k;
}

function formEncode(obj: any, prefix = "", out: string[] = []) {
  for (const [k, v] of Object.entries(obj ?? {})) {
    if (v === undefined || v === null) continue;
    const key = prefix ? `${prefix}[${k}]` : k;
    if (typeof v === "object") formEncode(v, key, out);
    else out.push(encodeURIComponent(key) + "=" + encodeURIComponent(String(v)));
  }
  return out.join("&");
}

export async function stripe(method: string, path: string, params: any = null, account: string | null = null) {
  const headers: Record<string, string> = { Authorization: "Bearer " + stripeKey() };
  if (account) headers["Stripe-Account"] = account;
  let url = "https://api.stripe.com/v1" + path;
  let body: string | undefined;
  if (params && method === "GET") url += "?" + formEncode(params);
  else if (params) {
    body = formEncode(params);
    headers["Content-Type"] = "application/x-www-form-urlencoded";
  }
  const res = await fetch(url, { method, headers, body });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data?.error?.message || `Stripe error ${res.status}`);
  return data;
}

// Stripe-Signature check (v1 HMAC-SHA256 over "<t>.<body>", 5 minute tolerance).
export async function verifyStripeSignature(body: string, header: string, secret: string) {
  const parts = Object.fromEntries(header.split(",").map(p => p.split("=", 2)).filter(p => p.length === 2)) as any;
  const sigs = header.split(",").filter(p => p.startsWith("v1=")).map(p => p.slice(3));
  const t = Number(parts.t);
  if (!t || !sigs.length || Math.abs(Date.now() / 1000 - t) > 300) return false;
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const mac = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${t}.${body}`)));
  const hex = [...mac].map(b => b.toString(16).padStart(2, "0")).join("");
  return sigs.some(s => s.length === hex.length && [...s].every((c, i) => c === hex[i]));
}

