// deno-lint-ignore-file no-explicit-any
// Gym attendance kiosk (webviews/gym-kiosk/): the only thing the kiosk tablets talk to.
//
// A tablet is set up once by a club admin (email + password, and they choose a coach PIN).
// The club is fixed at setup: only a club admin signing in again can remove the tablet
// (to move it to another club, remove it and set it up again). After setup the tablet
// holds a random device token (header x-kiosk-token) and never a member's login. The
// tablet can only read today's S&C sessions and member short names for its own club,
// and write check-ins for them.
//
// Writes only to the kiosk's own tables (kiosk_devices, event_checkins). Never touches
// event_attendance (RSVP) or anything else in CoachSmart.
//
// Actions (POST JSON { action, ... }):
//   pair      { email, password, device_name, pin, club_id? } → { token, device_id, club }   (club admins only)
//                (no club_id and the admin has more than one club → { clubs: [...] } to pick from)
//   bootstrap {}                       → club, teams, members (short names), today's events and check-ins
//   checkin   { items: [ { client_uuid, event_id | "auto" | null, member_id | member_code,
//                          method: "tap" | "qr", checked_in_at } ] } → { results: [...] }
//   undo      { client_uuid, pin? }    → undo a check-in (no PIN needed within 5 minutes on the same tablet)
//   coach     { pin }                  → { ok } when the coach PIN is right (opens coach mode)
//   unpair    { email, password }      → retires this tablet's token (an admin of the tablet's club)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

const TZ = "Europe/Dublin";
const SNC_CODE_NAME = "S&C";
const ADMIN_ROLE_LEVEL = 100;          // roles.role_level: Coach 30, Admin 100, SuperUser 110
const SUPERUSER_ROLE_LEVEL = 110;
const SELF_UNDO_MINUTES = 5;
const MAX_ITEMS = 200;
const MAX_AGE_DAYS = 7;                // offline check-ins older than this are refused

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-kiosk-token",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });

class HttpError extends Error {
  constructor(public status: number, message: string, public code = "error") { super(message); }
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  try {
    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
    const body = await req.json().catch(() => ({}));

    if (body.action === "pair") return json(await pair(sb, body));

    const device = await deviceFromToken(sb, req.headers.get("x-kiosk-token") || "");
    switch (body.action) {
      case "bootstrap": return json(await bootstrap(sb, device));
      case "checkin":   return json(await checkin(sb, device, body.items));
      case "undo":      return json(await undo(sb, device, body));
      case "coach":     await requirePin(device, body.pin); return json({ ok: true });
      case "unpair":    return json(await unpair(sb, device, body));
      default:          return json({ error: "Unknown action" }, 400);
    }
  } catch (e) {
    if (e instanceof HttpError) return json({ error: e.message, code: e.code }, e.status);
    console.error(e);
    return json({ error: "Something went wrong" }, 500);
  }
});

// ── Small helpers ──────────────────────────────────────────────────────────

async function sha256(s: string) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(buf)].map(b => b.toString(16).padStart(2, "0")).join("");
}

function randomToken() {
  const b = new Uint8Array(32);
  crypto.getRandomValues(b);
  return [...b].map(x => x.toString(16).padStart(2, "0")).join("");
}

/** YYYY-MM-DD of an instant in Dublin. */
const dublinDate = (d: Date) => new Intl.DateTimeFormat("en-CA", { timeZone: TZ, year: "numeric", month: "2-digit", day: "2-digit" }).format(d);

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const pinHash = (deviceId: number, pin: string) => sha256(`kiosk-pin:${deviceId}:${pin}`);
const validPin = (pin: unknown) => typeof pin === "string" && /^\d{4,6}$/.test(pin);

/** Members on a public screen: first name + surname initial ("Ken D"). Where two would clash, up to
 *  three letters of the surname ("Ken Da" / "Ken Du"); if they still clash (same name), a number. */
function shortNames(rows: { member_id: number; first_name: string | null; last_name: string | null }[]) {
  const clean = (s: string | null) => String(s || "").trim().replace(/\s+/g, " ");
  const people = rows.map(r => ({ id: r.member_id, first: clean(r.first_name), last: clean(r.last_name) }))
    .sort((a, b) => a.id - b.id);
  const make = (p: { first: string; last: string }, n: number) => (p.last ? `${p.first} ${p.last.slice(0, n)}` : p.first).trim() || "Member";
  const out = new Map<number, string>();
  const groups = new Map<string, typeof people>();
  for (const p of people) {
    const k = make(p, 1).toLowerCase();
    if (!groups.has(k)) groups.set(k, []);
    groups.get(k)!.push(p);
  }
  for (const group of groups.values()) {
    if (group.length === 1) { out.set(group[0].id, make(group[0], 1)); continue; }
    // Fewest surname letters (1 to 3) that tell this group apart.
    let n = 1;
    while (n < 3 && new Set(group.map(p => make(p, n).toLowerCase())).size < group.length) n++;
    const counts = new Map<string, number>();
    for (const p of group) counts.set(make(p, n).toLowerCase(), (counts.get(make(p, n).toLowerCase()) || 0) + 1);
    const seen = new Map<string, number>();
    for (const p of group) {
      const name = make(p, n);
      if (counts.get(name.toLowerCase())! > 1) {
        const i = (seen.get(name.toLowerCase()) || 0) + 1;
        seen.set(name.toLowerCase(), i);
        out.set(p.id, `${make(p, 1)} (${i})`);
      } else out.set(p.id, name);
    }
  }
  return out;
}

// ── Device auth ────────────────────────────────────────────────────────────

type Device = { device_id: number; club_id: number; device_name: string; pin_hash: string };

async function deviceFromToken(sb: any, token: string): Promise<Device> {
  if (!/^[0-9a-f]{64}$/.test(token)) throw new HttpError(401, "This tablet is not set up", "unpaired");
  const { data } = await sb.from("kiosk_devices").select("device_id, club_id, device_name, pin_hash, status")
    .eq("token_hash", await sha256(token)).maybeSingle();
  if (!data || data.status !== "active") throw new HttpError(401, "This tablet is not set up", "unpaired");
  await sb.from("kiosk_devices").update({ last_seen_at: new Date().toISOString() }).eq("device_id", data.device_id);
  return data;
}

async function requirePin(device: Device, pin: unknown) {
  if (!validPin(pin) || (await pinHash(device.device_id, pin as string)) !== device.pin_hash) {
    throw new HttpError(403, "Wrong coach PIN", "bad_pin");
  }
}

// ── Pairing ────────────────────────────────────────────────────────────────

/** Which of these teams use the S&C code (team-only club_code_link row, S&C switched on in team_code_link, or S&C events). */
async function sncTeamIds(sb: any, teamIds: number[]) {
  const out = new Set<number>();
  const { data: code } = await sb.from("event_codes").select("code_id").eq("event_code", SNC_CODE_NAME).maybeSingle();
  if (!code || !teamIds.length) return out;
  const { data: ccl } = await sb.from("club_code_link").select("team_id").eq("code_id", code.code_id).in("team_id", teamIds);
  for (const r of ccl || []) out.add(r.team_id);
  const { data: tcl } = await sb.from("team_code_link").select("team_id").eq("code_id", code.code_id).in("team_id", teamIds);
  for (const r of tcl || []) out.add(r.team_id);
  const { data: ev } = await sb.from("events").select("team_id").eq("event_code_id", code.code_id).in("team_id", teamIds);
  for (const r of ev || []) out.add(r.team_id);
  return out;
}

/** Signs in with CoachSmart email + password; returns the user and the clubs they may manage tablets for. */
async function adminClubs(sb: any, body: any) {
  const email = String(body.email || "").trim();
  const password = String(body.password || "");
  if (!email || !password) throw new HttpError(400, "Enter your CoachSmart email and password");

  const anon = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, { auth: { persistSession: false } });
  const { data: auth, error } = await anon.auth.signInWithPassword({ email, password });
  if (error || !auth?.user) throw new HttpError(401, "That email and password didn't work", "bad_login");
  const userId = auth.user.id;

  // Clubs this user may set up a tablet for: SuperUser on any of its teams, or Admin of one of its S&C teams.
  const { data: links } = await sb.from("user_member_link").select("member_id, status").eq("user_id", userId);
  const memberIds = (links || []).filter((l: any) => String(l.status || "active").toLowerCase() === "active").map((l: any) => l.member_id);
  const clubIds = new Set<number>();
  if (memberIds.length) {
    const { data: mtl } = await sb.from("member_team_link").select("member_team_id, team_id, status").in("member_id", memberIds);
    const active = (mtl || []).filter((r: any) => r.status === "active");
    const mtIds = active.map((r: any) => r.member_team_id);
    if (mtIds.length) {
      const { data: roleLinks } = await sb.from("member_team_role_link").select("member_team_id, roles(role_level)").in("member_team_id", mtIds);
      const level = new Map<number, number>();   // member_team_id → highest role level
      for (const r of roleLinks || []) level.set(r.member_team_id, Math.max(level.get(r.member_team_id) || 0, r.roles?.role_level || 0));
      const adminTeams = active.filter((r: any) => (level.get(r.member_team_id) || 0) >= ADMIN_ROLE_LEVEL);
      if (adminTeams.length) {
        const sncTeams = await sncTeamIds(sb, adminTeams.map((r: any) => r.team_id));
        const { data: teams } = await sb.from("teams").select("team_id, club_id").in("team_id", adminTeams.map((r: any) => r.team_id));
        const clubOf = new Map((teams || []).map((t: any) => [t.team_id, t.club_id]));
        for (const r of adminTeams) {
          const club = clubOf.get(r.team_id);
          // A SuperUser anywhere in the club, or an Admin of one of the club's S&C teams.
          if (club && ((level.get(r.member_team_id) || 0) >= SUPERUSER_ROLE_LEVEL || sncTeams.has(r.team_id))) clubIds.add(club as number);
        }
      }
    }
  }
  return { userId, clubIds };
}

async function pair(sb: any, body: any) {
  const deviceName = String(body.device_name || "").trim().slice(0, 60) || "Gym tablet";
  if (!validPin(body.pin)) throw new HttpError(400, "Choose a coach PIN of 4 to 6 digits");
  const { userId, clubIds } = await adminClubs(sb, body);
  if (!clubIds.size) throw new HttpError(403, "Only club admins can set up a gym tablet", "not_admin");

  const { data: clubs } = await sb.from("clubs").select("club_id, club_name, crest").in("club_id", [...clubIds]).order("club_name");
  const chosen = body.club_id ? (clubs || []).find((c: any) => c.club_id === Number(body.club_id)) : (clubs || []).length === 1 ? clubs[0] : null;
  if (!chosen) return { clubs: (clubs || []).map((c: any) => ({ club_id: c.club_id, name: c.club_name, crest: c.crest })) };

  const token = randomToken();
  const { data: dev, error: insErr } = await sb.from("kiosk_devices")
    .insert({ club_id: chosen.club_id, device_name: deviceName, token_hash: await sha256(token), pin_hash: "pending", paired_by: userId })
    .select("device_id").single();
  if (insErr) throw insErr;
  await sb.from("kiosk_devices").update({ pin_hash: await pinHash(dev.device_id, body.pin) }).eq("device_id", dev.device_id);
  return { token, device_id: dev.device_id, club: { club_id: chosen.club_id, name: chosen.club_name } };
}

/** Removing a tablet (e.g. to move it to another club) needs an admin of its club, not the coach PIN. */
async function unpair(sb: any, device: Device, body: any) {
  const { clubIds } = await adminClubs(sb, body);
  if (!clubIds.has(device.club_id)) throw new HttpError(403, "Only an admin of this club can remove the tablet", "not_admin");
  await sb.from("kiosk_devices").update({ status: "unpaired" }).eq("device_id", device.device_id);
  return { ok: true };
}

// ── Club context: S&C teams, squads, members ──────────────────────────────

type Ctx = {
  snc: number;
  club: any;
  teams: { team_id: number; name: string; juvenile: boolean; squads: { squad_id: number; name: string; colour: string | null }[] }[];
  members: Map<number, { id: number; name: string; teams: number[]; squads: number[] }>;
};

async function clubContext(sb: any, clubId: number): Promise<Ctx> {
  const { data: code } = await sb.from("event_codes").select("code_id").eq("event_code", SNC_CODE_NAME).maybeSingle();
  if (!code) throw new HttpError(500, "No S&C event code found");
  const snc = code.code_id;

  const { data: club } = await sb.from("clubs")
    .select("club_id, club_name, crest, primary_colour, secondary_colour, third_colour").eq("club_id", clubId).single();

  const { data: clubTeams } = await sb.from("teams").select("team_id, team_name, team_juvenile").eq("club_id", clubId);
  const clubTeamIds = (clubTeams || []).map((t: any) => t.team_id);
  const sncTeamIds = new Set<number>();
  if (clubTeamIds.length) {
    const { data: ccl } = await sb.from("club_code_link").select("team_id").eq("club_id", clubId).eq("code_id", snc).not("team_id", "is", null);
    for (const r of ccl || []) sncTeamIds.add(r.team_id);
    const { data: tcl } = await sb.from("team_code_link").select("team_id").eq("code_id", snc).in("team_id", clubTeamIds);
    for (const r of tcl || []) sncTeamIds.add(r.team_id);
    const { data: ev } = await sb.from("events").select("team_id").eq("event_code_id", snc).in("team_id", clubTeamIds);
    for (const r of ev || []) sncTeamIds.add(r.team_id);
  }
  const teamIds = [...sncTeamIds];

  const members: Ctx["members"] = new Map();
  let squads: any[] = [];
  if (teamIds.length) {
    const { data: sq } = await sb.from("squads").select("squad_id, team_id, squad_name, squad_colour, squad_list_seq").in("team_id", teamIds);
    squads = (sq || []).sort((a: any, b: any) => (a.squad_list_seq ?? 999) - (b.squad_list_seq ?? 999));

    const { data: mtl } = await sb.from("member_team_link").select("member_id, team_id").in("team_id", teamIds).eq("status", "active");
    const ids = [...new Set((mtl || []).map((r: any) => r.member_id))];
    const people: any[] = [];
    for (let i = 0; i < ids.length; i += 500) {
      const { data } = await sb.from("members").select("member_id, first_name, last_name").in("member_id", ids.slice(i, i + 500)).eq("status", "active");
      people.push(...(data || []));
    }
    const names = shortNames(people);
    for (const p of people) members.set(p.member_id, { id: p.member_id, name: names.get(p.member_id)!, teams: [], squads: [] });
    for (const r of mtl || []) { const m = members.get(r.member_id); if (m && !m.teams.includes(r.team_id)) m.teams.push(r.team_id); }

    const { data: msl } = await sb.from("member_squad_link").select("member_id, squad_id").in("team_id", teamIds).eq("code_id", snc);
    for (const r of msl || []) { const m = members.get(r.member_id); if (m && r.squad_id && !m.squads.includes(r.squad_id)) m.squads.push(r.squad_id); }
  }

  const teams = (clubTeams || []).filter((t: any) => sncTeamIds.has(t.team_id)).map((t: any) => ({
    team_id: t.team_id,
    name: t.team_name,
    juvenile: !!t.team_juvenile,
    squads: squads.filter(s => s.team_id === t.team_id).map(s => ({ squad_id: s.squad_id, name: s.squad_name, colour: s.squad_colour })),
  }));

  return { snc, club, teams, members };
}

/** S&C events for the club's S&C teams on a Dublin date. */
async function eventsOn(sb: any, ctx: Ctx, date: string) {
  const teamIds = ctx.teams.map(t => t.team_id);
  if (!teamIds.length) return [];
  const mid = new Date(`${date}T12:00:00Z`).getTime();
  const { data } = await sb.from("events")
    .select("event_id, event_title, event_date_time, team_id, squad_id, location_name, status")
    .eq("event_code_id", ctx.snc).in("team_id", teamIds)
    .gte("event_date_time", new Date(mid - 36 * 3600e3).toISOString())
    .lte("event_date_time", new Date(mid + 36 * 3600e3).toISOString())
    .order("event_date_time");
  return (data || []).filter((e: any) => e.status === "active" && e.event_date_time && dublinDate(new Date(e.event_date_time)) === date);
}

// ── Bootstrap: everything the tablet needs for today ──────────────────────

async function bootstrap(sb: any, device: Device) {
  const ctx = await clubContext(sb, device.club_id);
  const today = dublinDate(new Date());
  const events = await eventsOn(sb, ctx, today);
  const { data: checkins } = await sb.from("event_checkins")
    .select("checkin_id, client_uuid, event_id, member_id, checked_in_at, method, device_id")
    .eq("club_id", device.club_id).eq("checkin_date", today).eq("status", "active");

  const c = ctx.club;
  return {
    today,
    server_time: new Date().toISOString(),
    device: { device_id: device.device_id, name: device.device_name },
    club: { club_id: c.club_id, name: c.club_name, crest: c.crest, colours: [c.primary_colour, c.secondary_colour, c.third_colour] },
    teams: ctx.teams,
    members: [...ctx.members.values()].sort((a, b) => a.name.localeCompare(b.name)),
    events: events.map((e: any) => ({
      event_id: e.event_id, title: (e.event_title || "").trim() || "S&C", time: e.event_date_time,
      team_id: e.team_id, squad_id: e.squad_id, location: e.location_name || "",
    })),
    checkins: checkins || [],
  };
}

// ── Check-ins ─────────────────────────────────────────────────────────────

async function checkin(sb: any, device: Device, items: unknown) {
  if (!Array.isArray(items) || !items.length) throw new HttpError(400, "No check-ins sent");
  if (items.length > MAX_ITEMS) throw new HttpError(400, `At most ${MAX_ITEMS} check-ins at a time`);

  const ctx = await clubContext(sb, device.club_id);
  const eventsByDate = new Map<string, any[]>();
  const events = async (date: string) => {
    if (!eventsByDate.has(date)) eventsByDate.set(date, await eventsOn(sb, ctx, date));
    return eventsByDate.get(date)!;
  };

  const results = [];
  for (const raw of items as any[]) {
    try {
      results.push(await checkinOne(sb, device, ctx, events, raw));
    } catch (e) {
      const msg = e instanceof HttpError ? e.message : "Couldn't save this check-in";
      const code = e instanceof HttpError ? e.code : "error";
      if (!(e instanceof HttpError)) console.error(e);
      results.push({ client_uuid: raw?.client_uuid, ok: false, code, error: msg });
    }
  }
  return { results };
}

async function checkinOne(sb: any, device: Device, ctx: Ctx, events: (d: string) => Promise<any[]>, raw: any) {
  const clientUuid = String(raw?.client_uuid || "");
  if (!UUID_RE.test(clientUuid)) throw new HttpError(400, "Bad check-in id", "bad_request");

  // Already received (an offline replay)? Report what was stored.
  const { data: seen } = await sb.from("event_checkins").select("checkin_id, event_id, member_id, status").eq("client_uuid", clientUuid).maybeSingle();
  if (seen) return done(ctx, clientUuid, seen, { duplicate: true });

  const method = raw.method === "qr" ? "qr" : "tap";
  const at = new Date(raw.checked_in_at || Date.now());
  const now = Date.now();
  if (isNaN(at.getTime()) || at.getTime() > now + 10 * 60e3 || at.getTime() < now - MAX_AGE_DAYS * 864e5) {
    throw new HttpError(400, "The tablet's clock looks wrong", "bad_time");
  }
  const date = dublinDate(at);

  // Who
  let memberId = Number(raw.member_id) || 0;
  if (!memberId && raw.member_code) {
    const code = String(raw.member_code).trim().toUpperCase().replace(/^CS[-:]?/, "");
    if (!/^[A-Z0-9]{4,12}$/.test(code)) throw new HttpError(404, "That QR code isn't a CoachSmart member code", "unknown_code");
    const { data: m } = await sb.from("members").select("member_id").eq("unique_member_code", code).eq("status", "active").maybeSingle();
    memberId = m?.member_id || 0;
    if (!memberId) throw new HttpError(404, "That QR code isn't a CoachSmart member code", "unknown_code");
  }
  const member = ctx.members.get(memberId);
  if (!member) throw new HttpError(403, "This member isn't on one of the club's S&C teams", "not_in_club");

  // Which session
  let event: any = null;
  let converted = false;
  const todays = await events(date);
  if (raw.event_id === "auto") {
    const mine = todays.filter((e: any) => member.teams.includes(e.team_id));
    const score = (e: any) => (e.squad_id && member.squads.includes(e.squad_id) ? 0 : e.squad_id ? 2 : 1) * 1e12
      + Math.abs(new Date(e.event_date_time).getTime() - at.getTime());
    event = mine.sort((a: any, b: any) => score(a) - score(b))[0] || null;
  } else if (raw.event_id !== null && raw.event_id !== undefined && raw.event_id !== "") {
    event = todays.find((e: any) => e.event_id === Number(raw.event_id)) || null;
    if (!event) throw new HttpError(404, "That session isn't on today", "no_event");
    if (!member.teams.includes(event.team_id)) { event = null; converted = true; }  // not their team → Open gym
  }

  const row = {
    client_uuid: clientUuid,
    event_id: event?.event_id ?? null,
    club_id: device.club_id,
    team_id: event?.team_id ?? (member.teams.length === 1 ? member.teams[0] : null),
    member_id: memberId,
    checked_in_at: at.toISOString(),
    checkin_date: date,
    method,
    device_id: device.device_id,
  };
  const { data: ins, error } = await sb.from("event_checkins").insert(row).select("checkin_id, event_id, member_id, status").single();
  if (!error) return done(ctx, clientUuid, ins, { converted });

  if (error.code === "23505") {
    // Already checked in to this session (or Open gym today) from another tablet or tap.
    let q = sb.from("event_checkins").select("checkin_id, client_uuid, event_id, member_id, status").eq("member_id", memberId).eq("status", "active");
    q = row.event_id ? q.eq("event_id", row.event_id) : q.is("event_id", null).eq("club_id", device.club_id).eq("checkin_date", date);
    const { data: existing } = await q.maybeSingle();
    if (existing) return done(ctx, clientUuid, existing, { already: true, converted, original_client_uuid: existing.client_uuid });
    const { data: replay } = await sb.from("event_checkins").select("checkin_id, event_id, member_id, status").eq("client_uuid", clientUuid).maybeSingle();
    if (replay) return done(ctx, clientUuid, replay, { duplicate: true });
  }
  throw error;
}

function done(ctx: Ctx, clientUuid: string, row: any, extra: Record<string, unknown>) {
  return {
    client_uuid: clientUuid,
    ok: row.status === "active",
    checkin_id: row.checkin_id,
    event_id: row.event_id,
    member_id: row.member_id,
    name: ctx.members.get(row.member_id)?.name || "",
    ...extra,
  };
}

async function undo(sb: any, device: Device, body: any) {
  const clientUuid = String(body.client_uuid || "");
  if (!UUID_RE.test(clientUuid)) throw new HttpError(400, "Bad check-in id", "bad_request");
  const { data: row } = await sb.from("event_checkins").select("checkin_id, club_id, device_id, created_at, status").eq("client_uuid", clientUuid).maybeSingle();
  if (!row || row.club_id !== device.club_id) throw new HttpError(404, "Check-in not found", "not_found");
  if (row.status !== "active") return { ok: true };

  const recentHere = row.device_id === device.device_id && Date.now() - new Date(row.created_at).getTime() < SELF_UNDO_MINUTES * 60e3;
  if (!recentHere) await requirePin(device, body.pin);

  await sb.from("event_checkins").update({ status: "undone", undone_at: new Date().toISOString() }).eq("checkin_id", row.checkin_id);
  return { ok: true };
}
