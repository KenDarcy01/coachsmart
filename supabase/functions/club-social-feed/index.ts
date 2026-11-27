// deno-lint-ignore-file no-explicit-any
// Club news from the club's own social posts (Ken 2026-11-27).
//
// Woken every 30 minutes by club_social_sync_run (pg_cron). For each club
// with clubs.social_feed_url it reads the club's website and mirrors the
// social feed shown there: today the Squarespace Instagram block (Clontarf,
// clontarfgaa.com), which already syncs the club's Instagram. Each post's
// photo is copied once into the public club-social bucket, so the app never
// depends on the website or links to Instagram. Posts are upserted into
// club_social_posts; v3 reads them through get_club_social_posts.
//
// POST {}  or  { club_id }  (service role only)
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

function roleOf(req: Request): string {
  try {
    const jwt = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
    const part = jwt.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    return JSON.parse(atob(part + "===".slice((part.length + 3) % 4))).role || "";
  } catch {
    return "";
  }
}

const UA = "Mozilla/5.0 (compatible; CoachSmart club feed)";

function decode(s: string): string {
  // Squarespace double-encodes captions (&amp;rsquo;): decode twice.
  const once = (t: string) =>
    t.replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(+n))
      .replace(/&#x([0-9a-f]+);/gi, (_, n) => String.fromCodePoint(parseInt(n, 16)))
      .replace(/&(rsquo|lsquo);/g, "'").replace(/&(rdquo|ldquo);/g, '"')
      .replace(/&euro;/g, "€").replace(/&nbsp;/g, " ").replace(/&ndash;/g, "–")
      .replace(/&mdash;/g, "—").replace(/&hellip;/g, "…").replace(/&quot;/g, '"')
      .replace(/&#39;|&apos;/g, "'").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
      .replace(/&amp;/g, "&");
  return once(once(s)).trim();
}

type Post = { key: string; src: string; caption: string; postedAt: string | null };

/** Posts in a Squarespace Instagram block, newest first as the site shows them. */
function squarespaceInstagram(html: string): Post[] {
  const out: Post[] = [];
  let i = html.indexOf("sqs-block-instagram");
  while (i >= 0) {
    const end = html.indexOf("sqs-block ", i + 40);
    const block = html.slice(i, end > 0 ? end : undefined);
    const re = /data-description="([^"]*)"[\s\S]*?href="(https:\/\/images\.squarespace-cdn\.com\/content\/v1\/[^/"]+\/((\d{10,})-[A-Z0-9]+)\/[^"]+)"/g;
    let m;
    while ((m = re.exec(block))) {
      const ms = Number(m[4]);
      out.push({
        key: m[3],
        src: m[2],
        caption: decode(m[1]),
        postedAt: ms > 1.5e12 && ms < 4e12 ? new Date(ms).toISOString() : null,
      });
    }
    i = html.indexOf("sqs-block-instagram", end > 0 ? end : html.length);
  }
  return out;
}

Deno.serve(async (req) => {
  if (roleOf(req) !== "service_role") return new Response("Forbidden", { status: 403 });
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  let only: number | null = null;
  try {
    const b = await req.json();
    if (b?.club_id) only = Number(b.club_id);
  } catch { /* no body */ }

  let q = sb.from("clubs").select("club_id, social_feed_url").not("social_feed_url", "is", null);
  if (only) q = q.eq("club_id", only);
  const { data: clubs, error } = await q;
  if (error) return Response.json({ error: error.message }, { status: 500 });

  const report: any[] = [];
  for (const c of clubs || []) {
    const url = String(c.social_feed_url || "").trim();
    if (!url) continue;
    try {
      const res = await fetch(url, { headers: { "User-Agent": UA }, redirect: "follow" });
      if (!res.ok) throw new Error(`feed ${res.status}`);
      const posts = squarespaceInstagram(await res.text());
      const { data: have } = await sb.from("club_social_posts")
        .select("ext_key, image_url").eq("club_id", c.club_id)
        .in("ext_key", posts.length ? posts.map((p) => p.key) : ["-"]);
      const stored = new Map((have || []).map((h: any) => [h.ext_key, h.image_url]));
      let added = 0;
      for (const p of posts) {
        let image = stored.get(p.key) || null;
        if (!image) {
          // A phone-sized copy (750px wide) in our own bucket.
          const img = await fetch(`${p.src}?format=750w`, { headers: { "User-Agent": UA } });
          if (img.ok) {
            const type = img.headers.get("content-type") || "image/jpeg";
            const ext = type.includes("webp") ? "webp" : type.includes("png") ? "png" : "jpg";
            const path = `club-${c.club_id}/${p.key}.${ext}`;
            const up = await sb.storage.from("club-social")
              .upload(path, new Uint8Array(await img.arrayBuffer()), { contentType: type, upsert: true });
            if (!up.error) {
              image = sb.storage.from("club-social").getPublicUrl(path).data.publicUrl;
              added++;
            }
          }
        }
        await sb.from("club_social_posts").upsert({
          club_id: c.club_id,
          source: "instagram",
          ext_key: p.key,
          source_url: p.src,
          image_url: image,
          caption: p.caption,
          posted_at: p.postedAt,
          last_seen: new Date().toISOString(),
        }, { onConflict: "club_id,ext_key" });
      }
      report.push({ club_id: c.club_id, found: posts.length, new_images: added });
    } catch (e) {
      report.push({ club_id: c.club_id, error: String((e as Error).message || e) });
    }
  }
  console.log(JSON.stringify(report));
  return Response.json({ ok: true, report });
});
