-- Fix get_event_attendance_by_role: squad EXISTS check had no code_id filter,
-- so historical squad members (moved to a different squad) were included.
-- Adds v_effective_code_id via get_updated_event_code() and filters
-- AND msl2.code_id = v_effective_code_id in member_base_raw.
--
-- get_event_attendance_by_role_v2 already uses code_id correctly — no change needed.

CREATE OR REPLACE FUNCTION public.get_event_attendance_by_role(
    p_event_id           bigint,
    p_role_grade_filter  smallint DEFAULT NULL::smallint,
    p_role_level_filter  smallint DEFAULT NULL::smallint,
    p_role_level_exclude smallint DEFAULT NULL::smallint,
    p_response_id        bigint   DEFAULT NULL::bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_effective_code_id bigint;
BEGIN
    v_effective_code_id := public.get_updated_event_code(p_event_id);

    RETURN (
    WITH
    latest_event_attendance AS (
        SELECT
            DISTINCT ON (ea.event_id, ea.member_id)
            ea.event_id,
            ea.member_id,
            ea.response_id
        FROM
            public.event_attendance ea
        WHERE
            ea.event_id = p_event_id
        ORDER BY
            ea.event_id,
            ea.member_id,
            ea.created_at DESC
    ),
    member_base_raw AS (
        SELECT
            e.event_id,
            mtl.member_id,
            m.first_name,
            m.last_name,
            mtl.squad_id,
            sq.squad_name,
            sq.grade AS squad_grade,
            sq.squad_list_seq,
            sq.squad_image,
            mtrl.role_id,
            r.role_grade,
            r.role_level
        FROM
            events e
            JOIN public.member_team_link mtl ON e.team_id = mtl.team_id AND e.event_id = p_event_id
            JOIN public.members m ON mtl.member_id = m.member_id
            JOIN public.squads sq ON mtl.squad_id = sq.squad_id
            JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
            JOIN public.roles r ON mtrl.role_id = r.role_id
        WHERE
            mtl.squad_id IS NOT NULL
            AND (
                e.squad_id IS NULL
                OR EXISTS (
                    SELECT 1 FROM public.member_squad_link msl2
                    WHERE msl2.member_id = mtl.member_id
                      AND msl2.squad_id  = e.squad_id
                      AND msl2.code_id   = v_effective_code_id
                )
            )
    ),
    member_base_data AS (
        SELECT DISTINCT ON (event_id, member_id)
            event_id, member_id, first_name, last_name, squad_id,
            squad_name, squad_grade, squad_list_seq, squad_image, role_id
        FROM member_base_raw
        ORDER BY event_id, member_id, role_grade ASC, role_level DESC
    ),
    all_roles_for_event AS (
        SELECT DISTINCT
            e.event_id,
            r.role_id,
            r.role_name,
            r.role_level,
            r.role_grade,
            r.role_name_plural,
            r.role_list_seq
        FROM
            events e
            JOIN public.teams t ON e.team_id = t.team_id
            JOIN public.team_roles_link trl ON t.team_id = trl.team_id
            JOIN public.roles r ON trl.role_id = r.role_id
        WHERE
            e.event_id = p_event_id
            AND (p_role_grade_filter IS NULL OR p_role_grade_filter = 0 OR r.role_grade = p_role_grade_filter)
            AND (p_role_level_filter IS NULL OR p_role_level_filter = 0 OR r.role_level >= p_role_level_filter)
            AND (p_role_level_exclude IS NULL OR r.role_level != p_role_level_exclude)
    ),
    member_status_data AS (
        SELECT
            mbd.event_id,
            mbd.role_id,
            mbd.first_name,
            mbd.last_name,
            mbd.squad_grade,
            mbd.squad_list_seq,
            lea.response_id,
            jsonb_build_object(
                'member_id', mbd.member_id,
                'member_name', mbd.first_name || ' ' || mbd.last_name,
                'squad_id', mbd.squad_id,
                'squad_name', mbd.squad_name,
                'squad_grade', mbd.squad_grade,
                'squad_list_seq', mbd.squad_list_seq,
                'squad_image', mbd.squad_image
            ) AS member_json,
            CASE
                WHEN lea.response_id = 3 THEN 'accepted'
                WHEN lea.response_id = 4 THEN 'declined'
                WHEN lea.response_id IS NULL THEN 'no_response'
                ELSE 'irrelevant'
            END AS attendance_status
        FROM
            member_base_data mbd
            LEFT JOIN latest_event_attendance lea ON mbd.event_id = lea.event_id AND mbd.member_id = lea.member_id
    ),
    roles_with_attendance AS (
        SELECT
            r.role_id,
            r.role_name,
            r.role_name_plural,
            r.role_grade,
            r.role_level,
            r.role_list_seq,
            COALESCE(jsonb_agg(msd.member_json ORDER BY msd.squad_list_seq ASC, msd.first_name ASC, msd.last_name ASC) FILTER (WHERE msd.attendance_status = 'accepted'), '[]'::jsonb) AS accepted_members,
            COALESCE(jsonb_agg(msd.member_json ORDER BY msd.squad_list_seq ASC, msd.first_name ASC, msd.last_name ASC) FILTER (WHERE msd.attendance_status = 'declined'), '[]'::jsonb) AS declined_members,
            COALESCE(jsonb_agg(msd.member_json ORDER BY msd.squad_list_seq ASC, msd.first_name ASC, msd.last_name ASC) FILTER (WHERE msd.attendance_status = 'no_response'), '[]'::jsonb) AS no_response_members
        FROM
            all_roles_for_event r
            LEFT JOIN member_status_data msd ON r.event_id = msd.event_id AND r.role_id = msd.role_id
        GROUP BY
            r.event_id, r.role_id, r.role_name, r.role_name_plural, r.role_list_seq, r.role_grade, r.role_level
    )
    SELECT
        jsonb_agg(
            CASE
                WHEN p_response_id = 3 THEN
                    jsonb_build_object(
                        'role_id', ra.role_id,
                        'role_name', ra.role_name,
                        'role_name_plural', ra.role_name_plural,
                        'role_grade', ra.role_grade,
                        'role_level', ra.role_level,
                        'member_count', jsonb_array_length(ra.accepted_members),
                        'members', ra.accepted_members
                    )
                WHEN p_response_id = 4 THEN
                    jsonb_build_object(
                        'role_id', ra.role_id,
                        'role_name', ra.role_name,
                        'role_name_plural', ra.role_name_plural,
                        'role_grade', ra.role_grade,
                        'role_level', ra.role_level,
                        'member_count', jsonb_array_length(ra.declined_members),
                        'members', ra.declined_members
                    )
                WHEN p_response_id IS NOT NULL AND p_response_id NOT IN (3, 4) THEN
                    jsonb_build_object(
                        'role_id', ra.role_id,
                        'role_name', ra.role_name,
                        'role_name_plural', ra.role_name_plural,
                        'role_grade', ra.role_grade,
                        'role_level', ra.role_level,
                        'member_count', jsonb_array_length(ra.no_response_members),
                        'members', ra.no_response_members
                    )
                ELSE
                    jsonb_build_object(
                        'role_id', ra.role_id,
                        'role_name', ra.role_name,
                        'role_name_plural', ra.role_name_plural,
                        'role_grade', ra.role_grade,
                        'role_level', ra.role_level,
                        'accepted_count', jsonb_array_length(ra.accepted_members),
                        'no_response_count', jsonb_array_length(ra.no_response_members),
                        'declined_count', jsonb_array_length(ra.declined_members),
                        'accepted_members', ra.accepted_members,
                        'no_response_members', ra.no_response_members,
                        'declined_members', ra.declined_members
                    )
            END
            ORDER BY ra.role_list_seq, ra.role_grade DESC, ra.role_level DESC
        )
    FROM roles_with_attendance ra
    );
END;
$$;
