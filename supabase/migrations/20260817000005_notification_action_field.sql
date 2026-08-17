-- Add action and action_ref_id to notifications.
--
-- action values:
--   NULL            — informational, no quick action
--   'attend'        — Accept / Decline event attendance (action_ref_id unused; use event_id)
--   'approve_member'— Approve / Deny member team join  (action_ref_id = member_team_id)
--   'approve_access'— Approve / Deny profile access    (action_ref_id = user_member_id)
--
-- Also adds delivery_method to create_new_member_by_code (previously missing),
-- and updates get_user_notifications to return image, action, action_ref_id,
-- and is_delivered.

ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS action        text;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS action_ref_id bigint;

-- ─── get_user_notifications ───────────────────────────────────────────────────
-- Return type changes so DROP first.

DROP FUNCTION IF EXISTS public.get_user_notifications(uuid);

CREATE FUNCTION public.get_user_notifications(p_user_id uuid)
RETURNS TABLE (
    id              bigint,
    created_at      text,
    time_label      text,
    app_title       text,
    app_body        text,
    is_read         boolean,
    is_delivered    boolean,
    link_page       text,
    image           text,
    team_id         bigint,
    team_name       text,
    event_id        bigint,
    action          text,
    action_ref_id   bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    RETURN QUERY
    SELECT
        n.id,
        to_char(n.created_at, 'Dy, DD Mon YYYY "at" HH12:MI AM')::text,
        CASE
            WHEN n.created_at > now() - interval '2 minutes'  THEN 'Just now'
            WHEN n.created_at > now() - interval '1 hour'
                THEN floor(extract(epoch from (now() - n.created_at)) / 60)::text || 'm ago'
            WHEN n.created_at > now() - interval '24 hours'   THEN
                CASE
                    WHEN floor(extract(epoch from (now() - n.created_at)) / 3600) = 1 THEN '1 hour ago'
                    ELSE floor(extract(epoch from (now() - n.created_at)) / 3600)::text || ' hours ago'
                END
            ELSE
                CASE
                    WHEN floor(extract(epoch from (now() - n.created_at)) / 86400) = 1 THEN '1 day ago'
                    ELSE floor(extract(epoch from (now() - n.created_at)) / 86400)::text || ' days ago'
                END
        END AS time_label,
        COALESCE(n.app_title, n.push_title, 'Notification') AS app_title,
        COALESCE(n.app_body,  n.push_body,  '')              AS app_body,
        n.is_read,
        n.is_delivered,
        n.link_page,
        n.image,
        n.team_id,
        COALESCE(t.team_name, 'General') AS team_name,
        n.event_id,
        n.action,
        n.action_ref_id
    FROM  public.notifications n
    LEFT JOIN public.teams t ON n.team_id = t.team_id
    WHERE n.recipient_user_id = p_user_id
    ORDER BY n.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_notifications(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_notifications(uuid) TO service_role;

-- ─── create_new_member_by_code ────────────────────────────────────────────────
-- Add delivery_method = 'push', action = 'approve_member',
-- action_ref_id = v_new_member_team_id to the admin notification INSERT.

CREATE OR REPLACE FUNCTION public.create_new_member_by_code(
    p_first_name   text,
    p_last_name    text,
    p_joining_code text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_new_member_id       bigint;
    v_new_member_team_id  bigint;
    v_existing_member_id  bigint;
    v_existing_mtl_status text;
    v_team_id             bigint;
    v_club_id             bigint;
    v_user_id             uuid;
    v_team_name           text;
    v_no_team_squad_id    bigint;
    v_clean_first         text := INITCAP(TRIM(COALESCE(p_first_name, '')));
    v_clean_last          text := INITCAP(TRIM(COALESCE(p_last_name, '')));
    v_clean_code          text := UPPER(TRIM(COALESCE(p_joining_code, '')));
    v_default_pic         text := 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/hvxmhKxoCA4XCjUFmpM6/assets/50b842h4zvrj/image-removebg-preview_(14).png';
BEGIN
    v_user_id := auth.uid();

    IF v_clean_first = '' OR v_clean_last = '' OR v_clean_code = '' THEN
        RETURN jsonb_build_object('status', 'error',
            'message', 'First name, Last name, and Joining Code are all required.');
    END IF;

    SELECT team_id, club_id, team_name
      INTO v_team_id, v_club_id, v_team_name
      FROM public.teams
     WHERE UPPER(TRIM(team_unique_code)) = v_clean_code;

    IF v_team_id IS NULL THEN
        RETURN jsonb_build_object('status', 'error',
            'message', 'The joining code "' || p_joining_code || '" is not valid.');
    END IF;

    SELECT squad_id INTO v_no_team_squad_id
      FROM public.squads
     WHERE team_id = v_team_id AND squad_name = 'No Team'
     LIMIT 1;

    IF EXISTS (
        SELECT 1
          FROM public.member_team_link  mtl
          JOIN public.members           m   ON mtl.member_id = m.member_id
          JOIN public.user_member_link  uml ON m.member_id   = uml.member_id
         WHERE mtl.team_id  = v_team_id
           AND mtl.status   = 'active'
           AND uml.user_id  = v_user_id
           AND uml.status   = 'active'
           AND m.first_name = v_clean_first
           AND m.last_name  = v_clean_last
    ) THEN
        RETURN jsonb_build_object(
            'status',    'already_member',
            'team_name', v_team_name,
            'message',   v_clean_first || ' ' || v_clean_last ||
                         ' is already linked to your account on ' || v_team_name || '.'
        );
    END IF;

    IF EXISTS (
        SELECT 1
          FROM public.member_team_link  mtl
          JOIN public.members           m   ON mtl.member_id = m.member_id
          JOIN public.user_member_link  uml ON m.member_id   = uml.member_id
         WHERE mtl.team_id  = v_team_id
           AND mtl.status   = 'pending'
           AND uml.user_id  = v_user_id
           AND uml.status   = 'active'
           AND m.first_name = v_clean_first
           AND m.last_name  = v_clean_last
    ) THEN
        RETURN jsonb_build_object(
            'status',    'already_pending',
            'team_name', v_team_name,
            'message',   'You have already submitted a request for ' ||
                         v_clean_first || ' ' || v_clean_last ||
                         ' to join ' || v_team_name || '. It is awaiting admin approval.'
        );
    END IF;

    SELECT m.member_id, mtl.status
      INTO v_existing_member_id, v_existing_mtl_status
      FROM public.member_team_link mtl
      JOIN public.members          m ON mtl.member_id = m.member_id
     WHERE mtl.team_id  = v_team_id
       AND mtl.status   IN ('active', 'pending')
       AND m.first_name = v_clean_first
       AND m.last_name  = v_clean_last
       AND NOT EXISTS (
           SELECT 1 FROM public.user_member_link uml2
            WHERE uml2.member_id = m.member_id
              AND uml2.user_id   = v_user_id
              AND uml2.status    = 'active'
       )
     LIMIT 1;

    IF v_existing_member_id IS NOT NULL THEN
        IF v_existing_mtl_status = 'active' THEN
            RETURN jsonb_build_object(
                'status',    'duplicate',
                'member_id', v_existing_member_id,
                'team_name', v_team_name,
                'message',   v_clean_first || ' ' || v_clean_last ||
                             ' is already an active member of ' || v_team_name || '.'
            );
        ELSE
            RETURN jsonb_build_object(
                'status',    'pending_other',
                'team_name', v_team_name,
                'message',   'A request for ' || v_clean_first || ' ' || v_clean_last ||
                             ' to join ' || v_team_name ||
                             ' is already waiting for admin approval. ' ||
                             'Once it is confirmed, contact your team admin to link your account.'
            );
        END IF;
    END IF;

    INSERT INTO public.members (first_name, last_name, user_id, profile_pic)
    VALUES (v_clean_first, v_clean_last, v_user_id, v_default_pic)
    RETURNING member_id INTO v_new_member_id;

    INSERT INTO public.user_member_link (user_id, member_id, status)
    VALUES (v_user_id, v_new_member_id, 'active');

    INSERT INTO public.member_team_link (member_id, team_id, squad_id, member_team_code, status)
    VALUES (v_new_member_id, v_team_id, v_no_team_squad_id, v_clean_code, 'pending')
    RETURNING member_team_id INTO v_new_member_team_id;

    INSERT INTO public.member_squad_link (member_id, team_id, code_id, squad_id)
    SELECT v_new_member_id, v_team_id, code_id, v_no_team_squad_id
      FROM public.club_code_link
     WHERE club_id = v_club_id AND code_id > 1;

    INSERT INTO public.notifications (
        recipient_user_id, team_id,
        app_title, app_body,
        push_title, push_body,
        delivery_method,
        action, action_ref_id
    )
    SELECT DISTINCT uml2.user_id, v_team_id,
        'New Join Request',
        v_clean_first || ' ' || v_clean_last || ' has requested to join ' || v_team_name || '.',
        'New Join Request',
        v_clean_first || ' ' || v_clean_last || ' has requested to join ' || v_team_name || '.',
        'push',
        'approve_member',
        v_new_member_team_id
      FROM public.member_team_link      mtl2
      JOIN public.member_team_role_link mtrl2 ON mtl2.member_team_id = mtrl2.member_team_id
      JOIN public.roles                 r2    ON mtrl2.role_id        = r2.role_id
      JOIN public.user_member_link      uml2  ON mtl2.member_id       = uml2.member_id
     WHERE mtl2.team_id  = v_team_id
       AND mtl2.status   = 'active'
       AND uml2.status   = 'active'
       AND r2.role_grade = 100;

    RETURN jsonb_build_object(
        'status',    'pending',
        'member_id', v_new_member_id,
        'team_name', v_team_name,
        'message',   'Your request for ' || v_clean_first || ' ' || v_clean_last ||
                     ' to join ' || v_team_name ||
                     ' has been sent. An admin will confirm the membership shortly.'
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('status', 'error', 'message', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_new_member_by_code(text, text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.create_new_member_by_code(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_new_member_by_code(text, text, text) TO service_role;

-- ─── request_member_access ────────────────────────────────────────────────────
-- Capture user_member_id with RETURNING so it can be stored as action_ref_id.

CREATE OR REPLACE FUNCTION public.request_member_access(
    p_member_id    bigint,
    p_joining_code text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
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
        action, action_ref_id
    )
    SELECT DISTINCT uml2.user_id,
           v_team_id,
           'Access Request',
           (SELECT first_name || ' ' || last_name FROM public.users WHERE user_id = v_caller) ||
               ' has requested access to ' || v_first_name || ' ' || v_last_name ||
               ' on ' || v_team_name || '.',
           'Access Request',
           (SELECT first_name || ' ' || last_name FROM public.users WHERE user_id = v_caller) ||
               ' has requested access to ' || v_first_name || ' ' || v_last_name || '.',
           'push',
           'approve_access',
           v_user_member_id
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
$$;

GRANT EXECUTE ON FUNCTION public.request_member_access(bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_member_access(bigint, text) TO service_role;

-- ─── populate_event_notifications ────────────────────────────────────────────
-- Add action = 'attend' to every event reminder notification.

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
        false,
        CASE
            WHEN cpu.fcm_token IS NOT NULL AND cpu.fcm_token <> '' THEN false
            ELSE true
        END,
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
