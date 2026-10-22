-- St Annes follow-up (Ken, 2026-10-22): the first migration looked Clontarf up
-- by an exact name match, found nothing, so no codes or sport were copied.
-- Clontarf is the club behind the 'clontarf' lotto, so take it from there.

DO $$
DECLARE
  v_clontarf bigint;
  v_club     bigint;
BEGIN
  SELECT club_id INTO v_clontarf FROM public.lotto_clubs WHERE slug = 'clontarf';
  IF v_clontarf IS NULL THEN
    SELECT club_id INTO v_clontarf FROM public.clubs WHERE club_name ILIKE '%clontarf%' ORDER BY club_id LIMIT 1;
  END IF;
  SELECT club_id INTO v_club FROM public.clubs WHERE public.gaa_key(club_name) = 'stannes' ORDER BY club_id LIMIT 1;
  IF v_clontarf IS NULL OR v_club IS NULL THEN
    RAISE EXCEPTION 'Clontarf (%) or St Annes (%) not found', v_clontarf, v_club;
  END IF;

  UPDATE public.clubs SET sport_id = (SELECT sport_id FROM public.clubs WHERE club_id = v_clontarf)
  WHERE club_id = v_club AND sport_id IS NULL;

  -- Clontarf's club-wide codes (team-only codes like S&C are not copied)
  INSERT INTO public.club_code_link (club_id, code_id)
  SELECT DISTINCT v_club, ccl.code_id FROM public.club_code_link ccl
  WHERE ccl.club_id = v_clontarf AND ccl.team_id IS NULL
    AND NOT EXISTS (SELECT 1 FROM public.club_code_link x
                    WHERE x.club_id = v_club AND x.code_id = ccl.code_id AND x.team_id IS NULL);
END $$;
