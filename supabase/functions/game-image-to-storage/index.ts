// deno-lint-ignore-file no-explicit-any
// Moves a game's pictures into Supabase storage (Ken: every image lives in storage,
// not on the website). For the game named in the body, each of game_image and
// game_details_image that is not already a coachsmartimages URL is fetched, stored
// at coachsmartimages/games/<game_id>-image|details.<ext> and replaced by a 10-year
// signed URL, like ai-process-game does for uploads.
//
// Service role only (the Authorization header must carry a service_role JWT); a
// migration wakes it through pg_net the way gaa_sync_wake wakes gaa-sync.
// POST { game_id } -> { game_id, moved: { game_image?, game_details_image? }, skipped: [...], failed: [...] }
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

const TEN_YEARS = 60 * 60 * 24 * 365 * 10;
const COLS: Array<[string, string]> = [["game_image", "image"], ["game_details_image", "details"]];

function roleOf(req: Request): string | null {
  const m = /^Bearer\s+(.+)$/i.exec(req.headers.get("Authorization") || "");
  if (!m) return null;
  try {
    const payload = JSON.parse(atob(m[1].split(".")[1].replace(/-/g, "+").replace(/_/g, "/")));
    return payload?.role ?? null;
  } catch {
    return null;
  }
}

serve(async (req) => {
  if (req.method !== "POST") return new Response("POST only", { status: 405 });
  if (roleOf(req) !== "service_role") return new Response("service role only", { status: 403 });

  const body = await req.json().catch(() => ({}));
  const gameId = Number(body?.game_id);
  if (!gameId) return new Response(JSON.stringify({ error: "game_id required" }), { status: 400 });

  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
  const { data: game, error } = await sb.from("games")
    .select("game_id, game_image, game_details_image").eq("game_id", gameId).maybeSingle();
  if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  if (!game) return new Response(JSON.stringify({ error: "no such game" }), { status: 404 });

  const moved: Record<string, string> = {}, skipped: string[] = [], failed: string[] = [];
  for (const [col, suffix] of COLS) {
    const url: string | null = (game as any)[col];
    if (!url) { skipped.push(`${col}: empty`); continue; }
    if (/\/storage\/v1\/object\/(sign|public)\/coachsmartimages\//.test(url)) { skipped.push(`${col}: already in storage`); continue; }
    try {
      const res = await fetch(url);
      if (!res.ok) throw new Error(`fetch ${res.status}`);
      const ct = (res.headers.get("content-type") || "").split(";")[0].trim() || "image/png";
      if (!/^image\/(png|jpeg|gif|webp)$/.test(ct)) throw new Error(`not an image: ${ct}`);
      const ext = ct === "image/png" ? "png" : ct === "image/gif" ? "gif" : ct === "image/webp" ? "webp" : "jpg";
      const bytes = new Uint8Array(await res.arrayBuffer());
      const path = `games/${gameId}-${suffix}.${ext}`;
      const { error: upErr } = await sb.storage.from("coachsmartimages")
        .upload(path, bytes, { contentType: ct, upsert: true });
      if (upErr) throw new Error(upErr.message);
      const { data: signed } = await sb.storage.from("coachsmartimages").createSignedUrl(path, TEN_YEARS);
      if (!signed?.signedUrl) throw new Error("no signed url");
      moved[col] = signed.signedUrl;
    } catch (e: any) {
      failed.push(`${col}: ${e?.message ?? e}`);
    }
  }

  if (Object.keys(moved).length) {
    const { error: updErr } = await sb.from("games").update(moved).eq("game_id", gameId);
    if (updErr) failed.push(`update: ${updErr.message}`);
  }
  console.log(JSON.stringify({ game_id: gameId, moved: Object.keys(moved), skipped, failed }));
  return new Response(JSON.stringify({ game_id: gameId, moved, skipped, failed }), {
    headers: { "content-type": "application/json" },
  });
});
