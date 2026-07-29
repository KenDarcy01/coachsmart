-- Add onboarding_status to users table.
-- Written by the onboarding webview when the user reaches a terminal screen.
-- FlutterFlow subscribes to this column via real-time to update the app bar.
--
-- Values:
--   null           — not started / in progress
--   'pending'      — join request submitted, awaiting admin approval
--   'pending_other'— a different user already has a pending request for this name

ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS onboarding_status text;
