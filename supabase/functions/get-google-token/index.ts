// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { encode as base64urlEncode } from "https://deno.land/std@0.168.0/encoding/base64url.ts";
function getGoogleOAuthToken(clientEmail, privateKey) {
  const now = Math.floor(Date.now() / 1000);
  const header = {
    alg: "RS256",
    typ: "JWT"
  };
  const payload = {
    iss: clientEmail,
    scope: "https://www.googleapis.com/auth/drive https://www.googleapis.com/auth/spreadsheets",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now
  };
  const encodedHeader = base64urlEncode(JSON.stringify(header));
  const encodedPayload = base64urlEncode(JSON.stringify(payload));
  const unsignedToken = `${encodedHeader}.${encodedPayload}`;
  const cryptoKey = crypto.subtle.importKey("pkcs8", pemToBinary(privateKey), {
    name: "RSASSA-PKCS1-v1_5",
    hash: "SHA-256"
  }, false, [
    "sign"
  ]);
  return cryptoKey.then((key)=>crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsignedToken))).then((signature)=>fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded"
      },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: `${unsignedToken}.${base64urlEncode(signature)}`
      })
    }).then((res)=>{
      if (!res.ok) {
        return res.text().then((text)=>{
          throw new Error(`Google token request failed: ${res.status} - ${text}`);
        });
      }
      return res.json();
    }).then((data)=>data.access_token));
}
function pemToBinary(pem) {
  const lines = pem.trim().split("\n");
  const base64 = lines.filter((line)=>!line.includes("BEGIN") && !line.includes("END")).join("");
  const binary = atob(base64);
  const buffer = new Uint8Array(binary.length);
  for(let i = 0; i < binary.length; i++){
    buffer[i] = binary.charCodeAt(i);
  }
  return buffer.buffer;
}
serve(async (req)=>{
  // ✅ Handle CORS preflight request
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, content-type"
      }
    });
  }
  try {
    const clientEmail = Deno.env.get("GOOGLE_CLIENT_EMAIL");
    const privateKey = Deno.env.get("GOOGLE_PRIVATE_KEY")?.replace(/\\n/g, "\n");
    if (!clientEmail || !privateKey) {
      throw new Error("Missing GOOGLE_CLIENT_EMAIL or GOOGLE_PRIVATE_KEY environment variables");
    }
    const token = await getGoogleOAuthToken(clientEmail, privateKey);
    return new Response(JSON.stringify({
      access_token: token
    }), {
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      }
    });
  } catch (error) {
    return new Response(JSON.stringify({
      error: error.message,
      stack: error.stack
    }), {
      status: 500,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      }
    });
  }
});
