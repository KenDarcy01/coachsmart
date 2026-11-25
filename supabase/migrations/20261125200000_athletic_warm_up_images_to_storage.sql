-- Move the Clontarf Athletic Warm Up pictures (added by 20261125190000 with URLs on
-- coachsmart.app) into Supabase storage, where every other game picture lives.
--
-- game_image_to_storage_wake(game_id) wakes the game-image-to-storage edge function
-- through pg_net with a short-lived service-role token, the way gaa_sync_wake wakes
-- gaa-sync. Migrations run before functions deploy, so a pg_cron job retries every
-- two minutes until the game's pictures are in storage, then removes itself (and
-- gives up after two hours in any case).

CREATE OR REPLACE FUNCTION public.game_image_to_storage_wake(p_game_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_secret text;
  v_jwt    text;
BEGIN
  SELECT decrypted_secret INTO v_secret FROM vault.decrypted_secrets WHERE name = 'jwt_signing_secret' LIMIT 1;
  IF v_secret IS NULL THEN
    RAISE WARNING 'game_image_to_storage_wake: jwt_signing_secret not found in vault';
    RETURN;
  END IF;
  SELECT extensions.sign(json_build_object(
           'role', 'service_role', 'iss', 'supabase', 'ref', 'gyfporsbdftvtakdvukt',
           'iat', extract(epoch from now())::integer, 'exp', (extract(epoch from now()) + 900)::integer
         )::json, v_secret) INTO v_jwt;
  PERFORM net.http_post(
    url     := 'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/game-image-to-storage',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_jwt),
    body    := jsonb_build_object('game_id', p_game_id),
    timeout_milliseconds := 60000
  );
END;
$$;
REVOKE ALL ON FUNCTION public.game_image_to_storage_wake(bigint) FROM PUBLIC, anon, authenticated;

-- One-off: keep waking the function for the warm-up game until its pictures moved.
CREATE OR REPLACE FUNCTION public.athletic_warm_up_images_tick()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_id bigint;
BEGIN
  SELECT game_id INTO v_id
  FROM public.games
  WHERE game_name = 'Clontarf Athletic Warm Up'
    AND (game_image LIKE 'https://coachsmart.app/%' OR game_details_image LIKE 'https://coachsmart.app/%')
  LIMIT 1;
  IF v_id IS NULL OR now() > timestamptz '2026-11-25 15:00:00+00' THEN
    PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'athletic-warm-up-images';
    RETURN;
  END IF;
  PERFORM public.game_image_to_storage_wake(v_id);
END;
$$;
REVOKE ALL ON FUNCTION public.athletic_warm_up_images_tick() FROM PUBLIC, anon, authenticated;

DO $$
BEGIN
  PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'athletic-warm-up-images';
  PERFORM cron.schedule('athletic-warm-up-images', '*/2 * * * *', 'SELECT public.athletic_warm_up_images_tick()');
END $$;
