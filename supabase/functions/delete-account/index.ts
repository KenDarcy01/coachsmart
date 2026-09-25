import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Unauthorized" }, 401);

    // Verify caller using their own JWT
    const sb = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user }, error: userError } = await sb.auth.getUser();
    if (userError || !user) return json({ error: "Unauthorized" }, 401);

    const uid = user.id;

    // Admin client for privileged deletes
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    // 1. Delete notifications
    await admin.from("notifications").delete().eq("user_id", uid);

    // 2. Remove user↔member links (member records belong to the club, not the user)
    await admin.from("user_member_link").delete().eq("user_id", uid);

    // 3. Delete payment records linked directly to the user
    await admin.from("event_user_payment").delete().eq("user_id", uid).throwOnError().catch(() => {});
    await admin.from("event_user_member_payment").delete().eq("user_id", uid).throwOnError().catch(() => {});

    // 4. Delete the user profile
    await admin.from("users").delete().eq("user_id", uid);

    // 5. Delete the auth record — user can no longer sign in after this
    const { error: deleteError } = await admin.auth.admin.deleteUser(uid);
    if (deleteError) {
      console.error("auth.admin.deleteUser failed:", deleteError.message);
      return json({ error: "Failed to delete account. Please contact support." }, 500);
    }

    return json({ success: true });
  } catch (e) {
    console.error("delete-account error:", e);
    return json({ error: "Internal server error" }, 500);
  }
});
