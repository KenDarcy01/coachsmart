-- The anon role lost SELECT on the clubs table in migration 000011.
-- The web dashboard (dashboard-v2.html) calls /rest/v1/clubs directly
-- with only the anon key to populate the club picker.
-- Fix: a SECURITY DEFINER function that returns (club_id, club_name)
-- for all clubs — safe to expose (no PII), callable by anon.

CREATE OR REPLACE FUNCTION public.get_clubs_for_dashboard()
RETURNS TABLE(club_id integer, club_name text)
LANGUAGE sql
SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT c.club_id, c.club_name
  FROM public.clubs c
  ORDER BY c.club_name;
$$;

GRANT EXECUTE ON FUNCTION public.get_clubs_for_dashboard() TO anon;
