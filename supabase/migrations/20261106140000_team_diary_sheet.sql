-- Féile diary (coachsmart.app/clontarf-gaa/feile27/): extra entries from the
-- coaches' Google Sheet, for things CoachSmart doesn't create itself
-- (meetups, activities on certain days, day and week notes).
--
--   team_diary_sheet        the latest published sheet per team code. Only
--                           rows marked Live are in it, never coach notes.
--                           Read by the public team-diary edge function.
--   team_diary_suggestions  rows Claude suggests. The sheet's
--                           "Pull suggestions" menu takes them in as
--                           Status = Suggested; a coach sets Live to approve.
--
-- Only edge functions (service role) touch these tables: RLS on, no policies.

CREATE TABLE IF NOT EXISTS public.team_diary_sheet (
  team_code text PRIMARY KEY,
  data jsonb NOT NULL,
  published_at timestamptz NOT NULL DEFAULT now(),
  published_by text
);

CREATE TABLE IF NOT EXISTS public.team_diary_suggestions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  team_code text NOT NULL,
  tab text NOT NULL CHECK (tab IN ('Events', 'Activities', 'Notes')),
  row jsonb NOT NULL,          -- { "Heading": value } using the sheet's headings
  created_at timestamptz NOT NULL DEFAULT now(),
  pulled_at timestamptz
);

CREATE INDEX IF NOT EXISTS team_diary_suggestions_pending
  ON public.team_diary_suggestions (team_code) WHERE pulled_at IS NULL;

ALTER TABLE public.team_diary_sheet ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_diary_suggestions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.team_diary_sheet FROM anon, authenticated;
REVOKE ALL ON public.team_diary_suggestions FROM anon, authenticated;
