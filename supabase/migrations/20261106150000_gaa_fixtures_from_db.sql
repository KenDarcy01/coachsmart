-- Fixtures page (webviews/gaa-fixtures.html) reads from the season store instead of
-- live Sportlomo. Sportlomo is only touched by the gaa-sync loader now.
--
-- gaa_fixtures: games in the page's JSON shape, either
--   * every game in one competition (p_comp, whole season, for the competition panel), or
--   * games between two Dublin days, for one club (p_club = club name, any alias) or all clubs.
-- gaa_fixtures_clubs: names of every club with a stored game, for the club picker.
-- Read-only, anon allowed: the same data the season pages already expose.

CREATE OR REPLACE FUNCTION public.gaa_fixtures(
  p_from date DEFAULT NULL, p_to date DEFAULT NULL, p_club text DEFAULT NULL, p_comp text DEFAULT NULL)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  WITH club AS (
    SELECT k.club_id FROM public.gaa_clubs k
    WHERE coalesce(p_club, '') <> ''
      AND (k.name_key = public.gaa_key(p_club) OR public.gaa_key(p_club) = ANY (k.alias_keys))
    LIMIT 1
  ),
  g AS (
    SELECT g.* FROM public.gaa_games g
    WHERE lower(g.home_team) <> 'bye' AND lower(g.away_team) <> 'bye'
      AND CASE
        WHEN coalesce(p_comp, '') <> '' THEN g.comp_id = p_comp
        ELSE (g.start_at AT TIME ZONE 'Europe/Dublin')::date BETWEEN p_from AND p_to
          AND (coalesce(p_club, '') = ''
               OR g.home_club_id = (SELECT club_id FROM club)
               OR g.away_club_id = (SELECT club_id FROM club))
      END
  )
  SELECT coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
      'kind', g.status,
      'competition', c.name,
      'competitionId', g.comp_id,
      'age', c.age,
      'grade', c.grade,
      'code', coalesce(nullif(c.code, ''), g.code),
      'start', to_char(g.start_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'home', g.home_team,
      'away', g.away_team,
      'homeClub', hk.name,
      'awayClub', ak.name,
      'homeClubId', g.home_club_id,
      'awayClubId', g.away_club_id,
      'score', CASE WHEN g.status = 'result' AND g.home_score <> '' THEN
                 replace(g.home_score, '-', ' - ') || ' v ' || replace(g.away_score, '-', ' - ') END,
      'venue', nullif(g.venue, ''),
      'referee', nullif(g.referee, ''),
      'note', nullif(g.note, '')
    )) ORDER BY g.start_at, g.game_id), '[]'::jsonb)
  FROM g
  JOIN public.gaa_competitions c ON c.comp_id = g.comp_id
  LEFT JOIN public.gaa_clubs hk ON hk.club_id = g.home_club_id
  LEFT JOIN public.gaa_clubs ak ON ak.club_id = g.away_club_id;
$$;
GRANT EXECUTE ON FUNCTION public.gaa_fixtures(date, date, text, text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.gaa_fixtures_clubs()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT coalesce(jsonb_agg(k.name ORDER BY k.name), '[]'::jsonb)
  FROM public.gaa_clubs k
  WHERE EXISTS (SELECT 1 FROM public.gaa_games g WHERE g.home_club_id = k.club_id OR g.away_club_id = k.club_id);
$$;
GRANT EXECUTE ON FUNCTION public.gaa_fixtures_clubs() TO anon, authenticated;
