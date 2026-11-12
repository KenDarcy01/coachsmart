-- Team Stripe Connect: Ken's approval and the CoachSmart fee (2026-11-12,
-- thread "Plan Stripe Connect for team payouts").
-- - A team's own Stripe account only takes payments once Ken approves it
--   (stripe_approved_at). Ken is emailed when a team finishes Stripe setup and
--   approves on webviews/stripe-approvals.html (his login only).
-- - CoachSmart's cut: an application fee Stripe moves to the CoachSmart account
--   on each payment. payment_settings.default_fee_bps (basis points, 100 = 1%)
--   for everyone, teams.stripe_fee_bps overrides it per team. Starts at 0.
--   The fee comes out of the team's money; parents pay the price the coach set.

ALTER TABLE public.teams
  ADD COLUMN IF NOT EXISTS stripe_approved_at timestamptz,
  ADD COLUMN IF NOT EXISTS stripe_approved_by uuid,
  ADD COLUMN IF NOT EXISTS stripe_notified_at timestamptz,
  ADD COLUMN IF NOT EXISTS stripe_fee_bps integer CHECK (stripe_fee_bps IS NULL OR stripe_fee_bps BETWEEN 0 AND 2000);

ALTER TABLE public.event_user_member_payment
  ADD COLUMN IF NOT EXISTS platform_fee_amount integer;

CREATE TABLE IF NOT EXISTS public.payment_settings (
  id integer PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  default_fee_bps integer NOT NULL DEFAULT 0 CHECK (default_fee_bps BETWEEN 0 AND 2000),
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid
);
ALTER TABLE public.payment_settings ENABLE ROW LEVEL SECURITY;
INSERT INTO public.payment_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

-- The payments switch needs a ready AND approved team account.
CREATE OR REPLACE FUNCTION public.teams_payments_need_stripe()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = 'public'
AS $$
BEGIN
  IF NEW.payments AND (TG_OP = 'INSERT' OR NOT COALESCE(OLD.payments, false))
     AND (NOT NEW.stripe_charges_enabled OR NEW.stripe_approved_at IS NULL) THEN
    RAISE EXCEPTION 'The team''s Stripe account must be set up and approved before turning on payments'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;
