-- Mark all unread notifications as read for a given user.
-- Called on notification screen load so the badge clears immediately.
-- auth.uid() must match p_user_id — users can only clear their own notifications.
-- Returns the number of rows updated (useful for badge count logic).

CREATE OR REPLACE FUNCTION public.mark_all_notifications_read(p_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_updated integer;
BEGIN
    IF auth.uid() IS DISTINCT FROM p_user_id THEN
        RETURN 0;
    END IF;

    UPDATE public.notifications
    SET
        is_read   = true,
        when_read = now()
    WHERE recipient_user_id = p_user_id
      AND is_read = false;

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RETURN v_updated;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_all_notifications_read(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.mark_all_notifications_read(uuid) TO authenticated;
GRANT  EXECUTE ON FUNCTION public.mark_all_notifications_read(uuid) TO service_role;
