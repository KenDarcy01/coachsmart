-- Club Home "Coming up" Fixtures / Results pill (Ken 2026-11-27, "Build it").
-- Recent official results (gaa_games, the season store) for the user's
-- clubs, newest first, plus each club's primary colour for the diary icon.
-- Every result shows its score, losses too (Ken 2026-11-27: "Show the
-- results for the losses also"). Read-only; v2 never calls it.

CREATE OR REPLACE FUNCTION public.get_club_home_results(p_club_ids bigint[], p_days integer DEFAULT 14)
 RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
  WITH cl AS (
    SELECT c.club_id, c.gaa_club_id, c.primary_colour
      FROM clubs c WHERE c.club_id = ANY (p_club_ids)
  ),
  g AS (
    SELECT cl.club_id, g.*, (g.home_club_id = cl.gaa_club_id) AS home,
           comp.name AS comp_name, comp.age, coalesce(nullif(comp.code, ''), g.code) AS code_name
      FROM cl
      JOIN gaa_games g ON cl.gaa_club_id IS NOT NULL
                      AND (g.home_club_id = cl.gaa_club_id OR g.away_club_id = cl.gaa_club_id)
      JOIN gaa_competitions comp ON comp.comp_id = g.comp_id
     WHERE g.status = 'result' AND coalesce(g.home_score, '') <> ''
       AND g.start_at > now() - make_interval(days => greatest(1, least(coalesce(p_days, 14), 60)))
       AND g.start_at <= now()
       AND lower(g.home_team) <> 'bye' AND lower(g.away_team) <> 'bye'
  ),
  r AS (
    SELECT g.*,
           CASE WHEN home THEN g.home_pts ELSE g.away_pts END AS us_pts,
           CASE WHEN home THEN g.away_pts ELSE g.home_pts END AS opp_pts
      FROM g
  )
  SELECT jsonb_build_object(
    'colours', coalesce((SELECT jsonb_object_agg(cl.club_id::text, cl.primary_colour)
                           FROM cl WHERE coalesce(cl.primary_colour, '') <> ''), '{}'::jsonb),
    'results', coalesce((SELECT jsonb_agg(jsonb_build_object(
        'club_id', r.club_id,
        'start', r.start_at,
        'age', r.age,
        'code', r.code_name,
        'competition', r.comp_name,
        'opposition', CASE WHEN r.home THEN r.away_team ELSE r.home_team END,
        'home', r.home,
        'outcome', CASE WHEN r.us_pts > r.opp_pts THEN 'won'
                        WHEN r.us_pts < r.opp_pts THEN 'lost' ELSE 'drew' END,
        'us_score', CASE WHEN r.home THEN r.home_score ELSE r.away_score END,
        'opp_score', CASE WHEN r.home THEN r.away_score ELSE r.home_score END)
        ORDER BY r.start_at DESC, r.game_id) FROM r), '[]'::jsonb));
$$;
REVOKE ALL ON FUNCTION public.get_club_home_results(bigint[], integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_club_home_results(bigint[], integer) TO authenticated;
