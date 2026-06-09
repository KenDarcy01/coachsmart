-- Add event_code, event_type per event and role_name per player so the
-- webview can filter client-side without extra round trips.
-- Also orders team_players by role_list_seq so DISTINCT ON picks the
-- primary role for each member.

CREATE OR REPLACE FUNCTION public.get_team_attendance_dashboard(
    p_team_id    integer,
    p_start_date timestamptz DEFAULT NOW() - INTERVAL '90 days',
    p_end_date   timestamptz DEFAULT NOW()
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_team_name    text;
    v_total_events integer;
    v_result       jsonb;
BEGIN
    SELECT team_name INTO v_team_name
    FROM public.teams
    WHERE team_id = p_team_id;

    IF v_team_name IS NULL THEN
        RETURN jsonb_build_object('error', 'Team not found');
    END IF;

    SELECT COUNT(DISTINCT event_id) INTO v_total_events
    FROM public.events
    WHERE team_id        = p_team_id
      AND event_date_time >= p_start_date
      AND event_date_time <  p_end_date;

    WITH events_in_range AS (
        SELECT
            e.event_id,
            e.event_date_time,
            COALESCE(ec.event_code, '') AS event_code,
            COALESCE(et.event_type, '') AS event_type,
            CASE
                WHEN e.event_title IS NOT NULL AND trim(e.event_title) <> '' THEN e.event_title
                ELSE trim(
                    CASE WHEN t.team_female = true AND ec.code_id = 3
                         THEN 'Camogie'
                         ELSE COALESCE(ec.event_code, '')
                    END
                    || ' ' || COALESCE(et.event_type, '')
                    || CASE
                        WHEN et.event_type_id = 2
                         AND e.opposition IS NOT NULL
                         AND e.opposition <> ''
                        THEN ' v ' || e.opposition
                        ELSE ''
                       END
                )
            END AS display_title
        FROM public.events e
        JOIN public.teams t             ON e.team_id       = t.team_id
        LEFT JOIN public.event_codes ec ON e.event_code_id = ec.code_id
        LEFT JOIN public.event_types et ON e.event_type_id = et.event_type_id
        WHERE e.team_id        = p_team_id
          AND e.event_date_time >= p_start_date
          AND e.event_date_time <  p_end_date
    ),
    team_players AS (
        -- role_list_seq picks the primary role when a member has more than one
        SELECT DISTINCT ON (m.member_id)
            m.member_id,
            trim(m.first_name || ' ' || COALESCE(m.last_name, '')) AS full_name,
            r.role_name
        FROM public.member_team_link mtl
        JOIN public.members               m    ON mtl.member_id      = m.member_id
        JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN public.roles                 r    ON mtrl.role_id        = r.role_id
        WHERE mtl.team_id  = p_team_id
          AND r.role_grade = 10
        ORDER BY m.member_id, r.role_list_seq
    ),
    latest_attendance AS (
        SELECT DISTINCT ON (ea.member_id, ea.event_id)
            ea.member_id,
            ea.event_id,
            ea.response_id
        FROM public.event_attendance ea
        JOIN events_in_range e ON ea.event_id = e.event_id
        ORDER BY ea.member_id, ea.event_id, ea.attendance_id DESC
    ),
    player_stats AS (
        SELECT
            tp.member_id,
            tp.full_name,
            tp.role_name,
            COUNT(e.event_id)                                                AS total_events,
            COUNT(la.response_id) FILTER (WHERE la.response_id = 3)         AS accepted,
            COUNT(la.response_id) FILTER (WHERE la.response_id = 4)         AS declined,
            COUNT(e.event_id)
                - COUNT(la.response_id) FILTER (WHERE la.response_id IN (3,4)) AS no_response,
            CASE WHEN COUNT(e.event_id) = 0 THEN 0
                 ELSE ROUND(
                     COUNT(la.response_id) FILTER (WHERE la.response_id = 3)::numeric
                     / COUNT(e.event_id) * 100
                 )
            END                                                              AS attendance_rate,
            COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'event_id', e.event_id,
                        'date',     e.event_date_time,
                        'title',    e.display_title,
                        'code',     e.event_code,
                        'type',     e.event_type,
                        'response', CASE la.response_id
                                        WHEN 3 THEN 'accepted'
                                        WHEN 4 THEN 'declined'
                                        ELSE        'no_response'
                                    END
                    )
                    ORDER BY e.event_date_time DESC
                ),
                '[]'::jsonb
            )                                                                AS events
        FROM team_players tp
        CROSS JOIN events_in_range e
        LEFT JOIN latest_attendance la
            ON la.member_id = tp.member_id AND la.event_id = e.event_id
        GROUP BY tp.member_id, tp.full_name, tp.role_name
    )
    SELECT jsonb_build_object(
        'team_name',    v_team_name,
        'team_id',      p_team_id,
        'total_events', v_total_events,
        'start_date',   p_start_date,
        'end_date',     p_end_date,
        'generated_at', now(),
        'players',      COALESCE(
            (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'member_id',       ps.member_id,
                        'name',            ps.full_name,
                        'role',            ps.role_name,
                        'accepted',        ps.accepted,
                        'declined',        ps.declined,
                        'no_response',     ps.no_response,
                        'total_events',    ps.total_events,
                        'attendance_rate', ps.attendance_rate,
                        'events',          ps.events
                    )
                    ORDER BY ps.attendance_rate DESC NULLS LAST, ps.full_name ASC
                )
                FROM player_stats ps
            ),
            '[]'::jsonb
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_team_attendance_dashboard(integer, timestamptz, timestamptz)
    TO anon, authenticated, service_role;
