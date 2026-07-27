-- Drop 14 confirmed orphaned views.
-- Verified: zero pg_stat_statements queries, no RPC references, no FlutterFlow page references.

DROP VIEW IF EXISTS public.view_homepage_listview;
DROP VIEW IF EXISTS public.view_latest_member_event_attendance;
DROP VIEW IF EXISTS public.view_member_event_count;
DROP VIEW IF EXISTS public.view_member_response_list;
DROP VIEW IF EXISTS public.view_members_no_response;
DROP VIEW IF EXISTS public.view_test_data;
DROP VIEW IF EXISTS public.view_unique_user_team_members;
DROP VIEW IF EXISTS public.view_unique_user_teams;
DROP VIEW IF EXISTS public.view_user_clubs;
DROP VIEW IF EXISTS public.view_user_highest_role;
DROP VIEW IF EXISTS public.view_user_member_team_events;
DROP VIEW IF EXISTS public.view_user_team_member_squad;
DROP VIEW IF EXISTS public.view_user_teams;
DROP VIEW IF EXISTS public.view_user_teams_grade;
