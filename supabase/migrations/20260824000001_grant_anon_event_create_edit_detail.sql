-- get_user_event_edit_detail and get_user_event_create_detail are called from
-- Flutter with currentJwtToken, which is stream-based and can be '' before the
-- auth stream fires. An empty Bearer token falls back to anon role, which the
-- anon lockdown (20260817000002) revoked. Result: 403 → empty struct parsed →
-- form shows blank (no event types, no codes) → "clear screen" for affected users.
-- Both functions are SECURITY DEFINER and scoped by p_user_id, so anon execute
-- is safe — same pattern as get_user_notifications (20260822000001).

GRANT EXECUTE ON FUNCTION public.get_user_event_edit_detail(uuid, bigint) TO anon;
GRANT EXECUTE ON FUNCTION public.get_user_event_create_detail(uuid)        TO anon;
