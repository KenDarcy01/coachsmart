-- Private per-coach notes attached to any game.
-- One row per (game_id, user_id) pair. RLS ensures coaches can only see and
-- edit their own notes — no other user or admin can read them.

CREATE TABLE game_coach_notes (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  game_id    bigint NOT NULL REFERENCES games(game_id) ON DELETE CASCADE,
  user_id    uuid   NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  notes      text   NOT NULL DEFAULT '',
  UNIQUE (game_id, user_id)
);

ALTER TABLE game_coach_notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "coach_notes_select" ON game_coach_notes
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "coach_notes_insert" ON game_coach_notes
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "coach_notes_update" ON game_coach_notes
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "coach_notes_delete" ON game_coach_notes
  FOR DELETE USING (auth.uid() = user_id);

-- Keep updated_at current on every write
CREATE OR REPLACE FUNCTION _game_coach_notes_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql
SET search_path = 'public'
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER game_coach_notes_updated_at
  BEFORE UPDATE ON game_coach_notes
  FOR EACH ROW EXECUTE FUNCTION _game_coach_notes_set_updated_at();
