// deno-lint-ignore-file no-explicit-any
// Club officer invites for the chairperson dashboard (coachsmart.app/club).
//
//   action "invite"  SuperUser only. Adds an officer by email. If the person
//                    already has a CoachSmart account they become an officer
//                    straight away; otherwise a pending invite with a one-off
//                    token (30 days) is stored. Either way they get a
//                    club-branded email with a link to the dashboard.
//   action "lookup"  Public (token). Returns the club and name for the
//                    "set up your account" screen.
//   action "accept"  Public (token + password). Creates and confirms the
//                    account (the on_auth_user_confirmed trigger makes the
//                    users row), then makes the person a club officer.
//
// Requires SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY (auto)
// and RESEND_API_KEY (already set for send-email).
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { Resend } from "https://esm.sh/resend@3.2.0";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const SITE = "https://coachsmart.app/club/";
// The pitch planner (new app; preview address until the January switch).
// Opened straight from this link it uses the club's own look and can be
// added to the home screen as "<Club> Pitches" (Ken, 2026-11-18).
const PLANNER = (clubId: number) => `https://coachsmart-v3.web.app/pitches?club=${clubId}&look=club`;
const DAYS = 30;
const esc = (s: unknown) =>
  String(s ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

function token() {
  const b = new Uint8Array(24);
  crypto.getRandomValues(b);
  return Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("");
}

// A colour dark enough for white button text; falls back to CoachSmart dark.
function buttonColour(...hexes: (string | null | undefined)[]) {
  for (const h of hexes) {
    const m = /^#?([0-9a-f]{6})$/i.exec(h || "");
    if (!m) continue;
    const n = parseInt(m[1], 16);
    const c = [n >> 16, (n >> 8) & 255, n & 255].map((v) => {
      v /= 255;
      return v <= .03928 ? v / 12.92 : Math.pow((v + .055) / 1.055, 2.4);
    });
    if (.2126 * c[0] + .7152 * c[1] + .0722 * c[2] < .45) return "#" + m[1];
  }
  return "#1a1d23";
}

function emailHtml(o: {
  club: any; first: string; inviter: string; title: string; link: string; isNew: boolean;
  pitchesOnly?: boolean;
}) {
  if (o.pitchesOnly) return pitchEmailHtml(o);
  const btn = buttonColour(o.club.primary_colour, o.club.secondary_colour);
  const crest = o.club.crest
    ? `<img src="${esc(o.club.crest)}" alt="" width="64" height="64" style="display:block;margin:0 auto 12px;width:64px;height:64px;object-fit:contain">`
    : "";
  const intro = `${o.inviter ? esc(o.inviter) + " has" : "You have been"} ${o.inviter ? "added you" : "added"} as ${esc(o.title)} on the ${esc(o.club.club_name)} club dashboard.`;
  const what = "It shows how every team in the club is doing: this week's results and fixtures, match turnout, a health check for each team and the season so far.";
  const next = o.isNew
    ? `Tap the button to choose a password and open the dashboard. You don't need to download the app. The link works for ${DAYS} days.`
    : "Sign in with your CoachSmart email and password.";
  return `<!doctype html><html><body style="margin:0;background:#f4f5f7;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#1a1d23">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#f4f5f7;padding:28px 12px"><tr><td align="center">
<table width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;background:#fff;border-radius:16px;padding:28px">
<tr><td style="text-align:center">${crest}<div style="font-size:20px;font-weight:700;margin-bottom:4px">${esc(o.club.club_name)}</div>
<div style="color:#6b7280;font-size:14px;margin-bottom:22px">Club dashboard</div></td></tr>
<tr><td style="font-size:16px;line-height:1.5">
<p style="margin:0 0 12px">Hi${o.first ? " " + esc(o.first) : ""},</p>
<p style="margin:0 0 12px">${intro}</p>
<p style="margin:0 0 12px">${what}</p>
<p style="margin:0 0 22px">${next}</p>
<p style="margin:0 0 22px;text-align:center"><a href="${esc(o.link)}" style="display:inline-block;background:${btn};color:#fff;text-decoration:none;font-weight:600;padding:13px 26px;border-radius:10px">${o.isNew ? "Set up your account" : "Open the dashboard"}</a></p>
<p style="margin:0;color:#6b7280;font-size:13px">If the button doesn't work, copy this link into your browser:<br><a href="${esc(o.link)}" style="color:#6b7280;word-break:break-all">${esc(o.link)}</a></p>
</td></tr></table>
<div style="color:#9ca3af;font-size:12px;margin-top:14px">Powered by CoachSmart</div>
</td></tr></table></body></html>`;
}

// Invite for a planner-only officer (e.g. the club's pitch admin).
function pitchEmailHtml(o: { club: any; first: string; inviter: string; title: string; link: string; isNew: boolean }) {
  const btn = buttonColour(o.club.primary_colour, o.club.secondary_colour);
  const crest = o.club.crest
    ? `<img src="${esc(o.club.crest)}" alt="" width="64" height="64" style="display:block;margin:0 auto 12px;width:64px;height:64px;object-fit:contain">`
    : "";
  const intro = `${o.inviter ? esc(o.inviter) + " has added you" : "You have been added"} as ${esc(o.title)} on the ${esc(o.club.club_name)} pitch planner.`;
  const what = "You can book matches and training onto the club's pitches, sort clashes and publish the week so every team can see where they're playing.";
  const next = o.isNew
    ? `Tap the button to choose a password. You don't need to download anything. The link works for ${DAYS} days.`
    : "Sign in with your CoachSmart email and password.";
  const tip = "On your phone, open it in Safari or Chrome and choose \"Add to Home Screen\" to keep it like an app.";
  return `<!doctype html><html><body style="margin:0;background:#f4f5f7;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#1a1d23">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#f4f5f7;padding:28px 12px"><tr><td align="center">
<table width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;background:#fff;border-radius:16px;padding:28px">
<tr><td style="text-align:center">${crest}<div style="font-size:20px;font-weight:700;margin-bottom:4px">${esc(o.club.club_name)}</div>
<div style="color:#6b7280;font-size:14px;margin-bottom:22px">Pitch planner</div></td></tr>
<tr><td style="font-size:16px;line-height:1.5">
<p style="margin:0 0 12px">Hi${o.first ? " " + esc(o.first) : ""},</p>
<p style="margin:0 0 12px">${intro}</p>
<p style="margin:0 0 12px">${what}</p>
<p style="margin:0 0 22px">${next}</p>
<p style="margin:0 0 22px;text-align:center"><a href="${esc(o.link)}" style="display:inline-block;background:${btn};color:#fff;text-decoration:none;font-weight:600;padding:13px 26px;border-radius:10px">${o.isNew ? "Set up your account" : "Open the pitch planner"}</a></p>
<p style="margin:0 0 12px;color:#6b7280;font-size:14px">${tip}</p>
<p style="margin:0;color:#6b7280;font-size:13px">If the button doesn't work, copy this link into your browser:<br><a href="${esc(o.link)}" style="color:#6b7280;word-break:break-all">${esc(o.link)}</a></p>
</td></tr></table>
<div style="color:#9ca3af;font-size:12px;margin-top:14px">Powered by CoachSmart</div>
</td></tr></table></body></html>`;
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const body = await req.json().catch(() => ({}));
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    // ── Public: look up / accept an invite by token ─────────────────────
    if (body.action === "lookup" || body.action === "accept") {
      const t = String(body.token || "");
      if (!/^[0-9a-f]{48}$/.test(t)) return json({ error: "This invite link isn't valid." }, 400);
      const { data: inv } = await admin.from("club_officer_invites").select("*").eq("token", t).maybeSingle();
      if (!inv || inv.accepted_at) {
        return json({ error: "This invite link has already been used or was replaced by a newer one. Sign in with your email and password, or ask for a new invite.", used: true }, 400);
      }
      if (inv.expires_at && new Date(inv.expires_at) < new Date()) {
        return json({ error: "This invite has expired. Ask whoever invited you to send it again." }, 400);
      }
      const { data: club } = await admin.from("clubs")
        .select("club_id, club_name, crest, primary_colour, secondary_colour").eq("club_id", inv.club_id).single();

      if (body.action === "lookup") {
        return json({ club, email: inv.email, first_name: inv.first_name, last_name: inv.last_name, title: inv.title,
          can_pitches: inv.can_pitches !== false, can_dashboard: inv.can_dashboard !== false,
          planner: PLANNER(inv.club_id) });
      }

      const password = String(body.password || "");
      if (password.length < 8) return json({ error: "Use at least 8 characters for your password." }, 400);
      const first = String(body.first_name ?? inv.first_name ?? "").trim().slice(0, 60);
      const last = String(body.last_name ?? inv.last_name ?? "").trim().slice(0, 60);

      const { data: found } = await admin.rpc("club_invite_auth_user", { p_email: inv.email });
      const existing = Array.isArray(found) ? found[0] : null;
      let uid: string;
      if (existing?.confirmed) {
        // Already a CoachSmart user: keep their password, just make them an officer.
        uid = existing.user_id;
        if (!existing.has_profile) return json({ error: "Your account isn't finished yet. Please sign in to the CoachSmart app once, then try again." }, 400);
      } else if (existing) {
        // Started signing up but never confirmed: the invite link proves the email.
        uid = existing.user_id;
        const { error } = await admin.auth.admin.updateUserById(uid, {
          password, email_confirm: true, user_metadata: { first_name: first, last_name: last },
        });
        if (error) throw error;
      } else {
        // New account. Create unconfirmed, then confirm, so the on_auth_user_confirmed
        // trigger (UPDATE of email_confirmed_at) creates the users row as in a normal sign-up.
        const { data: cu, error } = await admin.auth.admin.createUser({
          email: inv.email, password, email_confirm: false, user_metadata: { first_name: first, last_name: last },
        });
        if (error || !cu?.user) throw error || new Error("createUser failed");
        uid = cu.user.id;
        const { error: e2 } = await admin.auth.admin.updateUserById(uid, { email_confirm: true });
        if (e2) throw e2;
      }

      // The users row comes from the trigger; make sure it exists before linking.
      const { data: urow } = await admin.from("users").select("user_id, first_name, last_name").eq("user_id", uid).maybeSingle();
      if (!urow) return json({ error: "Your account was created but isn't ready yet. Please try signing in in a minute." }, 500);
      const names: any = {};
      if (!urow.first_name && first) names.first_name = first;
      if (!urow.last_name && last) names.last_name = last;
      if (Object.keys(names).length) await admin.from("users").update(names).eq("user_id", uid);

      const { error: oe } = await admin.from("club_officers").upsert(
        { club_id: inv.club_id, user_id: uid, title: inv.title, created_by: inv.created_by, is_active: true,
          can_pitches: inv.can_pitches !== false, can_dashboard: inv.can_dashboard !== false },
        { onConflict: "club_id,user_id" },
      );
      if (oe) throw oe;
      await admin.from("club_officer_invites").update({ accepted_at: new Date().toISOString(), token: null })
        .eq("invite_id", inv.invite_id);

      return json({ ok: true, email: inv.email, club_id: inv.club_id, existing: !!existing?.confirmed,
        can_dashboard: inv.can_dashboard !== false, planner: PLANNER(inv.club_id) });
    }

    // ── SuperUser: invite ───────────────────────────────────────────────
    const auth = req.headers.get("Authorization") || "";
    const caller = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: auth } },
    });
    const { data: me } = await caller.auth.getUser();
    if (!me?.user) return json({ error: "Please sign in again." }, 401);
    const { data: isSuper } = await caller.rpc("is_app_super_user");
    if (!isSuper) return json({ error: "Only a SuperUser can invite club officers." }, 403);

    const clubId = Number(body.club_id);
    const email = String(body.email || "").trim().toLowerCase();
    const title = String(body.title || "").trim().slice(0, 60) || "Officer";
    const first = String(body.first_name || "").trim().slice(0, 60);
    const last = String(body.last_name || "").trim().slice(0, 60);
    const canPitches = body.can_pitches !== false;
    const canDashboard = body.can_dashboard !== false;
    if (!canPitches && !canDashboard) return json({ error: "Tick the pitch planner, the dashboard or both." }, 400);
    if (!clubId) return json({ error: "No club." }, 400);
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return json({ error: "That email doesn't look right." }, 400);

    const { data: club } = await admin.from("clubs")
      .select("club_id, club_name, crest, primary_colour, secondary_colour").eq("club_id", clubId).maybeSingle();
    if (!club) return json({ error: "Club not found." }, 404);
    const { data: inviterRow } = await admin.from("users").select("first_name, last_name").eq("user_id", me.user.id).maybeSingle();
    const inviter = [inviterRow?.first_name, inviterRow?.last_name].filter(Boolean).join(" ").trim();

    const { data: found } = await admin.rpc("club_invite_auth_user", { p_email: email });
    const existing = Array.isArray(found) ? found[0] : null;
    let link: string, isNew: boolean, firstName = first;

    if (existing?.confirmed && existing.has_profile) {
      // Already on CoachSmart: make them an officer now.
      const { error } = await admin.from("club_officers").upsert(
        { club_id: clubId, user_id: existing.user_id, title, created_by: me.user.id, is_active: true,
          can_pitches: canPitches, can_dashboard: canDashboard },
        { onConflict: "club_id,user_id" },
      );
      if (error) throw error;
      await admin.from("club_officer_invites").delete().eq("club_id", clubId).ilike("email", email.replace(/[\\%_]/g, "\\$&"));
      const { data: u } = await admin.from("users").select("first_name").eq("user_id", existing.user_id).maybeSingle();
      firstName = u?.first_name || first;
      link = canDashboard ? `${SITE}?club=${clubId}` : PLANNER(clubId);
      isNew = false;
    } else {
      const tok = token();
      const row = {
        club_id: clubId, email, title, first_name: first || null, last_name: last || null,
        created_by: me.user.id, sent_at: new Date().toISOString(), token: tok,
        expires_at: new Date(Date.now() + DAYS * 864e5).toISOString(), accepted_at: null,
        can_pitches: canPitches, can_dashboard: canDashboard,
      };
      await admin.from("club_officer_invites").delete().eq("club_id", clubId).ilike("email", email.replace(/[\\%_]/g, "\\$&"));
      const { error } = await admin.from("club_officer_invites").insert(row);
      if (error) throw error;
      link = `${SITE}?club=${clubId}&invite=${tok}`;
      isNew = true;
    }

    const resend = new Resend(Deno.env.get("RESEND_API_KEY")!);
    const { error: me2 } = await resend.emails.send({
      from: "CoachSmart <no-reply@coachsmart.app>",
      to: email,
      subject: canDashboard ? `${club.club_name} club dashboard` : `${club.club_name} pitch planner`,
      html: emailHtml({ club, first: firstName, inviter, title, link, isNew, pitchesOnly: !canDashboard }),
    });
    if (me2) {
      console.error("Resend failed:", me2);
      return json({ error: "Saved, but the email didn't send. Try Resend in a minute." }, 502);
    }
    return json({ ok: true, new_account: isNew });
  } catch (e) {
    console.error("club-invite error:", e);
    return json({ error: "Something went wrong. Please try again." }, 500);
  }
});
