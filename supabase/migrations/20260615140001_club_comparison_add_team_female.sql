-- Add team_female to get_club_comparison_dashboard JSON output
-- Enables client-side Hurling → Camogie display for female teams.
-- All other logic is identical to 20260611130000.

CREATE OR REPLACE FUNCTION public.get_club_comparison_dashboard(
    p_club_id    integer,
    p_start_date timestamptz DEFAULT NOW() - INTERVAL '90 days',
    p_end_date   timestamptz DEFAULT NOW()
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

    WITH club_teams AS (
        SELECT t.team_id, t.team_name, t.team_female
        FROM public.teams t
        WHERE t.club_id = p_club_id
    ),
    events_in_range AS (
        SELECT
            e.event_id,
            e.team_id,
            e.event_date_time,
            COALESCE(ec.event_code, '') AS event_code,
            COALESCE(et.event_type, '') AS event_type,
            e.opposition,
            CASE
                WHEN e.event_title IS NOT NULL AND trim(e.event_title) <> '' THEN e.event_title
                ELSE trim(
                    CASE WHEN ct.team_female = true AND ec.code_id = 3
                         THEN 'Camogie'
                         ELSE COALESCE(ec.event_code, '')
                    END
                    || ' ' || COALESCE(et.event_type, '')
                    || CASE
                        WHEN et.event_type_id = 2
                         AND e.opposition IS NOT NULL AND e.opposition <> ''
                        THEN ' v ' || e.opposition
                        ELSE ''
                       END
                )
            END AS display_title
        FROM public.events e
        JOIN club_teams ct              ON e.team_id       = ct.team_id
        LEFT JOIN public.event_codes ec ON e.event_code_id = ec.code_id
        LEFT JOIN public.event_types et ON e.event_type_id = et.event_type_id
        WHERE e.event_date_time >= p_start_date
          AND e.event_date_time <  p_end_date
    ),
    team_members AS (
        SELECT DISTINCT ON (mtl.team_id, m.member_id)
            mtl.team_id,
            m.member_id,
            trim(m.first_name || ' ' || COALESCE(m.last_name, '')) AS full_name,
            r.role_name
        FROM public.member_team_link mtl
        JOIN club_teams ct                     ON mtl.team_id       = ct.team_id
        JOIN public.members m                  ON mtl.member_id     = m.member_id
        JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN public.roles r                    ON mtrl.role_id      = r.role_id
        WHERE r.role_grade = 10
        ORDER BY mtl.team_id, m.member_id, r.role_list_seq
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
    team_event_rows AS (
        SELECT
            e.team_id,
            e.event_id,
            e.event_date_time,
            e.display_title,
            e.event_code,
            e.event_type,
            e.opposition,
            COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'member_id', tm.member_id,
                        'name',      tm.full_name,
                        'role',      tm.role_name,
                        'response',  CASE la.response_id
                                         WHEN 3 THEN 'accepted'
                                         WHEN 4 THEN 'declined'
                                         ELSE        'no_response'
                                     END
                    )
                    ORDER BY tm.full_name
                ),
                '[]'::jsonb
            ) AS members
        FROM events_in_range e
        JOIN team_members tm ON tm.team_id = e.team_id
        LEFT JOIN latest_attendance la
            ON la.member_id = tm.member_id AND la.event_id = e.event_id
        GROUP BY e.team_id, e.event_id, e.event_date_time, e.display_title,
                 e.event_code, e.event_type, e.opposition
    ),
    team_roster AS (
        SELECT DISTINCT ON (mtl.team_id, m.member_id)
            mtl.team_id,
            m.member_id,
            trim(m.first_name || ' ' || COALESCE(m.last_name, '')) AS full_name,
            r.role_name,
            r.role_level
        FROM public.member_team_link mtl
        JOIN club_teams ct                     ON mtl.team_id       = ct.team_id
        JOIN public.members m                  ON mtl.member_id     = m.member_id
        JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN public.roles r                    ON mtrl.role_id      = r.role_id
        WHERE r.role_grade = 10
        ORDER BY mtl.team_id, m.member_id, r.role_list_seq
    ),
    team_roster_by_role AS (
        SELECT
            team_id,
            role_name,
            role_level,
            COUNT(*) AS member_count,
            jsonb_agg(jsonb_build_object('member_id', member_id, 'name', full_name) ORDER BY full_name) AS members
        FROM team_roster
        GROUP BY team_id, role_name, role_level
    ),
    team_member_roles AS (
        SELECT
            team_id,
            jsonb_agg(
                jsonb_build_object('role', role_name, 'count', member_count, 'members', members)
                ORDER BY role_level ASC
            ) AS member_roles
        FROM team_roster_by_role
        GROUP BY team_id
    )
    SELECT jsonb_build_object(
        'club_name',    v_club_name,
        'club_id',      p_club_id,
        'start_date',   p_start_date,
        'end_date',     p_end_date,
        'generated_at', now(),
        'teams', COALESCE(
            (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'team_id',      ct.team_id,
                        'team_name',    ct.team_name,
                        'team_female',  ct.team_female,
                        'member_roles', COALESCE(
                            (SELECT tmr.member_roles FROM team_member_roles tmr WHERE tmr.team_id = ct.team_id),
                            '[]'::jsonb
                        ),
                        'events', COALESCE(
                            (
                                SELECT jsonb_agg(
                                    jsonb_build_object(
                                        'event_id',   ter.event_id,
                                        'date',       ter.event_date_time,
                                        'title',      ter.display_title,
                                        'code',       ter.event_code,
                                        'type',       ter.event_type,
                                        'opposition', ter.opposition,
                                        'members',    ter.members
                                    )
                                    ORDER BY ter.event_date_time DESC
                                )
                                FROM team_event_rows ter
                                WHERE ter.team_id = ct.team_id
                            ),
                            '[]'::jsonb
                        )
                    )
                    ORDER BY ct.team_name
                )
                FROM club_teams ct
            ),
            '[]'::jsonb
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_club_comparison_dashboard(integer, timestamptz, timestamptz)
    TO anon, authenticated, service_role;
