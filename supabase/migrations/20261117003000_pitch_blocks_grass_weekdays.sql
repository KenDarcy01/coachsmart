-- Pitch planner (Ken, 2026-11-16): on Clontarf's sheet the St Anne's grass
-- pitches 19, 21, 23 and 30 show only one weekday row, "17:30 - 18:30",
-- marked "Not Available" every weekday, and nothing else held. That reads
-- as "no weekday use at all" (winter), not "unavailable for that one hour",
-- so shade the whole weekday instead of a 17:30-18:30 band.
DELETE FROM public.pitch_blocks b
 USING public.pitches p
 WHERE p.pitch_id = b.pitch_id AND p.club_id = 1
   AND p.name IN ('Pitch 19', 'Pitch 21', 'Pitch 23', 'Pitch 30')
   AND b.weekday BETWEEN 1 AND 5 AND b.opens = '17:30' AND b.closes = '18:30';

INSERT INTO public.pitch_blocks(pitch_id, weekday, opens, closes, reason)
SELECT p.pitch_id, d, '08:00', '22:00', 'Not available on weekdays'
  FROM public.pitches p, generate_series(1, 5) d
 WHERE p.club_id = 1 AND p.name IN ('Pitch 19', 'Pitch 21', 'Pitch 23', 'Pitch 30')
   AND NOT EXISTS (SELECT 1 FROM public.pitch_blocks x
                    WHERE x.pitch_id = p.pitch_id AND x.weekday = d AND x.opens = '08:00');
