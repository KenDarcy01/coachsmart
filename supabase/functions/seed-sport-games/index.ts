// deno-lint-ignore-file no-explicit-any
// One-off starter library for soccer and rugby clubs (multi-sport, Ken 2026-11-14).
//
// Adds the 40 starter games in games.json (20 soccer, 20 rugby) as public games,
// HIDDEN (is_active = false) until Ken has checked them. Each diagram is fetched
// from coachsmart.app/img/game-seed/<slug>.png (deployed with the website),
// stored in coachsmartimages/games/starter/<slug>.png like every other game
// picture, and linked with a 10-year signed URL. games.sport_id is set by the
// games_set_sport trigger from the code (Soccer -> 2, Rugby -> 3).
//
// Idempotent: a game already there (same name and code) is skipped, so calling
// it again does nothing. POST {} -> { added: [...], skipped: [...], failed: [...] }
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import games from "./games.ts";

const SITE = "https://coachsmart.app/img/game-seed/";
const TEN_YEARS = 60 * 60 * 24 * 365 * 10;

serve(async (req) => {
  if (req.method !== "POST") return new Response("POST only", { status: 405 });
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
  const added: string[] = [], skipped: string[] = [], failed: string[] = [];
  for (const g of games as any[]) {
    try {
      const { data: have } = await sb.from("games").select("game_id")
        .eq("game_name", g.game_name).contains("game_code", g.game_code).limit(1);
      if (have && have.length) { skipped.push(g.slug); continue; }

      const res = await fetch(SITE + g.slug + ".png");
      if (!res.ok) throw new Error(`picture ${res.status}`);
      const bytes = new Uint8Array(await res.arrayBuffer());
      const path = `games/starter/${g.slug}.png`;
      const { error: upErr } = await sb.storage.from("coachsmartimages")
        .upload(path, bytes, { contentType: "image/png", upsert: true });
      if (upErr) throw new Error(upErr.message);
      const { data: signed } = await sb.storage.from("coachsmartimages").createSignedUrl(path, TEN_YEARS);
      if (!signed?.signedUrl) throw new Error("no signed url");

      const { error: insErr } = await sb.from("games").insert({
        game_name: g.game_name,
        game_code: g.game_code,
        game_type: g.game_type,
        game_age: g.game_age,
        game_skill: g.game_skill,
        game_setup: g.game_setup,
        game_how_to_play: g.game_how_to_play,
        game_variations: g.game_variations,
        game_teaching_points: g.game_teaching_points,
        game_image: signed.signedUrl,
        club_id: null,
        is_active: false,
      });
      if (insErr) throw new Error(insErr.message);
      added.push(g.slug);
    } catch (e: any) {
      failed.push(`${g.slug}: ${e?.message ?? e}`);
    }
  }
  return new Response(JSON.stringify({ added, skipped, failed }), { headers: { "content-type": "application/json" } });
});
