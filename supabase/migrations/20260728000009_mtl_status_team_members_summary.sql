-- Add mtl.status = 'active' filter to get_team_members_by_role and get_event_attendance_summary_by_role so soft-deleted team members are excluded.
--
-- get_team_members_by_role: both the role-level lookup subquery and the main
-- roster query join member_team_link (alias mtl). Both now require
-- mtl.status = 'active' so that members who have been soft-deleted from the
-- team (mtl.status != 'active') are invisible in roster management views.
--
-- get_event_attendance_summary_by_role: the actual_member_roles_for_event CTE
-- joins member_team_link. mtl.status = 'active' is added to its WHERE clause
-- for the same reason.


-- ─── get_team_members_by_role ─────────────────────────────────────────────────
-- Hides both 'deleted' and 'inactive' members — this is a roster management view.

CREATE OR REPLACE FUNCTION public.get_team_members_by_role(p_user_id uuid, p_team_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_user_highest_role smallint;
    v_team_info RECORD;
    v_roles_json jsonb;
    v_club_codes_json jsonb;
BEGIN
    SELECT MAX(r.role_level) INTO v_user_highest_role
    FROM public.roles r
    JOIN public.member_team_role_link mtrl ON r.role_id = mtrl.role_id
    JOIN public.member_team_link mtl ON mtrl.member_team_id = mtl.member_team_id
    JOIN public.members m ON mtl.member_id = m.member_id
    WHERE m.user_id = p_user_id
      AND mtl.status = 'active';  -- exclude soft-deleted team members

    SELECT team_id, team_name, team_unique_code, club_id, team_female
    INTO v_team_info
    FROM public.teams
    WHERE team_id = p_team_id;

    SELECT jsonb_agg(
        jsonb_build_object(
            'code_id', ec.code_id::bigint,
            'event_code', CASE
                WHEN v_team_info.team_female = TRUE AND ec.event_code = 'Hurling' THEN 'Camogie'
                ELSE ec.event_code
            END::text
        )
    ) INTO v_club_codes_json
    FROM public.club_code_link ccl
    JOIN public.event_codes ec ON ccl.code_id = ec.code_id
    WHERE ccl.club_id = v_team_info.club_id;

    SELECT jsonb_agg(role_group) INTO v_roles_json
    FROM (
        SELECT
            r.role_name, r.role_level,
            CASE
                WHEN r.role_name ILIKE '%y' THEN LEFT(r.role_name, -1) || 'ies'
                WHEN r.role_name ILIKE '%ch' OR r.role_name ILIKE '%sh' OR r.role_name ILIKE '%x' OR r.role_name ILIKE '%s' THEN r.role_name || 'es'
                ELSE r.role_name || 's'
            END as role_name_plural,
            COUNT(DISTINCT m.member_id) as member_count,
            jsonb_agg(
                jsonb_build_object(
                    'member_id',   m.member_id::bigint,
                    'first_name',  m.first_name::text,
                    'last_name',   m.last_name::text,
                    'full_name',   (m.first_name || ' ' || m.last_name)::text,
                    'squad_image', s.squad_image,
                    'squad_id',    mtl.squad_id::bigint,
                    'squad_name',  s.squad_name::text,
                    'squad_codes', (
                        SELECT jsonb_agg(
                            jsonb_build_object(
                                'code_id',    ec_sub.code_id::bigint,
                                'code_name',  CASE
                                    WHEN v_team_info.team_female = TRUE AND ec_sub.event_code = 'Hurling' THEN 'Camogie'
                                    ELSE ec_sub.event_code
                                END::text,
                                'squad_id',   COALESCE(s_sub.squad_id, 0)::bigint,
                                'squad_name', COALESCE(s_sub.squad_name, '')::text,
                                'squad_image',COALESCE(s_sub.squad_image, '')::text
                            )
                        )
                        FROM public.club_code_link ccl_sub
                        JOIN public.event_codes ec_sub ON ccl_sub.code_id = ec_sub.code_id
                        LEFT JOIN public.member_squad_link msl_sub
                            ON msl_sub.code_id = ec_sub.code_id AND msl_sub.member_id = m.member_id AND msl_sub.team_id = p_team_id
                        LEFT JOIN public.squads s_sub ON msl_sub.squad_id = s_sub.squad_id
                        WHERE ccl_sub.club_id = v_team_info.club_id
                    )
                )
            ) as members
        FROM public.roles r
        JOIN public.member_team_role_link mtrl ON r.role_id = mtrl.role_id
        JOIN public.member_team_link mtl ON mtrl.member_team_id = mtl.member_team_id
        JOIN public.members m ON mtl.member_id = m.member_id
        LEFT JOIN public.squads s ON mtl.squad_id = s.squad_id
        WHERE mtl.team_id = p_team_id
          AND mtl.status = 'active'       -- exclude soft-deleted team members
          AND m.status = 'active'         -- hide deleted + inactive members from roster
        GROUP BY r.role_name, r.role_level
        ORDER BY r.role_level DESC
    ) role_group;

    RETURN jsonb_build_object(
        'team_id',                v_team_info.team_id::bigint,
        'team_name',              v_team_info.team_name::text,
        'team_unique_code',       v_team_info.team_unique_code::text,
        'club_id',                v_team_info.club_id::bigint,
        'user_highest_role_level',COALESCE(v_user_highest_role, 0)::int,
        'role_groups',            COALESCE(v_roles_json, '[]'::jsonb),
        'club_codes',             COALESCE(v_club_codes_json, '[]'::jsonb)
    );
END;
$$;


-- ─── get_event_attendance_summary_by_role ────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_event_attendance_summary_by_role(
    p_event_id          bigint,
    p_role_grade_filter smallint DEFAULT NULL::smallint,
    p_role_level_filter smallint DEFAULT NULL::smallint,
    p_role_level_exclude smallint DEFAULT NULL::smallint
)
RETURNS TABLE(
    event_id               bigint,
    role_id                bigint,
    role_name              text,
    role_level             smallint,
    role_grade             smallint,
    role_name_plural       text,
    role_list_seq          smallint,
    accepted_attendees_count bigint,
    declined_attendees_count bigint,
    no_response_count      bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    RETURN QUERY
    WITH
    actual_member_roles_for_event AS (
        SELECT DISTINCT
            e.event_id,
            mtl.member_id,
            mtrl.role_id
        FROM events e
        JOIN member_team_link mtl
            ON e.team_id = mtl.team_id AND e.event_id = p_event_id
        JOIN members m ON mtl.member_id = m.member_id
        JOIN member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN team_roles_link trl
            ON mtl.team_id = trl.team_id AND mtrl.role_id = trl.role_id
        WHERE m.status != 'deleted'
          AND mtl.status = 'active'       -- exclude soft-deleted team members
          AND (
            e.squad_id IS NULL
            OR EXISTS (
                SELECT 1 FROM member_squad_link msl
                WHERE msl.member_id = mtl.member_id
                  AND msl.squad_id  = e.squad_id
            )
        )
    ),
    latest_event_attendance AS (
        SELECT DISTINCT ON (ea.event_id, ea.member_id)
            ea.event_id, ea.member_id, ea.response_id
        FROM event_attendance ea
        WHERE ea.event_id = p_event_id
        ORDER BY ea.event_id, ea.member_id, ea.created_at DESC
    )
    SELECT
        aetr.event_id,
        aetr.role_id,
        aetr.role_name,
        aetr.role_level,
        aetr.role_grade,
        aetr.role_name_plural,
        aetr.role_list_seq,
        COALESCE(SUM(CASE WHEN lea.response_id = 3 THEN 1 ELSE 0 END), 0::bigint) AS accepted_attendees_count,
        COALESCE(SUM(CASE WHEN lea.response_id = 4 THEN 1 ELSE 0 END), 0::bigint) AS declined_attendees_count,
        COALESCE(SUM(CASE WHEN lea.response_id IS NULL AND amr.member_id IS NOT NULL THEN 1 ELSE 0 END), 0::bigint) AS no_response_count
    FROM (
        SELECT
            e.event_id, t.team_id,
            r.role_id, r.role_name, r.role_level, r.role_grade,
            r.role_name_plural, r.role_list_seq
        FROM events e
        JOIN teams t ON e.team_id = t.team_id
        JOIN team_roles_link trl ON t.team_id = trl.team_id
        JOIN roles r ON trl.role_id = r.role_id
        WHERE e.event_id = p_event_id
          AND (p_role_grade_filter  IS NULL OR p_role_grade_filter  = 0 OR r.role_grade  = p_role_grade_filter)
          AND (p_role_level_filter  IS NULL OR p_role_level_filter  = 0 OR r.role_level >= p_role_level_filter)
          AND (p_role_level_exclude IS NULL OR r.role_level != p_role_level_exclude)
    ) aetr
    LEFT JOIN actual_member_roles_for_event amr
        ON aetr.event_id = amr.event_id AND aetr.role_id = amr.role_id
    LEFT JOIN latest_event_attendance lea
        ON amr.event_id = lea.event_id AND amr.member_id = lea.member_id
    GROUP BY
        aetr.event_id, aetr.role_id, aetr.role_name, aetr.role_level,
        aetr.role_grade, aetr.role_name_plural, aetr.role_list_seq
    ORDER BY
        aetr.role_list_seq, aetr.role_grade DESC, aetr.role_level DESC;
END;
$$;
