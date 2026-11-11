// Supabase Edge Function: a user's CoachSmart events as a calendar feed.
//
//   GET /functions/v1/calendar-feed?t=<token>
//
// Phones subscribe to this link once (webcal://) and refresh it themselves,
// so new, moved and cancelled events follow on their own. Public (no JWT):
// the private token in calendar_feeds stands in for a login, and the v3
// Profile page can swap it for a new one (get_my_calendar_token).
//
// events.event_date_time holds the Irish wall-clock time labelled UTC, so
// times go out as local times with TZID=Europe/Dublin, never as UTC instants.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { buildCalendar } from "./ics.ts";

serve(async (req) => {
  if (req.method !== "GET" && req.method !== "HEAD") {
    return new Response("Method not allowed", { status: 405 });
  }
  const token = new URL(req.url).searchParams.get("t") ?? "";
  if (!/^[0-9a-f]{64}$/.test(token)) {
    return new Response("Calendar not found", { status: 404 });
  }
  try {
    const db = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { data, error } = await db.rpc("get_calendar_feed", { p_token: token });
    if (error) throw error;
    if (!data) return new Response("Calendar not found", { status: 404 });
    const body = buildCalendar(data.events ?? [], new Date());
    return new Response(req.method === "HEAD" ? null : body, {
      headers: {
        "Content-Type": "text/calendar; charset=utf-8",
        "Content-Disposition": 'inline; filename="coachsmart.ics"',
        "Cache-Control": "private, max-age=600",
      },
    });
  } catch (e) {
    console.error("calendar-feed", e);
    return new Response("Calendar unavailable, try again later", { status: 503 });
  }
});
