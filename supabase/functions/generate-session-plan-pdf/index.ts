// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { buildSessionPlanPdf } from "./builder.ts";
import type { ClubData, EventData, PlanJson } from "./builder.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function applyCamogie(s: string | null, teamFemale: boolean): string | null {
  if (!s || !teamFemale) return s;
  return s.replace(/\bHurling\b/g, 'Camogie').replace(/\bhurling\b/g, 'camogie');
}

// ─── Edge function handler ────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return new Response(JSON.stringify({ error: "Missing auth" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const jwt = authHeader.slice(7);
    try {
      // Validate JWT structure; sub may be absent for anon-key callers —
      // user_id from the request body is used for any DB lookups.
      const payload = jwt.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
      JSON.parse(atob(payload));
    } catch {
      return new Response(JSON.stringify({ error: "Invalid JWT" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const { plan_id, plan_json: bodyPlanJson, user_id, format = "a4" } = body;
    if (!plan_id && !bodyPlanJson) {
      return new Response(JSON.stringify({ error: "Missing plan_id or plan_json" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    let planJsonResolved: any;
    let planEventId: number | null = null;
    let planCreatedBy: string | null = null;

    if (plan_id) {
      // ── Fetch session plan from DB ──
      const { data: planRow, error: planErr } = await supabase
        .from("session_plans")
        .select("plan_json, event_id, created_by")
        .eq("plan_id", plan_id)
        .maybeSingle();

      if (planErr || !planRow) {
        return new Response(JSON.stringify({ error: "Session plan not found" }), {
          status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      planJsonResolved = planRow.plan_json;
      planEventId      = planRow.event_id;
      planCreatedBy    = planRow.created_by;
    } else {
      // plan_json passed directly (e.g. from favourites screen — no event)
      planJsonResolved = bodyPlanJson;
    }

    // ── Fetch event data (only when a plan_id linked to an event is present) ──
    let eventRow: any = null;
    if (planEventId) {
      const { data: er, error: eventErr } = await supabase
        .from("events")
        .select(`
          event_title,
          event_date_time,
          teams!inner (
            team_name,
            team_female,
            clubs!inner (
              club_name,
              crest,
              primary_colour,
              secondary_colour,
              third_colour
            )
          ),
          squads (
            squad_name,
            grade
          ),
          event_types!events_event_type_id_fkey(event_type),
          event_codes!events_event_code_id_fkey(event_code)
        `)
        .eq("event_id", planEventId)
        .maybeSingle();
      if (eventErr) console.warn("Event fetch error (continuing with defaults):", eventErr);
      eventRow = er;
    }

    // Build EventData — gracefully handle missing relations
    const clubRaw   = eventRow?.teams?.clubs;
    const squadRaw  = eventRow?.squads;

    // Prefer user's default_club branding over the event's club chain
    const resolvedUserId = user_id || planCreatedBy;
    let userClubRaw: Record<string, any> | null = null;
    if (resolvedUserId) {
      const { data: userRow } = await supabase
        .from("users")
        .select("default_club")
        .eq("user_id", resolvedUserId)
        .maybeSingle();
      if (userRow?.default_club) {
        const { data: uc } = await supabase
          .from("clubs")
          .select("club_name, crest, primary_colour, secondary_colour, third_colour")
          .eq("club_id", userRow.default_club)
          .maybeSingle();
        userClubRaw = uc;
      }
    }

    const src = userClubRaw || clubRaw;
    const club: ClubData = {
      club_name:        src?.club_name        || "CoachSmart",
      crest:            src?.crest            || null,
      primary_colour:   src?.primary_colour   || "#2d7a00",
      secondary_colour: src?.secondary_colour || "#ffd700",
      third_colour:     src?.third_colour     || null,
    };

    const teamFemale = eventRow?.teams?.team_female === true;
    const eventData: EventData = {
      event_title: eventRow?.event_title                || null,
      event_date:  eventRow?.event_date_time            || null,
      squad_name:  squadRaw?.squad_name                 || null,
      squad_grade: squadRaw?.grade                      || null,
      team_name:   eventRow?.teams?.team_name           || null,
      event_type:  applyCamogie(eventRow?.event_types?.event_type || null, teamFemale),
      event_code:  applyCamogie(eventRow?.event_codes?.event_code || null, teamFemale),
      team_female: teamFemale,
      club,
    };

    const plan = planJsonResolved as PlanJson;
    if (!plan) {
      return new Response(JSON.stringify({ error: "plan_json is empty" }), {
        status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ── Build PDF ──
    const pdfBytes = await buildSessionPlanPdf(plan, eventData, format === "mobile" ? "mobile" : "a4");

    // Chunked base64 — avoids stack overflow on large PDFs
    let b64 = "";
    for (let i = 0; i < pdfBytes.length; i += 8192) {
      b64 += String.fromCharCode(...pdfBytes.subarray(i, i + 8192));
    }
    const base64 = btoa(b64);

    // Filename: use event date if available, else today
    const datePart = eventData.event_date
      ? eventData.event_date.slice(0, 10)
      : new Date().toISOString().slice(0, 10);
    const filename = `session-plan-${format === "mobile" ? "share" : "print"}-${datePart}.pdf`;

    return new Response(JSON.stringify({ pdf: base64, filename }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (err) {
    console.error("generate-session-plan-pdf error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
