-- Add club_id to session_plans for club-level sharing.
-- NULL = private plan; set = visible to all coaches in that club.
ALTER TABLE session_plans
  ADD COLUMN IF NOT EXISTS club_id integer REFERENCES clubs(club_id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS session_plans_club_id_idx ON session_plans(club_id);
