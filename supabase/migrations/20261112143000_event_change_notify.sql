-- v3 "Tell the team" on create, edit, cancel and delete (Ken, 2026-11-12).
-- The switch is off by default; nothing is sent unless the admin turns it on.
-- Who is told = whoever the event is for (Ken: "just those members
-- impacted"):
--   audience Coach (role_level 30+)  -> coaches and admins on the team
--   audience Player / none           -> every active member of the team
--   squad set                        -> only members of that squad
-- One message per user account (a parent of two gets one), never the sender.
-- Messages go through the notifications table (push or email, as usual).
-- v2 unchanged.

-- Members an event (or a draft event) is for, with each role they hold.
CREATE OR REPLACE FUNCTION public.event_invitee_members(
    p_team_id bigint, p_audience_id bigint, p_squad_id bigint, p_code_id bigint)
RETURNS TABLE(member_id bigint, role_level int, role_grade int)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_level int := 0;
    v_code  bigint := p_code_id;
    v_club  bigint;
BEGIN
    SELECT COALESCE(r.role_level, 0) INTO v_level
    FROM public.roles r WHERE r.role_id = p_audience_id;
    v_level := COALESCE(v_level, 0);

    -- Same code fallback as get_updated_event_code.
    IF p_squad_id IS NOT NULL AND COALESCE(v_code, 0) <= 1 THEN
        SELECT t.club_id INTO v_club FROM public.teams t WHERE t.team_id = p_team_id;
        SELECT COALESCE((
            SELECT ccl.code_id FROM public.club_code_link ccl
            WHERE ccl.club_id = v_club AND ccl.code_id > 1
              AND (ccl.team_id IS NULL OR ccl.team_id = p_team_id)
              AND public.team_has_code(p_team_id, ccl.code_id)
            ORDER BY ccl.code_id LIMIT 1), v_code) INTO v_code;
    END IF;

    RETURN QUERY
    SELECT DISTINCT mtl.member_id, r.role_level, r.role_grade
    FROM public.member_team_link mtl
    JOIN public.member_team_role_link mtrl ON mtrl.member_team_id = mtl.member_team_id
    JOIN public.roles r ON r.role_id = mtrl.role_id
    WHERE mtl.team_id = p_team_id
      AND mtl.status = 'active'
      AND (v_level <= 10 OR r.role_level >= v_level)
      AND (p_squad_id IS NULL OR EXISTS (
          SELECT 1 FROM public.member_squad_link msl
          WHERE msl.member_id = mtl.member_id
            AND msl.squad_id = p_squad_id
            AND msl.code_id = v_code));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.event_invitee_members(bigint, bigint, bigint, bigint) FROM PUBLIC, anon, authenticated;

-- Preview for the confirm sheet. Pass p_event_id for an existing event, or
-- the draft's team/audience/squad/code when creating. Team admins only.
-- Returns: people, push, email, members, players, flos, coaches, admins,
--          going, cant_go, not_replied, is_past (event only).
CREATE OR REPLACE FUNCTION public.get_event_notify_preview(
    p_event_id bigint DEFAULT NULL,
    p_team_id bigint DEFAULT NULL,
    p_audience_id bigint DEFAULT NULL,
    p_squad_id bigint DEFAULT NULL,
    p_code_id bigint DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_team bigint := p_team_id;
    v_aud  bigint := p_audience_id;
    v_sq   bigint := p_squad_id;
    v_code bigint := p_code_id;
    v_at   timestamptz;
    v_out  jsonb;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not signed in';
    END IF;
    IF p_event_id IS NOT NULL THEN
        SELECT e.team_id, e.audience_id, e.squad_id, e.event_code_id, e.event_date_time
        INTO v_team, v_aud, v_sq, v_code, v_at
        FROM public.events e WHERE e.event_id = p_event_id;
        IF v_team IS NULL THEN
            RAISE EXCEPTION 'Event not found';
        END IF;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.member_team_link mtl
        JOIN public.user_member_link uml ON uml.member_id = mtl.member_id AND uml.status = 'active'
        JOIN public.member_team_role_link mtrl ON mtrl.member_team_id = mtl.member_team_id
        JOIN public.roles r ON r.role_id = mtrl.role_id
        WHERE mtl.team_id = v_team AND mtl.status = 'active'
          AND uml.user_id = auth.uid() AND r.role_grade = 100) THEN
        RAISE EXCEPTION 'Only team admins can do this';
    END IF;

    WITH inv AS (
        SELECT * FROM public.event_invitee_members(v_team, v_aud, v_sq, v_code)
    ),
    mem AS (SELECT DISTINCT member_id FROM inv),
    acc AS (
        SELECT uml.user_id, bool_or(COALESCE(u.fcm_token, '') <> '') AS push
        FROM mem
        JOIN public.user_member_link uml ON uml.member_id = mem.member_id AND uml.status = 'active'
        JOIN public.users u ON u.user_id = uml.user_id AND u.deleted_at IS NULL
        WHERE uml.user_id <> auth.uid()
        GROUP BY uml.user_id
    ),
    lar AS (
        SELECT DISTINCT ON (ea.member_id) ea.member_id, ea.response_id
        FROM public.event_attendance ea
        WHERE p_event_id IS NOT NULL AND ea.event_id = p_event_id
          AND ea.member_id IN (SELECT member_id FROM mem)
        ORDER BY ea.member_id, ea.created_at DESC
    )
    SELECT jsonb_build_object(
        'people',  (SELECT COUNT(*) FROM acc),
        'push',    (SELECT COUNT(*) FROM acc WHERE push),
        'email',   (SELECT COUNT(*) FROM acc WHERE NOT push),
        'members', (SELECT COUNT(*) FROM mem),
        'players', (SELECT COUNT(DISTINCT member_id) FROM inv WHERE role_grade = 10 AND role_level = 10),
        'flos',    (SELECT COUNT(DISTINCT member_id) FROM inv WHERE role_grade = 10 AND role_level = 20),
        'coaches', (SELECT COUNT(DISTINCT member_id) FROM inv WHERE role_grade = 10 AND role_level = 30),
        'admins',  (SELECT COUNT(DISTINCT member_id) FROM inv WHERE role_grade = 100),
        'going',   (SELECT COUNT(*) FROM lar WHERE response_id = 3),
        'cant_go', (SELECT COUNT(*) FROM lar WHERE response_id = 4),
        'not_replied', (SELECT COUNT(*) FROM mem) - (SELECT COUNT(*) FROM lar WHERE response_id IN (3, 4)),
        'is_past', COALESCE(v_at < now(), false)
    ) INTO v_out;
    RETURN v_out;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.get_event_notify_preview(bigint, bigint, bigint, bigint, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_event_notify_preview(bigint, bigint, bigint, bigint, bigint) TO authenticated;

-- Tell the people an event is for that it was created, changed, cancelled
-- or deleted. Called by v3 after the action succeeds, only when the admin
-- turned "Tell the team" on (p_tell). For cancelled/deleted it also clears
-- open reply reminders for the affected events whether or not anyone is told.
--   p_kind    'created' | 'edited' | 'cancelled' | 'deleted'
--   p_note    optional text from the admin (cancel note, what changed)
--   p_events  how many events the action covered (a series = one message)
-- Returns {notified, cleared}.
CREATE OR REPLACE FUNCTION public.notify_event_change(
    p_event_id bigint,
    p_kind text,
    p_note text DEFAULT NULL,
    p_events int DEFAULT 1,
    p_tell boolean DEFAULT true)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    e         public.events%ROWTYPE;
    v_team    text;
    v_title   text;
    v_when    text;
    v_head    text;
    v_body    text;
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

    v_head := CASE p_kind
        WHEN 'created' THEN 'New event'
        WHEN 'edited' THEN 'Event changed'
        WHEN 'cancelled' THEN 'Event cancelled'
        ELSE 'Event removed' END;
    v_body := CASE p_kind
        WHEN 'created' THEN
            CASE WHEN COALESCE(p_events, 1) > 1
                 THEN v_title || ': ' || p_events || ' events from ' || v_when || '.'
                 ELSE v_title || ', ' || v_when || '.' END
        WHEN 'edited' THEN 'Changed: ' || v_title || ', ' || v_when || '.'
        WHEN 'cancelled' THEN
            CASE WHEN COALESCE(p_events, 1) > 1
                 THEN 'Cancelled: ' || v_title || ', ' || v_when
                      || ' and the ' || (p_events - 1) || ' after it.'
                 ELSE 'Cancelled: ' || v_title || ', ' || v_when || '.' END
        ELSE
            CASE WHEN COALESCE(p_events, 1) > 1
                 THEN 'Removed: ' || v_title || ', ' || v_when
                      || ' and the ' || (p_events - 1) || ' after it.'
                 ELSE 'Removed: ' || v_title || ', ' || v_when || '.' END
        END;
    IF v_note IS NOT NULL THEN
        v_body := v_body || ' ' || v_note;
    END IF;

    -- A single new event that asks for replies gets the Going / Can't go buttons.
    v_attend := p_kind = 'created' AND COALESCE(p_events, 1) = 1
                AND COALESCE(e.request_attendance, true)
                AND e.event_date_time > now();

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
$$;
REVOKE EXECUTE ON FUNCTION public.notify_event_change(bigint, text, text, int, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.notify_event_change(bigint, text, text, int, boolean) TO authenticated;
