// Supabase Edge Function: publish the senior diary plan from the Google Sheet.
//
//   POST /functions/v1/diary-sheet-publish
//   headers: Authorization: Bearer <anon key>, x-diary-secret: <DIARY_SHEET_SECRET>
//   body:    { by: "coach@email", dryRun?: true, tabs: { Settings: [[...]], Blocks, Sessions, Schedule, Notes } }
//
// Called only by the Apps Script in the coaches' sheet (tools/senior-diary-sheet/Code.gs).
// Who can publish = who can edit that sheet; the script holds the shared secret.
// Each tab arrives as rows of cells (first row = headings, dates already yyyy-mm-dd).
// parse.ts checks everything; nothing is saved if any row has an error, and the
// errors go back to the coach with tab and row number. dryRun returns the plan
// without saving it.
//
// The saved plan has the shape coachsmart.app/clontarf-gaa/senior-diary/ draws:
// blocks, sessions by code, and the team schedule by date. Player rows (their
// own schedule for a day, or coach notes) go to diary_player_days by email.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { build, sameSecret, tidy } from "./parse.ts";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

serve(async (req) => {
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  if (!sameSecret(req.headers.get("x-diary-secret") ?? "", Deno.env.get("DIARY_SHEET_SECRET") ?? "")) {
    return json({ error: "This sheet is not allowed to publish. Check the DIARY_SECRET script property." }, 403);
  }

  let body: { by?: string; dryRun?: boolean; tabs?: Record<string, unknown> };
  try { body = await req.json(); } catch { return json({ error: "Not JSON" }, 400); }

  const { errors, warnings, plan, players = [], summary } = build(body.tabs ?? {});
  if (errors.length) return json({ ok: false, errors, warnings }, 422);
  if (body.dryRun) return json({ ok: true, dryRun: true, summary, warnings, plan, players });

  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data, error } = await sb.rpc("diary_publish", { p_plan: plan, p_players: players, p_by: tidy(body.by) || null });
  if (error) {
    console.error("diary_publish failed", error);
    return json({ ok: false, errors: ["Saving failed: " + error.message] }, 500);
  }

  const unmatched: string[] = data?.unmatched ?? [];
  unmatched.forEach((e) => warnings.push(`${e} has no CoachSmart login yet. Their rows are saved and will show once they sign up with that email.`));
  return json({ ok: true, summary, warnings });
});
