// Supabase Edge Function: GAA fixtures -> calendar feed (.ics) or JSON.
//
//   GET /functions/v1/gaa-fixtures?comp=215248&team=Raheny
//   GET /functions/v1/gaa-fixtures?comp=215248,215300&team=Raheny&results=1
//   GET /functions/v1/gaa-fixtures?comp=215248&team=Raheny&format=json
//   GET /functions/v1/gaa-fixtures?comp=215248&type=table
//   GET /functions/v1/gaa-fixtures?type=discover&search=U13
//   GET /functions/v1/gaa-fixtures?type=club&club=3561&format=json&results=1
//   GET /functions/v1/gaa-fixtures?type=club&club=3561&age=U13   (calendar feed)
//   GET /functions/v1/gaa-fixtures?type=store&code=Ladies%20Football&age=U14   (season store, from the DB)
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
// type=store (diagnostic, JSON): the season store's gaa_status() and one club's stored
//   games with when each was last loaded. Anon key only, so nothing the pages can't read.
//   club (gaa_clubs name key, default "clontarf"), from, to
//   results / minutes / name / format as above.
import {
  buildIcs, type ClubGame, compMeta, discoverComps, filterGames, type Game,
  parseAjaxBody, parseClubGames, parseGames, parseTable,
} from "./gaa.ts";
import { AJAX, CODES, fetchClub, SOURCES, UA } from "./source.ts";
import { createClient } from "npm:@supabase/supabase-js@2.43.4";

const BASE = "https://dublingaa.sportlomo.com/league-2";
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

let camogieClubs: { at: number; list: { id: string; name: string }[] } | null = null;
const clubCache = new Map<string, { at: number; games: ClubGame[] }>();

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

  // ── Season store read: every game of one code and age this year, from the DB (no Sportlomo call).
  // ?type=store&code=Ladies%20Football&age=U14[&year=2026]. Public data (anon can read these tables).
  if (type === "store") {
    const code = CODES.find((k) => k.toLowerCase() === (q.get("code") ?? "").trim().toLowerCase());
    const age = (q.get("age") ?? "").trim().toUpperCase();
    const year = Number(q.get("year") ?? new Date().getFullYear());
    if (!code || !/^[A-Z0-9]{1,12}$/.test(age) || !(year >= 2020 && year <= 2100)) return text("code, age (and year) required", 400);
    // Optional from/to (YYYY-MM-DD) and part=meta|games, so a reader with a small page limit can take it in pieces.
    const day = /^\d{4}-\d{2}-\d{2}$/;
    const from = q.get("from") ?? `${year}-01-01`, to = q.get("to") ?? `${year + 1}-01-01`;
    if (!day.test(from) || !day.test(to)) return text("from/to must be YYYY-MM-DD", 400);
    const part = q.get("part") ?? "all";
    // Optional comp=<id,id> and team=<name part> narrow the games; fmt=lines returns one pipe-separated game per line.
    const compFilter = (q.get("comp") ?? "").split(",").map((s) => s.trim()).filter((s) => /^\d+$/.test(s));
    const teamFilter = (q.get("team") ?? "").trim().replace(/[%_,.()]/g, "");
    const fmt = q.get("fmt") ?? "json";
    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
    const { data: allComps, error: ce } = await sb.from("gaa_competitions").select("comp_id, name, grade, age, code").eq("code", code).eq("age", age);
    if (ce) return text(ce.message, 500);
    const comps = (allComps ?? []).filter((c: { comp_id: string }) => !compFilter.length || compFilter.includes(String(c.comp_id)));
    const ids = comps.map((c: { comp_id: string }) => c.comp_id);
    const games: unknown[] = [];
    for (let off = 0; ids.length && part !== "meta"; off += 1000) {
      let qb = sb.from("gaa_games")
        .select("game_id, comp_id, start_at, home_team, away_team, home_club_id, away_club_id, status, home_score, away_score, home_pts, away_pts, venue, note")
        .in("comp_id", ids).gte("start_at", from).lt("start_at", to).order("start_at").range(off, off + 999);
      if (teamFilter) qb = qb.or(`home_team.ilike.%${teamFilter}%,away_team.ilike.%${teamFilter}%`);
      const { data, error } = await qb;
      if (error) return text(error.message, 500);
      games.push(...(data ?? []));
      if ((data ?? []).length < 1000) break;
    }
    if (fmt === "lines") {
      const clean = (v: unknown) => String(v ?? "").replace(/[|\r\n]/g, " ").trim();
      const lines: string[] = [];
      if (part !== "games") for (const c of comps) lines.push(`C|${c.comp_id}|${clean(c.name)}|${clean(c.grade)}`);
      for (const g of games as Record<string, unknown>[]) {
        lines.push(`G|${g.game_id}|${g.comp_id}|${String(g.start_at).slice(0, 16)}|${clean(g.home_team)}|${clean(g.away_team)}|${clean(g.home_score)}|${clean(g.away_score)}|${g.status}|${clean(g.venue)}|${clean(g.note)}`);
      }
      return text(lines.join("\n"), 200);
    }
    const { data: clubs } = part === "games" ? { data: undefined } : await sb.from("gaa_clubs").select("club_id, name");
    return new Response(JSON.stringify(part === "games" ? { games } : { code, age, year, from, to, comps, clubs, games }), {
      headers: { ...common, "Cache-Control": "public, max-age=600", "Content-Type": "application/json; charset=utf-8" },
    });
  }

  // ── Camogie club list (Sportlomo's get_clubs; its IDs are the camogie ones) ──
  // ── Diagnostic: what the season store holds for one club ─────────────────
  // ?type=store&club=clontarf&from=2026-10-19&to=2026-10-31. Uses the anon key, so
  // it reads only what the public pages already can (gaa_status, gaa_games).
  if (type === "store") {
    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!);
    const key = (q.get("club") ?? "clontarf").toLowerCase().replace(/[^a-z0-9]/g, "");
    const from = q.get("from") ?? isoDay(new Date(Date.now() - 7 * 864e5));
    const to = q.get("to") ?? isoDay(new Date(Date.now() + 14 * 864e5));
    const [status, club] = await Promise.all([
      sb.rpc("gaa_status"),
      sb.from("gaa_clubs").select("club_id, name").eq("name_key", key).maybeSingle(),
    ]);
    let games: unknown = [];
    if (club.data) {
      const id = club.data.club_id;
      const r = await sb.from("gaa_games")
        .select("start_at, code, home_team, away_team, status, home_score, away_score, venue, note, synced_at, comp:gaa_competitions(name, age)")
        .or(`home_club_id.eq.${id},away_club_id.eq.${id}`)
        .gte("start_at", `${from}T00:00:00Z`).lte("start_at", `${to}T23:59:59Z`).order("start_at");
      games = r.data ?? r.error;
    }
    return new Response(JSON.stringify({ now: new Date().toISOString(), status: status.data ?? status.error, club: club.data, games }, null, 1), {
      headers: { "Cache-Control": "no-store", "Access-Control-Allow-Origin": "*", "Content-Type": "application/json; charset=utf-8" },
    });
  }

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
