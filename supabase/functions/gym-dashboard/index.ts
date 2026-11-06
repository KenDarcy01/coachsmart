// deno-lint-ignore-file no-explicit-any
// Gym activity dashboard (webviews/gym-dashboard/): read-only view of the gym kiosk's check-ins.
//
// Who can see what (Ken, 2026-11-06):
//   - Only team admins: role_grade 100 (roles Admin 100 and SuperUser 110 by role_level).
//   - A SuperUser anywhere in the club, or an Admin of one of the club's S&C teams, sees the whole club.
//   - Any other Admin sees their own team's players only, wherever in the club they checked in.
//   - Full names (admins only). No photos.
//
// Reads event_checkins, events, event_attendance (latest RSVP), member_team_link and roles.
// Writes nothing. The access check is done here, so the page can never ask for more.
//
// Action (POST JSON): load { club_id? } → everything the page needs for the last 12 weeks.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

const TZ = "Europe/Dublin";
const SNC_CODE_NAME = "S&C";
const ADMIN_ROLE_LEVEL = 100;      // role_grade 100 = Admin (level 100) and SuperUser (level 110)
const SUPERUSER_ROLE_LEVEL = 110;
const WEEKS = 12;
const ACCEPT = 3, DECLINE = 4;     // event_response_type

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });

class HttpError extends Error {
  constructor(public status: number, message: string) { super(message); }
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  try {
    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
    const body = await req.json().catch(() => ({}));
    const jwt = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
    const { data: { user } } = await sb.auth.getUser(jwt).catch(() => ({ data: { user: null } } as any));
    if (!user) throw new HttpError(401, "Please sign in");
    if ((body.action || "load") !== "load") throw new HttpError(400, "Unknown action");
    return json(await load(sb, user.id, Number(body.club_id) || 0));
  } catch (e) {
    if (e instanceof HttpError) return json({ error: e.message }, e.status);
    console.error(e);
    return json({ error: "Something went wrong" }, 500);
  }
});

// ── Helpers ────────────────────────────────────────────────────────────────

const dublinDate = (d: Date) => new Intl.DateTimeFormat("en-CA", { timeZone: TZ, year: "numeric", month: "2-digit", day: "2-digit" }).format(d);
const addDays = (date: string, n: number) => { const d = new Date(`${date}T12:00:00Z`); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10); };
/** Monday of the week a Dublin date falls in. */
const monday = (date: string) => addDays(date, -((new Date(`${date}T12:00:00Z`).getUTCDay() + 6) % 7));

/** .in() on a long id list, 300 at a time. */
async function inChunks<T>(ids: (number | string)[], fn: (chunk: any[]) => Promise<{ data: T[] | null; error: any }>) {
  const out: T[] = [];
  for (let i = 0; i < ids.length; i += 300) {
    const { data, error } = await fn(ids.slice(i, i + 300));
    if (error) throw error;
    out.push(...(data || []));
  }
  return out;
}

// ── Load ───────────────────────────────────────────────────────────────────

async function load(sb: any, userId: string, wantClub: number) {
  // The caller's teams and their highest role on each.
  const { data: links } = await sb.from("user_member_link").select("member_id, status").eq("user_id", userId);
  const myMemberIds = (links || []).filter((l: any) => String(l.status || "active").toLowerCase() === "active").map((l: any) => l.member_id);
  const myMtl = myMemberIds.length
    ? (await sb.from("member_team_link").select("member_team_id, team_id").in("member_id", myMemberIds).eq("status", "active")).data || []
    : [];
  const level = new Map<number, number>();   // team_id → caller's highest role level
  if (myMtl.length) {
    const teamOfMt = new Map<number, number>(myMtl.map((r: any) => [r.member_team_id, r.team_id]));
    const { data: rl } = await sb.from("member_team_role_link").select("member_team_id, roles!inner(role_level)").in("member_team_id", [...teamOfMt.keys()]);
    for (const r of rl || []) {
      const t = teamOfMt.get(r.member_team_id)!;
      level.set(t, Math.max(level.get(t) || 0, Number(r.roles?.role_level) || 0));
    }
  }
  const adminTeamIds = [...level].filter(([, l]) => l >= ADMIN_ROLE_LEVEL).map(([t]) => t);
  if (!adminTeamIds.length) throw new HttpError(403, "The gym dashboard is for team admins");

  const { data: adminTeams } = await sb.from("teams").select("team_id, team_name, club_id").in("team_id", adminTeamIds);
  const clubIds = [...new Set((adminTeams || []).map((t: any) => t.club_id).filter(Boolean))] as number[];
  const { data: clubs } = await sb.from("clubs")
    .select("club_id, club_name, crest, primary_colour, secondary_colour, third_colour").in("club_id", clubIds).order("club_name");
  const club = (clubs || []).find((c: any) => c.club_id === wantClub) || (clubs || [])[0];
  if (!club) throw new HttpError(403, "The gym dashboard is for team admins");
  const clubId = club.club_id;

  const { data: code } = await sb.from("event_codes").select("code_id").eq("event_code", SNC_CODE_NAME).maybeSingle();
  const snc = code?.code_id ?? -1;

  // The club's teams, and which of them are S&C teams (same test as the kiosk).
  const { data: clubTeams } = await sb.from("teams").select("team_id, team_name").eq("club_id", clubId);
  const teamName = new Map<number, string>((clubTeams || []).map((t: any) => [t.team_id, t.team_name]));
  const clubTeamIds = [...teamName.keys()];
  const sncTeams = new Set<number>();
  if (clubTeamIds.length && snc > 0) {
    const [ccl, tcl, ev] = await Promise.all([
      sb.from("club_code_link").select("team_id").eq("club_id", clubId).eq("code_id", snc).not("team_id", "is", null),
      inChunks<any>(clubTeamIds, c => sb.from("team_code_link").select("team_id").eq("code_id", snc).in("team_id", c)),
      inChunks<any>(clubTeamIds, c => sb.from("events").select("team_id").eq("event_code_id", snc).in("team_id", c)),
    ]);
    for (const r of [...(ccl.data || []), ...tcl, ...ev]) if (teamName.has(r.team_id)) sncTeams.add(r.team_id);
  }

  const myClubTeams: number[] = (adminTeams || []).filter((t: any) => t.club_id === clubId).map((t: any) => t.team_id as number);
  const clubWide = myClubTeams.some(t => (level.get(t) || 0) >= SUPERUSER_ROLE_LEVEL || sncTeams.has(t));
  // Teams whose players this caller sees.
  const scopeTeams = clubWide ? [...sncTeams] : myClubTeams;

  // Window: 12 full weeks back from this week's Monday, to this Sunday.
  const today = dublinDate(new Date());
  const since = addDays(monday(today), -7 * (WEEKS - 1));
  const until = addDays(monday(today), 6);

  // Members of the scope teams (active links) and their role on each.
  const scopeMtl = await inChunks<any>(scopeTeams, c =>
    sb.from("member_team_link").select("member_team_id, member_id, team_id").in("team_id", c).eq("status", "active"));
  const mtRoles = await inChunks<any>(scopeMtl.map(r => r.member_team_id), c =>
    sb.from("member_team_role_link").select("member_team_id, roles!inner(role_level)").in("member_team_id", c));
  const mtLevel = new Map<number, number>();
  for (const r of mtRoles) mtLevel.set(r.member_team_id, Math.max(mtLevel.get(r.member_team_id) || 0, Number(r.roles?.role_level) || 0));

  type M = { id: number; teams: Set<number>; player: boolean };
  const people = new Map<number, M>();
  const person = (id: number) => { if (!people.has(id)) people.set(id, { id, teams: new Set(), player: false }); return people.get(id)!; };
  for (const r of scopeMtl) {
    const p = person(r.member_id);
    p.teams.add(r.team_id);
    if ((mtLevel.get(r.member_team_id) || 0) < ADMIN_ROLE_LEVEL) p.player = true;   // admins of the team aren't counted as players
  }

  // Check-ins at this club in the window. Club-wide: all of them. Otherwise: only the scope's players.
  const { data: ck, error: ckErr } = await sb.from("event_checkins")
    .select("checkin_id, event_id, team_id, member_id, checked_in_at, checkin_date, method")
    .eq("club_id", clubId).eq("status", "active").gte("checkin_date", since).lte("checkin_date", until)
    .order("checked_in_at").limit(20000);
  if (ckErr) throw ckErr;
  const checkins = (ck || []).filter((c: any) => clubWide || people.has(c.member_id));
  if (clubWide) for (const c of checkins) { const p = person(c.member_id); if (!p.teams.size && c.team_id) p.teams.add(c.team_id); }

  // Sessions: S&C events of the scope teams in the window, plus any event someone in scope checked in to.
  const fromIso = new Date(`${since}T00:00:00Z`).getTime() - 36e5 * 2;
  const toIso = new Date(`${until}T23:59:59Z`).getTime() + 36e5 * 2;
  const sncEvents = scopeTeams.length && snc > 0 ? await inChunks<any>(scopeTeams, c =>
    sb.from("events").select("event_id, event_title, event_date_time, team_id, squad_id, event_code_id, status, location_name")
      .eq("event_code_id", snc).in("team_id", c)
      .gte("event_date_time", new Date(fromIso).toISOString()).lte("event_date_time", new Date(toIso).toISOString())) : [];
  const evById = new Map<number, any>();
  for (const e of sncEvents) if (e.status === "active") evById.set(e.event_id, e);
  const missing = [...new Set(checkins.map((c: any) => c.event_id).filter((id: any) => id && !evById.has(id)))] as number[];
  for (const e of await inChunks<any>(missing, c =>
    sb.from("events").select("event_id, event_title, event_date_time, team_id, squad_id, event_code_id, status, location_name").in("event_id", c))) {
    evById.set(e.event_id, e);
  }
  const events = [...evById.values()].filter(e => e.event_date_time && dublinDate(new Date(e.event_date_time)) >= since && dublinDate(new Date(e.event_date_time)) <= until);

  // Latest RSVP per member per session.
  const rsvps = await inChunks<any>(events.map(e => e.event_id), c =>
    sb.from("event_attendance").select("attendance_id, event_id, member_id, response_id, created_at").in("event_id", c).eq("status", "active"));
  const latest = new Map<string, any>();
  for (const r of rsvps) {
    const k = `${r.event_id}:${r.member_id}`;
    const cur = latest.get(k);
    if (!cur || r.created_at > cur.created_at || (r.created_at === cur.created_at && r.attendance_id > cur.attendance_id)) latest.set(k, r);
  }
  const accepted = new Map<number, number[]>(), declined = new Map<number, number[]>();
  for (const r of latest.values()) {
    // Own-team sessions: everyone who replied. Sessions of other teams: only this caller's players.
    const ev = evById.get(r.event_id);
    const inScope = people.has(r.member_id) || (clubWide && sncTeams.has(ev?.team_id));
    if (!inScope) continue;
    const m = r.response_id === ACCEPT ? accepted : r.response_id === DECLINE ? declined : null;
    if (!m) continue;
    if (!m.has(r.event_id)) m.set(r.event_id, []);
    m.get(r.event_id)!.push(r.member_id);
    const p = person(r.member_id);
    if (!p.teams.size && ev?.team_id) p.teams.add(ev.team_id);
  }
  // Names (full names: the dashboard is for admins only).
  const ids = [...people.keys()];
  const names = await inChunks<any>(ids, c => sb.from("members").select("member_id, first_name, last_name").in("member_id", c));
  const nameOf = new Map<number, string>(names.map((m: any) =>
    [m.member_id, `${String(m.first_name || "").trim()} ${String(m.last_name || "").trim()}`.trim() || "Member"]));

  const teamIds = new Set<number>(scopeTeams);
  for (const p of people.values()) for (const t of p.teams) if (teamName.has(t)) teamIds.add(t);
  for (const e of events) if (teamName.has(e.team_id)) teamIds.add(e.team_id);

  const myName = myMemberIds.length
    ? (await sb.from("members").select("first_name, last_name").in("member_id", myMemberIds).limit(1)).data?.[0] : null;

  return {
    today, since, until, server_time: new Date().toISOString(),
    me: { name: myName ? `${myName.first_name || ""} ${myName.last_name || ""}`.trim() : "" },
    club: { club_id: club.club_id, name: club.club_name, crest: club.crest, colours: [club.primary_colour, club.secondary_colour, club.third_colour] },
    clubs: (clubs || []).map((c: any) => ({ club_id: c.club_id, name: c.club_name })),
    scope: {
      club_wide: clubWide,
      label: clubWide ? "Whole club" : myClubTeams.map(t => teamName.get(t)).filter(Boolean).join(", "),
      teams: scopeTeams,
    },
    teams: [...teamIds].map(t => ({ team_id: t, name: teamName.get(t) || `Team ${t}`, snc: sncTeams.has(t) }))
      .sort((a, b) => a.name.localeCompare(b.name)),
    members: [...people.values()].map(p => ({
      id: p.id, name: nameOf.get(p.id) || "Member", teams: [...p.teams].filter(t => teamName.has(t)), player: p.player,
    })).sort((a, b) => a.name.localeCompare(b.name)),
    events: events.map(e => ({
      event_id: e.event_id,
      title: String(e.event_title || "").trim() || "Session",
      time: e.event_date_time,
      date: dublinDate(new Date(e.event_date_time)),
      team_id: e.team_id,
      snc: e.event_code_id === snc,
      own: clubWide || scopeTeams.includes(e.team_id),
      location: e.location_name || "",
      accepted: accepted.get(e.event_id) || [],
      declined: declined.get(e.event_id) || [],
    })).sort((a, b) => a.time.localeCompare(b.time)),
    checkins: checkins.map((c: any) => ({
      event_id: c.event_id, team_id: c.team_id, member_id: c.member_id, at: c.checked_in_at, date: c.checkin_date, method: c.method,
    })),
  };
}
