-- Allow clubs to have their own private games/skills/drills.
-- club_id NULL  = public (visible to all authenticated users)
-- club_id set   = club-specific (visible only to members of that club)

ALTER TABLE public.games
  ADD COLUMN IF NOT EXISTS club_id bigint
  REFERENCES public.clubs(club_id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_games_club_id ON public.games (club_id);

-- Replace the broad "any authenticated user can read all games" policy with
-- one that restricts club-specific rows to members of that club only.
DROP POLICY IF EXISTS "authenticated_users_can_read" ON public.games;

CREATE POLICY "games_select" ON public.games FOR SELECT TO authenticated
USING (
  club_id IS NULL
  OR EXISTS (
    SELECT 1
    FROM public.user_member_link uml
    JOIN public.member_team_link mtl
      ON uml.member_id = mtl.member_id AND mtl.status = 'active'
    JOIN public.teams t
      ON mtl.team_id = t.team_id
    WHERE uml.user_id = auth.uid()
      AND uml.status  = 'active'
      AND t.club_id   = games.club_id
  )
);
