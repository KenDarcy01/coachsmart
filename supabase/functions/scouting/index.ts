// deno-lint-ignore-file no-explicit-any
// Scouting report webview (webviews/scouting.html).
//
// The coach picks the opposition first (club, then age, code, division and team), then which
// of their own club's sides to compare it with. A match event is optional: from the app the
// event's details give a guess, and the pair is remembered for that event; in a browser the
// page works with no event at all.
//
// Actions (all need the caller's JWT; the caller must be a team manager, role level 100+,
// and a managed team must have the scouting switch on, or the caller must have ai_features):
//   start   { event_id? }                        → clubs, our club's sides, the event (if any) and a guess;
//                                                   with an event that already has a pair, the report instead
//   club    { club_id }                          → that club's sides this season, one per team and competition
//   sides   { code, age }                        → every side in that code and age, for the team list
//   link    { event_id?, code, age, opp_club_id, opp_team, opp_comp_id, scope: all | comp } → saves the pair, returns the report
//   report  { pair_key }                         → the report for a pair picked earlier
//   relink  { event_id }                         → forgets which pair the event uses (notes stay with the pair)
//   notes   { pair_key, notes }                  → saves the managers' shared notes for the pair
//   summary { pair_key }                         → { summary } AI "short version" (ai_features only), cached
//   pdf     { pair_key, format: a4 | mobile, event_id? } → { pdf (base64), filename }
//
// Numbers come from the season store (public.gaa_games, loaded nightly by gaa-sync).
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { buildReport, type Comp, type Game, norm, type Report } from "./report.ts";
import { buildScoutingPdf } from "./pdf.ts";

const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";
const GEMINI_URL   = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });

const GAME_COLS = "game_id, comp_id, start_at, home_team, away_team, home_club_id, away_club_id, status, home_score, away_score, home_pts, away_pts, venue, note";

const SUMMARY_PROMPT = `You are helping a GAA (Gaelic Athletic Association) coach prepare for a match.
You get a scouting summary of the opposition's season so far: their record, home and away form,
every result, results against teams both sides have played, and any earlier games between the two teams.

Write "the short version": exactly 3 short bullet points a coach can read in 20 seconds.
- Plain, friendly coaching language. Each point one sentence, under 25 words.
- Only facts that are in the data. Never invent players, scorers, tactics or results.
- Pick what matters most for the coming game: strengths, weaknesses, form, home/away, how they did against common opponents, and the last meeting.
- Refer to the coach's team as "we" / "us" and the opposition by name.
- Points are counted with a goal worth 3.

Return ONLY valid JSON: {"points": ["...", "...", "..."]}`;

/** Club name as a key: letters and digits only, without words like GAA or CLG. */
function clubKey(s: string | null | undefined) {
  return norm(String(s ?? "").replace(/\b(gaa|g\.a\.a\.|clg|cumann|club|hurling|camogie|lgfa|ladies|football|gfc|hc)\b/gi, ""));
}

/** The season store's code for an event code; teams marked female play camogie / ladies football. */
function storeCode(eventCode: string | null | undefined, female: boolean): string | null {
  const c = String(eventCode ?? "").toLowerCase();
  if (c.includes("camog")) return "Camogie";
  if (c.includes("ladies") || c.includes("lgfa")) return "Ladies Football";
  if (c.includes("hurl")) return female ? "Camogie" : "Hurling";
  if (c.includes("football")) return female ? "Ladies Football" : "Football";
  return null;
}

/** "U13 Boys" → "U13"; "Minor Hurling" → "Minor". */
function ageFrom(...names: (string | null | undefined)[]): string | null {
  for (const n of names) {
    const m = String(n ?? "").match(/\b(?:U|Under)[\s-]?(\d{1,2})\b/i);
    if (m) return `U${Number(m[1])}`;
    if (/\bminor\b/i.test(String(n ?? ""))) return "Minor";
  }
  return null;
}

/** How well a free-text opposition ("Na Fianna", "na fianna b") matches a side. 0 = not at all. */
function oppScore(text: string | null | undefined, team: string, club: any): number {
  const t = norm(text), k = clubKey(text);
  if (!t) return 0;
  if (t === norm(team)) return 3;
  const keys: string[] = club ? [club.name_key, ...(club.alias_keys || [])] : [];
  if (keys.includes(k)) return 2;
  if (keys.some(c => c && k.length >= 4 && (k.startsWith(c) || c.startsWith(k)))) return 1;
  return 0;
}

/** One key per pair of sides, shared by every event and browser visit that compares them. */
const pairKeyOf = (ourClubId: number, code: string, age: string, oppClubId: number, oppTeam: string, oppComp: string) =>
  `${ourClubId}|${code}|${age}|${oppClubId}|${norm(oppTeam)}|${oppComp}`;

/** Does a competition grade read like a league division ("League Div 3", "Division 1") rather than a
 *  cup, shield, championship or knockout stage? A team plays in one league division, so any other
 *  division is a different team (LGFA names every side after the club). */
const isLeagueDivision = (grade: string) => /\bdiv(?:ision)?\b/i.test(grade) && !/\b(cup|shield|plate|championship|knock\s*-?out|final|semi|quarter)\b/i.test(grade);
/** The division number in a grade ("Championship Division 5 Group B" → 5), or null. */
const divNumber = (grade: string): number | null => { const m = grade.match(/\bdiv(?:ision)?\s*(\d+)/i); return m ? Number(m[1]) : null; };

async function callGemini(apiKey: string, userText: string): Promise<string[]> {
  const body = JSON.stringify({
    system_instruction: { parts: [{ text: SUMMARY_PROMPT }] },
    contents: [{ parts: [{ text: userText }] }],
    generationConfig: { maxOutputTokens: 2048, temperature: 0.3, responseMimeType: "application/json" },
  });
  let res: Response | null = null;
  for (let attempt = 1; attempt <= 3; attempt++) {
    res = await fetch(`${GEMINI_URL}?key=${apiKey}`, { method: "POST", headers: { "Content-Type": "application/json" }, body });
    if (res.ok) break;
    console.warn(`Gemini attempt ${attempt} failed (${res.status}):`, (await res.text()).slice(0, 200));
    if (!(res.status === 503 || res.status === 429) || attempt === 3) break;
    await new Promise(r => setTimeout(r, attempt * 1500));
  }
  if (!res!.ok) throw new Error(`Gemini API error ${res!.status}`);
  const data = await res!.json();
  const text = (data.candidates?.[0]?.content?.parts?.[0]?.text || "").trim()
    .replace(/^```json\s*/i, "").replace(/^```\s*/i, "").replace(/\s*```$/i, "");
  const parsed = JSON.parse(text);
  const points = (parsed?.points || []).map((p: unknown) => String(p).trim()).filter(Boolean);
  if (!points.length) throw new Error("Gemini returned an unexpected format");
  return points.slice(0, 4);
}

/** Reads every row of a query, 1000 at a time (PostgREST's page size). */
async function allRows(q: () => any): Promise<any[]> {
  const out: any[] = [];
  for (let from = 0; ; from += 1000) {
    const { data, error } = await q().range(from, from + 999);
    if (error) throw new Error(error.message);
    out.push(...(data || []));
    if (!data || data.length < 1000) return out;
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const body = await req.json();
    const { action } = body;
    const eventId = Number(body.event_id) || 0;

    const SUPABASE_URL     = Deno.env.get("SUPABASE_URL")!;
    const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

    // ── Caller: a manager (role level 100+) on at least one team ──
    const jwt = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
    const { data: { user }, error: userErr } = await sb.auth.getUser(jwt);
    if (userErr || !user) return json({ error: "Please sign in again" }, 401);

    const { data: links } = await sb.from("user_member_link").select("member_id").eq("user_id", user.id).eq("status", "active");
    const memberIds = (links || []).map((l: any) => l.member_id).filter(Boolean);
    const { data: mts } = memberIds.length
      ? await sb.from("member_team_link").select("member_team_id, team_id").eq("status", "active").in("member_id", memberIds)
      : { data: [] as any[] };
    const teamOf = new Map<number, number>((mts || []).map((m: any) => [m.member_team_id, m.team_id]));
    const { data: roles } = teamOf.size
      ? await sb.from("member_team_role_link").select("member_team_id, roles!inner(role_level)").in("member_team_id", [...teamOf.keys()])
      : { data: [] as any[] };
    const managedTeamIds = [...new Set((roles || []).filter((r: any) => Number(r.roles?.role_level) >= 100).map((r: any) => teamOf.get(r.member_team_id)!))];
    if (!managedTeamIds.length) return json({ error: "Scouting reports are for team managers" }, 403);

    // ── The event, when the page was opened from one ──
    let ev: any = null;
    if (eventId) {
      ({ data: ev } = await sb.from("events")
        .select("event_id, event_title, event_date_time, opposition, home_away, location_name, squad_id, team_id, event_code_id")
        .eq("event_id", eventId).maybeSingle());
      if (!ev) return json({ error: "Match not found" }, 404);
      if (!managedTeamIds.includes(ev.team_id)) return json({ error: "You're not a manager on this team" }, 403);
    }

    const [{ data: teams }, { data: me }] = await Promise.all([
      sb.from("teams").select("team_id, team_name, team_female, scouting, club_id").in("team_id", managedTeamIds),
      sb.from("users").select("ai_features").eq("user_id", user.id).maybeSingle(),
    ]);
    const aiEnabled = me?.ai_features === true;
    const team = ev ? (teams || []).find((t: any) => t.team_id === ev.team_id) : null;
    const switchedOn = (teams || []).some((t: any) => t.scouting) || aiEnabled;
    if (!switchedOn) return json({ error: "Scouting reports aren't switched on for your teams" }, 403);

    // Our club: the event's team's club, or the club of the teams the caller manages.
    const clubId = team?.club_id ?? (teams || []).find((t: any) => t.scouting)?.club_id ?? (teams || [])[0]?.club_id;
    const { data: club } = await sb.from("clubs")
      .select("club_id, club_name, crest, primary_colour, secondary_colour, third_colour, gaa_club_id")
      .eq("club_id", clubId).maybeSingle();
    const clubTeamIds = (teams || []).filter((t: any) => t.club_id === clubId).map((t: any) => t.team_id);

    // ── Clubs in the season store, and ours ──
    const gaaClubs = await allRows(() => sb.from("gaa_clubs").select("club_id, name, name_key, alias_keys").order("club_id"));
    const clubById = new Map<number, any>(gaaClubs.map((c: any) => [c.club_id, c]));
    let ourClubId: number | null = club?.gaa_club_id ?? null;
    if (!ourClubId) {
      const k = clubKey(club?.club_name);
      ourClubId = gaaClubs.find((c: any) => c.name_key === k || (c.alias_keys || []).includes(k))?.club_id ?? null;
    }
    if (!ourClubId) return json({ error: `We couldn't find ${club?.club_name || "your club"} in the Dublin fixtures` }, 404);
    if (club && !club.gaa_club_id) await sb.from("clubs").update({ gaa_club_id: ourClubId }).eq("club_id", club.club_id);

    const eventStart = ev?.event_date_time ? new Date(ev.event_date_time) : new Date();
    const year = Number(new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Dublin", year: "numeric" }).format(eventStart));
    const yearStart = `${year}-01-01`, yearEnd = `${year + 1}-01-01`;

    /** Every side one club has fielded this season, one row per team and competition: a club can list
     *  several teams under one name (LGFA), so the competition is part of what makes a side. */
    const clubSides = async (cid: number) => {
      const games = await allRows(() => sb.from("gaa_games")
        .select("comp_id, home_team, away_team, home_club_id, away_club_id, gaa_competitions!inner(code, age, grade, name)")
        .or(`home_club_id.eq.${cid},away_club_id.eq.${cid}`).gte("start_at", yearStart).lt("start_at", yearEnd).order("game_id"));
      const sides = new Map<string, { code: string; age: string; team: string; comp_id: string; grade: string; games: number }>();
      for (const g of games) {
        const c = g.gaa_competitions;
        for (const side of ["home", "away"] as const) {
          if ((side === "home" ? g.home_club_id : g.away_club_id) !== cid) continue;
          const name = side === "home" ? g.home_team : g.away_team;
          const k = `${c.code}|${c.age}|${norm(name)}|${g.comp_id}`;
          if (!sides.has(k)) sides.set(k, { code: c.code, age: c.age, team: name, comp_id: g.comp_id, grade: c.grade || c.name, games: 0 });
          sides.get(k)!.games++;
        }
      }
      return [...sides.values()].sort((a, b) => a.grade.localeCompare(b.grade) || a.team.localeCompare(b.team));
    };

    /** Every side in the competitions of one code and age this season. */
    const sidesIn = async (code: string, age: string) => {
      const { data: comps } = await sb.from("gaa_competitions").select("comp_id, grade, name").eq("code", code).eq("age", age);
      const compById = new Map<string, any>((comps || []).map((c: any) => [c.comp_id, c]));
      const ids = [...compById.keys()];
      const games: Game[] = ids.length ? await allRows(() => sb.from("gaa_games")
        .select("game_id, comp_id, home_team, away_team, home_club_id, away_club_id")
        .in("comp_id", ids).gte("start_at", yearStart).lt("start_at", yearEnd).order("game_id")) : [];
      const sides = new Map<string, { club_id: number; club: string; team: string; comp_id: string; grade: string }>();
      for (const g of games) {
        const c = compById.get(g.comp_id);
        if (!c) continue;
        for (const side of ["home", "away"] as const) {
          const cid = side === "home" ? g.home_club_id : g.away_club_id;
          const name = side === "home" ? g.home_team : g.away_team;
          if (!cid) continue;
          const k = `${cid}|${norm(name)}|${g.comp_id}`;
          if (!sides.has(k)) sides.set(k, { club_id: cid, club: clubById.get(cid)?.name || name, team: name, comp_id: g.comp_id, grade: c.grade || c.name });
        }
      }
      return [...sides.values()];
    };

    const eventInfo = ev ? {
      event_id: ev.event_id, title: ev.event_title, date: ev.event_date_time, home_away: ev.home_away,
      location: ev.location_name, opposition: ev.opposition,
    } : null;

    // ── CLUB / SIDES: lists for the picker ──
    if (action === "club") {
      const cid = Number(body.club_id);
      if (!cid) return json({ error: "club_id required" }, 400);
      return json({ success: true, data: { club_id: cid, sides: await clubSides(cid) } });
    }
    if (action === "sides") {
      const code = String(body.code || ""), age = String(body.age || "");
      if (!code || !age) return json({ error: "code and age required" }, 400);
      const sides = (await sidesIn(code, age)).map(x => ({ ...x, score: ev ? oppScore(ev.opposition, x.team, clubById.get(x.club_id)) : 0 }))
        .sort((a, b) => b.score - a.score || a.club.localeCompare(b.club) || a.team.localeCompare(b.team));
      return json({ success: true, data: { sides } });
    }

    // ── RELINK: the event forgets its pair (the pair's notes stay) ──
    if (action === "relink" && ev) {
      await sb.from("scouting_reports").update({ event_id: null }).eq("event_id", eventId);
    }

    // ── START: the picker (or the report, when the event already has a pair) ──
    if (action === "start" || action === "relink") {
      if (ev && action === "start") {
        const { data: existing } = await sb.from("scouting_reports").select("*").eq("event_id", eventId).maybeSingle();
        if (existing) return json({ success: true, data: await reportPayload(existing) });
      }
      // The guess: the fixture on the event day whose opposition matches what the coach typed,
      // then the event's opposition text, code and age.
      let guess: any = null;
      if (ev) {
        const eventCode = storeCode((await sb.from("event_codes").select("event_code").eq("code_id", ev.event_code_id).maybeSingle()).data?.event_code, team?.team_female === true);
        const squadName = ev.squad_id ? (await sb.from("squads").select("squad_name").eq("squad_id", ev.squad_id).maybeSingle()).data?.squad_name : null;
        const teamAge = ageFrom(squadName, team?.team_name, ev.event_title);
        const from = new Date(eventStart.getTime() - 12 * 3600e3).toISOString();
        const to = new Date(eventStart.getTime() + 12 * 3600e3).toISOString();
        const { data: dayGames } = await sb.from("gaa_games")
          .select("comp_id, home_team, away_team, home_club_id, away_club_id, gaa_competitions!inner(code, age, grade, name)")
          .gte("start_at", from).lte("start_at", to)
          .or(`home_club_id.eq.${ourClubId},away_club_id.eq.${ourClubId}`);
        const ranked = (dayGames || []).filter((g: any) => g.home_club_id !== g.away_club_id).map((g: any) => {
          const home = g.home_club_id === ourClubId;
          const ours = home ? g.home_team : g.away_team, theirs = home ? g.away_team : g.home_team;
          const oppClub = home ? g.away_club_id : g.home_club_id;
          const { code, age } = g.gaa_competitions;
          const opp = oppScore(ev.opposition, theirs, clubById.get(oppClub));
          const score = opp * 4 + (eventCode && code === eventCode ? 2 : 0) + (teamAge && age === teamAge ? 1 : 0);
          return { code, age, comp_id: g.comp_id, grade: g.gaa_competitions.grade || g.gaa_competitions.name, ours, theirs, oppClub, score };
        }).sort((a: any, b: any) => b.score - a.score);
        const top = ranked[0];
        if (top && top.score > 0) {
          guess = { opp_club_id: top.oppClub, code: top.code, age: top.age, comp_id: top.comp_id, grade: top.grade, opp_team: top.theirs, our_team: top.ours };
        } else {
          const k = clubKey(ev.opposition);
          const oppClub = k ? gaaClubs.find((c: any) => c.name_key === k || (c.alias_keys || []).includes(k))
            ?? gaaClubs.find((c: any) => k.length >= 4 && (c.name_key.startsWith(k) || k.startsWith(c.name_key))) : null;
          guess = { opp_club_id: oppClub?.club_id ?? null, code: eventCode, age: teamAge, comp_id: null, grade: null, opp_team: null, our_team: null };
        }
      }
      return json({
        success: true,
        data: {
          link_needed: true, event: eventInfo, team_name: team?.team_name ?? null,
          club: { name: club?.club_name, crest: club?.crest, gaa_club_id: ourClubId },
          clubs: gaaClubs.map((c: any) => ({ club_id: c.club_id, name: c.name })).sort((a: any, b: any) => a.name.localeCompare(b.name)),
          guess, ai_enabled: aiEnabled,
        },
      });
    }

    // ── LINK: the coach picked both sides ──
    if (action === "link") {
      const code = String(body.code || "").trim(), age = String(body.age || "").trim();
      const oppTeam = String(body.opp_team || "").trim(), oppClubId = Number(body.opp_club_id);
      const oppComp = String(body.opp_comp_id || "").trim();
      const scope = body.scope === "comp" ? "comp" : "all";
      if (!code || !age || !oppTeam || !oppClubId || !oppComp) return json({ error: "Please pick the team and its division" }, 400);
      const sides = await clubSides(oppClubId);
      if (!sides.some(x => x.code === code && x.age === age && norm(x.team) === norm(oppTeam) && x.comp_id === oppComp)) {
        return json({ error: "That team wasn't found in the fixtures" }, 400);
      }
      const pairKey = pairKeyOf(ourClubId, code, age, oppClubId, oppTeam, oppComp);
      const { data: existing } = await sb.from("scouting_reports").select("report_id").eq("pair_key", pairKey).maybeSingle();
      if (existing) {
        await sb.from("scouting_reports").update({ scope, ...(ev ? { event_id: eventId } : {}) }).eq("report_id", existing.report_id);
      } else {
        await sb.from("scouting_reports").insert({
          pair_key: pairKey, event_id: ev ? eventId : null, code, age, our_club_id: ourClubId,
          opp_club_id: oppClubId, opp_team: oppTeam, comp_id: oppComp, scope, created_by: user.id,
        });
      }
      if (ev) {
        // Only one pair per event.
        await sb.from("scouting_reports").update({ event_id: null }).eq("event_id", eventId).neq("pair_key", pairKey);
      }
      const { data: pair } = await sb.from("scouting_reports").select("*").eq("pair_key", pairKey).maybeSingle();
      return json({ success: true, data: await reportPayload(pair) });
    }

    // ── Everything else works on a pair the coach already picked ──
    const pairKey = String(body.pair_key || "");
    const { data: pair } = pairKey
      ? await sb.from("scouting_reports").select("*").eq("pair_key", pairKey).maybeSingle()
      : { data: null };
    if (!pair) return json({ error: "Pick the two teams first" }, 400);
    if (pair.our_club_id !== ourClubId) return json({ error: "That report belongs to another club" }, 403);

    if (action === "notes") {
      const notes = String(body.notes ?? "").slice(0, 8000);
      const { error } = await sb.from("scouting_reports")
        .update({ notes, notes_by: user.id, notes_at: new Date().toISOString() }).eq("report_id", pair.report_id);
      if (error) return json({ error: "Could not save your notes" }, 500);
      return json({ success: true, data: { saved: true } });
    }

    if (action === "report") return json({ success: true, data: await reportPayload(pair) });

    if (action === "summary") {
      if (!aiEnabled) return json({ error: "AI features are not switched on for your account" }, 403);
      const { report } = await buildFor(sb, pair, year, eventStart);
      const key = JSON.stringify([report.record, report.last_result, report.h2h.length, report.common.length, ev?.home_away ?? null]);
      if (pair.ai_summary && pair.ai_key === key) return json({ success: true, data: { summary: pair.ai_summary.split("\n") } });
      const apiKey = Deno.env.get("GEMINI_API_KEY");
      if (!apiKey) return json({ error: "GEMINI_API_KEY not configured" }, 500);
      const ha = String(ev?.home_away || "").toLowerCase();
      const venue = ha.startsWith("h") ? "at our ground" : ha.startsWith("a") ? "at their ground" : "venue not given";
      const points = await callGemini(apiKey, [
        `Opposition: ${pair.opp_team} (${pair.age} ${pair.code})`,
        `Our club: ${club?.club_name || ""}`,
        ev ? `Coming game: ${ev.event_title || ""}, ${venue}` : "Coming game: not set",
        `Scouting data (JSON):`,
        JSON.stringify({ record: report.record, home: report.home, away: report.away, form_newest_first: report.form, games: report.games, common_opponents: report.common, earlier_games_v_us: report.h2h, table: report.table }),
      ].join("\n"));
      await sb.from("scouting_reports").update({ ai_summary: points.join("\n"), ai_key: key, ai_at: new Date().toISOString() }).eq("report_id", pair.report_id);
      return json({ success: true, data: { summary: points } });
    }

    if (action === "pdf") {
      const payload = await reportPayload(pair);
      const format = body.format === "mobile" ? "mobile" : "a4";
      const bytes = await buildScoutingPdf(payload, {
        club_name: club?.club_name || "CoachSmart", crest: club?.crest || null,
        primary_colour: club?.primary_colour || "#1B3A6B", secondary_colour: club?.secondary_colour || "#ED1B2E",
        third_colour: club?.third_colour || null,
      }, format, body.include_notes !== false);
      let b = "";
      for (let i = 0; i < bytes.length; i += 8192) b += String.fromCharCode(...bytes.subarray(i, i + 8192));
      const day = ev?.event_date_time ? String(ev.event_date_time).slice(0, 10) : new Date().toISOString().slice(0, 10);
      return json({ pdf: btoa(b), filename: `scouting-${norm(pair.opp_team).slice(0, 30)}-${day}.pdf` });
    }

    return json({ error: `Unknown action: ${action}` }, 400);

    /** The report screen's data for a pair. */
    async function reportPayload(pair: any) {
      const { report, fixture } = await buildFor(sb, pair, year, eventStart);
      // Match reports are left out for now (Ken, 2026-10-19): they aren't reliably about this team.
      const matchReports: any[] = [];
      const notesBy = pair.notes_by ? (await sb.from("users").select("first_name, last_name").eq("user_id", pair.notes_by).maybeSingle()).data : null;
      return {
        pair_key: pair.pair_key, event: eventInfo, team_name: team?.team_name ?? null, code: pair.code, scope: pair.scope || "all",
        club: { name: club?.club_name, crest: club?.crest },
        ai_enabled: aiEnabled,
        fixture: fixture ? { date: fixture.start_at, venue: fixture.venue || "", home: fixture.home_club_id === pair.our_club_id } : null,
        report,
        match_reports: matchReports,
        notes: pair.notes || "",
        notes_by: notesBy ? `${notesBy.first_name || ""} ${notesBy.last_name || ""}`.trim() : null,
        notes_at: pair.notes_at,
        summary: pair.ai_summary && aiEnabled ? pair.ai_summary.split("\n") : null,
      };
    }
  } catch (err) {
    console.error("scouting error:", err);
    return json({ error: (err as Error).message || "Something went wrong" }, 500);
  }
});

/** The season's results for the pair's age and code, up to the event (or today), and the report built from them.
 *  Scope "all": the team's league division plus every cup, shield, championship and knockout competition
 *  this year, never another league division. Scope "comp": just the competition picked. */
async function buildFor(sb: any, pair: any, year: number, eventStart: Date) {
  const { data: comps } = await sb.from("gaa_competitions").select("comp_id, name, code, age, grade").eq("code", pair.code).eq("age", pair.age);
  const ids = (comps || []).map((c: Comp) => c.comp_id);
  const until = new Date(Math.min(eventStart.getTime(), Date.now() + 86400e3)).toISOString();
  let games: Game[] = ids.length ? await allRows(() => sb.from("gaa_games").select(GAME_COLS).in("comp_id", ids)
    .gte("start_at", `${year}-01-01`).lt("start_at", until).order("game_id")) : [];
  if (pair.scope === "comp") {
    games = games.filter(g => g.comp_id === pair.comp_id);
  } else {
    // Other league divisions are other teams. A championship or cup that names a division number
    // counts only when it is the picked division's number. One with no number counts only when it
    // is clearly tied to the picked division: at least two thirds of its sides play in it.
    const sideOf = (g: Game, side: "home" | "away") => `${side === "home" ? g.home_club_id : g.away_club_id}|${norm(side === "home" ? g.home_team : g.away_team)}`;
    const inPicked = new Set<string>();
    const sidesByComp = new Map<string, Set<string>>();
    for (const g of games) {
      for (const side of ["home", "away"] as const) {
        const k = sideOf(g, side);
        if (g.comp_id === pair.comp_id) inPicked.add(k);
        if (!sidesByComp.has(g.comp_id)) sidesByComp.set(g.comp_id, new Set());
        sidesByComp.get(g.comp_id)!.add(k);
      }
    }
    const keep = new Set<string>([pair.comp_id]);
    const picked = (comps || []).find((c: Comp) => c.comp_id === pair.comp_id);
    const pickedNum = picked ? divNumber(picked.grade || picked.name) : null;
    for (const c of comps || []) {
      if (c.comp_id === pair.comp_id || isLeagueDivision(c.grade || c.name)) continue;
      const num = divNumber(c.grade || c.name);
      if (num !== null) { if (pickedNum !== null && num === pickedNum) keep.add(c.comp_id); continue; }
      const sides = [...(sidesByComp.get(c.comp_id) ?? [])];
      if (sides.length && sides.filter(k => inPicked.has(k)).length * 3 >= sides.length * 2) keep.add(c.comp_id);
    }
    games = games.filter(g => keep.has(g.comp_id));
  }
  const us = { club_id: pair.our_club_id, team: "", age: pair.age };
  const opp = { club_id: pair.opp_club_id, team: pair.opp_team, age: pair.age };
  // The fixture itself (venue, and whether we're at home): the two sides' next game within a day of the event.
  const { data: next } = await sb.from("gaa_games").select(GAME_COLS).in("comp_id", ids.length ? ids : ["-"])
    .gte("start_at", new Date(eventStart.getTime() - 12 * 3600e3).toISOString())
    .lte("start_at", new Date(eventStart.getTime() + 12 * 3600e3).toISOString())
    .or(`home_club_id.eq.${pair.our_club_id},away_club_id.eq.${pair.our_club_id}`);
  const fixture = (next || []).find((g: Game) =>
    [g.home_club_id, g.away_club_id].includes(pair.our_club_id) && [g.home_team, g.away_team].map(norm).includes(norm(pair.opp_team))) ?? null;
  const report: Report = buildReport(games, comps || [], us, opp, pair.code, pair.comp_id ?? fixture?.comp_id);
  return { report, fixture };
}

/** The club's earlier match reports against this opposition (last two years), newest first. */
async function loadMatchReports(sb: any, teamIds: number[], excludeEventId: number, oppClub: any, oppTeam: string) {
  if (!teamIds.length) return [];
  const since = new Date(Date.now() - 730 * 86400e3).toISOString();
  const { data: events } = await sb.from("events").select("event_id, event_date_time, opposition")
    .in("team_id", teamIds).gte("event_date_time", since).neq("event_id", excludeEventId || -1);
  if (!events?.length) return [];
  const byId = new Map<number, any>(events.map((e: any) => [e.event_id, e]));
  const rows: any[] = [];
  const ids = events.map((e: any) => e.event_id);
  for (let i = 0; i < ids.length; i += 200) {
    const { data } = await sb.from("match_reports").select("id, created_at, event_id, user_id, match_report, opposition")
      .in("event_id", ids.slice(i, i + 200));
    rows.push(...(data || []));
  }
  const mine = rows.filter(r => r.match_report && oppScore(r.opposition || byId.get(r.event_id)?.opposition, oppTeam, oppClub) > 0);
  if (!mine.length) return [];
  const userIds = [...new Set(mine.map(r => r.user_id).filter(Boolean))];
  const { data: users } = await sb.from("users").select("user_id, first_name, last_name").in("user_id", userIds);
  const names = new Map((users || []).map((u: any) => [u.user_id, `${u.first_name || ""} ${u.last_name || ""}`.trim()]));
  return mine.map(r => ({
    date: byId.get(r.event_id)?.event_date_time || r.created_at,
    author: names.get(r.user_id) || "",
    opposition: r.opposition || byId.get(r.event_id)?.opposition || "",
    report: r.match_report,
  })).sort((a, b) => String(b.date).localeCompare(String(a.date))).slice(0, 5);
}
