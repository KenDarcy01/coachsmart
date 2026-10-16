-- Feature flags used to switch features off while the app is in App Store review,
-- and later to tier access (e.g. AI as a premium feature).
--   teams.teamsheet    : show the Teamsheet button in team_selector (off by default)
--   users.ai_features  : allow AI features in game-upload and favourites (off by default)

ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS teamsheet boolean NOT NULL DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS ai_features boolean NOT NULL DEFAULT false;

UPDATE public.users SET ai_features = true WHERE lower(email_address) = 'ken.darcy@gmail.com';

-- Webviews ask for the caller's own flag; no JWT means false.
CREATE OR REPLACE FUNCTION public.get_my_ai_features()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT COALESCE((SELECT ai_features FROM public.users WHERE user_id = auth.uid()), false);
$$;

REVOKE ALL ON FUNCTION public.get_my_ai_features() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_ai_features() TO authenticated;
