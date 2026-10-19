// Scouting report numbers, built from the season store (public.gaa_games). Pure, so it is easy to test.
//
// A "team" is one Sportlomo side: its club, its name as listed ("Na Fianna B") and the age of
// the competitions it plays in (a club's "B" team at U13 and at U14 are different sides).
// With comp_id set, only that competition's games count. With team "", any side of the club matches
// (used for "us": the report no longer names our side, only our club).

export interface Game {
  game_id: number;
  comp_id: string;
  start_at: string;            // ISO
  home_team: string;
  away_team: string;
  home_club_id: number | null;
  away_club_id: number | null;
  status: string;              // fixture | result
  home_score: string;          // "2-10"
  away_score: string;
  home_pts: number | null;
  away_pts: number | null;
  venue?: string;
  note?: string;
}

export interface Comp { comp_id: string; name: string; code: string; age: string; grade: string }

export interface TeamRef { club_id: number; team: string; age: string; comp_id?: string | null }

export interface GameRow {
  date: string;                // YYYY-MM-DD, Dublin
  opp: string;                 // opponent as listed
  home: boolean;
  us: string;                  // this team's score, "2-10"
  them: string;
  u: number; t: number; m: number;
  res: "W" | "D" | "L";
  comp: string;                // grade, e.g. "League Div 3"
  vsUs: boolean;               // the game against the scouting team
}

export interface Record { p: number; w: number; d: number; l: number }

export interface Report {
  opp: { team: string; age: string; code: string };
  us: { team: string };
  record: Record & { pf: number; pa: number; avgFor: number; avgAgainst: number; goalsFor: number; goalsAgainst: number };
  home: Record;
  away: Record;
  form: ("W" | "D" | "L")[];   // newest first, up to 5
  games: GameRow[];            // oldest first
  common: { opp: string; them: { res: string; m: number }[]; us: { res: string; m: number }[] }[];
  h2h: GameRow[];              // the opposition's games against us, oldest first
  table: { comp: string; rows: { team: string; p: number; w: number; d: number; l: number; diff: number; pts: number; us: boolean; opp: boolean }[] } | null;
  last_result: string | null;  // date of the newest result used
}

export const norm = (s: string | null | undefined) => String(s ?? "").toLowerCase().replace(/[^a-z0-9]/g, "");

export function dublinDay(iso: string): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Dublin", year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date(iso));
}

function goals(score: string): number {
  const m = score.match(/^(\d+)-/);
  return m ? Number(m[1]) : 0;
}

// Abandoned games keep their part-time score in Sportlomo, so they are left out.
const scored = (g: Game) => g.status === "result" && g.home_pts != null && g.away_pts != null && !/abandon/i.test(g.note ?? "");

/** Does this side of the game belong to team t? Same club, same listed name, same age of competition. */
export function isTeam(g: Game, side: "home" | "away", t: TeamRef, comps: Map<string, Comp>): boolean {
  const club = side === "home" ? g.home_club_id : g.away_club_id;
  const name = side === "home" ? g.home_team : g.away_team;
  return club === t.club_id && (!t.team || norm(name) === norm(t.team)) && comps.get(g.comp_id)?.age === t.age && (!t.comp_id || g.comp_id === t.comp_id);
}

/** Key for "the same opponent" across both teams' games: club + listed name + age. */
const sideKey = (g: Game, side: "home" | "away", comps: Map<string, Comp>) =>
  `${side === "home" ? g.home_club_id : g.away_club_id}|${norm(side === "home" ? g.home_team : g.away_team)}|${comps.get(g.comp_id)?.age ?? ""}`;

/** The team's scored games, from its own point of view, oldest first. */
export function teamGames(games: Game[], t: TeamRef, comps: Map<string, Comp>, vsUs?: TeamRef) {
  const out: (GameRow & { oppKey: string })[] = [];
  for (const g of games) {
    if (!scored(g)) continue;
    const side = isTeam(g, "home", t, comps) ? "home" : isTeam(g, "away", t, comps) ? "away" : null;
    if (!side) continue;
    const home = side === "home";
    const u = (home ? g.home_pts : g.away_pts)!, th = (home ? g.away_pts : g.home_pts)!;
    out.push({
      date: dublinDay(g.start_at),
      opp: home ? g.away_team : g.home_team,
      home,
      us: home ? g.home_score : g.away_score,
      them: home ? g.away_score : g.home_score,
      u, t: th, m: u - th,
      res: u > th ? "W" : u === th ? "D" : "L",
      comp: comps.get(g.comp_id)?.grade || comps.get(g.comp_id)?.name || "",
      vsUs: !!vsUs && isTeam(g, home ? "away" : "home", vsUs, comps),
      oppKey: sideKey(g, home ? "away" : "home", comps),
    });
  }
  return out.sort((a, b) => a.date.localeCompare(b.date));
}

const rec = (rows: GameRow[]): Record => ({
  p: rows.length,
  w: rows.filter(r => r.res === "W").length,
  d: rows.filter(r => r.res === "D").length,
  l: rows.filter(r => r.res === "L").length,
});

/** League table for one competition: 2 points a win, 1 a draw. */
export function leagueTable(games: Game[], compId: string, us: TeamRef, opp: TeamRef, comps: Map<string, Comp>) {
  const T = new Map<string, { team: string; p: number; w: number; d: number; l: number; f: number; a: number; us: boolean; opp: boolean }>();
  for (const g of games) {
    if (g.comp_id !== compId || !scored(g)) continue;
    // Knockout games don't count towards a league table.
    if (/final|semi|quarter/i.test(g.note ?? "")) continue;
    for (const side of ["home", "away"] as const) {
      const k = sideKey(g, side, comps);
      if (!T.has(k)) {
        T.set(k, {
          team: side === "home" ? g.home_team : g.away_team, p: 0, w: 0, d: 0, l: 0, f: 0, a: 0,
          us: isTeam(g, side, us, comps), opp: isTeam(g, side, opp, comps),
        });
      }
      const r = T.get(k)!;
      const f = (side === "home" ? g.home_pts : g.away_pts)!, a = (side === "home" ? g.away_pts : g.home_pts)!;
      r.p++; r.f += f; r.a += a;
      if (f > a) r.w++; else if (f === a) r.d++; else r.l++;
    }
  }
  const rows = [...T.values()].map(r => ({ team: r.team, p: r.p, w: r.w, d: r.d, l: r.l, diff: r.f - r.a, pts: r.w * 2 + r.d, us: r.us, opp: r.opp }));
  rows.sort((a, b) => b.pts - a.pts || b.diff - a.diff || a.team.localeCompare(b.team));
  return rows;
}

export function buildReport(games: Game[], compList: Comp[], us: TeamRef, opp: TeamRef, code: string, fixtureCompId?: string | null): Report {
  const comps = new Map(compList.map(c => [c.comp_id, c]));
  const theirs = teamGames(games, opp, comps, us);
  const ours = us.team ? teamGames(games, us, comps) : [];

  const pf = theirs.reduce((s, r) => s + r.u, 0), pa = theirs.reduce((s, r) => s + r.t, 0);
  const n = theirs.length || 1;
  const goalsFor = theirs.reduce((s, r) => s + goals(r.us), 0), goalsAgainst = theirs.reduce((s, r) => s + goals(r.them), 0);

  // Teams both sides have played (not each other), in the order the opposition met them.
  const oursByOpp = new Map<string, typeof ours>();
  for (const r of ours) oursByOpp.set(r.oppKey, [...(oursByOpp.get(r.oppKey) ?? []), r]);
  const common: Report["common"] = [];
  const seen = new Set<string>();
  for (const r of theirs) {
    if (r.vsUs || seen.has(r.oppKey) || !oursByOpp.has(r.oppKey)) continue;
    seen.add(r.oppKey);
    common.push({
      opp: r.opp,
      them: theirs.filter(x => x.oppKey === r.oppKey).map(x => ({ res: x.res, m: x.m })),
      us: oursByOpp.get(r.oppKey)!.map(x => ({ res: x.res, m: x.m })),
    });
  }

  // Table: the competition of the coming fixture when it has a table, otherwise the
  // competition the opposition has played most in this season.
  let table: Report["table"] = null;
  const counts = new Map<string, number>();
  for (const g of games) {
    if (scored(g) && (isTeam(g, "home", opp, comps) || isTeam(g, "away", opp, comps))) counts.set(g.comp_id, (counts.get(g.comp_id) ?? 0) + 1);
  }
  const tryComps = [fixtureCompId, ...[...counts.entries()].sort((a, b) => b[1] - a[1]).map(e => e[0])].filter(Boolean) as string[];
  for (const id of tryComps) {
    const rows = leagueTable(games, id, us, opp, comps);
    if (rows.length >= 3 && rows.some(r => r.opp)) {
      const c = comps.get(id);
      table = { comp: c ? (c.grade || c.name) : "", rows };
      break;
    }
  }

  const strip = ({ oppKey: _k, ...r }: GameRow & { oppKey: string }) => r;
  return {
    opp: { team: opp.team, age: opp.age, code },
    us: { team: us.team },
    record: {
      ...rec(theirs), pf, pa,
      avgFor: Math.round((pf / n) * 10) / 10, avgAgainst: Math.round((pa / n) * 10) / 10,
      goalsFor, goalsAgainst,
    },
    home: rec(theirs.filter(r => r.home)),
    away: rec(theirs.filter(r => !r.home)),
    form: theirs.slice(-5).reverse().map(r => r.res),
    games: theirs.map(strip),
    common,
    h2h: theirs.filter(r => r.vsUs).map(strip),
    table,
    last_result: theirs.length ? theirs[theirs.length - 1].date : null,
  };
}
