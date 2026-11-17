// Supabase Edge Function: player check-ins for Clontarf Girls 2012 (Féile 2027).
//
//   POST /functions/v1/player-checkins   body: { action: "...", ... }
//
// Two kinds of caller:
//  1. People, with their CoachSmart login: Authorization: Bearer <user JWT>.
//     Used by coachsmart.app/clontarf-gaa/feile27/checkins/ (coaches) and
//     coachsmart.app/clontarf-gaa/feile27/card/ (families). The v3 app can open
//     either page with ?token=<jwt>.
//  2. The team's Google Sheet (tools/player-checkins-sheet/Code.gs): anon key as
//     Bearer plus x-pc-secret: <PC_SHEET_SECRET>. Only sheet_pull / sheet_push.
//
// Who can do what comes from the team's CoachSmart roles (team TEAM_CODE):
//  - Admin (role grade 100+): sees every girl, reviews, publishes, opens any card.
//  - Coach: sees and edits the girls whose Assessor Email is their login email.
//  - Parent: a login linked (user_member_link) to a Player member of the team
//    can open that girl's published card. Nobody else can open a card.
// Families only ever see published_card, the copy made at the last publish.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

const TEAM_CODE = "TMA47A5"; // Clontarf Girls 2012
const CHECK_DATES = ["2027-01-27", "2027-02-10", "2027-02-24", "2027-03-10", "2027-03-24"];
const CODES = ["football", "camogie"];
const PROGRESS: Record<string, string> = { starting: "Just getting started", coming: "Coming on well", nailed: "Nailed it" };

// Words that never go on a card about a u15 girl (see the project's language rule).
const BANNED = [
  "weak", "weakness", "weaker", "poor", "poorly", "bad", "lazy", "fat", "weight", "heavy", "overweight",
  "skinny", "chubby", "unfit", "useless", "terrible", "awful", "lacks", "lacking", "struggles", "worst", "body", "bmi",
];
const BANNED_RE = new RegExp(`\\b(${BANNED.join("|")})\\b`, "gi");

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-pc-secret",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json", "Cache-Control": "no-store" } });
const tidy = (s: unknown) => String(s ?? "").replace(/\s+/g, " ").trim();
const text = (s: unknown, max = 2000) => String(s ?? "").replace(/\r/g, "").trim().slice(0, max);
const lc = (s: unknown) => tidy(s).toLowerCase();
const nameKey = (s: unknown) =>
  tidy(s).normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[’'`.\-]/g, "").replace(/\s+/g, " ").toLowerCase();

function sameSecret(a: string, b: string) {
  if (!a || !b || a.length !== b.length) return false;
  let x = 0;
  for (let i = 0; i < a.length; i++) x |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return x === 0;
}

export function flagged(...parts: unknown[]) {
  const found = new Set<string>();
  parts.forEach((p) => (String(p ?? "").match(BANNED_RE) || []).forEach((w) => found.add(w.toLowerCase())));
  return [...found];
}

function okVideo(u: string) {
  if (!u) return true;
  try { return new URL(u).protocol === "https:"; } catch { return false; }
}
// Help videos: one or more links, kept one per line.
const videoList = (s: unknown) => String(s ?? "").split(/[\s,]+/).map((x) => x.trim()).filter(Boolean);
const videos = (s: unknown) => videoList(s).join("\n");
const badVideos = (s: unknown) => videoList(s).filter((u) => !okVideo(u));
const goodVideos = (s: unknown) => videoList(s).filter(okVideo).join("\n");
// Sheet "Player status": Active / Inactive. Anything else is ignored.
const activeFrom = (s: unknown): boolean | null => {
  const v = lc(s);
  if (v.startsWith("inactive") || v === "no" || v === "n") return false;
  if (v.startsWith("active") || v === "yes" || v === "y") return true;
  return null;
};

type Who = {
  userId: string; emails: string[]; name: string;
  isAdmin: boolean; isCoach: boolean; children: { member_id: number; name: string }[];
};

async function team(sb: SupabaseClient) {
  const { data } = await sb.from("teams").select("team_id, team_name").eq("team_unique_code", TEAM_CODE).maybeSingle();
  if (!data) throw new Error("Team not found");
  return data as { team_id: number; team_name: string };
}

// Team members with their role names, keyed by member_id.
async function roster(sb: SupabaseClient, teamId: number) {
  const { data: links, error } = await sb.from("member_team_link")
    .select("member_team_id, member_id, status, members(first_name, last_name)")
    .eq("team_id", teamId);
  if (error) throw error;
  const live = (links || []).filter((l: any) => l.status !== "deleted");
  const { data: rl } = await sb.from("member_team_role_link")
    .select("member_team_id, roles(role_name, role_grade)")
    .in("member_team_id", live.map((l: any) => l.member_team_id));
  const rolesByLink = new Map<number, { role_name: string; role_grade: number }[]>();
  (rl || []).forEach((r: any) => {
    if (!r.roles) return;
    const a = rolesByLink.get(r.member_team_id) || [];
    a.push(r.roles); rolesByLink.set(r.member_team_id, a);
  });
  const out = new Map<number, { name: string; roles: { role_name: string; role_grade: number }[] }>();
  live.forEach((l: any) => {
    const prev = out.get(l.member_id);
    const roles = [...(prev?.roles || []), ...(rolesByLink.get(l.member_team_id) || [])];
    out.set(l.member_id, { name: tidy(`${l.members?.first_name ?? ""} ${l.members?.last_name ?? ""}`), roles });
  });
  return out;
}

async function whoIs(sb: SupabaseClient, jwt: string, teamId: number): Promise<Who | null> {
  const { data: { user } } = await sb.auth.getUser(jwt);
  if (!user) return null;
  const [{ data: u }, { data: links }] = await Promise.all([
    sb.from("users").select("email_address, first_name, last_name").eq("user_id", user.id).maybeSingle(),
    sb.from("user_member_link").select("member_id, status").eq("user_id", user.id),
  ]);
  const mine = new Set((links || []).filter((l: any) => l.status !== "deleted").map((l: any) => l.member_id));
  const people = await roster(sb, teamId);
  let isAdmin = false, isCoach = false;
  const children: Who["children"] = [];
  people.forEach((p, memberId) => {
    if (!mine.has(memberId)) return;
    if (p.roles.some((r) => r.role_grade >= 100)) { isAdmin = true; isCoach = true; }
    if (p.roles.some((r) => r.role_name === "Coach")) isCoach = true;
    if (p.roles.some((r) => r.role_name === "Player")) children.push({ member_id: memberId, name: p.name });
  });
  const emails = [...new Set([lc(user.email), lc(u?.email_address)].filter(Boolean))];
  return {
    userId: user.id, emails, isAdmin, isCoach, children,
    name: tidy(`${u?.first_name ?? ""} ${u?.last_name ?? ""}`) || emails[0] || "Coach",
  };
}

const isAssessor = (w: Who, a: any) => !!a.assessor_email && w.emails.includes(lc(a.assessor_email));
const canEdit = (w: Who, a: any) => w.isAdmin || isAssessor(w, a);

function card(a: any, checks: any[]) {
  const first = tidy(a.player_name).split(" ")[0];
  return {
    first_name: first,
    code: a.code,
    superpower: a.superpower || "",
    development: a.development || "",
    how: a.how || "",
    video_url: videoList(a.video_url)[0] || "",
    videos: videoList(a.video_url),
    checkins: checks
      .filter((c) => c.note || c.progress)
      .sort((x, y) => x.check_date.localeCompare(y.check_date))
      .map((c) => ({ date: c.check_date, progress: PROGRESS[c.progress] || "", note: c.note || "" })),
  };
}

// The sheet's text for one check-in cell.
const checkText = (c: any) => [PROGRESS[c.progress] || "", c.note || ""].filter(Boolean).join(". ");

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  let body: any;
  try { body = await req.json(); } catch { return json({ error: "Not JSON" }, 400); }
  const action = String(body?.action || "");
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

  try {
    const t = await team(sb);

    // ---------- Google Sheet ----------
    if (action === "sheet_pull" || action === "sheet_push") {
      if (!sameSecret(req.headers.get("x-pc-secret") ?? "", Deno.env.get("PC_SHEET_SECRET") ?? "")) {
        return json({ error: "This sheet is not allowed to sync. Check the PC_SECRET script property." }, 403);
      }
      return action === "sheet_pull" ? await sheetPull(sb, t.team_id) : await sheetPush(sb, t.team_id, body);
    }

    // ---------- People ----------
    const jwt = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
    const w = await whoIs(sb, jwt, t.team_id);
    if (!w) return json({ error: "Please sign in" }, 401);

    if (action === "me") {
      return json({ team: t.team_name, name: w.name, isAdmin: w.isAdmin, isCoach: w.isCoach, children: w.children, checkDates: CHECK_DATES });
    }

    if (action === "card") {
      const memberId = Number(body.member_id) || (w.children.length === 1 ? w.children[0].member_id : 0);
      if (!memberId) return json({ children: w.children, cards: [] });
      if (!w.isAdmin && !w.children.some((c) => c.member_id === memberId)) {
        return json({ error: "This card can only be opened by the girl's parents and the team's admins." }, 403);
      }
      const { data } = await sb.from("pc_assessments").select("code, player_name, published_card, published_at")
        .eq("team_id", t.team_id).eq("member_id", memberId).eq("active", true).not("published_card", "is", null);
      const rows = (data || []).sort((a: any, b: any) => CODES.indexOf(a.code) - CODES.indexOf(b.code));
      return json({
        children: w.children,
        member_id: memberId,
        name: rows[0]?.player_name || w.children.find((c) => c.member_id === memberId)?.name || "",
        cards: rows.map((r: any) => ({ ...r.published_card, published_at: r.published_at })),
      });
    }

    if (!w.isCoach) return json({ error: "Only the team's coaches can open this page." }, 403);

    if (action === "list") {
      const { data, error } = await sb.from("pc_assessments").select("*").eq("team_id", t.team_id).order("player_name");
      if (error) throw error;
      // Inactive players (Player status in the team sheet) stay off the website.
      const mineOrAll = (data || []).filter((a: any) => w.isAdmin || isAssessor(w, a));
      const rows = mineOrAll.filter((a: any) => a.active !== false);
      const { data: checks } = await sb.from("pc_checkins").select("*").in("assessment_id", rows.map((a: any) => a.id));
      const byA = new Map<number, any[]>();
      (checks || []).forEach((c: any) => { const l = byA.get(c.assessment_id) || []; l.push(c); byA.set(c.assessment_id, l); });
      const { data: rel } = await sb.from("pc_releases").select("published_at, published_by, cards")
        .eq("team_id", t.team_id).order("published_at", { ascending: false }).limit(1).maybeSingle();
      return json({
        me: { name: w.name, emails: w.emails, isAdmin: w.isAdmin },
        lastRelease: rel || null,
        inactive: mineOrAll.length - rows.length,
        assessments: rows.map((a: any) => ({
          ...a,
          mine: isAssessor(w, a),
          checkins: byA.get(a.id) || [],
          changed_since_publish: !!a.published_at && new Date(a.updated_at) > new Date(a.published_at),
        })),
      });
    }

    const id = Number(body.id);
    const { data: a } = id
      ? await sb.from("pc_assessments").select("*").eq("id", id).eq("team_id", t.team_id).maybeSingle()
      : { data: null };

    if (action === "save" || action === "submit") {
      if (!a) return json({ error: "Not found" }, 404);
      if (!canEdit(w, a)) return json({ error: "Only her assessor or an admin can change this." }, 403);
      if (action === "submit" && a.status === "review") return json({ error: "This is already with the reviewer." }, 409);
      const patch: any = {};
      for (const k of ["superpower", "development", "how", "video_url", "coach_note"]) {
        if (k in body) patch[k] = k === "video_url" ? videos(body[k]) : text(body[k]);
      }
      if ("video_url" in patch && badVideos(patch.video_url).length) return json({ error: "Each video link must start with https://" }, 400);
      const next = { ...a, ...patch };
      const contentChanged = ["superpower", "development", "how", "video_url"].some((k) => k in patch && (patch[k] || "") !== (a[k] || ""));
      if (action === "submit") {
        if (!next.superpower || !next.development || !next.how) return json({ error: "Fill in Superpower, Development and How first." }, 400);
        const bad = flagged(next.superpower, next.development, next.how);
        if (bad.length) return json({ error: "Please reword before sending", flagged: bad }, 422);
        patch.status = "review";
        patch.review_comment = null;
      } else if (a.status === "todo" || (a.status === "approved" && contentChanged) || (a.status === "review" && contentChanged)) {
        patch.status = "draft";
      }
      patch.updated_by = w.name;
      patch.updated_at = new Date().toISOString();
      const { data: saved, error } = await sb.from("pc_assessments").update(patch).eq("id", a.id).select("*").single();
      if (error) throw error;
      return json({ ok: true, assessment: saved, flagged: flagged(next.superpower, next.development, next.how) });
    }

    if (action === "review") {
      if (!a) return json({ error: "Not found" }, 404);
      if (!w.isAdmin) return json({ error: "Only admins can review." }, 403);
      if (isAssessor(w, a)) return json({ error: "Someone other than her assessor needs to review this one." }, 403);
      if (a.status !== "review") return json({ error: "This one isn't waiting for review." }, 409);
      const approve = body.decision === "approve";
      const comment = text(body.comment, 1000);
      if (!approve && !comment) return json({ error: "Add a comment so the coach knows what to change." }, 400);
      if (approve && flagged(a.superpower, a.development, a.how).length) return json({ error: "The wording check found words to change first." }, 422);
      const { data: saved, error } = await sb.from("pc_assessments").update({
        status: approve ? "approved" : "changes", review_comment: comment || null,
        reviewed_by: w.name, reviewed_at: new Date().toISOString(),
      }).eq("id", a.id).select("*").single();
      if (error) throw error;
      return json({ ok: true, assessment: saved });
    }

    if (action === "checkin") {
      if (!a) return json({ error: "Not found" }, 404);
      if (!canEdit(w, a)) return json({ error: "Only her assessor or an admin can add a check-in." }, 403);
      const date = String(body.date || "");
      if (!CHECK_DATES.includes(date)) return json({ error: "Unknown check-in date" }, 400);
      const progress = PROGRESS[body.progress] ? body.progress : null;
      const note = text(body.note, 1000);
      const bad = flagged(note);
      if (bad.length) return json({ error: "Please reword before saving", flagged: bad }, 422);
      const { data: saved, error } = await sb.from("pc_checkins").upsert({
        assessment_id: a.id, check_date: date, progress, note: note || null, updated_by: w.name, updated_at: new Date().toISOString(),
      }, { onConflict: "assessment_id,check_date" }).select("*").single();
      if (error) throw error;
      await sb.from("pc_assessments").update({ updated_at: new Date().toISOString() }).eq("id", a.id);
      return json({ ok: true, checkin: saved });
    }

    if (action === "publish") {
      if (!w.isAdmin) return json({ error: "Only admins can publish." }, 403);
      const { data: all, error } = await sb.from("pc_assessments").select("*").eq("team_id", t.team_id);
      if (error) throw error;
      const live = (all || []).filter((x: any) => x.active !== false);
      const ready = live.filter((x: any) => x.status === "approved" && x.member_id);
      const { data: checks } = await sb.from("pc_checkins").select("*").in("assessment_id", ready.map((x: any) => x.id));
      const now = new Date().toISOString();
      for (const x of ready) {
        const c = card(x, (checks || []).filter((k: any) => k.assessment_id === x.id));
        const { error: e } = await sb.from("pc_assessments")
          .update({ published_card: c, published_at: now, published_by: w.name }).eq("id", x.id);
        if (e) throw e;
      }
      await sb.from("pc_releases").insert({ team_id: t.team_id, published_by: w.name, cards: ready.length });
      const noLogin = live.filter((x: any) => x.status === "approved" && !x.member_id).map((x: any) => x.player_name);
      return json({
        ok: true, published: ready.length,
        notReady: live.filter((x: any) => x.status !== "approved").length,
        noMatch: [...new Set(noLogin)],
      });
    }

    return json({ error: "Unknown action" }, 400);
  } catch (e) {
    console.error("player-checkins", action, e);
    return json({ error: (e as Error).message || "Something went wrong" }, 500);
  }
});

// Everything the sheet shows, one row per girl per code.
async function sheetPull(sb: SupabaseClient, teamId: number) {
  const { data, error } = await sb.from("pc_assessments").select("*").eq("team_id", teamId);
  if (error) throw error;
  const { data: checks } = await sb.from("pc_checkins").select("*").in("assessment_id", (data || []).map((a: any) => a.id));
  const label: Record<string, string> = { todo: "To do", draft: "Draft", review: "With reviewer", changes: "Change asked", approved: "Approved" };
  return json({
    ok: true,
    checkDates: CHECK_DATES,
    rows: (data || []).map((a: any) => {
      const st = a.published_at && a.status === "approved" && new Date(a.updated_at) <= new Date(a.published_at) ? "Shared with family" : label[a.status];
      const c: Record<string, string> = {};
      (checks || []).filter((k: any) => k.assessment_id === a.id).forEach((k: any) => { c[k.check_date] = checkText(k); });
      return {
        code: a.code, player_name: a.player_name, assessor_name: a.assessor_name || "", assessor_email: a.assessor_email || "",
        superpower: a.superpower || "", development: a.development || "", how: a.how || "", video_url: a.video_url || "",
        player_status: a.active === false ? "Inactive" : "Active",
        status: st, updated_at: a.updated_at, checks: c,
      };
    }),
  });
}

// Rows typed into the sheet. Assignments (assessor) and Player status always apply. Card text and
// check-ins only apply while the card is still with its coach (to do, draft or
// change asked), so nothing changes behind a reviewer's back. Anything skipped
// is reported back to the sheet.
async function sheetPush(sb: SupabaseClient, teamId: number, body: any) {
  const rows: any[] = Array.isArray(body.rows) ? body.rows.slice(0, 400) : [];
  const by = tidy(body.by) ? `Sheet (${tidy(body.by)})` : "Sheet";
  const people = await roster(sb, teamId);
  const players = new Map<string, number>();
  people.forEach((p, id) => { if (p.roles.some((r) => r.role_name === "Player")) players.set(nameKey(p.name), id); });

  const { data: existing } = await sb.from("pc_assessments").select("*").eq("team_id", teamId);
  const have = new Map((existing || []).map((a: any) => [`${a.code}|${nameKey(a.player_name)}`, a]));
  const { data: checks } = await sb.from("pc_checkins").select("*").in("assessment_id", (existing || []).map((a: any) => a.id));

  const out = { created: 0, updated: 0, skipped: [] as string[], unmatched: [] as string[], flagged: [] as string[] };
  const now = new Date().toISOString();

  for (const r of rows) {
    const code = lc(r.code);
    const name = tidy(r.player_name);
    if (!CODES.includes(code) || !name) continue;
    const memberId = players.get(nameKey(name)) ?? null;
    if (!memberId && !out.unmatched.includes(name)) out.unmatched.push(name);
    // The sheet sends only the cells changed there since its last sync (all of them on the first sync).
    const fields: Record<string, string> = {};
    for (const k of ["superpower", "development", "how", "video_url"]) {
      if (k in r) fields[k] = k === "video_url" ? goodVideos(r[k]) : text(r[k]);
    }
    const active = "player_status" in r ? activeFrom(r.player_status) : null;
    let a: any = have.get(`${code}|${nameKey(name)}`);
    if (!a) {
      const hasText = fields.superpower || fields.development || fields.how;
      const { data, error } = await sb.from("pc_assessments").insert({
        team_id: teamId, member_id: memberId, player_name: name, code,
        assessor_name: tidy(r.assessor_name) || null, assessor_email: lc(r.assessor_email) || null,
        ...fields, ...(active === null ? {} : { active }), status: hasText ? "draft" : "todo", updated_by: by, updated_at: now,
      }).select("*").single();
      if (error) throw error;
      a = data; out.created++;
    } else {
      const patch: any = {};
      if ("assessor_name" in r && tidy(r.assessor_name) !== (a.assessor_name || "")) patch.assessor_name = tidy(r.assessor_name) || null;
      if ("assessor_email" in r && lc(r.assessor_email) !== lc(a.assessor_email)) patch.assessor_email = lc(r.assessor_email) || null;
      if (memberId && memberId !== a.member_id) patch.member_id = memberId;
      if (active !== null && active !== (a.active !== false)) patch.active = active;
      const textChanged = Object.keys(fields).filter((k) => fields[k] !== (a[k] || ""));
      if (textChanged.length) {
        if (["todo", "draft", "changes"].includes(a.status)) {
          textChanged.forEach((k) => { patch[k] = fields[k] || null; });
          if (a.status === "todo") patch.status = "draft";
        } else {
          out.skipped.push(`${name} (${code}): card is ${a.status === "review" ? "with the reviewer" : "approved"}, so change it in the app`);
        }
      }
      if (Object.keys(patch).length) {
        patch.updated_by = by; patch.updated_at = now;
        const { error } = await sb.from("pc_assessments").update(patch).eq("id", a.id);
        if (error) throw error;
        out.updated++;
      }
    }
    const bad = flagged(fields.superpower, fields.development, fields.how);
    if (bad.length) out.flagged.push(`${name} (${code}): ${bad.join(", ")}`);

    // Check-in cells: free text from the sheet becomes the note.
    if (["todo", "draft", "changes", "approved"].includes(a.status) && r.checks && typeof r.checks === "object") {
      for (const d of CHECK_DATES) {
        if (!(d in r.checks)) continue;
        const cell = text(r.checks[d], 1000);
        const cur = (checks || []).find((k: any) => k.assessment_id === a.id && k.check_date === d);
        if (cell === (cur ? checkText(cur) : "")) continue;
        if (!cell && !cur) continue;
        const { error } = await sb.from("pc_checkins").upsert({
          assessment_id: a.id, check_date: d, progress: null, note: cell || null, updated_by: by, updated_at: now,
        }, { onConflict: "assessment_id,check_date" });
        if (error) throw error;
      }
    }
  }
  return json({ ok: true, ...out });
}
