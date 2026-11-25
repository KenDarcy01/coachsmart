// deno-lint-ignore-file no-explicit-any
// sponsors (2026-11-25, thread "Explore advertising in CoachSmart").
// Club officers (and SuperUsers) add their club's sponsor and read the reach
// report on coachsmart.app/club/sponsors.html?club=ID. v3 shows the card and
// counts views/taps through the get_my_sponsors / sponsor_seen RPCs.
// Totals only: no person's name or activity is stored or returned.
//
// POST { action, ... } with the user's JWT:
//   club    { club_id, sponsor_id?, month? }  -> club, sponsors, report
//   save    { club_id, sponsor: {...} }       -> saved sponsor
//   logo    { club_id, sponsor_id, image (base64), mime }
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { decode as b64 } from "https://deno.land/std@0.168.0/encoding/base64.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...cors, "Content-Type": "application/json" } });
const ok = (data: unknown) => json({ success: true, data });
const fail = (error: string, status = 400) => json({ success: false, error }, status);

const PUBLIC = "https://gyfporsbdftvtakdvukt.supabase.co/storage/v1/object/public/sponsors/";
const STATUSES = ["draft", "live", "ended"];

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (req.method !== "POST") return fail("Method not allowed", 405);

  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
  const auth = req.headers.get("Authorization") || "";
  const { data: u } = await sb.auth.getUser(auth.replace(/^Bearer\s+/i, ""));
  const user = u?.user;
  if (!user) return fail("Please sign in again.", 401);

  let body: any = {};
  try { body = await req.json(); } catch (_) { /* empty */ }
  const a = String(body.action || "");
  const clubId = Number(body.club_id) || 0;
  if (!clubId) return fail("Open this page from your club's link.");

  const { data: can, error: canErr } = await sb.rpc("sponsor_can_manage", { p_uid: user.id, p_club: clubId });
  if (canErr) return fail("Couldn't check your access. Please try again.", 500);
  if (!can) return fail("This page is for club officers.", 403);

  try {
    if (a === "club") return ok(await clubData(sb, clubId, Number(body.sponsor_id) || null, String(body.month || "")));
    if (a === "save") return ok(await save(sb, clubId, body.sponsor || {}, user.id));
    if (a === "logo") return ok(await logo(sb, clubId, body));
    return fail("Unknown action.");
  } catch (e) {
    return fail((e as Error).message || "Something went wrong.", 400);
  }
});

function dublinMonth(d = new Date()) {
  const s = d.toLocaleDateString("en-CA", { timeZone: "Europe/Dublin" }); // YYYY-MM-DD
  return s.slice(0, 7) + "-01";
}
function addMonths(m: string, n: number) {
  const [y, mo] = m.split("-").map(Number);
  const d = new Date(Date.UTC(y, mo - 1 + n, 1));
  return d.toISOString().slice(0, 10);
}

async function clubData(sb: any, clubId: number, sponsorId: number | null, monthIn: string) {
  const { data: club } = await sb.from("clubs")
    .select("club_id, club_name, crest, primary_colour, secondary_colour").eq("club_id", clubId).maybeSingle();
  if (!club) throw new Error("Club not found.");
  const { data: rows } = await sb.from("club_sponsors").select("*").eq("club_id", clubId).order("sponsor_id", { ascending: false });
  const sponsors = (rows || []).map((s: any) => ({ ...s, logo_url: s.logo_path ? PUBLIC + s.logo_path : "" }));

  const current = dublinMonth();
  const month = /^\d{4}-\d{2}-01$/.test(monthIn) ? monthIn : current;
  const pick = sponsors.find((s: any) => s.sponsor_id === sponsorId)
    || sponsors.find((s: any) => s.status === "live") || sponsors[0] || null;
  if (!pick) return { club, sponsors, report: null, month, current };

  const from6 = addMonths(month, -5), next = addMonths(month, 1);
  const { data: counts } = await sb.from("sponsor_counts").select("day, team_id, placement, views, taps")
    .eq("sponsor_id", pick.sponsor_id).gte("day", from6).lt("day", next);
  const inMonth = (counts || []).filter((c: any) => c.day >= month);

  const byPlacement: Record<string, { views: number; taps: number }> = {
    home: { views: 0, taps: 0 }, event: { views: 0, taps: 0 }, live: { views: 0, taps: 0 } };
  const byTeam = new Map<number, { views: number; taps: number }>();
  let views = 0, taps = 0;
  for (const c of inMonth) {
    views += c.views; taps += c.taps;
    const p = byPlacement[c.placement]; if (p) { p.views += c.views; p.taps += c.taps; }
    const t = byTeam.get(c.team_id) || { views: 0, taps: 0 };
    t.views += c.views; t.taps += c.taps; byTeam.set(c.team_id, t);
  }
  const teamIds = [...byTeam.keys()].filter((t) => t > 0);
  const names = new Map<number, string>();
  if (teamIds.length) {
    const { data: ts } = await sb.from("teams").select("team_id, team_name").in("team_id", teamIds);
    for (const t of ts || []) names.set(t.team_id, t.team_name);
  }
  const teams = [...byTeam.entries()]
    .map(([id, v]) => ({ team_id: id, team_name: id > 0 ? (names.get(id) || "A team") : "Home, all teams", ...v }))
    .sort((x, y) => y.views - x.views);

  // People reached: closed months from the kept totals, the current month
  // from this month's hashed viewer list.
  const { data: kept } = await sb.from("sponsor_reach_month").select("month, people")
    .eq("sponsor_id", pick.sponsor_id).gte("month", from6).lte("month", month);
  const people = new Map<string, number>((kept || []).map((r: any) => [String(r.month).slice(0, 10), r.people]));
  if (month >= current || !people.has(month)) {
    const { count } = await sb.from("sponsor_viewers").select("viewer", { count: "exact", head: true })
      .eq("sponsor_id", pick.sponsor_id).eq("month", month);
    if (count) people.set(month, (people.get(month) || 0) + count);
  }

  const history = [];
  for (let i = 5; i >= 0; i--) {
    const m = addMonths(month, -i), n = addMonths(m, 1);
    const cs = (counts || []).filter((c: any) => c.day >= m && c.day < n);
    history.push({ month: m, views: cs.reduce((s: number, c: any) => s + c.views, 0),
      taps: cs.reduce((s: number, c: any) => s + c.taps, 0), people: people.get(m) || 0 });
  }

  return { club, sponsors, month, current,
    report: { sponsor_id: pick.sponsor_id, views, taps, people: people.get(month) || 0, by_placement: byPlacement, teams, history } };
}

const clip = (v: any, n: number) => (typeof v === "string" ? v.trim().slice(0, n) : "") || null;
const date = (v: any) => (typeof v === "string" && /^\d{4}-\d{2}-\d{2}$/.test(v) ? v : null);

async function save(sb: any, clubId: number, s: any, uid: string) {
  const name = clip(s.name, 80);
  if (!name) throw new Error("Add the sponsor's name.");
  let link = clip(s.link_url, 300);
  if (link && !/^https?:\/\//i.test(link)) link = "https://" + link;
  const colour = typeof s.card_colour === "string" && /^#[0-9a-f]{6}$/i.test(s.card_colour) ? s.card_colour : null;
  const row: any = {
    name, tagline: clip(s.tagline, 60), link_url: link, card_colour: colour,
    status: STATUSES.includes(s.status) ? s.status : "draft",
    on_home: s.on_home !== false, on_events: s.on_events !== false, on_live: s.on_live !== false,
    starts_on: date(s.starts_on), ends_on: date(s.ends_on), updated_at: new Date().toISOString(),
  };
  // One live sponsor per club: going live ends any other live one.
  if (row.status === "live") {
    await sb.from("club_sponsors").update({ status: "ended", updated_at: row.updated_at })
      .eq("club_id", clubId).eq("status", "live").neq("sponsor_id", Number(s.sponsor_id) || 0);
  }
  if (s.sponsor_id) {
    const { data, error } = await sb.from("club_sponsors").update(row)
      .eq("sponsor_id", Number(s.sponsor_id)).eq("club_id", clubId).select().maybeSingle();
    if (error || !data) throw new Error("Couldn't save the sponsor.");
    return data;
  }
  const { data, error } = await sb.from("club_sponsors").insert({ ...row, club_id: clubId, created_by: uid }).select().single();
  if (error) throw new Error("Couldn't add the sponsor.");
  return data;
}

async function logo(sb: any, clubId: number, body: any) {
  const id = Number(body.sponsor_id);
  const { data: s } = await sb.from("club_sponsors").select("sponsor_id").eq("sponsor_id", id).eq("club_id", clubId).maybeSingle();
  if (!s) throw new Error("Save the sponsor first.");
  const mime = String(body.mime || "");
  const ext = mime === "image/png" ? "png" : mime === "image/jpeg" ? "jpg" : mime === "image/webp" ? "webp" : "";
  if (!ext) throw new Error("Use a PNG, JPG or WebP logo.");
  const bytes = b64(String(body.image || ""));
  if (!bytes.length || bytes.length > 2_000_000) throw new Error("The logo must be under 2 MB.");
  const path = `${clubId}/${id}-${Date.now()}.${ext}`;
  const { error } = await sb.storage.from("sponsors").upload(path, bytes, { contentType: mime, upsert: false, cacheControl: "31536000" });
  if (error) throw new Error("Couldn't upload the logo.");
  await sb.from("club_sponsors").update({ logo_path: path, updated_at: new Date().toISOString() }).eq("sponsor_id", id);
  return { logo_url: PUBLIC + path };
}
