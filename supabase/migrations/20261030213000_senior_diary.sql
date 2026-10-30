-- Senior team diary (coachsmart.app/clontarf-gaa/senior-diary/).
-- Players sign in with their CoachSmart login. Each player keeps a profile
-- and one row of ticks per day; RLS lets a player read and write only their
-- own rows. The kids Féile diary is unaffected (its ticks stay on the phone).

CREATE TABLE IF NOT EXISTS public.diary_profiles (
  user_id uuid PRIMARY KEY DEFAULT auth.uid() REFERENCES auth.users (id) ON DELETE CASCADE,
  first_name text,
  last_name text,
  phone text,
  date_of_birth date,
  emergency_name text,
  emergency_phone text,
  medical_notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.diary_ticks (
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users (id) ON DELETE CASCADE,
  day date NOT NULL,
  ticks jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, day)
);

ALTER TABLE public.diary_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.diary_ticks ENABLE ROW LEVEL SECURITY;

CREATE POLICY diary_profiles_own ON public.diary_profiles
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY diary_ticks_own ON public.diary_ticks
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE, DELETE ON public.diary_profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.diary_ticks TO authenticated;
