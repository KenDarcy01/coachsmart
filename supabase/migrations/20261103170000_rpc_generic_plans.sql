-- Busiest app RPCs: use the cached generic plan from the second call on a
-- connection (Ken, 2026-11-03). By default Postgres re-plans each query for
-- the first five calls per connection, and Supabase drops idle connections
-- quickly, so most calls paid ~15-20 ms of planning for ~5 ms of work.
-- Tested live: output identical; repeat calls 18 ms -> 5 ms (event details),
-- 21 -> 12 ms (home events, busiest user), 19 -> 7 ms (attendance pair).
-- Undo: ALTER FUNCTION <name>(<args>) RESET plan_cache_mode;
ALTER FUNCTION public.get_user_home_events(uuid) SET plan_cache_mode = force_generic_plan;
ALTER FUNCTION public.get_user_event_details(bigint, uuid) SET plan_cache_mode = force_generic_plan;
ALTER FUNCTION public.get_event_attendance_by_role(bigint, smallint, smallint, smallint, bigint) SET plan_cache_mode = force_generic_plan;
ALTER FUNCTION public.get_event_attendance_by_role_v2(bigint, smallint, smallint, smallint, bigint) SET plan_cache_mode = force_generic_plan;
ALTER FUNCTION public.get_event_attendance_summary_by_role_and_squad_v2(bigint, smallint, smallint, smallint, bigint) SET plan_cache_mode = force_generic_plan;
