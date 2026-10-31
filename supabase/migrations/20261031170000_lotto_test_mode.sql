-- Club lotto test mode: while a lotto is in setup, tickets can be taken without
-- Stripe so the whole flow (emails, draws, winners) can be tried end to end.
-- Test tickets are marked so they can be cleared before going live.
ALTER TABLE public.lotto_clubs   ADD COLUMN IF NOT EXISTS test_mode boolean NOT NULL DEFAULT false;
ALTER TABLE public.lotto_tickets ADD COLUMN IF NOT EXISTS is_test   boolean NOT NULL DEFAULT false;
