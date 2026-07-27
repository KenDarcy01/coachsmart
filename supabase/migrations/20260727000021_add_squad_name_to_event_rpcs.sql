-- Add squad_name to event RPC responses alongside the existing squad_id.
-- Uses a correlated subquery — NULL when squad_id IS NULL (whole-team events).
-- Affects: get_user_home_events, get_user_events, get_single_user_event,
--          get_events_list.

-- ─── get_user_home_events ────────────────────────────────────────────────────

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
eligible_attendees AS (
    SELECT DISTINCT ue.event_id, mtl.member_id
    FROM upcoming_events ue
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
              AND msl.team_id   = ue.team_id
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
        (SELECT s.squad_name FROM public.squads s WHERE s.squad_id = ue.squad_id) AS squad_name,
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
            OR EXISTS (
                SELECT 1 FROM public.member_squad_link msl
                WHERE msl.member_id = m.member_id
                  AND msl.squad_id  = ue2.squad_id
                  AND msl.team_id   = ue2.team_id
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


-- ─── get_user_events ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_user_events(user_id_param uuid)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = 'public'
AS $$

WITH user_roles AS (
    SELECT
        mtl.team_id,
        MAX(r.role_level) AS user_highest_role_on_team
    FROM public.user_member_link AS uml
    JOIN public.member_team_link AS mtl ON uml.member_id = mtl.member_id
    JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.roles AS r ON mtrl.role_id = r.role_id
    WHERE uml.user_id = user_id_param
    GROUP BY mtl.team_id
),
user_max_any_role AS (
    SELECT MAX(user_highest_role_on_team) AS user_highest_role_on_any_team FROM user_roles
),
upcoming_events AS (
    SELECT
        e.*, t.team_name, t.team_female, t.club_id, et.event_type, ec.event_code,
        event_role.role_level AS event_role_level,
        to_char(e.event_date_time::timestamp, 'FMDay, DD Month, YYYY at HH24:MI') AS event_date_time_formatted,
        CASE
            WHEN t.team_female = TRUE AND e.event_title LIKE 'Hurling%' THEN
                CASE WHEN et.event_type = 'Match'
                    THEN CONCAT(REPLACE(e.event_title, 'Hurling', 'Camogie'), ' (', e.opposition, ')')
                    ELSE REPLACE(e.event_title, 'Hurling', 'Camogie')
                END
            WHEN et.event_type = 'Match' THEN CONCAT(e.event_title, ' (', e.opposition, ')')
            ELSE e.event_title
        END AS effective_event_title
    FROM public.events AS e
    JOIN public.teams AS t ON e.team_id = t.team_id
    JOIN public.event_types AS et ON e.event_type_id = et.event_type_id
    LEFT JOIN public.event_codes AS ec ON e.event_code_id = ec.code_id
    LEFT JOIN public.roles AS event_role ON e.audience_id = event_role.role_id
    WHERE e.event_date_time >= CURRENT_DATE
      AND e.team_id IN (SELECT ur.team_id FROM user_roles ur)
      AND e.status != 'deleted'
),
relevant_member AS (
    SELECT DISTINCT ON (ue.event_id)
        ue.event_id, m.member_id,
        m.first_name AS member_first_name, m.last_name AS member_last_name,
        r.role_level AS member_role_level, ue.event_role_level
    FROM upcoming_events AS ue
    JOIN public.user_member_link AS uml ON uml.user_id = user_id_param
    JOIN public.members AS m ON uml.member_id = m.member_id
    JOIN public.member_team_link AS mtl
        ON m.member_id = mtl.member_id AND mtl.team_id = ue.team_id
    LEFT JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
    LEFT JOIN public.roles AS r ON mtrl.role_id = r.role_id
    WHERE r.role_level >= ue.event_role_level
      AND (
        ue.squad_id IS NULL
        OR EXISTS (
            SELECT 1 FROM public.member_squad_link msl
            WHERE msl.member_id = m.member_id
              AND msl.squad_id  = ue.squad_id
              AND msl.team_id   = ue.team_id
        )
    )
    ORDER BY ue.event_id, r.role_level ASC, m.member_id ASC
),
all_team_members AS (
    SELECT ue.event_id, mtl.member_id
    FROM upcoming_events AS ue
    JOIN public.member_team_link AS mtl ON ue.team_id = mtl.team_id
    JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.roles AS r_member ON mtrl.role_id = r_member.role_id
    WHERE (
        (ue.event_role_level = 10 AND r_member.role_level = 10)
        OR (ue.event_role_level > 10 AND r_member.role_level >= ue.event_role_level)
    )
      AND (
        ue.squad_id IS NULL
        OR EXISTS (
            SELECT 1 FROM public.member_squad_link msl
            WHERE msl.member_id = mtl.member_id
              AND msl.squad_id  = ue.squad_id
              AND msl.team_id   = ue.team_id
        )
    )
    GROUP BY ue.event_id, mtl.member_id
),
latest_event_attendance AS (
    SELECT DISTINCT ON (ea_sub.member_id, ea_sub.event_id)
        ea_sub.event_id, ea_sub.member_id, ea_sub.response_id, ea_sub.attendance_id
    FROM public.event_attendance AS ea_sub
    JOIN upcoming_events AS ue ON ea_sub.event_id = ue.event_id
    JOIN all_team_members AS atm
        ON ea_sub.member_id = atm.member_id AND ea_sub.event_id = atm.event_id
    ORDER BY ea_sub.member_id, ea_sub.event_id, ea_sub.created_at DESC, ea_sub.attendance_id DESC
),
attendance_summary AS (
    SELECT
        atm.event_id,
        COUNT(CASE WHEN lea.response_id = 3 THEN atm.member_id END) AS accepted_count,
        COUNT(CASE WHEN lea.response_id = 4 THEN atm.member_id END) AS declined_count,
        COUNT(CASE WHEN lea.response_id IS NULL THEN atm.member_id END) AS no_response_count
    FROM all_team_members AS atm
    LEFT JOIN latest_event_attendance AS lea
        ON atm.member_id = lea.member_id AND atm.event_id = lea.event_id
    GROUP BY atm.event_id
)
SELECT
    COALESCE(json_agg(final_result)::jsonb, '[]'::jsonb)
FROM (
    SELECT
        ue.event_id, ue.effective_event_title AS event_title, ue.meet_time,
        ue.event_date_time_formatted, ue.team_name, ue.team_id, ue.club_id,
        ue.status AS event_status, ue.squad_id,
        (SELECT s.squad_name FROM public.squads s WHERE s.squad_id = ue.squad_id) AS squad_name,
        rm.member_id, lea_user.attendance_id,
        ert.display_value AS attendance_status, ert.icon_link AS attendance_icon,
        lea_user.response_id, ue.request_attendance, ue.event_type, ue.event_link,
        ue.event_code, ue.location_name, ue.location_pin, ue.opposition, ue.event_details,
        ue.home_away, ue.created_by,
        CONCAT(u.first_name, ' ', u.last_name) AS created_by_user_name,
        u.phone_number AS created_by_phone_number,
        rm.member_first_name, rm.member_last_name, rm.member_role_level, rm.event_role_level,
        COALESCE(asum.accepted_count, 0) AS accepted_count,
        COALESCE(asum.declined_count, 0) AS declined_count,
        COALESCE(asum.no_response_count, 0) AS no_response_count,
        ur.user_highest_role_on_team, umr.user_highest_role_on_any_team,
        ue.notify_admins_changes, ue.notify_admins_all
    FROM upcoming_events AS ue
    LEFT JOIN user_roles AS ur ON ue.team_id = ur.team_id
    CROSS JOIN user_max_any_role AS umr
    LEFT JOIN public.users AS u ON ue.created_by = u.user_id
    LEFT JOIN relevant_member AS rm ON ue.event_id = rm.event_id
    LEFT JOIN latest_event_attendance AS lea_user
        ON lea_user.member_id = rm.member_id AND lea_user.event_id = ue.event_id
    LEFT JOIN public.event_response_type AS ert ON lea_user.response_id = ert.response_id
    LEFT JOIN attendance_summary AS asum ON ue.event_id = asum.event_id
    WHERE rm.member_id IS NOT NULL
    ORDER BY ue.event_date_time ASC
) AS final_result;
$$;


-- ─── get_single_user_event ───────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_single_user_event(p_user_id uuid, p_event_id bigint)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = 'public'
AS $$

WITH user_roles AS (
    SELECT
        mtl.team_id, t.show_advert,
        MAX(r.role_level) AS user_highest_role_on_team
    FROM public.user_member_link AS uml
    JOIN public.member_team_link AS mtl ON uml.member_id = mtl.member_id
    JOIN public.teams AS t ON mtl.team_id = t.team_id
    JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.roles AS r ON mtrl.role_id = r.role_id
    WHERE uml.user_id = p_user_id
    GROUP BY mtl.team_id, t.show_advert
),
target_event AS (
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
    WHERE e.event_id = p_event_id
      AND e.status != 'deleted'
),
eligible_attendees AS (
    SELECT DISTINCT te.event_id, mtl.member_id
    FROM target_event te
    JOIN public.member_team_link mtl ON te.team_id = mtl.team_id
    JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.roles r_member ON mtrl.role_id = r_member.role_id
    WHERE (
        (te.event_role_level > 10 AND r_member.role_level >= te.event_role_level)
        OR (te.event_role_level = 10 AND r_member.role_level = 10)
        OR (te.event_role_level = 0 OR te.event_role_level IS NULL)
    )
      AND (
        te.squad_id IS NULL
        OR EXISTS (
            SELECT 1 FROM public.member_squad_link msl
            WHERE msl.member_id = mtl.member_id
              AND msl.squad_id  = te.squad_id
              AND msl.team_id   = te.team_id
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
final_event_data AS (
    SELECT
        te.event_id, te.effective_event_title AS event_title, te.meet_time,
        te.event_date_time_formatted, te.team_name, te.team_id, te.club_id,
        te.status AS event_status, te.squad_id,
        (SELECT s.squad_name FROM public.squads s WHERE s.squad_id = te.squad_id) AS squad_name,
        rm.member_id, lar_user.attendance_id,
        ert.display_value AS attendance_status, ert.icon_link AS attendance_icon,
        lar_user.response_id, te.request_attendance, te.event_type, te.event_link,
        te.event_code, te.location_name, te.location_pin, te.opposition, te.event_details,
        te.home_away, te.created_by,
        CONCAT(u.first_name, ' ', u.last_name) AS created_by_user_name,
        u.phone_number AS created_by_phone_number,
        rm.member_first_name, rm.member_last_name, rm.member_role_level, rm.event_role_level,
        COALESCE(asum.accepted_count, 0) AS accepted_count,
        COALESCE(asum.declined_count, 0) AS declined_count,
        COALESCE(asum.no_response_count, 0) AS no_response_count,
        ur.user_highest_role_on_team, te.notify_admins_changes, te.notify_admins_all,
        te.payment_required,
        COALESCE((
            SELECT TRUE FROM public.event_user_member_payment eup
            WHERE eup.event_id = te.event_id AND eup.user_id = p_user_id
              AND eup.payment_status = 'confirmed' LIMIT 1
        ), FALSE) AS event_paid
    FROM target_event AS te
    LEFT JOIN user_roles AS ur ON te.team_id = ur.team_id
    LEFT JOIN public.users AS u ON te.created_by = u.user_id
    LEFT JOIN (
        SELECT DISTINCT ON (te2.event_id)
            te2.event_id, m.member_id,
            m.first_name AS member_first_name, m.last_name AS member_last_name,
            r.role_level AS member_role_level, te2.event_role_level
        FROM target_event AS te2
        JOIN public.user_member_link AS uml ON uml.user_id = p_user_id
        JOIN public.members AS m ON uml.member_id = m.member_id
        JOIN public.member_team_link AS mtl
            ON m.member_id = mtl.member_id AND mtl.team_id = te2.team_id
        JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN public.roles AS r ON mtrl.role_id = r.role_id
        WHERE r.role_level >= te2.event_role_level
          AND (
            te2.squad_id IS NULL
            OR EXISTS (
                SELECT 1 FROM public.member_squad_link msl
                WHERE msl.member_id = m.member_id
                  AND msl.squad_id  = te2.squad_id
                  AND msl.team_id   = te2.team_id
            )
        )
        ORDER BY te2.event_id, r.role_level ASC
    ) AS rm ON te.event_id = rm.event_id
    LEFT JOIN latest_attendance_records AS lar_user
        ON lar_user.member_id = rm.member_id AND lar_user.event_id = te.event_id
    LEFT JOIN public.event_response_type AS ert ON lar_user.response_id = ert.response_id
    LEFT JOIN attendance_summary AS asum ON te.event_id = asum.event_id
    WHERE rm.member_id IS NOT NULL
)
SELECT
    COALESCE(
        (SELECT jsonb_agg(fed) FROM final_event_data fed),
        '[]'::jsonb
    );
$$;


-- ─── get_events_list (admin) ─────────────────────────────────────────────────

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
    JOIN public.member_team_link AS mtl ON fe.team_id = mtl.team_id
    JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.roles AS r_member ON mtrl.role_id = r_member.role_id
    WHERE (
        (fe.event_role_level = 10 AND r_member.role_level = 10)
        OR (fe.event_role_level > 10 AND r_member.role_level >= fe.event_role_level)
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
        (SELECT s.squad_name FROM public.squads s WHERE s.squad_id = fe.squad_id) AS squad_name,
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
