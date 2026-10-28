// Supabase Edge Function: a team's CoachSmart events for a public diary page.
//
//   GET /functions/v1/team-diary?code=TMA47A5&from=2026-10-26&to=2027-04-25
//
// Used by coachsmart.app/clontarf-gaa/feile27/ (Clontarf Girls 2012 Féile diary).
// Public (no JWT), so only teams listed in TEAMS can be read, and only what a
// diary needs: date, time, type, code, title, squad, opposition, meet time and
// venue. Event details are never returned (they can hold players' names).
// Times are the event's wall-clock time (events.event_date_time_2).
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

// Team codes whose diary is public. Add a code here to open another team's diary.
const TEAMS = ["TMA47A5"];

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json", "Cache-Control": status === 200 ? "public, max-age=300" : "no-store" },
  });

const isDay = (s: string | null) => !!s && /^\d{4}-\d{2}-\d{2}$/.test(s);
const tidy = (s: unknown) => String(s ?? "").replace(/\s+/g, " ").trim();

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const url = new URL(req.url);
    const code = tidy(url.searchParams.get("code")).toUpperCase();
    if (!TEAMS.includes(code)) return json({ error: "This team's diary is not public" }, 404);

    const today = new Date().toISOString().slice(0, 10);
    const from = isDay(url.searchParams.get("from")) ? url.searchParams.get("from")! : today;
    const to = isDay(url.searchParams.get("to")) ? url.searchParams.get("to")! : today;
    if (Date.parse(to) - Date.parse(from) > 400 * 864e5 || to < from) return json({ error: "Bad date range" }, 400);

    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

    const { data: team } = await sb.from("teams").select("team_id, team_name").eq("team_unique_code", code).maybeSingle();
    if (!team) return json({ error: "Team not found" }, 404);

    const [{ data: events, error }, { data: squads }, { data: codes }, { data: types }] = await Promise.all([
      sb.from("events")
        .select("event_id, event_title, event_date_time_2, meet_time, opposition, location_name, status, event_type_id, event_code_id, squad_id")
        .eq("team_id", team.team_id)
        .gte("event_date_time_2", `${from}T00:00:00`)
        .lte("event_date_time_2", `${to}T23:59:59`)
        .order("event_date_time_2"),
      sb.from("squads").select("squad_id, squad_name, squad_colour").eq("team_id", team.team_id),
      sb.from("event_codes").select("code_id, event_code"),
      sb.from("event_types").select("event_type_id, event_type"),
    ]);
    if (error) throw error;

    const squad = new Map((squads || []).map((s: any) => [s.squad_id, s]));
    const codeName = new Map((codes || []).map((c: any) => [c.code_id, c.event_code]));
    const typeName = new Map((types || []).map((t: any) => [t.event_type_id, t.event_type]));

    const out = (events || [])
      .filter((e: any) => e.status !== "deleted")
      .map((e: any) => {
        const dt = String(e.event_date_time_2 || "");
        const s = squad.get(e.squad_id) as any;
        return {
          id: e.event_id,
          date: dt.slice(0, 10),
          start: dt.slice(11, 16),
          type: typeName.get(e.event_type_id) || null,
          code: codeName.get(e.event_code_id) || null,
          title: tidy(e.event_title),
          squad: s && s.squad_name !== "No Team" ? s.squad_name : null,
          squadColour: s ? s.squad_colour : null,
          opposition: tidy(e.opposition) || null,
          meet: tidy(e.meet_time) || null,
          location: tidy(e.location_name) || null,
          cancelled: e.status === "cancelled",
        };
      });

    return json({ team: team.team_name, from, to, events: out });
  } catch (e) {
    console.error(e);
    return json({ error: (e as Error).message || "Something went wrong" }, 500);
  }
});
