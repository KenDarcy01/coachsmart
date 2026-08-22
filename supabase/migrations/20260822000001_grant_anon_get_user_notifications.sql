-- get_user_notifications is called from Flutter with the anon key (no user JWT).
-- The anon lockdown migration (20260817000002) revoked this grant, causing all
-- notification list calls to fail with 400. The function is SECURITY DEFINER
-- and scoped to p_user_id, so anon execute is safe.

GRANT EXECUTE ON FUNCTION public.get_user_notifications(uuid, integer) TO anon;
