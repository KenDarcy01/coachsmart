-- Intake table for coaches requesting a new team/club setup.
-- No public SELECT/UPDATE/DELETE policies — rows are only accessible
-- via the service-role key used by the request-new-team edge function.

CREATE TABLE team_requests (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  name       text NOT NULL,
  club_name  text NOT NULL,
  county     text NOT NULL,
  email      text NOT NULL,
  notes      text,
  status     text NOT NULL DEFAULT 'pending'
             CHECK (status IN ('pending', 'in_progress', 'complete'))
);

ALTER TABLE team_requests ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION _team_requests_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql
SET search_path = 'public'
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER team_requests_updated_at
  BEFORE UPDATE ON team_requests
  FOR EACH ROW EXECUTE FUNCTION _team_requests_set_updated_at();
