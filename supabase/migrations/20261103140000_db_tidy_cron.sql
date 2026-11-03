-- Database tidy-up (Ken, 2026-11-03).
--
-- 1. cron.job_run_details had kept every pg_cron run since March (341k rows,
--    59 MB) and grows by about 3,200 rows a day. Keep a week of history and
--    clear the rest every night. The space freed is reused, so it stops growing.
-- 2. gaa-season-backfill ran every 5 minutes (four edge function calls each
--    time) but only has new work once a week, when another week comes inside
--    the four-weeks-ahead horizon, and at New Year. Hourly is plenty and cuts
--    about 1,150 idle calls a day to 96.

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule(jobname) FROM cron.job WHERE jobname = 'cron-history-cleanup';
    PERFORM cron.schedule('cron-history-cleanup', '45 3 * * *',
      $c$DELETE FROM cron.job_run_details WHERE end_time < now() - interval '7 days'$c$);

    PERFORM cron.unschedule(jobname) FROM cron.job WHERE jobname = 'gaa-season-backfill';
    PERFORM cron.schedule('gaa-season-backfill', '7 * * * *', $c$SELECT public.gaa_sync_wake('backfill')$c$);
  END IF;
END;
$$;
