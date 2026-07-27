-- Enable RLS on all remaining unprotected tables.
-- Uses DO blocks so the migration skips any table that doesn't exist
-- rather than failing (some tables in the base schema were never created).

DO $$
BEGIN

  -- event_user_payment
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'event_user_payment') THEN
    DROP POLICY IF EXISTS "authenticated_users_can_read"   ON public.event_user_payment;
    DROP POLICY IF EXISTS "authenticated_users_can_insert" ON public.event_user_payment;
    DROP POLICY IF EXISTS "authenticated_users_can_update" ON public.event_user_payment;
    DROP POLICY IF EXISTS "authenticated_users_can_delete" ON public.event_user_payment;
    CREATE POLICY "authenticated_users_can_read"   ON public.event_user_payment FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_insert" ON public.event_user_payment FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_update" ON public.event_user_payment FOR UPDATE TO authenticated USING (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_delete" ON public.event_user_payment FOR DELETE TO authenticated USING (auth.uid() IS NOT NULL);
    ALTER TABLE public.event_user_payment ENABLE ROW LEVEL SECURITY;
    RAISE NOTICE 'RLS enabled: event_user_payment';
  ELSE
    RAISE NOTICE 'Skipped (does not exist): event_user_payment';
  END IF;

  -- event_user_member_payment
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'event_user_member_payment') THEN
    DROP POLICY IF EXISTS "authenticated_users_can_read"   ON public.event_user_member_payment;
    DROP POLICY IF EXISTS "authenticated_users_can_insert" ON public.event_user_member_payment;
    DROP POLICY IF EXISTS "authenticated_users_can_update" ON public.event_user_member_payment;
    DROP POLICY IF EXISTS "authenticated_users_can_delete" ON public.event_user_member_payment;
    CREATE POLICY "authenticated_users_can_read"   ON public.event_user_member_payment FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_insert" ON public.event_user_member_payment FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_update" ON public.event_user_member_payment FOR UPDATE TO authenticated USING (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_delete" ON public.event_user_member_payment FOR DELETE TO authenticated USING (auth.uid() IS NOT NULL);
    ALTER TABLE public.event_user_member_payment ENABLE ROW LEVEL SECURITY;
    RAISE NOTICE 'RLS enabled: event_user_member_payment';
  ELSE
    RAISE NOTICE 'Skipped (does not exist): event_user_member_payment';
  END IF;

  -- match_reports
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'match_reports') THEN
    DROP POLICY IF EXISTS "authenticated_users_can_read"   ON public.match_reports;
    DROP POLICY IF EXISTS "authenticated_users_can_insert" ON public.match_reports;
    DROP POLICY IF EXISTS "authenticated_users_can_update" ON public.match_reports;
    DROP POLICY IF EXISTS "authenticated_users_can_delete" ON public.match_reports;
    CREATE POLICY "authenticated_users_can_read"   ON public.match_reports FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_insert" ON public.match_reports FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_update" ON public.match_reports FOR UPDATE TO authenticated USING (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_delete" ON public.match_reports FOR DELETE TO authenticated USING (auth.uid() IS NOT NULL);
    ALTER TABLE public.match_reports ENABLE ROW LEVEL SECURITY;
    RAISE NOTICE 'RLS enabled: match_reports';
  ELSE
    RAISE NOTICE 'Skipped (does not exist): match_reports';
  END IF;

  -- match_scores
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'match_scores') THEN
    DROP POLICY IF EXISTS "authenticated_users_can_read"   ON public.match_scores;
    DROP POLICY IF EXISTS "authenticated_users_can_insert" ON public.match_scores;
    DROP POLICY IF EXISTS "authenticated_users_can_update" ON public.match_scores;
    DROP POLICY IF EXISTS "authenticated_users_can_delete" ON public.match_scores;
    CREATE POLICY "authenticated_users_can_read"   ON public.match_scores FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_insert" ON public.match_scores FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_update" ON public.match_scores FOR UPDATE TO authenticated USING (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_delete" ON public.match_scores FOR DELETE TO authenticated USING (auth.uid() IS NOT NULL);
    ALTER TABLE public.match_scores ENABLE ROW LEVEL SECURITY;
    RAISE NOTICE 'RLS enabled: match_scores';
  ELSE
    RAISE NOTICE 'Skipped (does not exist): match_scores';
  END IF;

  -- match_scores_details
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'match_scores_details') THEN
    DROP POLICY IF EXISTS "authenticated_users_can_read"   ON public.match_scores_details;
    DROP POLICY IF EXISTS "authenticated_users_can_insert" ON public.match_scores_details;
    DROP POLICY IF EXISTS "authenticated_users_can_update" ON public.match_scores_details;
    DROP POLICY IF EXISTS "authenticated_users_can_delete" ON public.match_scores_details;
    CREATE POLICY "authenticated_users_can_read"   ON public.match_scores_details FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_insert" ON public.match_scores_details FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_update" ON public.match_scores_details FOR UPDATE TO authenticated USING (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_delete" ON public.match_scores_details FOR DELETE TO authenticated USING (auth.uid() IS NOT NULL);
    ALTER TABLE public.match_scores_details ENABLE ROW LEVEL SECURITY;
    RAISE NOTICE 'RLS enabled: match_scores_details';
  ELSE
    RAISE NOTICE 'Skipped (does not exist): match_scores_details';
  END IF;

  -- match_score_types
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'match_score_types') THEN
    DROP POLICY IF EXISTS "authenticated_users_can_read"   ON public.match_score_types;
    DROP POLICY IF EXISTS "authenticated_users_can_insert" ON public.match_score_types;
    DROP POLICY IF EXISTS "authenticated_users_can_update" ON public.match_score_types;
    DROP POLICY IF EXISTS "authenticated_users_can_delete" ON public.match_score_types;
    CREATE POLICY "authenticated_users_can_read"   ON public.match_score_types FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_insert" ON public.match_score_types FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_update" ON public.match_score_types FOR UPDATE TO authenticated USING (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_delete" ON public.match_score_types FOR DELETE TO authenticated USING (auth.uid() IS NOT NULL);
    ALTER TABLE public.match_score_types ENABLE ROW LEVEL SECURITY;
    RAISE NOTICE 'RLS enabled: match_score_types';
  ELSE
    RAISE NOTICE 'Skipped (does not exist): match_score_types';
  END IF;

  -- member_squad_link
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'member_squad_link') THEN
    DROP POLICY IF EXISTS "authenticated_users_can_read"   ON public.member_squad_link;
    DROP POLICY IF EXISTS "authenticated_users_can_insert" ON public.member_squad_link;
    DROP POLICY IF EXISTS "authenticated_users_can_update" ON public.member_squad_link;
    DROP POLICY IF EXISTS "authenticated_users_can_delete" ON public.member_squad_link;
    CREATE POLICY "authenticated_users_can_read"   ON public.member_squad_link FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_insert" ON public.member_squad_link FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_update" ON public.member_squad_link FOR UPDATE TO authenticated USING (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_delete" ON public.member_squad_link FOR DELETE TO authenticated USING (auth.uid() IS NOT NULL);
    ALTER TABLE public.member_squad_link ENABLE ROW LEVEL SECURITY;
    RAISE NOTICE 'RLS enabled: member_squad_link';
  ELSE
    RAISE NOTICE 'Skipped (does not exist): member_squad_link';
  END IF;

  -- legacy_users
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'legacy_users') THEN
    DROP POLICY IF EXISTS "authenticated_users_can_read"   ON public.legacy_users;
    DROP POLICY IF EXISTS "authenticated_users_can_insert" ON public.legacy_users;
    DROP POLICY IF EXISTS "authenticated_users_can_update" ON public.legacy_users;
    DROP POLICY IF EXISTS "authenticated_users_can_delete" ON public.legacy_users;
    CREATE POLICY "authenticated_users_can_read"   ON public.legacy_users FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_insert" ON public.legacy_users FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_update" ON public.legacy_users FOR UPDATE TO authenticated USING (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_delete" ON public.legacy_users FOR DELETE TO authenticated USING (auth.uid() IS NOT NULL);
    ALTER TABLE public.legacy_users ENABLE ROW LEVEL SECURITY;
    RAISE NOTICE 'RLS enabled: legacy_users';
  ELSE
    RAISE NOTICE 'Skipped (does not exist): legacy_users';
  END IF;

  -- user_game_link
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'user_game_link') THEN
    DROP POLICY IF EXISTS "authenticated_users_can_read"   ON public.user_game_link;
    DROP POLICY IF EXISTS "authenticated_users_can_insert" ON public.user_game_link;
    DROP POLICY IF EXISTS "authenticated_users_can_update" ON public.user_game_link;
    DROP POLICY IF EXISTS "authenticated_users_can_delete" ON public.user_game_link;
    CREATE POLICY "authenticated_users_can_read"   ON public.user_game_link FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_insert" ON public.user_game_link FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_update" ON public.user_game_link FOR UPDATE TO authenticated USING (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_delete" ON public.user_game_link FOR DELETE TO authenticated USING (auth.uid() IS NOT NULL);
    ALTER TABLE public.user_game_link ENABLE ROW LEVEL SECURITY;
    RAISE NOTICE 'RLS enabled: user_game_link';
  ELSE
    RAISE NOTICE 'Skipped (does not exist): user_game_link';
  END IF;

  -- match_stats
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'match_stats') THEN
    DROP POLICY IF EXISTS "authenticated_users_can_read"   ON public.match_stats;
    DROP POLICY IF EXISTS "authenticated_users_can_insert" ON public.match_stats;
    DROP POLICY IF EXISTS "authenticated_users_can_update" ON public.match_stats;
    DROP POLICY IF EXISTS "authenticated_users_can_delete" ON public.match_stats;
    CREATE POLICY "authenticated_users_can_read"   ON public.match_stats FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_insert" ON public.match_stats FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_update" ON public.match_stats FOR UPDATE TO authenticated USING (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_delete" ON public.match_stats FOR DELETE TO authenticated USING (auth.uid() IS NOT NULL);
    ALTER TABLE public.match_stats ENABLE ROW LEVEL SECURITY;
    RAISE NOTICE 'RLS enabled: match_stats';
  ELSE
    RAISE NOTICE 'Skipped (does not exist): match_stats';
  END IF;

  -- match_stats_details
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'match_stats_details') THEN
    DROP POLICY IF EXISTS "authenticated_users_can_read"   ON public.match_stats_details;
    DROP POLICY IF EXISTS "authenticated_users_can_insert" ON public.match_stats_details;
    DROP POLICY IF EXISTS "authenticated_users_can_update" ON public.match_stats_details;
    DROP POLICY IF EXISTS "authenticated_users_can_delete" ON public.match_stats_details;
    CREATE POLICY "authenticated_users_can_read"   ON public.match_stats_details FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_insert" ON public.match_stats_details FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_update" ON public.match_stats_details FOR UPDATE TO authenticated USING (auth.uid() IS NOT NULL);
    CREATE POLICY "authenticated_users_can_delete" ON public.match_stats_details FOR DELETE TO authenticated USING (auth.uid() IS NOT NULL);
    ALTER TABLE public.match_stats_details ENABLE ROW LEVEL SECURITY;
    RAISE NOTICE 'RLS enabled: match_stats_details';
  ELSE
    RAISE NOTICE 'Skipped (does not exist): match_stats_details';
  END IF;

END $$;
