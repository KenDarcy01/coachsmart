// deno-lint-ignore-file no-explicit-any
// Senior diary coach dashboard (clontarf-gaa/senior-diary/dashboard/): what players log.
//
// Who (Ken, 2026-11-06): only diary admins, i.e. the caller's sign-in email is in
// diary_admins. Players can still only see their own rows (RLS); this function is the
// one way to read everyone's, and it checks the caller first.
//
// POST JSON with the caller's JWT:
//   { action: "load" }                    players, ticks/numbers, the published plan, player days, admins
//   { action: "admin_add", email }        add a diary admin
//   { action: "admin_remove", email }     remove a diary admin (not yourself)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

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

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  try {
    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
    const jwt = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
    const { data: { user } } = await sb.auth.getUser(jwt).catch(() => ({ data: { user: null } } as any));
    if (!user || !user.email) throw new HttpError(401, "Please sign in");
    const me = user.email.toLowerCase();

    const { data: adminRow, error: adminErr } = await sb.from("diary_admins").select("email").eq("email", me).maybeSingle();
    if (adminErr) throw adminErr;
    if (!adminRow) throw new HttpError(403, "The diary dashboard is for diary admins only. Ask an admin to add your email.");

    const body = await req.json().catch(() => ({}));
    const action = body.action || "load";

    if (action === "admin_add" || action === "admin_remove") {
      const email = String(body.email || "").trim().toLowerCase();
      if (!EMAIL.test(email)) throw new HttpError(400, "That does not look like an email address");
      if (action === "admin_add") {
        const { error } = await sb.from("diary_admins").upsert({ email, added_by: me }, { onConflict: "email", ignoreDuplicates: true });
        if (error) throw error;
      } else {
        if (email === me) throw new HttpError(400, "You cannot remove yourself. Ask another admin.");
        const { error } = await sb.from("diary_admins").delete().eq("email", email);
        if (error) throw error;
      }
      return json({ admins: await admins(sb) });
    }
    if (action !== "load") throw new HttpError(400, "Unknown action");

    const [players, ticks, plan, days, list] = await Promise.all([
      sb.rpc("diary_dashboard_players"),
      all(sb, "diary_ticks", "user_id, day, ticks, updated_at", ["user_id", "day"]),
      sb.from("diary_plan").select("plan, published_at, published_by").order("id", { ascending: false }).limit(1).maybeSingle(),
      all(sb, "diary_player_days", "email, day, slots, extras", ["email", "day"]),
      admins(sb),
    ]);
    if (players.error) throw players.error;
    if (plan.error) throw plan.error;
    return json({
      me,
      admins: list,
      players: players.data || [],
      ticks,
      plan: plan.data || null,
      player_days: days,
    });
  } catch (e) {
    if (e instanceof HttpError) return json({ error: e.message }, e.status);
    console.error(e);
    return json({ error: "Something went wrong" }, 500);
  }
});

async function admins(sb: any) {
  const { data, error } = await sb.from("diary_admins").select("email, added_by, added_at").order("email");
  if (error) throw error;
  return data || [];
}

/** Every row of a table, 1000 at a time. */
async function all(sb: any, table: string, cols: string, order: string[]) {
  const out: any[] = [];
  for (let from = 0; ; from += 1000) {
    let q = sb.from(table).select(cols);
    for (const c of order) q = q.order(c);
    const { data, error } = await q.range(from, from + 999);
    if (error) throw error;
    out.push(...(data || []));
    if (!data || data.length < 1000) return out;
  }
}
