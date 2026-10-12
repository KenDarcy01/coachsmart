// Supabase Edge Function: GAA fixtures -> calendar feed (.ics) or JSON.
//
//   GET /functions/v1/gaa-fixtures?comp=215248&team=Raheny
//   GET /functions/v1/gaa-fixtures?comp=215248,215300&team=Raheny&results=1
//   GET /functions/v1/gaa-fixtures?comp=215248&team=Raheny&format=json
//
// Query params
//   comp     required. One or more competition IDs, comma separated (the number
//            in …sportlomo.com/league-2/<ID>/). Numbers only.
//   team     optional. Club name substring, e.g. "Raheny".
//   results  optional. "1" to include games already played.
//   minutes  optional. Event length, default 60.
//   name     optional. Calendar name shown in the calendar app.
//   format   optional. "ics" (default) or "json".
import { buildIcs, filterGames, type Game, parseGames } from "./gaa.ts";

const BASE = "https://dublingaa.sportlomo.com/league-2";
const UA = "Mozilla/5.0 (compatible; gaa-fixtures-feed)";
const CACHE_MS = 10 * 60 * 1000;

// Warm-instance cache so repeated calendar polls don't hammer the source site.
const cache = new Map<string, { at: number; games: Game[] }>();

async function loadComp(compId: string): Promise<Game[]> {
  const hit = cache.get(compId);
  if (hit && Date.now() - hit.at < CACHE_MS) return hit.games;

  const res = await fetch(`${BASE}/${compId}/`, {
    headers: { "User-Agent": UA, "Accept": "text/html" },
    signal: AbortSignal.timeout(15_000),
  });
  if (!res.ok) throw new Error(`Source site returned ${res.status} for competition ${compId}`);
  const games = parseGames(await res.text(), compId);
  cache.set(compId, { at: Date.now(), games });
  return games;
}

const text = (body: string, status: number) =>
  new Response(body, { status, headers: { "Content-Type": "text/plain; charset=utf-8" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  const q = new URL(req.url).searchParams;

  const comps = (q.get("comp") ?? "").split(",").map((s) => s.trim()).filter(Boolean);
  if (!comps.length) return text("Missing ?comp=<competition id>", 400);
  // Digits only: the ID goes into a URL on a fixed host, nothing else.
  if (!comps.every((c) => /^\d{1,10}$/.test(c))) return text("comp must be numeric IDs", 400);

  const team = q.get("team")?.trim() || undefined;
  const results = q.get("results") === "1";
  const minutes = Math.min(300, Math.max(15, Number(q.get("minutes")) || 60));
  const format = q.get("format") === "json" ? "json" : "ics";

  let games: Game[];
  try {
    games = (await Promise.all(comps.map(loadComp))).flat();
  } catch (e) {
    console.error(e);
    return text(`Could not load fixtures: ${(e as Error).message}`, 502);
  }
  games = filterGames(games, { team, results });

  const common = {
    "Cache-Control": "public, max-age=900",
    "Access-Control-Allow-Origin": "*",
  };

  if (format === "json") {
    return new Response(
      JSON.stringify(
        games.map((g) => ({
          kind: g.kind,
          competition: g.comp,
          competitionId: g.compId,
          start: g.startUtc.toISOString(),
          home: g.home,
          away: g.away,
          score: g.score || null,
          venue: g.venue || null,
          referee: g.referee || null,
          note: g.note || null,
        })),
      ),
      { headers: { ...common, "Content-Type": "application/json; charset=utf-8" } },
    );
  }

  const calName = q.get("name")?.trim() || `${team ?? "GAA"} fixtures`;
  return new Response(buildIcs(games, calName, minutes), {
    headers: {
      ...common,
      "Content-Type": "text/calendar; charset=utf-8",
      "Content-Disposition": 'inline; filename="fixtures.ics"',
    },
  });
});
