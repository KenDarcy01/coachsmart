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
// Blank rows are skipped. Row numbers match the sheet (headings = row 1).
function rowsOf(cells: unknown): Row[] {
  if (!Array.isArray(cells) || !cells.length) return [];
  const head = (cells[0] as unknown[]).map((h) => slug(tidy(h)));
  const out: Row[] = [];
  cells.slice(1).forEach((r, i) => {
    const vals = (Array.isArray(r) ? r : []).map(tidy);
    if (!vals.some(Boolean)) return;
    out.push({ n: i + 2, get: (col) => vals[head.indexOf(slug(col))] ?? "" });
  });
  return out;
}

export type Built = { errors: string[]; warnings: string[]; plan?: unknown; players?: { email: string; day: string; slots?: unknown[]; notes: string[] }[]; summary?: string };

export function build(tabs: Record<string, unknown>): Built {
  const errors: string[] = [];
  const warnings: string[] = [];
  const err = (tab: string, r: Row | null, msg: string) => errors.push(`${tab}${r ? ` row ${r.n}` : ""}: ${msg}`);

  // ---- Settings ----
  const settings: Record<string, string> = {};
  rowsOf(tabs.Settings).forEach((r) => { settings[slug(r.get("Setting"))] = r.get("Value"); });
  const form = settings[slug("Check-in form")] ?? "";
  const weights = settings[slug("Weights guidance")] ?? "";

  // ---- Blocks ----
  const blocks: { n: number; name: string; from: string; to: string; aim: string }[] = [];
  rowsOf(tabs.Blocks).forEach((r) => {
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
  rowsOf(tabs.Sessions).forEach((r) => {
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
  const player: Record<string, { slots?: Slot[]; notes: string[] }> = {}; // key email|day
  const pkey = (e: string, d: string) => `${e}|${d}`;
  const inBlocks = (d: string) => blocks.some((b) => d >= b.from && d <= b.to);
  rowsOf(tabs.Schedule).forEach((r) => {
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

  // ---- Notes: shown on that player's diary each day From..To ----
  rowsOf(tabs.Notes).forEach((r) => {
    const email = r.get("Player").toLowerCase(), from = r.get("From"), to = r.get("To") || from, note = r.get("Note");
    if (!isEmail(email)) return err("Notes", r, `Player "${email}" is not an email address`);
    if (!isDay(from)) return err("Notes", r, `From "${from}" is not a date`);
    if (!isDay(to) || to < from) return err("Notes", r, `To "${to}" should be a date on or after From`);
    if (!note) return err("Notes", r, "Note is blank");
    let n = 0;
    for (let d = from; d <= to && n < 200; d = addDay(d, 1), n++) (player[pkey(email, d)] ??= { notes: [] }).notes.push(note);
    if (n >= 200) warnings.push(`Notes row ${r.n}: only the first 200 days are used`);
  });

  if (errors.length) return { errors: errors.slice(0, 50), warnings };

  const used = new Set<string>();
  Object.values(days).flat().forEach((s) => s.code && used.add(s.code));
  Object.values(player).forEach((p) => p.slots?.forEach((s) => s.code && used.add(s.code)));
  Object.keys(sessions).filter((c) => !used.has(c)).forEach((c) => warnings.push(`Session ${c} isn't on the Schedule yet`));

  const plan = { form, weights, blocks, sessions, days };
  const players = Object.entries(player).map(([k, v]) => {
    const [email, day] = k.split("|");
    return { email, day, ...(v.slots ? { slots: v.slots } : {}), notes: v.notes };
  });

  const summary = `${blocks.length} block(s), ${Object.keys(sessions).length} session(s), ${Object.keys(days).length} team day(s), ${new Set(players.map((p) => p.email)).size} player(s) with their own rows`;
  return { errors, warnings, plan, players, summary };
}
