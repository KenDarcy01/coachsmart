-- Club dashboard "This week" view (Ken, 2026-11-16): the week's CoachSmart
-- events with player turnout, and the club's league results and fixtures.
-- Officers only (is_club_officer). Range capped at 15 days.
-- events: [event_id, team_id, event_type_id, event_code_id, event_date_time, players yes, scored live]
-- games:  [start_at, code, level, age, comp name, opposition, us score, them score, us pts, them pts, home, venue]

CREATE OR REPLACE FUNCTION public.get_club_week(
    p_club_id bigint,
    p_from    timestamptz,
    p_to      timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_gaa bigint;
    v_to  timestamptz := LEAST(p_to, p_from + interval '15 days');
BEGIN
    IF NOT public.is_club_officer(p_club_id) THEN
        RETURN jsonb_build_object('error', 'not_allowed');
    END IF;
    SELECT c.gaa_club_id INTO v_gaa FROM clubs c WHERE c.club_id = p_club_id;

    RETURN jsonb_build_object(
        'from', p_from, 'to', v_to,
        'events', COALESCE((
            SELECT jsonb_agg(jsonb_build_array(
                e.event_id, e.team_id, e.event_type_id, e.event_code_id, e.event_date_time,
                (SELECT count(*)
                   FROM (SELECT DISTINCT ON (ea.member_id) ea.member_id, ea.response_id
                           FROM event_attendance ea
                          WHERE ea.event_id = e.event_id
                          ORDER BY ea.member_id, ea.attendance_id DESC) x
                  WHERE x.response_id = 3
                    AND (SELECT min(r.role_level)
                           FROM member_team_link mtl
                           JOIN member_team_role_link mtrl ON mtrl.member_team_id = mtl.member_team_id
                           JOIN roles r ON r.role_id = mtrl.role_id AND r.role_grade = 10
                          WHERE mtl.team_id = e.team_id AND mtl.member_id = x.member_id
                            AND COALESCE(mtl.status, 'active') = 'active') = 10),
                EXISTS (SELECT 1 FROM match_stats ms WHERE ms.event_id = e.event_id)
            ) ORDER BY e.event_date_time)
            FROM events e
            JOIN teams t ON t.team_id = e.team_id
            WHERE t.club_id = p_club_id AND e.status = 'active'
              AND e.event_date_time >= p_from AND e.event_date_time < v_to
        ), '[]'::jsonb),
        'games', CASE WHEN v_gaa IS NULL THEN '[]'::jsonb ELSE COALESCE((
            SELECT jsonb_agg(jsonb_build_array(
                g.start_at, g.code, gc.level, gc.age, gc.name,
                CASE WHEN g.home_club_id = v_gaa THEN g.away_team ELSE g.home_team END,
                CASE WHEN g.home_club_id = v_gaa THEN g.home_score ELSE g.away_score END,
                CASE WHEN g.home_club_id = v_gaa THEN g.away_score ELSE g.home_score END,
                CASE WHEN g.home_club_id = v_gaa THEN g.home_pts ELSE g.away_pts END,
                CASE WHEN g.home_club_id = v_gaa THEN g.away_pts ELSE g.home_pts END,
                g.home_club_id = v_gaa, g.venue) ORDER BY g.start_at)
            FROM gaa_games g
            JOIN gaa_competitions gc ON gc.comp_id = g.comp_id
            WHERE (g.home_club_id = v_gaa OR g.away_club_id = v_gaa)
              AND g.home_club_id IS DISTINCT FROM g.away_club_id
              AND g.start_at >= p_from AND g.start_at < v_to
        ), '[]'::jsonb) END
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_club_week(bigint, timestamptz, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_club_week(bigint, timestamptz, timestamptz) TO authenticated;
