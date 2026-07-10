/**
 * One-time migration: download game images from Google Drive and upload to
 * Supabase Storage, then update game_image to the permanent Supabase public URL.
 *
 * Run from the repo root (Codespace):
 *   deno run --allow-net --allow-env scripts/migrate_game_images_to_storage.ts
 *
 * Requires env vars (already set when you run `supabase start` or in Codespace):
 *   SUPABASE_URL              — e.g. https://xxxx.supabase.co
 *   SUPABASE_SERVICE_ROLE_KEY — service role key (bypasses RLS for the update)
 *
 * Safe to re-run: games already pointing at Supabase Storage are skipped.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ── Config ────────────────────────────────────────────────────────────────────

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const BUCKET = "game-images";
const DELAY_MS = 250; // gap between Drive fetches to avoid rate-limiting

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error(
    "Missing env vars. Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY."
  );
  Deno.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

// ── Ensure bucket exists ──────────────────────────────────────────────────────

console.log(`Checking storage bucket "${BUCKET}"...`);
const { data: buckets } = await supabase.storage.listBuckets();
const bucketExists = buckets?.some((b) => b.name === BUCKET);

if (!bucketExists) {
  const { error } = await supabase.storage.createBucket(BUCKET, {
    public: true,
    fileSizeLimit: 5 * 1024 * 1024, // 5 MB per image
  });
  if (error) {
    console.error("Failed to create bucket:", error.message);
    Deno.exit(1);
  }
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

if (fetchError) {
  console.error("Failed to query games:", fetchError.message);
  Deno.exit(1);
}

console.log(`\nFound ${games.length} games with Drive image URLs.\n`);

// ── Migrate each image ────────────────────────────────────────────────────────

let success = 0;
let skipped = 0;
let failed = 0;
const failures: { name: string; reason: string }[] = [];

for (const game of games) {
  const label = `[${game.game_id}] ${game.game_name}`;

  // Skip if already pointing at Supabase Storage
  if (game.game_image?.includes(SUPABASE_URL)) {
    console.log(`  SKIP  ${label}`);
    skipped++;
    continue;
  }

  // ── Download from Drive ──
  let imageBytes: Uint8Array;
  let contentType: string;

  try {
    const resp = await fetch(game.game_image, { redirect: "follow" });

    if (!resp.ok) {
      throw new Error(`HTTP ${resp.status} ${resp.statusText}`);
    }

    contentType = resp.headers.get("content-type") ?? "image/jpeg";

    // Guard: if Drive returned HTML (redirect to login page), fail fast
    if (contentType.startsWith("text/html")) {
      throw new Error(
        "Drive returned HTML — file may not be publicly shared"
      );
    }

    imageBytes = new Uint8Array(await resp.arrayBuffer());
  } catch (err) {
    const reason = err instanceof Error ? err.message : String(err);
    console.error(`  FAIL  ${label} — download: ${reason}`);
    failures.push({ name: game.game_name, reason: `download: ${reason}` });
    failed++;
    continue;
  }

  // ── Derive filename ──
  const ext = contentType.includes("png")
    ? "png"
    : contentType.includes("webp")
    ? "webp"
    : contentType.includes("gif")
    ? "gif"
    : "jpg";
  const filename = `${game.game_id}.${ext}`;

  // ── Upload to Supabase Storage ──
  const { error: uploadError } = await supabase.storage
    .from(BUCKET)
    .upload(filename, imageBytes, { contentType, upsert: true });

  if (uploadError) {
    console.error(`  FAIL  ${label} — upload: ${uploadError.message}`);
    failures.push({
      name: game.game_name,
      reason: `upload: ${uploadError.message}`,
    });
    failed++;
    continue;
  }

  // ── Get the permanent public URL ──
  const {
    data: { publicUrl },
  } = supabase.storage.from(BUCKET).getPublicUrl(filename);

  // ── Update the DB row ──
  const { error: updateError } = await supabase
    .from("games")
    .update({ game_image: publicUrl })
    .eq("game_id", game.game_id);

  if (updateError) {
    console.error(`  FAIL  ${label} — db update: ${updateError.message}`);
    failures.push({
      name: game.game_name,
      reason: `db update: ${updateError.message}`,
    });
    failed++;
    continue;
  }

  console.log(`  OK    ${label}`);
  console.log(`        ${publicUrl}`);
  success++;

  // Small delay to be polite to Google Drive
  await new Promise((r) => setTimeout(r, DELAY_MS));
}

// ── Summary ───────────────────────────────────────────────────────────────────

console.log("\n─────────────────────────────────────────");
console.log(`Done: ${success} uploaded, ${skipped} already done, ${failed} failed`);

if (failures.length > 0) {
  console.log("\nFailed games:");
  for (const f of failures) {
    console.log(`  • ${f.name}: ${f.reason}`);
  }
  console.log(
    "\nTip: failed images were likely not shared publicly on Drive."
  );
  console.log(
    "     Open each Drive file → Share → 'Anyone with the link' → re-run."
  );
}
