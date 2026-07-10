/**
 * One-time migration: download game images from Google Drive → Supabase Storage.
 * Node.js version (no Deno required).
 *
 * Run:
 *   SUPABASE_URL=https://xxx.supabase.co \
 *   SUPABASE_SERVICE_ROLE_KEY=eyJ... \
 *   node scripts/migrate_game_images_to_storage.mjs
 */

import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const BUCKET = "game-images";
const DELAY_MS = 300;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY env vars.");
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ── Ensure bucket exists ──────────────────────────────────────────────────────
console.log(`Checking storage bucket "${BUCKET}"...`);
const { data: buckets } = await supabase.storage.listBuckets();
const bucketExists = buckets?.some((b) => b.name === BUCKET);

if (!bucketExists) {
  const { error } = await supabase.storage.createBucket(BUCKET, {
    public: true,
    fileSizeLimit: 5 * 1024 * 1024,
  });
  if (error) { console.error("Failed to create bucket:", error.message); process.exit(1); }
  console.log(`  Created bucket "${BUCKET}" (public).`);
} else {
  console.log(`  Bucket "${BUCKET}" already exists.`);
}

// ── Fetch games with Drive image URLs ────────────────────────────────────────
const { data: games, error: fetchError } = await supabase
  .from("games")
  .select("game_id, game_name, game_image")
  .not("game_image", "is", null)
  .ilike("game_image", "%drive.google.com%")
  .order("game_id");

if (fetchError) { console.error("Query failed:", fetchError.message); process.exit(1); }
console.log(`\nFound ${games.length} games with Drive image URLs.\n`);

// ── Migrate ───────────────────────────────────────────────────────────────────
let success = 0, skipped = 0, failed = 0;
const failures = [];

for (const game of games) {
  const label = `[${game.game_id}] ${game.game_name}`;

  if (game.game_image?.includes(SUPABASE_URL)) {
    console.log(`  SKIP  ${label}`);
    skipped++;
    continue;
  }

  // Download
  let imageBytes, contentType;
  try {
    const resp = await fetch(game.game_image, { redirect: "follow" });
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
    contentType = resp.headers.get("content-type") ?? "image/jpeg";
    if (contentType.startsWith("text/html")) throw new Error("Drive returned HTML — file not publicly shared");
    const buf = await resp.arrayBuffer();
    imageBytes = new Uint8Array(buf);
  } catch (err) {
    const reason = `download: ${err.message}`;
    console.error(`  FAIL  ${label} — ${reason}`);
    failures.push({ name: game.game_name, reason });
    failed++;
    continue;
  }

  // Upload
  const ext = contentType.includes("png") ? "png" : contentType.includes("webp") ? "webp" : "jpg";
  const filename = `${game.game_id}.${ext}`;

  const { error: uploadError } = await supabase.storage
    .from(BUCKET)
    .upload(filename, imageBytes, { contentType, upsert: true });

  if (uploadError) {
    const reason = `upload: ${uploadError.message}`;
    console.error(`  FAIL  ${label} — ${reason}`);
    failures.push({ name: game.game_name, reason });
    failed++;
    continue;
  }

  // Get public URL and update DB
  const { data: { publicUrl } } = supabase.storage.from(BUCKET).getPublicUrl(filename);

  const { error: updateError } = await supabase
    .from("games")
    .update({ game_image: publicUrl })
    .eq("game_id", game.game_id);

  if (updateError) {
    const reason = `db: ${updateError.message}`;
    console.error(`  FAIL  ${label} — ${reason}`);
    failures.push({ name: game.game_name, reason });
    failed++;
    continue;
  }

  console.log(`  OK    ${label}`);
  success++;
  await sleep(DELAY_MS);
}

// ── Summary ───────────────────────────────────────────────────────────────────
console.log("\n─────────────────────────────────────────");
console.log(`Done: ${success} uploaded, ${skipped} already done, ${failed} failed`);
if (failures.length > 0) {
  console.log("\nFailed:");
  failures.forEach((f) => console.log(`  • ${f.name}: ${f.reason}`));
  console.log("\nFor any 'not publicly shared' failures, open the Drive file,");
  console.log("set sharing to 'Anyone with the link', then re-run this script.");
}
