-- Payment reminders from the v3 Payments page: one in-app / push notification
-- per user who looks after an attending player with no confirmed payment for
-- the event. Rows go into public.notifications exactly like the attendance
-- reminders written by populate_event_notifications (action NULL, so the
-- existing apps show them as plain notifications and the push batch picks
-- them up). Additive: a new function only, nothing existing changes.

CREATE OR REPLACE FUNCTION public.send_event_payment_reminders(p_event_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $function$
DECLARE
    v_sent    integer := 0;
    v_members integer := 0;
BEGIN
    IF NOT public.is_event_admin(p_event_id) THEN
        RETURN jsonb_build_object('success', false,
                                  'message', 'Only team admins can send reminders');
    END IF;

    INSERT INTO public.notifications (
        recipient_user_id, team_id, event_id, link_page,
        is_delivered, is_read, delivery_method, created_at,
        push_title, push_body, app_title, app_body, action
    )
    WITH target_event AS (
        SELECT
            e.event_id,
            e.team_id,
            t.team_name,
            COALESCE(e.payment_amount, 0) AS payment_amount,
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
            to_char(e.event_date_time, 'Dy FMDD Mon, HH24:MI') AS date_time_formatted
        FROM public.events e
        JOIN public.teams t ON e.team_id = t.team_id
        LEFT JOIN public.event_codes ec ON e.event_code_id = ec.code_id
        LEFT JOIN public.event_types et ON e.event_type_id = et.event_type_id
        WHERE e.event_id = p_event_id
    ),
    unpaid AS (
        SELECT
            m.member_id,
            m.first_name AS member_fname,
            u.user_id,
            u.fcm_token
        FROM public.get_accepted_unpaid_members(p_event_id) up
        JOIN public.members m ON m.member_id = up.member_id
        JOIN public.user_member_link uml
             ON uml.member_id = m.member_id AND uml.status = 'active'
        JOIN public.users u ON u.user_id = uml.user_id
        WHERE u.deleted_at IS NULL
    ),
    per_user AS (
        SELECT
            up.user_id,
            up.fcm_token,
            te.team_id,
            te.event_id,
            te.team_name,
            te.display_title,
            te.date_time_formatted,
            te.payment_amount,
            COUNT(up.member_id) AS member_count,
            CASE
                WHEN COUNT(up.member_id) = 1 THEN MAX(up.member_fname)
                WHEN COUNT(up.member_id) = 2 THEN MIN(up.member_fname) || ' and ' || MAX(up.member_fname)
                ELSE (
                    SELECT string_agg(member_fname, ', ' ORDER BY member_fname)
                    FROM (
                        SELECT member_fname
                        FROM unpaid u2
                        WHERE u2.user_id = up.user_id
                        ORDER BY member_fname
                        LIMIT (COUNT(up.member_id) - 1)
                    ) all_but_last
                ) || ' and ' || (
                    SELECT member_fname
                    FROM unpaid u3
                    WHERE u3.user_id = up.user_id
                    ORDER BY member_fname DESC
                    LIMIT 1
                )
            END AS member_name_list
        FROM unpaid up
        CROSS JOIN target_event te
        GROUP BY up.user_id, up.fcm_token, te.team_id, te.event_id, te.team_name,
                 te.display_title, te.date_time_formatted, te.payment_amount
    )
    SELECT
        pu.user_id,
        pu.team_id,
        pu.event_id,
        'Notifications',
        false,
        false,
        CASE WHEN pu.fcm_token IS NOT NULL AND pu.fcm_token <> '' THEN 'push' ELSE 'email' END,
        timezone('utc', now()),
        pu.team_name,
        'Payment due for ' || pu.member_name_list || ' — ' || trim(pu.display_title),
        'Payment due for ' || pu.member_name_list,
        'Please pay €' || to_char(pu.payment_amount * pu.member_count / 100.0, 'FM999990.00') ||
            ' for ' || pu.member_name_list || ' for: ' || trim(pu.display_title) ||
            ' on ' || pu.date_time_formatted || '. Open the event to pay.',
        NULL
    FROM per_user pu;

    GET DIAGNOSTICS v_sent = ROW_COUNT;

    SELECT COUNT(*) INTO v_members FROM public.get_accepted_unpaid_members(p_event_id);

    RETURN jsonb_build_object('success', true, 'sent', v_sent, 'members', v_members);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.send_event_payment_reminders(bigint) TO authenticated;
