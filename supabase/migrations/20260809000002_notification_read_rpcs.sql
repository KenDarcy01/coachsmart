-- Two helpers for the notifications webview:
--   mark_notification_read   — marks a single notification read (stamps when_read)
--   mark_all_notifications_read — marks every unread notification for a user read

CREATE OR REPLACE FUNCTION public.mark_notification_read(
  p_notification_id bigint,
  p_user_id         uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  UPDATE public.notifications
  SET    is_read   = true,
         when_read = NOW()
  WHERE  id                = p_notification_id
    AND  recipient_user_id = p_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_all_notifications_read(
  p_user_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  UPDATE public.notifications
  SET    is_read   = true,
         when_read = NOW()
  WHERE  recipient_user_id = p_user_id
    AND  is_read            = false;
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_notification_read(bigint, uuid)  TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_notification_read(bigint, uuid)  TO anon;
GRANT EXECUTE ON FUNCTION public.mark_all_notifications_read(uuid)     TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_all_notifications_read(uuid)     TO anon;
