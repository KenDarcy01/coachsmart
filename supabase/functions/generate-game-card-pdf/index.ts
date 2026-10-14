// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { buildPdf } from "./builder.ts";
import type { ClubData, GameData } from "./builder.ts";
import { safeName } from "../_shared/pdf-kit.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ─── Edge function handler ────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return new Response(JSON.stringify({ error: "Missing auth" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const jwt = authHeader.slice(7);
    try {
      // Validate JWT structure; sub may be absent for anon-key callers —
      // user_id from the request body is used for any DB lookups.
      const payload = jwt.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
      JSON.parse(atob(payload));
    } catch {
      return new Response(JSON.stringify({ error: "Invalid JWT" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const { game_id, game_ids, user_id: userId, platform } = body;
    const isMobile = platform === 'mobile';

    // Accept either a single game_id or an array of game_ids
    let gameIds: string[] = [];
    if (Array.isArray(game_ids) && game_ids.length > 0) {
      gameIds = game_ids;
    } else if (game_id) {
      gameIds = [game_id];
    } else {
      return new Response(JSON.stringify({ error: "Missing game_id or game_ids" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Fetch all games + user's club in parallel
    const [gamesRes, userRes] = await Promise.all([
      supabase.from("games")
        .select("game_id,game_name,game_setup,game_how_to_play,game_variations,game_teaching_points,game_image,game_details_image,game_video,game_code,game_age,game_skill,game_type")
        .in("game_id", gameIds),
      supabase.from("users")
        .select("default_club")
        .eq("user_id", userId)
        .maybeSingle(),
    ]);

    if (gamesRes.error || !gamesRes.data?.length) {
      return new Response(JSON.stringify({ error: "Games not found" }), {
        status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    let clubData: ClubData = {
      club_name: "CoachSmart",
      crest: null,
      primary_colour: "#2d7a00",
      secondary_colour: "#ffd700",
      third_colour: null,
    };

    if (userRes.data?.default_club) {
      const clubRes = await supabase.from("clubs")
        .select("club_name,crest,primary_colour,secondary_colour,third_colour")
        .eq("club_id", userRes.data.default_club)
        .maybeSingle();
      if (clubRes.data) {
        clubData = {
          club_name:        clubRes.data.club_name        || "CoachSmart",
          crest:            clubRes.data.crest            || null,
          primary_colour:   clubRes.data.primary_colour   || "#2d7a00",
          secondary_colour: clubRes.data.secondary_colour || "#ffd700",
          third_colour:     clubRes.data.third_colour     || null,
        };
      }
    }

    // Re-sort to match the caller's requested order (DB .in() returns arbitrary order)
    const gameMap = new Map((gamesRes.data as any[]).map(g => [String(g.game_id), g]));
    const orderedGames = gameIds.map(id => gameMap.get(String(id))).filter(Boolean);

    const pdfBytes = await buildPdf(orderedGames as GameData[], clubData, isMobile);

    // Chunked base64 — avoids spread-arg stack overflow on large PDFs
    let b64 = '';
    for (let i = 0; i < pdfBytes.length; i += 8192) {
      b64 += String.fromCharCode(...pdfBytes.subarray(i, i + 8192));
    }
    const base64 = btoa(b64);

    const filename = gameIds.length === 1
      ? `${safeName(gamesRes.data[0].game_name || "game_card")}.pdf`
      : `CoachSmart_Games_${gameIds.length}.pdf`;

    return new Response(JSON.stringify({ pdf: base64, filename }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (err) {
    console.error("generate-game-card-pdf error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
