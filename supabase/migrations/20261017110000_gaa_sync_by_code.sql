-- Season store loader: one code and one week per call (was every code for two
-- weeks), so each call stays inside the edge function time and CPU limits.
-- The bigger calls were being stopped mid-load once the season got busy, which
-- left the backfill stuck in late spring without logging a failure.

ALTER TABLE public.gaa_sync_log ADD COLUMN IF NOT EXISTS code text;
CREATE INDEX IF NOT EXISTS gaa_sync_log_code ON public.gaa_sync_log (mode, code, from_day);

-- Wakes gaa-sync once per code, each with its own short-lived service-role token
CREATE OR REPLACE FUNCTION public.gaa_sync_wake(p_mode text, p_part int DEFAULT 0)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_secret text;
  v_jwt    text;
  v_code   text;
BEGIN
  SELECT decrypted_secret INTO v_secret FROM vault.decrypted_secrets WHERE name = 'jwt_signing_secret' LIMIT 1;
  IF v_secret IS NULL THEN
    RAISE WARNING 'gaa_sync_wake: jwt_signing_secret not found in vault';
    RETURN;
  END IF;
  SELECT extensions.sign(json_build_object(
           'role', 'service_role', 'iss', 'supabase', 'ref', 'gyfporsbdftvtakdvukt',
           'iat', extract(epoch from now())::integer, 'exp', (extract(epoch from now()) + 900)::integer
         )::json, v_secret) INTO v_jwt;
  FOREACH v_code IN ARRAY ARRAY['Football', 'Hurling', 'Camogie', 'Ladies Football'] LOOP
    PERFORM net.http_post(
      url     := 'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/gaa-sync',
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_jwt),
      body    := jsonb_build_object('mode', p_mode, 'part', p_part, 'code', v_code),
      timeout_milliseconds := 300000
    );
  END LOOP;
END;
$$;
REVOKE ALL ON FUNCTION public.gaa_sync_wake(text, int) FROM PUBLIC, anon, authenticated;

-- Backfill every 5 minutes (four codes at once, a week each). Nightly: six weeks,
-- from two weeks ago to four weeks ahead, five minutes apart.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule(jobname) FROM cron.job WHERE jobname LIKE 'gaa-season-%';
    PERFORM cron.schedule('gaa-season-backfill', '*/5 * * * *', $c$SELECT public.gaa_sync_wake('backfill')$c$);
    PERFORM cron.schedule('gaa-season-nightly-' || p, (10 + p * 5) || ' 4 * * *', format($c$SELECT public.gaa_sync_wake('nightly', %s)$c$, p))
      FROM generate_series(0, 5) p;
  END IF;
END;
$$;

-- Load status for the pages: a backfill week counts once every code has loaded it
CREATE OR REPLACE FUNCTION public.gaa_status()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT jsonb_build_object(
    'games',      (SELECT count(*) FROM public.gaa_games),
    'results',    (SELECT count(*) FROM public.gaa_games WHERE status = 'result'),
    'clubs',      (SELECT count(*) FROM public.gaa_clubs),
    'first_day',  (SELECT min((start_at AT TIME ZONE 'Europe/Dublin')::date) FROM public.gaa_games),
    'last_day',   (SELECT max((start_at AT TIME ZONE 'Europe/Dublin')::date) FROM public.gaa_games),
    'last_ok',    (SELECT max(ran_at) FROM public.gaa_sync_log WHERE ok),
    'failed_24h', (SELECT count(*) FROM public.gaa_sync_log WHERE NOT ok AND ran_at > now() - interval '24 hours'
                     AND ran_at < now() - interval '10 minutes'),
    'last_error', (SELECT error FROM public.gaa_sync_log WHERE NOT ok AND ran_at < now() - interval '10 minutes' ORDER BY ran_at DESC LIMIT 1),
    'windows_ok', (SELECT count(*) FROM public.gaa_sync_log WHERE ok AND mode = 'backfill' AND code IS NOT NULL),
    'backfill_to',(SELECT min(w) FROM (SELECT code, max(to_day) AS w FROM public.gaa_sync_log
                     WHERE ok AND mode = 'backfill' AND code IS NOT NULL GROUP BY code) x),
    'backfill_codes', (SELECT count(DISTINCT code) FROM public.gaa_sync_log WHERE ok AND mode = 'backfill' AND code IS NOT NULL)
  );
$$;
GRANT EXECUTE ON FUNCTION public.gaa_status() TO anon, authenticated;
