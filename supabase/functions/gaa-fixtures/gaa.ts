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

// ---------- ICS ----------

const esc = (s: string) =>
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
