-- v3 "Send reminder" confirm sheet (Ken, 2026-11-12).
-- Read-only preview of what populate_event_notifications(event, 10, 10)
-- would send, plus when a reminder was last sent for the event.
-- Uses the same filters as populate_event_notifications: active team
-- members with a grade 10 role (Player, FLO, Coach) who haven't replied,
-- limited to the event's squad when it has one. One message per user
-- account. Team admins (role 100+) only. Nothing is written; v2 unchanged.
--
-- Returns jsonb:
--   people       accounts that would get a reminder
--   push, email  how those accounts would get it (fcm_token set = push)
--   not_replied  members who haven't replied
--   players, flos, coaches   members who haven't replied, by role
--   names        [{name, roles}] members who haven't replied
--   times_sent   reminders sent for this event so far
--   last_at, last_by, last_people   the latest send (null if none)
CREATE OR REPLACE FUNCTION public.get_event_reminder_preview(p_event_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = 'public'
AS $$
DECLARE
    v_team_id  bigint;
    v_squad_id bigint;
    v_code     bigint;
    v_level    int;
    v_out      jsonb;
    v_last_at  timestamptz;
    v_last_by  text;
    v_last_n   int;
    v_times    int;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not signed in';
    END IF;

    SELECT e.team_id, e.squad_id INTO v_team_id, v_squad_id
    FROM public.events e WHERE e.event_id = p_event_id;
    IF v_team_id IS NULL THEN
        RAISE EXCEPTION 'Event not found';
    END IF;

    SELECT COALESCE(MAX(r.role_level), 0) INTO v_level
    FROM public.member_team_link mtl
    JOIN public.user_member_link uml ON uml.member_id = mtl.member_id AND uml.status = 'active'
    JOIN public.member_team_role_link mtrl ON mtrl.member_team_id = mtl.member_team_id
    JOIN public.roles r ON r.role_id = mtrl.role_id
    WHERE mtl.team_id = v_team_id AND mtl.status = 'active' AND uml.user_id = auth.uid();
    IF v_level < 100 THEN
        RAISE EXCEPTION 'Only team admins can send reminders';
    END IF;

    IF v_squad_id IS NOT NULL THEN
        v_code := public.get_updated_event_code(p_event_id);
    END IF;

    WITH um AS (
        SELECT m.member_id,
               trim(COALESCE(m.first_name, '') || ' ' || COALESCE(m.last_name, '')) AS name,
               u.user_id,
               COALESCE(u.fcm_token, '') <> '' AS push,
               r.role_name,
               r.role_level
        FROM public.member_team_link mtl
        JOIN public.members m ON m.member_id = mtl.member_id
        JOIN public.user_member_link uml ON uml.member_id = m.member_id AND uml.status = 'active'
        JOIN public.users u ON u.user_id = uml.user_id
        JOIN public.member_team_role_link mtrl ON mtrl.member_team_id = mtl.member_team_id
        JOIN public.roles r ON r.role_id = mtrl.role_id
        WHERE mtl.team_id = v_team_id
          AND mtl.status = 'active'
          AND r.role_grade = 10
          AND r.role_level >= 10
          AND NOT EXISTS (
              SELECT 1 FROM public.event_attendance ea
              WHERE ea.event_id = p_event_id
                AND ea.member_id = m.member_id
                AND ea.response_id IS NOT NULL
                AND ea.response_id > 0)
          AND (v_squad_id IS NULL OR EXISTS (
              SELECT 1 FROM public.member_squad_link msl
              WHERE msl.member_id = m.member_id
                AND msl.squad_id = v_squad_id
                AND msl.code_id = v_code))
    ),
    acc AS (
        SELECT user_id, bool_or(push) AS push FROM um GROUP BY user_id
    ),
    mem AS (
        SELECT member_id, MIN(name) AS name,
               string_agg(DISTINCT role_name, ', ') AS roles
        FROM um GROUP BY member_id
    )
    SELECT jsonb_build_object(
        'people',      (SELECT COUNT(*) FROM acc),
        'push',        (SELECT COUNT(*) FROM acc WHERE push),
        'email',       (SELECT COUNT(*) FROM acc WHERE NOT push),
        'not_replied', (SELECT COUNT(*) FROM mem),
        'players',     (SELECT COUNT(DISTINCT member_id) FROM um WHERE role_level = 10),
        'flos',        (SELECT COUNT(DISTINCT member_id) FROM um WHERE role_level = 20),
        'coaches',     (SELECT COUNT(DISTINCT member_id) FROM um WHERE role_level = 30),
        'names',       COALESCE((SELECT jsonb_agg(jsonb_build_object('name', name, 'roles', roles)
                                                  ORDER BY name) FROM mem), '[]'::jsonb)
    ) INTO v_out;

    SELECT COUNT(*) INTO v_times FROM public.reminders WHERE event_id = p_event_id;

    SELECT rm.created_at, NULLIF(trim(COALESCE(u.first_name, '')), '') AS by_name,
           NULLIF(substring(rm.result FROM '^\s*(\d+)'), '')::int AS n
    INTO v_last_at, v_last_by, v_last_n
    FROM public.reminders rm
    LEFT JOIN public.users u ON u.user_id = rm.user_id
    WHERE rm.event_id = p_event_id
    ORDER BY rm.created_at DESC
    LIMIT 1;

    RETURN v_out || jsonb_build_object(
        'times_sent',  v_times,
        'last_at',     v_last_at,
        'last_by',     v_last_by,
        'last_people', v_last_n);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.get_event_reminder_preview(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_event_reminder_preview(bigint) TO authenticated;
