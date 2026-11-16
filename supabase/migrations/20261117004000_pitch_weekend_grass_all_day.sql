-- Pitch planner (Ken, 2026-11-16): at weekends Clontarf has its St Anne's
-- grass pitches all day. The sheet's weekend times are how each day was
-- split up, not separate rentals, so each grass pitch gets one slot per
-- weekend day from its first sheet time to its last (no gaps or overlaps).
-- The AWPs have nothing on the sheet at weekends: shaded "No slot".
CREATE TEMP TABLE pitch_wk_span ON COMMIT DROP AS
SELECT h.pitch_id, h.weekday, min(h.opens) AS opens, max(h.closes) AS closes
  FROM public.pitch_hours h
  JOIN public.pitches p ON p.pitch_id = h.pitch_id
 WHERE p.club_id = 1 AND p.surface = 'grass' AND h.weekday IN (6, 7)
 GROUP BY h.pitch_id, h.weekday;

DELETE FROM public.pitch_hours h
 USING pitch_wk_span s
 WHERE h.pitch_id = s.pitch_id AND h.weekday = s.weekday;

INSERT INTO public.pitch_hours(pitch_id, weekday, opens, closes)
SELECT pitch_id, weekday, opens, closes FROM pitch_wk_span;

INSERT INTO public.pitch_blocks(pitch_id, weekday, opens, closes, reason)
SELECT p.pitch_id, d, '08:00', '22:00', 'No slot'
  FROM public.pitches p, generate_series(6, 7) d
 WHERE p.club_id = 1 AND p.name IN ('St Paul''s AWP', 'Rugby Club AWP')
   AND NOT EXISTS (SELECT 1 FROM public.pitch_blocks x
                    WHERE x.pitch_id = p.pitch_id AND x.weekday = d);
