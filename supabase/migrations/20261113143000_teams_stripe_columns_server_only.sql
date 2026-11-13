-- Team Stripe Connect hardening (2026-11-13). teams is readable and updatable
-- by any signed-in user (old FlutterFlow policies), so app users could write
-- the Stripe columns directly, e.g. mark a team approved or swap its Stripe
-- account. Only the edge functions (service role) and migrations may change
-- them now. Nothing in the app writes these columns.
CREATE OR REPLACE FUNCTION public.teams_stripe_columns_server_only()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = 'public'
AS $$
BEGIN
  IF COALESCE(auth.role(), '') IN ('authenticated', 'anon') AND (
       NEW.stripe_account_id        IS DISTINCT FROM OLD.stripe_account_id
    OR NEW.stripe_charges_enabled   IS DISTINCT FROM OLD.stripe_charges_enabled
    OR NEW.stripe_payouts_enabled   IS DISTINCT FROM OLD.stripe_payouts_enabled
    OR NEW.stripe_details_submitted IS DISTINCT FROM OLD.stripe_details_submitted
    OR NEW.stripe_ready_at          IS DISTINCT FROM OLD.stripe_ready_at
    OR NEW.stripe_approved_at       IS DISTINCT FROM OLD.stripe_approved_at
    OR NEW.stripe_approved_by       IS DISTINCT FROM OLD.stripe_approved_by
    OR NEW.stripe_connected_by      IS DISTINCT FROM OLD.stripe_connected_by
    OR NEW.stripe_notified_at       IS DISTINCT FROM OLD.stripe_notified_at
    OR NEW.stripe_fee_bps           IS DISTINCT FROM OLD.stripe_fee_bps
    OR NEW.stripe_updated_at        IS DISTINCT FROM OLD.stripe_updated_at
  ) THEN
    RAISE EXCEPTION 'Team Stripe settings can only be changed by CoachSmart'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS teams_stripe_columns_server_only ON public.teams;
CREATE TRIGGER teams_stripe_columns_server_only
  BEFORE UPDATE ON public.teams
  FOR EACH ROW EXECUTE FUNCTION public.teams_stripe_columns_server_only();

-- New teams start without Stripe settings when created from the app.
CREATE OR REPLACE FUNCTION public.teams_stripe_columns_blank_on_insert()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = 'public'
AS $$
BEGIN
  IF COALESCE(auth.role(), '') IN ('authenticated', 'anon') THEN
    NEW.stripe_account_id := NULL; NEW.stripe_charges_enabled := false; NEW.stripe_payouts_enabled := false;
    NEW.stripe_details_submitted := false; NEW.stripe_ready_at := NULL; NEW.stripe_approved_at := NULL;
    NEW.stripe_approved_by := NULL; NEW.stripe_connected_by := NULL; NEW.stripe_notified_at := NULL;
    NEW.stripe_fee_bps := NULL;
  END IF;
  RETURN NEW;
END;
$$;

-- Named to fire before teams_payments_need_stripe (triggers run in name order).
DROP TRIGGER IF EXISTS teams_a_stripe_blank_on_insert ON public.teams;
CREATE TRIGGER teams_a_stripe_blank_on_insert
  BEFORE INSERT ON public.teams
  FOR EACH ROW EXECUTE FUNCTION public.teams_stripe_columns_blank_on_insert();
