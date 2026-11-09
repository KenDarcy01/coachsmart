-- Senior diary coach dashboard (coachsmart.app/clontarf-gaa/senior-diary/dashboard/).
-- Only diary admins can open it: people whose CoachSmart sign-in email is in
-- diary_admins. Ken starts the list; admins add or remove others from the
-- dashboard itself. Nobody reads these from the browser: the diary-dashboard
-- edge function checks the caller and reads with the service role.

CREATE TABLE IF NOT EXISTS public.diary_admins (
  email text PRIMARY KEY CHECK (email = lower(email)),
  added_by text,
  added_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.diary_admins ENABLE ROW LEVEL SECURITY;
-- No policies: browser roles see nothing.

INSERT INTO public.diary_admins (email, added_by) VALUES ('ken@coachsmart.app', 'setup')
ON CONFLICT (email) DO NOTHING;

-- Every player with diary details, with their sign-in email (which lives in auth.users).
CREATE OR REPLACE FUNCTION public.diary_dashboard_players()
RETURNS TABLE (
  user_id uuid, email text, first_name text, last_name text, phone text,
  date_of_birth date, emergency_name text, emergency_phone text, medical_notes text,
  created_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT p.user_id, lower(u.email), p.first_name, p.last_name, p.phone,
         p.date_of_birth, p.emergency_name, p.emergency_phone, p.medical_notes, p.created_at
  FROM public.diary_profiles p
  JOIN auth.users u ON u.id = p.user_id;
$$;

REVOKE ALL ON FUNCTION public.diary_dashboard_players() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.diary_dashboard_players() TO service_role;
