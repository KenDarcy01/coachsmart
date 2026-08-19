-- Revert anon access to clubs added in 20260819000004/000006.
-- The create_team webview now always initialises its Supabase client with the
-- user's JWT as an Authorization header, so all queries run as authenticated.
DROP POLICY IF EXISTS "anon_can_read_clubs" ON public.clubs;
REVOKE SELECT ON public.clubs FROM anon;
