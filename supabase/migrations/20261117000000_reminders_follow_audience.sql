-- Reminders follow the event's audience (bug report, Clontarf Girls 2013,
-- 2026-11-16): a "Coaches only" mentors meeting (event 1809) sent its
-- reminder to 68 accounts, 45 of them parents, because
-- populate_event_notifications never looked at events.audience_id.
--
-- 1. populate_event_notifications (v2 + v3 "Send reminder"): when the event's
--    audience role is above Player (FLO 20, Coach 30), only members with that
--    role level or higher are reminded. Same rule as event_invitee_members.
-- 2. get_event_reminder_preview (v3 confirm sheet): same filter, so the count
--    matches who gets it.
-- 3. Clear the open 'attend' rows already sent to people outside the audience
--    on restricted events (auto_cleared = 'not_audience'). Undo with:
--    UPDATE notifications SET is_read = false, when_read = NULL, auto_cleared = NULL
--    WHERE auto_cleared = 'not_audience';

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
            COALESCE(ar.role_level, 0) AS audience_level,
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
        LEFT JOIN public.roles ar ON ar.role_id = e.audience_id
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
            -- Only the event's audience: on a Coaches event, only coaches.
            AND (te.audience_level <= 10 OR r.role_level >= te.audience_level)
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
    v_aud      int;
    v_out      jsonb;
    v_last_at  timestamptz;
    v_last_by  text;
    v_last_n   int;
    v_times    int;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not signed in';
    END IF;

    SELECT e.team_id, e.squad_id, COALESCE(ar.role_level, 0)
    INTO v_team_id, v_squad_id, v_aud
    FROM public.events e
    LEFT JOIN public.roles ar ON ar.role_id = e.audience_id
    WHERE e.event_id = p_event_id;
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
          AND (COALESCE(v_aud, 0) <= 10 OR r.role_level >= v_aud)
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

-- 3. Clear reminders sent outside the audience (only users with no linked
--    member at that level or higher on the event's team).
UPDATE public.notifications n
SET is_read      = true,
    when_read    = now(),
    is_delivered = true,
    auto_cleared = 'not_audience'
FROM public.events e
JOIN public.roles ar ON ar.role_id = e.audience_id AND ar.role_level > 10
WHERE n.event_id = e.event_id
  AND n.action   = 'attend'
  AND n.is_read  = false
  AND NOT EXISTS (
      SELECT 1
      FROM public.user_member_link uml
      JOIN public.member_team_link mtl ON mtl.member_id = uml.member_id
           AND mtl.team_id = e.team_id AND mtl.status = 'active'
      JOIN public.member_team_role_link mtrl ON mtrl.member_team_id = mtl.member_team_id
      JOIN public.roles r ON r.role_id = mtrl.role_id
      WHERE uml.user_id = n.recipient_user_id
        AND uml.status = 'active'
        AND r.role_level >= ar.role_level);
