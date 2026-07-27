-- Final RLS cleanup:
--   1. Enable RLS on match_stat_types (missed in previous migration)
--   2. Revoke anon access on the 6 restored views — views bypass RLS because
--      they run as the postgres superuser, so REVOKE is the only way to
--      prevent unauthenticated PostgREST access to them.

-- ─── match_stat_types ────────────────────────────────────────────────────────

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'match_stat_types') THEN
    DROP POLICY IF EXISTS "authenticated_users_can_read"   ON public.match_stat_types;
    DROP POLICY IF EXISTS "authenticated_users_can_insert" ON public.match_stat_types;
    DROP POLICY IF EXISTS "authenticated_users_can_update" ON public.match_stat_types;
    DROP POLICY IF EXISTS "authenticated_users_can_delete" ON public.match_stat_types;
    CREATE POLICY "authenticated_users_can_read"   ON public.match_stat_types FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_insert" ON public.match_stat_types FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_update" ON public.match_stat_types FOR UPDATE TO authenticated USING (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_delete" ON public.match_stat_types FOR DELETE TO authenticated USING (auth.uid() IS NOT NULL);
    ALTER TABLE public.match_stat_types ENABLE ROW LEVEL SECURITY;
    RAISE NOTICE 'RLS enabled: match_stat_types';
  ELSE
    RAISE NOTICE 'Skipped (does not exist): match_stat_types';
  END IF;
END $$;

-- ─── Revoke anon access on views ─────────────────────────────────────────────
-- Views run as the postgres superuser and bypass RLS on underlying tables.
-- Revoking anon prevents unauthenticated PostgREST calls from reading them.

REVOKE ALL ON public.view_match_reports     FROM anon;
REVOKE ALL ON public.view_team_details      FROM anon;
REVOKE ALL ON public.view_team_members      FROM anon;
REVOKE ALL ON public.view_user_members      FROM anon;
REVOKE ALL ON public.view_user_members_new  FROM anon;
REVOKE ALL ON public.view_user_team_members FROM anon;
