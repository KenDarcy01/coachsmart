-- Adds primary_colour and secondary_colour (from clubs) to each team
-- in the user_teams array returned by get_user_home_events.

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
        (COALESCE(u.first_name, '') <> '' AND EXISTS (SELECT 1 FROM user_roles)) AS user_onboarded,
        EXISTS (
            SELECT 1
            FROM user_roles ur_gaa
            JOIN public.teams t_gaa  ON ur_gaa.team_id = t_gaa.team_id
            JOIN public.clubs c_gaa  ON t_gaa.club_id  = c_gaa.club_id
            WHERE c_gaa.sport_id = 1
        ) AS is_gaa_member
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
        'is_gaa_member', ud.is_gaa_member,
        'user_team_count', (SELECT COUNT(DISTINCT team_id) + 1 FROM user_roles),
        'user_teams', (
            SELECT jsonb_agg(t) FROM (
                SELECT team_id, team_name, team_unique_code, profile_pic, team_female,
                       club_id, user_highest_role_on_team, primary_colour, secondary_colour, sort_order
                FROM (
                    SELECT 0::bigint, 'All Teams'::text, NULL::text, NULL::text, FALSE,
                           0::bigint, 0::smallint, NULL::text, NULL::text, 0
                    UNION ALL
                    SELECT t2.team_id, t2.team_name, t2.team_unique_code, t2.profile_pic,
                           t2.team_female, t2.club_id, ur2.user_highest_role_on_team,
                           c2.primary_colour, c2.secondary_colour, 1
                    FROM public.teams t2
                    JOIN user_roles ur2 ON t2.team_id = ur2.team_id
                    LEFT JOIN public.clubs c2 ON t2.club_id = c2.club_id
                ) teams_union(team_id, team_name, team_unique_code, profile_pic, team_female,
                              club_id, user_highest_role_on_team, primary_colour, secondary_colour, sort_order)
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
