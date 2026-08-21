-- Enable REPLICA IDENTITY FULL on notifications so Supabase Realtime can
-- reliably filter UPDATE events (e.g. is_read changes) by recipient_user_id.
-- Without this, the old tuple in the WAL only contains the primary key,
-- which breaks filtered postgres_changes subscriptions on UPDATE.

ALTER TABLE public.notifications REPLICA IDENTITY FULL;

-- Drop the deprecated two-param overload of mark_notification_read.
-- The single-param version (auth.uid()-guarded) is the only live version.
-- The two-param overload was never called by the Flutter app and had an
-- overly broad anon grant.

DROP FUNCTION IF EXISTS public.mark_notification_read(bigint, uuid);
