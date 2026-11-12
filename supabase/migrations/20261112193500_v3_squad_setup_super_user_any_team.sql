-- Squad setup: a super user is a super user on every team they're on
-- (Ken, 2026-11-12). The v3 Team page already decides this the same way
-- (get_team_members_by_role user_highest_role_level is the highest role on
-- any team), so the page and the functions now agree. Only v3's squad setup
-- functions (20261112190000) call is_team_super_user; v2 is untouched.
CREATE OR REPLACE FUNCTION public.is_team_super_user(p_team_id bigint)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1
      FROM members m
      JOIN member_team_link mtl       ON mtl.member_id = m.member_id
      JOIN member_team_role_link mtrl ON mtrl.member_team_id = mtl.member_team_id
      JOIN roles r                    ON r.role_id = mtrl.role_id
     WHERE m.user_id = auth.uid()
       AND mtl.status = 'active'
       AND r.role_level >= 110);
$$;

REVOKE ALL ON FUNCTION public.is_team_super_user(bigint) FROM PUBLIC, anon, authenticated;
