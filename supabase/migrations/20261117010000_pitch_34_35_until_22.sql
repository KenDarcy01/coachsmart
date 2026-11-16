-- Pitch planner (Ken, 2026-11-16 20:59): Pitches 34 and 35 are free until
-- 22:00 every night. Adds hourly slots from each day's last slot to 22:00
-- (or from 19:00 on a day with none) and clears any unavailable time there.
DO $$
DECLARE
  p bigint;
  d int;
  m time;
BEGIN
  FOR p IN SELECT pitch_id FROM pitches WHERE club_id = 1 AND name IN ('Pitch 34', 'Pitch 35') LOOP
    FOR d IN 1..7 LOOP
      SELECT coalesce(max(closes), '19:00') INTO m FROM pitch_hours WHERE pitch_id = p AND weekday = d;
      DELETE FROM pitch_blocks WHERE pitch_id = p AND weekday = d AND closes > m;
      WHILE m < '22:00' LOOP
        INSERT INTO pitch_hours(pitch_id, weekday, opens, closes)
        VALUES (p, d, m, least(m + interval '1 hour', '22:00'::time));
        m := m + interval '1 hour';
      END LOOP;
    END LOOP;
  END LOOP;
END $$;
