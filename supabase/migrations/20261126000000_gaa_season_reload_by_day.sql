-- One-off (Ken, 2026-11-25): reload the 2026 season again, now that gaa-sync fetches
-- one day per request. The first reload (20261125220000) still missed games because
-- Sportlomo's all-clubs list drops games when a request spans a whole week.
--
-- Same method as before: rename the finished backfill rows so the backfill walks the
-- season again from 1 January. The 5-minute job starts 10 minutes after this runs, so
-- the new gaa-sync (deployed in the same workflow, after the migrations) is live
-- first. Both one-off jobs remove themselves; the reload stops after 8 hours.
UPDATE public.gaa_sync_log
   SET mode = 'backfill-2026-11-25'
 WHERE mode = 'backfill' AND code IS NOT NULL;

DO $$
DECLARE
  s timestamptz := (now() AT TIME ZONE 'UTC') + interval '10 minutes';
  e timestamptz := (now() AT TIME ZONE 'UTC') + interval '8 hours';
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule(jobname) FROM cron.job
     WHERE jobname IN ('gaa-season-reload', 'gaa-season-reload-stop', 'gaa-season-reload-start');
    PERFORM cron.schedule('gaa-season-reload-start',
      format('%s %s %s %s *', extract(minute FROM s)::int, extract(hour FROM s)::int,
             extract(day FROM s)::int, extract(month FROM s)::int),
      $c$SELECT cron.schedule('gaa-season-reload', '*/5 * * * *', $j$SELECT public.gaa_sync_wake('backfill')$j$); SELECT cron.unschedule('gaa-season-reload-start')$c$);
    PERFORM cron.schedule('gaa-season-reload-stop',
      format('%s %s %s %s *', extract(minute FROM e)::int, extract(hour FROM e)::int,
             extract(day FROM e)::int, extract(month FROM e)::int),
      $c$SELECT cron.unschedule('gaa-season-reload'); SELECT cron.unschedule('gaa-season-reload-stop')$c$);
  END IF;
END;
$$;
