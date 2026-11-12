// deno-lint-ignore-file no-explicit-any
// stripe-admin (2026-11-12, thread "Plan Stripe Connect for team payouts"):
// Ken's page for team Stripe accounts (webviews/stripe-approvals.html).
// Ken only: the caller's JWT must belong to an email in ALLOWED.
//
// POST { action, ... }
//   list                       -> default fee, every team with a Stripe account, and the
//                                 teams still taking payments on the CoachSmart account
//   approve   { team_id }      -> the team's account can take payments; emails whoever set it up
//   unapprove { team_id }      -> stops the team's payments straight away (switch off)
//   default_fee { bps }        -> CoachSmart's cut for every team (100 = 1%)
//   team_fee  { team_id, bps } -> per team override; bps null = use the default
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { stripe } from "../_shared/stripe-connect.ts";

const ALLOWED = ["ken.darcy@gmail.com"];
const MAX_BPS = 2000;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...cors, "Content-Type": "application/json" } });

const TEAM_COLS = "team_id, team_name, payments, stripe_account_id, stripe_charges_enabled, stripe_payouts_enabled, " +
  "stripe_details_submitted, stripe_ready_at, stripe_approved_at, stripe_connected_by, stripe_fee_bps, stripe_updated_at, clubs(club_name)";

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
  const jwt = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  const { data: u } = await sb.auth.getUser(jwt);
  const user = u?.user;
  if (!user) return json({ error: "Please sign in" }, 401);
  if (!ALLOWED.includes(String(user.email || "").toLowerCase())) return json({ error: "This page is not available for your account." }, 403);

  let body: any = {};
  try { body = await req.json(); } catch (_) { /* empty */ }
  const teamId = Number(body.team_id);

  try {
    if (body.action === "list") return json({ success: true, data: await list(sb, Number.isInteger(teamId) ? teamId : null) });

    if (body.action === "approve" || body.action === "unapprove") {
      if (!Number.isInteger(teamId)) return json({ error: "Missing team_id" }, 400);
      const { data: t }: any = await sb.from("teams").select(TEAM_COLS).eq("team_id", teamId).maybeSingle();
      if (!t?.stripe_account_id) return json({ error: "This team has no Stripe account" }, 400);
      if (body.action === "approve") {
        await sb.from("teams").update({ stripe_approved_at: new Date().toISOString(), stripe_approved_by: user.id }).eq("team_id", teamId);
        await tellTeam(sb, t);
      } else {
        await sb.from("teams").update({ stripe_approved_at: null, stripe_approved_by: null, payments: false }).eq("team_id", teamId);
      }
      return json({ success: true, data: await list(sb, teamId) });
    }

    if (body.action === "default_fee") {
      const bps = Math.round(Number(body.bps));
      if (!Number.isFinite(bps) || bps < 0 || bps > MAX_BPS) return json({ error: "The fee must be between 0% and 20%" }, 400);
      await sb.from("payment_settings").update({ default_fee_bps: bps, updated_at: new Date().toISOString(), updated_by: user.id }).eq("id", 1);
      return json({ success: true, data: await list(sb, null) });
    }

    if (body.action === "team_fee") {
      if (!Number.isInteger(teamId)) return json({ error: "Missing team_id" }, 400);
      const bps = body.bps === null || body.bps === "" || body.bps === undefined ? null : Math.round(Number(body.bps));
      if (bps !== null && (!Number.isFinite(bps) || bps < 0 || bps > MAX_BPS)) return json({ error: "The fee must be between 0% and 20%" }, 400);
      await sb.from("teams").update({ stripe_fee_bps: bps }).eq("team_id", teamId);
      return json({ success: true, data: await list(sb, teamId) });
    }

    return json({ error: "Unknown action" }, 400);
  } catch (e) {
    console.error("stripe-admin", body.action, (e as Error).message);
    return json({ error: (e as Error).message || "Something went wrong" }, 500);
  }
});

async function list(sb: any, focus: number | null) {
  const { data: ps } = await sb.from("payment_settings").select("default_fee_bps").eq("id", 1).maybeSingle();
  const { data: teams } = await sb.from("teams").select(TEAM_COLS).not("stripe_account_id", "is", null);
  // Refresh the team asked about from Stripe, so the page shows the live state.
  if (focus) {
    const t = (teams || []).find((x: any) => x.team_id === focus);
    if (t) {
      try {
        const a = await stripe("GET", `/accounts/${t.stripe_account_id}`);
        t.stripe_charges_enabled = !!a.charges_enabled;
        t.stripe_payouts_enabled = !!a.payouts_enabled;
        t.stripe_details_submitted = !!a.details_submitted;
        t.stripe_name = a.business_profile?.name || a.settings?.dashboard?.display_name || null;
        t.stripe_type = a.business_type || null;
        await sb.from("teams").update({
          stripe_charges_enabled: t.stripe_charges_enabled, stripe_payouts_enabled: t.stripe_payouts_enabled,
          stripe_details_submitted: t.stripe_details_submitted, stripe_updated_at: new Date().toISOString(),
        }).eq("team_id", focus);
      } catch (e) {
        console.warn("stripe-admin refresh", focus, (e as Error).message);
      }
    }
  }
  const userIds = [...new Set((teams || []).map((t: any) => t.stripe_connected_by).filter(Boolean))];
  const { data: users } = userIds.length
    ? await sb.from("users").select("user_id, first_name, last_name, email_address").in("user_id", userIds)
    : { data: [] };
  const byId = new Map((users || []).map((x: any) => [x.user_id, x]));
  const { data: legacy } = await sb.from("teams").select("team_id, team_name, clubs(club_name)")
    .eq("payments", true).is("stripe_ready_at", null);
  return {
    default_fee_bps: Number(ps?.default_fee_bps) || 0,
    teams: (teams || []).map((t: any) => {
      const p: any = byId.get(t.stripe_connected_by);
      return {
        team_id: t.team_id,
        team_name: t.team_name,
        club_name: t.clubs?.club_name || null,
        ready: !!t.stripe_charges_enabled,
        payouts: !!t.stripe_payouts_enabled,
        details_submitted: !!t.stripe_details_submitted,
        approved_at: t.stripe_approved_at,
        payments: !!t.payments,
        fee_bps: t.stripe_fee_bps,
        stripe_name: t.stripe_name || null,
        stripe_type: t.stripe_type || null,
        connected_by: p ? { name: [p.first_name, p.last_name].filter(Boolean).join(" "), email: p.email_address } : null,
        updated_at: t.stripe_updated_at,
      };
    }),
    legacy: (legacy || []).map((t: any) => ({ team_id: t.team_id, team_name: t.team_name, club_name: t.clubs?.club_name || null })),
  };
}

// Tell whoever set up the team's Stripe account that payments can go on.
async function tellTeam(sb: any, t: any) {
  const key = Deno.env.get("RESEND_API_KEY");
  if (!key || !t.stripe_connected_by) return;
  const { data: p } = await sb.from("users").select("first_name, email_address").eq("user_id", t.stripe_connected_by).maybeSingle();
  if (!p?.email_address) return;
  const esc = (s: unknown) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]!));
  const html = `<div style="font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;max-width:480px;margin:0 auto;padding:16px;color:#1B2333">
<h2 style="font-size:19px;margin:0 0 12px">${esc(t.team_name)} can take payments</h2>
<p style="margin:0 0 8px">Hi ${esc(p.first_name || "there")}, the team's Stripe account is approved.</p>
<p style="margin:0">Open the team in the app, go to Payments and turn on Take payments at events. Payments then go straight to the team's Stripe account and on to its bank.</p>
</div>`;
  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: "Bearer " + key, "Content-Type": "application/json" },
      body: JSON.stringify({ from: "CoachSmart <no-reply@coachsmart.app>", to: [p.email_address], subject: `${t.team_name}: payments approved`, html }),
    });
    if (!res.ok) console.error("tellTeam email", res.status, await res.text());
  } catch (e) {
    console.error("tellTeam email", (e as Error).message);
  }
}
