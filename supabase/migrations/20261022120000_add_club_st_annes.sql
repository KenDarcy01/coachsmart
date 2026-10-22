-- New club: St Annes (Bohernabreena, Dublin 24). Ken, 2026-10-22.
-- Set up like Clontarf: same sport and the same club-wide codes. Colours are
-- blue and white; the crest is hosted at coachsmart.app/crests/.
-- Only runs once: does nothing if a club called St Annes already exists.

DO $$
DECLARE
  v_clontarf bigint;
  v_club     bigint;
BEGIN
  IF EXISTS (SELECT 1 FROM public.clubs WHERE public.gaa_key(club_name) = 'stannes') THEN
    RAISE NOTICE 'St Annes already exists, nothing to do';
    RETURN;
  END IF;

  SELECT club_id INTO v_clontarf FROM public.clubs
  WHERE public.gaa_key(club_name) = 'clontarf' ORDER BY club_id LIMIT 1;

  INSERT INTO public.clubs (club_name, county, sport_id, crest, primary_colour, secondary_colour, gaa_club_id)
  SELECT 'St Annes', 'Dublin',
         (SELECT sport_id FROM public.clubs WHERE club_id = v_clontarf),
         '__CREST__', '__PRIMARY__', '#FFFFFF',
         (SELECT club_id FROM public.gaa_clubs WHERE name_key = 'stannes' OR 'stannes' = ANY (alias_keys) LIMIT 1)
  RETURNING club_id INTO v_club;

  -- Clontarf's club-wide codes (team-only codes like S&C are not copied)
  INSERT INTO public.club_code_link (club_id, code_id)
  SELECT v_club, code_id FROM public.club_code_link
  WHERE club_id = v_clontarf AND team_id IS NULL
  GROUP BY code_id;

  RAISE NOTICE 'St Annes created as club_id %', v_club;
END $$;
