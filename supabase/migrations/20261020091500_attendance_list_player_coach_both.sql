-- Player-coaches appear under every grade-10 role they hold.
--
-- get_event_attendance_by_role_v2 kept one role per member (20260727000026),
-- so a member who is both Player and Coach was listed under Coaches only while
-- get_event_attendance_summary_by_role_and_squad_v2 counted them as a player
-- too: the Accepted screen showed "15" over 14 player names (Ken, 2026-10-20).
--
-- Now: one row per member per grade-10 role (Player, FLO, Coach). Admin-type
-- (non grade-10) roles still collapse into the member's grade-10 roles, so an
-- Admin + Coach is listed once, as before. Members with no grade-10 role keep
-- a single row (highest level). Only member_base_data changes.

CREATE OR REPLACE FUNCTION public.get_event_attendance_by_role_v2(
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
    v_event_code_id bigint;
    v_effective_code_id bigint;
    v_team_id bigint;
    v_has_members_for_code boolean;
    v_next_code_id bigint;
BEGIN
    SELECT event_code_id, team_id INTO v_event_code_id, v_team_id
    FROM public.events
    WHERE event_id = p_event_id;

    v_effective_code_id := v_event_code_id;

    IF v_event_code_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1
            FROM public.member_squad_link
            WHERE team_id = v_team_id
              AND code_id = v_event_code_id
            LIMIT 1
        ) INTO v_has_members_for_code;

        IF NOT v_has_members_for_code THEN
            SELECT code_id INTO v_next_code_id
            FROM public.member_squad_link
            WHERE team_id = v_team_id
              AND code_id IS NOT NULL
              AND code_id > v_event_code_id
            ORDER BY code_id ASC
            LIMIT 1;

            IF v_next_code_id IS NOT NULL THEN
                v_effective_code_id := v_next_code_id;
            ELSE
                SELECT MIN(code_id) INTO v_effective_code_id
                FROM public.member_squad_link
                WHERE team_id = v_team_id
                  AND code_id IS NOT NULL;
            END IF;
        END IF;
    ELSE
        SELECT MIN(code_id) INTO v_effective_code_id
        FROM public.member_squad_link
        WHERE team_id = v_team_id
          AND code_id IS NOT NULL;
    END IF;

    IF v_effective_code_id IS NULL THEN
        SELECT ccl.code_id INTO v_effective_code_id
        FROM public.teams t
        JOIN public.clubs c ON t.club_id = c.club_id
        JOIN public.club_code_link ccl ON c.club_id = ccl.club_id
        WHERE t.team_id = v_team_id
        ORDER BY ccl.code_id ASC
        LIMIT 1;
    END IF;

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
            msl.member_id,
            m.first_name,
            m.last_name,
            msl.squad_id,
            sq.squad_name,
            sq.grade AS squad_grade,
            sq.squad_list_seq,
            sq.squad_image,
            mtrl.role_id,
            r.role_grade,
            r.role_level,
            msl.squad_id AS squad_code_id,
            sq.squad_name AS squad_code_name,
            sq.squad_image AS squad_code_image
        FROM
            events e
            JOIN public.member_squad_link msl ON e.team_id = msl.team_id
                AND msl.code_id = v_effective_code_id
            JOIN public.members m ON msl.member_id = m.member_id
            JOIN public.squads sq ON msl.squad_id = sq.squad_id
            JOIN public.member_team_link mtl ON msl.member_id = mtl.member_id
                AND msl.team_id = mtl.team_id
            JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
            JOIN public.roles r ON mtrl.role_id = r.role_id
        WHERE
            e.event_id = p_event_id
            AND msl.squad_id IS NOT NULL
            AND mtl.status = 'active'
            AND (e.squad_id IS NULL OR msl.squad_id = e.squad_id)
    ),
    member_base_data AS (
        SELECT DISTINCT ON (event_id, member_id, CASE WHEN role_grade = 10 THEN role_id ELSE 0 END)
            event_id, member_id, first_name, last_name, squad_id,
            squad_name, squad_grade, squad_list_seq, squad_image, role_id,
            squad_code_id, squad_code_name, squad_code_image
        FROM member_base_raw mbr
        WHERE mbr.role_grade = 10
           OR NOT EXISTS (
                SELECT 1 FROM member_base_raw x
                WHERE x.member_id = mbr.member_id AND x.role_grade = 10
           )
        ORDER BY event_id, member_id, CASE WHEN role_grade = 10 THEN role_id ELSE 0 END,
                 role_grade ASC, role_level DESC
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
            mbd.member_id,
            mbd.first_name,
            mbd.last_name,
            mbd.squad_id,
            mbd.squad_grade,
            mbd.squad_list_seq,
            mbd.squad_code_id,
            lea.response_id,
            jsonb_build_object(
                'member_id', mbd.member_id,
                'member_name', mbd.first_name || ' ' || mbd.last_name,
                'squad_id', mbd.squad_id,
                'squad_name', mbd.squad_name,
                'squad_grade', mbd.squad_grade,
                'squad_list_seq', mbd.squad_list_seq,
                'squad_image', mbd.squad_image,
                'squad_code_id', mbd.squad_code_id,
                'squad_code_name', mbd.squad_code_name,
                'squad_code_image', mbd.squad_code_image,
                'sort_key', LPAD(mbd.squad_list_seq::text, 10, '0') || ' ' || mbd.first_name || ' ' || mbd.last_name
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
            MIN(msd.squad_list_seq) as min_squad_seq,
            COALESCE(jsonb_agg(msd.member_json ORDER BY msd.squad_id ASC, (msd.first_name || ' ' || msd.last_name) ASC) FILTER (WHERE msd.attendance_status = 'accepted'), '[]'::jsonb) AS accepted_members,
            COALESCE(jsonb_agg(msd.member_json ORDER BY msd.squad_id ASC, (msd.first_name || ' ' || msd.last_name) ASC) FILTER (WHERE msd.attendance_status = 'declined'), '[]'::jsonb) AS declined_members,
            COALESCE(jsonb_agg(msd.member_json ORDER BY msd.squad_id ASC, (msd.first_name || ' ' || msd.last_name) ASC) FILTER (WHERE msd.attendance_status = 'no_response'), '[]'::jsonb) AS no_response_members,
            COUNT(DISTINCT msd.member_id) FILTER (WHERE msd.squad_code_id IS NOT NULL) as squad_code_count,
            COUNT(DISTINCT msd.member_id) FILTER (WHERE msd.squad_code_id IS NOT NULL AND msd.attendance_status = 'accepted') as code_accepted_count,
            COUNT(DISTINCT msd.member_id) FILTER (WHERE msd.squad_code_id IS NOT NULL AND msd.attendance_status = 'declined') as code_declined_count,
            COUNT(DISTINCT msd.member_id) FILTER (WHERE msd.squad_code_id IS NOT NULL AND msd.attendance_status = 'no_response') as code_no_response_count
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
                        'squad_list_seq', ra.min_squad_seq,
                        'member_count', jsonb_array_length(ra.accepted_members),
                        'member_role_count', ra.code_accepted_count,
                        'members', ra.accepted_members
                    )
                WHEN p_response_id = 4 THEN
                    jsonb_build_object(
                        'role_id', ra.role_id,
                        'role_name', ra.role_name,
                        'role_name_plural', ra.role_name_plural,
                        'role_grade', ra.role_grade,
                        'role_level', ra.role_level,
                        'squad_list_seq', ra.min_squad_seq,
                        'member_count', jsonb_array_length(ra.declined_members),
                        'member_role_count', ra.code_declined_count,
                        'members', ra.declined_members
                    )
                WHEN p_response_id IS NOT NULL AND p_response_id NOT IN (3, 4) THEN
                    jsonb_build_object(
                        'role_id', ra.role_id,
                        'role_name', ra.role_name,
                        'role_name_plural', ra.role_name_plural,
                        'role_grade', ra.role_grade,
                        'role_level', ra.role_level,
                        'squad_list_seq', ra.min_squad_seq,
                        'member_count', jsonb_array_length(ra.no_response_members),
                        'member_role_count', ra.code_no_response_count,
                        'members', ra.no_response_members
                    )
                ELSE
                    jsonb_build_object(
                        'role_id', ra.role_id,
                        'role_name', ra.role_name,
                        'role_name_plural', ra.role_name_plural,
                        'role_grade', ra.role_grade,
                        'role_level', ra.role_level,
                        'squad_list_seq', ra.min_squad_seq,
                        'accepted_count', jsonb_array_length(ra.accepted_members),
                        'no_response_count', jsonb_array_length(ra.no_response_members),
                        'declined_count', jsonb_array_length(ra.declined_members),
                        'squad_code_count', ra.squad_code_count,
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

