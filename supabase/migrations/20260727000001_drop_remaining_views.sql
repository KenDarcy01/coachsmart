-- Drop all remaining unused views.
-- 14 orphaned views were dropped in 20260716000002.
-- view_event_attendance_details was dropped in 20260716000003.
-- This migration removes the final 15 views; none are referenced by any
-- edge function, RPC, or RLS policy.

DROP VIEW IF EXISTS public.view_attendee_details;
DROP VIEW IF EXISTS public.view_event_attendance_summary;
DROP VIEW IF EXISTS public.view_event_reminders;
DROP VIEW IF EXISTS public.view_event_squad_summary;
DROP VIEW IF EXISTS public.view_game_age_expansion;
DROP VIEW IF EXISTS public.view_match_reports;
DROP VIEW IF EXISTS public.view_match_squads;
DROP VIEW IF EXISTS public.view_team_details;
DROP VIEW IF EXISTS public.view_team_members;
DROP VIEW IF EXISTS public.view_team_roles;
DROP VIEW IF EXISTS public.view_user_members;
DROP VIEW IF EXISTS public.view_user_members_new;
DROP VIEW IF EXISTS public.view_user_team_highest_role;
DROP VIEW IF EXISTS public.view_user_team_members;
DROP VIEW IF EXISTS public.view_user_unique_member_team_events;
