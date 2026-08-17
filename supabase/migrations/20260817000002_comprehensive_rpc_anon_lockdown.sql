-- Comprehensive RPC security lockdown.
--
-- The PWA has been updated to send JWT authentication tokens, matching the
-- native app. All non-onboarding RPCs can now be restricted to authenticated
-- users only.
--
-- Supabase grants EXECUTE TO PUBLIC on all functions by default. Prior
-- migrations used REVOKE FROM anon / REVOKE FROM authenticated, which only
-- removes the explicit role grant while leaving the PUBLIC inheritance intact —
-- so anon could still call everything via PUBLIC. This migration uses
-- REVOKE FROM PUBLIC to fully close each function, then grants back only to
-- the roles that legitimately need access.
--
-- Onboarding functions intentionally left with PUBLIC access (anon callers):
--   get_team_by_code, check_email_exists, save_onboarding_details,
--   request_member_access, create_new_member_by_code, lookup_member_by_code

-- ─── 1. System-only functions — REVOKE FROM PUBLIC ────────────────────────────
-- Trigger functions, pg_cron tasks, and RLS helpers. The DB engine invokes
-- these as the postgres superuser, which is unaffected by REVOKE FROM PUBLIC.
-- No client — not even authenticated — should ever call these directly.

REVOKE EXECUTE ON FUNCTION public.handle_new_user()                                          FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.migrate_legacy_user_on_signup()                            FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.set_member_code()                                          FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.set_team_code_on_insert()                                  FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.set_match_timer_updated_at()                               FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.generate_unique_member_code()                              FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.generate_unique_team_code()                                FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.check_and_send_notifications()                             FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.populate_event_notifications(integer, integer, integer)    FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.notify_admins_attendance_change(integer, integer, integer, bigint) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.is_owner_of_member_team_role(bigint)                       FROM PUBLIC;

-- ─── 2. Edge-function-only RPCs — REVOKE FROM PUBLIC ─────────────────────────
-- Called exclusively by Supabase edge functions using the service_role key.
-- The baseline schema grants EXECUTE TO service_role explicitly; revoking
-- from PUBLIC removes the remaining anon/authenticated access while keeping
-- service_role access intact.

REVOKE EXECUTE ON FUNCTION public.get_unresponded_events(bigint)                             FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_unresponded_events_v2(bigint, smallint, smallint)      FROM PUBLIC;

-- ─── 3. Client data-read RPCs — REVOKE FROM PUBLIC + GRANT TO authenticated ──
-- Previously deferred because the PWA did not send JWT tokens.
-- PWA now matches the native app — all client calls include a signed JWT.

REVOKE EXECUTE ON FUNCTION public.get_user_home_events(uuid)                                 FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_user_home_events(uuid)                                 TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_user_event_details(bigint, uuid)                       FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_user_event_details(bigint, uuid)                       TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_team_members_by_role(uuid, bigint)                     FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_team_members_by_role(uuid, bigint)                     TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_user_notifications(uuid)                               FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_user_notifications(uuid)                               TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_event_car_pools(bigint, uuid)                          FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_event_car_pools(bigint, uuid)                          TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_user_event_create_detail(uuid)                         FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_user_event_create_detail(uuid)                         TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_event_attendance_by_role(bigint, smallint, smallint, smallint, bigint) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_event_attendance_by_role(bigint, smallint, smallint, smallint, bigint) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_event_attendance_by_role_v2(bigint, smallint, smallint, smallint, bigint) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_event_attendance_by_role_v2(bigint, smallint, smallint, smallint, bigint) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_event_attendance_summary_by_role_and_squad_v2(bigint, smallint, smallint, smallint, bigint) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_event_attendance_summary_by_role_and_squad_v2(bigint, smallint, smallint, smallint, bigint) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_event_attendance_summary_by_role(bigint, smallint, smallint, smallint) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_event_attendance_summary_by_role(bigint, smallint, smallint, smallint) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_events_list(text, text, bigint, bigint, bigint, text)  FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_events_list(text, text, bigint, bigint, bigint, text)  TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_full_car_pool_details(bigint, uuid)                    FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_full_car_pool_details(bigint, uuid)                    TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_event_admin_detail(bigint)                             FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_event_admin_detail(bigint)                             TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_user_team_summary(uuid)                                FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_user_team_summary(uuid)                                TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_user_event_edit_detail(uuid, bigint)                   FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_user_event_edit_detail(uuid, bigint)                   TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_updated_event_code(bigint)                             FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_updated_event_code(bigint)                             TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_single_user_event(uuid, bigint)                        FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_single_user_event(uuid, bigint)                        TO authenticated;

-- Unused/candidate-for-removal data RPCs: revoke without re-granting
-- so they are fully locked down until dropped in a future migration.
DO $$
BEGIN
  -- get_event_attendance_summary_by_role_and_squad (old v1, superseded by _v2)
  IF EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'get_event_attendance_summary_by_role_and_squad'
  ) THEN
    REVOKE EXECUTE ON FUNCTION public.get_event_attendance_summary_by_role_and_squad FROM PUBLIC;
  END IF;

  -- get_event_attendance_details has two overloads; revoke each by explicit signature
  IF EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'get_event_attendance_details'
      AND p.pronargs = 1
  ) THEN
    REVOKE EXECUTE ON FUNCTION public.get_event_attendance_details(bigint) FROM PUBLIC;
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'get_event_attendance_details'
      AND p.pronargs = 3
  ) THEN
    REVOKE EXECUTE ON FUNCTION public.get_event_attendance_details(uuid, bigint, integer) FROM PUBLIC;
  END IF;

  -- get_event_context_and_next_code
  IF EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'get_event_context_and_next_code'
  ) THEN
    REVOKE EXECUTE ON FUNCTION public.get_event_context_and_next_code FROM PUBLIC;
  END IF;

  -- get_member_match_stats
  IF EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'get_member_match_stats'
  ) THEN
    REVOKE EXECUTE ON FUNCTION public.get_member_match_stats FROM PUBLIC;
  END IF;

  -- get_member_match_stats_detail
  IF EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'get_member_match_stats_detail'
  ) THEN
    REVOKE EXECUTE ON FUNCTION public.get_member_match_stats_detail FROM PUBLIC;
  END IF;
END $$;

-- ─── 4. Write RPCs — REVOKE FROM PUBLIC + GRANT TO authenticated ─────────────
-- create_recurring_events and remove_member_from_team already had REVOKE FROM
-- anon in migration 20260817000001; this upgrades those to REVOKE FROM PUBLIC
-- to close the PUBLIC inheritance loophole.

REVOKE EXECUTE ON FUNCTION public.create_recurring_events                                    FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.create_recurring_events                                    TO authenticated;

REVOKE EXECUTE ON FUNCTION public.remove_member_from_team(bigint, bigint)                    FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.remove_member_from_team(bigint, bigint)                    TO authenticated;

REVOKE EXECUTE ON FUNCTION public.create_match_squad_from_attendance(bigint, uuid)           FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.create_match_squad_from_attendance(bigint, uuid)           TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_match_stat(bigint, bigint, text, integer, text, integer) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.log_match_stat(bigint, bigint, text, integer, text, integer) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.delete_last_match_stat(bigint, bigint, text)               FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.delete_last_match_stat(bigint, bigint, text)               TO authenticated;

REVOKE EXECUTE ON FUNCTION public.upsert_match_stats(bigint, text, bigint)                   FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.upsert_match_stats(bigint, text, bigint)                   TO authenticated;

REVOKE EXECUTE ON FUNCTION public.finalise_match_stats(bigint)                               FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.finalise_match_stats(bigint)                               TO authenticated;

REVOKE EXECUTE ON FUNCTION public.reset_match_stats_details(bigint)                          FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.reset_match_stats_details(bigint)                          TO authenticated;

REVOKE EXECUTE ON FUNCTION public.reset_match_stats_session(bigint)                          FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.reset_match_stats_session(bigint)                          TO authenticated;

-- ─── 5. confirm_member_join — drop old single-role overload, lock new one ────
-- The (bigint, bigint) overload was superseded by (bigint, bigint[]) in
-- migration 20260730000005. It is dead code that is never called.

DROP FUNCTION IF EXISTS public.confirm_member_join(bigint, bigint);

REVOKE EXECUTE ON FUNCTION public.confirm_member_join(bigint, bigint[])                      FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.confirm_member_join(bigint, bigint[])                      TO authenticated;

REVOKE EXECUTE ON FUNCTION public.deny_member_join(bigint)                                   FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.deny_member_join(bigint)                                   TO authenticated;

REVOKE EXECUTE ON FUNCTION public.confirm_user_member_access(bigint)                         FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.confirm_user_member_access(bigint)                         TO authenticated;

REVOKE EXECUTE ON FUNCTION public.deny_user_member_access(bigint)                            FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.deny_user_member_access(bigint)                            TO authenticated;
