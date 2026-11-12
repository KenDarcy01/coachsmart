// deno-lint-ignore-file no-explicit-any
// team-stripe (2026-11-12, thread "Plan Stripe Connect for team payouts").
// A team admin connects the team's own Stripe account (Standard), so event
// payments go straight to the team's bank. Stripe hosts the sign-up form and
// does the ID and bank checks; we never see bank details.
//
// POST { action, team_id } with the user's JWT. Team admins only (is_team_admin).
//   status        -> the team's Stripe state (live from Stripe, cached on teams)
//   start         -> creates the account if needed, returns { url } for Stripe's
//                    sign-up form (also used to finish or update details)
//   set_payments  -> { on: bool } turns the team's payments switch on or off.
//                    On needs a ready account (a trigger on teams enforces it).
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { stripe as stripeApi } from "../_shared/stripe-connect.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...cors, "Content-Type": "application/json" } });

const DONE_PAGE = "https://coachsmart.app/webviews/stripe-done.html";

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const auth = req.headers.get("Authorization") || "";
  const sb = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
  const { data: u } = await sb.auth.getUser(auth.replace(/^Bearer\s+/i, ""));
  const user = u?.user;
  if (!user) return json({ error: "Please sign in again." }, 401);

  let body: any = {};
  try { body = await req.json(); } catch (_) { /* empty */ }
  const teamId = Number(body.team_id);
  if (!Number.isInteger(teamId) || teamId <= 0) return json({ error: "Missing team_id." }, 400);

  const asUser = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    auth: { persistSession: false },
    global: { headers: { Authorization: auth } },
  });
  const { data: isAdmin } = await asUser.rpc("is_team_admin", { p_team_id: teamId });
  if (isAdmin !== true) return json({ error: "Only team admins can set up payments." }, 403);

  const { data: team } = await sb.from("teams")
    .select("team_id, team_name, payments, stripe_account_id, stripe_charges_enabled, stripe_ready_at")
    .eq("team_id", teamId).maybeSingle();
  if (!team) return json({ error: "Team not found." }, 404);
  const stripe = (method: string, path: string, params: any = null) => stripeApi(method, path, params);

  try {
    if (body.action === "status") return json({ success: true, data: await status(sb, team, stripe) });

    if (body.action === "start") {
      let account = team.stripe_account_id as string | null;
      if (!account) {
        const a = await stripe("POST", "/accounts", {
          type: "standard",
          country: "IE",
          email: user.email || undefined,
          metadata: { team_id: String(teamId), team_name: team.team_name || "" },
        });
        // Only the first tap creates the account; a second one reuses it.
        const { data: saved } = await sb.from("teams")
          .update({ stripe_account_id: a.id, stripe_connected_by: user.id, stripe_updated_at: new Date().toISOString() })
          .eq("team_id", teamId).is("stripe_account_id", null).select("stripe_account_id");
        if (saved?.length) account = a.id;
        else {
          const { data: again } = await sb.from("teams").select("stripe_account_id").eq("team_id", teamId).single();
          account = again?.stripe_account_id ?? null;
        }
      }
      const link = await stripe("POST", "/account_links", {
        account,
        type: "account_onboarding",
        refresh_url: `${DONE_PAGE}?s=expired`,
        return_url: `${DONE_PAGE}?s=done`,
      });
      return json({ success: true, data: { url: link.url } });
    }

    if (body.action === "set_payments") {
      const on = body.on === true;
      if (on) {
        const st = await status(sb, team, stripe);
        if (!st.ready) return json({ error: "Finish the Stripe setup before turning on payments." }, 409);
      }
      const { error } = await sb.from("teams").update({ payments: on }).eq("team_id", teamId);
      if (error) return json({ error: error.message }, 409);
      return json({ success: true, data: await status(sb, { ...team, payments: on }, stripe) });
    }

    return json({ error: "Unknown action." }, 400);
  } catch (e) {
    console.error("team-stripe", teamId, body.action, (e as Error).message);
    return json({ error: (e as Error).message || "Something went wrong." }, 502);
  }
});

// Live state from Stripe, cached on the team so checkout and the app agree.
async function status(sb: any, team: any, stripe: any) {
  const base = {
    connected: false,
    ready: false,
    details_submitted: false,
    payouts_enabled: false,
    due: 0,
    name: null as string | null,
    payments: !!team.payments,
    // Taking payments on the CoachSmart account (the teams from before Connect).
    legacy: !!team.payments && !team.stripe_ready_at,
  };
  if (!team.stripe_account_id) return base;
  const a = await stripe("GET", `/accounts/${team.stripe_account_id}`);
  const ready = !!a.charges_enabled;
  const now = new Date().toISOString();
  await sb.from("teams").update({
    stripe_charges_enabled: ready,
    stripe_payouts_enabled: !!a.payouts_enabled,
    stripe_details_submitted: !!a.details_submitted,
    stripe_updated_at: now,
    ...(ready && !team.stripe_ready_at ? { stripe_ready_at: now } : {}),
  }).eq("team_id", team.team_id);
  return {
    ...base,
    connected: true,
    ready,
    details_submitted: !!a.details_submitted,
    payouts_enabled: !!a.payouts_enabled,
    due: (a.requirements?.currently_due || []).length,
    name: a.business_profile?.name || a.settings?.dashboard?.display_name || null,
    legacy: !!team.payments && !team.stripe_ready_at && !ready,
  };
}

