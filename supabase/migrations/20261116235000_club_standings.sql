-- Club dashboard league positions (Ken, 2026-11-16): a table for every
-- competition the club played in this season, worked out from all scored
-- results in gaa_games (win 2, draw 1). Only round-robin competitions
-- (a side has played 3+ games), so knockouts are left out. Officers only.
-- Returns {comps: {comp name: [[team, ours, p, w, d, l, for, against, pts, dates], ...]},
--          fixtures: {comp name: [[start_at, our team, opposition, home, venue], ...]}}
-- fixtures = the club's games still to play in those competitions.
-- sorted by pts, score difference, scored; dates (YYYY-MM-DD) only for our sides,
-- so the page can tell two of our sides in one competition apart.

CREATE OR REPLACE FUNCTION public.get_club_standings(p_club_id bigint, p_from timestamptz)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_gaa bigint;
BEGIN
    IF NOT public.is_club_officer(p_club_id) THEN
        RETURN jsonb_build_object('error', 'not_allowed');
    END IF;
    SELECT c.gaa_club_id INTO v_gaa FROM clubs c WHERE c.club_id = p_club_id;
    IF v_gaa IS NULL THEN RETURN jsonb_build_object('comps', '{}'::jsonb, 'fixtures', '{}'::jsonb); END IF;

    RETURN jsonb_build_object(
      'fixtures', COALESCE((
        SELECT jsonb_object_agg(f.name, f.rows) FROM (
          SELECT c.name, jsonb_agg(jsonb_build_array(g.start_at,
                   CASE WHEN g.home_club_id = v_gaa THEN g.home_team ELSE g.away_team END,
                   CASE WHEN g.home_club_id = v_gaa THEN g.away_team ELSE g.home_team END,
                   g.home_club_id = v_gaa, g.venue) ORDER BY g.start_at) AS rows
            FROM gaa_games g JOIN gaa_competitions c ON c.comp_id = g.comp_id
           WHERE (g.home_club_id = v_gaa OR g.away_club_id = v_gaa)
             AND g.start_at >= now() AND g.start_at >= p_from AND g.start_at < now() + interval '120 days'
             AND g.home_team <> 'Bye' AND g.away_team <> 'Bye'
           GROUP BY c.name) f), '{}'::jsonb),
      'comps', COALESCE((
        WITH ours AS (
            SELECT DISTINCT g.comp_id FROM gaa_games g
             WHERE (g.home_club_id = v_gaa OR g.away_club_id = v_gaa)
               AND g.start_at >= p_from AND g.start_at < now()
        ), gm AS (
            SELECT g.comp_id, g.start_at, g.home_team, g.away_team, g.home_club_id, g.away_club_id, g.home_pts, g.away_pts
              FROM gaa_games g JOIN ours o USING (comp_id)
             WHERE g.home_pts IS NOT NULL AND g.away_pts IS NOT NULL AND g.start_at < now()
               AND g.home_team <> 'Bye' AND g.away_team <> 'Bye'
        ), side AS (
            SELECT comp_id, home_team AS team, home_club_id AS club, home_pts AS f, away_pts AS a, start_at FROM gm
            UNION ALL
            SELECT comp_id, away_team, away_club_id, away_pts, home_pts, start_at FROM gm
        ), agg AS (
            SELECT comp_id, team, bool_or(club = v_gaa) AS ours, count(*) AS p,
                   count(*) FILTER (WHERE f > a) AS w, count(*) FILTER (WHERE f = a) AS d, count(*) FILTER (WHERE f < a) AS l,
                   sum(f) AS pf, sum(a) AS pa,
                   2 * count(*) FILTER (WHERE f > a) + count(*) FILTER (WHERE f = a) AS pts,
                   jsonb_agg(to_char(start_at AT TIME ZONE 'Europe/Dublin', 'YYYY-MM-DD')) AS dates
              FROM side GROUP BY comp_id, team
        ), rr AS (
            SELECT comp_id FROM agg GROUP BY comp_id HAVING max(p) >= 3 AND count(*) >= 3 AND bool_or(ours)
        )
        SELECT jsonb_object_agg(c.name, t.rows)
          FROM (
            SELECT a.comp_id, jsonb_agg(jsonb_build_array(a.team, a.ours, a.p, a.w, a.d, a.l, a.pf, a.pa, a.pts,
                                        CASE WHEN a.ours THEN a.dates END)
                                        ORDER BY a.pts DESC, a.pf - a.pa DESC, a.pf DESC, a.team) AS rows
              FROM agg a JOIN rr USING (comp_id)
             GROUP BY a.comp_id
          ) t JOIN gaa_competitions c ON c.comp_id = t.comp_id
    ), '{}'::jsonb));
END;
$$;

REVOKE ALL ON FUNCTION public.get_club_standings(bigint, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_club_standings(bigint, timestamptz) TO authenticated;
