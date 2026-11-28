// deno-lint-ignore-file no-explicit-any
// Push for Important messages (Ken 2026-11-26).
//
// Woken by the database (app_message_push_run, each minute and on save) with
// the ids of Important messages whose push is now due. For each one it finds
// the phones in the message's audience (app_message_push_targets: one per
// push token) and sends a plain push. No link: a tap just opens the app, and
// v3 shows the Important pop-up on open / resume. No notifications row, no
// email (Ken: push only).
//
// POST { ids: number[] }  (service role only)
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { SignJWT, importPKCS8 } from "https://esm.sh/jose@5.4.1";

function roleOf(req: Request): string {
  try {
    const jwt = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
    const part = jwt.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    return JSON.parse(atob(part + "===".slice((part.length + 3) % 4))).role || "";
  } catch {
    return "";
  }
}

async function fcmAccess() {
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
  return { token: String(j.access_token || ""), project: String(sa.project_id || "") };
}

const short = (s: string, n: number) => (s.length > n ? s.slice(0, n - 1).trimEnd() + "…" : s);

async function sendOne(fcm: { token: string; project: string }, to: string, id: number, title: string, body: string) {
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${fcm.project}/messages:send`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${fcm.token}` },
    body: JSON.stringify({
      message: {
        token: to,
        notification: { title, body },
        data: { app_message_id: String(id), link_page: "" },
        apns: {
          headers: { "apns-priority": "10", "apns-push-type": "alert" },
          payload: { aps: { alert: { title, body }, sound: "default", "thread-id": "club-messages" } },
        },
        android: { priority: "high", notification: { sound: "default", click_action: "FLUTTER_NOTIFICATION_CLICK" } },
      },
    }),
  });
  if (res.ok) return "ok";
  const txt = await res.text();
  return /UNREGISTERED|registration-token-not-registered/i.test(txt) ? "dead" : `err ${res.status} ${txt.slice(0, 120)}`;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });
  if (roleOf(req) !== "service_role") return new Response("Forbidden", { status: 403 });
  const { ids } = await req.json().catch(() => ({ ids: [] }));
  const sb = createClient(Deno.env.get("SUPABASE_URL") ?? "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "");
  const fcm = await fcmAccess();
  const out: any[] = [];

  for (const id of (Array.isArray(ids) ? ids : []).map(Number).filter(Boolean)) {
    const { data: m } = await sb.from("app_messages")
      .select("id, kind, title, body, club_id, team_ids, push").eq("id", id).maybeSingle();
    if (!m || m.kind !== "important" || !m.push) { out.push({ id, skipped: true }); continue; }

    // Who it is from: the club (or club · team for one team), else CoachSmart.
    let from = "CoachSmart";
    const teamIds: number[] = m.team_ids || [];
    if (teamIds.length === 1) {
      const { data: t } = await sb.from("teams").select("team_name, clubs(club_name)").eq("team_id", teamIds[0]).maybeSingle();
      if (t) from = `${(t as any).clubs?.club_name ?? ""} · ${t.team_name}`.replace(/^ · /, "");
    } else if (m.club_id) {
      const { data: c } = await sb.from("clubs").select("club_name").eq("club_id", m.club_id).maybeSingle();
      if (c?.club_name) from = c.club_name;
    }
    // Ken 2026-11-28: club name in the push title, e.g. "Clontarf GAA: Pitches closed Saturday".
    const title = short(`${from}: ${String(m.title || "").trim()}`, 110);
    const text = String(m.body || "").replace(/\s+/g, " ").trim();
    const body = short(text, 170);

    const { data: targets, error } = await sb.rpc("app_message_push_targets", { p_id: id });
    if (error) { console.error("targets", id, error.message); out.push({ id, error: error.message }); continue; }

    let sent = 0;
    const dead: string[] = [];
    const list = (targets || []) as { user_id: string; fcm_token: string }[];
    for (let i = 0; i < list.length; i += 25) {
      const chunk = list.slice(i, i + 25);
      const res = await Promise.all(chunk.map((t) =>
        sendOne(fcm, t.fcm_token, id, title, body).catch((e) => `err ${String(e).slice(0, 80)}`)));
      res.forEach((r, k) => {
        if (r === "ok") sent++;
        else if (r === "dead") dead.push(chunk[k].user_id);
        else console.warn("FCM", id, r);
      });
    }
    if (dead.length) await sb.from("users").update({ fcm_token: null }).in("user_id", dead);
    await sb.rpc("app_message_push_done", { p_id: id, p_count: sent });
    console.log(`app-message-push id=${id} targets=${list.length} sent=${sent} dead=${dead.length}`);
    out.push({ id, targets: list.length, sent, dead: dead.length });
  }
  return new Response(JSON.stringify({ ok: true, out }), { headers: { "Content-Type": "application/json" } });
});
