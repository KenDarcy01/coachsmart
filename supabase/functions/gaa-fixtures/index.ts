// Supabase Edge Function: GAA fixtures -> calendar feed (.ics) or JSON.
//
//   GET /functions/v1/gaa-fixtures?comp=215248&team=Raheny
//   GET /functions/v1/gaa-fixtures?comp=215248,215300&team=Raheny&results=1
//   GET /functions/v1/gaa-fixtures?comp=215248&team=Raheny&format=json
//   GET /functions/v1/gaa-fixtures?comp=215248&type=table
//   GET /functions/v1/gaa-fixtures?type=discover&search=U13
//
// Query params
//   comp     required (except for type=discover). One or more competition IDs,
//            comma separated (the number in …sportlomo.com/league-2/<ID>/).
//   type     optional. "table" | "discover". discover returns [{id,name}] of
//            all competitions found on the Dublin GAA site that match ?search=.
//   search   optional (type=discover only). Case-insensitive substring filter.
//   team     optional. Club name substring, e.g. "Raheny".
//   results  optional. "1" to include games already played.
//   minutes  optional. Event length, default 60.
//   name     optional. Calendar name shown in the calendar app.
//   format   optional. "ics" (default) or "json".
import { buildIcs, discoverComps, filterGames, type Game, parseGames, parseTable } from "./gaa.ts";

const BASE = "https://dublingaa.sportlomo.com/league-2";
const UA = "Mozilla/5.0 (compatible; gaa-fixtures-feed)";
const CACHE_MS = 10 * 60 * 1000;

// Warm-instance cache so repeated calendar polls don't hammer the source site.
const cache = new Map<string, { at: number; html: string; games: Game[] }>();

async function loadComp(compId: string): Promise<{ html: string; games: Game[] }> {
  const hit = cache.get(compId);
  if (hit && Date.now() - hit.at < CACHE_MS) return hit;

  const res = await fetch(`${BASE}/${compId}/`, {
    headers: { "User-Agent": UA, "Accept": "text/html" },
    signal: AbortSignal.timeout(15_000),
  });
  if (!res.ok) throw new Error(`Source site returned ${res.status} for competition ${compId}`);
  const html = await res.text();
  const games = parseGames(html, compId);
  cache.set(compId, { at: Date.now(), html, games });
  return { html, games };
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
  const type = q.get("type") ?? "";

  const common = {
    "Cache-Control": "public, max-age=900",
    "Access-Control-Allow-Origin": "*",
  };

  // ── Competition discovery ───────────────────────────────────────────────
  if (type === "discover") {
    const search = q.get("search")?.trim() ?? "";
    let html: string;
    try {
      const res = await fetch(`${BASE}/`, {
        headers: { "User-Agent": UA, "Accept": "text/html" },
        signal: AbortSignal.timeout(15_000),
      });
      if (!res.ok) throw new Error(`Source site returned ${res.status}`);
      html = await res.text();
    } catch (e) {
      console.error(e);
      return text(`Could not reach source site: ${(e as Error).message}`, 502);
    }
    const found = discoverComps(html, search);
    return new Response(JSON.stringify(found), {
      headers: { ...common, "Content-Type": "application/json; charset=utf-8" },
    });
  }

  const comps = (q.get("comp") ?? "").split(",").map((s) => s.trim()).filter(Boolean);
  if (!comps.length) return text("Missing ?comp=<competition id>", 400);
  // Digits only: the ID goes into a URL on a fixed host, nothing else.
  if (!comps.every((c) => /^\d{1,10}$/.test(c))) return text("comp must be numeric IDs", 400);

  const reqType = type === "table" ? "table" : "fixtures";
  const team = q.get("team")?.trim() || undefined;
  const results = q.get("results") === "1";
  const minutes = Math.min(300, Math.max(15, Number(q.get("minutes")) || 60));
  const format = q.get("format") === "json" ? "json" : "ics";

  if (reqType === "table") {
    let loaded: { html: string; games: Game[] }[];
    try {
      loaded = await Promise.all(comps.map(loadComp));
    } catch (e) {
      console.error(e);
      return text(`Could not load standings: ${(e as Error).message}`, 502);
    }
    const rows = comps.flatMap((compId, i) => parseTable(loaded[i].html, compId));
    return new Response(JSON.stringify(rows), {
      headers: { ...common, "Content-Type": "application/json; charset=utf-8" },
    });
  }

  let loaded2: { html: string; games: Game[] }[];
  try {
    loaded2 = await Promise.all(comps.map(loadComp));
  } catch (e) {
    console.error(e);
    return text(`Could not load fixtures: ${(e as Error).message}`, 502);
  }
  let games: Game[] = loaded2.flatMap((r) => r.games);
  games = filterGames(games, { team, results });

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
