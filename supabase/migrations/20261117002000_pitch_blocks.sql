-- Pitch planner: times a pitch is marked as not available (Ken, 2026-11-16).
-- Only what the club's sheet actually says ("No Slot", "Not Available",
-- floodlighting not permitted) is shaded on the board; a gap between held
-- slots is just a gap. One row per weekday and time range.

CREATE TABLE IF NOT EXISTS public.pitch_blocks (
  block_id  bigserial PRIMARY KEY,
  pitch_id  bigint NOT NULL REFERENCES public.pitches(pitch_id) ON DELETE CASCADE,
  weekday   smallint NOT NULL CHECK (weekday BETWEEN 1 AND 7),
  opens     time NOT NULL,
  closes    time NOT NULL CHECK (closes > opens),
  reason    text NOT NULL DEFAULT 'Not available'
);
CREATE INDEX IF NOT EXISTS pitch_blocks_pitch_idx ON public.pitch_blocks(pitch_id, weekday);
ALTER TABLE public.pitch_blocks ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.pitch_blocks FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.pitch_blocks_get(p_club bigint)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = 'public' AS $$
BEGIN
  PERFORM public.pitch_require_admin(p_club);
  RETURN coalesce((
    SELECT jsonb_agg(jsonb_build_object(
             'pitch_id', b.pitch_id, 'weekday', b.weekday,
             'opens', to_char(b.opens, 'HH24:MI'), 'closes', to_char(b.closes, 'HH24:MI'),
             'reason', b.reason) ORDER BY b.pitch_id, b.weekday, b.opens)
      FROM pitch_blocks b JOIN pitches p ON p.pitch_id = b.pitch_id
     WHERE p.club_id = p_club), '[]'::jsonb);
END $$;
REVOKE ALL ON FUNCTION public.pitch_blocks_get(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pitch_blocks_get(bigint) TO authenticated;

-- Clontarf, from "Pitch Calendar.xlsx" (week ending 22 Nov 2026).
DO $$
DECLARE
  rows text[][] := ARRAY[
    -- DCC Astro: "No Slot" outside the rented hours.
    ['DCC Astro','1','09:00','22:00','No slot'],
    ['DCC Astro','2','09:00','22:00','No slot'],
    ['DCC Astro','3','09:00','17:00','No slot'],
    ['DCC Astro','3','18:00','22:00','No slot'],
    ['DCC Astro','4','09:00','17:00','No slot'],
    ['DCC Astro','4','19:00','21:00','No slot'],
    ['DCC Astro','5','09:00','22:00','No slot'],
    ['DCC Astro','6','11:00','13:00','No slot'],
    ['DCC Astro','6','17:00','22:00','No slot'],
    ['DCC Astro','7','09:00','22:00','No slot'],
    -- St Paul's AWP 19:00: no slot Tuesday to Thursday.
    ['St Paul''s AWP','2','19:00','20:00','No slot'],
    ['St Paul''s AWP','3','19:00','20:00','No slot'],
    ['St Paul''s AWP','4','19:00','20:00','No slot'],
    -- Rugby Club AWP 20:45: no slot Friday.
    ['Rugby Club AWP','5','20:45','21:45','No slot'],
    -- Clubhouse Astro: no floodlights on Sunday night.
    ['Clubhouse Astro','7','21:10','22:00','Floodlighting not permitted']
  ];
  r text[];
  v_pitch bigint;
  d int;
BEGIN
  IF EXISTS (SELECT 1 FROM pitch_blocks b JOIN pitches p ON p.pitch_id = b.pitch_id WHERE p.club_id = 1) THEN
    RETURN;
  END IF;
  FOREACH r SLICE 1 IN ARRAY rows LOOP
    SELECT pitch_id INTO v_pitch FROM pitches WHERE club_id = 1 AND name = r[1];
    IF v_pitch IS NOT NULL THEN
      INSERT INTO pitch_blocks(pitch_id, weekday, opens, closes, reason)
      VALUES (v_pitch, r[2]::smallint, r[3]::time, r[4]::time, r[5]);
    END IF;
  END LOOP;
  -- St Anne's grass: 17:30-18:30 "Not Available" Monday to Friday.
  FOR v_pitch IN SELECT pitch_id FROM pitches WHERE club_id = 1 AND name IN ('Pitch 19','Pitch 21','Pitch 23','Pitch 30') LOOP
    FOR d IN 1..5 LOOP
      INSERT INTO pitch_blocks(pitch_id, weekday, opens, closes, reason)
      VALUES (v_pitch, d, '17:30', '18:30', 'Not available');
    END LOOP;
  END LOOP;
END $$;
