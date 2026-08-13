-- RPC: create_recurring_events
-- Clones a source event into multiple recurring events.
--
-- p_recurring_type: 1 = weekly, 2 = fortnightly
-- p_num_weeks:      total weeks the recurrence spans (max 12)
--   weekly/8 weeks      → 8 new events at +1,+2,...,+8 weeks
--   fortnightly/8 weeks → 4 new events at +2,+4,+6,+8 weeks
--
-- Both event_date_time (timestamptz) and event_date_time_2 (timestamp)
-- have the offset applied as-is — no TZ conversion, event time is local.

CREATE OR REPLACE FUNCTION public.create_recurring_events(
    p_source_event_id       INTEGER,
    p_event_title           TEXT,
    p_recurring_type        INTEGER,   -- 1=weekly, 2=fortnightly
    p_num_weeks             INTEGER,   -- 1–12
    p_notify_admins_changes BOOLEAN DEFAULT false,
    p_notify_admins_all     BOOLEAN DEFAULT false
)
RETURNS TABLE(
    events_created  INTEGER,
    event_ids       INTEGER[],
    message         TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    source_event    public.events%ROWTYPE;
    new_event_id    INTEGER;
    created_ids     INTEGER[] := '{}';
    num_events      INTEGER;
    interval_weeks  INTEGER;
    i               INTEGER;
    offset_interval INTERVAL;
BEGIN
    -- Validate recurring type
    IF p_recurring_type NOT IN (1, 2) THEN
        RETURN QUERY SELECT 0, '{}'::INTEGER[],
            'p_recurring_type must be 1 (weekly) or 2 (fortnightly).'::TEXT;
        RETURN;
    END IF;

    -- Validate num_weeks
    IF p_num_weeks IS NULL OR p_num_weeks < 1 OR p_num_weeks > 12 THEN
        RETURN QUERY SELECT 0, '{}'::INTEGER[],
            'p_num_weeks must be between 1 and 12.'::TEXT;
        RETURN;
    END IF;

    -- Fetch source event
    SELECT * INTO source_event
    FROM public.events
    WHERE event_id = p_source_event_id;

    IF NOT FOUND THEN
        RETURN QUERY SELECT 0, '{}'::INTEGER[],
            ('Source event ' || p_source_event_id::TEXT || ' not found.')::TEXT;
        RETURN;
    END IF;

    -- Derive loop count and step
    IF p_recurring_type = 1 THEN
        interval_weeks := 1;
        num_events     := p_num_weeks;
    ELSE
        interval_weeks := 2;
        num_events     := p_num_weeks / 2;
    END IF;

    -- Create each recurring event
    FOR i IN 1..num_events LOOP
        offset_interval := (i * interval_weeks || ' weeks')::INTERVAL;

        INSERT INTO public.events (
            created_at,
            event_title,
            event_date_time,
            event_date_time_2,
            location_pin,
            location_name,
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
            notify_admins_changes,
            notify_admins_all,
            status
        )
        VALUES (
            NOW(),
            p_event_title,
            source_event.event_date_time  + offset_interval,
            CASE WHEN source_event.event_date_time_2 IS NOT NULL
                 THEN source_event.event_date_time_2 + offset_interval
                 ELSE NULL END,
            source_event.location_pin,
            source_event.location_name,
            source_event.created_by,
            source_event.team_id,
            source_event.event_code_id,
            source_event.event_type_id,
            source_event.audience_id,
            source_event.request_attendance,
            source_event.event_details,
            source_event.squad_id,
            source_event.meet_time,
            source_event.opposition,
            p_notify_admins_changes,
            p_notify_admins_all,
            source_event.status
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
