-- Soft-delete support for account deletion (App Store Guideline 5.1.1v).
-- The deleted_at timestamp marks the account as deleted while preserving
-- all data for potential reinstatement. The auth user is banned separately
-- via the delete-account edge function so the user cannot sign in.
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;
