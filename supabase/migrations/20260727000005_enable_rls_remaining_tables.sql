-- Enable RLS on all remaining unprotected tables.
-- None of these had any policies defined, so we create standard
-- "any authenticated user" policies before enabling RLS.
--
-- match_stats, match_stats_details, and user_game_link were created
-- directly in the database rather than via a migration file.

-- ─── Helper macro: for each table create 4 standard policies then enable RLS.
-- Policies use auth.uid() IS NOT NULL (= any logged-in user) consistent with
-- the approach taken in migrations 000003 and 000004.

-- ─── event_user_payment ──────────────────────────────────────────────────────

CREATE POLICY "authenticated_users_can_read"   ON "public"."event_user_payment" FOR SELECT TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_insert" ON "public"."event_user_payment" FOR INSERT TO "authenticated" WITH CHECK ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_update" ON "public"."event_user_payment" FOR UPDATE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_delete" ON "public"."event_user_payment" FOR DELETE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
ALTER TABLE "public"."event_user_payment" ENABLE ROW LEVEL SECURITY;

-- ─── event_user_member_payment ───────────────────────────────────────────────

CREATE POLICY "authenticated_users_can_read"   ON "public"."event_user_member_payment" FOR SELECT TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_insert" ON "public"."event_user_member_payment" FOR INSERT TO "authenticated" WITH CHECK ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_update" ON "public"."event_user_member_payment" FOR UPDATE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_delete" ON "public"."event_user_member_payment" FOR DELETE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
ALTER TABLE "public"."event_user_member_payment" ENABLE ROW LEVEL SECURITY;

-- ─── match_reports ───────────────────────────────────────────────────────────

CREATE POLICY "authenticated_users_can_read"   ON "public"."match_reports" FOR SELECT TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_insert" ON "public"."match_reports" FOR INSERT TO "authenticated" WITH CHECK ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_update" ON "public"."match_reports" FOR UPDATE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_delete" ON "public"."match_reports" FOR DELETE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
ALTER TABLE "public"."match_reports" ENABLE ROW LEVEL SECURITY;

-- ─── match_scores ────────────────────────────────────────────────────────────

CREATE POLICY "authenticated_users_can_read"   ON "public"."match_scores" FOR SELECT TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_insert" ON "public"."match_scores" FOR INSERT TO "authenticated" WITH CHECK ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_update" ON "public"."match_scores" FOR UPDATE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_delete" ON "public"."match_scores" FOR DELETE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
ALTER TABLE "public"."match_scores" ENABLE ROW LEVEL SECURITY;

-- ─── match_scores_details ────────────────────────────────────────────────────

CREATE POLICY "authenticated_users_can_read"   ON "public"."match_scores_details" FOR SELECT TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_insert" ON "public"."match_scores_details" FOR INSERT TO "authenticated" WITH CHECK ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_update" ON "public"."match_scores_details" FOR UPDATE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_delete" ON "public"."match_scores_details" FOR DELETE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
ALTER TABLE "public"."match_scores_details" ENABLE ROW LEVEL SECURITY;

-- ─── match_score_types ───────────────────────────────────────────────────────

CREATE POLICY "authenticated_users_can_read"   ON "public"."match_score_types" FOR SELECT TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_insert" ON "public"."match_score_types" FOR INSERT TO "authenticated" WITH CHECK ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_update" ON "public"."match_score_types" FOR UPDATE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_delete" ON "public"."match_score_types" FOR DELETE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
ALTER TABLE "public"."match_score_types" ENABLE ROW LEVEL SECURITY;

-- ─── member_squad_link ───────────────────────────────────────────────────────

CREATE POLICY "authenticated_users_can_read"   ON "public"."member_squad_link" FOR SELECT TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_insert" ON "public"."member_squad_link" FOR INSERT TO "authenticated" WITH CHECK ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_update" ON "public"."member_squad_link" FOR UPDATE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_delete" ON "public"."member_squad_link" FOR DELETE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
ALTER TABLE "public"."member_squad_link" ENABLE ROW LEVEL SECURITY;

-- ─── legacy_users ────────────────────────────────────────────────────────────

CREATE POLICY "authenticated_users_can_read"   ON "public"."legacy_users" FOR SELECT TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_insert" ON "public"."legacy_users" FOR INSERT TO "authenticated" WITH CHECK ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_update" ON "public"."legacy_users" FOR UPDATE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_delete" ON "public"."legacy_users" FOR DELETE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
ALTER TABLE "public"."legacy_users" ENABLE ROW LEVEL SECURITY;

-- ─── user_game_link (created directly in DB) ─────────────────────────────────

CREATE POLICY "authenticated_users_can_read"   ON "public"."user_game_link" FOR SELECT TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_insert" ON "public"."user_game_link" FOR INSERT TO "authenticated" WITH CHECK ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_update" ON "public"."user_game_link" FOR UPDATE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_delete" ON "public"."user_game_link" FOR DELETE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
ALTER TABLE "public"."user_game_link" ENABLE ROW LEVEL SECURITY;

-- ─── match_stats (created directly in DB) ────────────────────────────────────

CREATE POLICY "authenticated_users_can_read"   ON "public"."match_stats" FOR SELECT TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_insert" ON "public"."match_stats" FOR INSERT TO "authenticated" WITH CHECK ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_update" ON "public"."match_stats" FOR UPDATE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_delete" ON "public"."match_stats" FOR DELETE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
ALTER TABLE "public"."match_stats" ENABLE ROW LEVEL SECURITY;

-- ─── match_stats_details (created directly in DB) ────────────────────────────

CREATE POLICY "authenticated_users_can_read"   ON "public"."match_stats_details" FOR SELECT TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_insert" ON "public"."match_stats_details" FOR INSERT TO "authenticated" WITH CHECK ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_update" ON "public"."match_stats_details" FOR UPDATE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_delete" ON "public"."match_stats_details" FOR DELETE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
ALTER TABLE "public"."match_stats_details" ENABLE ROW LEVEL SECURITY;
