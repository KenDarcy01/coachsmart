-- Multi-sport step 3 (Ken, 2026-11-14): every game belongs to a sport, so
-- soccer and rugby get their own games and drills. Add-only for v2:
--  * games.sport_id, default GAA (1); all existing games are GAA.
--  * A trigger fills it on insert from the game's codes (Soccer -> 2,
--    Rugby -> 3, via event_codes.sport_id), else the club's sport, else GAA,
--    so the edge functions and v2 need no change.
--  * A RESTRICTIVE select policy: a soccer or rugby game is only visible to
--    members of a club of that sport. GAA clubs (all v2 users today) see
--    exactly the list they see now. Service-role reads are unaffected.

ALTER TABLE public.games
  ADD COLUMN IF NOT EXISTS sport_id bigint NOT NULL DEFAULT 1 REFERENCES public.sport (sport_id);

CREATE INDEX IF NOT EXISTS games_sport_id_idx ON public.games (sport_id);

COMMENT ON COLUMN public.games.sport_id IS
  'Sport this game is for (sport.sport_id): 1 GAA, 2 Soccer, 3 Rugby. Set from game_code or the club on insert.';

CREATE OR REPLACE FUNCTION public.games_set_sport()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_sport bigint;
BEGIN
  -- Codes decide: a game tagged Soccer or Rugby is that sport.
  SELECT ec.sport_id INTO v_sport
    FROM event_codes ec
   WHERE ec.event_code = ANY (COALESCE(NEW.game_code, ARRAY[]::text[]))
     AND ec.sport_id IS NOT NULL AND ec.sport_id <> 1
   LIMIT 1;

  -- Untagged (or GAA-tagged) game from a soccer or rugby club on insert:
  -- only when no GAA code was picked.
  IF v_sport IS NULL AND TG_OP = 'INSERT' AND NEW.club_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM event_codes ec
                      WHERE ec.event_code = ANY (COALESCE(NEW.game_code, ARRAY[]::text[]))
                        AND ec.sport_id = 1) THEN
    SELECT c.sport_id INTO v_sport FROM clubs c WHERE c.club_id = NEW.club_id;
  END IF;

  IF v_sport IS NOT NULL THEN
    NEW.sport_id := v_sport;
  ELSIF TG_OP = 'UPDATE' AND NEW.game_code IS DISTINCT FROM OLD.game_code
        AND EXISTS (SELECT 1 FROM event_codes ec
                     WHERE ec.event_code = ANY (COALESCE(NEW.game_code, ARRAY[]::text[]))
                       AND ec.sport_id = 1) THEN
    NEW.sport_id := 1;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS games_set_sport ON public.games;
CREATE TRIGGER games_set_sport
  BEFORE INSERT OR UPDATE OF game_code ON public.games
  FOR EACH ROW EXECUTE FUNCTION public.games_set_sport();

DROP POLICY IF EXISTS games_sport_visible ON public.games;
CREATE POLICY games_sport_visible ON public.games
  AS RESTRICTIVE
  FOR SELECT
  TO authenticated
  USING (
    sport_id = 1
    OR EXISTS (
      SELECT 1
        FROM user_member_link uml
        JOIN member_team_link mtl ON mtl.member_id = uml.member_id AND mtl.status = 'active'
        JOIN teams t ON t.team_id = mtl.team_id
        JOIN clubs c ON c.club_id = t.club_id
       WHERE uml.user_id = (SELECT auth.uid())
         AND uml.status = 'active'
         AND c.sport_id = games.sport_id
    )
  );
