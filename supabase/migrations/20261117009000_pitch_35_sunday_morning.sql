-- Pitch planner (Ken, 2026-11-16 20:55): Pitch 35 is also free on Sunday
-- 08:00-10:00 (hourly slots).
INSERT INTO pitch_hours(pitch_id, weekday, opens, closes)
SELECT p.pitch_id, 7, t.o, t.o + interval '1 hour'
  FROM pitches p, (VALUES ('08:00'::time), ('09:00'::time)) t(o)
 WHERE p.club_id = 1 AND p.name = 'Pitch 35'
   AND NOT EXISTS (SELECT 1 FROM pitch_hours h WHERE h.pitch_id = p.pitch_id AND h.weekday = 7 AND h.opens = t.o);
