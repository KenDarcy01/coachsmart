-- Fix NULL handling: treat NULL p_recurring_type as 0 (non-recurring)
-- so callers don't need to explicitly pass 0 for single events.

CREATE OR REPLACE FUNCTION public.create_recurring_events(
    p_recurring_type        INTEGER,
    p_num_weeks             INTEGER,
    p_event_title           TEXT            DEFAULT NULL,
    p_event_date_time       TIMESTAMPTZ     DEFAULT NULL,
    p_event_date_time_2     TIMESTAMP       DEFAULT NULL,
    p_team_id               BIGINT          DEFAULT NULL,
    p_created_by            UUID            DEFAULT NULL,
    p_event_type_id         BIGINT          DEFAULT NULL,
    p_event_code_id         BIGINT          DEFAULT NULL,
    p_audience_id           BIGINT          DEFAULT NULL,
    p_squad_id              BIGINT          DEFAULT NULL,
    p_location_name         TEXT            DEFAULT NULL,
    p_location_pin          TEXT            DEFAULT NULL,
    p_home_away             TEXT            DEFAULT NULL,
    p_meet_time             TEXT            DEFAULT NULL,
    p_opposition            TEXT            DEFAULT NULL,
    p_event_details         TEXT            DEFAULT NULL,
    p_event_link            TEXT            DEFAULT NULL,
    p_request_attendance    BOOLEAN         DEFAULT false,
    p_notify_admins_changes BOOLEAN         DEFAULT false,
    p_notify_admins_all     BOOLEAN         DEFAULT false,
    p_payment_required      BOOLEAN         DEFAULT false,
    p_payment_amount        SMALLINT        DEFAULT NULL,
    p_car_pooling           BOOLEAN         DEFAULT false
)
RETURNS TABLE(
    events_created  INTEGER,
    event_ids       BIGINT[],
    message         TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    new_event_id    BIGINT;
    created_ids     BIGINT[] := '{}';
    num_events      INTEGER;
    interval_weeks  INTEGER;
    i               INTEGER;
    offset_interval INTERVAL;
BEGIN
    -- Default NULLs so callers can omit these fields entirely
    p_recurring_type := COALESCE(p_recurring_type, 0);
    p_num_weeks      := COALESCE(p_num_weeks, 0);

    IF p_recurring_type NOT IN (0, 1, 2) THEN
        RETURN QUERY SELECT 0, '{}'::BIGINT[],
            'p_recurring_type must be 0 (none), 1 (weekly) or 2 (fortnightly).'::TEXT;
        RETURN;
    END IF;

    IF p_event_date_time IS NULL THEN
        RETURN QUERY SELECT 0, '{}'::BIGINT[],
            'p_event_date_time is required.'::TEXT;
        RETURN;
    END IF;

    -- Non-recurring: insert one event at exactly the given date
    IF p_recurring_type = 0 THEN
        INSERT INTO public.events (
            created_at, event_title, event_date_time, event_date_time_2,
            location_pin, location_name, home_away, created_by, team_id,
            event_code_id, event_type_id, audience_id, request_attendance,
            event_details, squad_id, meet_time, opposition, event_link,
            notify_admins_changes, notify_admins_all,
            payment_required, payment_amount, car_pooling, status
        ) VALUES (
            NOW(), p_event_title, p_event_date_time, p_event_date_time_2,
            p_location_pin, p_location_name, p_home_away, p_created_by, p_team_id,
            p_event_code_id, p_event_type_id, p_audience_id, p_request_attendance,
            p_event_details, p_squad_id, p_meet_time, p_opposition, p_event_link,
            p_notify_admins_changes, p_notify_admins_all,
            p_payment_required, p_payment_amount, p_car_pooling, 'active'
        )
        RETURNING event_id INTO new_event_id;

        created_ids := array_append(created_ids, new_event_id);
        RETURN QUERY SELECT 1, created_ids,
            ('1 event created successfully. ID: ' || new_event_id::TEXT)::TEXT;
        RETURN;
    END IF;

    -- Recurring: validate num_weeks
    IF p_num_weeks < 1 OR p_num_weeks > 12 THEN
        RETURN QUERY SELECT 0, '{}'::BIGINT[],
            'p_num_weeks must be between 1 and 12 for recurring events.'::TEXT;
        RETURN;
    END IF;

    IF p_recurring_type = 1 THEN
        interval_weeks := 1;
        num_events     := p_num_weeks;
    ELSE
        interval_weeks := 2;
        num_events     := p_num_weeks / 2;
    END IF;

    FOR i IN 1..num_events LOOP
        offset_interval := (i * interval_weeks || ' weeks')::INTERVAL;

        INSERT INTO public.events (
            created_at, event_title, event_date_time, event_date_time_2,
            location_pin, location_name, home_away, created_by, team_id,
            event_code_id, event_type_id, audience_id, request_attendance,
            event_details, squad_id, meet_time, opposition, event_link,
            notify_admins_changes, notify_admins_all,
            payment_required, payment_amount, car_pooling, status
        ) VALUES (
            NOW(), p_event_title,
            p_event_date_time + offset_interval,
            CASE WHEN p_event_date_time_2 IS NOT NULL
                 THEN p_event_date_time_2 + offset_interval ELSE NULL END,
            p_location_pin, p_location_name, p_home_away, p_created_by, p_team_id,
            p_event_code_id, p_event_type_id, p_audience_id, p_request_attendance,
            p_event_details, p_squad_id, p_meet_time, p_opposition, p_event_link,
            p_notify_admins_changes, p_notify_admins_all,
            p_payment_required, p_payment_amount, p_car_pooling, 'active'
        )
        RETURNING event_id INTO new_event_id;

        created_ids := array_append(created_ids, new_event_id);
    END LOOP;

    RETURN QUERY SELECT
        array_length(created_ids, 1),
        created_ids,
        (array_length(created_ids, 1)::TEXT
            || ' event(s) created successfully. IDs: '
            || array_to_string(created_ids, ', '))::TEXT;
END;
$$;
