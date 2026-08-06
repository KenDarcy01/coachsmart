-- Filtered postgres_changes subscriptions require REPLICA IDENTITY FULL so
-- PostgreSQL includes all column values in the WAL, not just the primary key.
-- Without this, row-level filters on realtime channels silently drop events.
ALTER TABLE public.match_stats_details REPLICA IDENTITY FULL;
ALTER TABLE public.match_timer         REPLICA IDENTITY FULL;
