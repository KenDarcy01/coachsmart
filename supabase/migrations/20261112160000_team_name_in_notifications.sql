-- Team name in every notification (Ken, 2026-11-12).
-- Wording only: every push title starts with the team, and every push and
-- in-app body names the team. No columns, rows, rules or recipients change.
-- The email subject and email card get the team in cron_batch_notification_send.
-- CREATE OR REPLACE keeps each function's existing grants.

-- ---------------------------------------------------------------------------
-- Attendance reminder (Send reminder), v2 and v3
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.populate_event_notifications(p_event_id_param integer, p_role_grade integer DEFAULT NULL::integer, p_role_level integer DEFAULT NULL::integer)
 RETURNS TABLE(notifications_created integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
            e.squad_id,
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
            to_char(e.event_date_time, 'Dy FMDD Mon, HH24:MI') AS date_time_formatted
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
        JOIN public.member_team_link mtl ON te.team_id = mtl.team_id AND mtl.status = 'active'
        JOIN public.members m ON mtl.member_id = m.member_id
        JOIN public.user_member_link uml ON m.member_id = uml.member_id AND uml.status = 'active'
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
            AND (
                te.squad_id IS NULL
                OR EXISTS (
                    SELECT 1 FROM public.member_squad_link msl
                    WHERE msl.member_id = m.member_id
                      AND msl.squad_id  = te.squad_id
                      AND msl.code_id   = public.get_updated_event_code(p_event_id_param)
                )
            )
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
        'Notifications',
        false,  -- is_delivered
        false,  -- is_read: always false — cleared by mark_notification_read after Attend/Decline
        CASE
            WHEN cpu.fcm_token IS NOT NULL AND cpu.fcm_token <> '' THEN 'push'
            ELSE 'email'
        END,
        NOW(),
        -- push_title: "Clontarf Boys 2015: Response needed"
        cpu.team_name || ': ' ||
            CASE WHEN cpu.member_count = 1 THEN 'Response needed' ELSE 'Responses needed' END,
        -- push_body: "Response needed for Aaron: Football Training for Clontarf Boys 2015, Thu 13 Nov, 18:30."
        CASE WHEN cpu.member_count = 1 THEN 'Response needed for ' ELSE 'Responses needed for ' END ||
            cpu.member_name_list || ': ' || trim(cpu.display_title) ||
            ' for ' || cpu.team_name || ', ' || cpu.date_time_formatted || '.',
        -- app_title unchanged (the app shows the team beside it; email adds it)
        CASE
            WHEN cpu.member_count = 1 THEN 'Response needed for ' || cpu.member_name_list
            ELSE 'Responses needed for ' || cpu.member_name_list
        END,
        'Please confirm attendance for ' || cpu.member_name_list ||
            ' for ' || cpu.team_name || ': ' || trim(cpu.display_title) ||
            ' on ' || cpu.date_time_formatted || '.',
        'attend'
    FROM consolidated_per_user cpu;

    GET DIAGNOSTICS created_count = ROW_COUNT;

    IF created_count > 0 AND auth.uid() IS NOT NULL THEN
        INSERT INTO public.reminders (event_id, user_id, result)
        VALUES (p_event_id_param, auth.uid(), created_count::text || ' reminders sent.');
    END IF;

    RETURN QUERY SELECT created_count;
END;
$function$;

-- ---------------------------------------------------------------------------
-- Admin attendance alert, v2 and v3
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_admins_attendance_change(p_event_id_param integer, p_member_id_param integer, p_response_id integer, p_attendance_id bigint)
 RETURNS TABLE(notifications_created integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    created_count         INT := 0;
    v_notify_all          BOOLEAN;
    v_notify_changes      BOOLEAN;
    v_prev_response_id    BIGINT;
    v_is_change_of_mind   BOOLEAN := false;
    v_response_word       TEXT;
    v_prev_response_word  TEXT;
    v_event_exists        BOOLEAN := false;
    v_member_exists       BOOLEAN := false;
    v_actor_user_id       UUID;
BEGIN
    SELECT
        true,
        COALESCE(notify_admins_all, false),
        COALESCE(notify_admins_changes, false)
    INTO v_event_exists, v_notify_all, v_notify_changes
    FROM public.events
    WHERE event_id = p_event_id_param;

    IF NOT v_event_exists THEN
        RETURN QUERY SELECT 0;
        RETURN;
    END IF;

    IF NOT v_notify_all AND NOT v_notify_changes THEN
        RETURN QUERY SELECT 0;
        RETURN;
    END IF;

    SELECT true INTO v_member_exists
    FROM public.members
    WHERE member_id = p_member_id_param;

    IF NOT v_member_exists THEN
        RETURN QUERY SELECT 0;
        RETURN;
    END IF;

    -- The person answering: the signed-in user, or (no JWT, e.g. PWA) the
    -- account linked to the member, as in 20260608110000.
    v_actor_user_id := auth.uid();
    IF v_actor_user_id IS NULL THEN
        SELECT uml.user_id INTO v_actor_user_id
        FROM public.user_member_link uml
        WHERE uml.member_id = p_member_id_param
        LIMIT 1;
    END IF;

    SELECT response_id
    INTO v_prev_response_id
    FROM public.event_attendance
    WHERE event_id    = p_event_id_param
      AND member_id   = p_member_id_param
      AND attendance_id < p_attendance_id
    ORDER BY attendance_id DESC
    LIMIT 1;

    IF NOT v_notify_all AND v_notify_changes THEN
        IF v_prev_response_id IS NULL THEN
            RETURN QUERY SELECT 0;
            RETURN;
        END IF;
        IF v_prev_response_id = p_response_id THEN
            RETURN QUERY SELECT 0;
            RETURN;
        END IF;
        v_is_change_of_mind := true;
    END IF;

    IF v_notify_all THEN
        IF v_prev_response_id IS NOT NULL AND v_prev_response_id <> p_response_id THEN
            v_is_change_of_mind := true;
        END IF;
    END IF;

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
            to_char(e.event_date_time, 'Dy FMDD Mon, HH24:MI') AS date_time_formatted
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
        JOIN public.member_team_link mtl       ON te.team_id = mtl.team_id AND mtl.status = 'active'
        JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN public.roles r                    ON mtrl.role_id = r.role_id
        JOIN public.members m                  ON mtl.member_id = m.member_id
        JOIN public.user_member_link uml       ON m.member_id = uml.member_id AND uml.status = 'active'
        JOIN public.users u                    ON uml.user_id = u.user_id
        WHERE r.role_grade = 100
          AND m.member_id != p_member_id_param
          AND u.deleted_at IS NULL
          -- Never tell the person who answered about their own answer
          AND u.user_id IS DISTINCT FROM v_actor_user_id
          -- The admin's own setting for this team (no row = as set on the event)
          AND NOT EXISTS (
              SELECT 1 FROM public.admin_alert_prefs ap
              WHERE ap.user_id = u.user_id
                AND ap.team_id = te.team_id
                AND (ap.attendance_alerts = 'off'
                     OR (ap.attendance_alerts = 'changes' AND NOT v_is_change_of_mind))
          )
    ),
    msg AS (
        -- "Aaron Hogan has changed their attendance from accepted to declined for
        --  Clontarf Boys 2015, Football Training, Mon 10 Nov, 18:30."
        -- Keeps "to accepted" / "to declined": the email picks its badge from them.
        SELECT
            CASE
                WHEN v_is_change_of_mind THEN
                    cm.full_name || ' has changed their attendance from ' ||
                    v_prev_response_word || ' to ' || v_response_word || ' for '
                ELSE
                    cm.full_name || ' has ' || v_response_word || ' attendance for '
            END
            || te.team_name || ', ' || trim(te.display_title) || ', ' || te.date_time_formatted || '.'
            AS body
        FROM target_event te
        CROSS JOIN changing_member cm
    )
    SELECT
        au.user_id,
        te.team_id,
        te.event_id,
        'Notifications',
        false,  -- is_delivered
        false,  -- is_read: always false so notification appears as unread in-app
        CASE
            WHEN au.fcm_token IS NOT NULL AND au.fcm_token <> '' THEN 'push'
            ELSE 'email'
        END,
        NOW(),
        te.team_name || ': Change of Attendance',
        mg.body,
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
        mg.body
    FROM admin_users au
    CROSS JOIN target_event te
    CROSS JOIN changing_member cm
    CROSS JOIN msg mg;

    GET DIAGNOSTICS created_count = ROW_COUNT;

    RETURN QUERY SELECT created_count;
END;
$function$;

-- ---------------------------------------------------------------------------
-- Access requests, v2 and v3 (join request titles get the team in the sender)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.request_member_access(p_member_id bigint, p_joining_code text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_caller         uuid := auth.uid();
    v_team_id        bigint;
    v_team_name      text;
    v_first_name     text;
    v_last_name      text;
    v_user_member_id bigint;
    v_clean_code     text := UPPER(TRIM(COALESCE(p_joining_code, '')));
BEGIN
    SELECT team_id, team_name INTO v_team_id, v_team_name
      FROM public.teams
     WHERE UPPER(TRIM(team_unique_code)) = v_clean_code;

    IF v_team_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Invalid joining code.');
    END IF;

    SELECT m.first_name, m.last_name
      INTO v_first_name, v_last_name
      FROM public.members          m
      JOIN public.member_team_link mtl ON m.member_id = mtl.member_id
     WHERE m.member_id  = p_member_id
       AND mtl.team_id  = v_team_id
       AND mtl.status   = 'active';

    IF v_first_name IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Member not found on this team.');
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.user_member_link
         WHERE user_id   = v_caller
           AND member_id = p_member_id
           AND status    IN ('active', 'pending')
    ) THEN
        RETURN json_build_object(
            'success', false,
            'message', 'You already have an active or pending link to this member.'
        );
    END IF;

    INSERT INTO public.user_member_link (user_id, member_id, status)
    VALUES (v_caller, p_member_id, 'pending')
    RETURNING user_member_id INTO v_user_member_id;

    INSERT INTO public.notifications (
        recipient_user_id, team_id,
        app_title, app_body,
        push_title, push_body,
        delivery_method,
        action, action_ref_id, member_id
    )
    SELECT DISTINCT uml2.user_id,
           v_team_id,
           'Access Request',
           (SELECT first_name || ' ' || last_name FROM public.users WHERE user_id = v_caller) ||
               ' has requested access to ' || v_first_name || ' ' || v_last_name ||
               ' on ' || v_team_name || '.',
           v_team_name || ': Access Request',
           (SELECT first_name || ' ' || last_name FROM public.users WHERE user_id = v_caller) ||
               ' has requested access to ' || v_first_name || ' ' || v_last_name ||
               ' on ' || v_team_name || '.',
           'push',
           'approve_access',
           v_user_member_id,
           p_member_id
      FROM public.member_team_link      mtl2
      JOIN public.member_team_role_link mtrl ON mtl2.member_team_id = mtrl.member_team_id
      JOIN public.roles                 r    ON mtrl.role_id    = r.role_id
      JOIN public.user_member_link      uml2 ON mtl2.member_id  = uml2.member_id
     WHERE mtl2.team_id  = v_team_id
       AND mtl2.status   = 'active'
       AND uml2.status   = 'active'
       AND r.role_grade  = 100;

    RETURN json_build_object(
        'success', true,
        'message', 'Your request to access ' || v_first_name || ' ' || v_last_name ||
                   '''s profile has been sent to the ' || v_team_name || ' admin.'
    );

EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$function$;

CREATE OR REPLACE FUNCTION public.confirm_user_member_access(p_user_member_id bigint)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_user_id    uuid;
    v_member_id  bigint;
    v_first_name text;
    v_last_name  text;
    v_team_id    bigint;
    v_team_name  text;
BEGIN
    SELECT uml.user_id, uml.member_id, m.first_name, m.last_name
      INTO v_user_id, v_member_id, v_first_name, v_last_name
      FROM public.user_member_link uml
      JOIN public.members          m ON uml.member_id = m.member_id
     WHERE uml.user_member_id = p_user_member_id
       AND uml.status         = 'pending';

    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Pending request not found.');
    END IF;

    SELECT mtl.team_id, t.team_name INTO v_team_id, v_team_name
      FROM public.member_team_link mtl
      JOIN public.teams            t ON mtl.team_id = t.team_id
     WHERE mtl.member_id = v_member_id
       AND mtl.status    = 'active'
     LIMIT 1;

    UPDATE public.user_member_link
       SET status = 'active'
     WHERE user_member_id = p_user_member_id;

    -- Mark all admin notifications for this request as read so peer admins
    -- see the buttons disabled in real-time.
    UPDATE public.notifications
       SET is_read   = true,
           when_read = now()
     WHERE action        = 'approve_access'
       AND action_ref_id = p_user_member_id
       AND is_read       = false;

    INSERT INTO public.notifications (
        recipient_user_id, team_id,
        app_title, app_body,
        push_title, push_body,
        delivery_method
    )
    VALUES (
        v_user_id, v_team_id,
        'Access Approved',
        'You now have access to ' || v_first_name || ' ' || v_last_name ||
            '''s profile on ' || COALESCE(v_team_name, 'your team') || '.',
        COALESCE(v_team_name || ': ', '') || 'Access Approved',
        'You now have access to ' || v_first_name || ' ' || v_last_name ||
            '''s profile on ' || COALESCE(v_team_name, 'your team') || '.',
        'push'
    );

    RETURN json_build_object('success', true, 'message', 'Access granted.');

EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$function$;

CREATE OR REPLACE FUNCTION public.deny_user_member_access(p_user_member_id bigint)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_user_id    uuid;
    v_member_id  bigint;
    v_first_name text;
    v_last_name  text;
    v_team_id    bigint;
    v_team_name  text;
BEGIN
    SELECT uml.user_id, uml.member_id, m.first_name, m.last_name
      INTO v_user_id, v_member_id, v_first_name, v_last_name
      FROM public.user_member_link uml
      JOIN public.members          m ON uml.member_id = m.member_id
     WHERE uml.user_member_id = p_user_member_id
       AND uml.status         = 'pending';

    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Pending request not found.');
    END IF;

    SELECT mtl.team_id, t.team_name INTO v_team_id, v_team_name
      FROM public.member_team_link mtl
      JOIN public.teams            t ON mtl.team_id = t.team_id
     WHERE mtl.member_id = v_member_id AND mtl.status = 'active'
     LIMIT 1;

    DELETE FROM public.user_member_link WHERE user_member_id = p_user_member_id;

    -- Mark all admin notifications for this request as read so peer admins
    -- see the buttons disabled in real-time.
    UPDATE public.notifications
       SET is_read   = true,
           when_read = now()
     WHERE action        = 'approve_access'
       AND action_ref_id = p_user_member_id
       AND is_read       = false;

    INSERT INTO public.notifications (
        recipient_user_id, team_id,
        app_title, app_body,
        push_title, push_body,
        delivery_method
    )
    VALUES (
        v_user_id, v_team_id,
        'Access Request Not Approved',
        'Your request to access ' || v_first_name || ' ' || v_last_name ||
            '''s profile on ' || COALESCE(v_team_name, 'the team') ||
            ' was not approved. Please contact your team admin.',
        COALESCE(v_team_name || ': ', '') || 'Access Not Approved',
        'Your request to access ' || v_first_name || ' ' || v_last_name ||
            '''s profile on ' || COALESCE(v_team_name, 'the team') || ' was not approved.',
        'push'
    );

    RETURN json_build_object('success', true, 'message', 'Request denied.');

EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$function$;

-- ---------------------------------------------------------------------------
-- v3 only: Tell the team (create, edit, cancel, delete)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_event_change(p_event_id bigint, p_kind text, p_note text DEFAULT NULL::text, p_events integer DEFAULT 1, p_tell boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    e         public.events%ROWTYPE;
    v_team    text;
    v_title   text;
    v_when    text;
    v_head    text;
    v_body    text;
    v_more    text := '';
    v_note    text := NULLIF(trim(COALESCE(p_note, '')), '');
    v_n       int := 0;
    v_cleared int := 0;
    v_attend  boolean := false;
BEGIN
    IF p_kind NOT IN ('created', 'edited', 'cancelled', 'deleted') THEN
        RAISE EXCEPTION 'Unknown change';
    END IF;
    IF auth.uid() IS NULL OR NOT public.is_event_admin(p_event_id) THEN
        RAISE EXCEPTION 'Only team admins can do this';
    END IF;
    SELECT * INTO e FROM public.events WHERE event_id = p_event_id;

    -- Nobody should be asked to reply to an event that is off.
    IF p_kind IN ('cancelled', 'deleted') THEN
        UPDATE public.notifications n
        SET is_read = true, when_read = now(), auto_cleared = 'event_' || p_kind
        WHERE n.action = 'attend' AND n.is_read = false
          AND n.event_id IN (
              SELECT x.event_id FROM public.events x
              WHERE x.event_id = p_event_id
                 OR (COALESCE(p_events, 1) > 1 AND e.series_id IS NOT NULL
                     AND x.series_id = e.series_id
                     AND x.event_date_time >= e.event_date_time
                     AND x.status = e.status));
        GET DIAGNOSTICS v_cleared = ROW_COUNT;
    END IF;

    IF NOT COALESCE(p_tell, false) THEN
        RETURN jsonb_build_object('notified', 0, 'cleared', v_cleared);
    END IF;

    SELECT t.team_name,
        trim(CASE
            WHEN e.event_title IS NOT NULL AND e.event_title <> '' THEN e.event_title
            ELSE (CASE WHEN t.team_female = true AND ec.code_id = 3 THEN 'Camogie'
                       ELSE COALESCE(ec.event_code, '') END)
                 || ' ' || COALESCE(et.event_type, '')
                 || CASE WHEN et.event_type_id = 2 AND COALESCE(e.opposition, '') <> ''
                         THEN ' - ' || e.opposition ELSE '' END
        END),
        to_char(e.event_date_time, 'Dy FMDD Mon, HH24:MI')
    INTO v_team, v_title, v_when
    FROM public.teams t
    LEFT JOIN public.event_codes ec ON ec.code_id = e.event_code_id
    LEFT JOIN public.event_types et ON et.event_type_id = e.event_type_id
    WHERE t.team_id = e.team_id;

    -- A single new event that asks for replies gets the Going / Can't go buttons.
    v_attend := p_kind = 'created' AND COALESCE(p_events, 1) = 1
                AND COALESCE(e.request_attendance, true)
                AND e.event_date_time > now();

    IF COALESCE(p_events, 1) > 1 THEN
        v_more := ', and the ' || (p_events - 1) || ' after it';
    END IF;

    v_head := CASE p_kind
        WHEN 'created' THEN
            CASE WHEN COALESCE(p_events, 1) > 1 THEN p_events || ' new events' ELSE 'New event' END
        WHEN 'edited' THEN 'Event changed'
        WHEN 'cancelled' THEN 'Event cancelled'
        ELSE 'Event removed' END;
    v_body := CASE p_kind
        WHEN 'created' THEN
            CASE WHEN COALESCE(p_events, 1) > 1
                 THEN p_events || ' new events for ' || v_team || ': ' || v_title
                      || ', starting ' || v_when || '.'
                 ELSE 'New ' || v_title || ' for ' || v_team || ', ' || v_when || '.'
                      || CASE WHEN v_attend THEN ' Are you going?' ELSE '' END END
        WHEN 'edited' THEN
            v_title || ' for ' || v_team || ' has changed. It is now ' || v_when || '.'
        WHEN 'cancelled' THEN
            v_title || ' for ' || v_team || ' on ' || v_when || ' is cancelled' || v_more || '.'
        ELSE
            v_title || ' for ' || v_team || ' on ' || v_when || ' has been removed' || v_more || '.'
        END;
    IF v_note IS NOT NULL THEN
        v_body := v_body || ' ' || v_note;
    END IF;

    INSERT INTO public.notifications (
        recipient_user_id, team_id, event_id, link_page,
        is_delivered, is_read, delivery_method, created_at,
        push_title, push_body, app_title, app_body, action)
    SELECT a.user_id, e.team_id,
        CASE WHEN p_kind = 'deleted' THEN NULL ELSE p_event_id END,
        'Notifications', false, false,
        CASE WHEN COALESCE(u.fcm_token, '') <> '' THEN 'push' ELSE 'email' END,
        NOW(),
        v_team || ': ' || v_head, v_body, v_head, v_body,
        CASE WHEN v_attend THEN 'attend' END
    FROM (
        SELECT DISTINCT uml.user_id
        FROM (SELECT DISTINCT member_id FROM public.event_invitee_members(
                  e.team_id, e.audience_id, e.squad_id, e.event_code_id)) m
        JOIN public.user_member_link uml ON uml.member_id = m.member_id AND uml.status = 'active'
        WHERE uml.user_id <> auth.uid()
    ) a
    JOIN public.users u ON u.user_id = a.user_id AND u.deleted_at IS NULL;
    GET DIAGNOSTICS v_n = ROW_COUNT;

    RETURN jsonb_build_object('notified', v_n, 'cleared', v_cleared);
END;
$function$;

-- ---------------------------------------------------------------------------
-- v3 only: Teams are out / Team change
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_event_teams(p_event_id bigint)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_shared  boolean;
    v_ms      bigint;
    v_team_id bigint;
    v_team    text;
    v_title   text;
    v_when    text;
    v_n       int := 0;
BEGIN
    SELECT s.shared INTO v_shared
    FROM public.event_team_shares s WHERE s.event_id = p_event_id;
    IF NOT COALESCE(v_shared, false) THEN
        RETURN 0;
    END IF;

    SELECT msq.match_squad_id INTO v_ms
    FROM public.match_squads msq
    WHERE msq.event_id = p_event_id
    ORDER BY msq.created_at DESC, msq.match_squad_id DESC
    LIMIT 1;
    IF v_ms IS NULL THEN
        RETURN 0;
    END IF;

    SELECT
        e.team_id,
        t.team_name,
        trim(CASE
            WHEN e.event_title IS NOT NULL AND e.event_title <> '' THEN e.event_title
            ELSE (CASE WHEN t.team_female = true AND ec.code_id = 3 THEN 'Camogie'
                       ELSE COALESCE(ec.event_code, '') END)
                 || ' ' || COALESCE(et.event_type, '')
                 || CASE WHEN et.event_type_id = 2 AND COALESCE(e.opposition, '') <> ''
                         THEN ' - ' || e.opposition ELSE '' END
        END),
        to_char(e.event_date_time, 'Dy FMDD Mon')
    INTO v_team_id, v_team, v_title, v_when
    FROM public.events e
    JOIN public.teams t ON t.team_id = e.team_id
    LEFT JOIN public.event_codes ec ON ec.code_id = e.event_code_id
    LEFT JOIN public.event_types et ON et.event_type_id = e.event_type_id
    WHERE e.event_id = p_event_id;

    WITH cur AS (
        SELECT DISTINCT ON (d.member_id)
            d.member_id,
            CASE WHEN sq.squad_id IS NULL OR sq.squad_name ILIKE 'no team' THEN NULL
                 ELSE sq.squad_id END AS squad_id,
            sq.squad_name
        FROM public.match_squad_details d
        LEFT JOIN public.squads sq ON sq.squad_id = d.squad_id
        WHERE d.match_squad_id = v_ms AND d.member_id IS NOT NULL
        ORDER BY d.member_id, d.id DESC
    ),
    chg AS (
        SELECT c.member_id, c.squad_name,
               (s.member_id IS NULL OR s.squad_id IS NULL) AS first_time
        FROM cur c
        LEFT JOIN public.event_team_share_sent s
               ON s.event_id = p_event_id AND s.member_id = c.member_id
        WHERE c.squad_id IS NOT NULL
          AND (s.member_id IS NULL OR s.squad_id IS DISTINCT FROM c.squad_id)
    ),
    lines AS (
        SELECT DISTINCT uml.user_id, ch.member_id, ch.first_time,
            COALESCE(NULLIF(trim(m.first_name), ''), 'Your player')
              || CASE WHEN ch.first_time THEN ' is on ' ELSE ' has moved to ' END
              || ch.squad_name AS line
        FROM chg ch
        JOIN public.members m ON m.member_id = ch.member_id
        JOIN public.user_member_link uml
          ON uml.member_id = ch.member_id AND uml.status = 'active'
    ),
    per_user AS (
        SELECT user_id,
               string_agg(line, ', ' ORDER BY line) AS body,
               bool_or(first_time) AS any_first,
               min(member_id) AS one_member,
               count(DISTINCT member_id) AS n
        FROM lines
        GROUP BY user_id
    )
    INSERT INTO public.notifications (
        recipient_user_id, team_id, event_id, member_id, link_page,
        is_delivered, is_read, delivery_method, created_at,
        push_title, push_body, app_title, app_body)
    SELECT u.user_id, v_team_id, p_event_id,
        CASE WHEN p.n = 1 THEN p.one_member END,
        'Notifications', false, false,
        CASE WHEN COALESCE(u.fcm_token, '') <> '' THEN 'push' ELSE 'email' END,
        NOW(),
        v_team || ': ' || CASE WHEN p.any_first THEN 'Teams are out' ELSE 'Team change' END,
        v_team || ', ' || v_title || ', ' || v_when || ': ' || p.body || '.',
        CASE WHEN p.any_first THEN 'Teams are out' ELSE 'Team change' END,
        v_team || ', ' || v_title || ', ' || v_when || ': ' || p.body || '.'
    FROM per_user p
    JOIN public.users u ON u.user_id = p.user_id AND u.deleted_at IS NULL;
    GET DIAGNOSTICS v_n = ROW_COUNT;

    -- Remember what every family now knows.
    INSERT INTO public.event_team_share_sent (event_id, member_id, squad_id, sent_at)
    SELECT p_event_id, c.member_id, c.squad_id, now()
    FROM (
        SELECT DISTINCT ON (d.member_id)
            d.member_id,
            CASE WHEN sq.squad_id IS NULL OR sq.squad_name ILIKE 'no team' THEN NULL
                 ELSE sq.squad_id END AS squad_id
        FROM public.match_squad_details d
        LEFT JOIN public.squads sq ON sq.squad_id = d.squad_id
        WHERE d.match_squad_id = v_ms AND d.member_id IS NOT NULL
        ORDER BY d.member_id, d.id DESC
    ) c
    ON CONFLICT (event_id, member_id) DO UPDATE
        SET squad_id = EXCLUDED.squad_id, sent_at = now()
        WHERE public.event_team_share_sent.squad_id IS DISTINCT FROM EXCLUDED.squad_id;

    RETURN v_n;
END;
$function$;

-- ---------------------------------------------------------------------------
-- v3 only: car pool
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.car_pool_notify(p_car_pool_id bigint, p_kind text, p_member_id bigint)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_me        uuid := auth.uid();
    v_driver    uuid;
    v_event_id  bigint;
    v_team_id   bigint;
    v_team      text;
    v_title     text;
    v_when      text;
    v_ev        text;
    v_driver_nm text;
    v_phone     text;
    v_member    text;
    v_linked    boolean;
    v_rows      int := 0;
    v_n         int;
BEGIN
    IF v_me IS NULL THEN
        RAISE EXCEPTION 'Not signed in';
    END IF;
    IF p_kind NOT IN ('reserved', 'cancelled', 'pool_cancelled') THEN
        RAISE EXCEPTION 'Unknown kind %', p_kind;
    END IF;

    SELECT cp.user_id, cp.event_id INTO v_driver, v_event_id
    FROM public.car_pool cp WHERE cp.car_pool_id = p_car_pool_id;
    IF v_driver IS NULL THEN
        RETURN 0;
    END IF;

    SELECT
        e.team_id,
        t.team_name,
        trim(CASE
            WHEN e.event_title IS NOT NULL AND e.event_title <> '' THEN e.event_title
            ELSE (CASE WHEN t.team_female = true AND ec.code_id = 3 THEN 'Camogie'
                       ELSE COALESCE(ec.event_code, '') END)
                 || ' ' || COALESCE(et.event_type, '')
                 || CASE WHEN et.event_type_id = 2 AND COALESCE(e.opposition, '') <> ''
                         THEN ' - ' || e.opposition ELSE '' END
        END),
        to_char(e.event_date_time, 'Dy FMDD Mon, HH24:MI')
    INTO v_team_id, v_team, v_title, v_when
    FROM public.events e
    JOIN public.teams t ON t.team_id = e.team_id
    LEFT JOIN public.event_codes ec ON ec.code_id = e.event_code_id
    LEFT JOIN public.event_types et ON et.event_type_id = e.event_type_id
    WHERE e.event_id = v_event_id;

    -- "Clontarf Boys 2015, Football Match - Ballymun, Sat 15 Nov, 10:00"
    v_ev := v_team || ', ' || v_title || ', ' || v_when;

    SELECT NULLIF(trim(COALESCE(first_name, '') || ' ' || COALESCE(last_name, '')), ''),
           NULLIF(trim(COALESCE(phone_number, '')), '')
    INTO v_driver_nm, v_phone
    FROM public.users WHERE user_id = v_driver;
    v_driver_nm := COALESCE(v_driver_nm, 'the driver');

    SELECT COALESCE(NULLIF(trim(COALESCE(first_name, '') || ' ' || COALESCE(last_name, '')), ''), 'A player')
    INTO v_member
    FROM public.members WHERE member_id = p_member_id;
    v_member := COALESCE(v_member, 'A player');

    SELECT EXISTS (
        SELECT 1 FROM public.user_member_link
        WHERE member_id = p_member_id AND user_id = v_me AND status = 'active'
    ) INTO v_linked;

    -- Only the people involved can trigger a message.
    IF p_kind = 'reserved' AND NOT v_linked THEN
        RAISE EXCEPTION 'Not your player';
    END IF;
    IF p_kind = 'cancelled' AND NOT v_linked AND v_me <> v_driver THEN
        RAISE EXCEPTION 'Not your seat';
    END IF;
    IF p_kind = 'pool_cancelled' AND v_me <> v_driver THEN
        RAISE EXCEPTION 'Not your car pool';
    END IF;

    -- Driver
    IF p_kind IN ('reserved', 'cancelled') THEN
        INSERT INTO public.notifications (
            recipient_user_id, team_id, event_id, member_id, link_page,
            is_delivered, is_read, delivery_method, created_at,
            push_title, push_body, app_title, app_body)
        SELECT u.user_id, v_team_id, v_event_id, p_member_id, 'Notifications',
            false, false,
            CASE WHEN COALESCE(u.fcm_token, '') <> '' THEN 'push' ELSE 'email' END,
            NOW(),
            v_team || ': Car pool',
            CASE p_kind
                WHEN 'reserved' THEN v_member || ' has reserved a seat in your car pool for ' || v_ev || '.'
                ELSE v_member || ' has cancelled their seat in your car pool for ' || v_ev || '.'
            END,
            CASE p_kind WHEN 'reserved' THEN 'Car pool seat reserved' ELSE 'Car pool seat cancelled' END,
            CASE p_kind
                WHEN 'reserved' THEN v_member || ' has reserved a seat in your car pool for ' || v_ev || '.'
                ELSE v_member || ' has cancelled their seat in your car pool for ' || v_ev || '.'
            END
        FROM public.users u
        WHERE u.user_id = v_driver AND u.deleted_at IS NULL;
        GET DIAGNOSTICS v_n = ROW_COUNT;
        v_rows := v_rows + v_n;
    END IF;

    -- Parent / player side: the caller for 'reserved' (as v2), the member's
    -- account(s) otherwise.
    INSERT INTO public.notifications (
        recipient_user_id, team_id, event_id, member_id, link_page,
        is_delivered, is_read, delivery_method, created_at,
        push_title, push_body, app_title, app_body)
    SELECT DISTINCT u.user_id, v_team_id, v_event_id, p_member_id, 'Notifications',
        false, false,
        CASE WHEN COALESCE(u.fcm_token, '') <> '' THEN 'push' ELSE 'email' END,
        NOW(),
        v_team || ': Car pool',
        x.body,
        x.title,
        x.body
    FROM public.users u
    CROSS JOIN LATERAL (
        SELECT
            CASE p_kind
                WHEN 'reserved' THEN 'Car pool seat reserved'
                WHEN 'cancelled' THEN 'Car pool seat cancelled'
                ELSE 'Car pool cancelled'
            END AS title,
            CASE p_kind
                WHEN 'reserved' THEN
                    'A seat is reserved with ' || v_driver_nm || ' for ' || v_member || ' for ' || v_ev ||
                    CASE WHEN v_phone IS NOT NULL THEN '. Please contact them on ' || v_phone || ' to finalise plans.' ELSE '.' END
                WHEN 'cancelled' THEN
                    'The car pool seat with ' || v_driver_nm || ' for ' || v_member || ' has been cancelled for ' || v_ev || '.'
                ELSE
                    'The car pool with ' || v_driver_nm || ' for ' || v_member || ' has been cancelled for ' || v_ev ||
                    '. Please look for another car pool if you still need a lift.'
            END AS body
    ) x
    WHERE u.deleted_at IS NULL
      AND u.user_id <> v_driver
      AND (
          (p_kind = 'reserved' AND u.user_id = v_me)
          OR (p_kind <> 'reserved' AND u.user_id IN (
                SELECT uml.user_id FROM public.user_member_link uml
                WHERE uml.member_id = p_member_id AND uml.status = 'active'))
      );
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_rows := v_rows + v_n;

    RETURN v_rows;
END;
$function$;

-- ---------------------------------------------------------------------------
-- v3 only: payment due
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.send_event_payment_reminders(p_event_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
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
            to_char(e.event_date_time AT TIME ZONE 'Europe/Dublin', 'Dy FMDD Mon, HH24:MI') AS date_time_formatted
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
        pu.team_name || ': Payment due',
        '€' || to_char(pu.payment_amount * pu.member_count / 100.0, 'FM999990.00') ||
            ' due for ' || pu.member_name_list || ' for ' || trim(pu.display_title) ||
            ', ' || pu.team_name || ', ' || pu.date_time_formatted || '.',
        'Payment due for ' || pu.member_name_list,
        'Please pay €' || to_char(pu.payment_amount * pu.member_count / 100.0, 'FM999990.00') ||
            ' for ' || pu.member_name_list || ' for ' || pu.team_name || ': ' || trim(pu.display_title) ||
            ' on ' || pu.date_time_formatted || '. Open the event to pay.',
        NULL
    FROM per_user pu;

    GET DIAGNOSTICS v_sent = ROW_COUNT;

    SELECT COUNT(*) INTO v_members FROM public.get_accepted_unpaid_members(p_event_id);

    RETURN jsonb_build_object('success', true, 'sent', v_sent, 'members', v_members);
END;
$function$;
