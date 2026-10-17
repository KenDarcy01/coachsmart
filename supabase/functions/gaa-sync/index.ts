// Supabase Edge Function: copies Dublin GAA games (every club) from Sportlomo
// into the gaa_* tables, one code and one week per call so each call stays
// well inside the edge function time and CPU limits.
//
// Woken by pg_cron through public.gaa_sync_wake(), once per code, with a
// service-role token:
//   { "mode": "backfill", "code": c }          next week of this season this code has
//                                              never loaded (nothing once all are in)
//   { "mode": "nightly", "part": n, "code": c }  week n of six, from two weeks ago
//   { "mode": "manual", "from": "YYYY-MM-DD", "to": "YYYY-MM-DD", "code"?: c }
//                                              (at most 15 days; every code if none given)
//
// A window is only written when every source loaded, and it replaces that
// window's games for the code, so moved or cancelled fixtures don't linger.
// Each call logs a row as it starts, so a call the platform kills still shows
// up as a failure.
import { createClient } from "npm:@supabase/supabase-js@2.43.4";
import { CODES, fetchClub, SOURCES } from "../gaa-fixtures/source.ts";
import { row } from "./rows.ts";

const WINDOW_DAYS = 7;
const NIGHTLY_PARTS = 6;
const MAX_TRIES = 3;   // a backfill week that keeps failing is skipped so later weeks still load

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

// Every game of the given codes between two days (inclusive)
async function loadWindow(from: string, to: string, codes: string[]) {
  const jobs = codes.flatMap((code) =>
    SOURCES[code].userIds.map((lvl) => fetchClub("", "", from, to, code, lvl, { maxPages: 150, strict: true }))
  );
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
  const code = body.code ? String(body.code) : "";
  if (code && !CODES.includes(code)) return new Response(`Unknown code ${code}`, { status: 400 });
  if (mode !== "manual" && !code) return new Response("code is required", { status: 400 });
  const codes = code ? [code] : CODES;
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
  const today = dublinToday();

  // Which window to load
  let from: string, to: string;
  if (mode === "nightly") {
    const part = Math.max(0, Math.min(NIGHTLY_PARTS - 1, Number(body.part) || 0));
    from = addDays(today, -2 * WINDOW_DAYS + part * WINDOW_DAYS);
    to = addDays(from, WINDOW_DAYS - 1);
  } else if (mode === "manual") {
    from = String(body.from || ""); to = String(body.to || "");
    const span = (Date.parse(to) - Date.parse(from)) / 864e5;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(from) || !/^\d{4}-\d{2}-\d{2}$/.test(to) || !(span >= 0 && span <= 15)) {
      return new Response("from/to must be YYYY-MM-DD, at most 15 days apart", { status: 400 });
    }
  } else {
    // Backfill: fixed weeks from 1 January, up to four weeks ahead
    const { data: rows, error } = await sb.from("gaa_sync_log").select("from_day, to_day, ok")
      .eq("mode", "backfill").eq("code", code);
    if (error) return new Response(error.message, { status: 500 });
    const done = new Set<string>(), tries: Record<string, number> = {};
    for (const r of rows ?? []) {
      const k = `${r.from_day}|${r.to_day}`;
      if (r.ok) done.add(k); else tries[k] = (tries[k] || 0) + 1;
    }
    const end = addDays(today, 28);
    let next: string | null = null;
    for (let d = `${today.slice(0, 4)}-01-01`; d <= end; d = addDays(d, WINDOW_DAYS)) {
      const k = `${d}|${addDays(d, WINDOW_DAYS - 1)}`;
      if (!done.has(k) && (tries[k] || 0) < MAX_TRIES) { next = d; break; }
    }
    if (!next) return Response.json({ mode, code, done: true });
    from = next; to = addDays(next, WINDOW_DAYS - 1);
  }

  const t0 = Date.now();
  const { data: started } = await sb.from("gaa_sync_log")
    .insert({ mode, code: code || null, from_day: from, to_day: to, ok: false, error: "Started, no finish recorded (stopped by a time or CPU limit?)" })
    .select("sync_id").single();
  const finish = (ok: boolean, games: number, error?: string) => {
    const fields = { ok, games, seconds: (Date.now() - t0) / 1000, error: error ?? null };
    return started ? sb.from("gaa_sync_log").update(fields).eq("sync_id", started.sync_id)
      : sb.from("gaa_sync_log").insert({ mode, code: code || null, from_day: from, to_day: to, ...fields });
  };
  try {
    const games = await loadWindow(from, to, codes);
    // A source having a bad day can answer with nothing: never let that wipe a loaded window
    const { count } = await sb.from("gaa_games").select("game_id", { count: "exact", head: true })
      .in("code", codes).gte("start_at", `${from}T00:00:00Z`).lte("start_at", `${to}T23:59:59Z`);
    if ((count ?? 0) > 20 && games.length < (count ?? 0) / 2) {
      throw new Error(`Only ${games.length} games came back where ${count} were stored; kept the stored games`);
    }
    const { data, error } = await sb.rpc("gaa_replace_window", { p_from: from, p_to: to, p_codes: codes, p_games: games });
    if (error) throw new Error(error.message);
    await finish(true, Number(data) || games.length);
    return Response.json({ mode, code, from, to, games: games.length });
  } catch (e) {
    const msg = (e as Error).message;
    console.error(`gaa-sync ${mode} ${code} ${from}..${to}: ${msg}`);
    await finish(false, 0, msg.slice(0, 500));
    return new Response(msg, { status: 502 });
  }
});
