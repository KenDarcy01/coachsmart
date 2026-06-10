-- app.settings.jwt_secret is not exposed on this project.
-- Instead read the raw JWT signing key from vault (name = 'jwt_signing_secret')
-- and use pgjwt to produce a fresh short-lived service_role token on every
-- cron tick. A fresh token always passes Supabase's legacy-JWT check and only
-- needs updating if the signing key is explicitly rotated (rare).
--
-- To set up: Supabase Dashboard → Settings → API → JWT Secret (Reveal)
-- then Vault → New secret, name = jwt_signing_secret, value = <that key>.

CREATE OR REPLACE FUNCTION public.check_and_send_notifications()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_signing_secret text;
  v_jwt            text;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.notifications WHERE is_delivered = false
  ) THEN
    RETURN;
  END IF;

  SELECT decrypted_secret
  INTO v_signing_secret
  FROM vault.decrypted_secrets
  WHERE name = 'jwt_signing_secret'
  LIMIT 1;

  IF v_signing_secret IS NULL THEN
    RAISE WARNING 'check_and_send_notifications: jwt_signing_secret not found in vault — aborting';
    RETURN;
  END IF;

  SELECT extensions.sign(
    json_build_object(
      'role', 'service_role',
      'iss',  'supabase',
      'ref',  'gyfporsbdftvtakdvukt',
      'iat',  extract(epoch from now())::integer,
      'exp',  (extract(epoch from now()) + 3600)::integer
    )::json,
    v_signing_secret
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
