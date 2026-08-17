-- get_member_match_stats_detail was incorrectly treated as dead code in the
-- anon lockdown migration and had its PUBLIC grant revoked with no replacement.
-- It is actively called from team_overview.html, club_overview.html, and
-- player_analytics.html using the Supabase anon key (no user JWT), so it
-- requires access for both anon and authenticated.

GRANT EXECUTE ON FUNCTION public.get_member_match_stats_detail TO anon;
GRANT EXECUTE ON FUNCTION public.get_member_match_stats_detail TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_member_match_stats_detail TO service_role;
