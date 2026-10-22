-- New club: Kilmacud Crokes (Stillorgan, Dublin). Ken, 2026-10-22.
-- Set up like St Annes: Clontarf's sport and club-wide codes. Crest and
-- colours are added separately once Ken sends the crest.
-- Only runs once: does nothing if a Kilmacud club already exists.

DO $$
DECLARE
  v_clontarf bigint;
  v_club     bigint;
BEGIN
  IF EXISTS (SELECT 1 FROM public.clubs WHERE club_name ILIKE '%kilmacud%') THEN
    RAISE NOTICE 'Kilmacud Crokes already exists, nothing to do';
    RETURN;
  END IF;

  SELECT club_id INTO v_clontarf FROM public.lotto_clubs WHERE slug = 'clontarf';
  IF v_clontarf IS NULL THEN
    SELECT club_id INTO v_clontarf FROM public.clubs WHERE club_name ILIKE '%clontarf%' ORDER BY club_id LIMIT 1;
  END IF;
  IF v_clontarf IS NULL THEN
    RAISE EXCEPTION 'Clontarf not found';
  END IF;

  INSERT INTO public.clubs (club_name, county, sport_id, gaa_club_id)
  SELECT 'Kilmacud Crokes', 'Dublin',
         (SELECT sport_id FROM public.clubs WHERE club_id = v_clontarf),
         (SELECT club_id FROM public.gaa_clubs
          WHERE name_key IN ('kilmacudcrokes', 'kilmacud') OR 'kilmacudcrokes' = ANY (alias_keys)
          ORDER BY club_id LIMIT 1)
  RETURNING club_id INTO v_club;

  -- Clontarf's club-wide codes (team-only codes like S&C are not copied)
  INSERT INTO public.club_code_link (club_id, code_id)
  SELECT DISTINCT v_club, code_id FROM public.club_code_link
  WHERE club_id = v_clontarf AND team_id IS NULL;
END $$;
