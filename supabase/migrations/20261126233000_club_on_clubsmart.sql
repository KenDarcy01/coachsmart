-- "Club is on ClubSmart" switch (Ken, 2026-11-26). ClubSmart is the club
-- layer (club home, following, messages, fundraisers, lotto, newsletter,
-- partners). A club on ClubSmart shows on the v3 Home (club) tab; a club
-- that only has teams on CoachSmart does not.
ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS club_on_clubsmart boolean NOT NULL DEFAULT false;
COMMENT ON COLUMN public.clubs.club_on_clubsmart IS
  'Club is on ClubSmart: shows on the v3 Home (club) tab. Off = only teams on CoachSmart.';
UPDATE public.clubs SET club_on_clubsmart = true WHERE club_id = 1;  -- Clontarf GAA

-- Clubs for the v3 Home (club) tab: clubs on ClubSmart that the user is on
-- a team in, or follows. Same shape as get_my_followed_clubs.
CREATE OR REPLACE FUNCTION public.get_my_home_clubs()
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = 'public'
AS $$
  WITH mine AS (
    SELECT DISTINCT t.club_id
      FROM user_member_link uml
      JOIN member_team_link mtl ON mtl.member_id = uml.member_id
                               AND COALESCE(mtl.status, 'active') = 'active'
      JOIN teams t ON t.team_id = mtl.team_id
     WHERE uml.user_id = auth.uid() AND COALESCE(uml.status, 'active') = 'active'
       AND t.club_id IS NOT NULL
    UNION
    SELECT club_id FROM user_followed_clubs(auth.uid())
  )
  SELECT COALESCE(jsonb_agg(club_follow_json(c.club_id, auth.uid()) ORDER BY c.club_name), '[]'::jsonb)
    FROM clubs c
   WHERE c.club_on_clubsmart AND c.club_id IN (SELECT club_id FROM mine)
     AND auth.uid() IS NOT NULL;
$$;
REVOKE ALL ON FUNCTION public.get_my_home_clubs() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_home_clubs() TO authenticated;
