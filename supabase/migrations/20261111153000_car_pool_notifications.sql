-- Car pool messages go through the notifications table (Ken, 2026-11-11), so they
-- follow the same push / email rules as every other notification: push when the
-- person has the phone app, email otherwise. Called by the v3 car pool page in
-- place of send-email. v2 keeps calling send-email and is unaffected.
--
-- p_kind:
--   'reserved'       caller reserved a seat for p_member_id: tell the driver,
--                    and send the caller a confirmation with the driver's phone
--   'cancelled'      a seat for p_member_id was cancelled: tell the driver and
--                    the member's account(s)
--   'pool_cancelled' the driver cancelled the car pool: tell p_member_id's account(s)

CREATE OR REPLACE FUNCTION public.car_pool_notify(
    p_car_pool_id bigint,
    p_kind        text,
    p_member_id   bigint
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_me        uuid := auth.uid();
    v_driver    uuid;
    v_event_id  bigint;
    v_team_id   bigint;
    v_team      text;
    v_title     text;
    v_when      text;
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
                WHEN 'reserved' THEN v_member || ' has reserved a seat in your car pool for ' || v_title || ' on ' || v_when
                ELSE v_member || ' has cancelled their seat in your car pool for ' || v_title || ' on ' || v_when
            END,
            CASE p_kind WHEN 'reserved' THEN 'Car pool seat reserved' ELSE 'Car pool seat cancelled' END,
            CASE p_kind
                WHEN 'reserved' THEN v_member || ' has reserved a seat in your car pool for ' || v_title || ' on ' || v_when
                ELSE v_member || ' has cancelled their seat in your car pool for ' || v_title || ' on ' || v_when
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
                    'A seat is reserved with ' || v_driver_nm || ' for ' || v_member || ' for ' || v_title || ' on ' || v_when ||
                    CASE WHEN v_phone IS NOT NULL THEN '. Please contact them on ' || v_phone || ' to finalise plans.' ELSE '.' END
                WHEN 'cancelled' THEN
                    'The car pool seat with ' || v_driver_nm || ' for ' || v_member || ' has been cancelled for ' || v_title || ' on ' || v_when || '.'
                ELSE
                    'The car pool with ' || v_driver_nm || ' for ' || v_member || ' has been cancelled for ' || v_title || ' on ' || v_when ||
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
$$;

REVOKE ALL ON FUNCTION public.car_pool_notify(bigint, text, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.car_pool_notify(bigint, text, bigint) TO authenticated;
