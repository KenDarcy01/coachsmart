-- Newsletter nightly crawl (Ken, 2026-11-26: "crawl the strip nightly and save
-- it in our DB ... only holds a month's worth"). Each night pg_cron wakes the
-- newsletter edge function ("harvest") with a short-lived service-role token,
-- the same way gaa_sync_wake wakes gaa-sync. It saves every post on each
-- club's website / Instagram strip into newsletter_posts, then posts older
-- than a month are deleted (photos already copied into issues are kept).

CREATE OR REPLACE FUNCTION public.newsletter_harvest_wake()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_secret text;
  v_jwt    text;
BEGIN
  DELETE FROM public.newsletter_posts
  WHERE at < (extract(epoch from now() - interval '31 days') * 1000)::bigint;

  SELECT decrypted_secret INTO v_secret FROM vault.decrypted_secrets WHERE name = 'jwt_signing_secret' LIMIT 1;
  IF v_secret IS NULL THEN
    RAISE WARNING 'newsletter_harvest_wake: jwt_signing_secret not found in vault';
    RETURN;
  END IF;
  SELECT extensions.sign(json_build_object(
           'role', 'service_role', 'iss', 'supabase', 'ref', 'gyfporsbdftvtakdvukt',
           'iat', extract(epoch from now())::integer, 'exp', (extract(epoch from now()) + 900)::integer
         )::json, v_secret) INTO v_jwt;
  PERFORM net.http_post(
    url     := 'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/newsletter',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_jwt),
    body    := jsonb_build_object('action', 'harvest'),
    timeout_milliseconds := 60000
  );
END;
$$;
REVOKE ALL ON FUNCTION public.newsletter_harvest_wake() FROM PUBLIC, anon, authenticated;

-- 23:40 UTC every night.
DO $$
BEGIN
  PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'newsletter-harvest';
  PERFORM cron.schedule('newsletter-harvest', '40 23 * * *', 'SELECT public.newsletter_harvest_wake()');
END $$;
