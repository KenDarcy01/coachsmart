import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Soft-delete: sets users.deleted_at and bans the auth user.
// Nothing is hard-deleted — all history is preserved for reinstatement.
// To reinstate: clear deleted_at and call auth.admin.updateUserById({ ban_duration: 'none' }).

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

Deno.serve(async (req) => {
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

    // Admin client for privileged operations
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    // 1. Stamp deleted_at on the user profile — all other data stays intact
    const { error: stampError } = await admin
      .from("users")
      .update({ deleted_at: new Date().toISOString() })
      .eq("user_id", uid);

    if (stampError) {
      console.error("Failed to stamp deleted_at:", stampError.message);
      return json({ error: "Failed to delete account. Please try again." }, 500);
    }

    // 2. Ban the auth user so they cannot sign in (100-year duration = effectively permanent).
    //    Existing sessions are immediately invalidated.
    //    To reinstate: updateUserById(uid, { ban_duration: 'none' }) + clear deleted_at.
    const { error: banError } = await admin.auth.admin.updateUserById(uid, {
      ban_duration: "876000h",
    });

    if (banError) {
      // Roll back the deleted_at stamp so the state stays consistent
      await admin.from("users").update({ deleted_at: null }).eq("user_id", uid);
      console.error("Failed to ban auth user:", banError.message);
      return json({ error: "Failed to delete account. Please try again." }, 500);
    }

    return json({ success: true });
  } catch (e) {
    console.error("delete-account error:", e);
    return json({ error: "Internal server error" }, 500);
  }
});
