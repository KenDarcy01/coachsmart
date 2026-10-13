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
//   club     Sportlomo club ID, or "all" for every club (up to 16 days) (the number in …/clubLogos/<ID>/…;
//            Clontarf is 3561). Every game also reports homeClubId/awayClubId.
//   clubName optional. Club name, passed through as Sportlomo's page does.
//   from,to  optional. YYYY-MM-DD, default 7 days ago to 35 days ahead, max 120 days.
//   code     optional. Comma list of codes in SOURCES (default all).
//   camogieClub, lgfaClub optional. The club's ID on the camogie / ladies football
//            organisations (Clontarf: 40597 / 5346). Each is fetched only when given.
//   age      optional. Keep only competitions for this age, e.g. "U13".
//
// type=probe (diagnostic, plain text): club, from, to, codes=<extra code_ids>
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
// How each code is selected on Sportlomo's club fixtures page. code_name alone
// doesn't switch code (code_id does). For football and hurling, user_id is the
// level: 3 = Adult & Minor, 7167 = CCC1 (U8-U12), 7130 = CCC2 (U13-U16); club IDs
// and code_ids are the same at every level. Camogie (7282) and LGFA (7046) are
// separate organisations with their own club IDs and no code_id.
const GAA_LEVELS = ["3", "7167", "7130"];
const SOURCES: Record<string, { userIds: string[]; codeId?: string; codeName: string; clubParam?: string }> = {
  Football: { userIds: GAA_LEVELS, codeId: "26", codeName: "Football" },
  Hurling: { userIds: GAA_LEVELS, codeId: "27", codeName: "Hurling" },
  Camogie: { userIds: ["7282"], codeName: "", clubParam: "camogieClub" },
  "Ladies Football": { userIds: ["7046"], codeName: "", clubParam: "lgfaClub" },
};
const CODES = Object.keys(SOURCES);
let camogieClubs: { at: number; list: { id: string; name: string }[] } | null = null;
const clubCache = new Map<string, { at: number; games: ClubGame[] }>();

/** Same request the club fixtures page (dublingaa.sportlomo.com/fixtures-3/) makes. */
// Requests already on their way to Sportlomo, so simultaneous visitors share one
const inflight = new Map<string, Promise<ClubGame[]>>();

/** club "" = every club (Sportlomo's "Select Club"). */
function loadClub(club: string, clubName: string, from: string, to: string, code: string): Promise<ClubGame[]> {
  return Promise.all(SOURCES[code].userIds.map((level) => loadLevel(club, clubName, from, to, code, level)))
    .then((parts) => parts.flat());
}

function loadLevel(club: string, clubName: string, from: string, to: string, code: string, level: string): Promise<ClubGame[]> {
  const key = [club, from, to, code, level].join("|");
  const hit = clubCache.get(key);
  if (hit && Date.now() - hit.at < CACHE_MS) return Promise.resolve(hit.games);
  if (!inflight.has(key)) {
    inflight.set(key, fetchClub(club, clubName, from, to, code, level)
      .then((games) => { clubCache.set(key, { at: Date.now(), games }); return games; })
      .finally(() => inflight.delete(key)));
  }
  return inflight.get(key)!;
}

async function fetchClub(
  club: string, clubName: string, from: string, to: string, code: string, level: string,
): Promise<ClubGame[]> {
  const games: ClubGame[] = [];
  const seen = new Set<string>();
  const maxPages = club ? 10 : 80;
  for (let page = 1; page <= maxPages; page++) {
    const src = SOURCES[code];
    const form = new URLSearchParams({
      action: "get_fixtures3", fdate: from, tdate: to, user_id: level,
      ...(src.codeId ? { code_id: src.codeId } : {}),
      age_id: "", spage_id: String(page), is_all: "0", sort: "", code_name: src.codeName, debug: "",
      is_fixture: "1", club_search_id: club, club_search_val: club ? clubName : "Select Club", comp_search_id: "",
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
    if (!res.ok) throw new Error(`Source site returned ${res.status} for ${club ? `club ${club}` : "all clubs"}`);
    const body = parseAjaxBody(await res.text());
    for (const g of parseClubGames(body.html)) {
      const id = [g.compId, g.home, g.away, g.startUtc.getTime()].join("|");
      if (!seen.has(id)) { seen.add(id); games.push({ ...g, code }); }
    }
    if (!body.isLoadMore) break;
  }
  return games;
}

const ALL_CLUBS_MAX_DAYS = 15;

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

  // ── Diagnostic: what Sportlomo returns for one club, per code ─────────────
  // ?type=probe&club=3561&from=2026-05-01&to=2026-06-30 -> plain-text report of
  // raw competition names and counts (before our parser), parsed counts, and the
  // code/age options on Sportlomo's own fixtures page. Read-only.
  if (type === "probe") {
    const club = q.get("club") ?? "3561";
    const from = q.get("from") ?? isoDay(new Date(Date.now() - 60 * 864e5));
    const to = q.get("to") ?? isoDay(new Date());
    if (!/^\d{1,8}$/.test(club) || !/^\d{4}-\d{2}-\d{2}$/.test(from) || !/^\d{4}-\d{2}-\d{2}$/.test(to)) {
      return text("club must be numeric, from/to YYYY-MM-DD", 400);
    }
    const lines: string[] = [`Probe club ${club}, ${from} to ${to}`];
    // names=Clontarf|St Brigid  -> report the club IDs seen for these names
    const watch = new RegExp((q.get("names") ?? "clontarf|clanna gael").replace(/[^\w |']/g, "").slice(0, 80) || "clontarf", "i");
    try {
      const page = await fetch("https://dublingaa.sportlomo.com/fixtures-3/", {
        headers: { "User-Agent": UA, "Accept": "text/html" }, signal: AbortSignal.timeout(15_000),
      }).then((r) => r.text());
      for (const m of page.matchAll(/<select[^>]*(?:id|name)="([^"]+)"[^>]*>([\s\S]*?)<\/select>/g)) {
        if (/club/i.test(m[1])) continue;   // club list is huge
        const opts = [...m[2].matchAll(/<option[^>]*value="([^"]*)"[^>]*>([^<]*)/g)].map((o) => `${o[1]}=${o[2].trim()}`);
        lines.push(`select ${m[1]}: ${opts.slice(0, 40).join(" | ")}`);
      }
    } catch (e) { lines.push(`fixtures-3 page: ${(e as Error).message}`); }
    // Sportlomo's club dropdown is filled by action=get_clubs; try it per organisation
    for (const [label, extra] of (q.get("clubs") ?? "").split(",").filter((x) => /^[\d_]{1,8}$/.test(x)).map((sp) =>
      [`get_clubs sport ${sp}`, { countyId: "126", sport: sp }] as [string, Record<string, string>])) {
      try {
        const res = await fetch(AJAX, {
          method: "POST", body: new URLSearchParams({ action: "get_clubs", ...extra }), signal: AbortSignal.timeout(15_000),
          headers: { "User-Agent": UA, "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
            "X-Requested-With": "XMLHttpRequest", "Referer": "https://dublingaa.sportlomo.com/fixtures-3/" },
        });
        const body = await res.text();
        const hits = [...body.replace(/\\/g, "").matchAll(/value="(\d+)">([^<]*)/g)].filter((m) => watch.test(m[2])).map((m) => `${m[1]}=${m[2]}`);
        lines.push("", `${label} (${JSON.stringify(extra)}): HTTP ${res.status}, ${body.length} chars`,
          `  options: ${(body.match(/option value/g) ?? []).length}`, ...hits.slice(0, 100).map((h) => `  match: ${h.replace(/\s+/g, " ")}`));
      } catch (e) { lines.push(`${label}: error ${(e as Error).message}`); }
    }
    // v=level:code[:club] list, e.g. v=3:26,3:6929,7167:26 (club defaults to ?club, "all" = every club)
    const variants: [string, Record<string, string>][] = (q.get("v") ?? "7130:26,7130:27").split(",").slice(0, 12)
      .map((x) => x.split(":"))
      .filter(([lvl, code, c]) => /^\d{1,6}$/.test(lvl) && /^\d{0,6}$/.test(code ?? "") && /^(\d{0,8}|all)$/.test(c ?? ""))
      .map(([lvl, code, c]) => [`level ${lvl} code ${code || "-"} club ${c || club}`, {
        user_id: lvl, ...(code ? { code_id: code } : {}), code_name: "",
        ...(c === "all" ? { club_search_id: "", club_search_val: "Select Club" } : c ? { club_search_id: c } : {}),
      }]);
    for (const [label, v] of variants) {
      const raw = new Map<string, number>();
      let parsed = 0, total = "?", pages = 0;
      const ids = new Set<string>();
      try {
        for (let p = 1; p <= 10; p++) {
          const form = new URLSearchParams({
            action: "get_fixtures3", fdate: from, tdate: to, age_id: "", spage_id: String(p), is_all: "0", sort: "",
            debug: "", is_fixture: "1", club_search_id: club, club_search_val: "Clontarf", comp_search_id: "", ...v,
          });
          const res = await fetch(AJAX, {
            method: "POST", body: form, signal: AbortSignal.timeout(20_000),
            headers: { "User-Agent": UA, "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
              "X-Requested-With": "XMLHttpRequest", "Referer": "https://dublingaa.sportlomo.com/fixtures-3/" },
          });
          const body = parseAjaxBody(await res.text());
          pages = p; total = String(body.totalRecords ?? "?");
          for (const m of String(body.html).matchAll(/data-competition="([^"]*)"/g)) raw.set(m[1], (raw.get(m[1]) ?? 0) + 1);
          const pg = parseClubGames(body.html);
          parsed += pg.length;
          for (const g of pg) for (const [n, id] of [[g.homeClub, g.homeClubId], [g.awayClub, g.awayClubId]]) {
            if (watch.test(n ?? "") && id) ids.add(`${n}=${id}`);
          }
          if (v.club_search_id === "" && p >= 2) break;
          if (!body.isLoadMore) break;
        }
      } catch (e) { lines.push(`${label}: error ${(e as Error).message}`); continue; }
      const rawCount = [...raw.values()].reduce((a, b) => a + b, 0);
      lines.push("", `${label}: totalRecords ${total}, pages ${pages}, raw rows ${rawCount}, parsed ${parsed}`,
        `  club ids seen: ${[...ids].join(", ") || "none"}`);
      for (const [name, n] of [...raw].sort((a, b) => a[0].localeCompare(b[0]))) lines.push(`  ${n}  ${name}  [${compMeta(name).age}]`);
    }
    return text(lines.join("\n"), 200);
  }

  // ── Camogie club list (Sportlomo's get_clubs; its IDs are the camogie ones) ──
  if (type === "clubs") {
    try {
      if (!camogieClubs || Date.now() - camogieClubs.at > 24 * 3600e3) {
        const res = await fetch(AJAX, {
          method: "POST", body: new URLSearchParams({ action: "get_clubs", countyId: "126", sport: "2" }),
          signal: AbortSignal.timeout(15_000),
          headers: { "User-Agent": UA, "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
            "X-Requested-With": "XMLHttpRequest", "Referer": "https://dublingaa.sportlomo.com/fixtures-3/" },
        });
        if (!res.ok) throw new Error(`Source site returned ${res.status}`);
        const html = String(parseAjaxBody(await res.text()).html ?? "");
        const list = [...html.matchAll(/<option value="(\d+)"[^>]*>([^<]+)</g)]
          .map((m) => ({ id: m[1], name: m[2].replace(/&amp;/g, "&").replace(/&#0?39;/g, "'").trim() }));
        camogieClubs = { at: Date.now(), list };
      }
      return new Response(JSON.stringify({ camogie: camogieClubs.list }), {
        headers: { ...common, "Cache-Control": "public, max-age=86400", "Content-Type": "application/json; charset=utf-8" },
      });
    } catch (e) {
      return text(`Could not load clubs: ${(e as Error).message}`, 502);
    }
  }

  if (type === "club") {
    // club=all fetches every club's games (short ranges only); otherwise club is
    // the GAA club ID and may be empty when only camogieClub/lgfaClub are known.
    const all = q.get("club") === "all";
    const club = all ? "" : q.get("club") ?? "";
    if (!/^\d{0,8}$/.test(club)) return text("club must be a numeric Sportlomo club ID or all", 400);
    const clubName = (q.get("clubName") ?? "").trim().slice(0, 60);
    const day = /^\d{4}-\d{2}-\d{2}$/;
    const now = Date.now();
    const from = q.get("from") ?? isoDay(new Date(now - 7 * 864e5));
    const to = q.get("to") ?? isoDay(new Date(now + 35 * 864e5));
    if (!day.test(from) || !day.test(to)) return text("from/to must be YYYY-MM-DD", 400);
    const span = (Date.parse(to) - Date.parse(from)) / 864e5;
    if (!(span >= 0 && span <= 120)) return text("from must be before to, at most 120 days apart", 400);
    if (all && span > ALL_CLUBS_MAX_DAYS) {
      return text(`All clubs works for up to ${ALL_CLUBS_MAX_DAYS + 1} days; pick a club or shorter dates`, 400);
    }
    const clubFor = (code: string) => {
      const p = SOURCES[code].clubParam;
      return p ? (q.get(p) ?? "") : club;
    };
    for (const p of ["camogieClub", "lgfaClub"]) {
      if (!/^\d{0,8}$/.test(q.get(p) ?? "")) return text(`${p} must be numeric`, 400);
    }
    const codes = (q.get("code") ?? CODES.join(",")).split(",")
      .map((c) => CODES.find((k) => k.toLowerCase() === c.trim().toLowerCase()))
      .filter((c): c is string => !!c);
    if (!codes.length) return text(`code must be one of ${CODES.join(", ")}`, 400);
    const age = (q.get("age") ?? "").trim().toUpperCase();

    let games: ClubGame[];
    try {
      const jobs = codes
        .filter((c) => all || clubFor(c))
        .map((c) => loadClub(all ? "" : clubFor(c), clubName, from, to, c));
      games = (await Promise.all(jobs)).flat();
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
          homeClub: (g as ClubGame).homeClub || null,
          awayClub: (g as ClubGame).awayClub || null,
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
