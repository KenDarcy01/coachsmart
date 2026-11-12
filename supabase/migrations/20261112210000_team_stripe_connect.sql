-- Team Stripe Connect (2026-11-12, thread "Plan Stripe Connect for team payouts").
-- Each team can connect its own Stripe account (Standard) so event payments go
-- straight to the team's bank. CoachSmart never holds a team's money:
-- - teams.payments can only be switched ON once the team's account can take
--   payments (stripe_charges_enabled). Switching it off is always allowed.
-- - The 4 teams already taking payments on the CoachSmart account keep it
--   until they connect (checkout falls back only when stripe_ready_at is null).
-- Nothing changes for any team until it connects. v2 screens are untouched.

ALTER TABLE public.teams
  ADD COLUMN IF NOT EXISTS stripe_account_id text,
  ADD COLUMN IF NOT EXISTS stripe_charges_enabled boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS stripe_payouts_enabled boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS stripe_details_submitted boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS stripe_ready_at timestamptz,
  ADD COLUMN IF NOT EXISTS stripe_connected_by uuid,
  ADD COLUMN IF NOT EXISTS stripe_updated_at timestamptz;

CREATE UNIQUE INDEX IF NOT EXISTS teams_stripe_account_id_key
  ON public.teams (stripe_account_id) WHERE stripe_account_id IS NOT NULL;

-- Which Stripe account a payment was made on (NULL = the CoachSmart account).
ALTER TABLE public.event_user_member_payment
  ADD COLUMN IF NOT EXISTS stripe_account_id text;

-- The payments switch stays locked until the team's own account is ready.
CREATE OR REPLACE FUNCTION public.teams_payments_need_stripe()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = 'public'
AS $$
BEGIN
  IF NEW.payments AND (TG_OP = 'INSERT' OR NOT COALESCE(OLD.payments, false)) AND NOT NEW.stripe_charges_enabled THEN
    RAISE EXCEPTION 'Connect the team''s Stripe account before turning on payments'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS teams_payments_need_stripe ON public.teams;
CREATE TRIGGER teams_payments_need_stripe
  BEFORE INSERT OR UPDATE OF payments ON public.teams
  FOR EACH ROW EXECUTE FUNCTION public.teams_payments_need_stripe();

