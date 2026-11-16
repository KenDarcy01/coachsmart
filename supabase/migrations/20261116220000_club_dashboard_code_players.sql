-- Club dashboard (Ken, 2026-11-16): per code, also count the players who said
-- yes to at least 1 in 5 of that code's sessions in the period (index 8 of
-- 'codes'), so squad size on a code-filtered team page is the players who
-- actually play that code, not everyone who turned up once.

CREATE OR REPLACE FUNCTION public.get_club_dashboard(
    p_club_id bigint,
    p_from    timestamptz DEFAULT date_trunc('year', now()),
    p_to      timestamptz DEFAULT now()
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_club   record;
    v_to     timestamptz := LEAST(p_to, now());
    v_hfrom  timestamptz := date_trunc('year', now());
    v_result jsonb;
BEGIN
    IF NOT public.is_club_officer(p_club_id) THEN
        RETURN jsonb_build_object('error', 'not_allowed');
    END IF;

    SELECT c.club_id, c.club_name, c.crest, c.primary_colour, c.secondary_colour, c.gaa_club_id
      INTO v_club FROM clubs c WHERE c.club_id = p_club_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('error', 'not_found');
    END IF;

    WITH club_teams AS (
        SELECT t.team_id, t.team_name, t.team_female
        FROM teams t WHERE t.club_id = p_club_id
    ),
    ev AS MATERIALIZED (
        SELECT e.event_id, e.team_id, e.event_date_time, e.squad_id, e.event_code_id AS code_id,
               (e.event_type_id = 2) AS is_match,
               COALESCE(ar.role_level, 10) AS aud
        FROM events e
        JOIN club_teams ct ON ct.team_id = e.team_id
        LEFT JOIN roles ar ON ar.role_id = e.audience_id
        WHERE e.status = 'active'
          AND e.event_date_time >= LEAST(p_from, v_hfrom, now() - interval '42 days')
          AND e.event_date_time <  now()
    ),
    roster AS MATERIALIZED (
        SELECT mtl.team_id, mtl.member_id,
               min(mtl.created_at) AS joined,
               max(r.role_level)   AS lvl,
               min(r.role_level)   AS min_lvl,
               min(trim(m.first_name || ' ' || COALESCE(m.last_name, ''))) AS full_name
        FROM member_team_link mtl
        JOIN club_teams ct              ON ct.team_id = mtl.team_id
        JOIN members m                  ON m.member_id = mtl.member_id
        JOIN member_team_role_link mtrl ON mtrl.member_team_id = mtl.member_team_id
        JOIN roles r                    ON r.role_id = mtrl.role_id AND r.role_grade = 10
        WHERE COALESCE(mtl.status, 'active') = 'active'
          AND COALESCE(m.status, '') <> 'deleted'
        GROUP BY mtl.team_id, mtl.member_id
    ),
    replies AS (
        SELECT DISTINCT ON (ea.event_id, ea.member_id)
               ea.event_id, ea.member_id, ea.response_id
        FROM event_attendance ea
        JOIN ev ON ev.event_id = ea.event_id
        ORDER BY ea.event_id, ea.member_id, ea.attendance_id DESC
    ),
    invited AS MATERIALIZED (
        SELECT ev.event_id, ev.team_id, ev.event_date_time, ev.is_match, ev.code_id,
               ro.member_id, ro.min_lvl, rp.response_id
        FROM ev
        JOIN roster ro       ON ro.team_id = ev.team_id
        LEFT JOIN replies rp ON rp.event_id = ev.event_id AND rp.member_id = ro.member_id
        WHERE rp.member_id IS NOT NULL
           OR (ro.joined <= ev.event_date_time
               AND ro.lvl >= ev.aud
               AND (ev.squad_id IS NULL OR EXISTS (
                       SELECT 1 FROM member_squad_link sm
                       WHERE sm.team_id = ev.team_id AND sm.squad_id = ev.squad_id
                         AND sm.member_id = ro.member_id)))
    ),
    per_team AS (
        -- Sessions: events with at least one player invited (leaves out
        -- coach-only events).
        SELECT i.team_id,
               count(DISTINCT i.event_id) FILTER (WHERE NOT i.is_match) AS trn_events,
               count(DISTINCT i.event_id) FILTER (WHERE i.is_match)     AS m_events
        FROM invited i
        WHERE i.event_date_time >= p_from AND i.event_date_time < v_to AND i.min_lvl = 10
        GROUP BY i.team_id
    ),
    per_team_att AS (
        SELECT i.team_id,
               count(*) FILTER (WHERE NOT i.is_match)                       AS trn_inv,
               count(*) FILTER (WHERE NOT i.is_match AND i.response_id = 3) AS trn_yes,
               count(*) FILTER (WHERE i.is_match)                           AS m_inv,
               count(*) FILTER (WHERE i.is_match AND i.response_id = 3)     AS m_yes,
               count(*) FILTER (WHERE i.response_id IN (3, 4))              AS replied
        FROM invited i
        WHERE i.event_date_time >= p_from AND i.event_date_time < v_to AND i.min_lvl = 10
        GROUP BY i.team_id
    ),
    per_month AS (
        -- [players who said yes, players invited, sessions]
        SELECT i.team_id, to_char(i.event_date_time, 'YYYY-MM') AS ym,
               count(*) FILTER (WHERE i.min_lvl = 10) AS inv,
               count(*) FILTER (WHERE i.min_lvl = 10 AND i.response_id = 3) AS yes,
               count(DISTINCT i.event_id) FILTER (WHERE i.min_lvl = 10) AS n
        FROM invited i
        WHERE i.event_date_time >= p_from AND i.event_date_time < v_to
        GROUP BY 1, 2
    ),
    per_code_month AS (
        SELECT i.team_id, i.code_id, to_char(i.event_date_time, 'YYYY-MM') AS ym,
               count(*) FILTER (WHERE i.response_id = 3) AS yes, count(*) AS inv,
               count(DISTINCT i.event_id) AS n
        FROM invited i
        WHERE i.event_date_time >= p_from AND i.event_date_time < v_to AND i.min_lvl = 10
          AND i.code_id IS NOT NULL
        GROUP BY 1, 2, 3
    ),
    per_code AS (
        SELECT i.team_id, i.code_id,
               count(DISTINCT i.event_id) FILTER (WHERE NOT i.is_match)     AS trn_events,
               count(*) FILTER (WHERE NOT i.is_match AND i.response_id = 3) AS trn_yes,
               count(*) FILTER (WHERE NOT i.is_match)                       AS trn_inv,
               count(DISTINCT i.event_id) FILTER (WHERE i.is_match)         AS m_events,
               count(*) FILTER (WHERE i.is_match AND i.response_id = 3)     AS m_yes,
               count(*) FILTER (WHERE i.is_match)                           AS m_inv,
               count(*) FILTER (WHERE i.response_id IN (3, 4))              AS replied
        FROM invited i
        WHERE i.event_date_time >= p_from AND i.event_date_time < v_to AND i.min_lvl = 10
          AND i.code_id IS NOT NULL
        GROUP BY 1, 2
    ),
    per_code_member AS (
        SELECT i.team_id, i.code_id, i.member_id, count(*) FILTER (WHERE i.response_id = 3) AS went
        FROM invited i
        WHERE i.event_date_time >= p_from AND i.event_date_time < v_to AND i.min_lvl = 10
          AND i.code_id IS NOT NULL
        GROUP BY 1, 2, 3
    ),
    health AS (
        -- Current season and the last 6 weeks, players only, matches only.
        SELECT i.team_id,
               count(*) FILTER (WHERE i.event_date_time >= v_hfrom AND i.response_id = 3) AS s_yes,
               count(*) FILTER (WHERE i.event_date_time >= v_hfrom)                       AS s_inv,
               count(DISTINCT i.event_id) FILTER (WHERE i.event_date_time >= v_hfrom)     AS s_n,
               count(*) FILTER (WHERE i.event_date_time >= now() - interval '42 days' AND i.response_id = 3) AS r_yes,
               count(*) FILTER (WHERE i.event_date_time >= now() - interval '42 days')                       AS r_inv,
               count(DISTINCT i.event_id) FILTER (WHERE i.event_date_time >= now() - interval '42 days')     AS r_n,
               count(*) FILTER (WHERE i.event_date_time >= now() - interval '42 days' AND i.response_id IN (3, 4)) AS r_rep
        FROM invited i
        WHERE i.min_lvl = 10 AND i.is_match
        GROUP BY i.team_id
    ),
    last_ev AS (
        SELECT e.team_id, max(e.event_date_time) AS last_at
        FROM events e
        JOIN club_teams ct ON ct.team_id = e.team_id
        WHERE e.status = 'active' AND e.event_date_time < now()
        GROUP BY e.team_id
    ),
    recent AS (
        -- Players (role level 10) invited in the last 4 weeks.
        SELECT i.team_id, i.member_id,
               bool_or(i.response_id = 3)        AS went,
               bool_or(i.response_id IN (3, 4))  AS answered
        FROM invited i
        WHERE i.event_date_time >= now() - interval '28 days'
          AND i.min_lvl = 10
        GROUP BY 1, 2
    ),
    keeper AS (
        SELECT e.team_id, count(DISTINCT ms.event_id) AS n
        FROM match_stats ms
        JOIN events e      ON e.event_id = ms.event_id
        JOIN club_teams ct ON ct.team_id = e.team_id
        WHERE e.event_date_time >= p_from AND e.event_date_time < v_to
        GROUP BY 1
    )
    SELECT jsonb_build_object(
        'club', jsonb_build_object(
            'club_id', v_club.club_id, 'club_name', v_club.club_name, 'crest', v_club.crest,
            'primary_colour', v_club.primary_colour, 'secondary_colour', v_club.secondary_colour,
            'gaa_club_id', v_club.gaa_club_id),
        'from', p_from, 'to', v_to,
        'teams', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'team_id', ct.team_id, 'team_name', ct.team_name, 'female', ct.team_female,
                'players', (SELECT count(*) FROM roster ro WHERE ro.team_id = ct.team_id AND ro.min_lvl = 10),
                'trn_events', COALESCE(pt.trn_events, 0), 'trn_inv', COALESCE(pa.trn_inv, 0), 'trn_yes', COALESCE(pa.trn_yes, 0),
                'm_events', COALESCE(pt.m_events, 0), 'm_inv', COALESCE(pa.m_inv, 0), 'm_yes', COALESCE(pa.m_yes, 0),
                'replied', COALESCE(pa.replied, 0),
                'keeper', COALESCE(k.n, 0),
                'last_event', le.last_at,
                'codes', COALESCE((SELECT jsonb_object_agg(pc.code_id, jsonb_build_array(
                                        pc.trn_events, pc.trn_yes, pc.trn_inv, pc.m_events, pc.m_yes, pc.m_inv, pc.replied,
                                        COALESCE((SELECT jsonb_object_agg(pcm.ym, jsonb_build_array(pcm.yes, pcm.inv, pcm.n))
                                                  FROM per_code_month pcm
                                                  WHERE pcm.team_id = pc.team_id AND pcm.code_id = pc.code_id), '{}'::jsonb),
                                        (SELECT count(*) FROM per_code_member m
                                          WHERE m.team_id = pc.team_id AND m.code_id = pc.code_id
                                            AND m.went >= GREATEST(1, ceil(0.2 * (pc.trn_events + pc.m_events))))))
                                   FROM per_code pc WHERE pc.team_id = ct.team_id), '{}'::jsonb),
                -- [season yes, season invited, season sessions, 6wk yes, 6wk invited, 6wk sessions, 6wk replied]
                'h', jsonb_build_array(COALESCE(hh.s_yes, 0), COALESCE(hh.s_inv, 0), COALESCE(hh.s_n, 0),
                                       COALESCE(hh.r_yes, 0), COALESCE(hh.r_inv, 0), COALESCE(hh.r_n, 0), COALESCE(hh.r_rep, 0)),
                'months', COALESCE((SELECT jsonb_object_agg(pm.ym, jsonb_build_array(pm.yes, pm.inv, pm.n))
                                    FROM per_month pm WHERE pm.team_id = ct.team_id), '{}'::jsonb),
                'not_attended', COALESCE((SELECT jsonb_agg(ro.full_name ORDER BY ro.full_name)
                                    FROM recent rc JOIN roster ro ON ro.team_id = rc.team_id AND ro.member_id = rc.member_id
                                    WHERE rc.team_id = ct.team_id AND NOT COALESCE(rc.went, false)), '[]'::jsonb),
                'not_replied', COALESCE((SELECT jsonb_agg(ro.full_name ORDER BY ro.full_name)
                                    FROM recent rc JOIN roster ro ON ro.team_id = rc.team_id AND ro.member_id = rc.member_id
                                    WHERE rc.team_id = ct.team_id AND NOT COALESCE(rc.answered, false)), '[]'::jsonb)
            ) ORDER BY ct.team_name)
            FROM club_teams ct
            LEFT JOIN per_team pt ON pt.team_id = ct.team_id
            LEFT JOIN per_team_att pa ON pa.team_id = ct.team_id
            LEFT JOIN keeper k    ON k.team_id = ct.team_id
            LEFT JOIN health hh   ON hh.team_id = ct.team_id
            LEFT JOIN last_ev le  ON le.team_id = ct.team_id
        ), '[]'::jsonb),
        -- [start_at, code, level, age, comp name, opposition, us score, them score, us pts, them pts, home]
        'games', CASE WHEN v_club.gaa_club_id IS NULL THEN '[]'::jsonb ELSE COALESCE((
            SELECT jsonb_agg(jsonb_build_array(
                g.start_at, g.code, gc.level, gc.age, gc.name,
                CASE WHEN g.home_club_id = v_club.gaa_club_id THEN g.away_team ELSE g.home_team END,
                CASE WHEN g.home_club_id = v_club.gaa_club_id THEN g.home_score ELSE g.away_score END,
                CASE WHEN g.home_club_id = v_club.gaa_club_id THEN g.away_score ELSE g.home_score END,
                CASE WHEN g.home_club_id = v_club.gaa_club_id THEN g.home_pts ELSE g.away_pts END,
                CASE WHEN g.home_club_id = v_club.gaa_club_id THEN g.away_pts ELSE g.home_pts END,
                g.home_club_id = v_club.gaa_club_id) ORDER BY g.start_at DESC)
            FROM gaa_games g
            JOIN gaa_competitions gc ON gc.comp_id = g.comp_id
            WHERE (g.home_club_id = v_club.gaa_club_id OR g.away_club_id = v_club.gaa_club_id)
              AND g.home_club_id IS DISTINCT FROM g.away_club_id
              AND g.start_at >= LEAST(p_from, v_hfrom) AND g.start_at < now()
        ), '[]'::jsonb) END
    ) INTO v_result;

    RETURN v_result;
END;
$$;
