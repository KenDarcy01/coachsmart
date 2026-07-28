-- Fix bare member_squad_link EXISTS checks that matched any historical
-- squad record (no code_id filter). This caused members who were formerly
-- in a squad to be counted even after being moved to a different squad.
--
-- Fix: resolve the effective code_id via get_updated_event_code() and
-- add AND msl.code_id = <effective_code_id> to every squad filter.
--
-- get_user_home_events  — stays SQL, adds event_effective_codes CTE
-- get_user_event_details — converted sql → plpgsql to support DECLARE


-- ─── get_user_home_events ─────────────────────────────────────────────────────

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
    JOIN public.member_team_link AS mtl ON uml.member_id = mtl.member_id
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
    WHERE e.event_date_time >= CURRENT_DATE
      AND e.status != 'deleted'
),
event_effective_codes AS (
    -- Resolve effective squad code_id once per squad-scoped event.
    -- Used to filter member_squad_link to the current configuration only.
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
    JOIN public.member_team_link mtl ON ue.team_id = mtl.team_id
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
        ue.status AS event_status, ue.squad_id,
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
        JOIN public.member_team_link AS mtl ON m.member_id = mtl.member_id AND mtl.team_id = ue2.team_id
        JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN public.roles AS r ON mtrl.role_id = r.role_id
        WHERE r.role_level >= ue2.event_role_level
          AND (
            ue2.squad_id IS NULL
            OR r.role_grade = 100
            OR EXISTS (
                SELECT 1 FROM public.member_squad_link msl
                WHERE msl.member_id = m.member_id
                  AND msl.squad_id  = ue2.squad_id
                  AND msl.code_id   = public.get_updated_event_code(ue2.event_id)
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


-- ─── get_user_event_details ──────────────────────────────────────────────────
-- Converted from LANGUAGE sql to plpgsql so v_effective_code_id can be
-- resolved once and reused in the categorized_eligible_members EXISTS check.

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
