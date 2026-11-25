-- One-off (Ken, 2026-11-25): reload the whole 2026 season from Sportlomo, every code.
-- Each week was loaded once by the backfill (mostly on 17 Oct) and is only refreshed
-- by the nightly load while it is within two weeks of today, so results that Sportlomo
-- added or fixed later never reached gaa_games. Found on the Clontarf 2013 girls Div 6
-- report: five LGFA U13 results (22 Mar, 27 Sep) were missing.
--
-- The backfill picks the first week with no successful 'backfill' row, so renaming
-- the old rows makes it walk the season again from 1 January. Each week replaces its
-- stored games (the existing guard keeps the stored games if Sportlomo returns less
-- than half of them). A temporary job runs the backfill every 5 minutes (about 4 to 5
-- hours for the year) and is removed after 7 hours by a second one-off job.
UPDATE public.gaa_sync_log
   SET mode = 'backfill-2026-10'
 WHERE mode = 'backfill' AND code IS NOT NULL;

DO $$
DECLARE
  t timestamptz := (now() AT TIME ZONE 'UTC') + interval '7 hours';
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule(jobname) FROM cron.job WHERE jobname IN ('gaa-season-reload', 'gaa-season-reload-stop');
    PERFORM cron.schedule('gaa-season-reload', '*/5 * * * *', $c$SELECT public.gaa_sync_wake('backfill')$c$);
    PERFORM cron.schedule('gaa-season-reload-stop',
      format('%s %s %s %s *', extract(minute FROM t)::int, extract(hour FROM t)::int,
             extract(day FROM t)::int, extract(month FROM t)::int),
      $c$SELECT cron.unschedule('gaa-season-reload'); SELECT cron.unschedule('gaa-season-reload-stop')$c$);
  END IF;
END;
$$;

SELECT public.gaa_sync_wake('backfill');
