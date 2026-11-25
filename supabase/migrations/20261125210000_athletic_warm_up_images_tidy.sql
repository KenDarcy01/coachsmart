-- The warm-up game's pictures are in coachsmartimages now (game-image-to-storage ran
-- at 12:42 UTC), so the one-off pg_cron job and its tick function from
-- 20261125200000 can go. game_image_to_storage_wake(game_id) stays for reuse.
DO $$
BEGIN
  PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'athletic-warm-up-images';
END $$;
DROP FUNCTION IF EXISTS public.athletic_warm_up_images_tick();
