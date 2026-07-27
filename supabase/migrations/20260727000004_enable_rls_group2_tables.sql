-- Enable RLS on the 7 remaining Group 2 tables.
--
-- invitations + reminders: existing "own only" policies are correct — enable as-is.
--
-- members, match_squads, match_squad_details, member_team_link,
-- member_team_role_link: existing policies were too restrictive (scoped to
-- user_id = auth.uid()) which would prevent coaches/admins from reading other
-- members' data. Replace with permissive "any authenticated user" policies
-- consistent with Group 1, then enable RLS. Tighten to club-scope when
-- multi-club support is added.

-- ─── invitations (enable as-is) ──────────────────────────────────────────────

ALTER TABLE "public"."invitations" ENABLE ROW LEVEL SECURITY;

-- ─── reminders (enable as-is) ────────────────────────────────────────────────

ALTER TABLE "public"."reminders" ENABLE ROW LEVEL SECURITY;

-- ─── members ─────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "authenticated_users_can_read"   ON "public"."members";
DROP POLICY IF EXISTS "authenticated_users_can_insert" ON "public"."members";
DROP POLICY IF EXISTS "authenticated_users_can_update" ON "public"."members";
DROP POLICY IF EXISTS "authenticated_users_can_delete" ON "public"."members";

CREATE POLICY "authenticated_users_can_read"   ON "public"."members" FOR SELECT TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_insert" ON "public"."members" FOR INSERT TO "authenticated" WITH CHECK ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_update" ON "public"."members" FOR UPDATE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_delete" ON "public"."members" FOR DELETE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);

ALTER TABLE "public"."members" ENABLE ROW LEVEL SECURITY;

-- ─── match_squads ────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "Authenticated users can manage their own match_squads." ON "public"."match_squads";

CREATE POLICY "authenticated_users_can_read"   ON "public"."match_squads" FOR SELECT TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_insert" ON "public"."match_squads" FOR INSERT TO "authenticated" WITH CHECK ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_update" ON "public"."match_squads" FOR UPDATE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_delete" ON "public"."match_squads" FOR DELETE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);

ALTER TABLE "public"."match_squads" ENABLE ROW LEVEL SECURITY;

-- ─── match_squad_details ─────────────────────────────────────────────────────

DROP POLICY IF EXISTS "Authenticated users can manage their own match_squads." ON "public"."match_squad_details";

CREATE POLICY "authenticated_users_can_read"   ON "public"."match_squad_details" FOR SELECT TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_insert" ON "public"."match_squad_details" FOR INSERT TO "authenticated" WITH CHECK ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_update" ON "public"."match_squad_details" FOR UPDATE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_delete" ON "public"."match_squad_details" FOR DELETE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);

ALTER TABLE "public"."match_squad_details" ENABLE ROW LEVEL SECURITY;

-- ─── member_team_link ────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "authenticated_users_can_read"   ON "public"."member_team_link";
DROP POLICY IF EXISTS "authenticated_users_can_insert" ON "public"."member_team_link";
DROP POLICY IF EXISTS "authenticated_users_can_update" ON "public"."member_team_link";
DROP POLICY IF EXISTS "authenticated_users_can_delete" ON "public"."member_team_link";

CREATE POLICY "authenticated_users_can_read"   ON "public"."member_team_link" FOR SELECT TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_insert" ON "public"."member_team_link" FOR INSERT TO "authenticated" WITH CHECK ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_update" ON "public"."member_team_link" FOR UPDATE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_delete" ON "public"."member_team_link" FOR DELETE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);

ALTER TABLE "public"."member_team_link" ENABLE ROW LEVEL SECURITY;

-- ─── member_team_role_link ───────────────────────────────────────────────────

DROP POLICY IF EXISTS "authenticated_users_can_read"   ON "public"."member_team_role_link";
DROP POLICY IF EXISTS "authenticated_users_can_insert" ON "public"."member_team_role_link";
DROP POLICY IF EXISTS "authenticated_users_can_update" ON "public"."member_team_role_link";
DROP POLICY IF EXISTS "authenticated_users_can_delete" ON "public"."member_team_role_link";

CREATE POLICY "authenticated_users_can_read"   ON "public"."member_team_role_link" FOR SELECT TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_insert" ON "public"."member_team_role_link" FOR INSERT TO "authenticated" WITH CHECK ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_update" ON "public"."member_team_role_link" FOR UPDATE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);
CREATE POLICY "authenticated_users_can_delete" ON "public"."member_team_role_link" FOR DELETE TO "authenticated" USING ("auth"."uid"() IS NOT NULL);

ALTER TABLE "public"."member_team_role_link" ENABLE ROW LEVEL SECURITY;
