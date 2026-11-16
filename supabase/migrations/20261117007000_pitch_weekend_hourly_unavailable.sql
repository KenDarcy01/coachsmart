-- Pitch planner (Ken, 2026-11-16 20:22):
-- 1. Weekend grass back to hourly slots: each Sat/Sun all-day slot is split
--    into one-hour slots from its start (the last one may be shorter).
-- 2. One word for every time a pitch can't be used: "Unavailable".
DO $$
DECLARE
  h record;
  m time;
BEGIN
  FOR h IN
    SELECT ph.* FROM pitch_hours ph JOIN pitches p ON p.pitch_id = ph.pitch_id
     WHERE p.club_id = 1 AND p.surface = 'grass' AND ph.weekday IN (6, 7)
       AND ph.closes - ph.opens > interval '90 minutes'
  LOOP
    DELETE FROM pitch_hours WHERE pitch_id = h.pitch_id AND weekday = h.weekday
       AND opens = h.opens AND closes = h.closes;
    m := h.opens;
    WHILE m < h.closes LOOP
      INSERT INTO pitch_hours(pitch_id, weekday, opens, closes)
      VALUES (h.pitch_id, h.weekday, m, least(m + interval '1 hour', h.closes));
      m := m + interval '1 hour';
    END LOOP;
  END LOOP;
END $$;

UPDATE pitch_blocks SET reason = 'Unavailable' WHERE reason <> 'Unavailable';
ALTER TABLE pitch_blocks ALTER COLUMN reason SET DEFAULT 'Unavailable';

CREATE OR REPLACE FUNCTION public.pitch_blocks_save(p_club bigint, p_pitch bigint, p_blocks jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $$
DECLARE
  b jsonb;
BEGIN
  PERFORM public.pitch_require_admin(p_club);
  IF NOT EXISTS (SELECT 1 FROM pitches WHERE pitch_id = p_pitch AND club_id = p_club) THEN
    RAISE EXCEPTION 'Pitch not found';
  END IF;
  DELETE FROM pitch_blocks WHERE pitch_id = p_pitch;
  FOR b IN SELECT * FROM jsonb_array_elements(coalesce(p_blocks, '[]'::jsonb)) LOOP
    IF (b->>'closes')::time > (b->>'opens')::time THEN
      INSERT INTO pitch_blocks(pitch_id, weekday, opens, closes, reason)
      VALUES (p_pitch, (b->>'weekday')::smallint, (b->>'opens')::time, (b->>'closes')::time, 'Unavailable');
    END IF;
  END LOOP;
  RETURN public.pitch_blocks_get(p_club);
END $$;
