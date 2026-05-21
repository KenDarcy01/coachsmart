-- Enforce caller identity on all SECURITY DEFINER functions that accept a user_id parameter.
-- Previously these functions trusted the caller-supplied p_user_id without verification,
-- meaning any authenticated user could query another user's data by passing a different UUID.
-- Fix: replace p_user_id/user_id_param with auth.uid() in every function body.
-- Function signatures are unchanged so no app changes are required.
-- Safe to apply to a live database — no schema changes, only function body rewrites.

CREATE OR REPLACE FUNCTION "public"."get_user_events"("user_id_param" "uuid") RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET search_path = 'public'
AS $$

WITH user_roles AS (
    -- Pre-calculate the user's highest role on each team they are a member of
    -- (This eliminates correlated subqueries for user roles)
    SELECT
        mtl.team_id,
        MAX(r.role_level) AS user_highest_role_on_team
    FROM
        public.user_member_link AS uml
    JOIN
        public.member_team_link AS mtl ON uml.member_id = mtl.member_id
    JOIN
        public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN
        public.roles AS r ON mtrl.role_id = r.role_id
    WHERE
        uml.user_id = auth.uid()
    GROUP BY
        mtl.team_id
),
user_max_any_role AS (
    -- Calculate the user's single highest role across ALL teams once
    SELECT
        MAX(user_highest_role_on_team) AS user_highest_role_on_any_team
    FROM
        user_roles
),
upcoming_events AS (
    -- Filter and pre-process event data, including event role level.
    SELECT
        e.*,
        t.team_name,
        t.team_female,
        t.club_id, -- ADDED: Select club_id from the teams table
        et.event_type,
        ec.event_code,
        event_role.role_level AS event_role_level,
        to_char(e.event_date_time::timestamp, 'FMDay, DD Month, YYYY at HH24:MI') AS event_date_time_formatted,
        -- START MODIFIED LOGIC for effective_event_title
        CASE
            -- 1. Check for Gender Substitution (Hurling/Camogie)
            WHEN t.team_female = TRUE AND e.event_title LIKE 'Hurling%' THEN
                -- Apply Gender Substitution first
                CASE
                    -- 2. Check if the newly-substituted title should include Opposition
                    WHEN et.event_type = 'Match' THEN 
                        CONCAT(REPLACE(e.event_title, 'Hurling', 'Camogie'), ' (', e.opposition, ')')
                    ELSE 
                        REPLACE(e.event_title, 'Hurling', 'Camogie')
                END
            -- 3. If no Gender Substitution needed, apply Opposition logic directly
            WHEN et.event_type = 'Match' THEN 
                CONCAT(e.event_title, ' (', e.opposition, ')')
            -- 4. Default case: use the original title
            ELSE e.event_title
        END AS effective_event_title
        -- END MODIFIED LOGIC
    FROM
        public.events AS e
    JOIN
        public.teams AS t ON e.team_id = t.team_id
    JOIN
        public.event_types AS et ON e.event_type_id = et.event_type_id
    LEFT JOIN
        public.event_codes AS ec ON e.event_code_id = ec.code_id
    LEFT JOIN
        public.roles AS event_role ON e.audience_id = event_role.role_id
    WHERE
        e.event_date_time >= CURRENT_DATE
        -- Early filtering to only include events for the user's teams
        AND e.team_id IN (SELECT ur.team_id FROM user_roles ur)
),
relevant_member AS (
    -- Identify the single 'most relevant' member (lowest role_level, then lowest member_id)
    -- linked to the user for each upcoming event's team, ensuring their role meets the event's audience level.
    SELECT DISTINCT ON (ue.event_id)
        ue.event_id,
        m.member_id,
        m.first_name AS member_first_name,
        m.last_name AS member_last_name,
        r.role_level AS member_role_level,
        ue.event_role_level
    FROM
        upcoming_events AS ue
    JOIN
        public.user_member_link AS uml ON uml.user_id = auth.uid()
    JOIN
        public.members AS m ON uml.member_id = m.member_id
    JOIN
        public.member_team_link AS mtl ON m.member_id = mtl.member_id AND mtl.team_id = ue.team_id
    LEFT JOIN
        public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
    LEFT JOIN
        public.roles AS r ON mtrl.role_id = r.role_id
    WHERE
        -- Logic for the *user's* eligibility (must meet or exceed the audience role)
        r.role_level >= ue.event_role_level
    ORDER BY
        ue.event_id, r.role_level ASC, m.member_id ASC
),
all_team_members AS (
    -- **CRITICAL FIX:** Select all members eligible for the attendance summary count.
    -- This CTE implements the complex role-level filtering logic from the original EXISTS clause.
    SELECT
        ue.event_id,
        mtl.member_id
    FROM
        upcoming_events AS ue
    JOIN
        public.member_team_link AS mtl ON ue.team_id = mtl.team_id
    JOIN
        public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN
        public.roles AS r_member ON mtrl.role_id = r_member.role_id
    WHERE
        (
            -- Original complex logic:
            -- If event role is 10 (Player), only count members whose role is exactly 10
            (ue.event_role_level = 10 AND r_member.role_level = 10)
            -- If event role is > 10, count members whose role is >= event role
            OR (ue.event_role_level > 10 AND r_member.role_level >= ue.event_role_level)
        )
    GROUP BY
        ue.event_id, mtl.member_id
),
latest_event_attendance AS (
    -- Calculate the latest attendance response for ALL relevant members on ALL upcoming events once
    -- (This eliminates redundant window function calls)
    SELECT DISTINCT ON (ea_sub.member_id, ea_sub.event_id)
        ea_sub.event_id,
        ea_sub.member_id,
        ea_sub.response_id,
        ea_sub.attendance_id
    FROM
        public.event_attendance AS ea_sub
    JOIN
        upcoming_events AS ue ON ea_sub.event_id = ue.event_id
    -- Only check attendance for members identified as relevant for the count
    JOIN
        all_team_members AS atm ON ea_sub.member_id = atm.member_id AND ea_sub.event_id = atm.event_id
    ORDER BY
        ea_sub.member_id, ea_sub.event_id, ea_sub.created_at DESC, ea_sub.attendance_id DESC
),
attendance_summary AS (
    -- Calculate the accepted, declined, and no-response counts for each event
    SELECT
        atm.event_id,
        COUNT(CASE WHEN lea.response_id = 3 THEN atm.member_id END) AS accepted_count,
        COUNT(CASE WHEN lea.response_id = 4 THEN atm.member_id END) AS declined_count,
        COUNT(CASE WHEN lea.response_id IS NULL THEN atm.member_id END) AS no_response_count
    FROM
        all_team_members AS atm
    LEFT JOIN
        latest_event_attendance AS lea ON atm.member_id = lea.member_id AND atm.event_id = lea.event_id
    GROUP BY
        atm.event_id
)
SELECT
    -- FIX: Cast json_agg result to jsonb to match the '[]'::jsonb type
    COALESCE(
        json_agg(final_result)::jsonb 
    , '[]'::jsonb) -- ⬅️ THIS ENSURES AN EMPTY ARRAY '[]' IS RETURNED INSTEAD OF NULL
FROM
(
    SELECT
        ue.event_id,
        ue.effective_event_title AS event_title,
        ue.meet_time,
        ue.event_date_time_formatted,
        ue.team_name,
        ue.team_id,
        ue.club_id,
        rm.member_id,
        lea_user.attendance_id,
        ert.display_value AS attendance_status,
        ert.icon_link AS attendance_icon,
        lea_user.response_id,
        ue.request_attendance,
        ue.event_type,
        ue.event_link,
        ue.event_code,
        ue.location_name,
        ue.location_pin,
        ue.opposition,
        ue.event_details,
        ue.home_away,
        ue.created_by,
        CONCAT(u.first_name, ' ', u.last_name) AS created_by_user_name,
        u.phone_number AS created_by_phone_number,
        rm.member_first_name,
        rm.member_last_name,
        rm.member_role_level,
        rm.event_role_level,
        COALESCE(asum.accepted_count, 0) AS accepted_count,
        COALESCE(asum.declined_count, 0) AS declined_count,
        COALESCE(asum.no_response_count, 0) AS no_response_count,
        ur.user_highest_role_on_team,
        umr.user_highest_role_on_any_team,
        ue.notify_admins_changes,
        ue.notify_admins_all
    FROM
        upcoming_events AS ue
    -- Join pre-calculated highest roles for the team and overall
    LEFT JOIN
        user_roles AS ur ON ue.team_id = ur.team_id
    CROSS JOIN
        user_max_any_role AS umr
    -- Join event creator details
    LEFT JOIN
        public.users AS u ON ue.created_by = u.user_id 
    -- Join the relevant member and their role details (for the specific user's view)
    LEFT JOIN
        relevant_member AS rm ON ue.event_id = rm.event_id
    -- Join the *user's* latest attendance from the pre-calculated set
    LEFT JOIN
        latest_event_attendance AS lea_user ON lea_user.member_id = rm.member_id AND lea_user.event_id = ue.event_id
    LEFT JOIN
        public.event_response_type AS ert ON lea_user.response_id = ert.response_id
    -- Join the attendance summary counts
    LEFT JOIN
        attendance_summary AS asum ON ue.event_id = asum.event_id
    WHERE
        rm.member_id IS NOT NULL -- Only include events the user has an eligible member for
    ORDER BY
        ue.event_date_time ASC
) AS final_result;

$$;

CREATE OR REPLACE FUNCTION "public"."get_user_home_events"("p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
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
    WHERE uml.user_id = auth.uid()
    GROUP BY mtl.team_id, t.show_advert
),
user_details AS (
    SELECT
        u.user_id, u.first_name, u.last_name, u.email_address, u.phone_number,
        COALESCE(MAX(ur.user_highest_role_on_team), 0) AS highest_role_level,
        COALESCE(BOOL_OR(ur.show_advert), FALSE) AS show_advert,
        (SELECT COUNT(*)::int FROM public.notifications WHERE recipient_user_id = auth.uid() AND is_read = false) AS unread_notifications,
        (COALESCE(u.first_name, '') <> '' AND EXISTS (SELECT 1 FROM user_roles)) AS user_onboarded
    FROM public.users AS u
    LEFT JOIN user_roles AS ur ON TRUE
    WHERE u.user_id = auth.uid()
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
                    COALESCE(
                        NULLIF(TRIM(e.event_title), ''), 
                        CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type, 
                            CASE WHEN COALESCE(e.opposition, '') <> '' THEN ' (' || e.opposition || ')' ELSE '' END)
                    ), 
                    'Hurling', 'Camogie'
                )
            ELSE 
                COALESCE(
                    NULLIF(TRIM(e.event_title), ''), 
                    CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type, 
                        CASE WHEN COALESCE(e.opposition, '') <> '' THEN ' (' || e.opposition || ')' ELSE '' END)
                )
        END AS effective_event_title
    FROM public.events AS e
    JOIN public.teams AS t ON e.team_id = t.team_id
    JOIN user_roles ur ON e.team_id = ur.team_id
    JOIN public.event_types AS et ON e.event_type_id = et.event_type_id
    LEFT JOIN public.event_codes AS ec ON e.event_code_id = ec.code_id
    LEFT JOIN public.roles AS event_role ON e.audience_id = event_role.role_id
    WHERE e.event_date_time >= CURRENT_DATE
),
eligible_attendees AS (
    SELECT DISTINCT
        ue.event_id,
        mtl.member_id
    FROM upcoming_events ue
    JOIN public.member_team_link mtl ON ue.team_id = mtl.team_id
    JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.roles r_member ON mtrl.role_id = r_member.role_id
    WHERE (
        (ue.event_role_level > 10 AND r_member.role_level >= ue.event_role_level)
        OR (ue.event_role_level = 10 AND r_member.role_level = 10)
        OR (ue.event_role_level = 0 OR ue.event_role_level IS NULL)
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
        ue.event_id, ue.effective_event_title AS event_title, ue.meet_time, ue.event_date_time_formatted, ue.team_name, ue.team_id, ue.club_id,
        rm.member_id, lar_user.attendance_id, ert.display_value AS attendance_status, ert.icon_link AS attendance_icon, lar_user.response_id,
        ue.request_attendance, ue.event_type, ue.event_link, ue.event_code, ue.location_name, ue.location_pin, ue.opposition, ue.event_details,
        ue.home_away, ue.created_by, CONCAT(u.first_name, ' ', u.last_name) AS created_by_user_name, u.phone_number AS created_by_phone_number,
        rm.member_first_name, rm.member_last_name, rm.member_role_level, rm.event_role_level,
        COALESCE(asum.accepted_count, 0) AS accepted_count, 
        COALESCE(asum.declined_count, 0) AS declined_count, 
        COALESCE(asum.no_response_count, 0) AS no_response_count,
        ur.user_highest_role_on_team, ue.notify_admins_changes, ue.notify_admins_all, ue.payment_required, 
        -- Updated Logic: Checks for ANY completed payment for this User and Event
        COALESCE((
            SELECT TRUE 
            FROM public.event_user_member_payment eup 
            WHERE eup.event_id = ue.event_id 
              AND eup.user_id = auth.uid() 
              AND eup.payment_status = 'confirmed' 
            LIMIT 1
        ), FALSE) AS event_paid
    FROM upcoming_events AS ue
    LEFT JOIN user_roles AS ur ON ue.team_id = ur.team_id
    LEFT JOIN public.users AS u ON ue.created_by = u.user_id 
    LEFT JOIN (
        SELECT DISTINCT ON (ue.event_id)
            ue.event_id, m.member_id, m.first_name AS member_first_name, m.last_name AS member_last_name, r.role_level AS member_role_level, ue.event_role_level
        FROM upcoming_events AS ue
        JOIN public.user_member_link AS uml ON uml.user_id = auth.uid()
        JOIN public.members AS m ON uml.member_id = m.member_id
        JOIN public.member_team_link AS mtl ON m.member_id = mtl.member_id AND mtl.team_id = ue.team_id
        JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN public.roles AS r ON mtrl.role_id = r.role_id
        WHERE r.role_level >= ue.event_role_level
        ORDER BY ue.event_id, r.role_level ASC
    ) AS rm ON ue.event_id = rm.event_id
    LEFT JOIN latest_attendance_records AS lar_user ON lar_user.member_id = rm.member_id AND lar_user.event_id = ue.event_id
    LEFT JOIN public.event_response_type AS ert ON lar_user.response_id = ert.response_id
    LEFT JOIN attendance_summary AS asum ON ue.event_id = asum.event_id
    WHERE rm.member_id IS NOT NULL 
    ORDER BY ue.event_date_time ASC
)
SELECT
    jsonb_build_object(
        'user_id', ud.user_id, 'first_name', ud.first_name, 'last_name', ud.last_name, 'email_address', ud.email_address, 'phone_number', ud.phone_number,
        'highest_role_level', ud.highest_role_level, 'user_onboarded', ud.user_onboarded, 'unread_notifications', ud.unread_notifications,
        'show_advert', ud.show_advert,
        'user_team_count', (SELECT COUNT(DISTINCT team_id) + 1 FROM user_roles),
        'user_teams', (
            SELECT jsonb_agg(t) FROM (
                SELECT team_id, team_name, team_unique_code, profile_pic, team_female, club_id, user_highest_role_on_team, sort_order 
                FROM (
                    SELECT 0::bigint AS team_id, 'All Teams'::text AS team_name, NULL::text AS team_unique_code, NULL::text AS profile_pic, FALSE AS team_female, 0::bigint AS club_id, 0::smallint AS user_highest_role_on_team, 0 AS sort_order
                    UNION ALL
                    SELECT t.team_id, t.team_name, t.team_unique_code, t.profile_pic, t.team_female, t.club_id, ur.user_highest_role_on_team, 1 AS sort_order
                    FROM public.teams t 
                    JOIN user_roles ur ON t.team_id = ur.team_id
                ) teams_union ORDER BY sort_order, team_name
            ) t
        ),
        'clubs', (
            SELECT jsonb_agg(c) FROM (
                SELECT DISTINCT club_id, club_name, county, banner, crest, sort_order FROM (
                    SELECT c.club_id, c.club_name, c.county, c.banner, c.crest, 1 AS sort_order
                    FROM public.teams t
                    JOIN user_roles ur ON t.team_id = ur.team_id
                    JOIN public.clubs c ON t.club_id = c.club_id
                    UNION ALL
                    SELECT NULL, 'All Clubs', NULL, NULL, 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/coach-smart-new-mpqa5l/assets/yk304zt4r8kj/Launcher_Icon_v2-removebg-preview.png', 0
                ) clubs_union ORDER BY sort_order, club_name
            ) c
        ),
        'events', (SELECT COALESCE(jsonb_agg(fed), '[]'::jsonb) FROM final_events_data fed)
    )
FROM user_details AS ud;
$$;

CREATE OR REPLACE FUNCTION "public"."get_single_user_event"("p_user_id" "uuid", "p_event_id" bigint) RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
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
    WHERE uml.user_id = auth.uid()
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
                    COALESCE(
                        NULLIF(TRIM(e.event_title), ''), 
                        CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type, 
                            CASE WHEN COALESCE(e.opposition, '') <> '' THEN ' (' || e.opposition || ')' ELSE '' END)
                    ), 
                    'Hurling', 'Camogie'
                )
            ELSE 
                COALESCE(
                    NULLIF(TRIM(e.event_title), ''), 
                    CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type, 
                        CASE WHEN COALESCE(e.opposition, '') <> '' THEN ' (' || e.opposition || ')' ELSE '' END)
                )
        END AS effective_event_title
    FROM public.events AS e
    JOIN public.teams AS t ON e.team_id = t.team_id
    JOIN user_roles ur ON e.team_id = ur.team_id
    JOIN public.event_types AS et ON e.event_type_id = et.event_type_id
    LEFT JOIN public.event_codes AS ec ON e.event_code_id = ec.code_id
    LEFT JOIN public.roles AS event_role ON e.audience_id = event_role.role_id
    WHERE e.event_id = p_event_id
),
eligible_attendees AS (
    SELECT DISTINCT
        te.event_id,
        mtl.member_id
    FROM target_event te
    JOIN public.member_team_link mtl ON te.team_id = mtl.team_id
    JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.roles r_member ON mtrl.role_id = r_member.role_id
    WHERE (
        (te.event_role_level > 10 AND r_member.role_level >= te.event_role_level)
        OR (te.event_role_level = 10 AND r_member.role_level = 10)
        OR (te.event_role_level = 0 OR te.event_role_level IS NULL)
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
        te.event_id, te.effective_event_title AS event_title, te.meet_time, te.event_date_time_formatted, te.team_name, te.team_id, te.club_id,
        rm.member_id, lar_user.attendance_id, ert.display_value AS attendance_status, ert.icon_link AS attendance_icon, lar_user.response_id,
        te.request_attendance, te.event_type, te.event_link, te.event_code, te.location_name, te.location_pin, te.opposition, te.event_details,
        te.home_away, te.created_by, CONCAT(u.first_name, ' ', u.last_name) AS created_by_user_name, u.phone_number AS created_by_phone_number,
        rm.member_first_name, rm.member_last_name, rm.member_role_level, rm.event_role_level,
        COALESCE(asum.accepted_count, 0) AS accepted_count, 
        COALESCE(asum.declined_count, 0) AS declined_count, 
        COALESCE(asum.no_response_count, 0) AS no_response_count,
        ur.user_highest_role_on_team, te.notify_admins_changes, te.notify_admins_all, te.payment_required, 
        COALESCE((
            SELECT TRUE 
            FROM public.event_user_member_payment eup 
            WHERE eup.event_id = te.event_id 
              AND eup.user_id = auth.uid() 
              AND eup.payment_status = 'confirmed' 
            LIMIT 1
        ), FALSE) AS event_paid
    FROM target_event AS te
    LEFT JOIN user_roles AS ur ON te.team_id = ur.team_id
    LEFT JOIN public.users AS u ON te.created_by = u.user_id 
    LEFT JOIN (
        SELECT DISTINCT ON (te.event_id)
            te.event_id, m.member_id, m.first_name AS member_first_name, m.last_name AS member_last_name, r.role_level AS member_role_level, te.event_role_level
        FROM target_event AS te
        JOIN public.user_member_link AS uml ON uml.user_id = auth.uid()
        JOIN public.members AS m ON uml.member_id = m.member_id
        JOIN public.member_team_link AS mtl ON m.member_id = mtl.member_id AND mtl.team_id = te.team_id
        JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN public.roles AS r ON mtrl.role_id = r.role_id
        WHERE r.role_level >= te.event_role_level
        ORDER BY te.event_id, r.role_level ASC
    ) AS rm ON te.event_id = rm.event_id
    LEFT JOIN latest_attendance_records AS lar_user ON lar_user.member_id = rm.member_id AND lar_user.event_id = te.event_id
    LEFT JOIN public.event_response_type AS ert ON lar_user.response_id = ert.response_id
    LEFT JOIN attendance_summary AS asum ON te.event_id = asum.event_id
    WHERE rm.member_id IS NOT NULL
)
SELECT
    COALESCE(
        (SELECT jsonb_agg(fed) FROM final_event_data fed),
        '[]'::jsonb
    )
FROM final_event_data;

$$;

CREATE OR REPLACE FUNCTION "public"."get_user_clubs"("p_user_id" "uuid") RETURNS TABLE("user_id" "uuid", "email_address" "text", "user_first_name" "text", "user_last_name" "text", "user_full_name" "text", "club_id" bigint, "club_name" "text", "county" "text", "banner" "text", "crest" "text", "sort_order" integer)
    LANGUAGE "sql" SECURITY DEFINER
    SET search_path = 'public'
AS $$
SELECT DISTINCT
    u.user_id,
    u.email_address,
    u.first_name AS user_first_name,
    u.last_name AS user_last_name,
    CONCAT(
        COALESCE(u.first_name, ''::text),
        ' ',
        COALESCE(u.last_name, ''::text)
    ) AS user_full_name,
    c.club_id,
    c.club_name,
    c.county,
    c.banner,
    c.crest,
    CASE
        WHEN c.club_name = 'All Clubs'::text THEN 0
        ELSE 1
    END AS sort_order
FROM
    public.users u
JOIN
    public.user_member_link uml ON u.user_id = uml.user_id
JOIN
    public.member_team_link mtl ON uml.member_id = mtl.member_id
JOIN
    public.teams t ON mtl.team_id = t.team_id
JOIN
    public.clubs c ON t.club_id = c.club_id
WHERE
    u.user_id = auth.uid() -- REVERTED: Now uses the passed parameter
UNION ALL
SELECT
    u.user_id,
    u.email_address,
    u.first_name AS user_first_name,
    u.last_name AS user_last_name,
    CONCAT(
        COALESCE(u.first_name, ''::text),
        ' ',
        COALESCE(u.last_name, ''::text)
    ) AS user_full_name,
    NULL::bigint AS club_id,
    'All Clubs'::text AS club_name,
    NULL::text AS county,
    NULL::text AS banner,
    'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/coach-smart-new-mpqa5l/assets/yk304zt4r8kj/Launcher_Icon_v2-removebg-preview.png'::text AS crest,
    0 AS sort_order
FROM
    public.users u
WHERE
    u.user_id = auth.uid() -- REVERTED: Now uses the passed parameter
ORDER BY
    1,
    11,
    7;
$$;

CREATE OR REPLACE FUNCTION "public"."get_user_event_create_detail"("p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET search_path = 'public'
AS $$
DECLARE
    v_result jsonb;
    v_default_team_id bigint;
BEGIN
    -- 1. Determine the default team
    -- Count distinct teams where the user is a member. 
    -- If count is exactly 1, return the ID, else NULL.
    SELECT 
        CASE 
            WHEN COUNT(DISTINCT mtl.team_id) = 1 THEN MAX(mtl.team_id)
            ELSE NULL 
        END INTO v_default_team_id
    FROM public.members m
    JOIN public.member_team_link mtl ON m.member_id = mtl.member_id
    WHERE m.user_id = auth.uid();

    -- 2. Build the full result object
    SELECT jsonb_build_object(
        'user_id', auth.uid(),
        'default_team_id', v_default_team_id, -- New top-level field
        'create_teams', (
            SELECT jsonb_agg(team_data)
            FROM (
                SELECT DISTINCT ON (t.team_id)
                    t.team_id,
                    t.team_name,
                    t.club_id,
                    c.club_name,
                    m.member_id,
                    (m.first_name || ' ' || m.last_name) AS authorized_member_name,
                    r.role_id,
                    r.role_name AS admin_role,
                    r.role_level AS admin_level,
                    -- Nested List of Event Types
                    (SELECT jsonb_agg(jsonb_build_object('id', et.event_type_id, 'name', et.event_type))
                     FROM public.event_types et) AS event_types,
                    -- Nested List of Event Codes specific to this team's Club
                    (SELECT jsonb_agg(jsonb_build_object('id', ec.code_id, 'name', ec.event_code))
                     FROM public.club_code_link ccl
                     JOIN public.event_codes ec ON ccl.code_id = ec.code_id
                     WHERE ccl.club_id = t.club_id) AS event_codes,
                    -- Nested List of Team Roles
                    (SELECT jsonb_agg(jsonb_build_object(
                        'id', r_inner.role_id, 
                        'name', r_inner.role_name,
                        'name_plural', r_inner.role_name_plural
                     ))
                     FROM public.team_roles_link trl
                     JOIN public.roles r_inner ON trl.role_id = r_inner.role_id
                     WHERE trl.team_id = t.team_id 
                       AND r_inner.role_grade = 10
                       AND r_inner.show_audience = true) AS team_roles 
                FROM public.members m
                JOIN public.member_team_link mtl ON m.member_id = mtl.member_id
                JOIN public.teams t ON mtl.team_id = t.team_id
                LEFT JOIN public.clubs c ON t.club_id = c.club_id
                JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
                JOIN public.roles r ON mtrl.role_id = r.role_id
                WHERE m.user_id = auth.uid()
                  AND r.role_grade = 100
                ORDER BY t.team_id, r.role_level DESC
            ) team_data
        )
    )
    INTO v_result;

    RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION "public"."get_user_event_details"("p_event_id" bigint, "p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET search_path = 'public'
AS $$

WITH event_details AS (
    -- Level 1: Get core event details, including the new car_pooling flag
    SELECT
        e.event_id,
        e.team_id,
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
        ec.code_id, -- CHANGED: Added code_id
        e.audience_id,
        event_role.role_level AS event_role_level,
        to_char(e.event_date_time::timestamp, 'FMDay, DD FMMonth, YYYY at HH24:MI') AS event_date_time_formatted,
        
        CASE
            WHEN t.team_female = TRUE AND
                (
                    CASE
                        WHEN e.event_title IS NOT NULL AND TRIM(e.event_title) <> '' THEN e.event_title
                        WHEN et.event_type = 'Match' THEN
                            CASE
                                WHEN e.opposition IS NOT NULL AND TRIM(e.opposition) <> '' THEN
                                    CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type, ' (', e.opposition, ')')
                                ELSE
                                    CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type)
                            END
                        ELSE CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type)
                    END
                ) LIKE '%Hurling%'
            THEN
                REPLACE(
                    CASE
                        WHEN e.event_title IS NOT NULL AND TRIM(e.event_title) <> '' THEN e.event_title
                        WHEN et.event_type = 'Match' THEN
                            CASE
                                WHEN e.opposition IS NOT NULL AND TRIM(e.opposition) <> '' THEN
                                    CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type, ' (', e.opposition, ')')
                                ELSE
                                    CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type)
                            END
                        ELSE CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type)
                    END
                , 'Hurling', 'Camogie')
            ELSE
                CASE
                    WHEN e.event_title IS NOT NULL AND TRIM(e.event_title) <> '' THEN e.event_title
                    WHEN et.event_type = 'Match' THEN
                        CASE
                            WHEN e.opposition IS NOT NULL AND TRIM(e.opposition) <> '' THEN
                                CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type, ' (', e.opposition, ')')
                            ELSE
                                CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type)
                        END
                    ELSE CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type)
                END
        END AS effective_event_title,
        
        CONCAT(u.first_name, ' ', u.last_name) AS created_by_user_name,
        u.phone_number AS created_by_phone_number
    FROM
        public.events AS e
    JOIN
        public.teams AS t ON e.team_id = t.team_id
    JOIN
        public.event_types AS et ON e.event_type_id = et.event_type_id
    LEFT JOIN
        public.event_codes AS ec ON e.event_code_id = ec.code_id
    LEFT JOIN
        public.roles AS event_role ON e.audience_id = event_role.role_id
    LEFT JOIN
        public.users AS u ON e.created_by = u.user_id
    WHERE
        e.event_id = p_event_id
),
latest_event_attendance AS (
    SELECT
        ea.member_id,
        ea.response_id,
        ROW_NUMBER() OVER(PARTITION BY ea.member_id ORDER BY ea.created_at DESC, ea.attendance_id DESC) as rn
    FROM
        public.event_attendance AS ea
    WHERE
        ea.event_id = p_event_id
),
member_primary_role AS (
    WITH ranked_roles AS (
        SELECT
            mtl.member_id,
            r.role_id,
            r.role_level,
            r.role_name,
            r.role_name_plural,
            r.role_grade,
            ROW_NUMBER() OVER(
                PARTITION BY mtl.member_id
                ORDER BY
                    CASE WHEN r.role_level BETWEEN 20 AND 99 THEN 0 ELSE 1 END ASC,
                    r.role_level ASC,
                    r.role_id ASC
            ) as rn
        FROM
            public.member_team_link AS mtl
        JOIN
            public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN
            public.roles AS r ON mtrl.role_id = r.role_id
        JOIN
            event_details AS ed ON mtl.team_id = ed.team_id
    )
    SELECT member_id, role_id, role_level, role_name, role_name_plural, role_grade FROM ranked_roles WHERE rn = 1
),
categorized_eligible_members AS (
    SELECT DISTINCT mtl.member_id
    FROM public.member_team_link AS mtl
    JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.roles AS r ON mtrl.role_id = r.role_id
    CROSS JOIN event_details AS ed
    WHERE mtl.team_id = ed.team_id AND r.role_grade = 10 AND r.role_level >= ed.event_role_level
),
total_eligible_count AS (
    SELECT COUNT(cem.member_id) AS total_count FROM categorized_eligible_members AS cem
),
member_role_attendance AS (
    SELECT cem.member_id, lea.response_id FROM categorized_eligible_members AS cem
    LEFT JOIN latest_event_attendance AS lea ON cem.member_id = lea.member_id AND lea.rn = 1
),
strictly_matched_members AS (
    SELECT mpr.member_id FROM member_primary_role AS mpr
    CROSS JOIN event_details AS ed
    WHERE mpr.role_grade = 10 AND mpr.role_level = ed.event_role_level
),
matched_role_attendance AS (
    SELECT smm.member_id, lea.response_id FROM strictly_matched_members AS smm
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
    SELECT mpr.role_id, mpr.role_level, mpr.role_name, mpr.role_grade, COALESCE(mra.response_id, 0) AS response_id, COUNT(mra.member_id) AS member_count
    FROM member_role_attendance AS mra JOIN member_primary_role AS mpr ON mra.member_id = mpr.member_id GROUP BY 1, 2, 3, 4, 5
),
event_distinct_primary_roles AS (
    SELECT DISTINCT mpr.role_id, mpr.role_level, mpr.role_name, mpr.role_name_plural, mpr.role_grade
    FROM member_primary_role AS mpr CROSS JOIN event_details AS ed
    WHERE mpr.role_grade = 10 AND mpr.role_level >= ed.event_role_level
),
event_response_types AS (
    SELECT response_id FROM public.event_response_type UNION ALL SELECT 0 AS response_id
),
zero_filled_attendance_by_role AS (
    SELECT ert.response_id, edpr.role_id, edpr.role_level, edpr.role_name, edpr.role_name_plural, edpr.role_grade, COALESCE(abrr.member_count, 0) AS member_count
    FROM event_response_types AS ert CROSS JOIN event_distinct_primary_roles AS edpr
    LEFT JOIN attendance_by_response_and_role AS abrr ON ert.response_id = abrr.response_id AND edpr.role_id = abrr.role_id
),
dynamic_role_attendance_summary AS (
    SELECT zfar.response_id, jsonb_agg(jsonb_build_object('role_id', zfar.role_id, 'role_level', zfar.role_level, 'role_name', zfar.role_name, 'role_name_plural', zfar.role_name_plural, 'member_count', zfar.member_count) ORDER BY zfar.role_level ASC, zfar.role_name ASC) AS filtered_response_by_role
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
    SELECT eump.member_id, eump.payment_id, eump.payment_status, CASE WHEN eump.payment_status = 'confirmed' THEN 1 ELSE 0 END AS member_paid,
    ROW_NUMBER() OVER(PARTITION BY eump.member_id ORDER BY eump.created_at DESC) as rn
    FROM public.event_user_member_payment AS eump WHERE eump.event_id = p_event_id AND eump.user_id = auth.uid() AND eump.payment_status <> 'pending'
),
latest_member_payment AS (
    SELECT member_id, payment_id, member_paid, payment_status FROM member_payment_status WHERE rn = 1
),
event_team_members AS (
    SELECT m.member_id, m.first_name, m.last_name, m.profile_pic, r.role_name, r.role_level, ROW_NUMBER() OVER(PARTITION BY m.member_id ORDER BY r.role_level ASC) as role_rn
    FROM public.members AS m
    INNER JOIN public.user_member_link AS uml ON m.member_id = uml.member_id
    INNER JOIN public.member_team_link AS mtl ON m.member_id = mtl.member_id
    INNER JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
    INNER JOIN public.roles AS r ON mtrl.role_id = r.role_id
    INNER JOIN event_details AS ed ON mtl.team_id = ed.team_id
    WHERE uml.user_id = auth.uid()
),
user_highest_role AS (
    SELECT MAX(etm.role_level) AS highest_role_level_for_user FROM event_team_members AS etm
),
user_payment_status AS (
    SELECT COALESCE(COUNT(eup.payment_id), 0)::integer AS event_paid FROM public.event_user_payment AS eup WHERE eup.event_id = p_event_id AND eup.user_id = auth.uid() AND eup.payment_status = 'confirmed'
),
event_payment_summary AS (
    SELECT COUNT(eup.stripe_session_id) AS total_payments, COALESCE(SUM(eup.amount_paid), 0) AS total_amount_paid,
    COALESCE(SUM(eup.amount_paid)::numeric - COALESCE(SUM(eup.fee_amount), 0)::numeric - COALESCE(SUM(eup.tax_amount), 0)::numeric, 0) AS total_net_amount
    FROM public.event_user_payment eup WHERE eup.event_id = p_event_id AND eup.payment_status = 'confirmed'
),
event_member_payment_summary AS (
    SELECT COALESCE(COUNT(eump.payment_id) FILTER (WHERE eump.payment_status = 'confirmed'), 0)::integer AS new_num_payments,
    COALESCE(SUM(eump.gross_amount), 0) AS new_gross_amount, COALESCE(SUM(eump.net_amount), 0) AS new_net_amount
    FROM public.event_user_member_payment eump WHERE eump.event_id = p_event_id AND eump.payment_status = 'confirmed'
)
SELECT
    jsonb_build_object(
        'event_id', ed.event_id,
        'team_id', ed.team_id,
        'team_has_squads', tsc.team_has_squads,
        'audience_id', ed.audience_id,
        'event_role_level', ed.event_role_level,
        'event_link', ed.event_link,
        'event_title', ed.effective_event_title,
        'team_name', ed.team_name,
        'event_date_time_formatted', ed.event_date_time_formatted,
        'meet_time', ed.meet_time,
        'event_type', ed.event_type,
        'event_code', ed.event_code,
        'code_id', ed.code_id, -- CHANGED: Added code_id
        'location_name', ed.location_name,
        'location_pin', ed.location_pin,
        'opposition', ed.opposition,
        'event_details', ed.event_details,
        'home_away', ed.home_away,
        'request_attendance', ed.request_attendance,
        'notify_admins_changes', ed.notify_admins_changes,
        'notify_admins_all', ed.notify_admins_all,
        'created_by', ed.created_by_user_name,
        'created_by_phone_number', ed.created_by_phone_number,
        'total_count', tec.total_count,
        'user_highest_role_level', uhr.highest_role_level_for_user,
        'car_pooling_enabled', COALESCE(ed.car_pooling, false),
        'payment_required', ed.payment_required,
        'payment_amount', ed.payment_amount,
        'event_paid', ups.event_paid,
        'total_payments', eps.total_payments,
        'total_amount_paid', eps.total_amount_paid,
        'total_net_amount', eps.total_net_amount,
        'event_image', ed.event_image,
        'new_gross_amount', emps.new_gross_amount,
        'new_net_amount', emps.new_net_amount,
        'new_num_payments', emps.new_num_payments,
        'team_members', (
            SELECT COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'member_id', etm.member_id,
                        'first_name', etm.first_name,
                        'last_name', etm.last_name,
                        'profile_pic', etm.profile_pic,
                        'role_name', etm.role_name,
                        'role_level', etm.role_level,
                        'response_id', lea.response_id,
                        'attendance_status', ert.display_value,
                        'attendance_icon', ert.icon_link,
                        'member_paid', COALESCE(lmp.member_paid, 0),
                        'member_payment_id', lmp.payment_id,
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
        'accepted_attendance_summary', sd.accepted_attendance_summary,
        'no_response_attendance_summary', sd.no_response_attendance_summary,
        'declined_attendance_summary', sd.declined_attendance_summary,
        'accepted_player_count', sd.accepted_exact_match_count,
        'no_response_player_count', sd.no_response_exact_match_count,
        'declined_player_count', sd.declined_exact_match_count
    )
FROM
    event_details AS ed
CROSS JOIN user_highest_role AS uhr
CROSS JOIN total_eligible_count AS tec
CROSS JOIN team_squad_check AS tsc
CROSS JOIN summary_data AS sd
CROSS JOIN user_payment_status AS ups
CROSS JOIN event_payment_summary AS eps
CROSS JOIN event_member_payment_summary AS emps
LIMIT 1;

$$;

CREATE OR REPLACE FUNCTION "public"."get_user_event_edit_detail"("p_user_id" "uuid", "p_event_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET search_path = 'public'
AS $$
DECLARE
    v_result jsonb;
    v_default_team_id bigint;
    v_current_event jsonb;
BEGIN
    -- 1. Determine the default team
    SELECT 
        CASE 
            WHEN COUNT(DISTINCT mtl.team_id) = 1 THEN MAX(mtl.team_id)
            ELSE NULL 
        END INTO v_default_team_id
    FROM public.members m
    JOIN public.member_team_link mtl ON m.member_id = mtl.member_id
    WHERE m.user_id = auth.uid();

    -- 2. Fetch Existing Event Data
    IF p_event_id IS NOT NULL THEN
        SELECT jsonb_build_object(
            'event_id', e.event_id,
            'event_title', e.event_title,
            'event_type_id', e.event_type_id,
            -- Explicitly ensuring this is treated as a timestamp
            'event_date_time', e.event_date_time_2, 
            'meet_time', e.meet_time,
            'event_code_id', e.event_code_id,
            'opposition', e.opposition,
            'home_away', e.home_away,
            'location_name', e.location_name,
            'location_pin', e.location_pin,
            'event_link', e.event_link,
            'audience_id', e.audience_id,
            'request_attendance', e.request_attendance,
            'event_details', e.event_details,
            'team_id', e.team_id,
            'event_image', e.event_image,
            'payment_required', e.payment_required,
            'payment_amount', e.payment_amount
        ) INTO v_current_event
        FROM public.events e
        WHERE e.event_id = p_event_id;
    END IF;

    -- 3. Build the final response
    SELECT jsonb_build_object(
        'user_id', auth.uid(),
        'default_team_id', v_default_team_id,
        'current_event', v_current_event,
        'create_teams', (
            SELECT jsonb_agg(team_data)
            FROM (
                SELECT DISTINCT ON (t.team_id)
                    t.team_id,
                    t.team_name,
                    t.club_id,
                    c.club_name,
                    m.member_id,
                    (m.first_name || ' ' || m.last_name) AS authorized_member_name,
                    r.role_id,
                    r.role_name AS admin_role,
                    r.role_level AS admin_level,
                    (SELECT jsonb_agg(jsonb_build_object('id', et.event_type_id, 'name', et.event_type))
                     FROM public.event_types et) AS event_types,
                    (SELECT jsonb_agg(jsonb_build_object('id', ec.code_id, 'name', ec.event_code))
                     FROM public.club_code_link ccl
                     JOIN public.event_codes ec ON ccl.code_id = ec.code_id
                     WHERE ccl.club_id = t.club_id) AS event_codes,
                    (SELECT jsonb_agg(jsonb_build_object(
                        'id', r_inner.role_id, 
                        'name', r_inner.role_name,
                        'name_plural', r_inner.role_name_plural
                     ))
                     FROM public.team_roles_link trl
                     JOIN public.roles r_inner ON trl.role_id = r_inner.role_id
                     WHERE trl.team_id = t.team_id 
                       AND r_inner.role_grade = 10
                       AND r_inner.show_audience = true) AS team_roles 
                FROM public.members m
                JOIN public.member_team_link mtl ON m.member_id = mtl.member_id
                JOIN public.teams t ON mtl.team_id = t.team_id
                LEFT JOIN public.clubs c ON t.club_id = c.club_id
                JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
                JOIN public.roles r ON mtrl.role_id = r.role_id
                WHERE m.user_id = auth.uid()
                  AND r.role_grade = 100
                ORDER BY t.team_id, r.role_level DESC
            ) team_data
        )
    )
    INTO v_result;

    RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION "public"."get_user_notifications"("p_user_id" "uuid") RETURNS TABLE("id" bigint, "created_at" "text", "time_label" "text", "app_title" "text", "app_body" "text", "is_read" boolean, "link_page" "text", "team_id" bigint, "team_name" "text", "event_id" bigint)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET search_path = 'public'
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        n.id,
        to_char(n.created_at, 'Dy, DD Mon YYYY "at" HH12:MI AM')::text,
        -- Refined Time Ago Logic
        CASE 
            WHEN n.created_at > now() - interval '2 minutes' 
                THEN 'Just now'
            WHEN n.created_at > now() - interval '1 hour' 
                THEN floor(extract(epoch from (now() - n.created_at)) / 60)::text || 'm ago'
            WHEN n.created_at > now() - interval '24 hours' THEN 
                CASE 
                    WHEN floor(extract(epoch from (now() - n.created_at)) / 3600) = 1 THEN '1 hour ago'
                    ELSE floor(extract(epoch from (now() - n.created_at)) / 3600)::text || ' hours ago'
                END
            ELSE 
                CASE 
                    WHEN floor(extract(epoch from (now() - n.created_at)) / 86400) = 1 THEN '1 day ago'
                    ELSE floor(extract(epoch from (now() - n.created_at)) / 86400)::text || ' days ago'
                END
        END as time_label,
        
        COALESCE(n.app_title, n.push_title, 'Notification') as title,
        COALESCE(n.app_body, n.push_body, '') as body,
        n.is_read,
        n.link_page,
        n.team_id,
        COALESCE(t.team_name, 'General') as team_name,
        n.event_id    
    FROM 
        public.notifications n
    LEFT JOIN 
        public.teams t ON n.team_id = t.team_id
    WHERE 
        n.recipient_user_id = auth.uid()
    ORDER BY 
        n.created_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION "public"."get_user_team_summary"("p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET search_path = 'public'
AS $$
DECLARE
    v_overall_highest smallint;
    v_teams_json jsonb;
BEGIN
    -- 1. Get the absolute MAX role level across all members LINKED to this user
    SELECT MAX(r.role_level) INTO v_overall_highest
    FROM public.user_member_link uml
    JOIN public.member_team_link mtl ON uml.member_id = mtl.member_id
    JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.roles r ON mtrl.role_id = r.role_id
    WHERE uml.user_id = auth.uid();

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
        INNER JOIN public.member_team_link mtl ON uml.member_id = mtl.member_id
        INNER JOIN public.teams t ON mtl.team_id = t.team_id
        INNER JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        INNER JOIN public.roles r ON mtrl.role_id = r.role_id
        WHERE uml.user_id = auth.uid()
        ORDER BY t.team_id, r.role_level DESC 
    ) t_final;

    RETURN jsonb_build_object(
        'overall_highest_role_level', COALESCE(v_overall_highest, 0),
        'teams', COALESCE(v_teams_json, '[]'::jsonb)
    );
END;
$$;

CREATE OR REPLACE FUNCTION "public"."get_team_members_by_role"("p_user_id" "uuid", "p_team_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET search_path = 'public'
AS $$
DECLARE
    v_user_highest_role smallint;
    v_team_info RECORD;
    v_roles_json jsonb;
    v_club_codes_json jsonb;
BEGIN
    -- 1. Get highest role level
    SELECT MAX(r.role_level) INTO v_user_highest_role
    FROM public.roles r
    JOIN public.member_team_role_link mtrl ON r.role_id = mtrl.role_id
    JOIN public.member_team_link mtl ON mtrl.member_team_id = mtl.member_team_id
    JOIN public.members m ON mtl.member_id = m.member_id
    WHERE m.user_id = auth.uid();

    -- 2. Get team details
    SELECT team_id, team_name, team_unique_code, club_id, team_female 
    INTO v_team_info
    FROM public.teams
    WHERE team_id = p_team_id;

    -- 3. Get club codes (with Camogie logic)
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

    -- 4. Create the grouped list of members
    SELECT jsonb_agg(role_group) INTO v_roles_json
    FROM (
        SELECT 
            r.role_name,
            r.role_level,
            CASE 
                WHEN r.role_name ILIKE '%y' THEN LEFT(r.role_name, -1) || 'ies'
                WHEN r.role_name ILIKE '%ch' OR r.role_name ILIKE '%sh' OR r.role_name ILIKE '%x' OR r.role_name ILIKE '%s' THEN r.role_name || 'es'
                ELSE r.role_name || 's'
            END as role_name_plural,
            COUNT(DISTINCT m.member_id) as member_count,
            jsonb_agg(
                jsonb_build_object(
                    'member_id', m.member_id::bigint,
                    'first_name', m.first_name::text,
                    'last_name', m.last_name::text,
                    'full_name', (m.first_name || ' ' || m.last_name)::text,
                    'squad_image', s.squad_image, 
                    'squad_id', mtl.squad_id::bigint,
                    'squad_name', s.squad_name::text,
                    'squad_codes', (
                        SELECT jsonb_agg(
                            jsonb_build_object(
                                'code_id', ec_sub.code_id::bigint,
                                'code_name', CASE 
                                    WHEN v_team_info.team_female = TRUE AND ec_sub.event_code = 'Hurling' THEN 'Camogie'
                                    ELSE ec_sub.event_code 
                                END::text,
                                'squad_id', COALESCE(s_sub.squad_id, 0)::bigint,
                                'squad_name', COALESCE(s_sub.squad_name, '')::text,
                                'squad_image', COALESCE(s_sub.squad_image, '')::text
                            )
                        )
                        FROM public.club_code_link ccl_sub
                        JOIN public.event_codes ec_sub ON ccl_sub.code_id = ec_sub.code_id
                        LEFT JOIN public.member_squad_link msl_sub ON (
                            msl_sub.code_id = ec_sub.code_id 
                            AND msl_sub.member_id = m.member_id
                            AND msl_sub.team_id = p_team_id
                        )
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
        GROUP BY r.role_name, r.role_level
        ORDER BY r.role_level DESC 
    ) role_group;

    RETURN jsonb_build_object(
        'team_id', v_team_info.team_id::bigint,
        'team_name', v_team_info.team_name::text,
        'team_unique_code', v_team_info.team_unique_code::text,
        'club_id', v_team_info.club_id::bigint,
        'user_highest_role_level', COALESCE(v_user_highest_role, 0)::int,
        'role_groups', COALESCE(v_roles_json, '[]'::jsonb),
        'club_codes', COALESCE(v_club_codes_json, '[]'::jsonb)
    );
END;
$$;

CREATE OR REPLACE FUNCTION "public"."get_event_car_pools"("p_event_id" bigint, "p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET search_path = 'public'
AS $$

WITH event_context AS (
    -- 1. Identify the Team for this event
    SELECT team_id FROM public.events WHERE event_id = p_event_id
),
open_car_pools AS (
    -- 2. Get all OPEN car pools for the event
    SELECT
        cp.car_pool_id,
        cp.user_id,
        cp.number_of_seats,
        cp.created_at
    FROM
        public.car_pool AS cp
    WHERE
        cp.event_id = p_event_id
        AND cp.status = 'open'
),
car_pool_reservations AS (
    -- 3. Calculate reserved seats
    SELECT
        cpd.car_pool_id,
        COUNT(cpd.id) AS reserved_count
    FROM
        public.car_pool_detail AS cpd
    WHERE
        EXISTS (SELECT 1 FROM open_car_pools ocp WHERE ocp.car_pool_id = cpd.car_pool_id)
    GROUP BY 1
),
user_stats AS (
    -- 4. Get the current user's role level and count their associated players
    SELECT 
        MAX(r.role_level) AS user_role_level, 
        COUNT(DISTINCT uml.member_id) FILTER (WHERE r.role_level = 10) AS player_count,
        EXISTS (
            SELECT 1 FROM open_car_pools ocp WHERE ocp.user_id = auth.uid()
        ) AS has_open_pool
    FROM 
        public.user_member_link uml
    JOIN 
        public.member_team_link mtl ON uml.member_id = mtl.member_id
    JOIN 
        public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN 
        public.roles r ON mtrl.role_id = r.role_id
    WHERE 
        uml.user_id = auth.uid()
        AND mtl.team_id = (SELECT team_id FROM event_context)
),
formatted_pools AS (
    -- 5. Format the list of car pools into a JSON array
    SELECT
        jsonb_agg(
            jsonb_build_object(
                'car_pool_id', ocp.car_pool_id,
                'driver_user_id', ocp.user_id,
                'driver_name', u.first_name || ' ' || u.last_name,
                'total_seats', ocp.number_of_seats,
                'reserved_seats', COALESCE(cpr.reserved_count, 0),
                'free_seats', (ocp.number_of_seats - COALESCE(cpr.reserved_count, 0)),
                'created_at', ocp.created_at
            ) ORDER BY ocp.created_at ASC
        ) AS pools_list
    FROM
        open_car_pools AS ocp
    JOIN
        public.users AS u ON ocp.user_id = u.user_id
    LEFT JOIN
        car_pool_reservations AS cpr ON ocp.car_pool_id = cpr.car_pool_id
)
SELECT
    jsonb_build_object(
        'current_user_has_pool', COALESCE(us.has_open_pool, false),
        'current_user_role_level', COALESCE(us.user_role_level, 0),
        'associated_players_count', COALESCE(us.player_count, 0),
        'car_pools', COALESCE(fp.pools_list, '[]'::jsonb)
    )
FROM
    user_stats AS us
CROSS JOIN
    formatted_pools AS fp;

$$;

CREATE OR REPLACE FUNCTION "public"."get_full_car_pool_details"("p_car_pool_id" bigint, "p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET search_path = 'public'
AS $$

WITH car_pool_context AS (
    SELECT
        cp.car_pool_id,
        u.user_id AS driver_user_id,
        u.first_name || ' ' || u.last_name AS driver_name,
        u.email_address AS driver_email,
        u.phone_number AS driver_phone,
        cp.number_of_seats AS total_seats,
        cp.status,
        cp.event_id,
        e.event_title,
        to_char(e.event_date_time_2::timestamp, 'FMDay, DD FMMonth, YYYY at HH24:MI') AS event_date_formatted,
        e.team_id,
        t.team_name,
        cp.created_at
    FROM
        public.car_pool AS cp
    JOIN
        public.users AS u ON cp.user_id = u.user_id
    LEFT JOIN 
        public.events AS e ON cp.event_id = e.event_id
    LEFT JOIN 
        public.teams AS t ON e.team_id = t.team_id
    WHERE
        cp.car_pool_id = p_car_pool_id
),
reserved_members AS (
    SELECT
        jsonb_agg(
            jsonb_build_object(
                'reservation_id', sub.reservation_id,
                'member_id', sub.member_id,
                'member_name', sub.member_name,
                'profile_pic', sub.profile_pic,
                'reserved_at', sub.reserved_at,
                'status', sub.status,
                -- ✅ Key changed back to singular 'associated_user_email'
                'associated_user_email', sub.emails_string, 
                'member_belongs_to_user', sub.belongs_to_user
            ) ORDER BY sub.reserved_at ASC
        ) AS members_list,
        COUNT(sub.member_id) AS reserved_count
    FROM (
        SELECT 
            cpd.id AS reservation_id,
            m.member_id,
            m.first_name || ' ' || m.last_name AS member_name,
            m.profile_pic,
            cpd.created_at AS reserved_at,
            cpd.status,
            -- ✅ Still comma-delimited for your Edge Function's split logic
            string_agg(DISTINCT u_assoc.email_address, ', ') FILTER (WHERE u_assoc.email_address IS NOT NULL) AS emails_string,
            BOOL_OR(u_assoc.user_id = auth.uid()) AS belongs_to_user
        FROM
            public.car_pool_detail AS cpd
        JOIN
            public.members AS m ON cpd.member_id = m.member_id
        LEFT JOIN 
            public.user_member_link uml ON m.member_id = uml.member_id
        LEFT JOIN 
            public.users u_assoc ON uml.user_id = u_assoc.user_id
        WHERE
            cpd.car_pool_id = p_car_pool_id
        GROUP BY 
            cpd.id, m.member_id, m.first_name, m.last_name, m.profile_pic, cpd.created_at, cpd.status
    ) sub
),
user_eligible_members AS (
    SELECT 
        jsonb_agg(
            jsonb_build_object(
                'member_id', m.member_id,
                'member_name', m.first_name || ' ' || m.last_name,
                'profile_pic', m.profile_pic
            )
        ) AS eligible_list,
        COUNT(DISTINCT m.member_id) AS player_count
    FROM 
        public.user_member_link uml
    JOIN 
        public.members m ON uml.member_id = m.member_id
    JOIN 
        public.member_team_link mtl ON m.member_id = mtl.member_id
    JOIN 
        public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN 
        public.roles r ON mtrl.role_id = r.role_id
    WHERE 
        uml.user_id = auth.uid()
        AND mtl.team_id = (SELECT team_id FROM car_pool_context)
        AND r.role_level = 10
)
SELECT
    jsonb_build_object(
        'car_pool_id', ctx.car_pool_id,
        'driver_user_id', ctx.driver_user_id,
        'driver_name', ctx.driver_name,
        'driver_email', ctx.driver_email,
        'driver_phone', ctx.driver_phone,
        'event_title', ctx.event_title,
        'event_date_formatted', ctx.event_date_formatted,
        'team_name', ctx.team_name,
        'total_seats', ctx.total_seats,
        'reserved_seats', COALESCE(rm.reserved_count, 0),
        'free_seats', (ctx.total_seats - COALESCE(rm.reserved_count, 0)),
        'status', ctx.status,
        'event_id', ctx.event_id,
        'team_id', ctx.team_id,
        'created_at', ctx.created_at,
        'reservations', COALESCE(rm.members_list, '[]'::jsonb),
        'user_associated_members', COALESCE(uem.eligible_list, '[]'::jsonb),
        'associated_players_count', COALESCE(uem.player_count, 0)
    )
FROM
    car_pool_context AS ctx
CROSS JOIN
    reserved_members AS rm
CROSS JOIN
    user_eligible_members AS uem;

$$;

CREATE OR REPLACE FUNCTION "public"."create_match_squad_from_attendance"("p_event_id" bigint, "p_user_id" "uuid") RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET search_path = 'public'
AS $$
DECLARE
    v_new_match_squad_id int8;
    v_team_id int8;
    v_lookup_code_id int8;
    v_member_record RECORD;
    v_squad_id_final int8;
BEGIN
    -- 1. Identify Team context
    SELECT e.team_id
    INTO v_team_id
    FROM public.events e
    WHERE e.event_id = p_event_id;

    -- 2. Use the helper function to determine the correct event code
    v_lookup_code_id := public.get_updated_event_code(p_event_id);

    -- 3. Create the parent Match Squad record
    INSERT INTO public.match_squads (event_id, user_id)
    VALUES (p_event_id, auth.uid())
    RETURNING match_squad_id INTO v_new_match_squad_id;

    -- 4. Loop through the MOST RECENT response for members with role_grade = 10
    FOR v_member_record IN 
        SELECT DISTINCT ON (ea.member_id) 
            ea.member_id, 
            ea.response_id,
            mtrl.role_id
        FROM public.event_attendance ea
        INNER JOIN public.member_team_link mtl ON (ea.member_id = mtl.member_id AND mtl.team_id = v_team_id)
        JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN public.roles r ON mtrl.role_id = r.role_id
        WHERE ea.event_id = p_event_id 
          AND r.role_grade = 10  -- Filtered to only include players/audience
        ORDER BY ea.member_id, ea.created_at DESC 
    LOOP
        -- 5. ONLY proceed if the latest response is "Accept" (3)
        IF v_member_record.response_id = 3 THEN
            
            -- Find the squad they belong to for this specific code/team
            v_squad_id_final := NULL;
            SELECT squad_id INTO v_squad_id_final
            FROM public.member_squad_link
            WHERE member_id = v_member_record.member_id 
              AND team_id = v_team_id 
              AND code_id = v_lookup_code_id
            LIMIT 1;

            -- Safety check: don't allow 0 to break foreign keys
            IF v_squad_id_final = 0 THEN v_squad_id_final := NULL; END IF;

            -- 6. Insert the detail record
            INSERT INTO public.match_squad_details (
                match_squad_id, 
                event_id, 
                user_id, 
                team_id, 
                squad_id, 
                member_id, 
                role_id
            )
            VALUES (
                v_new_match_squad_id, 
                p_event_id, 
                auth.uid(), 
                v_team_id, 
                v_squad_id_final, 
                v_member_record.member_id, 
                v_member_record.role_id
            );
        END IF;
    END LOOP;

    RETURN v_new_match_squad_id;
END;
$$;
