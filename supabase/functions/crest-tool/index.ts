// Crest migration tool (2026-11-11). Copies every club crest into the public
// `crests` bucket as a 256px PNG with a one-year cache header and points
// clubs.crest at it. Idempotent and safe to call without auth: it takes no
// input beyond an optional club_id, only re-encodes the crest URL already
// stored on the club, and skips clubs whose crest is already in the bucket.
// Delete the function once every club has been migrated.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { decode, Image } from "https://deno.land/x/imagescript@1.3.0/mod.ts";

const SIZE = 256;

async function migrate(sb: ReturnType<typeof createClient>, clubId: number, crest: string, force: boolean) {
  if (!force && crest.includes("/storage/v1/object/public/crests/")) return { clubId, skipped: "already in bucket" };
  const r = await fetch(crest);
  if (!r.ok) return { clubId, error: "fetch " + r.status };
  const src = new Uint8Array(await r.arrayBuffer());
  const img = (await decode(src)) as Image;
  const scale = Math.min(SIZE / img.width, SIZE / img.height, 1);
  const w = Math.max(1, Math.round(img.width * scale)), h = Math.max(1, Math.round(img.height * scale));
  img.resize(w, h);
  const canvas = new Image(SIZE, SIZE);
  canvas.composite(img, Math.round((SIZE - w) / 2), Math.round((SIZE - h) / 2));
  const bytes = await canvas.encode(9);
  const path = `club-${clubId}.png`;
  const up = await sb.storage.from("crests").upload(path, bytes, {
    contentType: "image/png", cacheControl: "31536000", upsert: true,
  });
  if (up.error) return { clubId, error: "upload: " + up.error.message };
  const publicUrl = sb.storage.from("crests").getPublicUrl(path).data.publicUrl;
  const upd = await sb.from("clubs").update({ crest: publicUrl }).eq("club_id", clubId);
  if (upd.error) return { clubId, error: "update: " + upd.error.message };
  return { clubId, publicUrl, from: `${img.width}x${img.height} ${src.length}B`, bytes: bytes.length };
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const only = Number(url.searchParams.get("club_id") || 0);
  const force = url.searchParams.get("force") === "1";
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  let q = sb.from("clubs").select("club_id, crest").not("crest", "is", null).order("club_id");
  if (only) q = q.eq("club_id", only);
  const { data, error } = await q;
  if (error) return new Response(error.message, { status: 500 });
  const out = [];
  for (const c of data ?? []) {
    try { out.push(await migrate(sb, c.club_id, c.crest, force)); }
    catch (e) { out.push({ clubId: c.club_id, error: String(e) }); }
  }
  return new Response(JSON.stringify(out), { headers: { "Content-Type": "application/json" } });
});
