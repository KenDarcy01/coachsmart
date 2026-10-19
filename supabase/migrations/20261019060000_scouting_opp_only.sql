-- The scouting picker names only the opposition side (Ken, 2026-10-19): no our-team step.
-- our_team and our_comp_id stay for older rows but are no longer filled in.
ALTER TABLE public.scouting_reports ALTER COLUMN our_team DROP NOT NULL;
