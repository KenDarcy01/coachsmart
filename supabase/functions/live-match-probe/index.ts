// deno-lint-ignore-file no-explicit-any
// Live match alert check: open /functions/v1/live-match-probe?event=<event_id>
// (or ?recent=1 for the last few matches played)
// in a browser to see what happened with alerts for that match (sessions,
// timer, what was alerted, each wake and run, the server's answers).
// Counts only: no names, user ids or tokens. No sign-in needed (like the
// gaa-fixtures probe), so it never returns anything personal.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

Deno.serve(async (req) => {
  const q = new URL(req.url).searchParams;
  const id = Number(q.get("event") || 0);
  if (!id && !q.get("recent")) return new Response("Add ?event=<event id> or ?recent=1", { status: 400 });
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
  const { data, error } = id
    ? await sb.rpc("lm_alert_probe", { p_event_id: id })
    : await sb.rpc("lm_alert_probe_recent");
  return new Response(JSON.stringify(error ? { error: error.message } : data, null, 1), {
    headers: { "Content-Type": "application/json; charset=utf-8", "Access-Control-Allow-Origin": "*" },
  });
});
