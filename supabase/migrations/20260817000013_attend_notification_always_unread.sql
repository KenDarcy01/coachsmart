-- populate_event_notifications previously set is_read = true immediately for
-- email users (no FCM token) to keep their badge count clean. Now that attend
-- notifications have in-app Attend/Decline action buttons, email users also
-- need the notification to stay unread until they complete the action.
-- Fix: always insert attend notifications with is_read = false. The notification
-- is marked read by mark_notification_read after the user taps Attend or Decline.

CREATE OR REPLACE FUNCTION public.populate_event_notifications(
    p_event_id_param integer,
    p_role_grade      integer DEFAULT NULL::integer,
    p_role_level      integer DEFAULT NULL::integer
)
RETURNS TABLE(notifications_created integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    created_count INT := 0;
BEGIN
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
        app_title,
        app_body,
        action
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
                        WHEN et.event_type_id = 2 AND e.opposition IS NOT NULL AND e.opposition <> ''
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
    unresponded_members AS (
        SELECT
            m.member_id,
            m.first_name AS member_fname,
            u.user_id,
            u.first_name AS user_fname,
            u.fcm_token,
            r.role_grade,
            r.role_level
        FROM target_event te
        JOIN public.member_team_link mtl ON te.team_id = mtl.team_id
        JOIN public.members m ON mtl.member_id = m.member_id
        JOIN public.user_member_link uml ON m.member_id = uml.member_id
        JOIN public.users u ON uml.user_id = u.user_id
        LEFT JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        LEFT JOIN public.roles r ON mtrl.role_id = r.role_id
        WHERE
            NOT EXISTS (
                SELECT 1
                FROM public.event_attendance ea
                WHERE ea.event_id = p_event_id_param
                  AND ea.member_id = m.member_id
                  AND ea.response_id IS NOT NULL
                  AND ea.response_id > 0
            )
            AND (p_role_grade IS NULL OR r.role_grade = p_role_grade)
            AND (p_role_level IS NULL OR r.role_level >= p_role_level)
    ),
    consolidated_per_user AS (
        SELECT
            um.user_id,
            um.user_fname,
            um.fcm_token,
            te.team_id,
            te.event_id,
            te.team_name,
            te.display_title,
            te.date_time_formatted,
            COUNT(um.member_id) AS member_count,
            CASE
                WHEN COUNT(um.member_id) = 1 THEN
                    MAX(um.member_fname)
                WHEN COUNT(um.member_id) = 2 THEN
                    MIN(um.member_fname) || ' and ' || MAX(um.member_fname)
                ELSE
                    (
                        SELECT string_agg(member_fname, ', ' ORDER BY member_fname)
                        FROM (
                            SELECT member_fname
                            FROM unresponded_members um2
                            WHERE um2.user_id = um.user_id
                            ORDER BY member_fname
                            LIMIT (COUNT(um.member_id) - 1)
                        ) all_but_last
                    ) || ' and ' || (
                        SELECT member_fname
                        FROM unresponded_members um3
                        WHERE um3.user_id = um.user_id
                        ORDER BY member_fname DESC
                        LIMIT 1
                    )
            END AS member_name_list
        FROM unresponded_members um
        CROSS JOIN target_event te
        GROUP BY
            um.user_id,
            um.user_fname,
            um.fcm_token,
            te.team_id,
            te.event_id,
            te.team_name,
            te.display_title,
            te.date_time_formatted
    )
    SELECT
        cpu.user_id,
        cpu.team_id,
        cpu.event_id,
        'coachsmartv2://coachsmartv2.com/eventDetails?eventID=' || cpu.event_id::text || '&fromSearch=false',
        false,  -- is_delivered
        false,  -- is_read: always false — cleared by mark_notification_read after Attend/Decline
        CASE
            WHEN cpu.fcm_token IS NOT NULL AND cpu.fcm_token <> '' THEN 'push'
            ELSE 'email'
        END,
        NOW(),
        cpu.team_name,
        CASE
            WHEN cpu.member_count = 1 THEN
                'Attendance response needed for ' || cpu.member_name_list || ' — ' || trim(cpu.display_title)
            ELSE
                'Attendance responses needed for ' || cpu.member_name_list || ' — ' || trim(cpu.display_title)
        END,
        CASE
            WHEN cpu.member_count = 1 THEN 'Response needed for ' || cpu.member_name_list
            ELSE 'Responses needed for ' || cpu.member_name_list
        END,
        CASE
            WHEN cpu.member_count = 1 THEN
                'Please confirm attendance for ' || cpu.member_name_list ||
                ' for: ' || trim(cpu.display_title) || ' on ' || cpu.date_time_formatted
            ELSE
                'Please confirm attendance for ' || cpu.member_name_list ||
                ' for: ' || trim(cpu.display_title) || ' on ' || cpu.date_time_formatted
        END,
        'attend'
    FROM consolidated_per_user cpu;

    GET DIAGNOSTICS created_count = ROW_COUNT;

    IF created_count > 0 AND auth.uid() IS NOT NULL THEN
        INSERT INTO public.reminders (event_id, user_id, result)
        VALUES (p_event_id_param, auth.uid(), created_count::text || ' reminders sent.');
    END IF;

    RETURN QUERY SELECT created_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.populate_event_notifications(integer, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.populate_event_notifications(integer, integer, integer) TO service_role;
