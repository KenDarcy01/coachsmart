-- Pitch planner: club admins edit a pitch's "not available" times from the
-- v3 Availability tab (Ken, 2026-11-16: slots change with the clocks, so the
-- admin needs to update them regularly). Replaces every block of one pitch.
-- p_blocks: [{"weekday":1,"opens":"08:00","closes":"22:00","reason":"..."}]

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
      VALUES (p_pitch, (b->>'weekday')::smallint, (b->>'opens')::time, (b->>'closes')::time,
              coalesce(nullif(trim(b->>'reason'), ''), 'Not available'));
    END IF;
  END LOOP;
  RETURN public.pitch_blocks_get(p_club);
END $$;
REVOKE ALL ON FUNCTION public.pitch_blocks_save(bigint, bigint, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pitch_blocks_save(bigint, bigint, jsonb) TO authenticated;
