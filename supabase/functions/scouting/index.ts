// deno-lint-ignore-file no-explicit-any
// Scouting report webview (webviews/scouting.html), opened from a match event.
//
// Actions (all need the caller's JWT; the caller must be a manager, role level 100+, on the
// event's team, and the team's scouting switch must be on or the caller must have ai_features):
//   load    { event_id }                         → report, or (link_needed) our club's sides and a guess
//   sides   { event_id, code, age }              → every side in that code and age, for the opposition choice
//   link    { event_id, code, age, our_team, opp_team, opp_club_id, grade } → saves which sides to compare, then as load
//   relink  { event_id }                         → the link sheet again (the saved pair and notes stay until a new link)
//   notes   { event_id, notes }                  → saves the managers' shared notes
//   summary { event_id }                         → { summary } AI "short version" (ai_features only), cached
//   pdf     { event_id, format: a4 | mobile }    → { pdf (base64), filename }
//   events  {}                                   → the caller's matches from yesterday to 6 weeks ahead on
//          teams they manage, for opening the page in a browser without an event (no event_id needed)
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

/** Sort key for ages: U8 … U16, then Minor and the adult grades. */
function ageRank(age: string): number {
  const m = age.match(/^U(\d+)$/);
  if (m) return Number(m[1]);
  return ["Minor", "Junior", "Intermediate", "Senior", "Adult", "Other"].indexOf(age) + 20;
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
    const eventId = Number(body.event_id);
    if (!eventId && action !== "events") return json({ error: "event_id required" }, 400);

    const SUPABASE_URL     = Deno.env.get("SUPABASE_URL")!;
    const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

    // ── Caller ──
    const jwt = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
    const { data: { user }, error: userErr } = await sb.auth.getUser(jwt);
    if (userErr || !user) return json({ error: "Please sign in again" }, 401);

    if (action === "events") return json({ success: true, data: await listMatches(sb, user.id) });

    const { data: ev } = await sb.from("events")
      .select("event_id, event_title, event_date_time, opposition, home_away, location_name, squad_id, team_id, event_code_id")
      .eq("event_id", eventId).maybeSingle();
    if (!ev) return json({ error: "Match not found" }, 404);

    // Manager on the event's team: highest role level across active memberships (as ai-match-report).
    const { data: links } = await sb.from("user_member_link").select("member_id")
      .eq("user_id", user.id).eq("status", "active");
    const memberIds = (links || []).map((l: any) => l.member_id).filter(Boolean);
    const { data: teamLinks } = memberIds.length
      ? await sb.from("member_team_link").select("member_team_id")
          .eq("team_id", ev.team_id).eq("status", "active").in("member_id", memberIds)
      : { data: [] as any[] };
    const memberTeamIds = (teamLinks || []).map((l: any) => l.member_team_id);
    if (!memberTeamIds.length) return json({ error: "You're not on this team" }, 403);
    const { data: roleRows } = await sb.from("member_team_role_link")
      .select("roles!inner(role_level)").in("member_team_id", memberTeamIds);
    const roleLevel = Math.max(0, ...(roleRows || []).map((r: any) => Number(r.roles?.role_level) || 0));
    if (roleLevel < 100) return json({ error: "Scouting reports are for team managers" }, 403);

    const [{ data: team }, { data: me }, { data: codeRow }, { data: squad }] = await Promise.all([
      sb.from("teams").select("team_name, team_female, scouting, club_id").eq("team_id", ev.team_id).maybeSingle(),
      sb.from("users").select("ai_features").eq("user_id", user.id).maybeSingle(),
      ev.event_code_id ? sb.from("event_codes").select("event_code").eq("code_id", ev.event_code_id).maybeSingle() : Promise.resolve({ data: null }),
      ev.squad_id ? sb.from("squads").select("squad_name").eq("squad_id", ev.squad_id).maybeSingle() : Promise.resolve({ data: null }),
    ]);
    const aiEnabled = me?.ai_features === true;
    if (!team?.scouting && !aiEnabled) return json({ error: "Scouting reports aren't switched on for this team" }, 403);

    // The event's code is only a guess for the picker; the coach chooses the code, age and sides.
    const eventCode = storeCode(codeRow?.event_code, team?.team_female === true);

    const { data: club } = await sb.from("clubs")
      .select("club_id, club_name, crest, primary_colour, secondary_colour, third_colour, gaa_club_id")
      .eq("club_id", team!.club_id).maybeSingle();

    // ── Our club in the season store ──
    const gaaClubs = await allRows(() => sb.from("gaa_clubs").select("club_id, name, name_key, alias_keys").order("club_id"));
    const clubById = new Map((gaaClubs || []).map((c: any) => [c.club_id, c]));
    let ourClubId: number | null = club?.gaa_club_id ?? null;
    if (!ourClubId) {
      const k = clubKey(club?.club_name);
      const hit = (gaaClubs || []).find((c: any) => c.name_key === k || (c.alias_keys || []).includes(k));
      ourClubId = hit?.club_id ?? null;
    }
    if (!ourClubId) return json({ error: `We couldn't find ${club?.club_name || "your club"} in the Dublin fixtures` }, 404);

    const eventStart = ev.event_date_time ? new Date(ev.event_date_time) : new Date();
    const year = Number(new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Dublin", year: "numeric" }).format(eventStart));
    const teamAge = ageFrom(squad?.squad_name, team?.team_name, ev.event_title);
    const squadKey = Number(ev.squad_id) || 0;
    const yearStart = `${year}-01-01`, yearEnd = `${year + 1}-01-01`;

    if (action === "notes") {
      const notes = String(body.notes ?? "").slice(0, 8000);
      const { error } = await sb.from("scouting_reports")
        .update({ notes, notes_by: user.id, notes_at: new Date().toISOString() }).eq("event_id", eventId);
      if (error) return json({ error: "Could not save your notes" }, 500);
      return json({ success: true, data: { saved: true } });
    }

    const eventInfo = {
      event_id: ev.event_id, title: ev.event_title, date: ev.event_date_time, home_away: ev.home_away,
      location: ev.location_name, opposition: ev.opposition,
    };

    /** Every side in the competitions of one code and age this season: club, name as listed, grades played. */
    const sidesIn = async (code: string, age: string) => {
      const { data: comps } = await sb.from("gaa_competitions").select("comp_id, grade, name").eq("code", code).eq("age", age);
      const compById = new Map<string, any>((comps || []).map((c: any) => [c.comp_id, c]));
      const ids = [...compById.keys()];
      const games: Game[] = ids.length ? await allRows(() => sb.from("gaa_games")
        .select("game_id, comp_id, home_team, away_team, home_club_id, away_club_id")
        .in("comp_id", ids).gte("start_at", yearStart).lt("start_at", yearEnd).order("game_id")) : [];
      const sides = new Map<string, { club_id: number; club: string; team: string; grades: Set<string> }>();
      for (const g of games) {
        for (const side of ["home", "away"] as const) {
          const cid = side === "home" ? g.home_club_id : g.away_club_id;
          const name = side === "home" ? g.home_team : g.away_team;
          if (!cid) continue;
          const k = `${cid}|${norm(name)}`;
          if (!sides.has(k)) sides.set(k, { club_id: cid, club: clubById.get(cid)?.name || name, team: name, grades: new Set() });
          const c = compById.get(g.comp_id);
          if (c) sides.get(k)!.grades.add(c.grade || c.name);
        }
      }
      return [...sides.values()].map(x => ({ club_id: x.club_id, club: x.club, team: x.team, grades: [...x.grades].sort() }));
    };

    // ── SIDES: the opposition choices for a code and age ──
    if (action === "sides") {
      const code = String(body.code || ""), age = String(body.age || "");
      if (!code || !age) return json({ error: "code and age required" }, 400);
      const sides = (await sidesIn(code, age)).map(x => ({ ...x, score: oppScore(ev.opposition, x.team, clubById.get(x.club_id)) }))
        .sort((a, b) => b.score - a.score || a.club.localeCompare(b.club) || a.team.localeCompare(b.team));
      return json({ success: true, data: { sides } });
    }

    // ── LINK: the coach picked the two sides ──
    if (action === "link") {
      const code = String(body.code || "").trim(), age = String(body.age || "").trim();
      const ourTeam = String(body.our_team || "").trim();
      const oppTeam = String(body.opp_team || "").trim(), oppClubId = Number(body.opp_club_id);
      if (!code || !age || !ourTeam || !oppTeam || !oppClubId) return json({ error: "Please pick both teams" }, 400);
      const sides = await sidesIn(code, age);
      const ok = (cid: number, name: string) => sides.some(x => x.club_id === cid && norm(x.team) === norm(name));
      if (!ok(ourClubId, ourTeam) || !ok(oppClubId, oppTeam)) return json({ error: "Those teams weren't found in the fixtures" }, 400);
      // The division the coach picked for the opposition gives the league table its competition.
      const grade = String(body.grade || "").trim();
      const { data: comp } = grade
        ? await sb.from("gaa_competitions").select("comp_id").eq("code", code).eq("age", age).eq("grade", grade).limit(1).maybeSingle()
        : { data: null };
      await saveLink(sb, ev, user.id, code, age, ourClubId, ourTeam, oppClubId, oppTeam, comp?.comp_id ?? null, squadKey, club);
    }

    // ── The saved pair for this event ──
    let { data: pair } = await sb.from("scouting_reports").select("*").eq("event_id", eventId).maybeSingle();
    // Relinking shows the picker again; the saved pair (and its notes) stays until a new pair is picked.
    if (action === "relink") pair = null;

    // ── No pair yet: the picker, with our best guess preselected ──
    if (!pair) {
      if (action !== "load" && action !== "relink") return json({ error: "Pick the two teams first" }, 400);

      // Every side our club has fielded this season, in every code and age.
      const { data: ourGames } = await sb.from("gaa_games")
        .select("comp_id, home_team, away_team, home_club_id, away_club_id, gaa_competitions!inner(code, age, grade, name)")
        .or(`home_club_id.eq.${ourClubId},away_club_id.eq.${ourClubId}`)
        .gte("start_at", yearStart).lt("start_at", yearEnd).limit(3000);
      const sides = new Map<string, { code: string; age: string; team: string; grades: Set<string> }>();
      for (const g of ourGames || []) {
        const c = (g as any).gaa_competitions;
        for (const side of ["home", "away"] as const) {
          if ((side === "home" ? g.home_club_id : g.away_club_id) !== ourClubId) continue;
          const name = side === "home" ? g.home_team : g.away_team;
          const k = `${c.code}|${c.age}|${norm(name)}`;
          if (!sides.has(k)) sides.set(k, { code: c.code, age: c.age, team: name, grades: new Set() });
          sides.get(k)!.grades.add(c.grade || c.name);
        }
      }

      // The best guess: the fixture on the event day whose opposition matches what the coach typed,
      // then what this team used last time, then the event's code and the team's age.
      const { data: saved } = await sb.from("scouting_links").select("code, gaa_team, age")
        .eq("team_id", ev.team_id).eq("squad_id", squadKey);
      const savedLink = (saved || []).find((l: any) => l.code === eventCode) || (saved || [])[0] || null;
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
        const grade = g.gaa_competitions.grade || g.gaa_competitions.name;
        const opp = oppScore(ev.opposition, theirs, clubById.get(oppClub));
        const score = opp * 4 + (eventCode && code === eventCode ? 2 : 0) + (teamAge && age === teamAge ? 1 : 0)
          + (savedLink && norm(savedLink.gaa_team) === norm(ours) && savedLink.age === age && savedLink.code === code ? 2 : 0);
        return { code, age, grade, ours, theirs, oppClub, score };
      }).sort((a: any, b: any) => b.score - a.score);
      const top = ranked[0];
      const guess = top && top.score > 0
        ? { code: top.code, age: top.age, grade: top.grade, team: top.ours, opp: { club_id: top.oppClub, team: top.theirs } }
        : savedLink ? { code: savedLink.code, age: savedLink.age, grade: null, team: savedLink.gaa_team, opp: null }
        : eventCode || teamAge ? { code: eventCode, age: teamAge, grade: null, team: null, opp: null } : null;

      const our_options = [...sides.values()].map(x => ({ code: x.code, age: x.age, team: x.team, grades: [...x.grades].sort() }))
        .sort((a, b) => a.code.localeCompare(b.code) || ageRank(a.age) - ageRank(b.age) || a.team.localeCompare(b.team));

      return json({
        success: true,
        data: {
          event: eventInfo, team_name: team?.team_name, squad_name: squad?.squad_name ?? null,
          club: { name: club?.club_name, crest: club?.crest },
          ai_enabled: aiEnabled, link_needed: true, our_options, guess,
        },
      });
    }

    const code: string = pair.code;

    // ── Build the report ──
    const built = await buildFor(sb, pair, code, year, eventStart, pair.comp_id);
    const report = built.report;

    if (action === "summary") {
      if (!aiEnabled) return json({ error: "AI features are not switched on for your account" }, 403);
      const key = JSON.stringify([report.record, report.last_result, report.h2h.length, report.common.length, ev.home_away]);
      if (pair.ai_summary && pair.ai_key === key) return json({ success: true, data: { summary: pair.ai_summary.split("\n") } });
      const apiKey = Deno.env.get("GEMINI_API_KEY");
      if (!apiKey) return json({ error: "GEMINI_API_KEY not configured" }, 500);
      const ha = String(ev.home_away || "").toLowerCase();
      const venue = ha.startsWith("h") ? "at our ground" : ha.startsWith("a") ? "at their ground" : "venue not given";
      const points = await callGemini(apiKey, [
        `Opposition: ${pair.opp_team} (${pair.age} ${code})`,
        `Our team: ${pair.our_team}`,
        `Coming game: ${ev.event_title || ""}, ${venue}`,
        `Scouting data (JSON):`,
        JSON.stringify({ record: report.record, home: report.home, away: report.away, form_newest_first: report.form, games: report.games, common_opponents: report.common, earlier_games_v_us: report.h2h, table: report.table }),
      ].join("\n"));
      await sb.from("scouting_reports").update({ ai_summary: points.join("\n"), ai_key: key, ai_at: new Date().toISOString() }).eq("event_id", eventId);
      return json({ success: true, data: { summary: points } });
    }

    const oppClub = clubById.get(pair.opp_club_id);
    const [matchReports, notesBy] = await Promise.all([
      loadMatchReports(sb, ev, oppClub, pair.opp_team),
      pair.notes_by ? sb.from("users").select("first_name, last_name").eq("user_id", pair.notes_by).maybeSingle().then((r: any) => r.data) : null,
    ]);
    const fx = built.fixture;
    const payload = {
      event: eventInfo, team_name: team?.team_name, squad_name: squad?.squad_name ?? null, code,
      club: { name: club?.club_name, crest: club?.crest },
      ai_enabled: aiEnabled,
      fixture: fx ? { date: fx.start_at, venue: fx.venue || "", home: fx.home_club_id === pair.our_club_id && norm(fx.home_team) === norm(pair.our_team) } : null,
      report,
      match_reports: matchReports,
      notes: pair.notes || "",
      notes_by: notesBy ? `${notesBy.first_name || ""} ${notesBy.last_name || ""}`.trim() : null,
      notes_at: pair.notes_at,
      summary: pair.ai_summary && aiEnabled ? pair.ai_summary.split("\n") : null,
    };

    if (action === "pdf") {
      const format = body.format === "mobile" ? "mobile" : "a4";
      const bytes = await buildScoutingPdf(payload, {
        club_name: club?.club_name || "CoachSmart", crest: club?.crest || null,
        primary_colour: club?.primary_colour || "#1B3A6B", secondary_colour: club?.secondary_colour || "#ED1B2E",
        third_colour: club?.third_colour || null,
      }, format, body.include_notes !== false);
      let b = "";
      for (let i = 0; i < bytes.length; i += 8192) b += String.fromCharCode(...bytes.subarray(i, i + 8192));
      const day = ev.event_date_time ? String(ev.event_date_time).slice(0, 10) : new Date().toISOString().slice(0, 10);
      const filename = `scouting-${norm(pair.opp_team).slice(0, 30)}-${day}.pdf`;
      return json({ pdf: btoa(b), filename });
    }

    if (action === "load" || action === "link" || action === "relink") return json({ success: true, data: payload });
    return json({ error: `Unknown action: ${action}` }, 400);
  } catch (err) {
    console.error("scouting error:", err);
    return json({ error: (err as Error).message || "Something went wrong" }, 500);
  }
});

async function saveLink(sb: any, ev: any, userId: string, code: string, age: string, ourClubId: number, ourTeam: string,
  oppClubId: number, oppTeam: string, compId: string | null, squadKey: number, club: any) {
  await sb.from("scouting_reports").upsert({
    event_id: ev.event_id, code, age, our_club_id: ourClubId, our_team: ourTeam, opp_club_id: oppClubId, opp_team: oppTeam,
    comp_id: compId, created_by: userId, ai_summary: null, ai_key: null,
  }, { onConflict: "event_id" });
  await sb.from("scouting_links").upsert({
    team_id: ev.team_id, squad_id: squadKey, code, gaa_team: ourTeam, age, updated_by: userId, updated_at: new Date().toISOString(),
  }, { onConflict: "team_id,squad_id,code" });
  if (club && !club.gaa_club_id) await sb.from("clubs").update({ gaa_club_id: ourClubId }).eq("club_id", club.club_id);
}

/** The season's results for this age and code, up to the event, and the report built from them. */
async function buildFor(sb: any, pair: any, code: string, year: number, eventStart: Date, compId: string | null) {
  const { data: comps } = await sb.from("gaa_competitions").select("comp_id, name, code, age, grade").eq("code", code).eq("age", pair.age);
  const ids = (comps || []).map((c: Comp) => c.comp_id);
  const until = new Date(Math.min(eventStart.getTime(), Date.now() + 86400e3)).toISOString();
  const games: Game[] = ids.length ? await allRows(() => sb.from("gaa_games").select(GAME_COLS).in("comp_id", ids)
    .gte("start_at", `${year}-01-01`).lt("start_at", until).order("game_id")) : [];
  const us = { club_id: pair.our_club_id, team: pair.our_team, age: pair.age };
  const opp = { club_id: pair.opp_club_id, team: pair.opp_team, age: pair.age };
  const { data: next } = await sb.from("gaa_games").select(GAME_COLS).in("comp_id", ids.length ? ids : ["-"])
    .gte("start_at", new Date(eventStart.getTime() - 12 * 3600e3).toISOString())
    .lte("start_at", new Date(eventStart.getTime() + 12 * 3600e3).toISOString())
    .or(`home_club_id.eq.${pair.our_club_id},away_club_id.eq.${pair.our_club_id}`);
  const fixture = (next || []).find((g: Game) =>
    [g.home_team, g.away_team].map(norm).includes(norm(pair.our_team)) && [g.home_team, g.away_team].map(norm).includes(norm(pair.opp_team))) ?? null;
  const report: Report = buildReport(games, comps || [], us, opp, code, compId ?? fixture?.comp_id);
  return { report, fixture };
}

/** Our team's earlier match reports against this club (last two years), newest first. */
async function loadMatchReports(sb: any, ev: any, oppClub: any, oppTeam: string) {
  const since = new Date(Date.now() - 730 * 86400e3).toISOString();
  const { data: events } = await sb.from("events").select("event_id, event_date_time, opposition")
    .eq("team_id", ev.team_id).gte("event_date_time", since).neq("event_id", ev.event_id);
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

/** Events with an opposition on teams the caller manages (role level 100+), yesterday to six weeks ahead. */
async function listMatches(sb: any, userId: string) {
  const { data: links } = await sb.from("user_member_link").select("member_id").eq("user_id", userId).eq("status", "active");
  const memberIds = (links || []).map((l: any) => l.member_id).filter(Boolean);
  if (!memberIds.length) return { events: [] };
  const { data: mts } = await sb.from("member_team_link").select("member_team_id, team_id").eq("status", "active").in("member_id", memberIds);
  if (!mts?.length) return { events: [] };
  const { data: roles } = await sb.from("member_team_role_link").select("member_team_id, roles!inner(role_level)")
    .in("member_team_id", mts.map((m: any) => m.member_team_id));
  const teamOf = new Map(mts.map((m: any) => [m.member_team_id, m.team_id]));
  const teamIds = [...new Set((roles || []).filter((r: any) => Number(r.roles?.role_level) >= 100).map((r: any) => teamOf.get(r.member_team_id)))];
  if (!teamIds.length) return { events: [] };
  const [{ data: teams }, { data: me }, { data: events }] = await Promise.all([
    sb.from("teams").select("team_id, team_name, scouting").in("team_id", teamIds),
    sb.from("users").select("ai_features").eq("user_id", userId).maybeSingle(),
    sb.from("events").select("event_id, event_title, event_date_time, opposition, home_away, team_id, squads(squad_name)")
      .in("team_id", teamIds).not("opposition", "is", null).neq("opposition", "")
      .gte("event_date_time", new Date(Date.now() - 86400e3).toISOString())
      .lte("event_date_time", new Date(Date.now() + 42 * 86400e3).toISOString())
      .order("event_date_time").limit(60),
  ]);
  const ai = me?.ai_features === true;
  const team = new Map<number, any>((teams || []).map((t: any) => [t.team_id, t]));
  return {
    events: (events || []).filter((e: any) => ai || team.get(e.team_id)?.scouting).map((e: any) => ({
      event_id: e.event_id, title: e.event_title, date: e.event_date_time, opposition: e.opposition, home_away: e.home_away,
      team_name: team.get(e.team_id)?.team_name || "", squad_name: e.squads?.squad_name || null,
    })),
  };
}
