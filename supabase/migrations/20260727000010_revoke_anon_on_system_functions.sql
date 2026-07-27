-- Revoke EXECUTE from anon on functions that are never called directly by clients.
-- These are trigger functions, pg_cron tasks, and edge-function-only RPCs.
-- Revoking anon execute on client-callable RPCs is deferred until the PWA
-- is updated to send a JWT (otherwise the PWA breaks).

-- ─── Trigger functions (called by triggers, never via PostgREST) ─────────────

REVOKE EXECUTE ON FUNCTION public.handle_new_user()                        FROM anon;
REVOKE EXECUTE ON FUNCTION public.migrate_legacy_user_on_signup()          FROM anon;
REVOKE EXECUTE ON FUNCTION public.set_member_code()                        FROM anon;
REVOKE EXECUTE ON FUNCTION public.set_team_code_on_insert()                FROM anon;
REVOKE EXECUTE ON FUNCTION public.set_match_timer_updated_at()             FROM anon;

-- ─── Trigger helper functions ────────────────────────────────────────────────

REVOKE EXECUTE ON FUNCTION public.generate_unique_member_code()            FROM anon;
REVOKE EXECUTE ON FUNCTION public.generate_unique_team_code()              FROM anon;

-- ─── pg_cron / internal notification functions ───────────────────────────────

REVOKE EXECUTE ON FUNCTION public.check_and_send_notifications()           FROM anon;
REVOKE EXECUTE ON FUNCTION public.populate_event_notifications(integer, integer, integer) FROM anon;
REVOKE EXECUTE ON FUNCTION public.notify_admins_attendance_change(integer, integer, integer, bigint) FROM anon;

-- ─── RLS helper (called by policy expression, not by clients) ────────────────

REVOKE EXECUTE ON FUNCTION public.is_owner_of_member_team_role(bigint)     FROM anon;

-- ─── Edge-function-only RPCs (not called from FlutterFlow or PWA) ───────────

REVOKE EXECUTE ON FUNCTION public.get_unresponded_events(bigint)           FROM anon;
REVOKE EXECUTE ON FUNCTION public.get_unresponded_events_v2(bigint, smallint, smallint) FROM anon;

-- ─── Enable RLS on tables found in GraphQL exposure warnings ─────────────────
-- match_stat_categories and match_stat_type_team_link were not in any prior
-- migration but appear in the database (created outside migration history).

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'match_stat_categories') THEN
    DROP POLICY IF EXISTS "authenticated_users_can_read"   ON public.match_stat_categories;
    DROP POLICY IF EXISTS "authenticated_users_can_insert" ON public.match_stat_categories;
    DROP POLICY IF EXISTS "authenticated_users_can_update" ON public.match_stat_categories;
    DROP POLICY IF EXISTS "authenticated_users_can_delete" ON public.match_stat_categories;
    CREATE POLICY "authenticated_users_can_read"   ON public.match_stat_categories FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_insert" ON public.match_stat_categories FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_update" ON public.match_stat_categories FOR UPDATE TO authenticated USING (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_delete" ON public.match_stat_categories FOR DELETE TO authenticated USING (auth.uid() IS NOT NULL);
    ALTER TABLE public.match_stat_categories ENABLE ROW LEVEL SECURITY;
    RAISE NOTICE 'RLS enabled: match_stat_categories';
  ELSE
    RAISE NOTICE 'Skipped (does not exist): match_stat_categories';
  END IF;

  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'match_stat_type_team_link') THEN
    DROP POLICY IF EXISTS "authenticated_users_can_read"   ON public.match_stat_type_team_link;
    DROP POLICY IF EXISTS "authenticated_users_can_insert" ON public.match_stat_type_team_link;
    DROP POLICY IF EXISTS "authenticated_users_can_update" ON public.match_stat_type_team_link;
    DROP POLICY IF EXISTS "authenticated_users_can_delete" ON public.match_stat_type_team_link;
    CREATE POLICY "authenticated_users_can_read"   ON public.match_stat_type_team_link FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_insert" ON public.match_stat_type_team_link FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_update" ON public.match_stat_type_team_link FOR UPDATE TO authenticated USING (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_delete" ON public.match_stat_type_team_link FOR DELETE TO authenticated USING (auth.uid() IS NOT NULL);
    ALTER TABLE public.match_stat_type_team_link ENABLE ROW LEVEL SECURITY;
    RAISE NOTICE 'RLS enabled: match_stat_type_team_link';
  ELSE
    RAISE NOTICE 'Skipped (does not exist): match_stat_type_team_link';
  END IF;
END $$;
