-- Replace hardcoded service_role JWT in check_and_send_notifications with
-- a vault lookup. The secret must already exist in vault.secrets with
-- name = 'service_role_key' before this migration is applied.

CREATE OR REPLACE FUNCTION public.check_and_send_notifications()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  has_pending_notifications boolean;
  v_service_role_key        text;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM public.notifications
    WHERE is_delivered = false
  ) INTO has_pending_notifications;

  IF has_pending_notifications THEN
    SELECT decrypted_secret
    INTO v_service_role_key
    FROM vault.decrypted_secrets
    WHERE name = 'service_role_key'
    LIMIT 1;

    IF v_service_role_key IS NULL THEN
      RAISE WARNING 'check_and_send_notifications: service_role_key not found in vault — aborting';
      RETURN;
    END IF;

    PERFORM net.http_post(
      url     := 'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/cron_batch_notification_send',
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || v_service_role_key
      ),
      body    := '{}'::jsonb
    );
  END IF;
END;
$$;
