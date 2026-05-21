-- Rollback: remove pinned search_path from all SECURITY DEFINER functions.
-- Run this if 20260521140722_add_search_path_to_security_definer_functions.sql
-- needs to be reversed. Creates a new migration to apply via: supabase db push

ALTER FUNCTION public.check_and_send_notifications()
  RESET search_path;

ALTER FUNCTION public.create_match_squad_from_attendance(bigint, uuid)
  RESET search_path;

ALTER FUNCTION public.create_new_member_by_code(text, text, text)
  RESET search_path;

ALTER FUNCTION public.get_event_attendance_by_role(bigint, smallint, smallint, smallint, bigint)
  RESET search_path;

ALTER FUNCTION public.get_event_attendance_by_role_v2(bigint, smallint, smallint, smallint, bigint)
  RESET search_path;

ALTER FUNCTION public.get_event_attendance_details(bigint)
  RESET search_path;

ALTER FUNCTION public.get_event_attendance_summary_by_role(bigint, smallint, smallint, smallint)
  RESET search_path;

ALTER FUNCTION public.get_event_attendance_summary_by_role_and_squad(bigint, smallint, smallint, smallint, bigint)
  RESET search_path;

ALTER FUNCTION public.get_event_attendance_summary_by_role_and_squad_v2(bigint, smallint, smallint, smallint, bigint)
  RESET search_path;

ALTER FUNCTION public.get_event_car_pools(bigint, uuid)
  RESET search_path;

ALTER FUNCTION public.get_event_context_and_next_code(bigint)
  RESET search_path;

ALTER FUNCTION public.get_events_list(text, text, bigint, bigint, bigint, text)
  RESET search_path;

ALTER FUNCTION public.get_full_car_pool_details(bigint, uuid)
  RESET search_path;

ALTER FUNCTION public.get_member_match_stats(text, text, text, date)
  RESET search_path;

ALTER FUNCTION public.get_member_match_stats_detail(text, text, text, date)
  RESET search_path;

ALTER FUNCTION public.get_single_user_event(uuid, bigint)
  RESET search_path;

ALTER FUNCTION public.get_team_members_by_role(uuid, bigint)
  RESET search_path;

ALTER FUNCTION public.get_updated_event_code(bigint)
  RESET search_path;

ALTER FUNCTION public.get_user_clubs()
  RESET search_path;

ALTER FUNCTION public.get_user_clubs(uuid)
  RESET search_path;

ALTER FUNCTION public.get_user_event_create_detail(uuid)
  RESET search_path;

ALTER FUNCTION public.get_user_event_details(bigint, uuid)
  RESET search_path;

ALTER FUNCTION public.get_user_event_edit_detail(uuid, bigint)
  RESET search_path;

ALTER FUNCTION public.get_user_events(uuid)
  RESET search_path;

ALTER FUNCTION public.get_user_home_events(uuid)
  RESET search_path;

ALTER FUNCTION public.get_user_notifications(uuid)
  RESET search_path;

ALTER FUNCTION public.get_user_team_summary(uuid)
  RESET search_path;

ALTER FUNCTION public.handle_new_user()
  RESET search_path;

ALTER FUNCTION public.is_owner_of_member_team_role(bigint)
  RESET search_path;

ALTER FUNCTION public.notify_admins_attendance_change(integer, integer, integer, bigint)
  RESET search_path;

ALTER FUNCTION public.populate_event_notifications(integer, integer, integer)
  RESET search_path;
