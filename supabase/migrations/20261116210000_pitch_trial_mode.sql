-- Pitch planner trial mode (Ken, 2026-11-16): while a club is trying the
-- planner out, bookings still link to CoachSmart events (so the board knows
-- an event has a pitch) but nothing is written to the events themselves:
-- no new location, and no "put the old location back" either. Clontarf
-- starts in trial mode. Turn it off per club with
--   UPDATE pitch_club_settings SET write_events = true WHERE club_id = <id>;

ALTER TABLE public.pitch_club_settings ADD COLUMN IF NOT EXISTS write_events boolean NOT NULL DEFAULT true;

INSERT INTO public.pitch_club_settings(club_id, write_events) VALUES (1, false)
ON CONFLICT (club_id) DO UPDATE SET write_events = false;

-- True when the planner may change this event's location.
CREATE OR REPLACE FUNCTION public.pitch_event_writes_on(p_event bigint)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = 'public' AS $$
  SELECT coalesce((SELECT s.write_events
                     FROM events e
                     JOIN teams t ON t.team_id = e.team_id
                     JOIN pitch_club_settings s ON s.club_id = t.club_id
                    WHERE e.event_id = p_event), true);
$$;
REVOKE ALL ON FUNCTION public.pitch_event_writes_on(bigint) FROM PUBLIC, anon, authenticated;

-- Add the check to every place the planner writes to events.
DO $$
DECLARE
  f record;
  src text;
  fixes text[][] := ARRAY[
    ['pitch_apply_following(bigint)',
     'WHERE e.event_id = b.event_id AND b.status = ''confirmed'' AND v_loc IS NOT NULL;',
     'WHERE e.event_id = b.event_id AND b.status = ''confirmed'' AND v_loc IS NOT NULL AND public.pitch_event_writes_on(e.event_id);'],
    ['pitch_booking_delete(bigint,bigint,boolean)',
     'UPDATE events SET location_name = b.prev_location, location_pin = b.prev_pin
       WHERE event_id = b.event_id;',
     'UPDATE events SET location_name = b.prev_location, location_pin = b.prev_pin
       WHERE event_id = b.event_id AND public.pitch_event_writes_on(b.event_id);'],
    ['pitch_booking_save(bigint,jsonb)',
     'location_pin = coalesce(v_pin, location_pin)
       WHERE event_id = v_event;',
     'location_pin = coalesce(v_pin, location_pin)
       WHERE event_id = v_event AND public.pitch_event_writes_on(v_event);'],
    ['pitch_roll_week(bigint,date)',
     'UPDATE events SET location_name = v_loc, location_pin = coalesce(v_pin, location_pin)
         WHERE event_id = v_ev;',
     'UPDATE events SET location_name = v_loc, location_pin = coalesce(v_pin, location_pin)
         WHERE event_id = v_ev AND public.pitch_event_writes_on(v_ev);'],
    ['pitch_unlink_moved(bigint)',
     'UPDATE events SET location_name = b.prev_location, location_pin = b.prev_pin WHERE event_id = b.event_id;',
     'UPDATE events SET location_name = b.prev_location, location_pin = b.prev_pin WHERE event_id = b.event_id AND public.pitch_event_writes_on(b.event_id);']
  ];
  i int;
BEGIN
  FOR i IN 1 .. array_length(fixes, 1) LOOP
    src := pg_get_functiondef(fixes[i][1]::regprocedure);
    IF position('pitch_event_writes_on' IN src) > 0 THEN CONTINUE; END IF;
    IF position(fixes[i][2] IN src) = 0 THEN
      RAISE EXCEPTION 'pitch trial mode: text not found in %', fixes[i][1];
    END IF;
    EXECUTE replace(src, fixes[i][2], fixes[i][3]);
  END LOOP;
END $$;
