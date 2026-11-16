-- Pitch planner (Ken, 2026-11-16): Pitch 23A follows the same rules as the
-- other St Anne's grass pitches: not available on weekdays (its weekend
-- slots are already one all-day block).
INSERT INTO public.pitch_blocks(pitch_id, weekday, opens, closes, reason)
SELECT p.pitch_id, d, '08:00', '22:00', 'Not available on weekdays'
  FROM public.pitches p, generate_series(1, 5) d
 WHERE p.club_id = 1 AND p.name = 'Pitch 23A'
   AND NOT EXISTS (SELECT 1 FROM public.pitch_blocks x
                    WHERE x.pitch_id = p.pitch_id AND x.weekday = d);
