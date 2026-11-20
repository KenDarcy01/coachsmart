// Checks the Féile diary sheet tabs and turns the Live rows into what the
// diary page draws. Rows marked Suggested or Off are skipped without checks;
// Coach notes never leave this file.

export type Cells = string[][];
export const tidy = (s: unknown) => String(s ?? "").replace(/\s+/g, " ").trim();
const lines = (s: unknown) => String(s ?? "").split(/\r?\n/).map(tidy).filter(Boolean);

export const HEADINGS: Record<string, string[]> = {
  Events: ["Status", "Date", "Start", "End", "Type", "Title", "Where", "Details", "Who", "Link", "Coach notes"],
  Activities: ["Status", "From", "To", "Days", "Time", "Type", "Where it shows", "Title", "Minutes", "Subtitle", "Steps", "Video link", "Replaces plan", "Coach notes"],
  Notes: ["Status", "Date", "Applies to", "Message", "Eating well tip", "Coach notes"],
};
const EVENT_TYPES = ["Meetup", "Social", "Fundraiser", "Club event", "Gear", "Notice"];
const ACT_TYPES = ["Home session", "Run", "Skills", "Challenge", "Diet", "Rest"];
const SQUADS = ["All", "Blue", "Red", "Green"];
const DOW = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"];

const isDay = (s: string) => /^\d{4}-\d{2}-\d{2}$/.test(s) && !isNaN(Date.parse(s));
const time = (s: string) => {
  const m = s.match(/^(\d{1,2})[:.](\d{2})/);
  if (!m || +m[1] > 23 || +m[2] > 59) return null;
  return m[1].padStart(2, "0") + ":" + m[2];
};
const url = (s: string) => /^https:\/\/\S+$/i.test(s) ? s : null;
const pick = (v: string, list: string[]) => list.find((x) => x.toLowerCase() === v.toLowerCase()) ?? null;

export function sameSecret(a: string, b: string) {
  if (!a || !b || a.length !== b.length) return false;
  let x = 0;
  for (let i = 0; i < a.length; i++) x |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return x === 0;
}

// Rows under the heading row (the row whose first cell is "Status"), as
// { heading: value } with the sheet row number for error messages.
function rowsOf(tab: string, cells: Cells | undefined, errors: string[]) {
  if (!cells) return [];
  const h = cells.findIndex((r) => tidy(r[0]).toLowerCase() === "status");
  if (h < 0) { errors.push(`${tab}: can't find the heading row (first column should be "Status").`); return []; }
  const head = cells[h].map(tidy);
  const missing = HEADINGS[tab].filter((x) => x !== "Coach notes" && !head.includes(x));
  if (missing.length) { errors.push(`${tab}: missing column ${missing.join(", ")}.`); return []; }
  return cells.slice(h + 1).map((r, i) => {
    const o: Record<string, string> = {};
    head.forEach((k, j) => { if (k) o[k] = String(r[j] ?? ""); });
    return { n: h + i + 2, o };
  }).filter(({ o }) => tidy(o.Status).toLowerCase() === "live");
}

function days(s: string): number[] | null | "bad" {
  const v = tidy(s).toLowerCase();
  if (!v || v === "every day" || v === "everyday" || v === "all") return null;
  const out = new Set<number>();
  for (const t of v.split(/[,\s/&]+/).filter(Boolean)) {
    if (t === "weekdays") [1, 2, 3, 4, 5].forEach((d) => out.add(d));
    else if (t === "weekends" || t === "weekend") [6, 7].forEach((d) => out.add(d));
    else if (t === "and") continue;
    else { const i = DOW.indexOf(t.slice(0, 3)); if (i < 0) return "bad"; out.add(i + 1); }
  }
  return [...out].sort();
}

export function build(tabs: Record<string, Cells | undefined>) {
  const errors: string[] = [], warnings: string[] = [];
  const err = (tab: string, n: number, msg: string) => errors.push(`${tab} row ${n}: ${msg}`);

  const events = rowsOf("Events", tabs.Events, errors).flatMap(({ n, o }) => {
    const date = tidy(o.Date), title = tidy(o.Title);
    if (!isDay(date)) { err("Events", n, "Date is missing or not a date."); return []; }
    if (!title) { err("Events", n, "Title is empty."); return []; }
    const start = tidy(o.Start) ? time(tidy(o.Start)) : null, end = tidy(o.End) ? time(tidy(o.End)) : null;
    if (tidy(o.Start) && !start) err("Events", n, "Start isn't a time like 18:30.");
    if (tidy(o.End) && !end) err("Events", n, "End isn't a time like 20:00.");
    const type = pick(tidy(o.Type), EVENT_TYPES) ?? "Meetup";
    const who = pick(tidy(o.Who) || "All", SQUADS);
    if (!who) err("Events", n, "Who should be All, Blue, Red or Green.");
    if (tidy(o.Link) && !url(tidy(o.Link))) warnings.push(`Events row ${n}: the link doesn't start with https:// so it's left out.`);
    return [{ date, start, end, type, title, where: tidy(o.Where) || null, details: tidy(o.Details) || null, who: who ?? "All", link: url(tidy(o.Link)) }];
  });

  const activities = rowsOf("Activities", tabs.Activities, errors).flatMap(({ n, o }) => {
    const from = tidy(o.From), to = tidy(o.To) || from, title = tidy(o.Title);
    if (!isDay(from)) { err("Activities", n, "From is missing or not a date."); return []; }
    if (!isDay(to)) { err("Activities", n, "To isn't a date."); return []; }
    if (to < from) { err("Activities", n, "To is before From."); return []; }
    if (!title) { err("Activities", n, "Title is empty."); return []; }
    const d = days(o.Days);
    if (d === "bad") { err("Activities", n, `Days "${tidy(o.Days)}" should be Every day, Weekdays, Weekends or day names like Mon, Wed.`); return []; }
    const t = tidy(o.Time) ? time(tidy(o.Time)) : null;
    if (tidy(o.Time) && !t) err("Activities", n, "Time isn't a time like 18:30.");
    const mins = tidy(o.Minutes) ? Math.round(Number(tidy(o.Minutes))) : null;
    if (mins !== null && !(mins > 0 && mins < 600)) err("Activities", n, "Minutes should be a number.");
    const steps = lines(o.Steps).map((l) => { const [a, ...b] = l.split("|"); return { n: tidy(a), d: tidy(b.join("|")) }; }).filter((s) => s.n);
    if (tidy(o["Video link"]) && !url(tidy(o["Video link"]))) warnings.push(`Activities row ${n}: the video link doesn't start with https:// so it's left out.`);
    return [{
      from, to, days: d, time: t, type: pick(tidy(o.Type), ACT_TYPES) ?? "Home session",
      place: /every/i.test(o["Where it shows"] ?? "") ? "everyday" : "timeline",
      title, mins, sub: tidy(o.Subtitle) || null, steps, video: url(tidy(o["Video link"])),
      replaces: /^y/i.test(tidy(o["Replaces plan"])),
    }];
  });

  const notes = rowsOf("Notes", tabs.Notes, errors).flatMap(({ n, o }) => {
    const date = tidy(o.Date), message = tidy(o.Message), tip = tidy(o["Eating well tip"]);
    if (!isDay(date)) { err("Notes", n, "Date is missing or not a date."); return []; }
    if (!message && !tip) { err("Notes", n, "Message and Eating well tip are both empty."); return []; }
    return [{ date, scope: /^w/i.test(tidy(o["Applies to"])) ? "week" : "day", message: message || null, tip: tip || null }];
  });

  const summary = `${events.length} event${events.length === 1 ? "" : "s"}, ${activities.length} activit${activities.length === 1 ? "y" : "ies"}, ${notes.length} note${notes.length === 1 ? "" : "s"} live.`;
  return { errors, warnings, data: { events, activities, notes }, summary };
}
