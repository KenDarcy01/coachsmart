-- Migration: 20260728000017_uml_status_rpc_filters.sql
--
-- Adds AND uml.status = 'active' to every JOIN/FROM on user_member_link
-- (alias uml) in the six RPCs below. The user_member_link.status column was
-- added in 20260728000016; rows inserted by request_member_access() default
-- to 'pending' and must not grant data visibility until an admin confirms
-- access (confirm_user_member_access sets status = 'active').
--
-- Placement rule: for INNER JOINs the filter is added to the ON clause;
-- for FROM-leading (no ON) the filter is added to the WHERE clause.
--
-- Functions updated (all other function attributes are unchanged):
--
--   get_user_home_events          user_roles CTE FROM/WHERE + rm subquery JOIN ON
--   get_user_event_details        event_team_members CTE INNER JOIN ON
--   get_user_team_summary         both FROM uml blocks in WHERE
--   get_unresponded_events        JOIN uml ON in main query
--   get_unresponded_events_v2     INNER JOIN uml ON in all_team_members CTE
--   notify_admins_attendance_change  STEP 2b FROM/WHERE, STEP 6 JOIN ON,
--                                    admin_users CTE JOIN ON


-- ─── get_user_home_events ─────────────────────────────────────────────────────
-- Changes: uml.status = 'active' added to
--   1. user_roles CTE WHERE clause
--   2. rm subquery JOIN ON condition

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
      AND uml.status = 'active'
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
        JOIN public.user_member_link AS uml ON uml.user_id = p_user_id AND uml.status = 'active'
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


-- ─── get_user_event_details ───────────────────────────────────────────────────
-- Change: event_team_members CTE INNER JOIN ON uml gains AND uml.status = 'active'

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
        INNER JOIN public.user_member_link AS uml ON m.member_id = uml.member_id AND uml.status = 'active'
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


-- ─── get_user_team_summary ───────────────────────────────────────────────────
-- Changes: both FROM uml blocks gain AND uml.status = 'active' in their WHERE

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
    WHERE uml.user_id = p_user_id
      AND uml.status = 'active';

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
          AND uml.status = 'active'
        ORDER BY t.team_id, r.role_level DESC
    ) t_final;

    RETURN jsonb_build_object(
        'overall_highest_role_level', COALESCE(v_overall_highest, 0),
        'teams', COALESCE(v_teams_json, '[]'::jsonb)
    );
END;
$$;


-- ─── get_unresponded_events ───────────────────────────────────────────────────
-- Change: JOIN uml ON gains AND uml.status = 'active'

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
  JOIN public.user_member_link uml ON uml.member_id = m.member_id AND uml.status = 'active'
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
-- Change: INNER JOIN uml ON in all_team_members CTE gains AND uml.status = 'active'

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
            public.user_member_link uml ON m.member_id = uml.member_id AND uml.status = 'active'
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


-- ─── notify_admins_attendance_change ─────────────────────────────────────────
-- Changes: uml.status = 'active' added to
--   1. STEP 2b FROM uml WHERE clause (actor user_id resolution)
--   2. STEP 6 admin-count query JOIN uml ON
--   3. STEP 7 admin_users CTE JOIN uml ON

CREATE OR REPLACE FUNCTION "public"."notify_admins_attendance_change"("p_event_id_param" integer, "p_member_id_param" integer, "p_response_id" integer, "p_attendance_id" bigint) RETURNS TABLE("notifications_created" integer)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET search_path = 'public'
    AS $$
DECLARE
    created_count         INT := 0;
    v_logo_url            TEXT := 'https://gyfporsbdftvtakdvukt.supabase.co/storage/v1/object/sign/coachsmartimages/CoachSmart%20Logo%20Transparent.png?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV82OTA4NmRkYy01MWQ3LTQ1NzUtYWYwMC1mZjQxYmMyNDU2YWMiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJjb2FjaHNtYXJ0aW1hZ2VzL0NvYWNoU21hcnQgTG9nbyBUcmFuc3BhcmVudC5wbmciLCJpYXQiOjE3NzQ2MDYzOTksImV4cCI6MjYzODYwNjM5OX0.20yMzSYnG08kYjMK6cmGMvwA6VPGvm9_yHG-CmEfSIs';
    v_notify_all          BOOLEAN;
    v_notify_changes      BOOLEAN;
    v_prev_response_id    BIGINT;
    v_is_change_of_mind   BOOLEAN := false;
    v_response_word       TEXT;
    v_prev_response_word  TEXT;
    v_response_colour     TEXT;
    v_prev_response_colour TEXT;
    v_badge_label         TEXT;
    v_admin_count         INT := 0;
    v_event_exists        BOOLEAN := false;
    v_member_exists       BOOLEAN := false;
    v_actor_user_id       UUID;
BEGIN

    RAISE NOTICE '=== notify_admins_attendance_change START ===';
    RAISE NOTICE 'Inputs: p_event_id_param=%, p_member_id_param=%, p_response_id=%, p_attendance_id=%',
        p_event_id_param, p_member_id_param, p_response_id, p_attendance_id;

    -- -------------------------------------------------------------------------
    -- STEP 1: Check event exists and read notification flags
    -- -------------------------------------------------------------------------
    SELECT
        true,
        COALESCE(notify_admins_all, false),
        COALESCE(notify_admins_changes, false)
    INTO v_event_exists, v_notify_all, v_notify_changes
    FROM public.events
    WHERE event_id = p_event_id_param;

    IF NOT v_event_exists THEN
        RAISE NOTICE 'EXIT: Event % not found', p_event_id_param;
        RETURN QUERY SELECT 0;
        RETURN;
    END IF;

    RAISE NOTICE 'Event found: notify_admins_all=%, notify_admins_changes=%', v_notify_all, v_notify_changes;

    IF NOT v_notify_all AND NOT v_notify_changes THEN
        RAISE NOTICE 'EXIT: Both notification flags are false/null — nothing to do';
        RETURN QUERY SELECT 0;
        RETURN;
    END IF;

    -- -------------------------------------------------------------------------
    -- STEP 2: Check member exists
    -- -------------------------------------------------------------------------
    SELECT true INTO v_member_exists
    FROM public.members
    WHERE member_id = p_member_id_param;

    IF NOT v_member_exists THEN
        RAISE NOTICE 'EXIT: Member % not found', p_member_id_param;
        RETURN QUERY SELECT 0;
        RETURN;
    END IF;

    RAISE NOTICE 'Member % found', p_member_id_param;

    -- -------------------------------------------------------------------------
    -- STEP 2b: Resolve the actor's user_id so we can exclude them regardless
    --          of which member record they hold an admin role under.
    -- -------------------------------------------------------------------------
    SELECT uml.user_id INTO v_actor_user_id
    FROM public.user_member_link uml
    WHERE uml.member_id = p_member_id_param
      AND uml.status = 'active'
    LIMIT 1;

    RAISE NOTICE 'Actor user_id resolved: %', v_actor_user_id;

    -- -------------------------------------------------------------------------
    -- STEP 3: Look up previous attendance record (strictly before p_attendance_id)
    -- -------------------------------------------------------------------------
    SELECT response_id
    INTO v_prev_response_id
    FROM public.event_attendance
    WHERE event_id    = p_event_id_param
      AND member_id   = p_member_id_param
      AND attendance_id < p_attendance_id
    ORDER BY attendance_id DESC
    LIMIT 1;

    RAISE NOTICE 'Previous attendance lookup: attendance_id < % → prev_response_id=%',
        p_attendance_id, v_prev_response_id;

    -- -------------------------------------------------------------------------
    -- STEP 4: Apply flag logic gate
    -- -------------------------------------------------------------------------
    IF NOT v_notify_all AND v_notify_changes THEN
        RAISE NOTICE 'Mode: notify_changes only — checking for genuine change of mind';
        IF v_prev_response_id IS NULL THEN
            RAISE NOTICE 'EXIT: No previous response found — first time responding, skipping';
            RETURN QUERY SELECT 0;
            RETURN;
        END IF;
        IF v_prev_response_id = p_response_id THEN
            RAISE NOTICE 'EXIT: Previous response (%) = current response (%) — no change of mind, skipping',
                v_prev_response_id, p_response_id;
            RETURN QUERY SELECT 0;
            RETURN;
        END IF;
        v_is_change_of_mind := true;
        RAISE NOTICE 'Change of mind confirmed: % → %', v_prev_response_id, p_response_id;
    END IF;

    IF v_notify_all THEN
        RAISE NOTICE 'Mode: notify_all — will create notification regardless';
        IF v_prev_response_id IS NOT NULL AND v_prev_response_id <> p_response_id THEN
            v_is_change_of_mind := true;
            RAISE NOTICE 'Also a change of mind: % → %', v_prev_response_id, p_response_id;
        END IF;
    END IF;

    -- -------------------------------------------------------------------------
    -- STEP 5: Resolve messaging variables
    -- -------------------------------------------------------------------------
    v_response_word := CASE p_response_id
        WHEN 3 THEN 'accepted'
        WHEN 4 THEN 'declined'
        ELSE        'updated'
    END;

    v_prev_response_word := CASE v_prev_response_id
        WHEN 3 THEN 'accepted'
        WHEN 4 THEN 'declined'
        ELSE        'updated'
    END;

    v_response_colour := CASE p_response_id
        WHEN 3 THEN '#87C232'
        WHEN 4 THEN '#e05252'
        ELSE        '#e7ebee'
    END;

    v_prev_response_colour := CASE v_prev_response_id
        WHEN 3 THEN '#87C232'
        WHEN 4 THEN '#e05252'
        ELSE        '#e7ebee'
    END;

    v_badge_label := CASE
        WHEN v_is_change_of_mind THEN 'CHANGE OF ATTENDANCE'
        WHEN p_response_id = 3   THEN 'ATTENDANCE ACCEPTED'
        WHEN p_response_id = 4   THEN 'ATTENDANCE DECLINED'
        ELSE                          'ATTENDANCE UPDATED'
    END;

    RAISE NOTICE 'Messaging: response_word=%, prev_response_word=%, badge_label=%, is_change_of_mind=%',
        v_response_word, v_prev_response_word, v_badge_label, v_is_change_of_mind;

    -- -------------------------------------------------------------------------
    -- STEP 6: Check admin count before attempting insert (excluding actor by user_id)
    -- -------------------------------------------------------------------------
    SELECT COUNT(DISTINCT u.user_id)
    INTO v_admin_count
    FROM public.member_team_link mtl
    JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.members m                  ON mtl.member_id = m.member_id
    JOIN public.user_member_link uml       ON m.member_id = uml.member_id AND uml.status = 'active'
    JOIN public.users u                    ON uml.user_id = u.user_id
    JOIN public.events e                   ON e.team_id = mtl.team_id
    WHERE e.event_id = p_event_id_param
      AND mtrl.role_id = 7
      AND u.user_id != v_actor_user_id;

    RAISE NOTICE 'Admin users found for team (excluding actor user_id=%): %', v_actor_user_id, v_admin_count;

    IF v_admin_count = 0 THEN
        RAISE NOTICE 'WARN: No other admin users (role_id=7) found for this team — no notifications will be created';
    END IF;

    -- -------------------------------------------------------------------------
    -- STEP 7: Insert one notification record per team admin (excluding actor by user_id)
    -- -------------------------------------------------------------------------
    RAISE NOTICE 'Proceeding with INSERT...';

    INSERT INTO public.notifications (
        recipient_user_id,
        team_id,
        event_id,
        link_page,
        is_delivered,
        is_read,
        delivery_method,
        created_at,
        push_title,
        push_body,
        email_title,
        email_body,
        app_title,
        app_body
    )
    WITH target_event AS (
        SELECT
            e.event_id,
            e.event_date_time,
            e.team_id,
            t.team_name,
            CASE
                WHEN e.event_title IS NOT NULL AND e.event_title <> '' THEN e.event_title
                ELSE (
                    CASE
                        WHEN t.team_female = true AND ec.code_id = 3 THEN 'Camogie'
                        ELSE COALESCE(ec.event_code, '')
                    END || ' ' ||
                    COALESCE(et.event_type, '') ||
                    CASE
                        WHEN et.event_type_id = 2
                         AND e.opposition IS NOT NULL
                         AND e.opposition <> ''
                        THEN ' - ' || e.opposition
                        ELSE ''
                    END
                )
            END AS display_title,
            trim(to_char(e.event_date_time, 'Day, Mon DD, YYYY "at" HH24:MI')) AS date_time_formatted
        FROM public.events e
        JOIN public.teams t ON e.team_id = t.team_id
        LEFT JOIN public.event_codes ec ON e.event_code_id = ec.code_id
        LEFT JOIN public.event_types et ON e.event_type_id = et.event_type_id
        WHERE e.event_id = p_event_id_param
    ),
    changing_member AS (
        SELECT
            COALESCE(
                NULLIF(trim(m.first_name || ' ' || COALESCE(m.last_name, '')), ''),
                'A member'
            ) AS full_name
        FROM public.members m
        WHERE m.member_id = p_member_id_param
    ),
    admin_users AS (
        SELECT DISTINCT
            u.user_id,
            u.first_name AS user_fname,
            u.fcm_token
        FROM target_event te
        JOIN public.member_team_link mtl       ON te.team_id = mtl.team_id
        JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN public.members m                  ON mtl.member_id = m.member_id
        JOIN public.user_member_link uml       ON m.member_id = uml.member_id AND uml.status = 'active'
        JOIN public.users u                    ON uml.user_id = u.user_id
        WHERE mtrl.role_id = 7
          AND u.user_id != v_actor_user_id  -- exclude the user who made the change (by user_id, handles multiple member records)
    )
    SELECT
        au.user_id,
        te.team_id,
        te.event_id,

        'coachsmartv2://coachsmartv2.com/eventDetails?eventID=' || te.event_id::text || '&fromSearch=false',

        false,  -- is_delivered

        -- is_read: true for email (user sees it in inbox), false for push (requires app interaction)
        CASE
            WHEN au.fcm_token IS NOT NULL AND au.fcm_token <> '' THEN false
            ELSE true
        END,

        CASE
            WHEN au.fcm_token IS NOT NULL AND au.fcm_token <> '' THEN 'push'
            ELSE 'email'
        END,

        NOW(),

        -- push_title
        te.team_name || ': Change of Attendance',

        -- push_body
        CASE
            WHEN v_is_change_of_mind THEN
                cm.full_name || ' has changed their attendance from ' ||
                v_prev_response_word || ' to ' || v_response_word || ' for ' ||
                trim(te.display_title) || ' on ' || te.date_time_formatted
            ELSE
                cm.full_name || ' has ' || v_response_word || ' attendance for ' ||
                trim(te.display_title) || ' on ' || te.date_time_formatted
        END,

        -- email_title
        CASE
            WHEN v_is_change_of_mind THEN
                te.team_name || ': Change of Attendance — ' || cm.full_name
            ELSE
                te.team_name || ': ' ||
                CASE p_response_id
                    WHEN 3 THEN 'Attendance Accepted'
                    WHEN 4 THEN 'Attendance Declined'
                    ELSE        'Attendance Updated'
                END || ' — ' || cm.full_name
        END,

        -- email_body HTML
        '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>CoachSmart</title></head>' ||
        '<body style="margin:0;padding:0;background-color:#111418;font-family:Arial,Helvetica,sans-serif;">' ||
        '<table width="100%" cellpadding="0" cellspacing="0" style="padding:40px 20px;"><tr><td align="center">' ||
        '<table width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background-color:#212529;border-radius:16px;overflow:hidden;border:1px solid #3a3f4b;">' ||

        -- Header
        '<tr><td style="background-color:#1E222B;padding:28px 24px;text-align:center;border-bottom:3px solid #87C232;">' ||
        '<table cellpadding="0" cellspacing="0" style="margin:0 auto;"><tr>' ||
        '<td style="padding-right:16px;vertical-align:middle;">' ||
        '<img src="' || v_logo_url || '" alt="CoachSmart" width="80" style="display:block;height:auto;border:0;"></td>' ||
        '<td style="vertical-align:middle;text-align:left;">' ||
        '<p style="margin:0;font-size:26px;font-weight:900;letter-spacing:2.5px;line-height:1;font-family:Arial,Helvetica,sans-serif;">' ||
        '<span style="color:#c8ccd0;">COACH</span><span style="color:#87C232;">SMART</span></p>' ||
        '<p style="margin:5px 0 0 0;font-size:9px;font-weight:700;letter-spacing:4px;color:#87C232;font-family:Arial,Helvetica,sans-serif;">COACHING&nbsp;&nbsp;MADE&nbsp;&nbsp;SIMPLE</p>' ||
        '</td></tr></table></td></tr>' ||

        -- Body
        '<tr><td style="padding:28px 28px 24px;">' ||
        '<p style="margin:0 0 6px 0;font-size:15px;color:#e7ebee;font-family:Arial,Helvetica,sans-serif;">Hi ' || au.user_fname || ',</p>' ||

        CASE
            WHEN v_is_change_of_mind THEN
                '<p style="margin:0 0 20px 0;font-size:14px;color:#a3a3a3;line-height:1.6;font-family:Arial,Helvetica,sans-serif;">' ||
                '<strong style="color:#e7ebee;">' || cm.full_name || '</strong> has changed their attendance from ' ||
                '<strong style="color:' || v_prev_response_colour || ';">' || v_prev_response_word || '</strong>' ||
                ' to <strong style="color:' || v_response_colour || ';">' || v_response_word || '</strong> for the following event:</p>'
            ELSE
                '<p style="margin:0 0 20px 0;font-size:14px;color:#a3a3a3;line-height:1.6;font-family:Arial,Helvetica,sans-serif;">' ||
                '<strong style="color:#e7ebee;">' || cm.full_name || '</strong> has <strong style="color:' || v_response_colour || ';">' || v_response_word || '</strong> attendance for the following event:</p>'
        END ||

        -- Event card
        '<table width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 22px 0;"><tr>' ||
        '<td style="background:#2c313a;border-left:3px solid #87C232;padding:16px 18px;border-radius:0 8px 8px 0;">' ||
        '<p style="margin:0 0 5px 0;color:#e7ebee;font-size:15px;font-weight:700;font-family:Arial,Helvetica,sans-serif;">' || trim(te.display_title) || '</p>' ||
        '<p style="margin:0;color:#a3a3a3;font-size:13px;font-family:Arial,Helvetica,sans-serif;">' || te.date_time_formatted || '</p>' ||
        '</td></tr></table>' ||

        -- Status badge
        '<table width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 4px 0;"><tr>' ||
        '<td style="background:#2c313a;border-radius:8px;padding:16px 18px;border:1px solid #3a3f4b;">' ||
        '<p style="margin:0 0 4px 0;font-size:13px;font-weight:700;color:#87C232;font-family:Arial,Helvetica,sans-serif;letter-spacing:0.5px;">' || v_badge_label || '</p>' ||
        '<p style="margin:0;font-size:13px;color:#a3a3a3;line-height:1.6;font-family:Arial,Helvetica,sans-serif;">' ||
        CASE
            WHEN v_is_change_of_mind THEN
                cm.full_name || ' has changed their mind. You may wish to review your squad in the CoachSmart app.'
            ELSE
                cm.full_name || ' has ' || v_response_word || ' their attendance. You may wish to review your squad in the CoachSmart app.'
        END ||
        '</p></td></tr></table>' ||

        '</td></tr>' ||

        -- Footer
        '<tr><td style="padding:16px 28px;border-top:1px solid #3a3f4b;text-align:center;">' ||
        '<p style="margin:0 0 4px 0;font-size:11px;color:#555;letter-spacing:1.5px;font-family:Arial,Helvetica,sans-serif;">COACHSMART &middot; COACHING MADE SIMPLE</p>' ||
        '<p style="margin:0;font-size:11px;color:#444;font-family:Arial,Helvetica,sans-serif;">You received this because you are a team admin on CoachSmart.</p>' ||
        '</td></tr>' ||

        '</table></td></tr></table></body></html>',

        -- app_title
        CASE
            WHEN v_is_change_of_mind THEN
                'Change of Attendance — ' || cm.full_name
            ELSE
                CASE p_response_id
                    WHEN 3 THEN 'Attendance Accepted'
                    WHEN 4 THEN 'Attendance Declined'
                    ELSE        'Attendance Updated'
                END || ' — ' || cm.full_name
        END,

        -- app_body
        CASE
            WHEN v_is_change_of_mind THEN
                cm.full_name || ' has changed their attendance from ' ||
                v_prev_response_word || ' to ' || v_response_word || ' for ' ||
                trim(te.display_title) || ' on ' || te.date_time_formatted
            ELSE
                cm.full_name || ' has ' || v_response_word || ' attendance for ' ||
                trim(te.display_title) || ' on ' || te.date_time_formatted
        END

    FROM admin_users au
    CROSS JOIN target_event te
    CROSS JOIN changing_member cm;

    GET DIAGNOSTICS created_count = ROW_COUNT;

    RAISE NOTICE 'INSERT complete: % notification row(s) created', created_count;
    RAISE NOTICE '=== notify_admins_attendance_change END ===';

    RETURN QUERY SELECT created_count;
END;
$$;
