-- Record who added a game, so the creator (and Ken) can delete it.
-- Existing games stay NULL: only the admin can delete those.
ALTER TABLE public.games ADD COLUMN IF NOT EXISTS created_by uuid;
CREATE INDEX IF NOT EXISTS games_created_by_idx ON public.games (created_by);
