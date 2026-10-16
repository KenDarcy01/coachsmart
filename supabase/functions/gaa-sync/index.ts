// Supabase Edge Function: copies Dublin GAA games (every club, every code) from
// Sportlomo into the gaa_* tables, two weeks at a time.
//
// Woken by pg_cron through public.gaa_sync_wake() with a service-role token:
//   { "mode": "backfill" }          next two-week window of this season that has
//                                   never loaded (does nothing once all are in)
//   { "mode": "nightly", "part": n }  n = 0: last 14 days, 1: next 14, 2: the 14 after
//   { "mode": "manual", "from": "YYYY-MM-DD", "to": "YYYY-MM-DD" }  (at most 15 days)
//
// A window is only written when every source loaded, and it replaces that
// window's games, so moved or cancelled fixtures don't linger.
import { createClient } from "npm:@supabase/supabase-js@2.43.4";
import { CODES, fetchClub, SOURCES } from "../gaa-fixtures/source.ts";
import { row } from "./rows.ts";

const WINDOW_DAYS = 14;

const isoDay = (d: Date) => d.toISOString().slice(0, 10);
const addDays = (iso: string, n: number) => {
  const d = new Date(iso + "T12:00:00Z");
  d.setUTCDate(d.getUTCDate() + n);
  return isoDay(d);
};
const dublinToday = () => new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Dublin" }).format(new Date());

function roleOf(req: Request): string {
  try {
    const jwt = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
    const part = jwt.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    return JSON.parse(atob(part + "===".slice((part.length + 3) % 4))).role || "";
  } catch {
    return "";
  }
}

// Every game of every code between two days (inclusive)
async function loadWindow(from: string, to: string) {
  const jobs = CODES.flatMap((code) => SOURCES[code].userIds.map((lvl) => fetchClub("", "", from, to, code, lvl)));
  const games = (await Promise.all(jobs)).flat();
  const seen = new Set<string>();
  return games.map(row).filter((g) => {
    if (!g.compId) return false;
    const k = [g.compId, g.home, g.away, g.start].join("|");
    return !seen.has(k) && seen.add(k);
  });
}

Deno.serve(async (req) => {
  if (roleOf(req) !== "service_role") return new Response("Forbidden", { status: 403 });
  const body = await req.json().catch(() => ({}));
  const mode = String(body.mode || "backfill");
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
  const today = dublinToday();

  // Which window to load
  let from: string, to: string;
  if (mode === "nightly") {
    const part = Math.max(0, Math.min(2, Number(body.part) || 0));
    from = addDays(today, -WINDOW_DAYS + part * WINDOW_DAYS);
    to = addDays(from, WINDOW_DAYS - 1);
  } else if (mode === "manual") {
    from = String(body.from || ""); to = String(body.to || "");
    const span = (Date.parse(to) - Date.parse(from)) / 864e5;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(from) || !/^\d{4}-\d{2}-\d{2}$/.test(to) || !(span >= 0 && span <= 15)) {
      return new Response("from/to must be YYYY-MM-DD, at most 15 days apart", { status: 400 });
    }
  } else {
    // Backfill: fixed two-week windows from 1 January, up to four weeks ahead
    const { data: done, error } = await sb.from("gaa_sync_log").select("from_day, to_day").eq("ok", true).eq("mode", "backfill");
    if (error) return new Response(error.message, { status: 500 });
    const have = new Set((done ?? []).map((r) => `${r.from_day}|${r.to_day}`));
    const end = addDays(today, 28);
    let next: string | null = null;
    for (let d = `${today.slice(0, 4)}-01-01`; d <= end; d = addDays(d, WINDOW_DAYS)) {
      if (!have.has(`${d}|${addDays(d, WINDOW_DAYS - 1)}`)) { next = d; break; }
    }
    if (!next) return Response.json({ mode, done: true });
    from = next; to = addDays(next, WINDOW_DAYS - 1);
  }

  const t0 = Date.now();
  const log = (ok: boolean, games: number, error?: string) =>
    sb.from("gaa_sync_log").insert({ mode, from_day: from, to_day: to, ok, games, seconds: (Date.now() - t0) / 1000, error: error ?? null });
  try {
    const games = await loadWindow(from, to);
    // A source having a bad day can answer with nothing: never let that wipe a loaded window
    const { count } = await sb.from("gaa_games").select("game_id", { count: "exact", head: true })
      .gte("start_at", `${from}T00:00:00Z`).lte("start_at", `${to}T23:59:59Z`);
    if ((count ?? 0) > 20 && games.length < (count ?? 0) / 2) {
      throw new Error(`Only ${games.length} games came back where ${count} were stored; kept the stored games`);
    }
    const { data, error } = await sb.rpc("gaa_replace_window", { p_from: from, p_to: to, p_codes: CODES, p_games: games });
    if (error) throw new Error(error.message);
    await log(true, Number(data) || games.length);
    return Response.json({ mode, from, to, games: games.length });
  } catch (e) {
    const msg = (e as Error).message;
    console.error(`gaa-sync ${mode} ${from}..${to}: ${msg}`);
    await log(false, 0, msg.slice(0, 500));
    return new Response(msg, { status: 502 });
  }
});
