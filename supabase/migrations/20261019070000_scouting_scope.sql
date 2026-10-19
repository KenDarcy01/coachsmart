-- Which results a scouting report includes (Ken, 2026-10-19): "all" = every competition the
-- team played this year; "comp" = just the competition picked.
ALTER TABLE public.scouting_reports ADD COLUMN IF NOT EXISTS scope text NOT NULL DEFAULT 'all';
