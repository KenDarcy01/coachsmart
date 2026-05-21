-- Pin search_path on all SECURITY DEFINER functions in public schema.
-- Prevents schema hijacking attacks where a malicious user creates a schema
-- containing tables with the same names as public tables, and tricks the
-- superuser-privileged function into querying them instead.
-- No behaviour change — functions return identical data as before.

ALTER FUNCTION public.check_and_send_notifications()
  SET search_path = 'public';

ALTER FUNCTION public.create_match_squad_from_attendance(bigint, uuid)
  SET search_path = 'public';

ALTER FUNCTION public.create_new_member_by_code(text, text, text)
  SET search_path = 'public';

ALTER FUNCTION public.get_event_attendance_by_role(bigint, smallint, smallint, smallint, bigint)
  SET search_path = 'public';

ALTER FUNCTION public.get_event_attendance_by_role_v2(bigint, smallint, smallint, smallint, bigint)
  SET search_path = 'public';

ALTER FUNCTION public.get_event_attendance_details(bigint)
  SET search_path = 'public';

ALTER FUNCTION public.get_event_attendance_summary_by_role(bigint, smallint, smallint, smallint)
  SET search_path = 'public';

ALTER FUNCTION public.get_event_attendance_summary_by_role_and_squad(bigint, smallint, smallint, smallint, bigint)
  SET search_path = 'public';

ALTER FUNCTION public.get_event_attendance_summary_by_role_and_squad_v2(bigint, smallint, smallint, smallint, bigint)
  SET search_path = 'public';

ALTER FUNCTION public.get_event_car_pools(bigint, uuid)
  SET search_path = 'public';

ALTER FUNCTION public.get_event_context_and_next_code(bigint)
  SET search_path = 'public';

ALTER FUNCTION public.get_events_list(text, text, bigint, bigint, bigint, text)
  SET search_path = 'public';

ALTER FUNCTION public.get_full_car_pool_details(bigint, uuid)
  SET search_path = 'public';

ALTER FUNCTION public.get_member_match_stats(text, text, text, date)
  SET search_path = 'public';

ALTER FUNCTION public.get_member_match_stats_detail(text, text, text, date)
  SET search_path = 'public';

ALTER FUNCTION public.get_single_user_event(uuid, bigint)
  SET search_path = 'public';

ALTER FUNCTION public.get_team_members_by_role(uuid, bigint)
  SET search_path = 'public';

ALTER FUNCTION public.get_updated_event_code(bigint)
  SET search_path = 'public';

ALTER FUNCTION public.get_user_clubs()
  SET search_path = 'public';

ALTER FUNCTION public.get_user_clubs(uuid)
  SET search_path = 'public';

ALTER FUNCTION public.get_user_event_create_detail(uuid)
  SET search_path = 'public';

ALTER FUNCTION public.get_user_event_details(bigint, uuid)
  SET search_path = 'public';

ALTER FUNCTION public.get_user_event_edit_detail(uuid, bigint)
  SET search_path = 'public';

ALTER FUNCTION public.get_user_events(uuid)
  SET search_path = 'public';

ALTER FUNCTION public.get_user_home_events(uuid)
  SET search_path = 'public';

ALTER FUNCTION public.get_user_notifications(uuid)
  SET search_path = 'public';

ALTER FUNCTION public.get_user_team_summary(uuid)
  SET search_path = 'public';

ALTER FUNCTION public.handle_new_user()
  SET search_path = 'public';

ALTER FUNCTION public.is_owner_of_member_team_role(bigint)
  SET search_path = 'public';

ALTER FUNCTION public.notify_admins_attendance_change(integer, integer, integer, bigint)
  SET search_path = 'public';

ALTER FUNCTION public.populate_event_notifications(integer, integer, integer)
  SET search_path = 'public';
