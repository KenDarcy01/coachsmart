-- Personal attendance-alert settings for team admins (v3 Notification settings, Ken 2026-11-11).
--
-- The event's own rule (events.notify_admins_all / notify_admins_changes) stays the parent rule.
-- Each admin can narrow it for themselves, per team:
--   'changes' = only tell me when someone changes their mind
--   'off'     = don't tell me about attendance answers for this team
-- No row means "as set on the event", so every existing user (and the whole v2 app) behaves
-- exactly as before. The table starts empty. Join/access requests are not affected.

CREATE TABLE IF NOT EXISTS public.admin_alert_prefs (
    user_id           uuid        NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
    team_id           bigint      NOT NULL REFERENCES public.teams(team_id) ON DELETE CASCADE,
    attendance_alerts text        NOT NULL CHECK (attendance_alerts IN ('changes', 'off')),
    updated_at        timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, team_id)
);

-- Only reached through the functions below.
ALTER TABLE public.admin_alert_prefs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.admin_alert_prefs FROM anon, authenticated;

-- Teams the signed-in user is an admin of (role grade 100), with their own setting.
CREATE OR REPLACE FUNCTION public.get_my_admin_alert_prefs()
RETURNS TABLE(team_id bigint, team_name text, club_name text, attendance_alerts text)
LANGUAGE sql
SECURITY DEFINER
SET search_path = 'public'
AS $$
    SELECT DISTINCT ON (t.team_id)
        t.team_id,
        t.team_name::text,
        c.club_name::text,
        COALESCE(p.attendance_alerts, 'event')
    FROM public.user_member_link uml
    JOIN public.member_team_link mtl       ON mtl.member_id = uml.member_id AND mtl.status = 'active'
    JOIN public.member_team_role_link mtrl ON mtrl.member_team_id = mtl.member_team_id
    JOIN public.roles r                    ON r.role_id = mtrl.role_id AND r.role_grade = 100
    JOIN public.teams t                    ON t.team_id = mtl.team_id
    LEFT JOIN public.clubs c               ON c.club_id = t.club_id
    LEFT JOIN public.admin_alert_prefs p   ON p.user_id = uml.user_id AND p.team_id = t.team_id
    WHERE uml.user_id = auth.uid()
      AND uml.status = 'active'
    ORDER BY t.team_id;
$$;

-- p_choice: 'event' (follow the event, removes the row), 'changes' or 'off'.
CREATE OR REPLACE FUNCTION public.set_my_admin_alert_pref(p_team_id bigint, p_choice text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not signed in';
    END IF;
    IF p_choice NOT IN ('event', 'changes', 'off') THEN
        RAISE EXCEPTION 'Unknown choice %', p_choice;
    END IF;
    IF p_choice = 'event' THEN
        DELETE FROM public.admin_alert_prefs WHERE user_id = auth.uid() AND team_id = p_team_id;
    ELSE
        INSERT INTO public.admin_alert_prefs (user_id, team_id, attendance_alerts, updated_at)
        VALUES (auth.uid(), p_team_id, p_choice, now())
        ON CONFLICT (user_id, team_id)
        DO UPDATE SET attendance_alerts = EXCLUDED.attendance_alerts, updated_at = now();
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_admin_alert_prefs() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.set_my_admin_alert_pref(bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_admin_alert_prefs() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_my_admin_alert_pref(bigint, text) TO authenticated;

-- notify_admins_attendance_change: copied unchanged from 20261015000001 except one extra
-- filter in admin_users that honours admin_alert_prefs.
CREATE OR REPLACE FUNCTION "public"."notify_admins_attendance_change"(
    "p_event_id_param" integer,
    "p_member_id_param" integer,
    "p_response_id" integer,
    "p_attendance_id" bigint
)
RETURNS TABLE("notifications_created" integer)
LANGUAGE "plpgsql" SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    created_count         INT := 0;
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

    SELECT true INTO v_member_exists
    FROM public.members
    WHERE member_id = p_member_id_param;

    IF NOT v_member_exists THEN
        RAISE NOTICE 'EXIT: Member % not found', p_member_id_param;
        RETURN QUERY SELECT 0;
        RETURN;
    END IF;

    RAISE NOTICE 'Member % found', p_member_id_param;

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

    RAISE NOTICE 'Previous attendance lookup: attendance_id < % → prev_response_id=%',
        p_attendance_id, v_prev_response_id;

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

    SELECT COUNT(DISTINCT u.user_id)
    INTO v_admin_count
    FROM public.member_team_link mtl
    JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.roles r                    ON mtrl.role_id = r.role_id
    JOIN public.members m                  ON mtl.member_id = m.member_id
    JOIN public.user_member_link uml       ON m.member_id = uml.member_id
    JOIN public.users u                    ON uml.user_id = u.user_id
    JOIN public.events e                   ON e.team_id = mtl.team_id
    WHERE e.event_id = p_event_id_param
      AND r.role_grade = 100
      AND m.member_id != p_member_id_param;

    RAISE NOTICE 'Admin users found for team (excluding actor): %', v_admin_count;

    IF v_admin_count = 0 THEN
        RAISE NOTICE 'WARN: No other admin users (role_grade=100) found for this team — no notifications will be created';
    END IF;

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
