-- Pitch planner: home-match defaults per group and "Fill from defaults"
-- (Ken, 2026-11-17). Each group (team) has a default home pitch, day and
-- time. The Fixtures tab books every unassigned home match of the week onto
-- its group's pitch; league fixtures keep the league throw-in time. Squads
-- of one team share the default, so they may clash; the admin swaps them.
-- Auto-filled bookings are flagged until the admin changes or accepts them.

ALTER TABLE public.pitch_groups
  ADD COLUMN IF NOT EXISTS home_pitch_id bigint REFERENCES public.pitches(pitch_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS home_day smallint CHECK (home_day BETWEEN 1 AND 7),
  ADD COLUMN IF NOT EXISTS home_time time;

ALTER TABLE public.pitch_bookings
  ADD COLUMN IF NOT EXISTS auto boolean NOT NULL DEFAULT false;

-- Moving an auto-filled booking (pitch, part, time or status) makes it the
-- admin's own.
CREATE OR REPLACE FUNCTION public.pitch_bookings_auto_clear()
RETURNS trigger LANGUAGE plpgsql SET search_path = 'public' AS $$
BEGIN
  IF OLD.auto AND NEW.auto AND (
       NEW.pitch_id IS DISTINCT FROM OLD.pitch_id OR NEW.part IS DISTINCT FROM OLD.part
       OR NEW.starts_at IS DISTINCT FROM OLD.starts_at OR NEW.status IS DISTINCT FROM OLD.status) THEN
    NEW.auto := false;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS pitch_bookings_auto_clear ON public.pitch_bookings;
CREATE TRIGGER pitch_bookings_auto_clear BEFORE UPDATE ON public.pitch_bookings
  FOR EACH ROW EXECUTE FUNCTION public.pitch_bookings_auto_clear();

CREATE OR REPLACE FUNCTION public.pitch_group_homes_get(p_club bigint)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = 'public' AS $$
BEGIN
  PERFORM public.pitch_require_admin(p_club);
  RETURN coalesce((
    SELECT jsonb_agg(jsonb_build_object('group_id', g.group_id, 'pitch_id', g.home_pitch_id,
             'day', g.home_day, 'time', to_char(g.home_time, 'HH24:MI')))
      FROM pitch_groups g
     WHERE g.club_id = p_club AND g.home_pitch_id IS NOT NULL), '[]'::jsonb);
END $$;

CREATE OR REPLACE FUNCTION public.pitch_group_home_save(p_club bigint, p_group bigint,
  p_pitch bigint, p_day int, p_time text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $$
BEGIN
  PERFORM public.pitch_require_admin(p_club);
  IF p_pitch IS NOT NULL AND NOT EXISTS (SELECT 1 FROM pitches WHERE pitch_id = p_pitch AND club_id = p_club) THEN
    RAISE EXCEPTION 'Pitch not found';
  END IF;
  UPDATE pitch_groups SET home_pitch_id = p_pitch, home_day = p_day,
         home_time = nullif(p_time, '')::time
   WHERE group_id = p_group AND club_id = p_club;
  IF NOT FOUND THEN RAISE EXCEPTION 'Group not found'; END IF;
END $$;

-- Saves the bookings the page worked out (same shape as pitch_booking_save_v2)
-- and flags them auto. A row that fails (e.g. fixture gone) is skipped.
CREATE OR REPLACE FUNCTION public.pitch_autofill_save(p_club bigint, p_items jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $$
DECLARE
  it jsonb;
  v_id bigint;
  n_ok int := 0;
  n_skip int := 0;
BEGIN
  PERFORM public.pitch_require_admin(p_club);
  FOR it IN SELECT * FROM jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) LOOP
    BEGIN
      v_id := public.pitch_booking_save_v2(p_club, it - 'booking_id');
      UPDATE pitch_bookings SET auto = true WHERE booking_id = v_id;
      n_ok := n_ok + 1;
    EXCEPTION WHEN others THEN
      n_skip := n_skip + 1;
    END;
  END LOOP;
  RETURN jsonb_build_object('added', n_ok, 'skipped', n_skip);
END $$;

CREATE OR REPLACE FUNCTION public.pitch_auto_ids(p_club bigint, p_monday date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = 'public' AS $$
BEGIN
  PERFORM public.pitch_require_admin(p_club);
  RETURN coalesce((SELECT jsonb_agg(booking_id) FROM pitch_bookings
     WHERE club_id = p_club AND auto AND starts_at >= p_monday AND starts_at < p_monday + 7), '[]'::jsonb);
END $$;

-- "Keep them": the week's auto bookings become ordinary ones.
CREATE OR REPLACE FUNCTION public.pitch_autofill_accept(p_club bigint, p_monday date)
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $$
DECLARE n int;
BEGIN
  PERFORM public.pitch_require_admin(p_club);
  UPDATE pitch_bookings SET auto = false
   WHERE club_id = p_club AND auto AND starts_at >= p_monday AND starts_at < p_monday + 7;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END $$;

-- "Undo fill": removes the week's auto bookings still untouched.
CREATE OR REPLACE FUNCTION public.pitch_autofill_undo(p_club bigint, p_monday date)
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $$
DECLARE
  b bigint;
  n int := 0;
BEGIN
  PERFORM public.pitch_require_admin(p_club);
  FOR b IN SELECT booking_id FROM pitch_bookings
            WHERE club_id = p_club AND auto AND starts_at >= p_monday AND starts_at < p_monday + 7 LOOP
    PERFORM public.pitch_booking_delete(p_club, b, false);
    n := n + 1;
  END LOOP;
  RETURN n;
END $$;

DO $$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY['pitch_group_homes_get(bigint)',
    'pitch_group_home_save(bigint,bigint,bigint,int,text)', 'pitch_autofill_save(bigint,jsonb)',
    'pitch_auto_ids(bigint,date)', 'pitch_autofill_accept(bigint,date)', 'pitch_autofill_undo(bigint,date)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO authenticated', f);
  END LOOP;
END $$;

-- Clontarf: best guesses from this year's weekend home matches on CoachSmart
-- (most common pitch and time) and the club sheet; the admin reviews them.
DO $$
DECLARE
  rows text[][] := ARRAY[
    ['U8 Boys','Pitch 19','6','10:00'],
    ['U9 Boys','Pitch 23','6','11:00'],
    ['U10 Boys','Pitch 19','6','09:30'],
    ['U12 Boys','Pitch 21','6','12:00'],
    ['U13 Boys','Pitch 21','6','13:00'],
    ['U14 Boys','Pitch 19','6','09:45'],
    ['U8 Girls','Pitch 30','7','09:30'],
    ['U9 Girls','Pitch 23','7','10:00'],
    ['U10 Girls','Pitch 19','6','12:00'],
    ['U11 Girls','Pitch 19','6','13:00'],
    ['U12 Girls','Pitch 23','6','12:30'],
    ['U13 Girls','Pitch 21','7','13:45'],
    ['U14 Girls','Pitch 19','7','14:30'],
    ['U21 Camogie','Pitch 34','2','20:00']
  ];
  r text[];
BEGIN
  FOREACH r SLICE 1 IN ARRAY rows LOOP
    UPDATE pitch_groups g SET home_pitch_id = p.pitch_id, home_day = r[3]::smallint, home_time = r[4]::time
      FROM pitches p
     WHERE g.club_id = 1 AND g.name = r[1] AND g.home_pitch_id IS NULL
       AND p.club_id = 1 AND p.name = r[2];
  END LOOP;
END $$;
