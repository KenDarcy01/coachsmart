-- Daytime top-up for one club (Ken, 2026-10-22): Clontarf's games are reloaded at
-- 13:30 Irish time as well as in the nightly all-clubs load, so fixtures moved
-- during the day reach the club website sooner. Every code, two weeks back to
-- four weeks ahead, fetched with Sportlomo's club filter (gaa-sync mode "club").

-- Replaces one club's games for the given codes between two Dublin days.
-- Same as gaa_replace_window, but only deletes games that club plays in.
CREATE OR REPLACE FUNCTION public.gaa_replace_club_window(p_from date, p_to date, p_codes text[], p_club_id int, p_games jsonb)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_n int;
BEGIN
  INSERT INTO public.gaa_competitions (comp_id, name, code, age, grade, level, season, updated_at)
  SELECT DISTINCT ON (g->>'compId') g->>'compId', g->>'comp', g->>'code', g->>'age', coalesce(g->>'grade', ''),
         g->>'level', extract(year FROM (g->>'start')::timestamptz AT TIME ZONE 'Europe/Dublin')::int, now()
  FROM jsonb_array_elements(p_games) g
  ORDER BY g->>'compId'
  ON CONFLICT (comp_id) DO UPDATE
    SET name = EXCLUDED.name, code = EXCLUDED.code, age = EXCLUDED.age,
        grade = EXCLUDED.grade, level = EXCLUDED.level, updated_at = now();

  DELETE FROM public.gaa_games
   WHERE code = ANY (p_codes)
     AND (home_club_id = p_club_id OR away_club_id = p_club_id)
     AND (start_at AT TIME ZONE 'Europe/Dublin')::date BETWEEN p_from AND p_to;

  INSERT INTO public.gaa_games (comp_id, code, start_at, home_team, away_team, home_club_id, away_club_id,
                                status, home_score, away_score, home_pts, away_pts, venue, referee, note)
  SELECT g->>'compId', g->>'code', (g->>'start')::timestamptz, g->>'home', g->>'away',
         public.gaa_club_for(g->>'homeClub', g->>'org', g->>'homeClubId'),
         public.gaa_club_for(g->>'awayClub', g->>'org', g->>'awayClubId'),
         g->>'status', coalesce(g->>'hs', ''), coalesce(g->>'as', ''),
         (g->>'hp')::int, (g->>'ap')::int,
         coalesce(g->>'venue', ''), coalesce(g->>'referee', ''), coalesce(g->>'note', '')
  FROM jsonb_array_elements(p_games) g
  ON CONFLICT (comp_id, home_team, away_team, start_at) DO UPDATE
    SET status = EXCLUDED.status, home_score = EXCLUDED.home_score, away_score = EXCLUDED.away_score,
        home_pts = EXCLUDED.home_pts, away_pts = EXCLUDED.away_pts, venue = EXCLUDED.venue,
        referee = EXCLUDED.referee, note = EXCLUDED.note, synced_at = now();
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$$;
REVOKE ALL ON FUNCTION public.gaa_replace_club_window(date, date, text[], int, jsonb) FROM PUBLIC, anon, authenticated;

-- Wakes gaa-sync for one club, but only in the 13:00 hour Irish time. pg_cron runs
-- in UTC, so the job is scheduled at 12:30 and 13:30 UTC and this keeps whichever
-- one is 13:30 in Dublin (summer or winter time).
CREATE OR REPLACE FUNCTION public.gaa_sync_wake_club(p_club text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_secret text;
  v_jwt    text;
BEGIN
  IF extract(hour FROM now() AT TIME ZONE 'Europe/Dublin') <> 13 THEN RETURN; END IF;
  SELECT decrypted_secret INTO v_secret FROM vault.decrypted_secrets WHERE name = 'jwt_signing_secret' LIMIT 1;
  IF v_secret IS NULL THEN
    RAISE WARNING 'gaa_sync_wake_club: jwt_signing_secret not found in vault';
    RETURN;
  END IF;
  SELECT extensions.sign(json_build_object(
           'role', 'service_role', 'iss', 'supabase', 'ref', 'gyfporsbdftvtakdvukt',
           'iat', extract(epoch from now())::integer, 'exp', (extract(epoch from now()) + 900)::integer
         )::json, v_secret) INTO v_jwt;
  PERFORM net.http_post(
    url     := 'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/gaa-sync',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_jwt),
    body    := jsonb_build_object('mode', 'club', 'club', p_club),
    timeout_milliseconds := 300000
  );
END;
$$;
REVOKE ALL ON FUNCTION public.gaa_sync_wake_club(text) FROM PUBLIC, anon, authenticated;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule(jobname) FROM cron.job WHERE jobname = 'gaa-club-clontarf';
    PERFORM cron.schedule('gaa-club-clontarf', '30 12,13 * * *', $c$SELECT public.gaa_sync_wake_club('clontarf')$c$);
  END IF;
END;
$$;

-- First run now, so the top-up is proven today (does nothing outside 13:00-14:00 Irish time)
SELECT public.gaa_sync_wake_club('clontarf');
