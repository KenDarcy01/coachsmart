CREATE OR REPLACE FUNCTION "public"."get_event_attendance_summary_by_role_and_squad_v2"(
    "p_event_id" bigint,
    "p_role_grade_filter" smallint DEFAULT NULL::smallint,
    "p_role_level_filter" smallint DEFAULT NULL::smallint,
    "p_role_level_exclude" smallint DEFAULT NULL::smallint,
    "p_response_id" bigint DEFAULT NULL::bigint
)
RETURNS "jsonb"
LANGUAGE "plpgsql" SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_event_code_id bigint;
    v_effective_code_id bigint;
    v_team_id bigint;
    v_has_members_for_code boolean;
    v_next_code_id bigint;
    v_match_squad_available boolean;
    v_allow_lineup boolean;
BEGIN
    -- Get the event's code_id, team_id, and allow_lineup from the team
    SELECT e.event_code_id, e.team_id, t.allow_lineup
    INTO v_event_code_id, v_team_id, v_allow_lineup
    FROM public.events e
    JOIN public.teams t ON e.team_id = t.team_id
    WHERE e.event_id = p_event_id;

    -- Start with the event's code_id
    v_effective_code_id := v_event_code_id;

    -- If event has a code_id, check if it has any members
    IF v_event_code_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1
            FROM public.member_squad_link
            WHERE team_id = v_team_id
              AND code_id = v_event_code_id
            LIMIT 1
        ) INTO v_has_members_for_code;

        -- If no members found with event's code_id, find the next valid code_id in ascending order
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

    -- If still no code found, try club_code_link
    IF v_effective_code_id IS NULL THEN
        SELECT ccl.code_id INTO v_effective_code_id
        FROM public.teams t
        JOIN public.clubs c ON t.club_id = c.club_id
        JOIN public.club_code_link ccl ON c.club_id = ccl.club_id
        WHERE t.team_id = v_team_id
        ORDER BY ccl.code_id ASC
        LIMIT 1;
    END IF;

    -- Check if a match squad exists for this event
    SELECT EXISTS (
        SELECT 1
        FROM public.match_squads
        WHERE event_id = p_event_id
        LIMIT 1
    ) INTO v_match_squad_available;

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
    actual_member_squad_roles_for_event AS (
        SELECT DISTINCT
            e.event_id,
            msl.member_id,
            msl.squad_id,
            mtrl.role_id
        FROM
            events e
            JOIN public.member_squad_link msl ON e.team_id = msl.team_id
                AND msl.code_id = v_effective_code_id
            JOIN public.member_team_link mtl ON msl.member_id = mtl.member_id
                AND msl.team_id = mtl.team_id
            JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        WHERE
            e.event_id = p_event_id
            AND msl.squad_id IS NOT NULL
    ),
    all_squad_roles_for_event AS (
        SELECT
            e.event_id,
            sq.squad_id,
            sq.squad_name,
            sq.grade,
            sq.squad_image,
            sq.squad_list_seq,
            r.role_id,
            r.role_name,
            r.role_level,
            r.role_grade,
            r.role_name_plural,
            r.role_list_seq
        FROM
            events e
            JOIN public.teams t ON e.team_id = t.team_id
            JOIN public.squads sq ON t.team_id = sq.team_id
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
            amsr.event_id,
            amsr.squad_id,
            amsr.role_id,
            amsr.member_id,
            lea.response_id,
            CASE
                WHEN lea.response_id = 3 THEN 'accepted'
                WHEN lea.response_id = 4 THEN 'declined'
                WHEN lea.response_id IS NULL AND amsr.member_id IS NOT NULL THEN 'no_response'
                ELSE 'irrelevant'
            END AS attendance_status
        FROM
            actual_member_squad_roles_for_event amsr
            LEFT JOIN latest_event_attendance lea ON amsr.event_id = lea.event_id AND amsr.member_id = lea.member_id
        WHERE
            amsr.member_id IS NOT NULL
    ),
    squad_dynamic_role_count AS (
        SELECT
            msd.squad_id,
            COUNT(DISTINCT msd.member_id) AS dynamic_member_count
        FROM
            member_status_data msd
            JOIN public.roles r ON msd.role_id = r.role_id
        WHERE
            (p_role_level_filter IS NULL OR p_role_level_filter = 0 OR r.role_level = p_role_level_filter)
            AND (
                (p_response_id IN (3, 4) AND msd.response_id = p_response_id)
                OR (p_response_id IS NULL OR p_response_id NOT IN (3, 4) AND msd.response_id IS NULL)
            )
        GROUP BY
            msd.squad_id
    ),
    roles_with_counts AS (
        SELECT
            r.event_id,
            r.squad_id,
            r.squad_name,
            r.grade,
            r.squad_image,
            r.squad_list_seq,
            r.role_id,
            r.role_name,
            r.role_list_seq,
            r.role_grade,
            r.role_level,
            r.role_name_plural,
            COUNT(msd.member_id) FILTER (WHERE msd.attendance_status = 'accepted') AS accepted_count,
            COUNT(msd.member_id) FILTER (WHERE msd.attendance_status = 'declined') AS declined_count,
            COUNT(msd.member_id) FILTER (WHERE msd.attendance_status = 'no_response') AS no_response_count
        FROM
            all_squad_roles_for_event r
            LEFT JOIN member_status_data msd ON r.event_id = msd.event_id
                                            AND r.squad_id = msd.squad_id
                                            AND r.role_id = msd.role_id
        GROUP BY
            r.event_id, r.squad_id, r.squad_name, r.grade, r.squad_image, r.squad_list_seq,
            r.role_id, r.role_name, r.role_list_seq, r.role_grade, r.role_level, r.role_name_plural
    ),
    squads_with_roles AS (
        SELECT
            rwc.event_id,
            rwc.squad_id,
            rwc.squad_name,
            rwc.grade,
            rwc.squad_image,
            rwc.squad_list_seq,
            COALESCE(MAX(sdrc.dynamic_member_count), 0) AS role_level_count,
            jsonb_agg(
                jsonb_build_object(
                    'role_id', rwc.role_id,
                    'role_name', rwc.role_name,
                    'role_name_plural', rwc.role_name_plural,
                    'role_list_seq', rwc.role_list_seq,
                    'role_grade', rwc.role_grade,
                    'role_level', rwc.role_level,
                    'member_count', CASE
                        WHEN p_response_id = 3 THEN rwc.accepted_count
                        WHEN p_response_id = 4 THEN rwc.declined_count
                        ELSE rwc.no_response_count
                    END
                )
                ORDER BY rwc.role_list_seq, rwc.role_grade DESC, rwc.role_level DESC
            ) AS roles_list
        FROM
            roles_with_counts rwc
            LEFT JOIN squad_dynamic_role_count sdrc ON rwc.squad_id = sdrc.squad_id
        GROUP BY
            rwc.event_id, rwc.squad_id, rwc.squad_name, rwc.grade, rwc.squad_image, rwc.squad_list_seq
    )
    SELECT
        jsonb_build_object(
            'event_id',             sq.event_id,
            'team_name',            (SELECT t.team_name FROM public.events e JOIN public.teams t ON e.team_id = t.team_id WHERE e.event_id = p_event_id LIMIT 1),
            'allow_lineup',         v_allow_lineup,
            'response_id',          p_response_id,
            'event_code_id',        v_event_code_id,
            'effective_code_id',    v_effective_code_id,
            'used_fallback',        (v_effective_code_id != v_event_code_id OR v_event_code_id IS NULL),
            'match_squad_available', v_match_squad_available,
            'squads', jsonb_agg(
                jsonb_build_object(
                    'squad_id',         sq.squad_id,
                    'squad_name',       sq.squad_name,
                    'squad_grade',      sq.grade,
                    'squad_image',      sq.squad_image,
                    'role_level_count', sq.role_level_count,
                    'roles',            sq.roles_list
                )
                ORDER BY sq.squad_list_seq, sq.grade, sq.squad_name
            )
        )
    FROM squads_with_roles sq
    GROUP BY sq.event_id
    );
END;
$$;
