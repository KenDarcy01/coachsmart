-- Apply members.status filter to all member-listing RPCs.
-- Rule: 'deleted' members are hidden from everything.
--       'inactive' members are hidden from active roster/management views
--       but preserved in event-attendance historical views.
--
-- All CREATE OR REPLACE statements include SECURITY DEFINER SET search_path = 'public'
-- to preserve the settings applied in migrations 000013 and 000521140722.
-- No behaviour change for existing data — all current members have status = 'active'.

-- ─── get_accepted_unpaid_members ─────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_accepted_unpaid_members(p_event_id bigint)
RETURNS TABLE(member_id bigint, member_full_name text, role_name text, role_level smallint)
LANGUAGE sql
SECURITY DEFINER
SET search_path = 'public'
AS $$

WITH event_details AS (
    SELECT e.team_id
    FROM public.events AS e
    WHERE e.event_id = p_event_id
),
latest_event_attendance AS (
    WITH ranked_attendance AS (
        SELECT
            ea.member_id,
            ea.response_id,
            ROW_NUMBER() OVER(
                PARTITION BY ea.member_id
                ORDER BY ea.created_at DESC, ea.attendance_id DESC
            ) as rn
        FROM public.event_attendance AS ea
        WHERE ea.event_id = p_event_id
    )
    SELECT member_id, response_id
    FROM ranked_attendance
    WHERE rn = 1 AND response_id = 3
),
member_primary_role AS (
    WITH ranked_roles AS (
        SELECT
            mtl.member_id,
            r.role_name,
            r.role_level,
            r.role_grade,
            ROW_NUMBER() OVER(
                PARTITION BY mtl.member_id
                ORDER BY r.role_level ASC
            ) as rn
        FROM public.member_team_link AS mtl
        JOIN event_details AS ed ON mtl.team_id = ed.team_id
        JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN public.roles AS r ON mtrl.role_id = r.role_id
    )
    SELECT member_id, role_name, role_level, role_grade
    FROM ranked_roles
    WHERE rn = 1 AND role_grade = 10
),
latest_member_payment AS (
    WITH ranked_payment AS (
        SELECT
            eump.member_id,
            eump.payment_id,
            eump.payment_status,
            ROW_NUMBER() OVER(
                PARTITION BY eump.member_id
                ORDER BY eump.created_at DESC
            ) as rn
        FROM public.event_user_member_payment AS eump
        WHERE eump.event_id = p_event_id AND eump.payment_status <> 'pending'
    )
    SELECT member_id
    FROM ranked_payment
    WHERE rn = 1 AND payment_status = 'confirmed'
)

SELECT
    mpr.member_id,
    m.first_name || ' ' || m.last_name AS member_full_name,
    mpr.role_name,
    mpr.role_level
FROM latest_event_attendance AS lea
JOIN member_primary_role AS mpr ON lea.member_id = mpr.member_id
JOIN public.members AS m ON lea.member_id = m.member_id
LEFT JOIN latest_member_payment AS lmp ON lea.member_id = lmp.member_id
WHERE lmp.member_id IS NULL
  AND mpr.role_level = 10
  AND m.status != 'deleted'              -- hide deleted members
ORDER BY mpr.role_level ASC, m.last_name ASC;

$$;


-- ─── get_event_attendance_by_role_v2 ─────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_event_attendance_by_role_v2(
    p_event_id          bigint,
    p_role_grade_filter smallint DEFAULT NULL::smallint,
    p_role_level_filter smallint DEFAULT NULL::smallint,
    p_role_level_exclude smallint DEFAULT NULL::smallint,
    p_response_id       bigint   DEFAULT NULL::bigint
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
            WHERE team_id = v_team_id AND code_id = v_event_code_id
            LIMIT 1
        ) INTO v_has_members_for_code;

        IF NOT v_has_members_for_code THEN
            SELECT code_id INTO v_next_code_id
            FROM public.member_squad_link
            WHERE team_id = v_team_id AND code_id IS NOT NULL AND code_id > v_event_code_id
            ORDER BY code_id ASC LIMIT 1;

            IF v_next_code_id IS NOT NULL THEN
                v_effective_code_id := v_next_code_id;
            ELSE
                SELECT MIN(code_id) INTO v_effective_code_id
                FROM public.member_squad_link
                WHERE team_id = v_team_id AND code_id IS NOT NULL;
            END IF;
        END IF;
    ELSE
        SELECT MIN(code_id) INTO v_effective_code_id
        FROM public.member_squad_link
        WHERE team_id = v_team_id AND code_id IS NOT NULL;
    END IF;

    IF v_effective_code_id IS NULL THEN
        SELECT ccl.code_id INTO v_effective_code_id
        FROM public.teams t
        JOIN public.clubs c ON t.club_id = c.club_id
        JOIN public.club_code_link ccl ON c.club_id = ccl.club_id
        WHERE t.team_id = v_team_id
        ORDER BY ccl.code_id ASC LIMIT 1;
    END IF;

    RETURN (
    WITH
    latest_event_attendance AS (
        SELECT DISTINCT ON (ea.event_id, ea.member_id)
            ea.event_id, ea.member_id, ea.response_id
        FROM public.event_attendance ea
        WHERE ea.event_id = p_event_id
        ORDER BY ea.event_id, ea.member_id, ea.created_at DESC
    ),
    member_base_data AS (
        SELECT DISTINCT
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
            msl.squad_id AS squad_code_id,
            sq.squad_name AS squad_code_name,
            sq.squad_image AS squad_code_image
        FROM events e
        JOIN public.member_squad_link msl
            ON e.team_id = msl.team_id AND msl.code_id = v_effective_code_id
        JOIN public.members m ON msl.member_id = m.member_id
        JOIN public.squads sq ON msl.squad_id = sq.squad_id
        JOIN public.member_team_link mtl
            ON msl.member_id = mtl.member_id AND msl.team_id = mtl.team_id
        JOIN public.member_team_role_link mtrl
            ON mtl.member_team_id = mtrl.member_team_id
        WHERE e.event_id = p_event_id
          AND msl.squad_id IS NOT NULL
          AND m.status != 'deleted'       -- hide deleted members
    ),
    all_roles_for_event AS (
        SELECT DISTINCT
            e.event_id,
            r.role_id, r.role_name, r.role_level, r.role_grade,
            r.role_name_plural, r.role_list_seq
        FROM events e
        JOIN public.teams t ON e.team_id = t.team_id
        JOIN public.team_roles_link trl ON t.team_id = trl.team_id
        JOIN public.roles r ON trl.role_id = r.role_id
        WHERE e.event_id = p_event_id
          AND (p_role_grade_filter IS NULL OR p_role_grade_filter = 0 OR r.role_grade = p_role_grade_filter)
          AND (p_role_level_filter IS NULL OR p_role_level_filter = 0 OR r.role_level >= p_role_level_filter)
          AND (p_role_level_exclude IS NULL OR r.role_level != p_role_level_exclude)
    ),
    member_status_data AS (
        SELECT
            mbd.event_id, mbd.role_id, mbd.member_id,
            mbd.first_name, mbd.last_name,
            mbd.squad_id, mbd.squad_grade, mbd.squad_list_seq, mbd.squad_code_id,
            lea.response_id,
            jsonb_build_object(
                'member_id',      mbd.member_id,
                'member_name',    mbd.first_name || ' ' || mbd.last_name,
                'squad_id',       mbd.squad_id,
                'squad_name',     mbd.squad_name,
                'squad_grade',    mbd.squad_grade,
                'squad_list_seq', mbd.squad_list_seq,
                'squad_image',    mbd.squad_image,
                'squad_code_id',  mbd.squad_code_id,
                'squad_code_name',mbd.squad_code_name,
                'squad_code_image',mbd.squad_code_image,
                'sort_key',       LPAD(mbd.squad_list_seq::text, 10, '0') || ' ' || mbd.first_name || ' ' || mbd.last_name
            ) AS member_json,
            CASE
                WHEN lea.response_id = 3 THEN 'accepted'
                WHEN lea.response_id = 4 THEN 'declined'
                WHEN lea.response_id IS NULL THEN 'no_response'
                ELSE 'irrelevant'
            END AS attendance_status
        FROM member_base_data mbd
        LEFT JOIN latest_event_attendance lea
            ON mbd.event_id = lea.event_id AND mbd.member_id = lea.member_id
    ),
    roles_with_attendance AS (
        SELECT
            r.role_id, r.role_name, r.role_name_plural, r.role_grade,
            r.role_level, r.role_list_seq,
            MIN(msd.squad_list_seq) as min_squad_seq,
            COALESCE(jsonb_agg(msd.member_json ORDER BY msd.squad_id ASC, (msd.first_name || ' ' || msd.last_name) ASC) FILTER (WHERE msd.attendance_status = 'accepted'),    '[]'::jsonb) AS accepted_members,
            COALESCE(jsonb_agg(msd.member_json ORDER BY msd.squad_id ASC, (msd.first_name || ' ' || msd.last_name) ASC) FILTER (WHERE msd.attendance_status = 'declined'),    '[]'::jsonb) AS declined_members,
            COALESCE(jsonb_agg(msd.member_json ORDER BY msd.squad_id ASC, (msd.first_name || ' ' || msd.last_name) ASC) FILTER (WHERE msd.attendance_status = 'no_response'), '[]'::jsonb) AS no_response_members,
            COUNT(DISTINCT msd.member_id) FILTER (WHERE msd.squad_code_id IS NOT NULL)                                         as squad_code_count,
            COUNT(DISTINCT msd.member_id) FILTER (WHERE msd.squad_code_id IS NOT NULL AND msd.attendance_status = 'accepted')  as code_accepted_count,
            COUNT(DISTINCT msd.member_id) FILTER (WHERE msd.squad_code_id IS NOT NULL AND msd.attendance_status = 'declined')  as code_declined_count,
            COUNT(DISTINCT msd.member_id) FILTER (WHERE msd.squad_code_id IS NOT NULL AND msd.attendance_status = 'no_response') as code_no_response_count
        FROM all_roles_for_event r
        LEFT JOIN member_status_data msd ON r.event_id = msd.event_id AND r.role_id = msd.role_id
        GROUP BY r.event_id, r.role_id, r.role_name, r.role_name_plural, r.role_list_seq, r.role_grade, r.role_level
    )
    SELECT
        jsonb_agg(
            CASE
                WHEN p_response_id = 3 THEN
                    jsonb_build_object('role_id', ra.role_id, 'role_name', ra.role_name, 'role_name_plural', ra.role_name_plural,
                        'role_grade', ra.role_grade, 'role_level', ra.role_level, 'squad_list_seq', ra.min_squad_seq,
                        'member_count', jsonb_array_length(ra.accepted_members), 'member_role_count', ra.code_accepted_count,
                        'members', ra.accepted_members)
                WHEN p_response_id = 4 THEN
                    jsonb_build_object('role_id', ra.role_id, 'role_name', ra.role_name, 'role_name_plural', ra.role_name_plural,
                        'role_grade', ra.role_grade, 'role_level', ra.role_level, 'squad_list_seq', ra.min_squad_seq,
                        'member_count', jsonb_array_length(ra.declined_members), 'member_role_count', ra.code_declined_count,
                        'members', ra.declined_members)
                WHEN p_response_id IS NOT NULL AND p_response_id NOT IN (3, 4) THEN
                    jsonb_build_object('role_id', ra.role_id, 'role_name', ra.role_name, 'role_name_plural', ra.role_name_plural,
                        'role_grade', ra.role_grade, 'role_level', ra.role_level, 'squad_list_seq', ra.min_squad_seq,
                        'member_count', jsonb_array_length(ra.no_response_members), 'member_role_count', ra.code_no_response_count,
                        'members', ra.no_response_members)
                ELSE
                    jsonb_build_object('role_id', ra.role_id, 'role_name', ra.role_name, 'role_name_plural', ra.role_name_plural,
                        'role_grade', ra.role_grade, 'role_level', ra.role_level, 'squad_list_seq', ra.min_squad_seq,
                        'accepted_count', jsonb_array_length(ra.accepted_members),
                        'no_response_count', jsonb_array_length(ra.no_response_members),
                        'declined_count', jsonb_array_length(ra.declined_members),
                        'squad_code_count', ra.squad_code_count,
                        'accepted_members', ra.accepted_members,
                        'no_response_members', ra.no_response_members,
                        'declined_members', ra.declined_members)
            END
            ORDER BY ra.role_list_seq, ra.role_grade DESC, ra.role_level DESC
        )
    FROM roles_with_attendance ra
    );
END;
$$;


-- ─── get_event_attendance_summary_by_role_and_squad_v2 ───────────────────────

CREATE OR REPLACE FUNCTION public.get_event_attendance_summary_by_role_and_squad_v2(
    p_event_id          bigint,
    p_role_grade_filter smallint DEFAULT NULL::smallint,
    p_role_level_filter smallint DEFAULT NULL::smallint,
    p_role_level_exclude smallint DEFAULT NULL::smallint,
    p_response_id       bigint   DEFAULT NULL::bigint
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
    v_match_squad_available boolean;
    v_allow_lineup boolean;
BEGIN
    SELECT e.event_code_id, e.team_id, t.allow_lineup
    INTO v_event_code_id, v_team_id, v_allow_lineup
    FROM public.events e
    JOIN public.teams t ON e.team_id = t.team_id
    WHERE e.event_id = p_event_id;

    v_effective_code_id := v_event_code_id;

    IF v_event_code_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1 FROM public.member_squad_link
            WHERE team_id = v_team_id AND code_id = v_event_code_id LIMIT 1
        ) INTO v_has_members_for_code;

        IF NOT v_has_members_for_code THEN
            SELECT code_id INTO v_next_code_id
            FROM public.member_squad_link
            WHERE team_id = v_team_id AND code_id IS NOT NULL AND code_id > v_event_code_id
            ORDER BY code_id ASC LIMIT 1;

            IF v_next_code_id IS NOT NULL THEN
                v_effective_code_id := v_next_code_id;
            ELSE
                SELECT MIN(code_id) INTO v_effective_code_id
                FROM public.member_squad_link
                WHERE team_id = v_team_id AND code_id IS NOT NULL;
            END IF;
        END IF;
    ELSE
        SELECT MIN(code_id) INTO v_effective_code_id
        FROM public.member_squad_link
        WHERE team_id = v_team_id AND code_id IS NOT NULL;
    END IF;

    IF v_effective_code_id IS NULL THEN
        SELECT ccl.code_id INTO v_effective_code_id
        FROM public.teams t
        JOIN public.clubs c ON t.club_id = c.club_id
        JOIN public.club_code_link ccl ON c.club_id = ccl.club_id
        WHERE t.team_id = v_team_id
        ORDER BY ccl.code_id ASC LIMIT 1;
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.match_squads WHERE event_id = p_event_id LIMIT 1
    ) INTO v_match_squad_available;

    RETURN (
    WITH
    latest_event_attendance AS (
        SELECT DISTINCT ON (ea.event_id, ea.member_id)
            ea.event_id, ea.member_id, ea.response_id
        FROM public.event_attendance ea
        WHERE ea.event_id = p_event_id
        ORDER BY ea.event_id, ea.member_id, ea.created_at DESC
    ),
    actual_member_squad_roles_for_event AS (
        SELECT DISTINCT
            e.event_id, msl.member_id, msl.squad_id, mtrl.role_id
        FROM events e
        JOIN public.member_squad_link msl
            ON e.team_id = msl.team_id AND msl.code_id = v_effective_code_id
        JOIN public.members m ON msl.member_id = m.member_id  -- filter deleted members
        JOIN public.member_team_link mtl
            ON msl.member_id = mtl.member_id AND msl.team_id = mtl.team_id
        JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        WHERE e.event_id = p_event_id
          AND msl.squad_id IS NOT NULL
          AND m.status != 'deleted'       -- hide deleted members
    ),
    all_squad_roles_for_event AS (
        SELECT
            e.event_id,
            sq.squad_id, sq.squad_name, sq.grade, sq.squad_image, sq.squad_list_seq,
            r.role_id, r.role_name, r.role_level, r.role_grade,
            r.role_name_plural, r.role_list_seq
        FROM events e
        JOIN public.teams t ON e.team_id = t.team_id
        JOIN public.squads sq ON t.team_id = sq.team_id
        JOIN public.team_roles_link trl ON t.team_id = trl.team_id
        JOIN public.roles r ON trl.role_id = r.role_id
        WHERE e.event_id = p_event_id
          AND (p_role_grade_filter IS NULL OR p_role_grade_filter = 0 OR r.role_grade = p_role_grade_filter)
          AND (p_role_level_filter IS NULL OR p_role_level_filter = 0 OR r.role_level >= p_role_level_filter)
          AND (p_role_level_exclude IS NULL OR r.role_level != p_role_level_exclude)
    ),
    member_status_data AS (
        SELECT
            amsr.event_id, amsr.squad_id, amsr.role_id, amsr.member_id,
            lea.response_id,
            CASE
                WHEN lea.response_id = 3 THEN 'accepted'
                WHEN lea.response_id = 4 THEN 'declined'
                WHEN lea.response_id IS NULL AND amsr.member_id IS NOT NULL THEN 'no_response'
                ELSE 'irrelevant'
            END AS attendance_status
        FROM actual_member_squad_roles_for_event amsr
        LEFT JOIN latest_event_attendance lea
            ON amsr.event_id = lea.event_id AND amsr.member_id = lea.member_id
        WHERE amsr.member_id IS NOT NULL
    ),
    squad_dynamic_role_count AS (
        SELECT
            msd.squad_id,
            COUNT(DISTINCT msd.member_id) AS dynamic_member_count
        FROM member_status_data msd
        JOIN public.roles r ON msd.role_id = r.role_id
        WHERE
            (p_role_level_filter IS NULL OR p_role_level_filter = 0 OR r.role_level = p_role_level_filter)
            AND (
                (p_response_id IN (3, 4) AND msd.response_id = p_response_id)
                OR (p_response_id IS NULL OR p_response_id NOT IN (3, 4) AND msd.response_id IS NULL)
            )
        GROUP BY msd.squad_id
    ),
    roles_with_counts AS (
        SELECT
            r.event_id, r.squad_id, r.squad_name, r.grade, r.squad_image, r.squad_list_seq,
            r.role_id, r.role_name, r.role_list_seq, r.role_grade, r.role_level, r.role_name_plural,
            COUNT(msd.member_id) FILTER (WHERE msd.attendance_status = 'accepted')    AS accepted_count,
            COUNT(msd.member_id) FILTER (WHERE msd.attendance_status = 'declined')    AS declined_count,
            COUNT(msd.member_id) FILTER (WHERE msd.attendance_status = 'no_response') AS no_response_count
        FROM all_squad_roles_for_event r
        LEFT JOIN member_status_data msd
            ON r.event_id = msd.event_id AND r.squad_id = msd.squad_id AND r.role_id = msd.role_id
        GROUP BY
            r.event_id, r.squad_id, r.squad_name, r.grade, r.squad_image, r.squad_list_seq,
            r.role_id, r.role_name, r.role_list_seq, r.role_grade, r.role_level, r.role_name_plural
    ),
    squads_with_roles AS (
        SELECT
            rwc.event_id, rwc.squad_id, rwc.squad_name, rwc.grade,
            rwc.squad_image, rwc.squad_list_seq,
            COALESCE(MAX(sdrc.dynamic_member_count), 0) AS role_level_count,
            jsonb_agg(
                jsonb_build_object(
                    'role_id', rwc.role_id, 'role_name', rwc.role_name,
                    'role_name_plural', rwc.role_name_plural, 'role_list_seq', rwc.role_list_seq,
                    'role_grade', rwc.role_grade, 'role_level', rwc.role_level,
                    'member_count', CASE
                        WHEN p_response_id = 3 THEN rwc.accepted_count
                        WHEN p_response_id = 4 THEN rwc.declined_count
                        ELSE rwc.no_response_count
                    END
                )
                ORDER BY rwc.role_list_seq, rwc.role_grade DESC, rwc.role_level DESC
            ) AS roles_list
        FROM roles_with_counts rwc
        LEFT JOIN squad_dynamic_role_count sdrc ON rwc.squad_id = sdrc.squad_id
        GROUP BY rwc.event_id, rwc.squad_id, rwc.squad_name, rwc.grade, rwc.squad_image, rwc.squad_list_seq
    )
    SELECT
        jsonb_build_object(
            'event_id',              sq.event_id,
            'team_name',             (SELECT t.team_name FROM public.events e JOIN public.teams t ON e.team_id = t.team_id WHERE e.event_id = p_event_id LIMIT 1),
            'allow_lineup',          v_allow_lineup,
            'response_id',           p_response_id,
            'event_code_id',         v_event_code_id,
            'effective_code_id',     v_effective_code_id,
            'used_fallback',         (v_effective_code_id != v_event_code_id OR v_event_code_id IS NULL),
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
    WHERE m.user_id = p_user_id;

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


-- ─── get_event_team_members_for_user ─────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_event_team_members_for_user(p_event_id bigint, p_user_id uuid)
RETURNS TABLE(member_id bigint, first_name text, last_name text, event_team_id bigint, member_team_link_id bigint)
LANGUAGE sql
SECURITY DEFINER
SET search_path = 'public'
AS $$
WITH event_team AS (
    SELECT team_id FROM public.events WHERE event_id = p_event_id
)
SELECT
    m.member_id, m.first_name, m.last_name,
    et.team_id AS event_team_id,
    mtl.member_team_id AS member_team_link_id
FROM public.members m
JOIN public.user_member_link uml ON m.member_id = uml.member_id
JOIN public.member_team_link mtl ON m.member_id = mtl.member_id
JOIN event_team et ON mtl.team_id = et.team_id
WHERE uml.user_id = p_user_id
  AND et.team_id IS NOT NULL
  AND m.status != 'deleted'              -- hide deleted members
ORDER BY m.last_name, m.first_name;
$$;


-- ─── get_event_team_members_with_attendance ───────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_event_team_members_with_attendance(p_event_id bigint, p_user_id uuid)
RETURNS TABLE(member_id bigint, first_name text, last_name text, profile_pic text, response_value text, response_icon text, display_value text, icon_link text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    RETURN QUERY
    SELECT
        m.member_id, m.first_name, m.last_name, m.profile_pic,
        ert.response_value, ert.response_icon, ert.display_value, ert.icon_link
    FROM public.events AS e
    INNER JOIN public.member_team_link AS mtl ON e.team_id = mtl.team_id
    INNER JOIN public.members AS m ON mtl.member_id = m.member_id
    INNER JOIN public.user_member_link AS uml ON m.member_id = uml.member_id
    LEFT JOIN (
        SELECT
            event_attendance.member_id,
            event_attendance.response_id,
            ROW_NUMBER() OVER(PARTITION BY event_attendance.member_id ORDER BY event_attendance.created_at DESC) as rn
        FROM public.event_attendance
        WHERE event_attendance.event_id = p_event_id
    ) AS ea ON m.member_id = ea.member_id AND ea.rn = 1
    LEFT JOIN public.event_response_type AS ert ON ea.response_id = ert.response_id
    WHERE e.event_id = p_event_id
      AND uml.user_id = p_user_id
      AND m.status != 'deleted';         -- hide deleted members
END;
$$;


-- ─── get_members_attendance_latest ───────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_members_attendance_latest(p_event_id bigint, p_user_id uuid)
RETURNS TABLE(member_id bigint, first_name text, last_name text, profile_pic text, response_value text, response_icon text, display_value text, icon_link text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    RETURN QUERY
    SELECT
        m.member_id, m.first_name, m.last_name, m.profile_pic,
        ert.response_value, ert.response_icon, ert.display_value, ert.icon_link
    FROM public.members AS m
    INNER JOIN public.user_member_link AS uml ON m.member_id = uml.member_id
    LEFT JOIN (
        SELECT
            event_attendance.member_id,
            event_attendance.event_id,
            event_attendance.response_id,
            event_attendance.created_at,
            ROW_NUMBER() OVER(PARTITION BY event_attendance.member_id ORDER BY event_attendance.created_at DESC) as rn
        FROM public.event_attendance
        WHERE event_attendance.event_id = p_event_id
    ) AS ea ON m.member_id = ea.member_id AND ea.rn = 1
    LEFT JOIN public.event_response_type AS ert ON ea.response_id = ert.response_id
    WHERE uml.user_id = p_user_id
      AND m.status != 'deleted';         -- hide deleted members
END;
$$;


-- ─── get_user_event_members_with_attendance ───────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_user_event_members_with_attendance(p_event_id bigint, p_user_id uuid)
RETURNS TABLE(member_id bigint, first_name text, last_name text, profile_pic text, response_value text, response_icon text, display_value text, icon_link text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    RETURN QUERY
    SELECT
        m.member_id, m.first_name, m.last_name, m.profile_pic,
        ert.response_value, ert.response_icon, ert.display_value, ert.icon_link
    FROM public.members AS m
    INNER JOIN public.user_member_link AS uml ON m.member_id = uml.member_id
    INNER JOIN public.member_team_link AS mtl ON m.member_id = mtl.member_id
    INNER JOIN public.events AS e ON mtl.team_id = e.team_id
    LEFT JOIN (
        SELECT
            event_attendance.member_id,
            event_attendance.response_id,
            ROW_NUMBER() OVER(PARTITION BY event_attendance.member_id ORDER BY event_attendance.created_at DESC) as rn
        FROM public.event_attendance
        WHERE event_attendance.event_id = p_event_id
    ) AS ea ON m.member_id = ea.member_id AND ea.rn = 1
    LEFT JOIN public.event_response_type AS ert ON ea.response_id = ert.response_id
    WHERE uml.user_id = p_user_id
      AND e.event_id = p_event_id
      AND m.status != 'deleted';         -- hide deleted members
END;
$$;


-- ─── get_user_event_team_members ─────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_user_event_team_members(
    p_event_id  bigint,
    p_user_id   uuid,
    p_role_grade text DEFAULT NULL::text,
    p_role_level text DEFAULT NULL::text
)
RETURNS TABLE(member_id bigint, first_name text, last_name text, profile_pic text, response_value text, response_icon text, display_value text, icon_link text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    RETURN QUERY
    WITH latest_event_attendance AS (
        SELECT
            ea_sub.member_id, ea_sub.response_id,
            ROW_NUMBER() OVER(PARTITION BY ea_sub.member_id ORDER BY ea_sub.created_at DESC, ea_sub.attendance_id DESC) as rn
        FROM public.event_attendance AS ea_sub
        WHERE ea_sub.event_id = p_event_id
    ),
    distinct_members AS (
        SELECT
            m.member_id, m.first_name, m.last_name, m.profile_pic,
            r.role_level,
            lea.response_id,
            ROW_NUMBER() OVER(PARTITION BY m.member_id ORDER BY r.role_level ASC) as role_rn
        FROM public.members AS m
        INNER JOIN public.user_member_link AS uml ON m.member_id = uml.member_id
        INNER JOIN public.member_team_link AS mtl ON m.member_id = mtl.member_id
        INNER JOIN public.events AS e ON mtl.team_id = e.team_id
        INNER JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
        INNER JOIN public.roles AS r ON mtrl.role_id = r.role_id
        LEFT JOIN latest_event_attendance AS lea ON m.member_id = lea.member_id AND lea.rn = 1
        WHERE uml.user_id = p_user_id
          AND e.event_id = p_event_id
          AND (p_role_grade IS NULL OR p_role_grade = '' OR r.role_grade = p_role_grade::INT)
          AND (p_role_level IS NULL OR p_role_level = '' OR r.role_level >= p_role_level::INT)
          AND m.status != 'deleted'      -- hide deleted members
    )
    SELECT
        dm.member_id, dm.first_name, dm.last_name, dm.profile_pic,
        ert.response_value, ert.response_icon, ert.display_value, ert.icon_link
    FROM distinct_members AS dm
    LEFT JOIN public.event_response_type AS ert ON dm.response_id = ert.response_id
    WHERE dm.role_rn = 1
    ORDER BY dm.role_level ASC, dm.last_name ASC, dm.first_name ASC;
END;
$$;


-- ─── get_user_members_event_attendance ───────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_user_members_event_attendance(p_event_id bigint, p_user_id uuid)
RETURNS TABLE(member_id bigint, first_name text, last_name text, latest_response_value text, response_created_at timestamp with time zone, is_accepted boolean)
LANGUAGE sql
SECURITY DEFINER
SET search_path = 'public'
AS $$
WITH event_team AS (
    SELECT team_id FROM public.events WHERE event_id = p_event_id
),
latest_member_attendance AS (
    SELECT
        ea.member_id, ea.response_id,
        ert.response_value,
        ea.created_at AS response_created_at,
        ROW_NUMBER() OVER (PARTITION BY ea.member_id ORDER BY ea.created_at DESC) as rn
    FROM public.event_attendance ea
    JOIN public.event_response_type ert ON ea.response_id = ert.response_id
    WHERE ea.event_id = p_event_id
)
SELECT
    m.member_id, m.first_name, m.last_name,
    lta.response_value AS latest_response_value,
    lta.response_created_at,
    CASE
        WHEN lta.response_id = 3 THEN TRUE
        WHEN lta.response_id IS NOT NULL THEN FALSE
        ELSE NULL
    END AS is_accepted
FROM public.members m
JOIN public.user_member_link uml ON m.member_id = uml.member_id
JOIN public.member_team_link mtl ON m.member_id = mtl.member_id
JOIN event_team et ON mtl.team_id = et.team_id AND et.team_id IS NOT NULL
LEFT JOIN latest_member_attendance lta ON m.member_id = lta.member_id AND lta.rn = 1
WHERE uml.user_id = p_user_id
  AND m.status != 'deleted'             -- hide deleted members
ORDER BY m.last_name, m.first_name;
$$;


-- ─── create_match_squad_from_attendance ──────────────────────────────────────

CREATE OR REPLACE FUNCTION public.create_match_squad_from_attendance(p_event_id bigint, p_user_id uuid)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_new_match_squad_id int8;
    v_team_id int8;
    v_lookup_code_id int8;
    v_member_record RECORD;
    v_squad_id_final int8;
BEGIN
    SELECT e.team_id INTO v_team_id
    FROM public.events e
    WHERE e.event_id = p_event_id;

    v_lookup_code_id := public.get_updated_event_code(p_event_id);

    INSERT INTO public.match_squads (event_id, user_id)
    VALUES (p_event_id, p_user_id)
    RETURNING match_squad_id INTO v_new_match_squad_id;

    FOR v_member_record IN
        SELECT DISTINCT ON (ea.member_id)
            ea.member_id, ea.response_id, mtrl.role_id
        FROM public.event_attendance ea
        INNER JOIN public.member_team_link mtl
            ON ea.member_id = mtl.member_id AND mtl.team_id = v_team_id
        JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN public.roles r ON mtrl.role_id = r.role_id
        JOIN public.members m ON ea.member_id = m.member_id  -- filter deleted members
        WHERE ea.event_id = p_event_id
          AND r.role_grade = 10
          AND m.status != 'deleted'      -- hide deleted members
        ORDER BY ea.member_id, ea.created_at DESC
    LOOP
        IF v_member_record.response_id = 3 THEN
            v_squad_id_final := NULL;
            SELECT squad_id INTO v_squad_id_final
            FROM public.member_squad_link
            WHERE member_id = v_member_record.member_id
              AND team_id = v_team_id
              AND code_id = v_lookup_code_id
            LIMIT 1;

            IF v_squad_id_final = 0 THEN v_squad_id_final := NULL; END IF;

            INSERT INTO public.match_squad_details (
                match_squad_id, event_id, user_id, team_id, squad_id, member_id, role_id
            ) VALUES (
                v_new_match_squad_id, p_event_id, p_user_id, v_team_id,
                v_squad_id_final, v_member_record.member_id, v_member_record.role_id
            );
        END IF;
    END LOOP;

    RETURN v_new_match_squad_id;
END;
$$;
