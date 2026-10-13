// Supabase Edge Function: GAA fixtures -> calendar feed (.ics) or JSON.
//
//   GET /functions/v1/gaa-fixtures?comp=215248&team=Raheny
//   GET /functions/v1/gaa-fixtures?comp=215248,215300&team=Raheny&results=1
//   GET /functions/v1/gaa-fixtures?comp=215248&team=Raheny&format=json
//   GET /functions/v1/gaa-fixtures?comp=215248&type=table
//   GET /functions/v1/gaa-fixtures?type=discover&search=U13
//   GET /functions/v1/gaa-fixtures?type=club&club=3561&format=json&results=1
//   GET /functions/v1/gaa-fixtures?type=club&club=3561&age=U13   (calendar feed)
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
//
// type=club (every competition one club plays in, no comp IDs needed)
//   club     required. Sportlomo club ID (the number in …/clubLogos/<ID>/…;
//            Clontarf is 3561). Every game also reports homeClubId/awayClubId.
//   clubName optional. Club name, passed through as Sportlomo's page does.
//   from,to  optional. YYYY-MM-DD, default 7 days ago to 35 days ahead, max 120 days.
//   code     optional. Comma list of codes in CODE_IDS (Football, Hurling; default both).
//   age      optional. Keep only competitions for this age, e.g. "U13".
//   results / minutes / name / format as above.
import {
  buildIcs, type ClubGame, compMeta, discoverComps, filterGames, type Game,
  parseAjaxBody, parseClubGames, parseGames, parseTable,
} from "./gaa.ts";

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

const AJAX = "https://dublingaa.sportlomo.com/wp-admin/admin-ajax.php";
// code_name -> code_id on Sportlomo's club fixtures page. code_name alone
// doesn't switch code, so a code needs its ID here before it can be fetched.
const CODE_IDS: Record<string, string> = { Football: "26", Hurling: "27" };
const CODES = Object.keys(CODE_IDS);
const clubCache = new Map<string, { at: number; games: ClubGame[] }>();

/** Same request the club fixtures page (dublingaa.sportlomo.com/fixtures-3/) makes. */
async function loadClub(club: string, clubName: string, from: string, to: string, code: string): Promise<ClubGame[]> {
  const key = [club, from, to, code].join("|");
  const hit = clubCache.get(key);
  if (hit && Date.now() - hit.at < CACHE_MS) return hit.games;

  const games: ClubGame[] = [];
  const seen = new Set<string>();
  for (let page = 1; page <= 10; page++) {
    const form = new URLSearchParams({
      action: "get_fixtures3", fdate: from, tdate: to, user_id: "7130", code_id: CODE_IDS[code],
      age_id: "", spage_id: String(page), is_all: "0", sort: "", code_name: code, debug: "",
      is_fixture: "1", club_search_id: club, club_search_val: clubName, comp_search_id: "",
    });
    const res = await fetch(AJAX, {
      method: "POST",
      headers: {
        "User-Agent": UA,
        "Accept": "application/json, text/javascript, */*; q=0.01",
        "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
        "X-Requested-With": "XMLHttpRequest",
        "Referer": "https://dublingaa.sportlomo.com/fixtures-3/",
      },
      body: form,
      signal: AbortSignal.timeout(20_000),
    });
    if (!res.ok) throw new Error(`Source site returned ${res.status} for club ${club}`);
    const body = parseAjaxBody(await res.text());
    for (const g of parseClubGames(body.html)) {
      const id = [g.compId, g.home, g.away, g.startUtc.getTime()].join("|");
      if (!seen.has(id)) { seen.add(id); games.push({ ...g, code }); }
    }
    if (!body.isLoadMore) break;
  }
  clubCache.set(key, { at: Date.now(), games });
  return games;
}

const isoDay = (d: Date) => d.toISOString().slice(0, 10);

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

  if (type === "club") {
    const club = q.get("club") ?? "";
    if (!/^\d{1,8}$/.test(club)) return text("club must be a numeric Sportlomo club ID", 400);
    const clubName = (q.get("clubName") ?? "").trim().slice(0, 60);
    const day = /^\d{4}-\d{2}-\d{2}$/;
    const now = Date.now();
    const from = q.get("from") ?? isoDay(new Date(now - 7 * 864e5));
    const to = q.get("to") ?? isoDay(new Date(now + 35 * 864e5));
    if (!day.test(from) || !day.test(to)) return text("from/to must be YYYY-MM-DD", 400);
    const span = (Date.parse(to) - Date.parse(from)) / 864e5;
    if (!(span >= 0 && span <= 120)) return text("from must be before to, at most 120 days apart", 400);
    const codes = (q.get("code") ?? CODES.join(",")).split(",")
      .map((c) => CODES.find((k) => k.toLowerCase() === c.trim().toLowerCase()))
      .filter((c): c is string => !!c);
    if (!codes.length) return text(`code must be one of ${CODES.join(", ")}`, 400);
    const age = (q.get("age") ?? "").trim().toUpperCase();

    let games: ClubGame[];
    try {
      games = (await Promise.all(codes.map((c) => loadClub(club, clubName, from, to, c)))).flat();
    } catch (e) {
      console.error(e);
      return text(`Could not load club fixtures: ${(e as Error).message}`, 502);
    }
    const results = q.get("results") === "1";
    games = filterGames(games, { results }) as ClubGame[];
    if (age) games = games.filter((g) => compMeta(g.comp).age.toUpperCase() === age);
    return output(games, q, common, clubName || "Club");
  }

  const comps = (q.get("comp") ?? "").split(",").map((s) => s.trim()).filter(Boolean);
  if (!comps.length) return text("Missing ?comp=<competition id>", 400);
  // Digits only: the ID goes into a URL on a fixed host, nothing else.
  if (!comps.every((c) => /^\d{1,10}$/.test(c))) return text("comp must be numeric IDs", 400);

  const reqType = type === "table" ? "table" : "fixtures";
  const team = q.get("team")?.trim() || undefined;
  const results = q.get("results") === "1";

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

  return output(games, q, common, team ?? "GAA");
});

function output(games: Game[], q: URLSearchParams, common: Record<string, string>, label: string): Response {
  const minutes = Math.min(300, Math.max(15, Number(q.get("minutes")) || 60));
  if (q.get("format") === "json") {
    return new Response(
      JSON.stringify(
        games.map((g) => ({
          kind: g.kind,
          competition: g.comp,
          competitionId: g.compId,
          ...compMeta(g.comp),
          ...((g as ClubGame).code ? { code: (g as ClubGame).code } : {}),
          start: g.startUtc.toISOString(),
          home: g.home,
          away: g.away,
          homeClubId: (g as ClubGame).homeClubId || null,
          awayClubId: (g as ClubGame).awayClubId || null,
          score: g.score || null,
          venue: g.venue || null,
          referee: g.referee || null,
          note: g.note || null,
        })),
      ),
      { headers: { ...common, "Content-Type": "application/json; charset=utf-8" } },
    );
  }

  const calName = q.get("name")?.trim() || `${label} fixtures`;
  return new Response(buildIcs(games, calName, minutes), {
    headers: {
      ...common,
      "Content-Type": "text/calendar; charset=utf-8",
      "Content-Disposition": 'inline; filename="fixtures.ics"',
    },
  });
}
