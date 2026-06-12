-- Squad dashboard v11: minimal fix to v5 — drop latest_match_squads
--
-- v5 bug: DISTINCT ON (ms.event_id) picked a single match_squads row per
-- event (globally highest match_squad_id).  If a later resave omitted a
-- player (e.g. Alex Beggs, event 633) that player was excluded from
-- match_sels even though they appeared in an earlier correct save.
--
-- Fix: remove latest_match_squads entirely.  Join match_squad_details
-- directly to filtered_events and use COUNT(DISTINCT event_id).
-- A player counts once per event as long as they appear in ANY save for
-- that event — exactly what the drawer does.
-- No NOW() cap: the slider end date is the only upper bound, matching the
-- drawer which also uses the slider range for its date filter.

CREATE OR REPLACE FUNCTION public.get_squad_dashboard(
    p_club_id    integer,
    p_start_date timestamptz DEFAULT NOW() - INTERVAL '90 days',
    p_end_date   timestamptz DEFAULT NOW(),
    p_codes      text[]      DEFAULT NULL,
    p_types      text[]      DEFAULT NULL,
    p_att_min    integer     DEFAULT 0,
    p_att_max    integer     DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_club_name text;
    v_result    jsonb;
BEGIN
    SELECT club_name INTO v_club_name
    FROM public.clubs
    WHERE club_id = p_club_id;

    IF v_club_name IS NULL THEN
        RETURN jsonb_build_object('error', 'Club not found');
    END IF;

    WITH
    club_teams AS (
        SELECT t.team_id, t.team_name
        FROM public.teams t
        WHERE t.club_id = p_club_id
    ),
    team_member_roles AS (
        SELECT DISTINCT ON (mtl.team_id, m.member_id)
            mtl.team_id,
            m.member_id,
            trim(m.first_name || ' ' || COALESCE(m.last_name, '')) AS full_name,
            r.role_name
        FROM public.member_team_link mtl
        JOIN club_teams ct                     ON mtl.team_id        = ct.team_id
        JOIN public.members m                  ON mtl.member_id      = m.member_id
        JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN public.roles r                    ON mtrl.role_id       = r.role_id
        WHERE r.role_grade = 10
        ORDER BY mtl.team_id, m.member_id, r.role_list_seq
    ),
    squad_assignments AS (
        SELECT
            msl.team_id,
            msl.squad_id,
            msl.code_id,
            msl.member_id,
            s.squad_name,
            s.grade,
            s.squad_list_seq,
            COALESCE(ec.event_code, '') AS event_code
        FROM public.member_squad_link msl
        JOIN club_teams ct              ON msl.team_id  = ct.team_id
        JOIN public.squads s            ON msl.squad_id = s.squad_id
        LEFT JOIN public.event_codes ec ON msl.code_id  = ec.code_id
    ),
    event_att_counts AS (
        SELECT
            e.event_id,
            COUNT(*) FILTER (WHERE ea.response_id = 3) AS accepted_count
        FROM public.events e
        JOIN  club_teams ct                  ON e.team_id   = ct.team_id
        LEFT JOIN public.event_attendance ea ON ea.event_id = e.event_id
        WHERE e.event_date_time >= p_start_date
          AND e.event_date_time <  p_end_date
        GROUP BY e.event_id
    ),
    latest_att AS (
        SELECT DISTINCT ON (ea.member_id, ea.event_id)
            ea.member_id,
            e.team_id,
            e.event_code_id AS code_id,
            ea.response_id
        FROM public.event_attendance ea
        JOIN public.events e            ON ea.event_id      = e.event_id
        JOIN club_teams ct              ON e.team_id        = ct.team_id
        JOIN event_att_counts eac       ON ea.event_id      = eac.event_id
        LEFT JOIN public.event_codes ec ON e.event_code_id  = ec.code_id
        LEFT JOIN public.event_types et ON e.event_type_id  = et.event_type_id
        WHERE e.event_date_time >= p_start_date
          AND e.event_date_time <  p_end_date
          AND (p_codes    IS NULL OR ec.event_code = ANY(p_codes))
          AND (p_types    IS NULL OR et.event_type = ANY(p_types))
          AND (p_att_min <= 0     OR eac.accepted_count >= p_att_min)
          AND (p_att_max  IS NULL OR eac.accepted_count <= p_att_max)
        ORDER BY ea.member_id, ea.event_id, ea.attendance_id DESC
    ),
    member_att AS (
        SELECT
            member_id, team_id, code_id,
            COUNT(*) FILTER (WHERE response_id = 3) AS accepted,
            COUNT(*)                                  AS total_events
        FROM latest_att
        GROUP BY member_id, team_id, code_id
    ),
    filtered_events AS (
        SELECT e.event_id
        FROM public.events e
        JOIN club_teams ct               ON e.team_id        = ct.team_id
        JOIN event_att_counts eac        ON e.event_id       = eac.event_id
        LEFT JOIN public.event_codes ec  ON e.event_code_id  = ec.code_id
        LEFT JOIN public.event_types et  ON e.event_type_id  = et.event_type_id
        WHERE e.event_date_time >= p_start_date
          AND e.event_date_time <  p_end_date
          AND (p_codes    IS NULL OR ec.event_code = ANY(p_codes))
          AND (p_types    IS NULL OR et.event_type = ANY(p_types))
          AND (p_att_min <= 0     OR eac.accepted_count >= p_att_min)
          AND (p_att_max  IS NULL OR eac.accepted_count <= p_att_max)
    ),
    match_sels AS (
        SELECT
            msd.member_id,
            msd.team_id,
            msd.squad_id,
            COUNT(DISTINCT msd.event_id) AS match_count
        FROM public.match_squad_details msd
        JOIN filtered_events fe ON msd.event_id = fe.event_id
        GROUP BY msd.member_id, msd.team_id, msd.squad_id
    ),
    squad_stats AS (
        SELECT
            sa.team_id,
            sa.squad_id,
            sa.squad_name,
            sa.grade,
            sa.squad_list_seq,
            sa.event_code,
            sa.code_id,
            COUNT(DISTINCT sa.member_id) AS member_count,
            COALESCE(SUM(ms.match_count), 0) AS match_appearances,
            CASE
                WHEN SUM(COALESCE(ma.total_events, 0)) > 0
                THEN ROUND(
                    SUM(COALESCE(ma.accepted, 0))::numeric
                    / SUM(COALESCE(ma.total_events, 0)) * 100, 1)
                ELSE 0
            END AS acceptance_rate,
            CASE
                WHEN COUNT(DISTINCT sa.member_id) > 0
                THEN ROUND(
                    COALESCE(SUM(ma.accepted), 0)::numeric
                    / COUNT(DISTINCT sa.member_id), 1)
                ELSE 0
            END AS avg_accepted
        FROM squad_assignments sa
        LEFT JOIN member_att ma
            ON  sa.member_id = ma.member_id
            AND sa.team_id   = ma.team_id
            AND sa.code_id   = ma.code_id
        LEFT JOIN match_sels ms
            ON  sa.member_id = ms.member_id
            AND sa.team_id   = ms.team_id
            AND sa.squad_id  = ms.squad_id
        GROUP BY sa.team_id, sa.squad_id, sa.squad_name,
                 sa.grade, sa.squad_list_seq, sa.event_code, sa.code_id
    ),
    squad_member_rows AS (
        SELECT
            ms.team_id,
            ms.squad_id,
            COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'member_id',        ms.member_id,
                        'name',             COALESCE(tmr.full_name, ''),
                        'role',             COALESCE(tmr.role_name, ''),
                        'match_selections', ms.match_count
                    ) ORDER BY tmr.full_name
                ) FILTER (WHERE tmr.full_name IS NOT NULL AND trim(tmr.full_name) <> ''),
                '[]'::jsonb
            ) AS members
        FROM match_sels ms
        LEFT JOIN team_member_roles tmr
            ON  ms.member_id = tmr.member_id
            AND ms.team_id   = tmr.team_id
        GROUP BY ms.team_id, ms.squad_id
    ),
    squad_rows AS (
        SELECT
            ss.team_id,
            COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'squad_id',          ss.squad_id,
                        'squad_name',        ss.squad_name,
                        'squad_list_seq',    ss.squad_list_seq,
                        'grade',             ss.grade,
                        'code',              ss.event_code,
                        'code_id',           ss.code_id,
                        'member_count',      ss.member_count,
                        'match_appearances', ss.match_appearances,
                        'acceptance_rate',   ss.acceptance_rate,
                        'avg_accepted',      ss.avg_accepted,
                        'members',           COALESCE(smr.members, '[]'::jsonb)
                    ) ORDER BY ss.squad_list_seq NULLS LAST, ss.event_code, ss.squad_name
                ),
                '[]'::jsonb
            ) AS squads
        FROM squad_stats ss
        LEFT JOIN squad_member_rows smr
            ON  ss.team_id  = smr.team_id
            AND ss.squad_id = smr.squad_id
        GROUP BY ss.team_id
    ),
    team_squad_counts AS (
        SELECT team_id, COUNT(DISTINCT member_id) AS total_squad_members
        FROM squad_assignments
        GROUP BY team_id
    ),
    team_rows AS (
        SELECT
            COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'team_id',             ct.team_id,
                        'team_name',           ct.team_name,
                        'total_squad_members', COALESCE(tsc.total_squad_members, 0),
                        'squads',              COALESCE(sr.squads, '[]'::jsonb)
                    ) ORDER BY ct.team_name
                ),
                '[]'::jsonb
            ) AS teams
        FROM club_teams ct
        LEFT JOIN team_squad_counts tsc ON ct.team_id = tsc.team_id
        LEFT JOIN squad_rows sr         ON ct.team_id = sr.team_id
    )
    SELECT jsonb_build_object(
        'club_name',    v_club_name,
        'club_id',      p_club_id,
        'start_date',   p_start_date,
        'end_date',     p_end_date,
        'generated_at', now(),
        'teams',        (SELECT teams FROM team_rows)
    ) INTO v_result;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_squad_dashboard(integer, timestamptz, timestamptz, text[], text[], integer, integer)
    TO anon, authenticated, service_role;
