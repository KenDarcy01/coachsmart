-- Remove "Your team manager is waiting on your response." from the action-required
-- box in the notification email body.

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
    v_logo_url TEXT := 'https://gyfporsbdftvtakdvukt.supabase.co/storage/v1/object/sign/coachsmartimages/CoachSmart%20Logo%20Transparent.png?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV82OTA4NmRkYy01MWQ3LTQ1NzUtYWYwMC1mZjQxYmMyNDU2YWMiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJjb2FjaHNtYXJ0aW1hZ2VzL0NvYWNoU21hcnQgTG9nbyBUcmFuc3BhcmVudC5wbmciLCJpYXQiOjE3NzQ2MDYzOTksImV4cCI6MjYzODYwNjM5OX0.20yMzSYnG08kYjMK6cmGMvwA6VPGvm9_yHG-CmEfSIs';
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
        false,  -- is_read

        CASE
            WHEN cpu.fcm_token IS NOT NULL AND cpu.fcm_token <> ''
            THEN 'push'
            ELSE 'email'
        END,

        NOW(),

        -- push_title
        cpu.team_name,

        -- push_body
        CASE
            WHEN cpu.member_count = 1 THEN
                'Attendance response needed for ' || cpu.member_name_list || ' — ' || trim(cpu.display_title)
            ELSE
                'Attendance responses needed for ' || cpu.member_name_list || ' — ' || trim(cpu.display_title)
        END,

        -- email_title
        cpu.team_name || ': ' ||
        CASE
            WHEN cpu.member_count = 1 THEN 'Response needed for ' || cpu.member_name_list
            ELSE 'Responses needed for ' || cpu.member_name_list
        END,

        -- email_body
        '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>CoachSmart</title></head>' ||
        '<body style="margin:0;padding:0;background-color:#111418;font-family:Arial,Helvetica,sans-serif;">' ||
        '<table width="100%" cellpadding="0" cellspacing="0" style="padding:40px 20px;"><tr><td align="center">' ||
        '<table width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background-color:#212529;border-radius:16px;overflow:hidden;border:1px solid #3a3f4b;">' ||

        '<tr><td style="background-color:#1E222B;padding:28px 24px;text-align:center;border-bottom:3px solid #87C232;">' ||
        '<table cellpadding="0" cellspacing="0" style="margin:0 auto;"><tr>' ||
        '<td style="padding-right:16px;vertical-align:middle;">' ||
        '<img src="' || v_logo_url || '" alt="CoachSmart" width="80" style="display:block;height:auto;border:0;"></td>' ||
        '<td style="vertical-align:middle;text-align:left;">' ||
        '<p style="margin:0;font-size:26px;font-weight:900;letter-spacing:2.5px;line-height:1;font-family:Arial,Helvetica,sans-serif;">' ||
        '<span style="color:#c8ccd0;">COACH</span><span style="color:#87C232;">SMART</span></p>' ||
        '<p style="margin:5px 0 0 0;font-size:9px;font-weight:700;letter-spacing:4px;color:#87C232;font-family:Arial,Helvetica,sans-serif;">COACHING&nbsp;&nbsp;MADE&nbsp;&nbsp;SIMPLE</p>' ||
        '</td></tr></table></td></tr>' ||

        '<tr><td style="padding:28px 28px 24px;">' ||
        '<p style="margin:0 0 6px 0;font-size:15px;color:#e7ebee;font-family:Arial,Helvetica,sans-serif;">Hi ' || cpu.user_fname || ',</p>' ||

        CASE
            WHEN cpu.member_count = 1 THEN
                '<p style="margin:0 0 20px 0;font-size:14px;color:#a3a3a3;line-height:1.6;font-family:Arial,Helvetica,sans-serif;">' ||
                'A response is still needed for <strong style="color:#e7ebee;">' || cpu.member_name_list || '</strong> for the following event:</p>'
            ELSE
                '<p style="margin:0 0 20px 0;font-size:14px;color:#a3a3a3;line-height:1.6;font-family:Arial,Helvetica,sans-serif;">' ||
                'Responses are still needed for <strong style="color:#e7ebee;">' || cpu.member_name_list || '</strong> for the following event:</p>'
        END ||

        '<table width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 22px 0;"><tr>' ||
        '<td style="background:#2c313a;border-left:3px solid #87C232;padding:16px 18px;border-radius:0 8px 8px 0;">' ||
        '<p style="margin:0 0 5px 0;color:#e7ebee;font-size:15px;font-weight:700;font-family:Arial,Helvetica,sans-serif;">' || trim(cpu.display_title) || '</p>' ||
        '<p style="margin:0;color:#a3a3a3;font-size:13px;font-family:Arial,Helvetica,sans-serif;">' || cpu.date_time_formatted || '</p>' ||
        '</td></tr></table>' ||

        '<table width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 4px 0;"><tr>' ||
        '<td style="background:#2c313a;border-radius:8px;padding:16px 18px;border:1px solid #3a3f4b;">' ||
        '<p style="margin:0 0 4px 0;font-size:13px;font-weight:700;color:#87C232;font-family:Arial,Helvetica,sans-serif;letter-spacing:0.5px;">ACTION REQUIRED</p>' ||
        '<p style="margin:0;font-size:13px;color:#a3a3a3;line-height:1.6;font-family:Arial,Helvetica,sans-serif;">' ||
        'Please open the <strong style="color:#e7ebee;">CoachSmart app</strong> on your device to confirm attendance.</p>' ||
        '</td></tr></table>' ||

        '</td></tr>' ||

        '<tr><td style="padding:16px 28px;border-top:1px solid #3a3f4b;text-align:center;">' ||
        '<p style="margin:0 0 4px 0;font-size:11px;color:#555;letter-spacing:1.5px;font-family:Arial,Helvetica,sans-serif;">COACHSMART &middot; COACHING MADE SIMPLE</p>' ||
        '<p style="margin:0;font-size:11px;color:#444;font-family:Arial,Helvetica,sans-serif;">You received this because you are a member of a CoachSmart team.</p>' ||
        '</td></tr>' ||

        '</table></td></tr></table></body></html>',

        -- app_title
        CASE
            WHEN cpu.member_count = 1 THEN 'Response needed for ' || cpu.member_name_list
            ELSE 'Responses needed for ' || cpu.member_name_list
        END,

        -- app_body
        CASE
            WHEN cpu.member_count = 1 THEN
                'Please confirm attendance for ' || cpu.member_name_list ||
                ' for: ' || trim(cpu.display_title) || ' on ' || cpu.date_time_formatted
            ELSE
                'Please confirm attendance for ' || cpu.member_name_list ||
                ' for: ' || trim(cpu.display_title) || ' on ' || cpu.date_time_formatted
        END

    FROM consolidated_per_user cpu;

    GET DIAGNOSTICS created_count = ROW_COUNT;

    IF created_count > 0 AND auth.uid() IS NOT NULL THEN
        INSERT INTO public.reminders (event_id, user_id, result)
        VALUES (p_event_id_param, auth.uid(), created_count::text || ' reminders sent.');
    END IF;

    RETURN QUERY SELECT created_count;
END;
$$;
