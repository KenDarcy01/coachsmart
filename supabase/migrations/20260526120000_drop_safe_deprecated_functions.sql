-- Drop 4 confirmed-safe deprecated functions.
-- Rollback: supabase/rollback/reinstate_dropped_functions.sql

-- Broken: references non-existent 'attendees' table, cannot execute
DROP FUNCTION IF EXISTS public.get_unresponded_events();

-- Broken: references non-existent 'attendees' table, cannot execute
DROP FUNCTION IF EXISTS public.get_unresponded_events(uuid);

-- Exact duplicate of get_event_team_members_with_attendance(bigint, uuid)
DROP FUNCTION IF EXISTS public.get_members_attendance_for_event(bigint, uuid);

-- Dev/debug function: no SECURITY DEFINER, never called from app
DROP FUNCTION IF EXISTS public.get_user_teams_debug(uuid);
