-- Returns true if the calling user has at least one active team membership.
-- Called immediately after login to decide whether to route to home or the
-- onboarding webview.
--
-- true  → user is fully onboarded, go to home page
-- false → no active memberships yet, go to onboarding webview

CREATE OR REPLACE FUNCTION public.get_user_onboarding_status()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = 'public'
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM user_member_link uml
        JOIN member_team_link mtl ON mtl.member_id = uml.member_id
        WHERE uml.user_id  = auth.uid()
          AND uml.status   = 'active'
          AND mtl.status   = 'active'
    );
$$;

GRANT EXECUTE ON FUNCTION public.get_user_onboarding_status() TO authenticated;
