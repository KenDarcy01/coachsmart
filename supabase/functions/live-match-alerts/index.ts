// deno-lint-ignore-file no-explicit-any
// Live match alerts (pushes for followed matches).
//
// Woken by the database (lm_alert_wake) when a score is saved or the clock
// changes phase. It answers straight away and then, in the background:
//   1. asks lm_alert_claim for scores that have settled (8 s old, so a score
//      undone straight away is never sent) and for kick-off / HT / FT
//   2. works out who wants which alert (lm_alert_targets)
//   3. sends the pushes through FCM: one for each score, plus throw-in, half
//      time and full time. Each is its own notification (Ken, 2026-10-16), so
//      nothing replaces the last; iOS groups them by match.
//   4. repeats while newer scores are still settling
//
// POST { match_stats_id }  (service role only)
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { SignJWT, importPKCS8 } from "https://esm.sh/jose@5.4.1";

const SETTLE_S = 8;
const MAX_RUN_MS = 100_000;

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
const pad2 = (n: number) => String(n).padStart(2, "0");
const gaa = (s: { g: number; p: number }) => `${s.g}-${pad2(s.p)}`;
const cleanClub = (n: string) =>
  String(n || "").replace(/\b(GAA|GFC|CLG|HC|LGFA|Camogie Club)\b/gi, "").replace(/\s{2,}/g, " ").trim();

function roleOf(req: Request): string {
  try {
    const jwt = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
    const part = jwt.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    return JSON.parse(atob(part + "===".slice((part.length + 3) % 4))).role || "";
  } catch {
    return "";
  }
}

let fcmCache: { token: string; project: string; exp: number } | null = null;
async function fcmAccess() {
  if (fcmCache && fcmCache.exp > Date.now() + 60_000) return fcmCache;
  const sa = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT") || "{}");
  const key = await importPKCS8(String(sa.private_key || "").replace(/\\n/g, "\n"), "RS256");
  const now = Math.floor(Date.now() / 1000);
  const assertion = await new SignJWT({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }).setProtectedHeader({ alg: "RS256", typ: "JWT" }).sign(key);
  const r = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }),
  });
  const j = await r.json();
  fcmCache = { token: j.access_token, project: sa.project_id, exp: Date.now() + 3_300_000 };
  return fcmCache;
}

async function sendPush(token: string, eventId: number, title: string, body: string): Promise<string> {
  const fcm = await fcmAccess();
  const group = `live-${eventId}`;
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${fcm.project}/messages:send`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${fcm.token}` },
    body: JSON.stringify({
      message: {
        token,
        notification: { title, body },
        data: {
          live_event_id: String(eventId),
          // Older app builds open the event from this
          link_page: `eventDetails?eventID=${eventId}`,
        },
        apns: {
          headers: { "apns-priority": "10", "apns-push-type": "alert" },
          payload: { aps: { alert: { title, body }, sound: "default", "thread-id": group } },
        },
        android: { priority: "high", notification: { sound: "default", click_action: "FLUTTER_NOTIFICATION_CLICK" } },
      },
    }),
  });
  if (!res.ok) {
    const txt = (await res.text()).slice(0, 200);
    console.warn("FCM", res.status, txt);
    return `${res.status} ${txt.slice(0, 80)}`;
  }
  return "ok";
}

// ── Message text ──────────────────────────────────────────────────────────────
type Names = { us: string; opp: string; team: string };

function minute(state: any, half: number, sec: number) {
  const halfMin = Math.round(((state.timer && state.timer.duration_seconds) || 1800) / 60);
  const m = Math.floor((sec || 0) / 60) + 1;
  const base = half === 2 ? halfMin : 0;
  return m > halfMin ? `${base + halfMin}+${m - halfMin}'` : `${base + m}'`;
}

function scoreLine(n: Names, s: any) {
  return `${n.us} ${gaa(s.us)} ${n.opp} ${gaa(s.opp)}`;
}

function leadText(n: Names, s: any) {
  const d = s.us.t - s.opp.t;
  if (d === 0) return "Level";
  return `${d > 0 ? n.us : n.opp} lead by ${Math.abs(d)}`;
}

// One message per score. score is the score just after this one.
function scoreMessage(n: Names, state: any, item: any, score: any, names: boolean) {
  const what = item.value === 3 ? "GOAL" : item.type;
  const who = item.side === "us" ? (names && item.member ? item.member : n.us) : n.opp;
  const title = `${what} · ${scoreLine(n, score)}`;
  const body = `${who} ${minute(state, item.half, item.second)}. ${leadText(n, score)}. ${n.team}`;
  return { title, body };
}

// The score after each item: the current score with later items taken off
function runningScores(items: any[], now: any) {
  const cur = { us: { ...now.us }, opp: { ...now.opp } };
  const out: any[] = new Array(items.length);
  for (let i = items.length - 1; i >= 0; i--) {
    out[i] = { us: { ...cur.us }, opp: { ...cur.opp } };
    const side = items[i].side === "us" ? cur.us : cur.opp;
    const v = Number(items[i].value) || 0;
    if (v === 3) side.g = Math.max(0, side.g - 1); else side.p = Math.max(0, side.p - v);
    side.t = side.g * 3 + side.p;
  }
  return out;
}

function phaseMessage(n: Names, state: any, phase: string) {
  const s = state.score;
  if (phase === "ko") return { title: `Throw-in · ${n.team} v ${n.opp}`, body: "Tap to watch live." };
  if (phase === "ht") return { title: `Half time · ${scoreLine(n, s)}`, body: `${n.team}. Tap for the chart and scorers.` };
  const d = s.us.t - s.opp.t;
  const res = d > 0 ? `won by ${d}` : d < 0 ? `lost by ${-d}` : "drew";
  return { title: `Full time · ${scoreLine(n, s)}`, body: `${n.team} ${res}.` };
}

// ── One pass ──────────────────────────────────────────────────────────────────
async function handle(sb: any, claim: any): Promise<Record<string, unknown> | null> {
  const items: any[] = claim.items || [];
  const phases: string[] = claim.phases || [];
  if (!items.length && !phases.length) return null;
  const state = claim.state || {};
  const ev = state.event || {};
  const n: Names = {
    us: cleanClub(ev.club_name) || ev.team_name || "Us",
    opp: ev.opposition || "Opposition",
    team: ev.team_name || "",
  };
  const { data: targets, error } = await sb.rpc("lm_alert_targets", { p_event_id: claim.event_id, p_scorer: claim.scorer });
  if (error) { console.warn("targets", error.message); return { items: items.length, phases, error: "targets: " + error.message }; }

  const result = phases.includes("ft") ? "ft" : phases.includes("ht") ? "ht" : null;
  const scores = runningScores(items, state.score);
  const jobs: Promise<string[]>[] = [];
  const results: string[] = [];
  for (const t of targets || []) {
    // In order: throw-in, each score, then half time or full time
    const msgs: { title: string; body: string }[] = [];
    if (phases.includes("ko") && t.kickoff && !result) msgs.push(phaseMessage(n, state, "ko"));
    items.forEach((it, i) => {
      if (t.level === "all" || (t.level === "goals" && it.value === 3)) msgs.push(scoreMessage(n, state, it, scores[i], t.names));
    });
    if (result) msgs.push(phaseMessage(n, state, result));
    if (!msgs.length) continue;
    jobs.push((async () => {
      const r: string[] = [];
      for (const m of msgs) r.push(await sendPush(t.fcm_token, claim.event_id, m.title, m.body).catch((e) => `error ${String(e).slice(0, 80)}`));
      return r;
    })());
    if (jobs.length >= 25) for (const r of await Promise.all(jobs.splice(0))) results.push(...r);
  }
  for (const r of await Promise.all(jobs)) results.push(...r);
  // A short record for lm_alert_probe: counts and FCM answers only
  const fcm: Record<string, number> = {};
  for (const r of results) fcm[r] = (fcm[r] || 0) + 1;
  return { items: items.length, phases, phase: claim.phase, targets: (targets || []).length, sent: results.length, fcm };
}

async function run(matchStatsId: number) {
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
  const started = Date.now();
  while (true) {
    const { data: claim, error } = await sb.rpc("lm_alert_claim", { p_match_stats_id: matchStatsId, p_settle: SETTLE_S });
    if (error) {
      console.error("claim", error.message);
      await sb.rpc("lm_alert_note", { p_match_stats_id: matchStatsId, p_note: { error: "claim: " + error.message } });
      return;
    }
    let note: Record<string, unknown> | null = null;
    try { note = await handle(sb, claim); } catch (e) { console.error("handle", e); note = { error: "handle: " + String(e).slice(0, 160) }; }
    if (note) await sb.rpc("lm_alert_note", { p_match_stats_id: matchStatsId, p_note: note });
    if (!claim.more) return;
    if (Date.now() - started > MAX_RUN_MS) {
      await sb.rpc("lm_alert_rewake", { p_match_stats_id: matchStatsId });
      return;
    }
    await sleep(2500);
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  if (roleOf(req) !== "service_role") return new Response("Forbidden", { status: 403 });
  let id = 0;
  try { id = Number((await req.json()).match_stats_id); } catch { /* bad body */ }
  if (!id) return new Response("match_stats_id required", { status: 400 });
  const work = run(id).catch((e) => console.error("live-match-alerts", e));
  // Keep going after answering (pg_net only waits a few seconds)
  // @ts-ignore EdgeRuntime is provided by Supabase
  if (typeof EdgeRuntime !== "undefined") EdgeRuntime.waitUntil(work); else await work;
  return new Response(JSON.stringify({ ok: true }), { headers: { "Content-Type": "application/json" } });
});
