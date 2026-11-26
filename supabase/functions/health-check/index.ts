// deno-lint-ignore-file no-explicit-any
// Nightly health check (Ken 2026-11-26).
//
// Woken by the database at 4am Dublin time (health_report_wake). It runs the
// in-database checks (health_collect), adds checks that need GitHub (did the
// deploy workflows on main pass, is every migration on main applied), saves
// the night in health_reports and emails Ken a phone-friendly report:
// Critical, Warning, Planned / known, then KPIs with a 7-day average.
//
// POST { run_date?: "YYYY-MM-DD", test?: boolean }   (service role only)
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

const REPO = "KenDarcy01/coachsmart";
const TO = (Deno.env.get("HEALTH_REPORT_TO") || "ken.darcy@gmail.com").split(",").map((s) => s.trim()).filter(Boolean);

type Finding = { level: "critical" | "warning" | "planned" | "info"; area: string; title: string; detail?: string; link?: string };

function roleOf(req: Request): string {
  try {
    const jwt = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
    const part = jwt.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    return JSON.parse(atob(part + "===".slice((part.length + 3) % 4))).role || "";
  } catch {
    return "";
  }
}

const esc = (s: unknown) =>
  String(s ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]!));

async function gh(path: string): Promise<any> {
  const r = await fetch(`https://api.github.com/repos/${REPO}/${path}`, {
    headers: { "User-Agent": "coachsmart-health-check", Accept: "application/vnd.github+json" },
  });
  if (!r.ok) throw new Error(`GitHub ${r.status}`);
  return r.json();
}

async function githubChecks(migrationsInDb: string[]): Promise<{ findings: Finding[]; kpis: Record<string, unknown> }> {
  const findings: Finding[] = [];
  const kpis: Record<string, unknown> = {};
  // Deploy workflows on main: latest finished run of each, and failures in 24h.
  try {
    const j = await gh("actions/runs?branch=main&per_page=60");
    const runs: any[] = j.workflow_runs || [];
    const since = Date.now() - 24 * 3600 * 1000;
    const latest = new Map<string, any>();
    let deploys24 = 0;
    for (const r of runs) {
      if (r.status !== "completed") continue;
      if (Date.parse(r.created_at) > since) deploys24++;
      if (!latest.has(r.name)) latest.set(r.name, r);
    }
    kpis.deploys_24h = deploys24;
    for (const [name, r] of latest) {
      if (r.conclusion === "failure" || r.conclusion === "timed_out") {
        findings.push({
          level: "warning",
          area: "Code and deploys",
          title: `Last "${name}" run failed`,
          detail: `${r.display_title || ""} (${new Date(r.created_at).toLocaleString("en-IE", { timeZone: "Europe/Dublin" })})`,
          link: r.html_url,
        });
      }
    }
  } catch (e) {
    findings.push({ level: "info", area: "Code and deploys", title: "Couldn't read GitHub deploy runs", detail: String(e) });
  }
  // Migrations on main that the database hasn't applied.
  try {
    const files: any[] = await gh("contents/supabase/migrations?ref=main");
    const inDb = new Set(migrationsInDb);
    const missing = files
      .map((f) => String(f.name))
      .filter((n) => /^\d{14}_.*\.sql$/.test(n) && n.slice(0, 14) >= "20261001" && !inDb.has(n.slice(0, 14)));
    kpis.migrations_on_main = files.length;
    if (missing.length) {
      findings.push({
        level: "critical",
        area: "Code and deploys",
        title: `${missing.length} migration(s) on main not applied`,
        detail: missing.slice(0, 5).join(", ") + ". The Supabase deploy workflow probably failed.",
      });
    }
  } catch (e) {
    findings.push({ level: "info", area: "Code and deploys", title: "Couldn't read migrations from GitHub", detail: String(e) });
  }
  return { findings, kpis };
}

// KPI rows shown in the email: [key, label, format]
const KPI_ROWS: [string, string, ((v: any) => string)?][] = [
  ["active_users_24h", "Active users (24h)"],
  ["active_users_7d", "Active users (7 days)"],
  ["new_users_24h", "New sign-ups"],
  ["users_total", "Users total"],
  ["events_created", "Events created"],
  ["events_today", "Events today"],
  ["attendance_responses", "Attendance responses"],
  ["live_matches", "Live matches scored"],
  ["notifications_sent", "Notifications sent"],
  ["message_pushes", "Message pushes"],
  ["event_payments", "Event payments"],
  ["event_payments_cents", "Event payments €", (v) => (Number(v || 0) / 100).toFixed(2)],
  ["lotto_payments", "Lotto payments"],
  ["lotto_payments_cents", "Lotto €", (v) => (Number(v || 0) / 100).toFixed(2)],
  ["background_call_errors", "Failed cron calls"],
  ["notifications_stuck", "Stuck notifications"],
  ["db_mb", "Database MB"],
  ["db_growth_mb", "Database growth MB"],
  ["db_mb_days_to_cap", "Days until DB passes 8 GB"],
  ["db_busy_pct", "Database busy %"],
  ["background_calls", "Background function calls"],
  ["db_connections_pct", "DB connections %"],
  ["storage_mb", "File storage MB"],
  ["storage_growth_mb", "Storage growth MB"],
  ["storage_mb_days_to_cap", "Days until storage passes 100 GB"],
  ["cron_jobs", "Cron jobs"],
  ["deploys_24h", "Deploys (24h)"],
];

const LEVELS: { key: Finding["level"]; label: string; colour: string; bg: string }[] = [
  { key: "critical", label: "🔴 Critical", colour: "#b42318", bg: "#fef3f2" },
  { key: "warning", label: "🟠 Warning", colour: "#b54708", bg: "#fffaeb" },
  { key: "planned", label: "🔵 Planned / known", colour: "#175cd3", bg: "#eff8ff" },
  { key: "info", label: "ℹ️ Notes", colour: "#475467", bg: "#f9fafb" },
];

function buildEmail(runDate: string, findings: Finding[], kpis: Record<string, any>, history: Record<string, any>[], test: boolean) {
  const crit = findings.filter((f) => f.level === "critical").length;
  const warn = findings.filter((f) => f.level === "warning").length;
  const headline = crit
    ? `🔴 ${crit} critical${warn ? `, ${warn} warning${warn > 1 ? "s" : ""}` : ""}`
    : warn
    ? `🟠 ${warn} warning${warn > 1 ? "s" : ""}`
    : "✅ All good";
  const subject = `${test ? "[Test] " : ""}CoachSmart health ${runDate}: ${headline}`;

  let sections = "";
  for (const L of LEVELS) {
    const list = findings.filter((f) => f.level === L.key);
    if (!list.length) continue;
    sections += `<h2 style="font-size:16px;margin:22px 0 8px;color:${L.colour}">${L.label}</h2>`;
    for (const f of list) {
      sections += `<div style="background:${L.bg};border-left:4px solid ${L.colour};border-radius:8px;padding:10px 12px;margin:0 0 8px">
        <div style="font-size:12px;color:#667085;text-transform:uppercase;letter-spacing:.04em">${esc(f.area)}</div>
        <div style="font-size:15px;font-weight:600;color:#101828;margin-top:2px">${esc(f.title)}</div>
        ${f.detail ? `<div style="font-size:13px;color:#344054;margin-top:4px;white-space:pre-line">${esc(f.detail)}</div>` : ""}
        ${f.link ? `<div style="margin-top:4px"><a href="${esc(f.link)}" style="font-size:13px;color:#175cd3">Open</a></div>` : ""}
      </div>`;
    }
  }

  const avg = (key: string) => {
    const vals = history.map((h) => Number(h?.[key])).filter((v) => Number.isFinite(v));
    return vals.length ? vals.reduce((a, b) => a + b, 0) / vals.length : null;
  };
  let rows = "";
  for (const [key, label, fmt] of KPI_ROWS) {
    if (!(key in kpis)) continue;
    const show = fmt || ((v: any) => String(v ?? "–"));
    const a = avg(key);
    rows += `<tr>
      <td style="padding:6px 4px;border-bottom:1px solid #eaecf0;font-size:14px;color:#344054">${esc(label)}</td>
      <td style="padding:6px 4px;border-bottom:1px solid #eaecf0;font-size:14px;font-weight:600;text-align:right;color:#101828">${esc(show(kpis[key]))}</td>
      <td style="padding:6px 4px;border-bottom:1px solid #eaecf0;font-size:13px;text-align:right;color:#667085">${a === null ? "–" : esc(fmt ? fmt(a) : (Math.round(a * 10) / 10).toString())}</td>
    </tr>`;
  }

  const html = `<!DOCTYPE html><html><body style="margin:0;background:#f2f4f7;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif">
  <div style="max-width:560px;margin:0 auto;padding:16px">
    <div style="background:#14181b;border-radius:12px;padding:16px 18px;color:#f1f4f8">
      <div style="font-size:12px;color:#a1a1a2">CoachSmart nightly health · ${esc(runDate)}${test ? " · test" : ""}</div>
      <div style="font-size:22px;font-weight:700;margin-top:4px">${headline}</div>
    </div>
    <div style="background:#fff;border-radius:12px;padding:4px 16px 16px;margin-top:12px">
      ${sections || `<p style="font-size:14px;color:#344054">Nothing needs attention.</p>`}
    </div>
    <div style="background:#fff;border-radius:12px;padding:12px 16px 16px;margin-top:12px">
      <h2 style="font-size:16px;margin:4px 0 8px;color:#101828">KPIs (last 24 hours)</h2>
      <table style="width:100%;border-collapse:collapse">
        <tr><th style="text-align:left;font-size:12px;color:#667085;padding:4px">Measure</th><th style="text-align:right;font-size:12px;color:#667085;padding:4px">Last night</th><th style="text-align:right;font-size:12px;color:#667085;padding:4px">7-day avg</th></tr>
        ${rows}
      </table>
    </div>
    <p style="font-size:11px;color:#98a2b3;text-align:center;margin-top:12px">Sent by the health-check function at 4am Irish time.</p>
  </div></body></html>`;
  return { subject, html };
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("POST only", { status: 405 });
  if (roleOf(req) !== "service_role") return new Response("Forbidden", { status: 403 });
  const body = await req.json().catch(() => ({}));
  const test = !!body.test;
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  const runDate: string = body.run_date || new Date().toLocaleDateString("en-CA", { timeZone: "Europe/Dublin" });
  const { data: collected, error } = await sb.rpc("health_collect", { p_run_date: runDate });

  let findings: Finding[] = [];
  let kpis: Record<string, any> = {};
  let snapshot: Record<string, any> = {};
  if (error || !collected) {
    findings.push({ level: "critical", area: "Health check", title: "The database checks failed to run", detail: error?.message || "No result" });
  } else {
    findings = collected.findings || [];
    kpis = collected.kpis || {};
    snapshot = collected.snapshot || {};
  }

  const g = await githubChecks((snapshot.migrations || []) as string[]);
  findings.push(...g.findings);
  Object.assign(kpis, g.kpis);

  const { data: hist } = await sb.from("health_reports").select("kpis").lt("run_date", runDate)
    .order("run_date", { ascending: false }).limit(7);
  const history = (hist || []).map((h: any) => h.kpis || {});

  await sb.from("health_reports").upsert({ run_date: runDate, kpis, findings, snapshot });

  const { subject, html } = buildEmail(runDate, findings, kpis, history, test);
  const r = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${Deno.env.get("RESEND_API_KEY")}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from: "CoachSmart Health <noreply@coachsmart.app>", to: TO, subject, html }),
  });
  const sent = r.ok;
  if (sent) await sb.from("health_reports").update({ sent_at: new Date().toISOString(), sent_to: TO.join(",") }).eq("run_date", runDate);
  else console.error("health-check: Resend failed", r.status, await r.text());

  return new Response(JSON.stringify({ ok: sent, subject, findings: findings.length }), {
    status: sent ? 200 : 502,
    headers: { "Content-Type": "application/json" },
  });
});
