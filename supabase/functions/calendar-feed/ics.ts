// Builds the iCalendar (RFC 5545) text for the calendar-feed function.

export type FeedEvent = {
  event_id: number;
  title: string | null;
  team_name: string | null;
  event_type: string | null;
  local_time: string; // "2026-11-15T10:00:00", Irish wall-clock time
  meet_time: string | null;
  location_name: string | null;
  location_pin: string | null;
  opposition: string | null;
  home_away: string | null;
  event_details: string | null;
  status: string | null;
  squad_name: string | null;
};

// How long an event runs; the app keeps only a start time.
const MINUTES: Record<string, number> = { match: 90, training: 60 };

const TIMEZONE = [
  "BEGIN:VTIMEZONE",
  "TZID:Europe/Dublin",
  "BEGIN:STANDARD",
  "DTSTART:19701025T020000",
  "RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU",
  "TZOFFSETFROM:+0100",
  "TZOFFSETTO:+0000",
  "TZNAME:GMT",
  "END:STANDARD",
  "BEGIN:DAYLIGHT",
  "DTSTART:19700329T010000",
  "RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU",
  "TZOFFSETFROM:+0000",
  "TZOFFSETTO:+0100",
  "TZNAME:IST",
  "END:DAYLIGHT",
  "END:VTIMEZONE",
];

const tidy = (s: unknown) => String(s ?? "").trim();

/** Escapes text values: backslash, semicolon, comma and newlines. */
export function esc(s: string): string {
  return s
    .replace(/\\/g, "\\\\")
    .replace(/;/g, "\\;")
    .replace(/,/g, "\\,")
    .replace(/\r\n|\r|\n/g, "\\n");
}

/** Folds a line at 75 octets, continuation lines start with a space. */
export function fold(line: string): string {
  const enc = new TextEncoder();
  if (enc.encode(line).length <= 75) return line;
  const out: string[] = [];
  let cur = "";
  let len = 0;
  for (const ch of line) {
    const n = enc.encode(ch).length;
    const max = out.length === 0 ? 75 : 74;
    if (len + n > max) {
      out.push(cur);
      cur = "";
      len = 0;
    }
    cur += ch;
    len += n;
  }
  out.push(cur);
  return out.join("\r\n ");
}

/** "2026-11-15T10:00:00" -> "20261115T100000", plus [minutes] added. */
export function localStamp(iso: string, minutes = 0): string {
  const m = iso.match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/);
  if (!m) throw new Error(`bad time ${iso}`);
  // Plain clock arithmetic in UTC so the result is the same wall-clock time.
  const d = new Date(Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5]) + minutes * 60000);
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getUTCFullYear()}${p(d.getUTCMonth() + 1)}${p(d.getUTCDate())}T${p(d.getUTCHours())}${p(d.getUTCMinutes())}00`;
}

/**
 * Minutes before the start that the meet time asks for, or null when it isn't
 * one clear time (Ken, 2026-11-11: entries start at the meet time). The field
 * is typed freely: "18:30", "9.30am", "1245", "30 mins before" work; two times,
 * "TBC" or notes fall back to the start time. Without am/pm the reading at or
 * before the start is used ("6:45" for a 19:10 start is 18:45), and a meet
 * more than four hours early is treated as a typo.
 */
export function meetLead(meet: string | null, startIso: string): number | null {
  const t = tidy(meet).toLowerCase();
  if (!t) return null;
  const before = t.match(/^(\d{1,3})\s*(?:m|min|mins|minutes)\s*(?:before)?$/);
  if (before) {
    const n = +before[1];
    return n > 0 && n <= 240 ? n : null;
  }
  const m = t.match(/^(\d{1,2})(?:\s*[:.]\s*(\d{2}))?\s*(am|pm)?$/) ??
    t.match(/^(\d{1,2})(\d{2})\s*(am|pm)?$/);
  if (!m) return null;
  let h = +m[1];
  const min = m[2] ? +m[2] : 0;
  if (h > 23 || min > 59) return null;
  const s = startIso.match(/T(\d{2}):(\d{2})/);
  if (!s) return null;
  const start = +s[1] * 60 + +s[2];
  const options: number[] = [];
  if (m[3]) {
    if (h > 12 || h === 0) return null;
    options.push(((h % 12) + (m[3] === "pm" ? 12 : 0)) * 60 + min);
  } else {
    options.push(h * 60 + min);
    if (h >= 1 && h < 12) options.push((h + 12) * 60 + min);
  }
  const leads = options.map((o) => start - o).filter((d) => d >= 0 && d <= 240);
  return leads.length ? Math.min(...leads) : null;
}

function utcStamp(d: Date): string {
  return d.toISOString().replace(/[-:]/g, "").replace(/\.\d{3}/, "");
}

export function eventLines(e: FeedEvent, now: Date): string[] {
  const type = tidy(e.event_type);
  const title = tidy(e.title) || type || "Event";
  const team = tidy(e.team_name);
  const cancelled = tidy(e.status).toLowerCase() === "cancelled";
  const summary = `${cancelled ? "Cancelled: " : ""}${title}${team ? ` (${team})` : ""}`;

  const notes: string[] = [];
  const opp = tidy(e.opposition);
  if (opp) {
    const ha = tidy(e.home_away);
    notes.push(`v ${opp}${ha ? ` (${ha})` : ""}`);
  }
  if (tidy(e.squad_name)) notes.push(`Squad: ${tidy(e.squad_name)}`);
  const lead = meetLead(e.meet_time, e.local_time);
  if (tidy(e.meet_time)) notes.push(`Meet: ${tidy(e.meet_time)}`);
  if (lead) notes.push(`Starts: ${e.local_time.slice(11, 16)}`);
  if (tidy(e.event_details)) notes.push("", tidy(e.event_details));
  const pin = tidy(e.location_pin);
  if (/^https?:\/\//i.test(pin)) notes.push("", `Map: ${pin}`);
  notes.push("", "Reply in the CoachSmart app.");

  const lines = [
    "BEGIN:VEVENT",
    `UID:event-${e.event_id}@coachsmart.app`,
    `DTSTAMP:${utcStamp(now)}`,
    `DTSTART;TZID=Europe/Dublin:${localStamp(e.local_time, -(lead ?? 0))}`,
    `DTEND;TZID=Europe/Dublin:${localStamp(e.local_time, MINUTES[type.toLowerCase()] ?? 60)}`,
    `SUMMARY:${esc(summary)}`,
    `DESCRIPTION:${esc(notes.join("\n").replace(/^\n+/, ""))}`,
  ];
  if (tidy(e.location_name)) lines.push(`LOCATION:${esc(tidy(e.location_name))}`);
  lines.push(`STATUS:${cancelled ? "CANCELLED" : "CONFIRMED"}`, "TRANSP:OPAQUE", "END:VEVENT");
  return lines;
}

export function buildCalendar(events: FeedEvent[], now: Date): string {
  const lines = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//CoachSmart//Calendar feed//EN",
    "CALSCALE:GREGORIAN",
    "METHOD:PUBLISH",
    "X-WR-CALNAME:CoachSmart",
    "X-WR-TIMEZONE:Europe/Dublin",
    "REFRESH-INTERVAL;VALUE=DURATION:PT1H",
    "X-PUBLISHED-TTL:PT1H",
    ...TIMEZONE,
  ];
  for (const e of events) {
    try {
      lines.push(...eventLines(e, now));
    } catch (err) {
      console.error("calendar-feed: skipped event", e.event_id, err);
    }
  }
  lines.push("END:VCALENDAR");
  return lines.map(fold).join("\r\n") + "\r\n";
}
