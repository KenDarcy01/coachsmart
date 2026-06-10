-- Replace vault-stored JWT with a dynamically signed token so the cron
-- delivery call never breaks when Supabase rotates the JWT signing key.
--
-- pgjwt uses pgcrypto (already enabled) to produce a short-lived
-- service_role JWT signed with app.settings.jwt_secret, which Supabase
-- keeps in sync with the project's current signing key.

CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";

CREATE OR REPLACE FUNCTION public.check_and_send_notifications()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_jwt  text;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.notifications WHERE is_delivered = false
  ) THEN
    RETURN;
  END IF;

  -- Build a short-lived (1 hour) service_role JWT using the project's
  -- current signing key. This stays valid across key rotations because
  -- app.settings.jwt_secret is always up to date.
  SELECT extensions.sign(
    json_build_object(
      'role', 'service_role',
      'iss',  'supabase',
      'ref',  'gyfporsbdftvtakdvukt',
      'iat',  extract(epoch from now())::integer,
      'exp',  (extract(epoch from now()) + 3600)::integer
    )::json,
    current_setting('app.settings.jwt_secret')
  ) INTO v_jwt;

  PERFORM net.http_post(
    url     := 'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/cron_batch_notification_send',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_jwt
    ),
    body    := '{}'::jsonb
  );
END;
$$;
