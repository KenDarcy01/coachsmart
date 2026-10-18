-- Club lotto refunds: a ticket refunded in Stripe drops out of future draws, and
-- the refund is kept as a negative payment so sales figures stay net.
ALTER TABLE public.lotto_tickets DROP CONSTRAINT IF EXISTS lotto_tickets_status_check;
ALTER TABLE public.lotto_tickets ADD CONSTRAINT lotto_tickets_status_check
  CHECK (status IN ('pending', 'active', 'cancelled', 'ended', 'refunded'));
ALTER TABLE public.lotto_tickets ADD COLUMN IF NOT EXISTS refunded_at timestamptz;

ALTER TABLE public.lotto_payments DROP CONSTRAINT IF EXISTS lotto_payments_kind_check;
ALTER TABLE public.lotto_payments ADD CONSTRAINT lotto_payments_kind_check
  CHECK (kind IN ('checkout', 'renewal', 'refund'));
