-- Reads for the season comparison pages (webviews/gaa-season.html, gaa-club.html).
-- Public fixture data only, so anon may call both.

-- Every scored result between two days, packed small so a whole season loads in one go:
--   clubs: [[club_id, name]], comps: [[comp_id, code, age, level, grade]],
--   games: [[day (YYYY-MM-DD, Dublin), comp index, home club_id, away club_id,
--            home pts, away pts, home team suffix, away team suffix]]
-- The suffix is what the team name adds to the club name ("C" for "Clontarf C").
CREATE OR REPLACE FUNCTION public.gaa_season_data(p_from date, p_to date)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  WITH g AS (
    SELECT g.*, (g.start_at AT TIME ZONE 'Europe/Dublin')::date AS day
    FROM public.gaa_games g
    WHERE g.status = 'result' AND g.home_pts IS NOT NULL AND g.away_pts IS NOT NULL
      AND g.home_club_id IS NOT NULL AND g.away_club_id IS NOT NULL
      AND (g.start_at AT TIME ZONE 'Europe/Dublin')::date BETWEEN p_from AND p_to
  ),
  comps AS (
    SELECT c.comp_id, c.code, c.age, c.level, c.grade, (row_number() OVER (ORDER BY c.comp_id) - 1)::int AS ix
    FROM public.gaa_competitions c
    WHERE c.comp_id IN (SELECT DISTINCT comp_id FROM g)
  ),
  clubs AS (
    SELECT DISTINCT k.club_id, k.name
    FROM public.gaa_clubs k
    WHERE k.club_id IN (SELECT home_club_id FROM g UNION SELECT away_club_id FROM g)
  )
  SELECT jsonb_build_object(
    'clubs', coalesce((SELECT jsonb_agg(jsonb_build_array(club_id, name) ORDER BY name) FROM clubs), '[]'::jsonb),
    'comps', coalesce((SELECT jsonb_agg(jsonb_build_array(comp_id, code, age, level, grade) ORDER BY ix) FROM comps), '[]'::jsonb),
    'games', coalesce((
      SELECT jsonb_agg(jsonb_build_array(
               to_char(g.day, 'YYYY-MM-DD'), c.ix, g.home_club_id, g.away_club_id, g.home_pts, g.away_pts,
               CASE WHEN lower(g.home_team) LIKE lower(hk.name) || '%' THEN trim(substr(g.home_team, length(hk.name) + 1)) ELSE '' END,
               CASE WHEN lower(g.away_team) LIKE lower(ak.name) || '%' THEN trim(substr(g.away_team, length(ak.name) + 1)) ELSE '' END)
             ORDER BY g.start_at)
      FROM g
      JOIN comps c ON c.comp_id = g.comp_id
      JOIN public.gaa_clubs hk ON hk.club_id = g.home_club_id
      JOIN public.gaa_clubs ak ON ak.club_id = g.away_club_id
    ), '[]'::jsonb)
  );
$$;
GRANT EXECUTE ON FUNCTION public.gaa_season_data(date, date) TO anon, authenticated;

-- How full the store is and when it last loaded, for the "Updated" line on the pages
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
    'failed_24h', (SELECT count(*) FROM public.gaa_sync_log WHERE NOT ok AND ran_at > now() - interval '24 hours'),
    'last_error', (SELECT error FROM public.gaa_sync_log WHERE NOT ok ORDER BY ran_at DESC LIMIT 1),
    'windows_ok', (SELECT count(*) FROM public.gaa_sync_log WHERE ok AND mode = 'backfill')
  );
$$;
GRANT EXECUTE ON FUNCTION public.gaa_status() TO anon, authenticated;
