// Turns the coaches' sheet tabs into the diary plan. No imports, so it can be
// tested outside Deno: node --experimental-strip-types.
type Row = { n: number; get: (col: string) => string };
export const tidy = (s: unknown) => String(s ?? "").replace(/\s+/g, " ").trim();
const isDay = (s: string) => /^\d{4}-\d{2}-\d{2}$/.test(s) && !isNaN(Date.parse(s + "T00:00:00Z"));
const isEmail = (s: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s);
const slug = (s: string) => s.toLowerCase().replace(/[^a-z0-9]+/g, "");
const addDay = (d: string, n: number) => new Date(Date.parse(d + "T00:00:00Z") + n * 864e5).toISOString().slice(0, 10);
const KINDS = ["gym", "speed", "run", "rest"];
const REST = ["rest", "off"];

export function sameSecret(a: string, b: string) {
  if (!a || !b || a.length !== b.length) return false;
  let x = 0;
  for (let i = 0; i < a.length; i++) x |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return x === 0;
}

// Rows of a tab as objects keyed by heading (case and spacing ignored).
// The heading row is the first row (of the top 10) holding `key`. In the
// styled sheet that is row 4 (title, subtitle, blank above it) and the row
// under it is a grey hint row, which is skipped. Blank rows are skipped.
// Row numbers match the sheet.
function rowsOf(cells: unknown, key = ""): Row[] {
  if (!Array.isArray(cells) || !cells.length) return [];
  // Line breaks inside a cell are kept (Steps uses one line per step).
  const cell = (c: unknown) => String(c ?? "").replace(/[^\S\n]+/g, " ").replace(/ *\n */g, "\n").replace(/\n+/g, "\n").trim();
  const all = cells.map((r) => (Array.isArray(r) ? r : []).map(cell));
  let h = key ? all.slice(0, 10).findIndex((r) => r.some((c) => slug(c) === slug(key))) : 0;
  if (h < 0) h = 0;
  const head = all[h].map(slug);
  const first = h > 0 ? h + 2 : h + 1; // styled tabs: skip the hint row
  const out: Row[] = [];
  all.slice(first).forEach((vals, i) => {
    if (!vals.some(Boolean)) return;
    out.push({ n: first + i + 1, get: (col) => vals[head.indexOf(slug(col))] ?? "" });
  });
  return out;
}
const hasCol = (cells: unknown, col: string) =>
  Array.isArray(cells) && cells.slice(0, 10).some((r) => Array.isArray(r) && r.some((c) => slug(tidy(c)) === slug(col)));

// Status column: only Live rows reach players. (Yes also counts, for old sheets.)
const live = (r: Row) => ["live", "yes"].includes(r.get("Status").toLowerCase() || r.get("Show").toLowerCase());
const isTime = (s: string) => /^([01]?\d|2[0-3]):[0-5]\d$/.test(s);
const DAYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"];
const dowOf = (d: string) => (new Date(Date.parse(d + "T00:00:00Z")).getUTCDay() + 6) % 7; // 0 = Mon
// "Every day", blank, "Weekdays", "Weekends", or a list like "Mon, Wed, Fri".
function daySet(s: string): Set<number> | null {
  const t = s.toLowerCase();
  if (!t || /every|daily|all/.test(t)) return new Set([0, 1, 2, 3, 4, 5, 6]);
  if (t.includes("weekday")) return new Set([0, 1, 2, 3, 4]);
  if (t.includes("weekend")) return new Set([5, 6]);
  const out = new Set<number>();
  for (const w of t.split(/[^a-z]+/).filter(Boolean)) {
    const i = DAYS.indexOf(w.slice(0, 3));
    if (i < 0) return null;
    out.add(i);
  }
  return out.size ? out : null;
}
// Each date From..To (To blank = one day), at most 200.
function datesIn(from: string, to: string, days: Set<number>) {
  const out: string[] = [];
  for (let d = from, n = 0; d <= to && n < 200; d = addDay(d, 1), n++) if (days.has(dowOf(d))) out.push(d);
  return out;
}

export type Built = { errors: string[]; warnings: string[]; plan?: unknown; players?: { email: string; day: string; slots?: unknown[]; notes: string[]; extras: unknown[] }[]; summary?: string };

export function build(tabs: Record<string, unknown>): Built {
  const errors: string[] = [];
  const warnings: string[] = [];
  const err = (tab: string, r: Row | null, msg: string) => errors.push(`${tab}${r ? ` row ${r.n}` : ""}: ${msg}`);

  // ---- Settings ----
  const settings: Record<string, string> = {};
  rowsOf(tabs.Settings, "Setting").forEach((r) => { settings[slug(r.get("Setting"))] = r.get("Value"); });
  const form = settings[slug("Check-in form")] ?? "";
  const weights = settings[slug("Weights guidance")] ?? "";

  // ---- Blocks ----
  const blocks: { n: number; name: string; from: string; to: string; aim: string }[] = [];
  rowsOf(tabs.Blocks, "Block").forEach((r) => {
    const name = r.get("Block"), from = r.get("From"), to = r.get("To");
    if (!name) return err("Blocks", r, "Block name is missing");
    if (!isDay(from)) return err("Blocks", r, `From "${from}" is not a date`);
    if (!isDay(to)) return err("Blocks", r, `To "${to}" is not a date`);
    if (to < from) return err("Blocks", r, "To is before From");
    blocks.push({ n: blocks.length + 1, name, from, to, aim: r.get("Aim") });
  });
  blocks.sort((a, b) => a.from.localeCompare(b.from));
  blocks.forEach((b, i) => {
    b.n = i + 1;
    if (i && b.from <= blocks[i - 1].to) errors.push(`Blocks: ${b.name} overlaps ${blocks[i - 1].name}`);
  });
  if (!blocks.length) errors.push("Blocks: add at least one block with From and To dates");

  // ---- Sessions: one row per exercise; a blank Code carries on the session above ----
  type Item = { n: string; d: string; v: string | null };
  type Section = { title: string; note?: string; items: Item[] };
  type Session = { kind: string; name: string; sub: string; mins: number; track: { id: string; n: string } | null; blocks: Section[] };
  const sessions: Record<string, Session> = {};
  let cur: Session | null = null, sec: Section | null = null;
  rowsOf(tabs.Sessions, "Code").forEach((r) => {
    const code = r.get("Code").toUpperCase();
    if (code) {
      if (sessions[code]) { cur = null; return err("Sessions", r, `code ${code} is used twice; give each session its own code, or leave Code blank on its later rows`); }
      const kind = r.get("Kind").toLowerCase() || "gym";
      if (!KINDS.includes(kind) || kind === "rest") err("Sessions", r, `Kind "${r.get("Kind")}" should be gym, speed or run`);
      const mins = r.get("Minutes");
      if (mins && !/^\d+$/.test(mins)) err("Sessions", r, `Minutes "${mins}" should be a number`);
      const lift = r.get("Track lift");
      cur = { kind, name: r.get("Session") || code, sub: r.get("Subtitle"), mins: +mins || 0, track: lift ? { id: slug(lift), n: lift } : null, blocks: [] };
      sessions[code] = cur;
      sec = null;
    }
    if (!cur) return err("Sessions", r, "no Code on this row or a row above it");
    const title = r.get("Section");
    if (title || !sec) {
      sec = { title: title || "Session", items: [] };
      const note = r.get("Section note");
      if (note) sec.note = note;
      (cur as Session).blocks.push(sec);
    }
    const ex = r.get("Exercise");
    if (ex) sec.items.push({ n: ex, d: r.get("Detail"), v: r.get("Video") || null });
    else if (r.get("Detail") || r.get("Video")) err("Sessions", r, "Exercise is blank but Detail or Video is filled");
  });

  // ---- Schedule: one row per slot; Player blank = whole team ----
  type Slot = { t: string; code?: string; kind?: string; title?: string; detail?: string };
  const days: Record<string, Slot[]> = {};
  const player: Record<string, { slots?: Slot[]; notes: string[]; extras?: unknown[] }> = {}; // key email|day
  const pkey = (e: string, d: string) => `${e}|${d}`;
  const inBlocks = (d: string) => blocks.some((b) => d >= b.from && d <= b.to);
  rowsOf(tabs.Schedule, "Session").forEach((r) => {
    const d = r.get("Date"), what = r.get("Session"), email = r.get("Player").toLowerCase();
    if (!isDay(d)) return err("Schedule", r, `Date "${d}" is not a date`);
    if (!what) return err("Schedule", r, "Session is blank (use a session code, or Rest)");
    if (email && !isEmail(email)) return err("Schedule", r, `Player "${email}" is not an email address`);
    if (!inBlocks(d)) warnings.push(`Schedule row ${r.n}: ${d} is outside every block, so players won't see it`);
    const slot: Slot = { t: r.get("When") || "Any time" };
    if (REST.includes(what.toLowerCase())) Object.assign(slot, { kind: "rest", title: "Off", detail: r.get("Note") });
    else {
      const code = what.toUpperCase();
      if (!sessions[code]) return err("Schedule", r, `session ${code} isn't on the Sessions tab`);
      slot.code = code;
    }
    if (email) {
      const p = (player[pkey(email, d)] ??= { notes: [] });
      (p.slots ??= []).push(slot);
    } else (days[d] ??= []).push(slot);
  });

  // ---- Notes: the "From your coach" box, for the squad (Who = All) or one player ----
  const teamNotes: Record<string, string[]> = {};
  const teamExtras: Record<string, unknown[]> = {};
  const replaced = new Set<string>();
  let suggested = 0;
  const who = (tab: string, r: Row, col = "Who") => {
    const w = r.get(col).toLowerCase();
    if (!w || w === "all") return "";
    if (!isEmail(w)) { err(tab, r, `${col} "${r.get(col)}" should be All or a player's email address`); return null; }
    return w;
  };
  const range = (tab: string, r: Row, fromCol: string, toCol: string) => {
    const from = r.get(fromCol), to = r.get(toCol) || from;
    if (!isDay(from)) { err(tab, r, `${fromCol} "${from}" is not a date`); return null; }
    if (!isDay(to) || to < from) { err(tab, r, `${toCol} "${to}" should be a date on or after ${fromCol}`); return null; }
    return { from, to };
  };
  const pday = (email: string, d: string) => (player[pkey(email, d)] ??= { notes: [] });
  const newNotes = hasCol(tabs.Notes, "Message");
  rowsOf(tabs.Notes, newNotes ? "Message" : "Note").forEach((r) => {
    if (newNotes) {
      if (!live(r)) { if (r.get("Status").toLowerCase() === "suggested") suggested++; return; }
      const w = who("Notes", r); if (w === null) return;
      const span = range("Notes", r, "From", "To"); if (!span) return;
      const note = r.get("Message");
      if (!note) return err("Notes", r, "Message is blank");
      datesIn(span.from, span.to, daySet("")!).forEach((d) => w ? pday(w, d).notes.push(note) : (teamNotes[d] ??= []).push(note));
      return;
    }
    // The original Notes tab: Player | From | To | Note
    const email = r.get("Player").toLowerCase(), from = r.get("From"), to = r.get("To") || from, note = r.get("Note");
    if (!isEmail(email)) return err("Notes", r, `Player "${email}" is not an email address`);
    if (!isDay(from)) return err("Notes", r, `From "${from}" is not a date`);
    if (!isDay(to) || to < from) return err("Notes", r, `To "${to}" should be a date on or after From`);
    if (!note) return err("Notes", r, "Note is blank");
    datesIn(from, to, daySet("")!).forEach((d) => pday(email, d).notes.push(note));
  });

  // ---- Events: informal things to know about. No tick box, no RSVP. ----
  let nEvents = 0, nActs = 0;
  rowsOf(tabs.Events, "Title").forEach((r) => {
    if (!live(r)) { if (r.get("Status").toLowerCase() === "suggested") suggested++; return; }
    const d = r.get("Date"), title = r.get("Title"), start = r.get("Start"), end = r.get("End");
    if (!isDay(d)) return err("Events", r, `Date "${d}" is not a date`);
    if (!title) return err("Events", r, "Title is blank");
    if (start && !isTime(start)) return err("Events", r, `Start "${start}" should be a time like 19:30`);
    if (end && !isTime(end)) return err("Events", r, `End "${end}" should be a time like 20:30`);
    const w = who("Events", r); if (w === null) return;
    const ev = { kind: "event", id: `ev${r.n}`, t: start || "Any time", end, type: r.get("Type"), title,
      where: r.get("Where"), detail: r.get("Details"), link: r.get("Link") };
    if (w) (pday(w, d).extras ??= []).push(ev); else (teamExtras[d] ??= []).push(ev);
    nEvents++;
  });

  // ---- Activities: extra things to do, with a tick box; may replace the day's plan ----
  const ACT_KIND: Record<string, string> = { gym: "gym", speed: "speed", run: "run", rest: "rest" };
  rowsOf(tabs.Activities, "Title").forEach((r) => {
    if (!live(r)) { if (r.get("Status").toLowerCase() === "suggested") suggested++; return; }
    const title = r.get("Title");
    if (!title) return err("Activities", r, "Title is blank");
    const span = range("Activities", r, "From", "To"); if (!span) return;
    const days = daySet(r.get("Days"));
    if (!days) return err("Activities", r, `Days "${r.get("Days")}" should be Every day, Weekdays, Weekends or days like Mon, Wed`);
    const mins = r.get("Minutes");
    if (mins && !/^\d+$/.test(mins)) return err("Activities", r, `Minutes "${mins}" should be a number`);
    const time = r.get("Time");
    const w = who("Activities", r); if (w === null) return;
    const type = r.get("Type");
    const kind = ACT_KIND[type.toLowerCase()] ?? "extra";
    const video = r.get("Video link") || null;
    const steps = r.get("Steps").split(/\s*\n\s*/).map((x) => x.trim()).filter(Boolean)
      .map((x) => { const [n, ...d] = x.split("|"); return { n: n.trim(), d: d.join("|").trim(), v: null as string | null }; });
    const act: Record<string, unknown> = { kind, id: `ac${r.n}`, t: time || "Any time", type, title, detail: r.get("Subtitle") };
    if (kind !== "rest") {
      const blocks = steps.length ? [{ title: "What to do", items: steps }] : video ? [{ title: "Watch", items: [{ n: title, d: r.get("Subtitle"), v: video }] }] : [];
      if (steps.length && video) steps[0].v = video;
      act.s = { kind, name: title, sub: r.get("Subtitle"), mins: +mins || 0, track: null, blocks };
    }
    const replace = r.get("Replaces plan").toLowerCase() === "yes";
    const ds = datesIn(span.from, span.to, days);
    if (!ds.length) warnings.push(`Activities row ${r.n}: no ${r.get("Days")} between ${span.from} and ${span.to}`);
    ds.forEach((d) => {
      if (w) { const p = pday(w, d); (p.extras ??= []).push(act); if (replace) p.slots ??= []; }
      else { (teamExtras[d] ??= []).push(act); if (replace) replaced.add(d); }
    });
    nActs++;
  });
  replaced.forEach((d) => { days[d] = []; });
  if (suggested) warnings.push(`${suggested} Suggested row(s) are waiting for you. Set Status to Live to show them.`);

  if (errors.length) return { errors: errors.slice(0, 50), warnings };

  const used = new Set<string>();
  Object.values(days).flat().forEach((s) => s.code && used.add(s.code));
  Object.values(player).forEach((p) => p.slots?.forEach((s) => s.code && used.add(s.code)));
  Object.keys(sessions).filter((c) => !used.has(c)).forEach((c) => warnings.push(`Session ${c} isn't on the Schedule yet`));

  const plan = { form, weights, blocks, sessions, days, notes: teamNotes, extras: teamExtras };
  const players = Object.entries(player).map(([k, v]) => {
    const [email, day] = k.split("|");
    return { email, day, ...(v.slots ? { slots: v.slots } : {}), notes: v.notes, extras: v.extras ?? [] };
  });

  const summary = `${blocks.length} block(s), ${Object.keys(sessions).length} session(s), ${Object.keys(days).length} team day(s), ${nEvents} event(s), ${nActs} activit${nActs === 1 ? "y" : "ies"}, ${new Set(players.map((p) => p.email)).size} player(s) with their own rows`;
  return { errors, warnings, plan, players, summary };
}
