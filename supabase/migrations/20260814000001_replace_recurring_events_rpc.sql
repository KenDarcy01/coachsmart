-- Replace create_recurring_events with the correct version.
-- The original cloned a source event; this version creates events from scratch
-- using field values passed directly as parameters.
--
-- p_recurring_type: 1 = weekly, 2 = fortnightly
-- p_num_weeks:      total weeks the recurrence spans (max 12)
--   weekly/8 weeks      → 8 events at +1, +2, … +8 weeks
--   fortnightly/8 weeks → 4 events at +2, +4, +6, +8 weeks

-- Drop old overload (different parameter list)
DROP FUNCTION IF EXISTS public.create_recurring_events(integer, text, integer, integer, boolean, boolean);

CREATE OR REPLACE FUNCTION public.create_recurring_events(
    -- Recurrence control
    p_recurring_type        INTEGER,                    -- 1=weekly, 2=fortnightly
    p_num_weeks             INTEGER,                    -- 1–12

    -- Event fields
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
    -- Validate recurring type
    IF p_recurring_type NOT IN (1, 2) THEN
        RETURN QUERY SELECT 0, '{}'::BIGINT[],
            'p_recurring_type must be 1 (weekly) or 2 (fortnightly).'::TEXT;
        RETURN;
    END IF;

    -- Validate num_weeks
    IF p_num_weeks IS NULL OR p_num_weeks < 1 OR p_num_weeks > 12 THEN
        RETURN QUERY SELECT 0, '{}'::BIGINT[],
            'p_num_weeks must be between 1 and 12.'::TEXT;
        RETURN;
    END IF;

    -- Require a start date
    IF p_event_date_time IS NULL THEN
        RETURN QUERY SELECT 0, '{}'::BIGINT[],
            'p_event_date_time is required.'::TEXT;
        RETURN;
    END IF;

    -- Derive loop count and week step
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
            created_at,
            event_title,
            event_date_time,
            event_date_time_2,
            location_pin,
            location_name,
            home_away,
            created_by,
            team_id,
            event_code_id,
            event_type_id,
            audience_id,
            request_attendance,
            event_details,
            squad_id,
            meet_time,
            opposition,
            event_link,
            notify_admins_changes,
            notify_admins_all,
            payment_required,
            payment_amount,
            car_pooling,
            status
        )
        VALUES (
            NOW(),
            p_event_title,
            p_event_date_time + offset_interval,
            CASE WHEN p_event_date_time_2 IS NOT NULL
                 THEN p_event_date_time_2 + offset_interval
                 ELSE NULL END,
            p_location_pin,
            p_location_name,
            p_home_away,
            p_created_by,
            p_team_id,
            p_event_code_id,
            p_event_type_id,
            p_audience_id,
            p_request_attendance,
            p_event_details,
            p_squad_id,
            p_meet_time,
            p_opposition,
            p_event_link,
            p_notify_admins_changes,
            p_notify_admins_all,
            p_payment_required,
            p_payment_amount,
            p_car_pooling,
            'active'
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
