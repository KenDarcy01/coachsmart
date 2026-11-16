-- Pitch planner (Ken, 2026-11-16 21:00): grass pitches without floodlights
-- are free at weekends 08:00-18:00, in hourly slots. Replaces their Sat/Sun
-- slots and clears unavailable times inside those hours.
DO $$
DECLARE
  p bigint;
  d int;
  m time;
BEGIN
  FOR p IN SELECT pitch_id FROM pitches
            WHERE club_id = 1 AND surface = 'grass' AND NOT coalesce(floodlit, false) LOOP
    FOR d IN 6..7 LOOP
      DELETE FROM pitch_hours WHERE pitch_id = p AND weekday = d;
      DELETE FROM pitch_blocks WHERE pitch_id = p AND weekday = d
         AND opens < '18:00' AND closes > '08:00';
      m := '08:00';
      WHILE m < '18:00' LOOP
        INSERT INTO pitch_hours(pitch_id, weekday, opens, closes) VALUES (p, d, m, m + interval '1 hour');
        m := m + interval '1 hour';
      END LOOP;
    END LOOP;
  END LOOP;
END $$;
