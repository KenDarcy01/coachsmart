-- Pitch planner (Ken, 2026-11-16 20:47): every grass pitch's slots run on
-- the hour for an hour. Each pitch-day's span (first opens to last closes)
-- is rounded to the nearest hour (a start at :30 rounds down, an end at :30
-- rounds up) and split into one-hour slots.
DO $$
DECLARE
  r record;
  m time;
BEGIN
  FOR r IN
    SELECT h.pitch_id, h.weekday,
           date_trunc('hour', '2000-01-01'::date + min(h.opens)
             + CASE WHEN extract(minute FROM min(h.opens)) > 30 THEN interval '1 hour' ELSE interval '0' END)::time AS o,
           date_trunc('hour', '2000-01-01'::date + max(h.closes)
             + CASE WHEN extract(minute FROM max(h.closes)) >= 30 THEN interval '1 hour' ELSE interval '0' END)::time AS c
      FROM pitch_hours h JOIN pitches p ON p.pitch_id = h.pitch_id
     WHERE p.club_id = 1 AND p.surface = 'grass'
     GROUP BY h.pitch_id, h.weekday
  LOOP
    DELETE FROM pitch_hours WHERE pitch_id = r.pitch_id AND weekday = r.weekday;
    m := r.o;
    WHILE m < r.c AND m >= r.o LOOP
      INSERT INTO pitch_hours(pitch_id, weekday, opens, closes)
      VALUES (r.pitch_id, r.weekday, m, m + interval '1 hour');
      m := m + interval '1 hour';
    END LOOP;
  END LOOP;
END $$;
