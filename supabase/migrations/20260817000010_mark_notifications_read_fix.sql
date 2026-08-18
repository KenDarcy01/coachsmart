-- Migration 9 was partially applied by the GitHub Action before it was edited.
-- DROP + CREATE to resolve the "cannot change return type" conflict.

DROP FUNCTION IF EXISTS public.mark_all_notifications_read(uuid);
DROP FUNCTION IF EXISTS public.mark_notification_read(bigint);

-- ─── mark_all_notifications_read ─────────────────────────────────────────────
-- Called on notification screen load. Marks only action-less notifications
-- as read (reminders, attendance updates, general info). Action notifications
-- (approve_member, approve_access, attend) stay unread until completed.

CREATE FUNCTION public.mark_all_notifications_read(p_user_id uuid)
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
      AND is_read            = false
      AND action             IS NULL;

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RETURN v_updated;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_all_notifications_read(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.mark_all_notifications_read(uuid) TO authenticated;
GRANT  EXECUTE ON FUNCTION public.mark_all_notifications_read(uuid) TO service_role;

-- ─── mark_notification_read ───────────────────────────────────────────────────
-- Called after the user completes an action (Approve/Deny/Attend/Decline).
-- Marks that single notification as read. Returns true if updated.

CREATE FUNCTION public.mark_notification_read(p_notification_id bigint)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_updated integer;
BEGIN
    UPDATE public.notifications
    SET
        is_read   = true,
        when_read = now()
    WHERE id                = p_notification_id
      AND recipient_user_id = auth.uid()
      AND is_read           = false;

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RETURN v_updated > 0;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_notification_read(bigint) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.mark_notification_read(bigint) TO authenticated;
GRANT  EXECUTE ON FUNCTION public.mark_notification_read(bigint) TO service_role;
