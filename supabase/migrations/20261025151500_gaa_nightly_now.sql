-- One-off (Ken, 2026-10-25): run the full nightly Sportlomo load now instead of
-- waiting for 04:10. Each of the six nightly weeks (two weeks ago to four weeks
-- ahead, every code) gets its own one-off cron job, five minutes apart like the
-- real nightly run, and each job removes itself after it fires.
DO $$
DECLARE
  t timestamptz;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    FOR p IN 0..5 LOOP
      t := (now() AT TIME ZONE 'UTC') + make_interval(mins => 2 + p * 5);
      PERFORM cron.unschedule(jobname) FROM cron.job WHERE jobname = 'gaa-season-now-' || p;
      PERFORM cron.schedule('gaa-season-now-' || p,
        format('%s %s %s %s *', extract(minute FROM t)::int, extract(hour FROM t)::int,
               extract(day FROM t)::int, extract(month FROM t)::int),
        format($c$SELECT public.gaa_sync_wake('nightly', %s); SELECT cron.unschedule('gaa-season-now-%s')$c$, p, p));
    END LOOP;
  ELSE
    PERFORM public.gaa_sync_wake('nightly', p) FROM generate_series(0, 5) p;
  END IF;
END;
$$;
