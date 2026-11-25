// deno-lint-ignore-file no-explicit-any
// spend (2026-11-23, thread "Explore coach expenses and gear orders").
// Coaches log expenses (with a receipt photo the AI reads) and request gear
// from the club's stock list in v3; club officers approve, mark paid back,
// group gear orders and set team budgets on coachsmart.app/club/spend.html.
// Records only: CoachSmart never moves club money.
//
// POST { action, ... } with the user's JWT. Everyone needs a spend_access row
// (Ken only while it is tried). Team actions: team admins (role grade 100)
// or the club's officers. Club actions: club officers (or SuperUsers).
//   team          { team_id }            -> budget, items, stock list, events
//   read_receipt  { team_id, image, mime } -> stores the photo, AI reads it
//   add_expense   { team_id, amount, spent_on, shop, category, note, payback, event_id, receipt_path }
//   add_gear      { team_id, note, lines: [{ item_id?, name?, qty }] }
//   withdraw      { kind: 'expense'|'gear', id } (own, still waiting)
//   receipt_url   { expense_id }         -> short signed link
//   club          { club_id, season }    -> everything for the club page
//   decide        { kind, id, move, note }  move: approve|query|reject|paid|ordered|delivered|reopen
//   set_budget    { team_id, season, amount }
//   save_item     { club_id, item: { gear_item_id?, name, category, unit_price, detail } }
//   remove_item   { club_id, gear_item_id }
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

const CATEGORIES = ["Ref fee", "Pitch hire", "Travel", "Match day food", "Entry fee", "Equipment", "Other"];
const SPENT_EXP = ["approved", "paid"];
const SPENT_GEAR = ["approved", "ordered", "delivered"];

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (req.method !== "POST") return fail("Method not allowed", 405);

  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
  const auth = req.headers.get("Authorization") || "";
  const { data: u } = await sb.auth.getUser(auth.replace(/^Bearer\s+/i, ""));
  const user = u?.user;
  if (!user) return fail("Please sign in again.", 401);

  // spend_access (Ken) opens everything; otherwise a club officer with the
  // "Spend & gear" tick on the club officers page (Ken 2026-11-25) can use
  // the club side for that club only.
  const { data: acc } = await sb.from("spend_access").select("user_id").eq("user_id", user.id).maybeSingle();
  const hasAccess = !!acc;

  let body: any = {};
  try { body = await req.json(); } catch (_) { /* empty */ }
  const a = String(body.action || "");
  const CLUB_SIDE = ["club", "decide", "set_budget", "save_item", "remove_item", "receipt_url"];
  if (!hasAccess && !CLUB_SIDE.includes(a)) return fail("Spend and gear isn't switched on for your account yet.", 403);

  try {
    const roles = await myRoles(sb, user.id);

    // ── Team side (v3 app) ─────────────────────────────────────────────
    if (["team", "read_receipt", "add_expense", "add_gear"].includes(a)) {
      const team = await teamOf(sb, Number(body.team_id));
      if (!team) return fail("Team not found.", 404);
      const isOfficer = await clubOfficer(sb, user.id, hasAccess, team.club_id, roles);
      if (!roles.adminTeams.has(team.team_id) && !isOfficer) return fail("Only team admins can use spend and gear.", 403);

      if (a === "team") return ok(await teamData(sb, team, user.id, isOfficer));
      if (a === "read_receipt") return ok(await readReceipt(sb, team, body));
      if (a === "add_expense") {
        const amount = Math.round(Number(body.amount) * 100) / 100;
        if (!(amount > 0 && amount < 100000)) return fail("Type the amount.");
        const spentOn = /^\d{4}-\d{2}-\d{2}$/.test(body.spent_on || "") ? body.spent_on : new Date().toISOString().slice(0, 10);
        const category = CATEGORIES.includes(body.category) ? body.category : "Other";
        const payback = ["bank", "cash", "none"].includes(body.payback) ? body.payback : "bank";
        let receipt: string | null = typeof body.receipt_path === "string" ? body.receipt_path : null;
        if (receipt && !receipt.startsWith(`${team.club_id ?? 0}/${team.team_id}/`)) receipt = null;
        let eventId: number | null = Number(body.event_id) || null;
        if (eventId) {
          const { data: ev } = await sb.from("events").select("team_id").eq("event_id", eventId).maybeSingle();
          if (ev?.team_id !== team.team_id) eventId = null;
        }
        let aiRead: any = null;
        if (receipt && body.ai_read && typeof body.ai_read === "object") aiRead = body.ai_read;
        const { data, error } = await sb.from("team_expenses").insert({
          team_id: team.team_id, club_id: team.club_id, event_id: eventId, created_by: user.id,
          spent_on: spentOn, amount, shop: clip(body.shop, 80), category, note: clip(body.note, 500),
          payback, receipt_path: receipt, ai_read: aiRead,
        }).select("expense_id").single();
        if (error) throw error;
        return ok({ expense_id: data.expense_id });
      }
      if (a === "add_gear") {
        const lines = Array.isArray(body.lines) ? body.lines : [];
        const { data: items } = await sb.from("gear_items").select("gear_item_id, name, unit_price")
          .eq("club_id", team.club_id ?? -1).eq("is_active", true);
        const byId = new Map((items || []).map((i: any) => [i.gear_item_id, i]));
        const rows: any[] = [];
        for (const l of lines.slice(0, 40)) {
          const qty = Math.round(Number(l.qty));
          if (!(qty >= 1 && qty <= 999)) continue;
          const it: any = byId.get(Number(l.item_id));
          if (it) rows.push({ gear_item_id: it.gear_item_id, name: it.name, qty, unit_price: it.unit_price });
          else if (clip(l.name, 120)) rows.push({ gear_item_id: null, name: clip(l.name, 120), qty, unit_price: null });
        }
        if (!rows.length) return fail("Pick at least one item.");
        const { data: r, error } = await sb.from("gear_requests").insert({
          team_id: team.team_id, club_id: team.club_id, created_by: user.id, note: clip(body.note, 500),
        }).select("gear_request_id").single();
        if (error) throw error;
        const { error: e2 } = await sb.from("gear_request_lines").insert(rows.map((x) => ({ ...x, gear_request_id: r.gear_request_id })));
        if (e2) { await sb.from("gear_requests").delete().eq("gear_request_id", r.gear_request_id); throw e2; }
        return ok({ gear_request_id: r.gear_request_id });
      }
    }

    if (a === "withdraw") {
      const isExp = body.kind === "expense";
      const tbl = isExp ? "team_expenses" : "gear_requests";
      const idc = isExp ? "expense_id" : "gear_request_id";
      const { data, error } = await sb.from(tbl).update({ deleted_at: new Date().toISOString() })
        .eq(idc, Number(body.id)).eq("created_by", user.id).in("status", isExp ? ["submitted", "queried"] : ["requested", "queried"])
        .is("deleted_at", null).select(idc);
      if (error) throw error;
      if (!data?.length) return fail("Only your own items that are still waiting can be taken back.");
      return ok({});
    }

    if (a === "receipt_url") {
      const { data: e } = await sb.from("team_expenses").select("team_id, club_id, receipt_path").eq("expense_id", Number(body.expense_id)).maybeSingle();
      if (!e?.receipt_path) return fail("No receipt for this one.", 404);
      if (!(hasAccess && roles.adminTeams.has(e.team_id)) && !(await clubOfficer(sb, user.id, hasAccess, e.club_id, roles))) return fail("Not allowed.", 403);
      const { data: s, error } = await sb.storage.from("receipts").createSignedUrl(e.receipt_path, 600);
      if (error) throw error;
      return ok({ url: s.signedUrl });
    }

    // ── Club side (club page) ──────────────────────────────────────────
    if (["club", "decide", "set_budget", "save_item", "remove_item"].includes(a)) {
      let clubId = Number(body.club_id) || null;
      let target: any = null;
      if (a === "decide") {
        const isExp = body.kind === "expense";
        const { data } = await sb.from(isExp ? "team_expenses" : "gear_requests").select("*")
          .eq(isExp ? "expense_id" : "gear_request_id", Number(body.id)).is("deleted_at", null).maybeSingle();
        if (!data) return fail("Not found.", 404);
        target = data; clubId = data.club_id;
      }
      if (a === "set_budget") {
        const t = await teamOf(sb, Number(body.team_id));
        if (!t) return fail("Team not found.", 404);
        clubId = t.club_id;
      }
      if (!clubId || !(await clubOfficer(sb, user.id, hasAccess, clubId, roles))) return fail("This page is for club officers.", 403);

      if (a === "club") return ok(await clubData(sb, clubId, Number(body.season) || new Date().getFullYear()));
      if (a === "decide") return ok(await decide(sb, user.id, body, target));
      if (a === "set_budget") {
        const amount = Number(body.amount);
        const season = Number(body.season) || new Date().getFullYear();
        if (body.amount === null || body.amount === "" || !(amount >= 0)) {
          await sb.from("spend_budgets").delete().eq("team_id", Number(body.team_id)).eq("season", season);
        } else {
          const { error } = await sb.from("spend_budgets").upsert({ team_id: Number(body.team_id), season, amount: Math.round(amount * 100) / 100, set_by: user.id, set_at: new Date().toISOString() });
          if (error) throw error;
        }
        return ok({});
      }
      if (a === "save_item") {
        const it = body.item || {};
        const row: any = {
          club_id: clubId, name: clip(it.name, 120), category: clip(it.category, 40) || "Other",
          unit_price: it.unit_price === "" || it.unit_price == null || isNaN(Number(it.unit_price)) ? null : Math.round(Number(it.unit_price) * 100) / 100,
          detail: clip(it.detail, 120),
        };
        if (!row.name) return fail("Give the item a name.");
        if (it.gear_item_id) {
          const { error } = await sb.from("gear_items").update(row).eq("gear_item_id", Number(it.gear_item_id)).eq("club_id", clubId);
          if (error) throw error;
        } else {
          const { error } = await sb.from("gear_items").insert({ ...row, sort: 1000 });
          if (error) throw error;
        }
        return ok({});
      }
      if (a === "remove_item") {
        const { error } = await sb.from("gear_items").update({ is_active: false }).eq("gear_item_id", Number(body.gear_item_id)).eq("club_id", clubId);
        if (error) throw error;
        return ok({});
      }
    }
    return fail("Unknown action.");
  } catch (e) {
    console.error("spend", a, e);
    return fail("Something went wrong. Please try again.", 500);
  }
});

const clip = (s: any, n: number) => (typeof s === "string" && s.trim() ? s.trim().slice(0, n) : null);

async function teamOf(sb: any, teamId: number) {
  if (!Number.isInteger(teamId) || teamId <= 0) return null;
  const { data } = await sb.from("teams").select("team_id, team_name, club_id").eq("team_id", teamId).maybeSingle();
  return data;
}

// Teams where the user holds an active admin-grade role, and whether they
// are a SuperUser (role level 110+ anywhere), same rules as is_team_admin
// and is_app_super_user.
async function myRoles(sb: any, userId: string) {
  const out = { adminTeams: new Set<number>(), superUser: false };
  const { data: links } = await sb.from("user_member_link").select("member_id, status").eq("user_id", userId);
  const memberIds = (links || []).filter((l: any) => (l.status ?? "active") === "active").map((l: any) => l.member_id);
  const { data: own } = await sb.from("members").select("member_id").eq("user_id", userId);
  for (const m of own || []) if (!memberIds.includes(m.member_id)) memberIds.push(m.member_id);
  if (!memberIds.length) return out;
  const { data: mtl } = await sb.from("member_team_link").select("member_team_id, team_id")
    .eq("status", "active").in("member_id", memberIds);
  if (!mtl?.length) return out;
  const teamOfMt = new Map(mtl.map((r: any) => [r.member_team_id, r.team_id]));
  const { data: rl } = await sb.from("member_team_role_link").select("member_team_id, roles(role_grade, role_level)")
    .in("member_team_id", [...teamOfMt.keys()]);
  for (const r of rl || []) {
    if (Number(r.roles?.role_grade) === 100) out.adminTeams.add(teamOfMt.get(r.member_team_id) as number);
    if (Number(r.roles?.role_level) >= 110) out.superUser = true;
  }
  return out;
}

// Club side: an officer of the club with the Spend & gear tick, or (for
// spend_access holders) a SuperUser or an officer with the dashboard tick.
async function clubOfficer(sb: any, userId: string, hasAccess: boolean, clubId: number | null, roles: any) {
  if (hasAccess && roles.superUser) return true;
  if (!clubId) return false;
  const { data } = await sb.from("club_officers").select("can_spend, can_dashboard")
    .eq("club_id", clubId).eq("user_id", userId).eq("is_active", true).limit(1);
  const o = data?.[0];
  return !!o && (o.can_spend || (hasAccess && o.can_dashboard));
}

async function names(sb: any, ids: string[]) {
  const uniq = [...new Set(ids.filter(Boolean))];
  if (!uniq.length) return new Map();
  const { data } = await sb.from("users").select("user_id, first_name, last_name").in("user_id", uniq);
  return new Map((data || []).map((r: any) => [r.user_id, [r.first_name, r.last_name ? r.last_name[0] : ""].filter(Boolean).join(" ").trim() || "A coach"]));
}

const money = (n: any) => Math.round(Number(n || 0) * 100) / 100;
const gearTotal = (lines: any[]) => money(lines.reduce((s, l) => s + (l.unit_price == null ? 0 : Number(l.unit_price) * l.qty), 0));

async function teamData(sb: any, team: any, userId: string, isOfficer: boolean) {
  const season = new Date().getFullYear();
  const from = `${season}-01-01`;
  const [{ data: club }, { data: budget }, { data: exps }, { data: reqs }, { data: items }, { data: evs }] = await Promise.all([
    sb.from("clubs").select("club_id, club_name, crest").eq("club_id", team.club_id ?? -1).maybeSingle(),
    sb.from("spend_budgets").select("amount").eq("team_id", team.team_id).eq("season", season).maybeSingle(),
    sb.from("team_expenses").select("expense_id, event_id, created_by, spent_on, amount, shop, category, note, payback, receipt_path, status, status_note, decided_at, paid_at, created_at")
      .eq("team_id", team.team_id).is("deleted_at", null).gte("spent_on", `${season - 1}-07-01`).order("created_at", { ascending: false }).limit(200),
    sb.from("gear_requests").select("gear_request_id, created_by, note, status, status_note, decided_at, ordered_at, delivered_at, created_at, gear_request_lines(name, qty, unit_price, gear_item_id)")
      .eq("team_id", team.team_id).is("deleted_at", null).gte("created_at", `${season - 1}-07-01`).order("created_at", { ascending: false }).limit(200),
    sb.from("gear_items").select("gear_item_id, name, category, unit_price, detail, sort").eq("club_id", team.club_id ?? -1).eq("is_active", true).order("sort").order("name"),
    sb.from("events").select("event_id, event_title, opposition, event_date_time, event_type_id")
      .eq("team_id", team.team_id).gte("event_date_time", new Date(Date.now() - 21 * 864e5).toISOString())
      .lte("event_date_time", new Date(Date.now() + 2 * 864e5).toISOString()).order("event_date_time", { ascending: false }).limit(30),
  ]);
  const who = await names(sb, [...(exps || []).map((e: any) => e.created_by), ...(reqs || []).map((r: any) => r.created_by)]);
  const expenses = (exps || []).map((e: any) => ({ ...e, amount: money(e.amount), by: who.get(e.created_by) || "A coach", mine: e.created_by === userId, has_receipt: !!e.receipt_path, receipt_path: undefined }));
  const gear = (reqs || []).map((r: any) => ({
    gear_request_id: r.gear_request_id, note: r.note, status: r.status, status_note: r.status_note, created_at: r.created_at,
    decided_at: r.decided_at, ordered_at: r.ordered_at, delivered_at: r.delivered_at,
    lines: r.gear_request_lines || [], total: gearTotal(r.gear_request_lines || []),
    by: who.get(r.created_by) || "A coach", mine: r.created_by === userId,
  }));
  const used = money(
    expenses.filter((e: any) => SPENT_EXP.includes(e.status) && e.spent_on >= from).reduce((s: number, e: any) => s + e.amount, 0) +
    gear.filter((g: any) => SPENT_GEAR.includes(g.status) && g.created_at >= from).reduce((s: number, g: any) => s + g.total, 0));
  const waiting = money(
    expenses.filter((e: any) => e.status === "submitted").reduce((s: number, e: any) => s + e.amount, 0) +
    gear.filter((g: any) => g.status === "requested").reduce((s: number, g: any) => s + g.total, 0));
  return {
    team: { team_id: team.team_id, team_name: team.team_name, club_id: team.club_id },
    club, season, budget: budget ? money(budget.amount) : null, used, waiting, is_officer: isOfficer,
    categories: CATEGORIES, expenses, gear, items: items || [], events: evs || [],
  };
}

async function readReceipt(sb: any, team: any, body: any) {
  const b64 = String(body.image || "").replace(/^data:[^,]+,/, "");
  if (!b64 || b64.length > 8_000_000) throw new Error("bad image");
  const mime = ["image/jpeg", "image/png", "image/webp"].includes(body.mime) ? body.mime : "image/jpeg";
  const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  const path = `${team.club_id ?? 0}/${team.team_id}/${crypto.randomUUID()}.${mime.split("/")[1].replace("jpeg", "jpg")}`;
  const { error } = await sb.storage.from("receipts").upload(path, bytes, { contentType: mime, upsert: false });
  if (error) throw error;

  let read: any = null;
  try {
    const anthropic = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY")! });
    const msg = await anthropic.messages.create({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 300,
      messages: [{
        role: "user",
        content: [
          { type: "image", source: { type: "base64", media_type: mime, data: b64 } },
          { type: "text", text:
            `This is a photo of a receipt a GAA coach paid for a team. Reply with JSON only, no other text:
{"amount": total paid in euro as a number or null, "date": "YYYY-MM-DD" or null, "shop": short shop or payee name or null,
 "category": one of ${JSON.stringify(CATEGORIES)} (best guess: food, drinks, fruit -> "Match day food"; bus, taxi, fuel, parking, tolls -> "Travel"; referee -> "Ref fee"; pitch, hall, astro booking -> "Pitch hire"; tournament or blitz entry -> "Entry fee"; balls, cones, bibs, sports shop -> "Equipment")}
If it is not a receipt, reply {"amount": null, "date": null, "shop": null, "category": null}.` },
        ],
      }],
    });
    const text = msg.content.map((c: any) => c.type === "text" ? c.text : "").join("");
    const m = /\{[\s\S]*\}/.exec(text);
    if (m) {
      const j = JSON.parse(m[0]);
      read = {
        amount: typeof j.amount === "number" && j.amount > 0 && j.amount < 100000 ? money(j.amount) : null,
        date: /^\d{4}-\d{2}-\d{2}$/.test(j.date || "") ? j.date : null,
        shop: clip(j.shop, 80),
        category: CATEGORIES.includes(j.category) ? j.category : null,
      };
    }
  } catch (e) {
    console.error("receipt read", e);
  }
  return { receipt_path: path, read };
}

async function clubData(sb: any, clubId: number, season: number) {
  const from = `${season}-01-01`, to = `${season}-12-31`;
  const [{ data: club }, { data: teams }, { data: budgets }, { data: exps }, { data: reqs }, { data: items }] = await Promise.all([
    sb.from("clubs").select("club_id, club_name, crest, primary_colour, secondary_colour").eq("club_id", clubId).maybeSingle(),
    sb.from("teams").select("team_id, team_name").eq("club_id", clubId),
    sb.from("spend_budgets").select("team_id, amount").eq("season", season),
    sb.from("team_expenses").select("expense_id, team_id, event_id, created_by, spent_on, amount, shop, category, note, payback, receipt_path, status, status_note, decided_at, paid_at, created_at")
      .eq("club_id", clubId).is("deleted_at", null).gte("spent_on", from).lte("spent_on", to).order("spent_on", { ascending: false }),
    sb.from("gear_requests").select("gear_request_id, team_id, created_by, note, status, status_note, decided_at, ordered_at, delivered_at, created_at, gear_request_lines(name, qty, unit_price, gear_item_id)")
      .eq("club_id", clubId).is("deleted_at", null).gte("created_at", from).lte("created_at", `${to}T23:59:59Z`).order("created_at", { ascending: false }),
    sb.from("gear_items").select("gear_item_id, name, category, unit_price, detail, sort").eq("club_id", clubId).eq("is_active", true).order("sort").order("name"),
  ]);
  const teamIds = new Set((teams || []).map((t: any) => t.team_id));
  const who = await names(sb, [...(exps || []).map((e: any) => e.created_by), ...(reqs || []).map((r: any) => r.created_by)]);
  const evIds = [...new Set((exps || []).map((e: any) => e.event_id).filter(Boolean))];
  const { data: evs } = evIds.length ? await sb.from("events").select("event_id, event_title, opposition, event_date_time").in("event_id", evIds) : { data: [] };
  return {
    club, season,
    teams: (teams || []).map((t: any) => ({ team_id: t.team_id, team_name: t.team_name })),
    budgets: (budgets || []).filter((b: any) => teamIds.has(b.team_id)).map((b: any) => ({ team_id: b.team_id, amount: money(b.amount) })),
    expenses: (exps || []).map((e: any) => ({ ...e, amount: money(e.amount), by: who.get(e.created_by) || "A coach", has_receipt: !!e.receipt_path, receipt_path: undefined, created_by: undefined })),
    gear: (reqs || []).map((r: any) => ({
      gear_request_id: r.gear_request_id, team_id: r.team_id, note: r.note, status: r.status, status_note: r.status_note,
      created_at: r.created_at, decided_at: r.decided_at, ordered_at: r.ordered_at, delivered_at: r.delivered_at,
      lines: r.gear_request_lines || [], total: gearTotal(r.gear_request_lines || []), by: who.get(r.created_by) || "A coach",
    })),
    events: evs || [],
    items: items || [],
  };
}

// Allowed moves. Expenses: submitted|queried -> approved|queried|rejected,
// approved -> paid, back to submitted from anything but paid. Gear:
// requested|queried -> approved|queried|rejected, approved -> ordered ->
// delivered.
async function decide(sb: any, userId: string, body: any, row: any) {
  const isExp = body.kind === "expense";
  const act = String(body.move || "");
  const now = new Date().toISOString();
  const note = clip(body.note, 500);
  const patch: any = {};
  const s = row.status;
  const waiting = isExp ? ["submitted", "queried"] : ["requested", "queried"];
  if (act === "approve" && waiting.includes(s)) Object.assign(patch, { status: "approved", decided_by: userId, decided_at: now, status_note: note });
  else if (act === "query" && (waiting.includes(s) || s === "approved")) Object.assign(patch, { status: "queried", decided_by: userId, decided_at: now, status_note: note });
  else if (act === "reject" && (waiting.includes(s) || s === "approved")) Object.assign(patch, { status: "rejected", decided_by: userId, decided_at: now, status_note: note });
  else if (isExp && act === "paid" && s === "approved") Object.assign(patch, { status: "paid", paid_at: now });
  else if (!isExp && act === "ordered" && s === "approved") Object.assign(patch, { status: "ordered", ordered_at: now });
  else if (!isExp && act === "delivered" && (s === "ordered" || s === "approved")) Object.assign(patch, { status: "delivered", delivered_at: now });
  else if (act === "reopen" && s !== "paid" && s !== "delivered") Object.assign(patch, { status: isExp ? "submitted" : "requested", status_note: null, decided_by: null, decided_at: null, ordered_at: null });
  else throw new Error(`move ${s} -> ${act} not allowed`);
  const { error } = await sb.from(isExp ? "team_expenses" : "gear_requests").update(patch)
    .eq(isExp ? "expense_id" : "gear_request_id", isExp ? row.expense_id : row.gear_request_id).eq("status", s);
  if (error) throw error;
  return { status: patch.status };
}
