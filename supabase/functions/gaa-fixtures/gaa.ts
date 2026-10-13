// Parsing + .ics generation for dublingaa.sportlomo.com competition pages.
// Pure functions only (no Deno/Supabase APIs) so they are easy to test.
import { load } from "npm:cheerio@1.0.0";

export interface Game {
  kind: "fixture" | "result";
  compId: string;
  comp: string;
  startUtc: Date;
  home: string;
  away: string;
  score: string; // "2 - 10 v 1 - 6" or ""
  venue: string;
  referee: string;
  note: string;
}

const TZ = "Europe/Dublin";
const MONTHS = [
  "January", "February", "March", "April", "May", "June", "July",
  "August", "September", "October", "November", "December",
];
// JS getUTCDay(): 0 = Sunday
const WEEKDAYS = [
  "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
];

/** Offset of Europe/Dublin from UTC, in minutes, at the given instant. */
function dublinOffsetMinutes(at: Date): number {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: TZ, hourCycle: "h23",
    year: "numeric", month: "numeric", day: "numeric",
    hour: "numeric", minute: "numeric", second: "numeric",
  }).formatToParts(at);
  const g = (t: string) => Number(parts.find((p) => p.type === t)!.value);
  const asUtc = Date.UTC(g("year"), g("month") - 1, g("day"), g("hour"), g("minute"), g("second"));
  return Math.round((asUtc - Math.floor(at.getTime() / 1000) * 1000) / 60000);
}

/** Dublin wall-clock time -> real UTC instant (handles BST/GMT). */
export function dublinToUtc(y: number, mo: number, d: number, hh: number, mm: number): Date {
  const guess = Date.UTC(y, mo - 1, d, hh, mm);
  const off1 = dublinOffsetMinutes(new Date(guess));
  let utc = guess - off1 * 60000;
  const off2 = dublinOffsetMinutes(new Date(utc));
  if (off2 !== off1) utc = guess - off2 * 60000; // across a clock change
  return new Date(utc);
}

/**
 * "Saturday October 17th" -> {y, mo, d}. The page has no year, so pick the
 * year (this one, last, or next) in which that date falls on that weekday.
 */
export function resolveDate(text: string, today: Date) {
  const m = text.trim().match(/^(\w+)\s+(\w+)\s+(\d+)/);
  if (!m) throw new Error(`Unrecognised date heading: ${text}`);
  const wd = WEEKDAYS.indexOf(m[1]);
  const mo = MONTHS.indexOf(m[2]) + 1;
  const d = Number(m[3]);
  if (wd < 0 || mo < 1) throw new Error(`Unrecognised date heading: ${text}`);
  const y0 = today.getUTCFullYear();
  for (const y of [y0, y0 - 1, y0 + 1]) {
    const dt = new Date(Date.UTC(y, mo - 1, d));
    if (dt.getUTCMonth() === mo - 1 && dt.getUTCDay() === wd) return { y, mo, d };
  }
  throw new Error(`No matching year for: ${text}`);
}

const clean = (s: string) => s.replace(/\s+/g, " ").trim();

export function parseGames(html: string, compId: string, today = new Date()): Game[] {
  const $ = load(html);
  const out: Game[] = [];

  const sections: [string, "fixture" | "result"][] = [
    ["#fixtures_listing", "fixture"],
    ["#results_listing", "result"],
  ];
  for (const [sel, kind] of sections) {
    const table = $(`${sel} table.sp-table-container`).first();
    if (!table.length) continue;

    let date: { y: number; mo: number; d: number } | null = null;
    let comp = "";

    table.children("thead.divider, tbody").each((_, el) => {
      const node = $(el);
      if (el.tagName === "thead") {
        const dText = clean(node.find(".comp-header .date").first().text());
        if (dText) date = resolveDate(dText, today);
        comp = clean(node.find(".comp-header .comp-name").first().text()) || comp;
        return;
      }
      const row = node.find("tr.desktop").first();
      if (!row.length || !date) return;

      const names = row.find(".team-name a").map((_, a) => clean($(a).text())).get();
      if (names.length !== 2) return;
      const timeTxt = clean(row.find("td.time").first().text());
      const tm = timeTxt.match(/^(\d{1,2}):(\d{2})$/);
      if (!tm) return;
      const scores = row.find("td.score").map((_, s) => clean($(s).text())).get();
      const foot = node.find(".footer-section").first();

      out.push({
        kind,
        compId,
        comp,
        startUtc: dublinToUtc(date.y, date.mo, date.d, Number(tm[1]), Number(tm[2])),
        home: names[0],
        away: names[1],
        score: scores.length === 2 ? `${scores[0]} v ${scores[1]}` : "",
        venue: clean(foot.find(".venue span").first().text()),
        referee: clean(foot.find(".referee span").first().text()),
        note: clean(foot.find(".comment span").first().text()),
      });
    });
  }
  return out;
}

export function filterGames(games: Game[], opts: { team?: string; results: boolean }): Game[] {
  const t = opts.team?.toLowerCase();
  return games
    .filter((g) => opts.results || g.kind === "fixture")
    .filter((g) => g.home.toLowerCase() !== "bye" && g.away.toLowerCase() !== "bye")
    .filter((g) => !t || g.home.toLowerCase().includes(t) || g.away.toLowerCase().includes(t))
    .sort((a, b) => a.startUtc.getTime() - b.startUtc.getTime());
}

// ---------- Club fixtures (dublingaa.sportlomo.com/fixtures-3/) ----------
//
// The club fixtures page POSTs to wp-admin/admin-ajax.php (action=get_fixtures3)
// and gets back {html, totalRecords, isLoadMore}. One call covers every
// competition the club plays in, so nothing has to be listed by hand.

export interface ClubGame extends Game {
  homeClub: string;   // club name (team names can carry a suffix, e.g. "Clontarf C")
  awayClub: string;
  homeClubId: string;
  awayClubId: string;
  code?: string; // the code it was fetched under (Football, Hurling)
}

/** The body is JSON but has raw tabs/newlines inside the html string. */
export function parseAjaxBody(body: string): { html: string; totalRecords: number; isLoadMore: boolean } {
  const j = JSON.parse(body.replace(/[\r\n\t]+/g, " "));
  return {
    html: String(j.html ?? ""),
    totalRecords: Number(j.totalRecords) || 0,
    isLoadMore: j.isLoadMore === true,
  };
}

const logoClubId = (src: string) => src.match(/\/clubLogos\/(\d+)\//)?.[1] ?? "";

export function parseClubGames(html: string, today = new Date()): ClubGame[] {
  const $ = load(html);
  const out: ClubGame[] = [];
  let date: { y: number; mo: number; d: number } | null = null;
  let comp = "";
  let compId = "";

  $("thead.divider, tbody.fixture-row").each((_, el) => {
    const node = $(el);
    if (el.tagName === "thead") {
      const dText = clean(node.find(".comp-header .date").first().text());
      if (dText) date = resolveDate(dText, today);
      const a = node.find(".comp-header .comp-name a").first();
      comp = clean(a.text()) || comp;
      compId = (a.attr("href") ?? "").match(/\/league-2\/(\d+)/)?.[1] ?? compId;
      return;
    }
    const row = node.find("tr.desktop").first();
    if (!row.length || !date) return;

    const names = row.find(".team-name a").map((_, a) => clean($(a).text())).get();
    if (names.length !== 2) return;
    const tm = clean(row.find("td.time").first().text()).match(/^(\d{1,2}):(\d{2})$/);
    const scores = row.find("td.score").map((_, s) => clean($(s).text())).get();
    const played = scores.length === 2 && scores.every((s) => /\d/.test(s));
    const foot = node.find(".footer-section").first();

    out.push({
      kind: played ? "result" : "fixture",
      compId,
      comp: clean(node.attr("data-competition") ?? "") || comp,
      startUtc: dublinToUtc(date.y, date.mo, date.d, tm ? Number(tm[1]) : 0, tm ? Number(tm[2]) : 0),
      home: names[0],
      away: names[1],
      score: played ? `${scores[0]} v ${scores[1]}` : "",
      venue: clean(node.attr("data-venue") ?? "") || clean(foot.find(".venue span").first().text()),
      referee: clean(foot.find(".referee span").first().text()),
      note: [tm ? "" : "Time TBC", clean(foot.find(".comment span").first().text())].filter(Boolean).join(" · "),
      homeClub: clean(node.attr("data-home-club") ?? "") || names[0],
      awayClub: clean(node.attr("data-away-club") ?? "") || names[1],
      homeClubId: logoClubId(row.find("td.align-right img.team-logo").attr("src") ?? ""),
      awayClubId: logoClubId(row.find("td.align-left img.team-logo").attr("src") ?? ""),
    });
  });
  return out;
}

/**
 * "U13 Football League Div.3" -> {age:"U13", code:"Football", grade:"League Div.3"}
 * Camogie and LGFA write "Under 15" / "Under-9" / "U-14", so all map to "U15" style.
 */
export function compMeta(name: string): { age: string; code: string; grade: string } {
  // Dublin's adult leagues are named "AFL ..." / "AHL ..." (Adult Football/Hurling League).
  const afl = name.match(/\bA([FH])L\b/i);
  const ageM = name.match(/\b(?:U|Under)[\s-]?(\d{1,2})\b/i) ??
    name.match(/\b(Minor|Junior|Intermediate|Senior|Adult)\b/i);
  const age = !ageM ? (afl ? "Adult" : "Other") : /^\d+$/.test(ageM[1]) ? `U${Number(ageM[1])}`
    : ageM[1][0].toUpperCase() + ageM[1].slice(1).toLowerCase();
  const codeM = name.match(/\b(Football|Hurling|Camogie)\b/i);
  const code = codeM ? codeM[1][0].toUpperCase() + codeM[1].slice(1).toLowerCase()
    : afl ? (afl[1].toUpperCase() === "F" ? "Football" : "Hurling") : "";
  const grade = clean(name.replace(ageM?.[0] ?? "", "").replace(codeM?.[0] ?? "", ""));
  return { age, code, grade };
}

// ---------- ICS ----------

const esc =(s: string) =>
  s.replace(/\\/g, "\\\\").replace(/;/g, "\\;").replace(/,/g, "\\,").replace(/\n/g, "\\n");

/** RFC 5545 line folding at 75 octets, never splitting a UTF-8 character. */
function fold(line: string): string {
  const enc = new TextEncoder();
  const parts: string[] = [];
  let cur = "";
  let bytes = 0;
  let limit = 75;
  for (const ch of line) {
    const n = enc.encode(ch).length;
    if (bytes + n > limit) {
      parts.push(cur);
      cur = "";
      bytes = 0;
      limit = 74; // continuation lines start with a space
    }
    cur += ch;
    bytes += n;
  }
  parts.push(cur);
  return parts.join("\r\n ");
}

const stamp = (d: Date) => d.toISOString().replace(/[-:]/g, "").replace(/\.\d{3}/, "");

// ---------- Competition discovery ----------

export interface CompEntry { id: string; name: string }

/**
 * Scrape any Dublin GAA Sportlomo page and return every competition
 * linked from it. Links take the form …/league-2/{id}/ or …/league-2/{id}/…
 * Optional search filters by name substring (case-insensitive).
 */
export function discoverComps(html: string, search = ""): CompEntry[] {
  const $ = load(html);
  const seen = new Set<string>();
  const out: CompEntry[] = [];
  const q = search.toLowerCase();
  $('a[href*="/league-2/"]').each((_, el) => {
    const href = $(el).attr("href") ?? "";
    const m = href.match(/\/league-2\/(\d{1,10})/);
    if (!m) return;
    const id = m[1];
    if (seen.has(id)) return;
    const name = clean($(el).text());
    if (!name || name.length < 3) return;
    if (q && !name.toLowerCase().includes(q)) return;
    seen.add(id);
    out.push({ id, name });
  });
  return out;
}

// ---------- League Table ----------

export interface TableRow {
  position: number;
  team: string;
  played: number;
  won: number;
  drawn: number;
  lost: number;
  points: number;
}

export function parseTable(html: string, compId: string): TableRow[] {
  const $ = load(html);
  const out: TableRow[] = [];
  $(`#leagueContent-${compId} table.league_table tbody.low tr`).each((_, tr) => {
    const tds = $(tr).children("td");
    const position = parseInt(tds.eq(0).text().trim(), 10);
    const team = clean(tds.filter(".Team").find("a").first().text());
    const played = parseInt(tds.filter(".Pld").first().text().trim(), 10);
    const won = parseInt(tds.filter(".W").first().text().trim(), 10);
    const drawn = parseInt(tds.filter(".D").first().text().trim(), 10);
    const lost = parseInt(tds.filter(".L").first().text().trim(), 10);
    const points = parseInt(tds.filter(".Pts").first().text().trim(), 10);
    if (team && !isNaN(position)) {
      out.push({ position, team, played, won, drawn, lost, points });
    }
  });
  return out;
}

// ---------- ICS ----------

export function buildIcs(games: Game[], calName: string, minutes: number, now = new Date()): string {
  const lines = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//gaa-fixtures//EN",
    "CALSCALE:GREGORIAN",
    "METHOD:PUBLISH",
    `X-WR-CALNAME:${esc(calName)}`,
    `X-WR-TIMEZONE:${TZ}`,
    "REFRESH-INTERVAL;VALUE=DURATION:PT6H",
    "X-PUBLISHED-TTL:PT6H",
  ];
  for (const g of games) {
    const end = new Date(g.startUtc.getTime() + minutes * 60000);
    const desc = [g.comp];
    if (g.referee) desc.push(`Referee: ${g.referee}`);
    if (g.note) desc.push(`Note: ${g.note}`);
    if (g.score) desc.push(`Result: ${g.score}`);
    // UID is per pairing (not per date) so a rescheduled game updates in place.
    const slug = `${g.home}-${g.away}`.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
    lines.push(
      "BEGIN:VEVENT",
      `UID:${g.compId}-${slug}@gaa-fixtures`,
      `DTSTAMP:${stamp(now)}`,
      `DTSTART:${stamp(g.startUtc)}`,
      `DTEND:${stamp(end)}`,
      `SUMMARY:${esc(`${g.home} v ${g.away}`)}`,
      `LOCATION:${esc(g.venue)}`,
      `DESCRIPTION:${esc(desc.join("\n"))}`,
      "END:VEVENT",
    );
  }
  lines.push("END:VCALENDAR");
  return lines.map(fold).join("\r\n") + "\r\n";
}
