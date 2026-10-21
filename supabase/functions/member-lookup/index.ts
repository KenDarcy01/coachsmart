// deno-lint-ignore-file no-explicit-any
// Member lookup (webviews/member-lookup.html): search every club's teams and members.
//
// Ken only: the caller's JWT must belong to an email in ALLOWED.
// Actions:
//   search { q }        → teams whose name or team code matches, members whose name or codes match
//   team   { team_id }  → the team and every member on it
//   member { member_id } → one member: codes, every team with role and squad, linked users
//   people { q }        → app accounts whose name or email matches, for linking
//   link   { member_id, user_id } → gives that account access to the member (active straight away,
//                                    like an approved member-code request)
//   unlink { user_member_id }     → removes an account's access (the row is deleted, as when a request is denied)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

const ALLOWED = ["ken.darcy@gmail.com"];

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });

/** Search text that is safe inside a PostgREST or() filter. */
const clean = (s: unknown) => String(s ?? "").replace(/[,()%*\\:"']/g, " ").replace(/\s+/g, " ").trim();

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

    const jwt = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
    const { data: { user } } = await sb.auth.getUser(jwt);
    if (!user) return json({ error: "Please sign in" }, 401);
    if (!ALLOWED.includes(String(user.email || "").toLowerCase())) return json({ error: "This page is not available for your account." }, 403);

    const body = await req.json().catch(() => ({}));
    if (body.action === "search") return json(await search(sb, clean(body.q)));
    if (body.action === "team") return json(await team(sb, Number(body.team_id)));
    if (body.action === "member") return json(await member(sb, Number(body.member_id)));
    if (body.action === "people") return json(await people(sb, clean(body.q)));
    if (body.action === "link") return json(await link(sb, Number(body.member_id), String(body.user_id || "")));
    if (body.action === "unlink") return json(await unlink(sb, Number(body.user_member_id)));
    return json({ error: "Unknown action" }, 400);
  } catch (e) {
    console.error(e);
    return json({ error: (e as Error).message || "Something went wrong" }, 500);
  }
});

// ── Lookups ────────────────────────────────────────────────────────────────

async function search(sb: any, q: string) {
  if (q.length < 2) return { teams: [], members: [] };
  const words = q.toLowerCase().split(" ");
  const like = `%${q}%`;

  // Teams: every word in the team or club name, or the team code
  const { data: byCode } = await sb.from("teams").select("team_id").ilike("team_unique_code", like).limit(50);
  const { data: clubHits } = await sb.from("clubs").select("club_id, club_name").or(words.map(w => `club_name.ilike.%${w}%`).join(",")).limit(200);
  const { data: nameHits } = await sb.from("teams").select("team_id, team_name, club_id")
    .or([...words.map(w => `team_name.ilike.%${w}%`), ...(clubHits || []).length ? [`club_id.in.(${(clubHits || []).map((c: any) => c.club_id).join(",")})`] : []].join(","))
    .limit(1000);
  const clubName = new Map((clubHits || []).map((c: any) => [c.club_id, c.club_name.toLowerCase()]));
  const teamIds = new Set<number>((byCode || []).map((t: any) => t.team_id));
  for (const t of nameHits || []) {
    const hay = `${t.team_name || ""} ${clubName.get(t.club_id) || ""}`.toLowerCase();
    if (words.every(w => hay.includes(w))) teamIds.add(t.team_id);
  }
  const teams = await teamRows(sb, [...teamIds].slice(0, 40));

  // Members: every word in the first or last name, or a member code
  const first = words[0];
  const { data: named } = await sb.from("members").select("member_id, first_name, last_name")
    .or(`first_name.ilike.%${first}%,last_name.ilike.%${first}%`).limit(1000);
  const memberIds = new Set<number>((named || [])
    .filter((m: any) => { const hay = `${m.first_name || ""} ${m.last_name || ""}`.toLowerCase(); return words.every(w => hay.includes(w)); })
    .map((m: any) => m.member_id));
  if (!q.includes(" ")) {
    const { data: c1 } = await sb.from("members").select("member_id").ilike("unique_member_code", like).limit(50);
    const { data: c2 } = await sb.from("member_team_link").select("member_id").ilike("member_team_code", like).limit(50);
    [...(c1 || []), ...(c2 || [])].forEach((m: any) => memberIds.add(m.member_id));
  }
  const members = await memberRows(sb, [...memberIds].slice(0, 100));
  return { teams, members, more: memberIds.size > 100 || teamIds.size > 40 };
}

async function teamRows(sb: any, ids: number[]) {
  if (!ids.length) return [];
  const { data: teams } = await sb.from("teams").select("*").in("team_id", ids);
  const clubs = await byId(sb, "clubs", "club_id", (teams || []).map((t: any) => t.club_id));
  const { data: links } = await sb.from("member_team_link").select("team_id, status").in("team_id", ids);
  return (teams || []).map((t: any) => ({
    team_id: t.team_id,
    team_name: t.team_name,
    team_code: t.team_unique_code,
    female: t.team_female,
    club: clubs.get(t.club_id)?.club_name || "",
    members: (links || []).filter((l: any) => l.team_id === t.team_id && l.status !== "inactive").length,
  })).sort((a: any, b: any) => (a.club + a.team_name).localeCompare(b.club + b.team_name));
}

async function team(sb: any, teamId: number) {
  const [t] = await teamRows(sb, [teamId]);
  if (!t) return { error: "Team not found" };
  const { data: links } = await sb.from("member_team_link").select("member_id").eq("team_id", teamId);
  const members = await memberRows(sb, (links || []).map((l: any) => l.member_id), teamId);
  return { team: t, members };
}

async function member(sb: any, memberId: number) {
  const [m] = await memberRows(sb, [memberId]);
  return m ? { member: m } : { error: "Member not found" };
}

async function people(sb: any, q: string) {
  if (q.length < 2) return { people: [] };
  const words = q.toLowerCase().split(" ");
  const first = words[0];
  const { data } = await sb.from("users").select("user_id, first_name, last_name, email_address, phone_number")
    .or(`first_name.ilike.%${first}%,last_name.ilike.%${first}%,email_address.ilike.%${first}%`).limit(500);
  const hits = (data || []).filter((u: any) => {
    const hay = `${u.first_name || ""} ${u.last_name || ""} ${u.email_address || ""}`.toLowerCase();
    return words.every(w => hay.includes(w));
  }).slice(0, 30);
  const ids = hits.map((u: any) => u.user_id);
  const { data: own } = ids.length ? await sb.from("members").select("user_id, first_name, last_name").in("user_id", ids) : { data: [] };
  const { data: uml } = ids.length ? await sb.from("user_member_link").select("user_id, member_id, status").in("user_id", ids) : { data: [] };
  const linked = await byId(sb, "members", "member_id", (uml || []).filter((l: any) => l.status === "active").map((l: any) => l.member_id));
  return {
    people: hits.map((u: any) => ({
      user_id: u.user_id,
      name: `${u.first_name || ""} ${u.last_name || ""}`.trim(),
      email: u.email_address, phone: u.phone_number,
      members: [...new Set([
        ...(own || []).filter((m: any) => m.user_id === u.user_id),
        ...(uml || []).filter((l: any) => l.user_id === u.user_id && l.status === "active").map((l: any) => linked.get(l.member_id)).filter(Boolean),
      ].map((m: any) => `${m.first_name || ""} ${m.last_name || ""}`.trim()))],
    })).sort((a: any, b: any) => a.name.localeCompare(b.name)),
  };
}

async function link(sb: any, memberId: number, userId: string) {
  if (!memberId || !userId) return { error: "Pick a member and an account" };
  const { data: m } = await sb.from("members").select("member_id, user_id").eq("member_id", memberId).maybeSingle();
  if (!m) return { error: "Member not found" };
  if (m.user_id === userId) return { error: "That is this member's own account" };
  const { data: existing } = await sb.from("user_member_link").select("user_member_id, status").eq("member_id", memberId).eq("user_id", userId);
  const active = (existing || []).find((l: any) => l.status === "active");
  if (active) return { error: "Already linked" };
  const pending = (existing || []).find((l: any) => l.status === "pending");
  const { error } = pending
    ? await sb.from("user_member_link").update({ status: "active" }).eq("user_member_id", pending.user_member_id)
    : await sb.from("user_member_link").insert({ user_id: userId, member_id: memberId, status: "active" });
  if (error) return { error: error.message };
  return member(sb, memberId);
}

async function unlink(sb: any, userMemberId: number) {
  const { data: row } = await sb.from("user_member_link").select("member_id").eq("user_member_id", userMemberId).maybeSingle();
  if (!row) return { error: "Link not found" };
  const { error } = await sb.from("user_member_link").delete().eq("user_member_id", userMemberId);
  if (error) return { error: error.message };
  return member(sb, row.member_id);
}

/** Members with their codes, team links (role, squad, status) and linked users. onlyTeam limits the links. */
async function memberRows(sb: any, ids: number[], onlyTeam?: number) {
  ids = [...new Set(ids)].filter(Boolean);
  if (!ids.length) return [];
  const { data: members } = await sb.from("members").select("*").in("member_id", ids);
  let lq = sb.from("member_team_link").select("*").in("member_id", ids);
  if (onlyTeam) lq = lq.eq("team_id", onlyTeam);
  const { data: links } = await lq;
  const linkIds = (links || []).map((l: any) => l.member_team_id);
  const { data: roleLinks } = linkIds.length ? await sb.from("member_team_role_link").select("member_team_id, role_id").in("member_team_id", linkIds) : { data: [] };
  const roles = await byId(sb, "roles", "role_id", (roleLinks || []).map((r: any) => r.role_id));
  const teams = await byId(sb, "teams", "team_id", (links || []).map((l: any) => l.team_id));
  const clubs = await byId(sb, "clubs", "club_id", [...teams.values()].map((t: any) => t.club_id));
  const squads = await byId(sb, "squads", "squad_id", (links || []).map((l: any) => l.squad_id));
  const { data: uml } = await sb.from("user_member_link").select("*").in("member_id", ids);
  const userIds = [...(members || []).map((m: any) => m.user_id), ...(uml || []).map((u: any) => u.user_id)];
  const users = await byId(sb, "users", "user_id", userIds);

  return (members || []).map((m: any) => {
    const userLinks = new Map<string, any>();
    if (m.user_id) userLinks.set(m.user_id, { status: "own account", own: true });
    for (const u of (uml || []).filter((u: any) => u.member_id === m.member_id)) if (!userLinks.has(u.user_id)) userLinks.set(u.user_id, u);
    return {
      member_id: m.member_id,
      name: `${m.first_name || ""} ${m.last_name || ""}`.trim(),
      first_name: m.first_name, last_name: m.last_name,
      member_code: m.unique_member_code,
      date_of_birth: m.date_of_birth,
      membership_num: m.membership_num,
      created_at: m.created_at,
      teams: (links || []).filter((l: any) => l.member_id === m.member_id).map((l: any) => {
        const t = teams.get(l.team_id) || {};
        return {
          team_id: l.team_id,
          team_name: t.team_name || "",
          team_code: t.team_unique_code || "",
          club: clubs.get(t.club_id)?.club_name || "",
          member_team_code: l.member_team_code,
          status: l.status ?? null,
          squad: squads.get(l.squad_id)?.squad_name || "",
          roles: (roleLinks || []).filter((r: any) => r.member_team_id === l.member_team_id)
            .map((r: any) => roles.get(r.role_id)).filter(Boolean)
            .sort((a: any, b: any) => (b.role_grade ?? 0) - (a.role_grade ?? 0))
            .map((r: any) => r.role_name),
        };
      }).sort((a: any, b: any) => (a.club + a.team_name).localeCompare(b.club + b.team_name)),
      users: [...userLinks].map(([id, link]) => {
        const u = users.get(id);
        return u ? {
          user_id: id,
          user_member_id: link.own ? null : link.user_member_id,
          name: `${u.first_name || ""} ${u.last_name || ""}`.trim(),
          email: u.email_address, phone: u.phone_number,
          link: link.status && link.status !== "active" ? link.status : "",
        } : null;
      }).filter(Boolean),
    };
  }).sort((a: any, b: any) => (a.last_name || "").localeCompare(b.last_name || "") || (a.first_name || "").localeCompare(b.first_name || ""));
}

async function byId(sb: any, table: string, key: string, ids: unknown[]) {
  const list = [...new Set(ids.filter((x) => x !== null && x !== undefined))];
  const out = new Map<any, any>();
  for (let i = 0; i < list.length; i += 200) {
    const { data } = await sb.from(table).select("*").in(key, list.slice(i, i + 200));
    (data || []).forEach((r: any) => out.set(r[key], r));
  }
  return out;
}
