// Supabase Edge Function: the Féile diary's Google Sheet.
//
//   POST /functions/v1/team-diary-sheet
//   headers: Authorization: Bearer <anon key>, x-diary-secret: <secret for the team>
//   body:    { code: "TMA47A5", action: "publish", by, dryRun?, tabs: { Events: [[...]], Activities, Notes } }
//            { code: "TMA47A5", action: "suggestions" }
//
// Called only by the Apps Script in the coaches' sheet (tools/girls-diary-sheet/Code.gs).
// Each team's secret is the TEAM_DIARY_SECRET_<CODE> function secret.
//
// publish:     checks the Live rows (parse.ts) and saves them to team_diary_sheet,
//              which the public team-diary function hands to the diary page.
//              Nothing is saved if any Live row has an error.
// suggestions: returns rows Claude has suggested (team_diary_suggestions) and
//              marks them pulled, so the sheet adds each one once.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { build, HEADINGS, sameSecret, tidy } from "./parse.ts";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

serve(async (req) => {
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  let body: { code?: string; action?: string; by?: string; dryRun?: boolean; tabs?: Record<string, string[][]> };
  try { body = await req.json(); } catch { return json({ error: "Not JSON" }, 400); }

  const code = tidy(body.code).toUpperCase();
  if (!/^[A-Z0-9]{4,12}$/.test(code)) return json({ error: "No team code" }, 400);
  if (!sameSecret(req.headers.get("x-diary-secret") ?? "", Deno.env.get(`TEAM_DIARY_SECRET_${code}`) ?? "")) {
    return json({ error: "This sheet isn't allowed to publish. Check the DIARY_SECRET script property." }, 403);
  }
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

  if (body.action === "suggestions") {
    const { data, error } = await sb.from("team_diary_suggestions")
      .select("id, tab, row").eq("team_code", code).is("pulled_at", null).order("id");
    if (error) return json({ ok: false, error: error.message }, 500);
    const rows = (data ?? []).map((s: any) => ({ tab: s.tab, cells: HEADINGS[s.tab].map((h) => h === "Status" ? "Suggested" : String(s.row?.[h] ?? "")) }));
    if (data?.length) {
      const { error: e2 } = await sb.from("team_diary_suggestions").update({ pulled_at: new Date().toISOString() }).in("id", data.map((s: any) => s.id));
      if (e2) return json({ ok: false, error: e2.message }, 500);
    }
    return json({ ok: true, headings: HEADINGS, rows });
  }

  if (body.action !== "publish") return json({ error: "Unknown action" }, 400);
  const { errors, warnings, data, summary } = build(body.tabs ?? {});
  if (errors.length) return json({ ok: false, errors, warnings }, 422);
  if (body.dryRun) return json({ ok: true, dryRun: true, summary, warnings, data });

  const { error } = await sb.from("team_diary_sheet").upsert({ team_code: code, data, published_at: new Date().toISOString(), published_by: tidy(body.by) || null });
  if (error) {
    console.error("team_diary_sheet save failed", error);
    return json({ ok: false, errors: ["Saving failed: " + error.message] }, 500);
  }
  return json({ ok: true, summary, warnings });
});
