-- Event series + per-team payments switch (v3 create/edit event, Ken OK 2026-11-09).
-- Additive: the live app ignores the new columns and keeps calling the same
-- functions with the same arguments.
--
-- 1. teams.payments: shows the Payment row on the v3 create/edit form.
-- 2. events.series_id: links the copies made by a recurring create, so
--    Save / Cancel / Delete can apply to "this and later events". Existing
--    recurring groups (same team, created_at and type) are linked too.
-- 3. create_recurring_events stamps series_id (= first event's id).
-- 4. get_user_event_create_detail / get_user_event_edit_detail return the
--    team switches, and the edit one returns series info for the event.
-- 5. update_event_series / set_event_series_status: the v3 edit calls.

ALTER TABLE public.teams
    ADD COLUMN IF NOT EXISTS payments boolean NOT NULL DEFAULT false;
COMMENT ON COLUMN public.teams.payments IS
    'Admins can ask players to pay for events on this team (v3 form shows the Payment row).';
UPDATE public.teams SET payments = true WHERE team_id = 84; -- Test Team, for testing

ALTER TABLE public.events ADD COLUMN IF NOT EXISTS series_id bigint;
COMMENT ON COLUMN public.events.series_id IS
    'Events created together as a recurring series share the first event''s id here.';
CREATE INDEX IF NOT EXISTS events_series_id_idx ON public.events (series_id)
    WHERE series_id IS NOT NULL;

-- Link the groups the old recurring create made (identical created_at).
WITH g AS (
    SELECT team_id, created_at, event_type_id, MIN(event_id) AS first_id
    FROM public.events
    WHERE series_id IS NULL
    GROUP BY team_id, created_at, event_type_id
    HAVING COUNT(*) > 1
)
UPDATE public.events e
SET series_id = g.first_id
FROM g
WHERE e.series_id IS NULL
  AND e.team_id = g.team_id
  AND e.created_at = g.created_at
  AND e.event_type_id IS NOT DISTINCT FROM g.event_type_id;

-- 3. create_recurring_events: unchanged apart from stamping series_id.
CREATE OR REPLACE FUNCTION public.create_recurring_events(p_recurring_type integer, p_num_weeks integer, p_event_title text DEFAULT NULL::text, p_event_date_time timestamp with time zone DEFAULT NULL::timestamp with time zone, p_event_date_time_2 timestamp without time zone DEFAULT NULL::timestamp without time zone, p_team_id bigint DEFAULT NULL::bigint, p_created_by uuid DEFAULT NULL::uuid, p_event_type_id bigint DEFAULT NULL::bigint, p_event_code_id bigint DEFAULT NULL::bigint, p_audience_id bigint DEFAULT NULL::bigint, p_squad_id bigint DEFAULT NULL::bigint, p_location_name text DEFAULT NULL::text, p_location_pin text DEFAULT NULL::text, p_home_away text DEFAULT NULL::text, p_meet_time text DEFAULT NULL::text, p_opposition text DEFAULT NULL::text, p_event_details text DEFAULT NULL::text, p_event_link text DEFAULT NULL::text, p_event_image text DEFAULT NULL::text, p_request_attendance boolean DEFAULT false, p_notify_admins_changes boolean DEFAULT false, p_notify_admins_all boolean DEFAULT false, p_payment_required boolean DEFAULT false, p_payment_amount smallint DEFAULT NULL::smallint, p_car_pooling boolean DEFAULT false)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    new_event_id    BIGINT;
    created_ids     BIGINT[] := '{}';
    num_events      INTEGER;
    interval_weeks  INTEGER;
    i               INTEGER;
    offset_interval INTERVAL;
BEGIN
    p_recurring_type := COALESCE(p_recurring_type, 0);
    p_num_weeks      := COALESCE(p_num_weeks, 0);

    -- Sanitize: treat empty string or the literal text "null" as SQL NULL
    p_event_image := CASE WHEN TRIM(COALESCE(p_event_image, '')) IN ('', 'null')
                          THEN NULL ELSE p_event_image END;

    IF p_recurring_type NOT IN (0, 1, 2) THEN
        RETURN json_build_object(
            'success', false,
            'events_created', 0,
            'event_ids', '[]'::json,
            'message', 'Recurring type must be None, Weekly or Fortnightly.'
        );
    END IF;

    IF p_event_date_time IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'events_created', 0,
            'event_ids', '[]'::json,
            'message', 'Event date and time is required.'
        );
    END IF;

    IF p_recurring_type = 0 THEN
        INSERT INTO public.events (
            created_at, event_title, event_date_time, event_date_time_2,
            location_pin, location_name, home_away, created_by, team_id,
            event_code_id, event_type_id, audience_id, request_attendance,
            event_details, squad_id, meet_time, opposition, event_link,
            event_image, notify_admins_changes, notify_admins_all,
            payment_required, payment_amount, car_pooling, status
        ) VALUES (
            NOW(), p_event_title, p_event_date_time, p_event_date_time_2,
            p_location_pin, p_location_name, p_home_away, p_created_by, p_team_id,
            p_event_code_id, p_event_type_id, p_audience_id, p_request_attendance,
            p_event_details, p_squad_id, p_meet_time, p_opposition, p_event_link,
            p_event_image, p_notify_admins_changes, p_notify_admins_all,
            p_payment_required, p_payment_amount, p_car_pooling, 'active'
        )
        RETURNING event_id INTO new_event_id;

        created_ids := array_append(created_ids, new_event_id);
        RETURN json_build_object(
            'success', true,
            'events_created', 1,
            'event_ids', to_json(created_ids),
            'message', '1 event created successfully. ID: ' || new_event_id::TEXT
        );
    END IF;

    IF p_num_weeks < 1 OR p_num_weeks > 12 THEN
        RETURN json_build_object(
            'success', false,
            'events_created', 0,
            'event_ids', '[]'::json,
            'message', 'Number of weeks must be between 1 and 12 for recurring events.'
        );
    END IF;

    IF p_recurring_type = 1 THEN
        interval_weeks := 1;
        num_events     := p_num_weeks;
    ELSE
        interval_weeks := 2;
        num_events     := p_num_weeks / 2;
    END IF;

    FOR i IN 0..(num_events - 1) LOOP
        offset_interval := (i * interval_weeks || ' weeks')::INTERVAL;

        INSERT INTO public.events (
            created_at, event_title, event_date_time, event_date_time_2,
            location_pin, location_name, home_away, created_by, team_id,
            event_code_id, event_type_id, audience_id, request_attendance,
            event_details, squad_id, meet_time, opposition, event_link,
            event_image, notify_admins_changes, notify_admins_all,
            payment_required, payment_amount, car_pooling, status
        ) VALUES (
            NOW(), p_event_title,
            p_event_date_time + offset_interval,
            CASE WHEN p_event_date_time_2 IS NOT NULL
                 THEN p_event_date_time_2 + offset_interval ELSE NULL END,
            p_location_pin, p_location_name, p_home_away, p_created_by, p_team_id,
            p_event_code_id, p_event_type_id, p_audience_id, p_request_attendance,
            p_event_details, p_squad_id, p_meet_time, p_opposition, p_event_link,
            p_event_image, p_notify_admins_changes, p_notify_admins_all,
            p_payment_required, p_payment_amount, p_car_pooling, 'active'
        )
        RETURNING event_id INTO new_event_id;

        created_ids := array_append(created_ids, new_event_id);
    END LOOP;

    -- Link the copies as one series (first event's id).
    UPDATE public.events SET series_id = created_ids[1]
    WHERE event_id = ANY(created_ids);

    RETURN json_build_object(
        'success', true,
        'events_created', array_length(created_ids, 1),
        'event_ids', to_json(created_ids),
        'series_id', created_ids[1],
        'message', array_length(created_ids, 1)::TEXT
            || ' event(s) created successfully. IDs: '
            || array_to_string(created_ids, ', ')
    );
END;
$function$;

-- 4a. Team switches in the create payload.
CREATE OR REPLACE FUNCTION public.get_user_event_create_detail(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_result jsonb;
    v_default_team_id bigint;
BEGIN
    SELECT
        CASE WHEN COUNT(DISTINCT mtl.team_id) = 1 THEN MAX(mtl.team_id) ELSE NULL END
    INTO v_default_team_id
    FROM public.members m
    JOIN public.user_member_link uml ON m.member_id = uml.member_id
    JOIN public.member_team_link mtl ON m.member_id = mtl.member_id AND mtl.status = 'active'
    WHERE uml.user_id = p_user_id;

    SELECT jsonb_build_object(
        'user_id',         p_user_id,
        'default_team_id', v_default_team_id,
        'create_teams', (
            SELECT jsonb_agg(team_data)
            FROM (
                SELECT DISTINCT ON (t.team_id)
                    t.team_id, t.team_name, t.club_id, c.club_name,
                    COALESCE(t.payments, false) AS payments,
                    COALESCE(t.car_pooling_allowed, false) AS car_pooling_allowed,
                    m.member_id,
                    (m.first_name || ' ' || m.last_name) AS authorized_member_name,
                    r.role_id,
                    r.role_name  AS admin_role,
                    r.role_level AS admin_level,
                    (SELECT jsonb_agg(jsonb_build_object('id', et.event_type_id, 'name', et.event_type))
                     FROM public.event_types et) AS event_types,
                    (SELECT jsonb_agg(jsonb_build_object('id', ec.code_id, 'name', ec.event_code))
                     FROM public.club_code_link ccl
                     JOIN public.event_codes ec ON ccl.code_id = ec.code_id
                     WHERE ccl.club_id = t.club_id
                       AND (ccl.team_id IS NULL OR ccl.team_id = t.team_id)
                       AND public.team_has_code(t.team_id, ccl.code_id)) AS event_codes,
                    (SELECT jsonb_agg(jsonb_build_object(
                         'id', r_inner.role_id, 'name', r_inner.role_name,
                         'name_plural', r_inner.role_name_plural))
                     FROM public.team_roles_link trl
                     JOIN public.roles r_inner ON trl.role_id = r_inner.role_id
                     WHERE trl.team_id = t.team_id
                       AND r_inner.role_grade = 10 AND r_inner.show_audience = true) AS team_roles,
                    (SELECT jsonb_agg(jsonb_build_object(
                         'id', s.squad_id, 'name', s.squad_name, 'image', s.squad_image,
                         'squad_list_seq', s.squad_list_seq))
                     FROM public.squads s
                     WHERE s.team_id = t.team_id) AS squads
                FROM public.members m
                JOIN public.user_member_link uml ON m.member_id = uml.member_id
                JOIN public.member_team_link mtl ON m.member_id = mtl.member_id AND mtl.status = 'active'
                JOIN public.teams t ON mtl.team_id = t.team_id
                LEFT JOIN public.clubs c ON t.club_id = c.club_id
                JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
                JOIN public.roles r ON mtrl.role_id = r.role_id
                WHERE uml.user_id = p_user_id AND r.role_grade = 100
                ORDER BY t.team_id, r.role_level DESC
            ) team_data
        )
    ) INTO v_result;

    RETURN v_result;
END;
$function$;

-- 4b. Edit payload: team switches plus series info on the event.
CREATE OR REPLACE FUNCTION public.get_user_event_edit_detail(p_user_id uuid, p_event_id bigint DEFAULT NULL::bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_result jsonb;
    v_default_team_id bigint;
    v_current_event jsonb;
BEGIN
    SELECT CASE WHEN COUNT(DISTINCT mtl.team_id) = 1 THEN MAX(mtl.team_id) ELSE NULL END
    INTO v_default_team_id
    FROM public.members m
    JOIN public.user_member_link uml ON m.member_id = uml.member_id
    JOIN public.member_team_link mtl ON m.member_id = mtl.member_id AND mtl.status = 'active'
    WHERE uml.user_id = p_user_id;

    IF p_event_id IS NOT NULL THEN
        SELECT jsonb_build_object(
            'event_id', e.event_id,
            'event_title', e.event_title,
            'event_type_id', e.event_type_id,
            'event_date_time', e.event_date_time_2,
            'meet_time', e.meet_time,
            'event_code_id', e.event_code_id,
            'opposition', e.opposition,
            'home_away', e.home_away,
            'location_name', e.location_name,
            'location_pin', e.location_pin,
            'event_link', e.event_link,
            'audience_id', e.audience_id,
            'request_attendance', e.request_attendance,
            'event_details', e.event_details,
            'team_id', e.team_id,
            'event_image', e.event_image,
            'payment_required', e.payment_required,
            'payment_amount', e.payment_amount,
            'squad_id', e.squad_id,
            'status', e.status,
            'series_id', e.series_id,
            -- events in the same series on or after this one (this one included)
            'series_later', CASE WHEN e.series_id IS NULL THEN 0 ELSE (
                SELECT COUNT(*) FROM public.events x
                WHERE x.series_id = e.series_id
                  AND x.status <> 'deleted'
                  AND x.event_date_time >= e.event_date_time) END
        ) INTO v_current_event
        FROM public.events e
        WHERE e.event_id = p_event_id;
    END IF;

    SELECT jsonb_build_object(
        'user_id', p_user_id,
        'default_team_id', v_default_team_id::text,
        'current_event', v_current_event,
        'create_teams', (
            SELECT jsonb_agg(team_data)
            FROM (
                SELECT DISTINCT ON (t.team_id)
                    t.team_id, t.team_name, t.club_id, c.club_name,
                    COALESCE(t.payments, false) AS payments,
                    COALESCE(t.car_pooling_allowed, false) AS car_pooling_allowed,
                    m.member_id,
                    (m.first_name || ' ' || m.last_name) AS authorized_member_name,
                    r.role_id,
                    r.role_name AS admin_role,
                    r.role_level AS admin_level,
                    (SELECT jsonb_agg(jsonb_build_object('id', et.event_type_id, 'name', et.event_type))
                     FROM public.event_types et) AS event_types,
                    (SELECT jsonb_agg(jsonb_build_object('id', ec.code_id, 'name', ec.event_code))
                     FROM public.club_code_link ccl
                     JOIN public.event_codes ec ON ccl.code_id = ec.code_id
                     WHERE ccl.club_id = t.club_id
                       AND (ccl.team_id IS NULL OR ccl.team_id = t.team_id)
                       AND public.team_has_code(t.team_id, ccl.code_id)) AS event_codes,
                    (SELECT jsonb_agg(jsonb_build_object(
                         'id', r_inner.role_id, 'name', r_inner.role_name,
                         'name_plural', r_inner.role_name_plural))
                     FROM public.team_roles_link trl
                     JOIN public.roles r_inner ON trl.role_id = r_inner.role_id
                     WHERE trl.team_id = t.team_id
                       AND r_inner.role_grade = 10 AND r_inner.show_audience = true) AS team_roles,
                    (SELECT jsonb_agg(jsonb_build_object(
                         'id', s.squad_id, 'name', s.squad_name, 'image', s.squad_image,
                         'squad_list_seq', s.squad_list_seq))
                     FROM public.squads s
                     WHERE s.team_id = t.team_id) AS squads
                FROM public.members m
                JOIN public.user_member_link uml ON m.member_id = uml.member_id
                JOIN public.member_team_link mtl ON m.member_id = mtl.member_id AND mtl.status = 'active'
                JOIN public.teams t ON mtl.team_id = t.team_id
                LEFT JOIN public.clubs c ON t.club_id = c.club_id
                JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
                JOIN public.roles r ON mtrl.role_id = r.role_id
                WHERE uml.user_id = p_user_id AND r.role_grade = 100
                ORDER BY t.team_id, r.role_level DESC
            ) team_data
        )
    ) INTO v_result;

    RETURN v_result;
END;
$function$;

-- Helper: is the signed-in user an admin (role grade 100) on the event's team?
CREATE OR REPLACE FUNCTION public.is_event_admin(p_event_id bigint)
 RETURNS boolean
 LANGUAGE sql
 SECURITY DEFINER
 STABLE
 SET search_path TO 'public'
AS $function$
    SELECT EXISTS (
        SELECT 1
        FROM public.events e
        JOIN public.member_team_link mtl ON mtl.team_id = e.team_id AND mtl.status = 'active'
        JOIN public.user_member_link uml ON uml.member_id = mtl.member_id AND uml.status = 'active'
        JOIN public.member_team_role_link mtrl ON mtrl.member_team_id = mtl.member_team_id
        JOIN public.roles r ON r.role_id = mtrl.role_id
        WHERE e.event_id = p_event_id
          AND uml.user_id = auth.uid()
          AND r.role_grade = 100
    );
$function$;

-- 5a. Save changes to one event or to it and every later event in its series.
-- p_changes holds only the fields the user changed (a key with a null value
-- clears that column). A new event_date_time moves the later events by the
-- same amount. Columns not in p_changes are left as they are on each event.
CREATE OR REPLACE FUNCTION public.update_event_series(p_event_id bigint, p_scope text, p_changes jsonb)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    e           public.events%ROWTYPE;
    v_delta     interval := NULL;
    v_new_dt    timestamp;
    v_count     integer := 0;
BEGIN
    IF auth.uid() IS NULL OR NOT public.is_event_admin(p_event_id) THEN
        RETURN json_build_object('success', false, 'message', 'Only team admins can edit events.');
    END IF;

    SELECT * INTO e FROM public.events WHERE event_id = p_event_id;
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Event not found.');
    END IF;

    IF p_changes ? 'event_date_time' AND p_changes->>'event_date_time' IS NOT NULL THEN
        v_new_dt := (p_changes->>'event_date_time')::timestamp;
        v_delta  := v_new_dt - COALESCE(e.event_date_time_2, (e.event_date_time AT TIME ZONE 'UTC'));
    END IF;

    UPDATE public.events x SET
        event_title        = CASE WHEN p_changes ? 'event_title'        THEN p_changes->>'event_title' ELSE x.event_title END,
        location_name      = CASE WHEN p_changes ? 'location_name'      THEN p_changes->>'location_name' ELSE x.location_name END,
        location_pin       = CASE WHEN p_changes ? 'location_pin'       THEN p_changes->>'location_pin' ELSE x.location_pin END,
        home_away          = CASE WHEN p_changes ? 'home_away'          THEN p_changes->>'home_away' ELSE x.home_away END,
        meet_time          = CASE WHEN p_changes ? 'meet_time'          THEN p_changes->>'meet_time' ELSE x.meet_time END,
        opposition         = CASE WHEN p_changes ? 'opposition'         THEN p_changes->>'opposition' ELSE x.opposition END,
        event_details      = CASE WHEN p_changes ? 'event_details'      THEN p_changes->>'event_details' ELSE x.event_details END,
        event_link         = CASE WHEN p_changes ? 'event_link'         THEN p_changes->>'event_link' ELSE x.event_link END,
        event_image        = CASE WHEN p_changes ? 'event_image'        THEN p_changes->>'event_image' ELSE x.event_image END,
        event_code_id      = CASE WHEN p_changes ? 'event_code_id'      THEN (p_changes->>'event_code_id')::bigint ELSE x.event_code_id END,
        event_type_id      = CASE WHEN p_changes ? 'event_type_id'      THEN (p_changes->>'event_type_id')::bigint ELSE x.event_type_id END,
        audience_id        = CASE WHEN p_changes ? 'audience_id'        THEN (p_changes->>'audience_id')::bigint ELSE x.audience_id END,
        squad_id           = CASE WHEN p_changes ? 'squad_id'           THEN (p_changes->>'squad_id')::bigint ELSE x.squad_id END,
        request_attendance = CASE WHEN p_changes ? 'request_attendance' THEN (p_changes->>'request_attendance')::boolean ELSE x.request_attendance END,
        payment_required   = CASE WHEN p_changes ? 'payment_required'   THEN (p_changes->>'payment_required')::boolean ELSE x.payment_required END,
        payment_amount     = CASE WHEN p_changes ? 'payment_amount'     THEN (p_changes->>'payment_amount')::smallint ELSE x.payment_amount END,
        event_date_time    = CASE WHEN v_delta IS NULL THEN x.event_date_time   ELSE x.event_date_time + v_delta END,
        event_date_time_2  = CASE WHEN v_delta IS NULL THEN x.event_date_time_2 ELSE x.event_date_time_2 + v_delta END
    WHERE x.event_id = p_event_id
       OR (p_scope = 'following'
           AND e.series_id IS NOT NULL
           AND x.series_id = e.series_id
           AND x.status <> 'deleted'
           AND x.event_date_time >= e.event_date_time);
    GET DIAGNOSTICS v_count = ROW_COUNT;

    RETURN json_build_object('success', true, 'events_updated', v_count);
END;
$function$;

-- 5b. Cancel / reinstate / delete one event or it and every later one in its series.
CREATE OR REPLACE FUNCTION public.set_event_series_status(p_event_id bigint, p_scope text, p_status text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    e        public.events%ROWTYPE;
    v_ids    bigint[];
BEGIN
    IF p_status NOT IN ('active', 'cancelled', 'deleted') THEN
        RETURN json_build_object('success', false, 'message', 'Unknown status.');
    END IF;
    IF auth.uid() IS NULL OR NOT public.is_event_admin(p_event_id) THEN
        RETURN json_build_object('success', false, 'message', 'Only team admins can change events.');
    END IF;

    SELECT * INTO e FROM public.events WHERE event_id = p_event_id;
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Event not found.');
    END IF;

    SELECT array_agg(x.event_id) INTO v_ids
    FROM public.events x
    WHERE x.event_id = p_event_id
       OR (p_scope = 'following'
           AND e.series_id IS NOT NULL
           AND x.series_id = e.series_id
           AND x.status <> 'deleted'
           AND x.event_date_time >= e.event_date_time);

    UPDATE public.events SET status = p_status WHERE event_id = ANY(v_ids);
    UPDATE public.event_attendance SET status = p_status WHERE event_id = ANY(v_ids);

    RETURN json_build_object('success', true, 'events_updated', COALESCE(array_length(v_ids, 1), 0));
END;
$function$;

REVOKE ALL ON FUNCTION public.update_event_series(bigint, text, jsonb) FROM anon;
REVOKE ALL ON FUNCTION public.set_event_series_status(bigint, text, text) FROM anon;
REVOKE ALL ON FUNCTION public.is_event_admin(bigint) FROM anon;
