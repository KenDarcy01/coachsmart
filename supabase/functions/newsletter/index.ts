// deno-lint-ignore-file no-explicit-any
// newsletter (2026-11-25, thread "Build The Tarbh Times club newsletter").
// Weekly newspaper-style club newsletter. Club officers with the newsletter
// tick (and super users) use coachsmart.app/club/newsletter.html?club=ID:
// this function suggests the week's stories, saves their edits and order,
// stores photos and the built PDF, and approves the issue. Approved issues
// are read without signing in at coachsmart.app/club/news.html?i=<token>.
//
// Ken's rules for every story (also given to the AI writer):
// - The audience is club members: positive language only.
// - Wins are told with their score. Losses are left out, except semi-finals
//   and finals: 3 points or less shows the score and says it was close; a
//   bigger loss shows no score ("runners-up", "reached the semi-final").
//   Never "hammered" or anything like it.
// - Competitions are named exactly as in the results data; never add labels
//   such as "county final" yourself.
// - Hurling and camogie never say "kick".
// - Never mention the lotto, payments or car pooling.
// Results come from gaa_games only (never Sportlomo).
//
// POST { action, ... }:
//   public    { token }                       (no sign-in) approved issue
//   club      { club_id }                     club, settings, issues
//   open      { club_id, week_start? }        issue for a week (suggests on first open)
//   get       { club_id, issue_id }
//   resuggest { club_id, issue_id }           redo suggestions, keeps edited stories
//   save      { club_id, story }              headline/deck/body/kicker/placement/included
//   order     { club_id, issue_id, items:[{story_id, included}] }
//   add       { club_id, issue_id }           blank story of your own
//   remove    { club_id, story_id }           only stories of your own
//   photo     { club_id, story_id, image (base64), mime } / { ..., clear: true }
//   rewrite   { club_id, story_id }           AI writes it again
//   build     { club_id, issue_id, pdf (base64) }
//   approve   { club_id, issue_id }
//   reopen    { club_id, issue_id }
//   settings  { club_id, settings: { title, strap, website_url, standing? } }
//   delete_issue { club_id, issue_id }  draft or built issues only
//   standing_photo { club_id, image (base64), mime }   photo for an "every issue" item
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Anthropic from "npm:@anthropic-ai/sdk";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...cors, "Content-Type": "application/json" } });
const ok = (data: unknown) => json({ success: true, data });
const fail = (error: string, status = 400) => json({ success: false, error }, status);

const BUCKET = "newsletter";
const PUBLIC = "https://gyfporsbdftvtakdvukt.supabase.co/storage/v1/object/public/" + BUCKET + "/";
const MODEL = Deno.env.get("NEWSLETTER_MODEL") || "claude-haiku-4-5-20251001";
const CLOSE = 3; // points: a semi-final or final lost by this or less is "close"

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (req.method !== "POST") return fail("Method not allowed", 405);
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

  let body: any = {};
  try { body = await req.json(); } catch (_) { /* empty */ }
  const a = String(body.action || "");

  if (a === "public") {
    try { return ok(await publicIssue(sb, String(body.token || ""))); }
    catch (e) { return fail((e as Error).message, 404); }
  }

  const auth = req.headers.get("Authorization") || "";
  const { data: u } = await sb.auth.getUser(auth.replace(/^Bearer\s+/i, ""));
  const user = u?.user;
  if (!user) return fail("Please sign in again.", 401);
  const clubId = Number(body.club_id) || 0;
  if (!clubId) return fail("Open this page from your club's link.");
  const { data: can, error: canErr } = await sb.rpc("newsletter_can_manage", { p_uid: user.id, p_club: clubId });
  if (canErr) return fail("Couldn't check your access. Please try again.", 500);
  if (!can) return fail("The newsletter is for club officers who have been given access.", 403);

  try {
    switch (a) {
      case "club": return ok(await clubData(sb, clubId));
      case "open": return ok(await openWeek(sb, clubId, String(body.week_start || "")));
      case "get": return ok(await issueData(sb, await issueOf(sb, clubId, body.issue_id)));
      case "resuggest": {
        const iss = await issueOf(sb, clubId, body.issue_id);
        // Remember photos first: the club site's feed only shows recent posts,
        // so a photo found last time may not be found again.
        const { data: old } = await sb.from("newsletter_stories").select("data, photo_path").eq("issue_id", iss.issue_id).eq("edited", false).neq("kind", "custom");
        const prior: Record<string, any> = {};
        for (const o of old || []) if (o.data?.home && o.photo_path) prior[gameKey(o.data)] = { image: o.data.image, photo_path: o.photo_path };
        await sb.from("newsletter_stories").delete().eq("issue_id", iss.issue_id).eq("edited", false).neq("kind", "custom");
        await suggest(sb, iss, prior);
        return ok(await issueData(sb, await draft(sb, iss)));
      }
      case "save": return ok(await saveStory(sb, clubId, body.story || {}));
      case "order": return ok(await order(sb, clubId, body));
      case "add": {
        const iss = await draft(sb, await issueOf(sb, clubId, body.issue_id));
        const { data: mx } = await sb.from("newsletter_stories").select("position").eq("issue_id", iss.issue_id).order("position", { ascending: false }).limit(1);
        const { data, error } = await sb.from("newsletter_stories").insert({
          issue_id: iss.issue_id, kind: "custom", source: "you", headline: "", body: "", placement: "story",
          included: true, position: (mx?.[0]?.position ?? 0) + 1, edited: true,
        }).select().single();
        if (error) throw error;
        return ok(withUrl(data));
      }
      case "remove": {
        const st = await storyOf(sb, clubId, body.story_id);
        if (st.kind !== "custom") throw new Error("Only stories you wrote can be deleted. Untick the others instead.");
        await draft(sb, { issue_id: st.issue_id });
        await sb.from("newsletter_stories").delete().eq("story_id", st.story_id);
        return ok(true);
      }
      case "photo": return ok(await photo(sb, clubId, body));
      case "rewrite": return ok(await rewrite(sb, clubId, body.story_id));
      case "build": return ok(await build(sb, clubId, body, user.id));
      case "approve": {
        const iss = await issueOf(sb, clubId, body.issue_id);
        if (iss.status !== "built" || !iss.pdf_path) throw new Error("Build the issue before approving it.");
        await sb.from("newsletter_issues").update({ status: "approved", approved_at: new Date().toISOString(), approved_by: user.id, updated_at: new Date().toISOString() }).eq("issue_id", iss.issue_id);
        return ok(await issueData(sb, await issueOf(sb, clubId, iss.issue_id)));
      }
      case "delete_issue": {
        const iss = await issueOf(sb, clubId, body.issue_id);
        if (iss.status === "approved") throw new Error("Approved issues can't be deleted. Tap Make changes first.");
        await sb.from("newsletter_issues").delete().eq("issue_id", iss.issue_id);
        return ok(await clubData(sb, clubId));
      }
      case "reopen": return ok(await issueData(sb, await draft(sb, await issueOf(sb, clubId, body.issue_id))));
      case "settings": {
        const s = body.settings || {};
        const title = clip(s.title, 60);
        if (!title) throw new Error("Give the newsletter a name.");
        let site = clip(s.website_url, 200) || null;
        if (site && !/^https:\/\/[^\s/]+\.[^\s]+$/i.test(site)) throw new Error("The website should start with https://");
        if (site) site = site.replace(/\/+$/, "");
        const row: any = { club_id: clubId, title, strap: clip(s.strap, 120) || null, website_url: site, updated_at: new Date().toISOString() };
        if (Array.isArray(s.standing)) row.standing = cleanStanding(s.standing, clubId);
        await sb.from("newsletter_settings").upsert(row);
        if (row.standing) {
          // New "every issue" items also go into issues still in draft.
          const { data: drafts } = await sb.from("newsletter_issues").select("*").eq("club_id", clubId).eq("status", "draft");
          for (const iss of drafts || []) await addStanding(sb, iss, row.standing);
        }
        return ok(await clubData(sb, clubId));
      }
      case "standing_photo": {
        const path = await uploadImage(sb, `${clubId}/standing`, body);
        return ok({ photo_path: path, photo_url: PUBLIC + path });
      }
    }
    return fail("Unknown action.");
  } catch (e) {
    console.error(e);
    return fail((e as Error).message || "Something went wrong.", 400);
  }
});

// ── helpers ─────────────────────────────────────────────────────────────
function clip(v: any, n: number) { const s = String(v ?? "").trim(); return s ? s.slice(0, n) : ""; }
function dublinDate(d = new Date()) { return d.toLocaleDateString("en-CA", { timeZone: "Europe/Dublin" }); }
function addDays(day: string, n: number) { const d = new Date(day + "T12:00:00Z"); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10); }
function mondayOf(day: string) { const d = new Date(day + "T12:00:00Z"); const w = (d.getUTCDay() + 6) % 7; return addDays(day, -w); }
const lastWeekStart = () => addDays(mondayOf(dublinDate()), -7);
const withUrl = (s: any) => ({ ...s, photo_url: s.photo_path ? PUBLIC + s.photo_path : "" });
const DAY = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
function dublinParts(iso: string) {
  const d = new Date(iso);
  const day = dublinDate(d);
  const time = d.toLocaleTimeString("en-GB", { timeZone: "Europe/Dublin", hour: "2-digit", minute: "2-digit" });
  return { day, dow: DAY[new Date(day + "T12:00:00Z").getUTCDay()], time };
}
function niceTime(t: string) {
  const [h, m] = t.split(":").map(Number);
  const hh = h % 12 || 12;
  return hh + (m ? "." + String(m).padStart(2, "0") : "") + (h < 12 ? "am" : "pm");
}

async function settingsOf(sb: any, clubId: number, club: any) {
  const { data } = await sb.from("newsletter_settings").select("*").eq("club_id", clubId).maybeSingle();
  const short = String(club.club_name || "Club").replace(/\s+(GAA|CLG|GFC|HC|LGFC)$/i, "");
  return data || { club_id: clubId, title: `The ${short} Times`, strap: `The week at ${club.club_name}`, website_url: null, first_issue_no: 1 };
}

async function clubRow(sb: any, clubId: number) {
  const { data: club } = await sb.from("clubs")
    .select("club_id, club_name, club_name_translated, crest, primary_colour, secondary_colour, third_colour, gaa_club_id").eq("club_id", clubId).maybeSingle();
  if (!club) throw new Error("Club not found.");
  return club;
}

async function clubData(sb: any, clubId: number) {
  const club = await clubRow(sb, clubId);
  const settings = await settingsOf(sb, clubId, club);
  const { data: issues } = await sb.from("newsletter_issues")
    .select("issue_id, week_start, week_end, issue_no, status, title, pdf_path, share_token, built_at, approved_at")
    .eq("club_id", clubId).order("week_start", { ascending: false }).limit(60);
  const ids = (issues || []).map((i: any) => i.issue_id);
  const leads: Record<number, string> = {};
  if (ids.length) {
    const { data: ls } = await sb.from("newsletter_stories").select("issue_id, headline").in("issue_id", ids).eq("placement", "lead").eq("included", true);
    for (const l of ls || []) leads[l.issue_id] = l.headline;
  }
  return {
    club, settings, last_week: lastWeekStart(),
    issues: (issues || []).map((i: any) => ({ ...i, lead: leads[i.issue_id] || "", pdf_url: i.pdf_path ? PUBLIC + i.pdf_path : "" })),
  };
}

async function issueOf(sb: any, clubId: number, id: any) {
  const { data } = await sb.from("newsletter_issues").select("*").eq("issue_id", Number(id) || 0).eq("club_id", clubId).maybeSingle();
  if (!data) throw new Error("Issue not found.");
  return data;
}
async function storyOf(sb: any, clubId: number, id: any) {
  const { data } = await sb.from("newsletter_stories").select("*, newsletter_issues!inner(club_id)").eq("story_id", Number(id) || 0).maybeSingle();
  if (!data || data.newsletter_issues.club_id !== clubId) throw new Error("Story not found.");
  delete data.newsletter_issues;
  return data;
}
// Game ids can change when the results are re-synced, so match a game by
// its teams and day.
const gameKey = (d: any) => `${d.home}|${d.away}|${d.day}`;

async function uploadImage(sb: any, folder: string, body: any) {
  const b64 = String(body.image || "").replace(/^data:[^,]+,/, "");
  if (!b64 || b64.length > 6_000_000) throw new Error("That photo is too big. Try a smaller one.");
  const mime = ["image/jpeg", "image/png", "image/webp"].includes(body.mime) ? body.mime : "image/jpeg";
  const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  const path = `${folder}/${crypto.randomUUID()}.${mime.split("/")[1].replace("jpeg", "jpg")}`;
  const { error } = await sb.storage.from(BUCKET).upload(path, bytes, { contentType: mime });
  if (error) throw error;
  return path;
}

// "In every issue" items (settings.standing).
function cleanStanding(list: any[], clubId: number) {
  return list.slice(0, 12).map((x: any) => ({
    id: /^[a-z0-9-]{6,40}$/i.test(String(x.id || "")) ? String(x.id) : crypto.randomUUID(),
    kicker: clip(x.kicker, 120) || "",
    headline: clip(x.headline, 120) || "",
    body: clip(x.body, 4000) || "",
    placement: x.placement === "story" ? "story" : "short",
    photo_path: typeof x.photo_path === "string" && x.photo_path.startsWith(`${clubId}/standing/`) ? x.photo_path : null,
    active: x.active !== false,
  })).filter((x: any) => x.headline || x.body);
}
async function addStanding(sb: any, iss: any, standing?: any[]) {
  if (!standing) {
    const { data } = await sb.from("newsletter_settings").select("standing").eq("club_id", iss.club_id).maybeSingle();
    standing = data?.standing || [];
  }
  const items = (standing || []).filter((x: any) => x.active);
  if (!items.length) return;
  const { data: have } = await sb.from("newsletter_stories").select("kind, data, position").eq("issue_id", iss.issue_id);
  const got = new Set((have || []).filter((h: any) => h.kind === "standing").map((h: any) => h.data?.standing_id));
  const rows = items.filter((x: any) => !got.has(x.id));
  if (!rows.length) return;
  // Just before the fixtures box (fixtures stay last).
  const fx = (have || []).filter((h: any) => h.kind === "fixtures").map((h: any) => h.position);
  const nonFx = (have || []).filter((h: any) => h.kind !== "fixtures").map((h: any) => h.position || 0);
  let pos = Math.max(0, ...nonFx);
  if (fx.length) {
    for (const f of fx) await sb.from("newsletter_stories").update({ position: f + rows.length }).eq("issue_id", iss.issue_id).eq("kind", "fixtures").eq("position", f);
  }
  const { error } = await sb.from("newsletter_stories").insert(rows.map((x: any) => ({
    issue_id: iss.issue_id, kind: "standing", source: "standing", kicker: x.kicker || null, headline: x.headline, body: x.body,
    placement: x.placement, included: true, position: ++pos, photo_path: x.photo_path, data: { standing_id: x.id },
  })));
  if (error) throw error;
}

// Any change after a build sends the issue back to draft (its PDF is stale).
async function draft(sb: any, iss: any) {
  if (iss.status && iss.status === "draft") return iss;
  const { data } = await sb.from("newsletter_issues").update({ status: "draft", approved_at: null, approved_by: null, updated_at: new Date().toISOString() })
    .eq("issue_id", iss.issue_id).neq("status", "draft").select().maybeSingle();
  return data || iss;
}

async function issueData(sb: any, iss: any) {
  const club = await clubRow(sb, iss.club_id);
  const settings = await settingsOf(sb, iss.club_id, club);
  const { data: stories } = await sb.from("newsletter_stories").select("*").eq("issue_id", iss.issue_id).order("position");
  return { club, settings, issue: { ...iss, pdf_url: iss.pdf_path ? PUBLIC + iss.pdf_path : "" }, stories: (stories || []).map(withUrl) };
}

async function publicIssue(sb: any, token: string) {
  if (!/^[0-9a-f-]{36}$/i.test(token)) throw new Error("Issue not found.");
  const { data: iss } = await sb.from("newsletter_issues").select("*").eq("share_token", token).eq("status", "approved").maybeSingle();
  if (!iss) throw new Error("Issue not found.");
  const d = await issueData(sb, iss);
  const { club } = d;
  return {
    club: { club_name: club.club_name, crest: club.crest, primary_colour: club.primary_colour, secondary_colour: club.secondary_colour, third_colour: club.third_colour },
    settings: { title: d.settings.title, strap: d.settings.strap },
    issue: { issue_no: iss.issue_no, week_start: iss.week_start, week_end: iss.week_end, title: iss.title, pdf_url: d.issue.pdf_url },
    stories: d.stories.filter((s: any) => s.included).map((s: any) => ({
      kind: s.kind, kicker: s.kicker, headline: s.headline, deck: s.deck, body: s.body, placement: s.placement, photo_url: s.photo_url, data: s.data,
    })),
  };
}

async function openWeek(sb: any, clubId: number, weekIn: string) {
  const ws = /^\d{4}-\d{2}-\d{2}$/.test(weekIn) ? mondayOf(weekIn) : lastWeekStart();
  const { data: found } = await sb.from("newsletter_issues").select("*").eq("club_id", clubId).eq("week_start", ws).maybeSingle();
  if (found) return issueData(sb, found);
  const club = await clubRow(sb, clubId);
  const settings = await settingsOf(sb, clubId, club);
  const { count } = await sb.from("newsletter_issues").select("issue_id", { count: "exact", head: true }).eq("club_id", clubId).lt("week_start", ws);
  const { data: iss, error } = await sb.from("newsletter_issues").insert({
    club_id: clubId, week_start: ws, week_end: addDays(ws, 6), issue_no: (settings.first_issue_no || 1) + (count || 0), title: settings.title,
  }).select().single();
  if (error) {
    const { data: again } = await sb.from("newsletter_issues").select("*").eq("club_id", clubId).eq("week_start", ws).maybeSingle();
    if (again) return issueData(sb, again);
    throw error;
  }
  await suggest(sb, iss);
  return issueData(sb, iss);
}

// ── suggestions ─────────────────────────────────────────────────────────
const CODE: Record<string, string> = { "Football": "Football", "Hurling": "Hurling", "Camogie": "Camogie", "Ladies Football": "Ladies Football" };
function roundOf(note: string, grade: string) {
  const s = `${note || ""} ${grade || ""}`;
  if (/\b(s\/f|semi[\s-]?final)/i.test(s)) return "Semi-Final";
  if (/\b(q\/f|quarter[\s-]?final)/i.test(s)) return "Quarter-Final";
  if (/\bfinal\b/i.test(s)) {
    const m = /\b(shield|cup|plate|bowl|trophy|champ\w*|league)\s+final\b/i.exec(note || "");
    return m ? m[1][0].toUpperCase() + m[1].slice(1).toLowerCase().replace(/^champ$/, "Championship") + " Final" : "Final";
  }
  return "";
}
function compLabel(c: any) {
  const age = c?.age ? String(c.age) : "";
  const code = CODE[c?.code] || c?.code || "";
  return [age, code].filter(Boolean).join(" ");
}

async function gamesFor(sb: any, gid: number, from: string, to: string) {
  const { data: games } = await sb.from("gaa_games").select("*")
    .gte("start_at", from + "T00:00:00Z").lt("start_at", addDays(to, 1) + "T03:00:00Z")
    .or(`home_club_id.eq.${gid},away_club_id.eq.${gid}`).order("start_at");
  const compIds = [...new Set((games || []).map((g: any) => String(g.comp_id)))];
  const comps: Record<string, any> = {};
  if (compIds.length) {
    const { data: cs } = await sb.from("gaa_competitions").select("comp_id, name, code, age, grade, level").in("comp_id", compIds);
    for (const c of cs || []) comps[String(c.comp_id)] = c;
  }
  return (games || []).filter((g: any) => {
    const p = dublinParts(g.start_at).day;
    return p >= from && p <= to;
  }).map((g: any) => {
    const c = comps[String(g.comp_id)] || { code: g.code };
    const home = g.home_club_id === gid;
    const p = dublinParts(g.start_at);
    return {
      g, c, home, p,
      us: home ? g.home_pts : g.away_pts, them: home ? g.away_pts : g.home_pts,
      opp: home ? g.away_team : g.home_team,
      label: compLabel(c), grade: c.grade || c.name || "", round: roundOf(g.note, c.grade || ""),
      ccc1: c.level === "ccc1",
    };
  });
}

function scoreData(x: any, show: boolean) {
  const g = x.g;
  return {
    home: g.home_team, away: g.away_team, home_score: g.home_score, away_score: g.away_score,
    us: x.home ? "home" : "away", show_score: show, code: x.c.code || g.code, age: x.c.age || "",
    competition: x.grade, round: x.round, day: x.p.day, dow: x.p.dow, time: niceTime(x.p.time), venue: g.venue || "",
    margin: Math.abs((x.us ?? 0) - (x.them ?? 0)),
  };
}

async function siteNews(site: string, from: string, to: string) {
  const out: any[] = [];
  if (!site) return out;
  const lo = new Date(addDays(from, -1) + "T00:00:00Z").getTime();
  const hi = new Date(addDays(to, 1) + "T12:00:00Z").getTime();
  try {
    const r = await fetch(site + "/news?format=json", { headers: { "User-Agent": "CoachSmart newsletter" }, signal: AbortSignal.timeout(8000) });
    if (r.ok) {
      const j = await r.json();
      for (const it of j.items || []) {
        if (!(it.publishOn >= lo && it.publishOn <= hi)) continue;
        const text = String(it.body || it.excerpt || "").replace(/<style[\s\S]*?<\/style>|<script[\s\S]*?<\/script>/gi, " ")
          .replace(/<[^>]+>/g, " ").replace(/&nbsp;/g, " ").replace(/&amp;/g, "&").replace(/&rsquo;|&#39;/g, "'").replace(/&[a-z]+;/g, " ").replace(/\s+/g, " ").trim();
        out.push({ source: "website", title: it.title, text: text.slice(0, 2500), url: site + (it.fullUrl || ""), image: it.assetUrl || "", at: it.publishOn });
      }
    }
  } catch (e) { console.error("news", e); }
  try {
    const r = await fetch(site + "/", { headers: { "User-Agent": "CoachSmart newsletter" }, signal: AbortSignal.timeout(8000) });
    if (r.ok) {
      const h = await r.text();
      const i = h.indexOf("instagram-block");
      const part = i >= 0 ? h.slice(i, i + 200000) : "";
      const re = /data-description="([^"]*)"[\s\S]*?(https:\/\/images\.squarespace-cdn\.com\/content\/v1\/[^/"]+\/(\d{13})-[^"\s]+)/g;
      const seen = new Set<string>();
      let m: RegExpExecArray | null;
      while ((m = re.exec(part))) {
        const at = Number(m[3]);
        const text = m[1].replace(/&amp;/g, "&").replace(/&rsquo;|&#39;/g, "'").replace(/&quot;/g, '"').replace(/&[a-z]+;/g, " ").trim();
        if (!text || seen.has(text) || !(at >= lo && at <= hi)) continue;
        seen.add(text);
        if (/\blott(o|ery)\b|jackpot|car ?pool|payment/i.test(text)) continue; // Ken: never publicly
        out.push({ source: "instagram", title: "", text: text.slice(0, 1500), url: site, image: m[2].split("?")[0], at });
      }
    }
  } catch (e) { console.error("instagram", e); }
  return out;
}

async function copyPhoto(sb: any, url: string, clubId: number, issueId: number) {
  try {
    const r = await fetch(url + "?format=1000w", { signal: AbortSignal.timeout(8000) });
    if (!r.ok) return null;
    const type = r.headers.get("content-type") || "image/jpeg";
    if (!/^image\//.test(type)) return null;
    const bytes = new Uint8Array(await r.arrayBuffer());
    if (bytes.length > 4_000_000) return null;
    const path = `${clubId}/${issueId}/${crypto.randomUUID()}.${type.includes("png") ? "png" : "jpg"}`;
    const { error } = await sb.storage.from(BUCKET).upload(path, bytes, { contentType: type });
    return error ? null : path;
  } catch (_) { return null; }
}

async function suggest(sb: any, iss: any, prior: Record<string, any> = {}) {
  const club = await clubRow(sb, iss.club_id);
  const settings = await settingsOf(sb, iss.club_id, club);
  const gid = Number(club.gaa_club_id) || 0;
  const from = iss.week_start, to = iss.week_end;
  const week = gid ? await gamesFor(sb, gid, from, to) : [];
  const next = gid ? await gamesFor(sb, gid, addDays(to, 1), addDays(to, 7)) : [];
  const news = await siteNews(settings.website_url || "", from, to);

  const { data: kept } = await sb.from("newsletter_stories").select("kind, data, placement, position").eq("issue_id", iss.issue_id);
  const keptGames = new Set((kept || []).filter((k: any) => k.data?.home).map((k: any) => gameKey(k.data)));
  const keptImages = new Set((kept || []).map((k: any) => k.data?.image).filter(Boolean));
  const hasLead = (kept || []).some((k: any) => k.placement === "lead");

  const played = week.filter((x) => x.g.status === "result" && !x.ccc1 && x.us != null && x.them != null);
  const wins = played.filter((x) => x.us > x.them);
  const rank = (x: any) => (x.round.includes("Final") && x.round !== "Semi-Final" && x.round !== "Quarter-Final" ? 300 : x.round === "Semi-Final" ? 200 : x.round ? 150 : 100)
    + (x.us - x.them <= 2 ? 20 : Math.min(x.us - x.them, 15));
  wins.sort((a, b) => rank(b) - rank(a));
  const ko = played.filter((x) => x.us < x.them && (x.round === "Semi-Final" || /Final$/.test(x.round) && x.round !== "Quarter-Final"));

  const items: any[] = [];
  wins.forEach((x, i) => {
    if (keptGames.has(gameKey(scoreData(x, true)))) return;
    items.push({
      kind: "win", source: "results", placement: i === 0 && !hasLead ? "lead" : "story", included: i < 3,
      kicker: `${x.label} · ${x.grade}${x.round ? " · " + x.round : ""}`,
      data: { ...scoreData(x, true), game_id: x.g.game_id, result: "win" },
    });
  });
  if (wins.length >= 2) {
    items.push({
      kind: "wins_box", source: "results", placement: "story", included: true, headline: "Big Wins This Week",
      data: { rows: wins.map((x) => ({ label: `${x.label} · ${x.grade}${x.round ? " " + x.round : ""}`, ...scoreData(x, true) })) },
    });
  }
  for (const x of ko) {
    if (keptGames.has(gameKey(scoreData(x, true)))) continue;
    const close = x.them - x.us <= CLOSE;
    items.push({
      kind: "final", source: "results", placement: "story", included: true,
      kicker: `${x.label} · ${x.grade} · ${x.round}`,
      data: { ...scoreData(x, close), game_id: x.g.game_id, result: close ? "close" : "runners_up" },
    });
  }
  const go = week.filter((x) => x.ccc1);
  if (go.length) {
    const by: Record<string, number> = {};
    for (const x of go) { const k = `${x.c.age || ""} ${CODE[x.c.code] || x.c.code || ""}`.trim(); by[k] = (by[k] || 0) + 1; }
    items.push({ kind: "go_games", source: "results", placement: "short", included: false, kicker: "Go Games", data: { count: go.length, groups: by } });
  }
  // A club post about a game we already have (both scores in its text) gives
  // that story its photo instead of becoming a second story.
  for (const n of news) {
    const twin = items.find((it) => (it.kind === "win" || it.kind === "final") && it.data.home_score && it.data.away_score
      && n.text.includes(it.data.home_score) && n.text.includes(it.data.away_score));
    if (twin) { if (n.image && !twin.data.image) twin.data.image = n.image; n.used = true; }
    else if ((kept || []).some((k: any) => k.data?.home_score && k.data?.away_score && n.text.includes(k.data.home_score) && n.text.includes(k.data.away_score))) n.used = true;
  }
  for (const n of news) {
    if (n.used || (n.image && keptImages.has(n.image))) continue;
    items.push({
      kind: "club_news", source: n.source, placement: "story", included: true,
      kicker: n.source === "website" ? "Club news" : "From the club",
      data: { title: n.title, text: n.text, url: n.url, image: n.image, at: n.at },
    });
  }
  const fx = next.filter((x) => x.g.status !== "result" && !x.ccc1);
  if (fx.length) {
    items.push({
      kind: "fixtures", source: "results", placement: "story", included: true, headline: "Coming Up This Week",
      data: { rows: fx.map((x) => ({ label: x.label, ...scoreData(x, false), final: /Final$/.test(x.round) && !["Quarter-Final", "Semi-Final"].includes(x.round), semi: x.round === "Semi-Final" })) },
    });
  }

  // The writer fills headline/deck/body for each story.
  const written = await writeAll(settings, club, items);
  const rows: any[] = [];
  for (let i = 0; i < items.length; i++) {
    const it = items[i];
    const w = written[i] || fallback(it);
    let photo_path: string | null = null;
    const was = it.data.home ? prior[gameKey(it.data)] : null;
    if (was && (!it.data.image || it.data.image === was.image)) { photo_path = was.photo_path; if (was.image) it.data.image = was.image; }
    else if (it.data.image) photo_path = await copyPhoto(sb, it.data.image, iss.club_id, iss.issue_id);
    rows.push({
      issue_id: iss.issue_id, kind: it.kind, source: it.source, kicker: it.kicker || w.kicker || null,
      headline: it.headline || w.headline || "", deck: it.placement === "lead" ? (w.deck || null) : null, body: w.body || "",
      placement: it.placement, included: it.included, position: 0, data: it.data, photo_path,
    });
  }
  // Order: lead, wins box, other wins, finals, club news, go games, fixtures (fixtures last).
  const ordr: Record<string, number> = { lead: 0, wins_box: 1, win: 2, final: 3, club_news: 4, go_games: 5, fixtures: 9 };
  rows.sort((a, b) => (a.placement === "lead" ? 0 : ordr[a.kind] ?? 6) - (b.placement === "lead" ? 0 : ordr[b.kind] ?? 6));
  const base = Math.max(0, ...(kept || []).map((k: any) => k.position || 0));
  rows.forEach((r, i) => r.position = base + i + 1);
  if (rows.length) {
    const { error } = await sb.from("newsletter_stories").insert(rows);
    if (error) throw error;
  }
  await addStanding(sb, iss);
  await sb.from("newsletter_issues").update({ suggested_at: new Date().toISOString(), updated_at: new Date().toISOString() }).eq("issue_id", iss.issue_id);
}

// ── writing ─────────────────────────────────────────────────────────────
const RULES = `You write stories for a GAA club's weekly members' newsletter, styled like a local newspaper, in Irish English.
Rules (never break them):
- The readers are club members, parents and players. Positive, warm, proud language only.
- Use only the facts given. Never invent scorers, players' names, weather, crowd sizes, quotes, minutes or moments of play.
- Never name children or under-18 players, even if a name appears in the facts; talk about the team ("our U14 girls").
- Name competitions exactly as given in the facts. Never call a game a "county final" unless the competition name says so.
- Hurling and camogie: never use the word "kick" or football terms. Ladies football and football: fine.
- Wins: give the score as given (e.g. 2-16 to 1-18, our score first).
- result "close" (a semi-final or final lost narrowly): give the score and say how close it was, praise the effort, never dwell on losing.
- result "runners_up" (a bigger semi-final or final loss): NEVER give the score or margin. Celebrate reaching the semi-final or final and the season; you may say the other team "took the honours on the day".
- Never use words like hammered, thrashed, beaten heavily, defeat, disappointing.
- Never mention the lotto, payments, money, fees or car pooling.
- Club news / social posts: rewrite them as a short newspaper item; keep any dates, times and places exactly. Do not include hashtags or emoji.
- A short Irish phrase now and then is welcome (Comhghairdeas, Maith sibh, Ar aghaidh linn), not in every story.
Lengths: lead story headline 2-6 words with a deck (one sentence) and a body of two short paragraphs (70-110 words). Other stories: headline 3-8 words, body 40-70 words, one paragraph. Go Games: headline and 25-45 words. Fixtures and wins box need no body.
Separate paragraphs in a body with a blank line.`;

function factsFor(it: any) {
  const d = it.data || {};
  if (it.kind === "win" || it.kind === "final") {
    const ours = d.us === "home" ? d.home_score : d.away_score, theirs = d.us === "home" ? d.away_score : d.home_score;
    const opp = d.us === "home" ? d.away : d.home;
    return { type: it.kind === "win" ? "win" : d.result, placement: it.placement, competition: `${d.age} ${d.code} · ${d.competition}${d.round ? " · " + d.round : ""}`,
      opponent: opp, our_score: d.show_score ? ours : undefined, their_score: d.show_score ? theirs : undefined,
      margin_points: d.show_score ? d.margin : undefined, home_or_away: d.us === "home" ? "home" : "away", day: `${d.dow} ${d.day}`, venue: d.venue };
  }
  if (it.kind === "go_games") return { type: "go_games", blitzes: d.count, groups: d.groups };
  if (it.kind === "club_news") return { type: "club_news", source: it.source, title: d.title || undefined, text: d.text };
  return null;
}

async function writeAll(settings: any, club: any, items: any[]) {
  const list = items.map((it, i) => ({ id: i, facts: factsFor(it) })).filter((x) => x.facts);
  if (!list.length || !Deno.env.get("ANTHROPIC_API_KEY")) return [];
  try {
    const anthropic = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY")! });
    const msg = await anthropic.messages.create({
      model: MODEL, max_tokens: 4000, system: RULES,
      messages: [{ role: "user", content:
        `Club: ${club.club_name}. Newsletter: ${settings.title}.
Write each story below. Reply with JSON only: an array of {"id": number, "headline": string, "deck": string or null, "body": string}.
${JSON.stringify(list)}` }],
    });
    const text = msg.content.map((c: any) => c.type === "text" ? c.text : "").join("");
    const m = /\[[\s\S]*\]/.exec(text);
    const arr = m ? JSON.parse(m[0]) : [];
    const out: any[] = [];
    for (const w of arr) if (Number.isInteger(w.id) && items[w.id]) out[w.id] = { headline: clip(w.headline, 120), deck: clip(w.deck, 240), body: clip(w.body, 2000) };
    return out;
  } catch (e) { console.error("writer", e); return []; }
}

function fallback(it: any) {
  const d = it.data || {};
  const opp = d.us === "home" ? d.away : d.home;
  const ours = d.us === "home" ? d.home_score : d.away_score, theirs = d.us === "home" ? d.away_score : d.home_score;
  if (it.kind === "win") return { headline: `Win over ${opp}`, deck: `A great result for our ${d.age} ${d.code} side.`, body: `Well done to our ${d.age} ${d.code} team on a ${ours} to ${theirs} win over ${opp} in the ${d.competition} on ${d.dow}.` };
  if (it.kind === "final" && d.result === "close") return { headline: `So close for our ${d.age}s`, body: `Our ${d.age} ${d.code} side were edged out ${ours} to ${theirs} by ${opp} in the ${d.competition} ${d.round}. A brilliant effort and a season to be proud of.` };
  if (it.kind === "final") return { headline: `${d.age}s reach the ${d.round}`, body: `Our ${d.age} ${d.code} side reached the ${d.competition} ${d.round}, where ${opp} took the honours on the day. A fine achievement and a season to be proud of.` };
  if (it.kind === "go_games") return { headline: "Go Games for our youngest", body: `Our youngest players took part in ${d.count} Go Games blitzes this week. Well done to all the players and volunteers.` };
  if (it.kind === "club_news") return { headline: d.title || "Club news", body: String(d.text || "").slice(0, 400) };
  return { headline: "", body: "" };
}

async function rewrite(sb: any, clubId: number, id: any) {
  const st = await storyOf(sb, clubId, id);
  const f = factsFor(st);
  if (!f) throw new Error("This story has nothing for the writer to work from. Edit it by hand.");
  const club = await clubRow(sb, clubId);
  const settings = await settingsOf(sb, clubId, club);
  const anthropic = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY")! });
  const msg = await anthropic.messages.create({
    model: MODEL, max_tokens: 1200, system: RULES,
    messages: [{ role: "user", content:
      `Club: ${club.club_name}. Newsletter: ${settings.title}. This story is placed as: ${st.placement}.
Write a fresh version, different from this one: ${JSON.stringify({ headline: st.headline, body: st.body })}
Facts: ${JSON.stringify(f)}
Reply with JSON only: {"headline": string, "deck": string or null, "body": string}` }],
  });
  const text = msg.content.map((c: any) => c.type === "text" ? c.text : "").join("");
  const m = /\{[\s\S]*\}/.exec(text);
  if (!m) throw new Error("The writer didn't answer. Try again.");
  const w = JSON.parse(m[0]);
  await draft(sb, { issue_id: st.issue_id });
  const { data } = await sb.from("newsletter_stories").update({
    headline: clip(w.headline, 120), deck: st.placement === "lead" ? clip(w.deck, 240) || null : null, body: clip(w.body, 2000),
    edited: true, updated_at: new Date().toISOString(),
  }).eq("story_id", st.story_id).select().single();
  return withUrl(data);
}

// ── edits ───────────────────────────────────────────────────────────────
async function saveStory(sb: any, clubId: number, s: any) {
  const st = await storyOf(sb, clubId, s.story_id);
  const placement = ["lead", "story", "short"].includes(s.placement) ? s.placement : st.placement;
  await draft(sb, { issue_id: st.issue_id });
  if (placement === "lead" && st.placement !== "lead") {
    await sb.from("newsletter_stories").update({ placement: "story" }).eq("issue_id", st.issue_id).eq("placement", "lead");
  }
  const { data, error } = await sb.from("newsletter_stories").update({
    headline: s.headline !== undefined ? clip(s.headline, 120) : st.headline,
    deck: s.deck !== undefined ? clip(s.deck, 240) || null : st.deck,
    body: s.body !== undefined ? clip(s.body, 4000) : st.body,
    kicker: s.kicker !== undefined ? clip(s.kicker, 120) || null : st.kicker,
    included: s.included !== undefined ? !!s.included : st.included,
    data: s.show_photo !== undefined ? { ...(st.data || {}), hide_photo: !s.show_photo } : st.data,
    placement, edited: true, updated_at: new Date().toISOString(),
  }).eq("story_id", st.story_id).select().single();
  if (error) throw error;
  return withUrl(data);
}

async function order(sb: any, clubId: number, body: any) {
  const iss = await draft(sb, await issueOf(sb, clubId, body.issue_id));
  const items = Array.isArray(body.items) ? body.items.slice(0, 200) : [];
  const { data: mine } = await sb.from("newsletter_stories").select("story_id").eq("issue_id", iss.issue_id);
  const ids = new Set((mine || []).map((r: any) => r.story_id));
  let i = 1;
  for (const it of items) {
    const id = Number(it.story_id);
    if (!ids.has(id)) continue;
    await sb.from("newsletter_stories").update({ position: i++, included: !!it.included }).eq("story_id", id);
  }
  return true;
}

async function photo(sb: any, clubId: number, body: any) {
  const st = await storyOf(sb, clubId, body.story_id);
  await draft(sb, { issue_id: st.issue_id });
  const path = body.clear ? null : await uploadImage(sb, `${clubId}/${st.issue_id}`, body);
  const { data } = await sb.from("newsletter_stories").update({ photo_path: path, data: { ...(st.data || {}), hide_photo: false }, edited: true, updated_at: new Date().toISOString() }).eq("story_id", st.story_id).select().single();
  return withUrl(data);
}

async function build(sb: any, clubId: number, body: any, uid: string) {
  const iss = await issueOf(sb, clubId, body.issue_id);
  const b64 = String(body.pdf || "").replace(/^data:[^,]+,/, "");
  if (!b64 || b64.length > 14_000_000) throw new Error("The PDF didn't come through. Please try again.");
  const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  const slug = String(iss.title || "newsletter").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
  const path = `${clubId}/${iss.issue_id}/${slug}-${iss.issue_no}-${Date.now()}.pdf`;
  const { error } = await sb.storage.from(BUCKET).upload(path, bytes, { contentType: "application/pdf" });
  if (error) throw error;
  if (iss.pdf_path) await sb.storage.from(BUCKET).remove([iss.pdf_path]);
  await sb.from("newsletter_issues").update({
    status: "built", pdf_path: path, built_at: new Date().toISOString(), built_by: uid, approved_at: null, approved_by: null, updated_at: new Date().toISOString(),
  }).eq("issue_id", iss.issue_id);
  return issueData(sb, await issueOf(sb, clubId, iss.issue_id));
}
