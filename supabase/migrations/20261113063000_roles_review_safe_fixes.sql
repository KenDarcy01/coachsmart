-- Roles review, safe fixes (Ken approved 2026-11-13, thread "Review what each
-- role can see and do"). Nothing here changes what v2 does:
--
-- 1. is_team_super_user: a super user is still a super user on every team
--    they're on (Ken, 2026-11-12), but they must actually be on the team.
--    Before, being SuperUser anywhere passed for every team in the database.
--    Only v3's squad setup functions call it.
-- 2. teams Stripe fields and the payments switch can only be changed by
--    CoachSmart's server code (edge functions with the service key, or
--    SECURITY DEFINER functions), never by an app user writing to the table.
--    Neither app writes these columns.
-- 3. users.ai_features: same, only server code or Ken via SQL can change it.

-- 1 ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_team_super_user(p_team_id bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT auth.uid() IS NOT NULL
    -- SuperUser on some team ...
    AND EXISTS (
      SELECT 1
        FROM members m
        JOIN member_team_link mtl       ON mtl.member_id = m.member_id
        JOIN member_team_role_link mtrl ON mtrl.member_team_id = mtl.member_team_id
        JOIN roles r                    ON r.role_id = mtrl.role_id
       WHERE m.user_id = auth.uid()
         AND mtl.status = 'active'
         AND r.role_level >= 110)
    -- ... and on this team.
    AND EXISTS (
      SELECT 1
        FROM user_member_link uml
        JOIN member_team_link mtl ON mtl.member_id = uml.member_id
       WHERE uml.user_id = auth.uid()
         AND COALESCE(uml.status, 'active') = 'active'
         AND mtl.team_id = p_team_id
         AND mtl.status = 'active');
$function$;

-- 2 ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.teams_protect_stripe()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = 'public'
AS $$
BEGIN
  -- App users write as 'authenticated' (or 'anon'); server code runs as
  -- service_role or as the owner of a SECURITY DEFINER function.
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'INSERT' THEN
    IF NEW.stripe_account_id IS NOT NULL OR NEW.stripe_charges_enabled
       OR NEW.stripe_payouts_enabled OR NEW.stripe_details_submitted
       OR NEW.stripe_ready_at IS NOT NULL OR NEW.stripe_connected_by IS NOT NULL
       OR NEW.stripe_approved_at IS NOT NULL OR NEW.stripe_approved_by IS NOT NULL
       OR NEW.stripe_notified_at IS NOT NULL OR NEW.stripe_fee_bps IS NOT NULL
       OR COALESCE(NEW.payments, false) THEN
      RAISE EXCEPTION 'Team payment settings can only be changed by CoachSmart'
        USING ERRCODE = 'insufficient_privilege';
    END IF;
    RETURN NEW;
  END IF;
  IF NEW.stripe_account_id IS DISTINCT FROM OLD.stripe_account_id
     OR NEW.stripe_charges_enabled IS DISTINCT FROM OLD.stripe_charges_enabled
     OR NEW.stripe_payouts_enabled IS DISTINCT FROM OLD.stripe_payouts_enabled
     OR NEW.stripe_details_submitted IS DISTINCT FROM OLD.stripe_details_submitted
     OR NEW.stripe_ready_at IS DISTINCT FROM OLD.stripe_ready_at
     OR NEW.stripe_connected_by IS DISTINCT FROM OLD.stripe_connected_by
     OR NEW.stripe_updated_at IS DISTINCT FROM OLD.stripe_updated_at
     OR NEW.stripe_approved_at IS DISTINCT FROM OLD.stripe_approved_at
     OR NEW.stripe_approved_by IS DISTINCT FROM OLD.stripe_approved_by
     OR NEW.stripe_notified_at IS DISTINCT FROM OLD.stripe_notified_at
     OR NEW.stripe_fee_bps IS DISTINCT FROM OLD.stripe_fee_bps
     OR NEW.payments IS DISTINCT FROM OLD.payments THEN
    RAISE EXCEPTION 'Team payment settings can only be changed by CoachSmart'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS teams_protect_stripe ON public.teams;
CREATE TRIGGER teams_protect_stripe
  BEFORE INSERT OR UPDATE ON public.teams
  FOR EACH ROW EXECUTE FUNCTION public.teams_protect_stripe();

-- 3 ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.users_protect_ai_features()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = 'public'
AS $$
DECLARE
  v_before boolean := false;
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' THEN
    v_before := COALESCE(OLD.ai_features, false);
  END IF;
  IF COALESCE(NEW.ai_features, false) <> v_before THEN
    RAISE EXCEPTION 'AI features can only be switched on by CoachSmart'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS users_protect_ai_features ON public.users;
CREATE TRIGGER users_protect_ai_features
  BEFORE INSERT OR UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.users_protect_ai_features();
