-- Re-apply soft delete for remove_member_from_team and mtl.status = 'active'
-- filters across all active RPCs.
--
-- Migration 000013 (rollback) was auto-applied by supabase db push, which
-- restored the hard-delete function and removed the mtl.status filters.
-- This migration re-applies the intended changes.

-- Migration: 20260728000004_soft_delete_remove_member
--
-- Rewrites remove_member_from_team() as a soft delete operation.
--
-- Key changes vs the previous hard-delete version:
--   - member_team_link.status is set to 'removed' instead of the row being deleted,
--     preserving the link for audit and historical reporting.
--   - members.status is set to 'deleted' only when the member has no remaining active
--     team memberships; the row itself is never deleted.
--   - Historical and financial data is intentionally preserved:
--       event_attendance        — attendance history must not be lost
--       match_squad_details     — match participation records must not be lost
--       event_user_member_payment — financial records must not be lost
--   - member_team_role_link rows are hard-deleted (no historical value once the
--     team membership is ended).
--   - user_member_link, car_pool_detail, and member_squad_link are hard-deleted
--     when the member has no remaining active teams (removes app access and
--     clears operational/transient data that has no historical value).

CREATE OR REPLACE FUNCTION public.remove_member_from_team(
    p_member_id bigint,
    p_team_id   bigint
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_member_team_id   bigint;
    v_other_team_count int;
BEGIN
    -- 1. Locate the member_team_link row
    SELECT member_team_id
      INTO v_member_team_id
      FROM member_team_link
     WHERE member_id = p_member_id
       AND team_id   = p_team_id;

    -- 2. Guard: member must actually be linked to this team
    IF v_member_team_id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Member is not linked to this team'
        );
    END IF;

    -- 3. Hard-delete role assignments (no historical value)
    DELETE FROM member_team_role_link
     WHERE member_team_id = v_member_team_id;

    -- 4. Soft-delete the team membership
    UPDATE member_team_link
       SET status = 'removed'
     WHERE member_team_id = v_member_team_id;

    -- 5. Check whether the member still belongs to any other active team
    SELECT COUNT(*)
      INTO v_other_team_count
      FROM member_team_link
     WHERE member_id = p_member_id
       AND status    = 'active';

    -- 6. If no active teams remain, revoke app access and clear operational data
    IF v_other_team_count = 0 THEN
        -- Soft-delete the member record
        UPDATE members
           SET status = 'deleted'
         WHERE member_id = p_member_id;

        -- Remove app login link (revokes access)
        DELETE FROM user_member_link
         WHERE member_id = p_member_id;

        -- Remove car-pool assignments (operational, not historical)
        DELETE FROM car_pool_detail
         WHERE member_id = p_member_id;

        -- Remove squad assignments (operational, not historical)
        DELETE FROM member_squad_link
         WHERE member_id = p_member_id;

        -- NOTE: event_attendance, match_squad_details, and event_user_member_payment
        -- are intentionally NOT deleted — they are historical / financial records.
    END IF;

    -- 7. Success
    RETURN json_build_object(
        'success', true,
        'message', 'Member removed successfully'
    );

EXCEPTION
    WHEN OTHERS THEN
        -- 8. Surface any unexpected error to the caller
        RETURN json_build_object(
            'success', false,
            'message', SQLERRM
        );
END;
$$;

GRANT EXECUTE ON FUNCTION public.remove_member_from_team(bigint, bigint) TO anon;
GRANT EXECUTE ON FUNCTION public.remove_member_from_team(bigint, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_member_from_team(bigint, bigint) TO service_role;


-- Add mtl.status = 'active' filter to get_user_home_events so members soft-deleted from this team are excluded from user_roles, eligible_attendees, and the rm visibility subquery.

CREATE OR REPLACE FUNCTION public.get_user_home_events(p_user_id uuid)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = 'public'
AS $$

WITH user_roles AS (
    SELECT
        mtl.team_id,
        t.show_advert,
        MAX(r.role_level) AS user_highest_role_on_team
    FROM public.user_member_link AS uml
    JOIN public.member_team_link AS mtl ON uml.member_id = mtl.member_id AND mtl.status = 'active'
    JOIN public.teams AS t ON mtl.team_id = t.team_id
    JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.roles AS r ON mtrl.role_id = r.role_id
    WHERE uml.user_id = p_user_id
    GROUP BY mtl.team_id, t.show_advert
),
user_details AS (
    SELECT
        u.user_id, u.first_name, u.last_name, u.email_address, u.phone_number,
        COALESCE(MAX(ur.user_highest_role_on_team), 0) AS highest_role_level,
        COALESCE(BOOL_OR(ur.show_advert), FALSE) AS show_advert,
        (SELECT COUNT(*)::int FROM public.notifications WHERE recipient_user_id = p_user_id AND is_read = false) AS unread_notifications,
        (COALESCE(u.first_name, '') <> '' AND EXISTS (SELECT 1 FROM user_roles)) AS user_onboarded
    FROM public.users AS u
    LEFT JOIN user_roles AS ur ON TRUE
    WHERE u.user_id = p_user_id
    GROUP BY u.user_id
),
upcoming_events AS (
    SELECT
        e.*, t.team_name, t.team_female, t.club_id, et.event_type, ec.event_code,
        COALESCE(event_role.role_level, 0) AS event_role_level,
        sq.squad_name,
        to_char(e.event_date_time::timestamp, 'FMDay, DD FMMonth, YYYY at HH24:MI') AS event_date_time_formatted,
        CASE
            WHEN t.team_female = TRUE THEN
                REPLACE(
                    COALESCE(NULLIF(TRIM(e.event_title), ''),
                        CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type,
                            CASE WHEN COALESCE(e.opposition, '') <> '' THEN ' (' || e.opposition || ')' ELSE '' END)),
                    'Hurling', 'Camogie')
            ELSE
                COALESCE(NULLIF(TRIM(e.event_title), ''),
                    CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type,
                        CASE WHEN COALESCE(e.opposition, '') <> '' THEN ' (' || e.opposition || ')' ELSE '' END))
        END AS effective_event_title
    FROM public.events AS e
    JOIN public.teams AS t ON e.team_id = t.team_id
    JOIN user_roles ur ON e.team_id = ur.team_id
    JOIN public.event_types AS et ON e.event_type_id = et.event_type_id
    LEFT JOIN public.event_codes AS ec ON e.event_code_id = ec.code_id
    LEFT JOIN public.roles AS event_role ON e.audience_id = event_role.role_id
    LEFT JOIN public.squads AS sq ON e.squad_id = sq.squad_id
    WHERE e.event_date_time >= CURRENT_DATE
      AND e.status != 'deleted'
),
event_effective_codes AS (
    SELECT ue.event_id, public.get_updated_event_code(ue.event_id) AS effective_code_id
    FROM upcoming_events ue
    WHERE ue.squad_id IS NOT NULL
),
eligible_attendees AS (
    SELECT DISTINCT
        ue.event_id,
        mtl.member_id
    FROM upcoming_events ue
    LEFT JOIN event_effective_codes eec ON ue.event_id = eec.event_id
    JOIN public.member_team_link mtl ON ue.team_id = mtl.team_id AND mtl.status = 'active'
    JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.roles r_member ON mtrl.role_id = r_member.role_id
    WHERE (
        (ue.event_role_level > 10 AND r_member.role_level >= ue.event_role_level)
        OR (ue.event_role_level = 10 AND r_member.role_level = 10)
        OR (ue.event_role_level = 0 OR ue.event_role_level IS NULL)
    )
      AND (
        ue.squad_id IS NULL
        OR EXISTS (
            SELECT 1 FROM public.member_squad_link msl
            WHERE msl.member_id = mtl.member_id
              AND msl.squad_id  = ue.squad_id
              AND msl.code_id   = eec.effective_code_id
        )
    )
),
latest_attendance_records AS (
    SELECT DISTINCT ON (ea.event_id, ea.member_id)
        ea.event_id, ea.member_id, ea.response_id, ea.attendance_id
    FROM public.event_attendance ea
    INNER JOIN eligible_attendees el ON ea.event_id = el.event_id AND ea.member_id = el.member_id
    ORDER BY ea.event_id, ea.member_id, ea.created_at DESC
),
attendance_summary AS (
    SELECT
        el.event_id,
        COUNT(CASE WHEN lar.response_id = 3 THEN 1 END) AS accepted_count,
        COUNT(CASE WHEN lar.response_id = 4 THEN 1 END) AS declined_count,
        COUNT(el.member_id) - COUNT(lar.response_id) AS no_response_count
    FROM eligible_attendees el
    LEFT JOIN latest_attendance_records lar ON el.event_id = lar.event_id AND el.member_id = lar.member_id
    GROUP BY el.event_id
),
final_events_data AS (
    SELECT
        ue.event_id, ue.effective_event_title AS event_title, ue.meet_time,
        ue.event_date_time_formatted, ue.team_name, ue.team_id, ue.club_id,
        ue.status AS event_status, ue.squad_id, ue.squad_name,
        rm.member_id, lar_user.attendance_id,
        ert.display_value AS attendance_status, ert.icon_link AS attendance_icon,
        lar_user.response_id,
        ue.request_attendance, ue.event_type, ue.event_link, ue.event_code,
        ue.location_name, ue.location_pin, ue.opposition, ue.event_details,
        ue.home_away, ue.created_by,
        CONCAT(u.first_name, ' ', u.last_name) AS created_by_user_name,
        u.phone_number AS created_by_phone_number,
        rm.member_first_name, rm.member_last_name, rm.member_role_level, rm.event_role_level,
        COALESCE(asum.accepted_count, 0) AS accepted_count,
        COALESCE(asum.declined_count, 0) AS declined_count,
        COALESCE(asum.no_response_count, 0) AS no_response_count,
        ur.user_highest_role_on_team, ue.notify_admins_changes, ue.notify_admins_all,
        ue.payment_required,
        COALESCE((
            SELECT TRUE FROM public.event_user_member_payment eup
            WHERE eup.event_id = ue.event_id AND eup.user_id = p_user_id
              AND eup.payment_status = 'confirmed' LIMIT 1
        ), FALSE) AS event_paid
    FROM upcoming_events AS ue
    LEFT JOIN user_roles AS ur ON ue.team_id = ur.team_id
    LEFT JOIN public.users AS u ON ue.created_by = u.user_id
    LEFT JOIN (
        SELECT DISTINCT ON (ue2.event_id)
            ue2.event_id, m.member_id,
            m.first_name AS member_first_name, m.last_name AS member_last_name,
            r.role_level AS member_role_level, ue2.event_role_level
        FROM upcoming_events AS ue2
        JOIN public.user_member_link AS uml ON uml.user_id = p_user_id
        JOIN public.members AS m ON uml.member_id = m.member_id
        JOIN public.member_team_link AS mtl ON m.member_id = mtl.member_id AND mtl.team_id = ue2.team_id AND mtl.status = 'active'
        JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN public.roles AS r ON mtrl.role_id = r.role_id
        WHERE (
            r.role_grade = 100
            OR (
                r.role_level >= ue2.event_role_level
                AND (
                    ue2.squad_id IS NULL
                    OR EXISTS (
                        SELECT 1 FROM public.member_squad_link msl
                        WHERE msl.member_id = m.member_id
                          AND msl.squad_id  = ue2.squad_id
                          AND msl.code_id   = public.get_updated_event_code(ue2.event_id)
                    )
                )
            )
        )
        ORDER BY ue2.event_id, r.role_level ASC
    ) AS rm ON ue.event_id = rm.event_id
    LEFT JOIN latest_attendance_records AS lar_user
        ON lar_user.member_id = rm.member_id AND lar_user.event_id = ue.event_id
    LEFT JOIN public.event_response_type AS ert ON lar_user.response_id = ert.response_id
    LEFT JOIN attendance_summary AS asum ON ue.event_id = asum.event_id
    WHERE rm.member_id IS NOT NULL
    ORDER BY ue.event_date_time ASC
)
SELECT
    jsonb_build_object(
        'user_id', ud.user_id, 'first_name', ud.first_name, 'last_name', ud.last_name,
        'email_address', ud.email_address, 'phone_number', ud.phone_number,
        'highest_role_level', ud.highest_role_level, 'user_onboarded', ud.user_onboarded,
        'unread_notifications', ud.unread_notifications, 'show_advert', ud.show_advert,
        'user_team_count', (SELECT COUNT(DISTINCT team_id) + 1 FROM user_roles),
        'user_teams', (
            SELECT jsonb_agg(t) FROM (
                SELECT team_id, team_name, team_unique_code, profile_pic, team_female,
                       club_id, user_highest_role_on_team, sort_order
                FROM (
                    SELECT 0::bigint, 'All Teams'::text, NULL::text, NULL::text, FALSE,
                           0::bigint, 0::smallint, 0
                    UNION ALL
                    SELECT t2.team_id, t2.team_name, t2.team_unique_code, t2.profile_pic,
                           t2.team_female, t2.club_id, ur2.user_highest_role_on_team, 1
                    FROM public.teams t2 JOIN user_roles ur2 ON t2.team_id = ur2.team_id
                ) teams_union(team_id, team_name, team_unique_code, profile_pic, team_female,
                              club_id, user_highest_role_on_team, sort_order)
                ORDER BY sort_order, team_name
            ) t
        ),
        'clubs', (
            SELECT jsonb_agg(c) FROM (
                SELECT DISTINCT club_id, club_name, county, banner, crest, sort_order FROM (
                    SELECT c2.club_id, c2.club_name, c2.county, c2.banner, c2.crest, 1
                    FROM public.teams t2
                    JOIN user_roles ur2 ON t2.team_id = ur2.team_id
                    JOIN public.clubs c2 ON t2.club_id = c2.club_id
                    UNION ALL
                    SELECT NULL, 'All Clubs', NULL, NULL,
                        'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/coach-smart-new-mpqa5l/assets/yk304zt4r8kj/Launcher_Icon_v2-removebg-preview.png',
                        0
                ) clubs_union(club_id, club_name, county, banner, crest, sort_order)
                ORDER BY sort_order, club_name
            ) c
        ),
        'events', (SELECT COALESCE(jsonb_agg(fed), '[]'::jsonb) FROM final_events_data fed)
    )
FROM user_details AS ud;
$$;


-- Add mtl.status = 'active' filter to get_user_event_details member_primary_role CTE so soft-deleted team members are excluded from role assignment.

CREATE OR REPLACE FUNCTION public.get_user_event_details(p_event_id bigint, p_user_id uuid)
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
    WITH event_details AS (
        SELECT
            e.event_id,
            e.team_id,
            e.squad_id,
            e.status        AS event_status,
            e.meet_time,
            e.event_link,
            e.location_name,
            e.location_pin,
            e.opposition,
            e.event_details,
            e.home_away,
            e.request_attendance,
            e.notify_admins_changes,
            e.notify_admins_all,
            e.payment_required,
            e.payment_amount,
            e.event_image,
            e.car_pooling,
            t.team_name,
            t.team_female,
            et.event_type,
            ec.event_code,
            ec.code_id,
            e.audience_id,
            event_role.role_level AS event_role_level,
            to_char(e.event_date_time::timestamp, 'FMDay, DD FMMonth, YYYY at HH24:MI') AS event_date_time_formatted,
            CASE
                WHEN t.team_female = TRUE AND (
                    CASE
                        WHEN e.event_title IS NOT NULL AND TRIM(e.event_title) <> '' THEN e.event_title
                        WHEN et.event_type = 'Match' THEN
                            CASE WHEN e.opposition IS NOT NULL AND TRIM(e.opposition) <> ''
                                 THEN CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type, ' (', e.opposition, ')')
                                 ELSE CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type) END
                        ELSE CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type)
                    END
                ) LIKE '%Hurling%' THEN
                    REPLACE(
                        CASE
                            WHEN e.event_title IS NOT NULL AND TRIM(e.event_title) <> '' THEN e.event_title
                            WHEN et.event_type = 'Match' THEN
                                CASE WHEN e.opposition IS NOT NULL AND TRIM(e.opposition) <> ''
                                     THEN CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type, ' (', e.opposition, ')')
                                     ELSE CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type) END
                            ELSE CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type)
                        END, 'Hurling', 'Camogie')
                ELSE
                    CASE
                        WHEN e.event_title IS NOT NULL AND TRIM(e.event_title) <> '' THEN e.event_title
                        WHEN et.event_type = 'Match' THEN
                            CASE WHEN e.opposition IS NOT NULL AND TRIM(e.opposition) <> ''
                                 THEN CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type, ' (', e.opposition, ')')
                                 ELSE CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type) END
                        ELSE CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type)
                    END
            END AS effective_event_title,
            CONCAT(u.first_name, ' ', u.last_name) AS created_by_user_name,
            u.phone_number AS created_by_phone_number
        FROM public.events AS e
        JOIN public.teams AS t ON e.team_id = t.team_id
        JOIN public.event_types AS et ON e.event_type_id = et.event_type_id
        LEFT JOIN public.event_codes AS ec ON e.event_code_id = ec.code_id
        LEFT JOIN public.roles AS event_role ON e.audience_id = event_role.role_id
        LEFT JOIN public.users AS u ON e.created_by = u.user_id
        WHERE e.event_id = p_event_id
    ),
    latest_event_attendance AS (
        SELECT
            ea.member_id, ea.response_id,
            ROW_NUMBER() OVER(PARTITION BY ea.member_id ORDER BY ea.created_at DESC, ea.attendance_id DESC) as rn
        FROM public.event_attendance AS ea
        WHERE ea.event_id = p_event_id
    ),
    member_primary_role AS (
        WITH ranked_roles AS (
            SELECT
                mtl.member_id,
                r.role_id, r.role_level, r.role_name, r.role_name_plural, r.role_grade,
                ROW_NUMBER() OVER(
                    PARTITION BY mtl.member_id
                    ORDER BY
                        CASE WHEN r.role_level BETWEEN 20 AND 99 THEN 0 ELSE 1 END ASC,
                        r.role_level ASC, r.role_id ASC
                ) as rn
            FROM public.member_team_link AS mtl
            JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
            JOIN public.roles AS r ON mtrl.role_id = r.role_id
            JOIN event_details AS ed ON mtl.team_id = ed.team_id
            WHERE mtl.status = 'active'
        )
        SELECT member_id, role_id, role_level, role_name, role_name_plural, role_grade
        FROM ranked_roles WHERE rn = 1
    ),
    categorized_eligible_members AS (
        SELECT DISTINCT mtl.member_id
        FROM public.member_team_link AS mtl
        JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN public.roles AS r ON mtrl.role_id = r.role_id
        JOIN public.members AS m ON mtl.member_id = m.member_id
        CROSS JOIN event_details AS ed
        WHERE mtl.team_id = ed.team_id
          AND r.role_grade = 10
          AND r.role_level >= ed.event_role_level
          AND m.status != 'deleted'
          AND (
            ed.squad_id IS NULL
            OR EXISTS (
                SELECT 1 FROM public.member_squad_link msl
                WHERE msl.member_id = mtl.member_id
                  AND msl.squad_id  = ed.squad_id
                  AND msl.code_id   = v_effective_code_id
            )
        )
    ),
    total_eligible_count AS (
        SELECT COUNT(cem.member_id) AS total_count FROM categorized_eligible_members AS cem
    ),
    member_role_attendance AS (
        SELECT cem.member_id, lea.response_id
        FROM categorized_eligible_members AS cem
        LEFT JOIN latest_event_attendance AS lea ON cem.member_id = lea.member_id AND lea.rn = 1
    ),
    strictly_matched_members AS (
        SELECT cem.member_id
        FROM categorized_eligible_members AS cem
        JOIN member_primary_role AS mpr ON cem.member_id = mpr.member_id
        CROSS JOIN event_details AS ed
        WHERE mpr.role_grade = 10 AND mpr.role_level = ed.event_role_level
    ),
    matched_role_attendance AS (
        SELECT smm.member_id, lea.response_id
        FROM strictly_matched_members AS smm
        LEFT JOIN latest_event_attendance AS lea ON smm.member_id = lea.member_id AND lea.rn = 1
    ),
    matched_attendance_totals AS (
        SELECT COALESCE(mra.response_id, 0) AS response_id, COUNT(mra.member_id) AS member_count
        FROM matched_role_attendance AS mra GROUP BY 1
    ),
    team_squad_check AS (
        SELECT EXISTS (SELECT 1 FROM public.squads AS s JOIN event_details AS ed ON s.team_id = ed.team_id) AS team_has_squads LIMIT 1
    ),
    attendance_by_response_and_role AS (
        SELECT mpr.role_id, mpr.role_level, mpr.role_name, mpr.role_grade,
               COALESCE(mra.response_id, 0) AS response_id, COUNT(mra.member_id) AS member_count
        FROM member_role_attendance AS mra
        JOIN member_primary_role AS mpr ON mra.member_id = mpr.member_id
        GROUP BY 1, 2, 3, 4, 5
    ),
    event_distinct_primary_roles AS (
        SELECT DISTINCT mpr.role_id, mpr.role_level, mpr.role_name, mpr.role_name_plural, mpr.role_grade
        FROM member_primary_role AS mpr
        CROSS JOIN event_details AS ed
        WHERE mpr.role_grade = 10 AND mpr.role_level >= ed.event_role_level
    ),
    event_response_types AS (
        SELECT response_id FROM public.event_response_type UNION ALL SELECT 0 AS response_id
    ),
    zero_filled_attendance_by_role AS (
        SELECT ert.response_id, edpr.role_id, edpr.role_level, edpr.role_name, edpr.role_name_plural,
               edpr.role_grade, COALESCE(abrr.member_count, 0) AS member_count
        FROM event_response_types AS ert
        CROSS JOIN event_distinct_primary_roles AS edpr
        LEFT JOIN attendance_by_response_and_role AS abrr
            ON ert.response_id = abrr.response_id AND edpr.role_id = abrr.role_id
    ),
    dynamic_role_attendance_summary AS (
        SELECT zfar.response_id,
               jsonb_agg(jsonb_build_object(
                   'role_id', zfar.role_id, 'role_level', zfar.role_level,
                   'role_name', zfar.role_name, 'role_name_plural', zfar.role_name_plural,
                   'member_count', zfar.member_count
               ) ORDER BY zfar.role_level ASC, zfar.role_name ASC) AS filtered_response_by_role
        FROM zero_filled_attendance_by_role AS zfar GROUP BY 1
    ),
    summary_data AS (
        SELECT
            ed.event_role_level,
            COALESCE((SELECT filtered_response_by_role FROM dynamic_role_attendance_summary WHERE response_id = 3), '[]'::jsonb) AS accepted_attendance_summary,
            COALESCE((SELECT filtered_response_by_role FROM dynamic_role_attendance_summary WHERE response_id = 0), '[]'::jsonb) AS no_response_attendance_summary,
            COALESCE((SELECT filtered_response_by_role FROM dynamic_role_attendance_summary WHERE response_id = 4), '[]'::jsonb) AS declined_attendance_summary,
            COALESCE((SELECT member_count FROM matched_attendance_totals WHERE response_id = 3), 0) AS accepted_exact_match_count,
            COALESCE((SELECT member_count FROM matched_attendance_totals WHERE response_id = 0), 0) AS no_response_exact_match_count,
            COALESCE((SELECT member_count FROM matched_attendance_totals WHERE response_id = 4), 0) AS declined_exact_match_count
        FROM event_details AS ed LIMIT 1
    ),
    member_payment_status AS (
        SELECT eump.member_id, eump.payment_id, eump.payment_status,
               CASE WHEN eump.payment_status = 'confirmed' THEN 1 ELSE 0 END AS member_paid,
               ROW_NUMBER() OVER(PARTITION BY eump.member_id ORDER BY eump.created_at DESC) as rn
        FROM public.event_user_member_payment AS eump
        WHERE eump.event_id = p_event_id AND eump.user_id = p_user_id AND eump.payment_status <> 'pending'
    ),
    latest_member_payment AS (
        SELECT member_id, payment_id, member_paid, payment_status
        FROM member_payment_status WHERE rn = 1
    ),
    event_team_members AS (
        SELECT m.member_id, m.first_name, m.last_name, m.profile_pic, r.role_name, r.role_level,
               ROW_NUMBER() OVER(PARTITION BY m.member_id ORDER BY r.role_level ASC) as role_rn
        FROM public.members AS m
        INNER JOIN public.user_member_link AS uml ON m.member_id = uml.member_id
        INNER JOIN public.member_team_link AS mtl ON m.member_id = mtl.member_id
        INNER JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
        INNER JOIN public.roles AS r ON mtrl.role_id = r.role_id
        INNER JOIN event_details AS ed ON mtl.team_id = ed.team_id
        WHERE uml.user_id = p_user_id
          AND m.status != 'deleted'
    ),
    user_highest_role AS (
        SELECT MAX(etm.role_level) AS highest_role_level_for_user FROM event_team_members AS etm
    ),
    user_payment_status AS (
        SELECT COALESCE(COUNT(eup.payment_id), 0)::integer AS event_paid
        FROM public.event_user_payment AS eup
        WHERE eup.event_id = p_event_id AND eup.user_id = p_user_id AND eup.payment_status = 'confirmed'
    ),
    event_payment_summary AS (
        SELECT COUNT(eup.stripe_session_id) AS total_payments,
               COALESCE(SUM(eup.amount_paid), 0) AS total_amount_paid,
               COALESCE(SUM(eup.amount_paid)::numeric - COALESCE(SUM(eup.fee_amount), 0)::numeric - COALESCE(SUM(eup.tax_amount), 0)::numeric, 0) AS total_net_amount
        FROM public.event_user_payment eup
        WHERE eup.event_id = p_event_id AND eup.payment_status = 'confirmed'
    ),
    event_member_payment_summary AS (
        SELECT COALESCE(COUNT(eump.payment_id) FILTER (WHERE eump.payment_status = 'confirmed'), 0)::integer AS new_num_payments,
               COALESCE(SUM(eump.gross_amount), 0) AS new_gross_amount,
               COALESCE(SUM(eump.net_amount), 0) AS new_net_amount
        FROM public.event_user_member_payment eump
        WHERE eump.event_id = p_event_id AND eump.payment_status = 'confirmed'
    )
    SELECT
        jsonb_build_object(
            'event_id',                   ed.event_id,
            'team_id',                    ed.team_id,
            'squad_id',                   ed.squad_id,
            'squad_name',                 (SELECT s.squad_name FROM public.squads s WHERE s.squad_id = ed.squad_id),
            'event_status',               ed.event_status,
            'team_has_squads',            tsc.team_has_squads,
            'audience_id',                ed.audience_id,
            'event_role_level',           ed.event_role_level,
            'event_link',                 ed.event_link,
            'event_title',                ed.effective_event_title,
            'team_name',                  ed.team_name,
            'event_date_time_formatted',  ed.event_date_time_formatted,
            'meet_time',                  ed.meet_time,
            'event_type',                 ed.event_type,
            'event_code',                 ed.event_code,
            'code_id',                    ed.code_id,
            'location_name',              ed.location_name,
            'location_pin',               ed.location_pin,
            'opposition',                 ed.opposition,
            'event_details',              ed.event_details,
            'home_away',                  ed.home_away,
            'request_attendance',         ed.request_attendance,
            'notify_admins_changes',      ed.notify_admins_changes,
            'notify_admins_all',          ed.notify_admins_all,
            'created_by',                 ed.created_by_user_name,
            'created_by_phone_number',    ed.created_by_phone_number,
            'total_count',                tec.total_count,
            'user_highest_role_level',    uhr.highest_role_level_for_user,
            'car_pooling_enabled',        COALESCE(ed.car_pooling, false),
            'payment_required',           ed.payment_required,
            'payment_amount',             ed.payment_amount,
            'event_paid',                 ups.event_paid,
            'total_payments',             eps.total_payments,
            'total_amount_paid',          eps.total_amount_paid,
            'total_net_amount',           eps.total_net_amount,
            'event_image',                ed.event_image,
            'new_gross_amount',           emps.new_gross_amount,
            'new_net_amount',             emps.new_net_amount,
            'new_num_payments',           emps.new_num_payments,
            'team_members', (
                SELECT COALESCE(
                    jsonb_agg(
                        jsonb_build_object(
                            'member_id',             etm.member_id,
                            'first_name',            etm.first_name,
                            'last_name',             etm.last_name,
                            'profile_pic',           etm.profile_pic,
                            'role_name',             etm.role_name,
                            'role_level',            etm.role_level,
                            'response_id',           lea.response_id,
                            'attendance_status',     ert.display_value,
                            'attendance_icon',       ert.icon_link,
                            'member_paid',           COALESCE(lmp.member_paid, 0),
                            'member_payment_id',     lmp.payment_id,
                            'member_payment_status', lmp.payment_status
                        ) ORDER BY etm.role_level ASC, etm.last_name ASC
                    ) FILTER (WHERE etm.role_rn = 1), '[]'::jsonb
                )
                FROM event_team_members AS etm
                LEFT JOIN latest_event_attendance AS lea ON etm.member_id = lea.member_id AND lea.rn = 1
                LEFT JOIN public.event_response_type AS ert ON lea.response_id = ert.response_id
                LEFT JOIN latest_member_payment AS lmp ON etm.member_id = lmp.member_id
                WHERE etm.role_rn = 1
            ),
            'accepted_attendance_summary',    sd.accepted_attendance_summary,
            'no_response_attendance_summary', sd.no_response_attendance_summary,
            'declined_attendance_summary',    sd.declined_attendance_summary,
            'accepted_player_count',          sd.accepted_exact_match_count,
            'no_response_player_count',       sd.no_response_exact_match_count,
            'declined_player_count',          sd.declined_exact_match_count
        )
    FROM event_details AS ed
    CROSS JOIN user_highest_role AS uhr
    CROSS JOIN total_eligible_count AS tec
    CROSS JOIN team_squad_check AS tsc
    CROSS JOIN summary_data AS sd
    CROSS JOIN user_payment_status AS ups
    CROSS JOIN event_payment_summary AS eps
    CROSS JOIN event_member_payment_summary AS emps
    LIMIT 1
    );
END;
$$;


-- Add mtl.status = 'active' filter to member_base_raw in both attendance-by-role
-- functions so that inactive team members (e.g. transferred, left club) are
-- excluded from the attendance roster regardless of whether they still have a
-- squad assignment in member_team_link.

-- ─── get_event_attendance_by_role ────────────────────────────────────────────
-- mtl.status = 'active' added to member_base_raw WHERE clause so inactive
-- member_team_link rows are excluded from the attendance roster.

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
            AND mtl.status = 'active'
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


-- ─── get_event_attendance_by_role_v2 ─────────────────────────────────────────
-- mtl.status = 'active' added to member_base_raw WHERE clause so inactive
-- member_team_link rows are excluded from the attendance roster.

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
        SELECT DISTINCT ON (event_id, member_id)
            event_id, member_id, first_name, last_name, squad_id,
            squad_name, squad_grade, squad_list_seq, squad_image, role_id,
            squad_code_id, squad_code_name, squad_code_image
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


-- Add mtl.status = 'active' filter to actual_member_squad_roles_for_event so members soft-deleted from this team are excluded from squad attendance summary counts.

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
        JOIN public.members m ON msl.member_id = m.member_id
        JOIN public.member_team_link mtl
            ON msl.member_id = mtl.member_id AND msl.team_id = mtl.team_id
        JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN public.roles r ON mtrl.role_id = r.role_id
        WHERE e.event_id = p_event_id
          AND msl.squad_id IS NOT NULL
          AND m.status != 'deleted'
          AND r.role_grade = 10
          AND mtl.status = 'active'
          AND (e.squad_id IS NULL OR msl.squad_id = e.squad_id)
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
          AND (e.squad_id IS NULL OR sq.squad_id = e.squad_id)
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


-- Add mtl.status = 'active' filter to get_events_list all_team_members CTE so soft-deleted team members are excluded from attendance counts.

-- ─── get_events_list (admin) ──────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_events_list(
    p_date_from  text    DEFAULT NULL,
    p_date_to    text    DEFAULT NULL,
    p_team_id    bigint  DEFAULT NULL,
    p_code_id    bigint  DEFAULT NULL,
    p_type_id    bigint  DEFAULT NULL,
    p_opposition text    DEFAULT NULL
)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = 'public'
AS $$

WITH sanitized_filters AS (
    SELECT
        NULLIF(TRIM(p_date_from), '')  AS filter_date_from,
        NULLIF(TRIM(p_date_to), '')    AS filter_date_to,
        NULLIF(p_team_id, 0)           AS filter_team_id,
        NULLIF(p_code_id, 0)           AS filter_code_id,
        NULLIF(p_type_id, 0)           AS filter_type_id,
        NULLIF(TRIM(p_opposition), '') AS filter_opposition
),
filtered_events AS (
    SELECT
        e.*, t.team_name, t.team_female, t.club_id, et.event_type, ec.event_code,
        event_role.role_level AS event_role_level,
        to_char(e.event_date_time::timestamp, 'FMDay, DD Month, YYYY at HH24:MI') AS event_date_time_formatted,
        CASE
            WHEN t.team_female = TRUE AND (
                CASE
                    WHEN e.event_title IS NOT NULL AND TRIM(e.event_title) <> '' THEN e.event_title
                    WHEN et.event_type = 'Match' THEN
                        CASE WHEN e.opposition IS NOT NULL AND TRIM(e.opposition) <> ''
                             THEN CONCAT(COALESCE(ec.event_code,''),' ',et.event_type,' (',e.opposition,')')
                             ELSE CONCAT(COALESCE(ec.event_code,''),' ',et.event_type) END
                    ELSE CONCAT(COALESCE(ec.event_code,''),' ',et.event_type)
                END
            ) LIKE '%Hurling%' THEN
                REPLACE(
                    CASE
                        WHEN e.event_title IS NOT NULL AND TRIM(e.event_title) <> '' THEN e.event_title
                        WHEN et.event_type = 'Match' THEN
                            CASE WHEN e.opposition IS NOT NULL AND TRIM(e.opposition) <> ''
                                 THEN CONCAT(COALESCE(ec.event_code,''),' ',et.event_type,' (',e.opposition,')')
                                 ELSE CONCAT(COALESCE(ec.event_code,''),' ',et.event_type) END
                        ELSE CONCAT(COALESCE(ec.event_code,''),' ',et.event_type)
                    END, 'Hurling', 'Camogie')
            ELSE
                CASE
                    WHEN e.event_title IS NOT NULL AND TRIM(e.event_title) <> '' THEN e.event_title
                    WHEN et.event_type = 'Match' THEN
                        CASE WHEN e.opposition IS NOT NULL AND TRIM(e.opposition) <> ''
                             THEN CONCAT(COALESCE(ec.event_code,''),' ',et.event_type,' (',e.opposition,')')
                             ELSE CONCAT(COALESCE(ec.event_code,''),' ',et.event_type) END
                    ELSE CONCAT(COALESCE(ec.event_code,''),' ',et.event_type)
                END
        END AS effective_event_title
    FROM public.events AS e
    CROSS JOIN sanitized_filters AS sf
    JOIN public.teams AS t ON e.team_id = t.team_id
    JOIN public.event_types AS et ON e.event_type_id = et.event_type_id
    LEFT JOIN public.event_codes AS ec ON e.event_code_id = ec.code_id
    LEFT JOIN public.roles AS event_role ON e.audience_id = event_role.role_id
    WHERE e.event_date_time_2 >= COALESCE(sf.filter_date_from::timestamp with time zone, '1900-01-01'::timestamp with time zone)
      AND e.event_date_time_2 <= COALESCE(sf.filter_date_to::timestamp with time zone,   '2100-01-01'::timestamp with time zone)
      AND (sf.filter_team_id    IS NULL OR e.team_id        = sf.filter_team_id)
      AND (sf.filter_code_id    IS NULL OR e.event_code_id  = sf.filter_code_id)
      AND (sf.filter_type_id    IS NULL OR e.event_type_id  = sf.filter_type_id)
      AND (sf.filter_opposition IS NULL OR e.opposition ILIKE ('%' || sf.filter_opposition || '%'))
      AND e.status != 'deleted'
),
all_team_members AS (
    SELECT fe.event_id, mtl.member_id
    FROM filtered_events AS fe
    JOIN public.member_team_link AS mtl ON fe.team_id = mtl.team_id AND mtl.status = 'active'
    JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.roles AS r_member ON mtrl.role_id = r_member.role_id
    WHERE (
        (fe.event_role_level = 10 AND r_member.role_level = 10)
        OR (fe.event_role_level > 10 AND r_member.role_level >= fe.event_role_level)
    )
      AND (
        fe.squad_id IS NULL
        OR EXISTS (
            SELECT 1 FROM public.member_squad_link msl
            WHERE msl.member_id = mtl.member_id
              AND msl.squad_id  = fe.squad_id
        )
    )
    GROUP BY fe.event_id, mtl.member_id
),
latest_event_attendance AS (
    SELECT DISTINCT ON (ea_sub.member_id, ea_sub.event_id)
        ea_sub.event_id, ea_sub.member_id, ea_sub.response_id, ea_sub.attendance_id
    FROM public.event_attendance AS ea_sub
    JOIN filtered_events AS fe ON ea_sub.event_id = fe.event_id
    JOIN all_team_members AS atm ON ea_sub.member_id = atm.member_id AND ea_sub.event_id = atm.event_id
    ORDER BY ea_sub.member_id, ea_sub.event_id, ea_sub.created_at DESC, ea_sub.attendance_id DESC
),
attendance_summary AS (
    SELECT
        atm.event_id,
        COUNT(CASE WHEN lea.response_id = 3 THEN atm.member_id END) AS accepted_count,
        COUNT(CASE WHEN lea.response_id = 4 THEN atm.member_id END) AS declined_count,
        COUNT(CASE WHEN lea.response_id IS NULL THEN atm.member_id END) AS no_response_count,
        COUNT(atm.member_id) AS total_eligible_members
    FROM all_team_members AS atm
    LEFT JOIN latest_event_attendance AS lea ON atm.member_id = lea.member_id AND atm.event_id = lea.event_id
    GROUP BY atm.event_id
)
SELECT
    COALESCE(json_agg(final_result)::jsonb, '[]'::jsonb)
FROM (
    SELECT
        fe.event_id, fe.effective_event_title AS event_title, fe.meet_time,
        fe.event_date_time_formatted, fe.team_name, fe.team_id, fe.club_id,
        fe.status AS event_status,
        fe.request_attendance, fe.event_type, fe.event_link, fe.event_code,
        fe.location_name, fe.location_pin, fe.opposition, fe.event_details,
        fe.home_away, fe.created_by,
        CONCAT(u.first_name, ' ', u.last_name) AS created_by_user_name,
        u.phone_number AS created_by_phone_number,
        COALESCE(asum.accepted_count, 0) AS accepted_count,
        COALESCE(asum.declined_count, 0) AS declined_count,
        COALESCE(asum.no_response_count, 0) AS no_response_count,
        COALESCE(asum.total_eligible_members, 0) AS total_eligible_members,
        fe.notify_admins_changes, fe.notify_admins_all
    FROM filtered_events AS fe
    LEFT JOIN public.users AS u ON fe.created_by = u.user_id
    LEFT JOIN attendance_summary AS asum ON fe.event_id = asum.event_id
    ORDER BY fe.event_date_time DESC
) AS final_result;
$$;


-- Add mtl.status = 'active' filter to get_user_event_create_detail and get_user_event_edit_detail
-- so admins removed from a team can no longer create/edit events for that team.


-- ─── get_user_event_create_detail ───────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_user_event_create_detail(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_result jsonb;
    v_default_team_id bigint;
BEGIN
    SELECT
        CASE WHEN COUNT(DISTINCT mtl.team_id) = 1 THEN MAX(mtl.team_id) ELSE NULL END
    INTO v_default_team_id
    FROM public.members m
    JOIN public.member_team_link mtl ON m.member_id = mtl.member_id AND mtl.status = 'active'
    WHERE m.user_id = p_user_id;

    SELECT jsonb_build_object(
        'user_id',         p_user_id,
        'default_team_id', v_default_team_id,
        'create_teams', (
            SELECT jsonb_agg(team_data)
            FROM (
                SELECT DISTINCT ON (t.team_id)
                    t.team_id, t.team_name, t.club_id, c.club_name,
                    m.member_id,
                    (m.first_name || ' ' || m.last_name) AS authorized_member_name,
                    r.role_id,
                    r.role_name  AS admin_role,
                    r.role_level AS admin_level,
                    (SELECT jsonb_agg(jsonb_build_object('id', et.event_type_id, 'name', et.event_type))
                     FROM public.event_types et) AS event_types,
                    (SELECT jsonb_agg(jsonb_build_object('id', ec.code_id, 'name', ec.event_code))
                     FROM public.club_code_link ccl
                     JOIN public.event_codes ec ON ccl.code_id = ec.code_id
                     WHERE ccl.club_id = t.club_id) AS event_codes,
                    (SELECT jsonb_agg(jsonb_build_object(
                         'id', r_inner.role_id, 'name', r_inner.role_name,
                         'name_plural', r_inner.role_name_plural))
                     FROM public.team_roles_link trl
                     JOIN public.roles r_inner ON trl.role_id = r_inner.role_id
                     WHERE trl.team_id = t.team_id
                       AND r_inner.role_grade = 10 AND r_inner.show_audience = true) AS team_roles,
                    (SELECT jsonb_agg(jsonb_build_object(         -- new: squads per team
                         'id', s.squad_id, 'name', s.squad_name, 'image', s.squad_image))
                     FROM public.squads s
                     WHERE s.team_id = t.team_id) AS squads
                FROM public.members m
                JOIN public.member_team_link mtl ON m.member_id = mtl.member_id AND mtl.status = 'active'
                JOIN public.teams t ON mtl.team_id = t.team_id
                LEFT JOIN public.clubs c ON t.club_id = c.club_id
                JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
                JOIN public.roles r ON mtrl.role_id = r.role_id
                WHERE m.user_id = p_user_id AND r.role_grade = 100
                ORDER BY t.team_id, r.role_level DESC
            ) team_data
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$;


-- ─── get_user_event_edit_detail ─────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_user_event_edit_detail(
    p_user_id  uuid,
    p_event_id bigint DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_result          jsonb;
    v_default_team_id bigint;
    v_current_event   jsonb;
BEGIN
    SELECT
        CASE WHEN COUNT(DISTINCT mtl.team_id) = 1 THEN MAX(mtl.team_id) ELSE NULL END
    INTO v_default_team_id
    FROM public.members m
    JOIN public.member_team_link mtl ON m.member_id = mtl.member_id AND mtl.status = 'active'
    WHERE m.user_id = p_user_id;

    IF p_event_id IS NOT NULL THEN
        SELECT jsonb_build_object(
            'event_id',          e.event_id,
            'event_title',       e.event_title,
            'event_type_id',     e.event_type_id,
            'event_date_time',   e.event_date_time_2,
            'meet_time',         e.meet_time,
            'event_code_id',     e.event_code_id,
            'opposition',        e.opposition,
            'home_away',         e.home_away,
            'location_name',     e.location_name,
            'location_pin',      e.location_pin,
            'event_link',        e.event_link,
            'audience_id',       e.audience_id,
            'request_attendance',e.request_attendance,
            'event_details',     e.event_details,
            'team_id',           e.team_id,
            'event_image',       e.event_image,
            'payment_required',  e.payment_required,
            'payment_amount',    e.payment_amount,
            'squad_id',          e.squad_id,              -- new
            'status',            e.status                 -- new
        ) INTO v_current_event
        FROM public.events e
        WHERE e.event_id = p_event_id;
    END IF;

    SELECT jsonb_build_object(
        'user_id',         p_user_id,
        'default_team_id', v_default_team_id,
        'current_event',   v_current_event,
        'create_teams', (
            SELECT jsonb_agg(team_data)
            FROM (
                SELECT DISTINCT ON (t.team_id)
                    t.team_id, t.team_name, t.club_id, c.club_name,
                    m.member_id,
                    (m.first_name || ' ' || m.last_name) AS authorized_member_name,
                    r.role_id,
                    r.role_name  AS admin_role,
                    r.role_level AS admin_level,
                    (SELECT jsonb_agg(jsonb_build_object('id', et.event_type_id, 'name', et.event_type))
                     FROM public.event_types et) AS event_types,
                    (SELECT jsonb_agg(jsonb_build_object('id', ec.code_id, 'name', ec.event_code))
                     FROM public.club_code_link ccl
                     JOIN public.event_codes ec ON ccl.code_id = ec.code_id
                     WHERE ccl.club_id = t.club_id) AS event_codes,
                    (SELECT jsonb_agg(jsonb_build_object(
                         'id', r_inner.role_id, 'name', r_inner.role_name,
                         'name_plural', r_inner.role_name_plural))
                     FROM public.team_roles_link trl
                     JOIN public.roles r_inner ON trl.role_id = r_inner.role_id
                     WHERE trl.team_id = t.team_id
                       AND r_inner.role_grade = 10 AND r_inner.show_audience = true) AS team_roles,
                    (SELECT jsonb_agg(jsonb_build_object(         -- new: squads per team
                         'id', s.squad_id, 'name', s.squad_name, 'image', s.squad_image))
                     FROM public.squads s
                     WHERE s.team_id = t.team_id) AS squads
                FROM public.members m
                JOIN public.member_team_link mtl ON m.member_id = mtl.member_id AND mtl.status = 'active'
                JOIN public.teams t ON mtl.team_id = t.team_id
                LEFT JOIN public.clubs c ON t.club_id = c.club_id
                JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
                JOIN public.roles r ON mtrl.role_id = r.role_id
                WHERE m.user_id = p_user_id AND r.role_grade = 100
                ORDER BY t.team_id, r.role_level DESC
            ) team_data
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$;


-- Migration: 20260728000012_mtl_status_team_summary_unresponded
--
-- Adds mtl.status = 'active' to every JOIN on member_team_link in three
-- functions so that soft-deleted team memberships are invisible.
--
-- get_user_team_summary(p_user_id uuid)
--   Two JOINs on member_team_link (alias mtl):
--     1. The MAX(role_level) subquery that determines the user's
--        overall highest role level.
--     2. The DISTINCT ON query that builds the per-team role list.
--   Both now require mtl.status = 'active' so a user who has been
--   removed from a team no longer sees that team or inherits its
--   role level in the home-screen summary.
--
-- get_unresponded_events(event_id_param bigint)
--   Single JOIN on member_team_link (alias mtl) that expands a team
--   to all its members.  Soft-deleted members (mtl.status != 'active')
--   must NOT receive unresponded-event notification emails.
--
-- get_unresponded_events_v2(event_id_param bigint, ...)
--   Same concern as v1: the all_team_members CTE joins member_team_link
--   to enumerate every member on the event's team.  Adding
--   mtl.status = 'active' prevents removed members from appearing in
--   the notification dispatch list.
--
-- All three functions are written with SECURITY DEFINER
-- SET search_path = 'public' inline (migration 20260727000012 already
-- set search_path via ALTER, and get_user_team_summary already carried
-- SECURITY DEFINER; this makes the intent explicit and keeps the body
-- self-contained for future reads).


-- ─── get_user_team_summary ───────────────────────────────────────────────────
-- Change: both MTL joins now carry AND mtl.status = 'active'.

CREATE OR REPLACE FUNCTION public.get_user_team_summary(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_overall_highest smallint;
    v_teams_json jsonb;
BEGIN
    -- 1. Get the absolute MAX role level across all members LINKED to this user
    SELECT MAX(r.role_level) INTO v_overall_highest
    FROM public.user_member_link uml
    JOIN public.member_team_link mtl ON uml.member_id = mtl.member_id AND mtl.status = 'active'
    JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.roles r ON mtrl.role_id = r.role_id
    WHERE uml.user_id = p_user_id;

    -- 2. Build the flat team list for members explicitly linked to this user
    SELECT jsonb_agg(t_final) INTO v_teams_json
    FROM (
        SELECT DISTINCT ON (t.team_id)
            t.team_id,
            t.team_name,
            t.team_unique_code,
            r.role_level as team_highest_role_level,
            r.role_name as team_role_name
        FROM public.user_member_link uml
        INNER JOIN public.member_team_link mtl ON uml.member_id = mtl.member_id AND mtl.status = 'active'
        INNER JOIN public.teams t ON mtl.team_id = t.team_id
        INNER JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        INNER JOIN public.roles r ON mtrl.role_id = r.role_id
        WHERE uml.user_id = p_user_id
        ORDER BY t.team_id, r.role_level DESC
    ) t_final;

    RETURN jsonb_build_object(
        'overall_highest_role_level', COALESCE(v_overall_highest, 0),
        'teams', COALESCE(v_teams_json, '[]'::jsonb)
    );
END;
$$;


-- ─── get_unresponded_events ───────────────────────────────────────────────────
-- Change: MTL join now carries AND mtl.status = 'active' so removed members
-- are excluded from the unresponded-event notification list.

CREATE OR REPLACE FUNCTION public.get_unresponded_events(event_id_param bigint)
RETURNS SETOF jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  RETURN QUERY
  WITH latest_attendance AS (
    SELECT
      ea.event_id,
      ea.member_id,
      ea.response_id,
      row_number() OVER (
        PARTITION BY ea.event_id, ea.member_id
        ORDER BY ea.created_at DESC
      ) AS rn
    FROM public.event_attendance ea
  )
  SELECT DISTINCT
    jsonb_build_object(
      'email',             u.email_address,
      'team_name',         t.team_name,
      'event_title',       e.event_title,
      'event_date_time',   e.event_date_time,
      'full_name',         u.first_name || ' ' || u.last_name,
      'first_name',        u.first_name,
      'last_name',         u.last_name,
      'member_first_name', m.first_name,
      'member_last_name',  m.last_name
    )
  FROM public.events e
  JOIN public.teams t    ON t.team_id    = e.team_id
  JOIN public.member_team_link mtl ON mtl.team_id = t.team_id AND mtl.status = 'active'
  JOIN public.members m  ON m.member_id  = mtl.member_id
  JOIN public.user_member_link uml ON uml.member_id = m.member_id
  JOIN public.users u    ON u.user_id    = uml.user_id
  LEFT JOIN latest_attendance la
         ON la.event_id  = e.event_id
        AND la.member_id = m.member_id
        AND la.rn = 1
  WHERE e.event_id = event_id_param
    AND (la.response_id IS NULL OR la.response_id = 0);
END;
$$;


-- ─── get_unresponded_events_v2 ────────────────────────────────────────────────
-- Change: the all_team_members CTE INNER JOIN on member_team_link now carries
-- AND mtl.status = 'active' so removed members are excluded from the
-- notification dispatch list before role-grade / role-level filtering.

CREATE OR REPLACE FUNCTION public.get_unresponded_events_v2(
    event_id_param bigint,
    p_role_grade   smallint DEFAULT NULL::smallint,
    p_role_level   smallint DEFAULT NULL::smallint
)
RETURNS SETOF jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    RETURN QUERY
    WITH
    -- 1. CTE: Find ALL members linked to the event's team (The foundation set).
    all_team_members AS (
        SELECT DISTINCT ON (e.event_id, m.member_id, u.user_id)
            e.event_id,
            e.event_title,
            e.event_date_time,
            t.team_name,
            u.email_address,
            u.first_name AS user_first_name,
            u.last_name AS user_last_name,
            u.first_name || ' ' || u.last_name AS full_user_name,
            m.member_id,
            m.first_name AS member_first_name,
            m.last_name AS member_last_name,
            r.role_grade, -- Needed for filtering
            r.role_level  -- Needed for filtering
        FROM
            public.events e
        INNER JOIN
            public.teams t ON e.team_id = t.team_id
        INNER JOIN
            public.member_team_link mtl ON t.team_id = mtl.team_id AND mtl.status = 'active'
        INNER JOIN
            public.members m ON mtl.member_id = m.member_id
        INNER JOIN
            public.user_member_link uml ON m.member_id = uml.member_id
        INNER JOIN
            public.users u ON uml.user_id = u.user_id
        LEFT JOIN
            public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        LEFT JOIN
            public.roles r ON mtrl.role_id = r.role_id
        WHERE
            e.event_id = event_id_param
    ),
    -- 2. CTE: Find the latest attendance response for each distinct event-member combination.
    -- This identifies the member's CURRENT status.
    latest_member_event_attendance AS (
        SELECT
            ea.event_id,
            ea.member_id,
            ea.response_id,
            ROW_NUMBER() OVER (
                PARTITION BY ea.event_id, ea.member_id
                ORDER BY ea.created_at DESC
            ) AS rn
        FROM
            public.event_attendance ea
        WHERE
            ea.event_id = event_id_param
    )
    SELECT
        jsonb_build_object(
            'email', atm.email_address,
            'team_name', atm.team_name,
            'event_title', atm.event_title,
            'event_date_time', atm.event_date_time,
            'full_name', atm.full_user_name,
            'first_name', atm.user_first_name,
            'last_name', atm.user_last_name,
            'member_first_name', atm.member_first_name,
            'member_last_name', atm.member_last_name
        )
    FROM
        all_team_members atm -- Step 1: Start with ALL members
    LEFT JOIN
        latest_member_event_attendance lmea
        ON atm.event_id = lmea.event_id
        AND atm.member_id = lmea.member_id
        AND lmea.rn = 1 -- Only join the latest response status (Step 2 Prep)
    WHERE
        -- Filter 1: Check for members who are UNRESPONDED (latest status is NULL or 0)
        (lmea.response_id IS NULL OR lmea.response_id = 0)
        -- Filter 2: Conditional Role Grade filter (exact match if provided)
        AND (p_role_grade IS NULL OR atm.role_grade = p_role_grade)
        -- Filter 3: Conditional Role Level filter (minimum level if provided)
        AND (p_role_level IS NULL OR atm.role_level >= p_role_level);
END;
$$;
