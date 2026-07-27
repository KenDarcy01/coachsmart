-- Two-part hardening:
--   1. REVOKE SELECT FROM anon on all public tables.
--      This hides them from unauthenticated pg_graphql introspection
--      (pg_graphql_anon_table_exposed warnings). Data is already
--      blocked by RLS; this removes the schema-level exposure.
--      Note: anon PostgREST table queries will return 403 instead of [].
--
--   2. REVOKE EXECUTE FROM authenticated on system-only functions.
--      These are trigger functions, pg_cron tasks, and RLS helpers —
--      no client should ever call them directly, even when authenticated.
--      (authenticated_security_definer_function_executable warnings)

-- ─── 1. Revoke SELECT from anon on all tables ────────────────────────────────

REVOKE SELECT ON public.car_pool                    FROM anon;
REVOKE SELECT ON public.car_pool_detail             FROM anon;
REVOKE SELECT ON public.club_code_link              FROM anon;
REVOKE SELECT ON public.clubs                       FROM anon;
REVOKE SELECT ON public.event_attendance            FROM anon;
REVOKE SELECT ON public.event_codes                 FROM anon;
REVOKE SELECT ON public.event_response_type         FROM anon;
REVOKE SELECT ON public.event_types                 FROM anon;
REVOKE SELECT ON public.event_user_member_payment   FROM anon;
REVOKE SELECT ON public.event_user_payment          FROM anon;
REVOKE SELECT ON public.events                      FROM anon;
REVOKE SELECT ON public.game_ages                   FROM anon;
REVOKE SELECT ON public.games                       FROM anon;
REVOKE SELECT ON public.invitations                 FROM anon;
REVOKE SELECT ON public.legacy_users                FROM anon;
REVOKE SELECT ON public.lineup                      FROM anon;
REVOKE SELECT ON public.lineup_details              FROM anon;
REVOKE SELECT ON public.match_reports               FROM anon;
REVOKE SELECT ON public.match_squad_details         FROM anon;
REVOKE SELECT ON public.match_squads                FROM anon;
REVOKE SELECT ON public.members                     FROM anon;
REVOKE SELECT ON public.member_squad_link           FROM anon;
REVOKE SELECT ON public.member_team_link            FROM anon;
REVOKE SELECT ON public.member_team_role_link       FROM anon;
REVOKE SELECT ON public.notifications               FROM anon;
REVOKE SELECT ON public.reminders                   FROM anon;
REVOKE SELECT ON public.roles                       FROM anon;
REVOKE SELECT ON public.sport                       FROM anon;
REVOKE SELECT ON public.squads                      FROM anon;
REVOKE SELECT ON public.team_roles_link             FROM anon;
REVOKE SELECT ON public.teams                       FROM anon;
REVOKE SELECT ON public.user_game_link              FROM anon;
REVOKE SELECT ON public.user_member_link            FROM anon;
REVOKE SELECT ON public.users                       FROM anon;

-- Conditional revokes for tables that may not exist in all environments
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'match_stat_categories') THEN
    REVOKE SELECT ON public.match_stat_categories FROM anon;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'match_stat_type_team_link') THEN
    REVOKE SELECT ON public.match_stat_type_team_link FROM anon;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'match_stat_types') THEN
    REVOKE SELECT ON public.match_stat_types FROM anon;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'match_stats') THEN
    REVOKE SELECT ON public.match_stats FROM anon;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'match_stats_details') THEN
    REVOKE SELECT ON public.match_stats_details FROM anon;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'match_timer') THEN
    REVOKE SELECT ON public.match_timer FROM anon;
  END IF;
END $$;

-- ─── 2. Revoke EXECUTE from authenticated on system-only functions ────────────
-- Trigger functions — called by the DB engine, never by a client
REVOKE EXECUTE ON FUNCTION public.handle_new_user()                        FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.migrate_legacy_user_on_signup()          FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.set_member_code()                        FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.set_team_code_on_insert()                FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.set_match_timer_updated_at()             FROM authenticated;

-- Trigger helper functions
REVOKE EXECUTE ON FUNCTION public.generate_unique_member_code()            FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.generate_unique_team_code()              FROM authenticated;

-- pg_cron / internal notification functions
REVOKE EXECUTE ON FUNCTION public.check_and_send_notifications()           FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.populate_event_notifications(integer, integer, integer) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.notify_admins_attendance_change(integer, integer, integer, bigint) FROM authenticated;

-- RLS helper — evaluated by policy expression, not by clients
REVOKE EXECUTE ON FUNCTION public.is_owner_of_member_team_role(bigint)     FROM authenticated;

-- Edge-function-only RPCs — edge functions run as service_role, not authenticated
REVOKE EXECUTE ON FUNCTION public.get_unresponded_events(bigint)           FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.get_unresponded_events_v2(bigint, smallint, smallint) FROM authenticated;
