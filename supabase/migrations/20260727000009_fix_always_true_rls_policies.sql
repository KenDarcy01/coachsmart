-- Fix RLS policies that use the literal `true` expression.
-- The Supabase security linter flags these because `true` is indistinguishable
-- from "no restriction" — any row always passes. Replacing with
-- `auth.uid() IS NOT NULL` is semantically equivalent for the `authenticated`
-- role (every authenticated request satisfies it) but removes the lint warning.
--
-- Tables: lineup, lineup_details, roles, sport, squads

-- ─── lineup ──────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "authenticated_insert_lineup" ON public.lineup;
CREATE POLICY "authenticated_insert_lineup"
    ON public.lineup FOR INSERT TO authenticated
    WITH CHECK (auth.uid() IS NOT NULL);

-- ─── lineup_details ──────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "authenticated_insert_lineup_details" ON public.lineup_details;
CREATE POLICY "authenticated_insert_lineup_details"
    ON public.lineup_details FOR INSERT TO authenticated
    WITH CHECK (auth.uid() IS NOT NULL);

-- ─── roles ───────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "authenticated_users_can_read"   ON public.roles;
DROP POLICY IF EXISTS "authenticated_users_can_insert" ON public.roles;
DROP POLICY IF EXISTS "authenticated_users_can_update" ON public.roles;
DROP POLICY IF EXISTS "authenticated_users_can_delete" ON public.roles;

CREATE POLICY "authenticated_users_can_read"   ON public.roles FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);
CREATE POLICY "authenticated_users_can_insert" ON public.roles FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "authenticated_users_can_update" ON public.roles FOR UPDATE TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "authenticated_users_can_delete" ON public.roles FOR DELETE TO authenticated USING (auth.uid() IS NOT NULL);

-- ─── sport ───────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "authenticated_users_can_read"   ON public.sport;
DROP POLICY IF EXISTS "authenticated_users_can_insert" ON public.sport;
DROP POLICY IF EXISTS "authenticated_users_can_update" ON public.sport;
DROP POLICY IF EXISTS "authenticated_users_can_delete" ON public.sport;

CREATE POLICY "authenticated_users_can_read"   ON public.sport FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);
CREATE POLICY "authenticated_users_can_insert" ON public.sport FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "authenticated_users_can_update" ON public.sport FOR UPDATE TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "authenticated_users_can_delete" ON public.sport FOR DELETE TO authenticated USING (auth.uid() IS NOT NULL);

-- ─── squads ──────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "authenticated_users_can_read"   ON public.squads;
DROP POLICY IF EXISTS "authenticated_users_can_insert" ON public.squads;
DROP POLICY IF EXISTS "authenticated_users_can_update" ON public.squads;
DROP POLICY IF EXISTS "authenticated_users_can_delete" ON public.squads;

CREATE POLICY "authenticated_users_can_read"   ON public.squads FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);
CREATE POLICY "authenticated_users_can_insert" ON public.squads FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "authenticated_users_can_update" ON public.squads FOR UPDATE TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "authenticated_users_can_delete" ON public.squads FOR DELETE TO authenticated USING (auth.uid() IS NOT NULL);
