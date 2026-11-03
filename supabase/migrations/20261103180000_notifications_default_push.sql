-- Root cause of 35 notifications stuck unsent since August (Ken, 2026-11-03):
-- join/access request rows were inserted with delivery_method NULL between
-- 4 and 17 August, and cron_batch_notification_send only picks up 'push' or
-- 'email', so they were never sent and the every-minute job kept calling the
-- send function for them. Default the column to 'push' (push falls back to
-- email when the user has no token). The send function now also treats NULL
-- as push and gives up on anything older than a day (auto_cleared =
-- 'stale_unsent'), which clears the August rows on its next run.
ALTER TABLE public.notifications ALTER COLUMN delivery_method SET DEFAULT 'push';
