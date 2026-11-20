-- Pitch planner (Ken, 2026-11-20): some pitches are laid out on the same
-- ground, e.g. Clontarf's Pitch 23A runs across Pitch 23 and is smaller.
-- When one of a pair is booked the other is unavailable at that time, and
-- both booked at once is a clash. Additive only; v2 untouched.

CREATE TABLE IF NOT EXISTS public.pitch_shared_ground (
  club_id  bigint NOT NULL REFERENCES public.clubs(club_id) ON DELETE CASCADE,
  pitch_a  bigint NOT NULL REFERENCES public.pitches(pitch_id) ON DELETE CASCADE,
  pitch_b  bigint NOT NULL REFERENCES public.pitches(pitch_id) ON DELETE CASCADE,
  PRIMARY KEY (pitch_a, pitch_b),
  CHECK (pitch_a < pitch_b)
);
CREATE INDEX IF NOT EXISTS pitch_shared_ground_club_idx ON public.pitch_shared_ground(club_id);
ALTER TABLE public.pitch_shared_ground ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.pitch_shared_ground_get(p_club bigint)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = 'public' AS $$
BEGIN
  PERFORM public.pitch_require_admin(p_club);
  RETURN coalesce((
    SELECT jsonb_agg(jsonb_build_array(s.pitch_a, s.pitch_b) ORDER BY s.pitch_a, s.pitch_b)
      FROM pitch_shared_ground s WHERE s.club_id = p_club), '[]'::jsonb);
END $$;
REVOKE ALL ON FUNCTION public.pitch_shared_ground_get(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pitch_shared_ground_get(bigint) TO authenticated;

-- Clontarf: Pitch 23 and Pitch 23A.
INSERT INTO public.pitch_shared_ground (club_id, pitch_a, pitch_b)
SELECT 1, least(a.pitch_id, b.pitch_id), greatest(a.pitch_id, b.pitch_id)
  FROM pitches a JOIN pitches b ON b.club_id = a.club_id
 WHERE a.club_id = 1 AND a.name = 'Pitch 23' AND b.name = 'Pitch 23A'
ON CONFLICT DO NOTHING;
