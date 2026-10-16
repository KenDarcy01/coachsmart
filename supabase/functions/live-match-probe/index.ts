// deno-lint-ignore-file no-explicit-any
// Live match alert check: open /functions/v1/live-match-probe?event=<event_id>
// in a browser to see what happened with alerts for that match (sessions,
// timer, what was alerted, each wake and run, the server's answers).
// Counts only: no names, user ids or tokens. No sign-in needed (like the
// gaa-fixtures probe), so it never returns anything personal.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

Deno.serve(async (req) => {
  const id = Number(new URL(req.url).searchParams.get("event") || 0);
  if (!id) return new Response("Add ?event=<event id>", { status: 400 });
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
  const { data, error } = await sb.rpc("lm_alert_probe", { p_event_id: id });
  return new Response(JSON.stringify(error ? { error: error.message } : data, null, 1), {
    headers: { "Content-Type": "application/json; charset=utf-8", "Access-Control-Allow-Origin": "*" },
  });
});
