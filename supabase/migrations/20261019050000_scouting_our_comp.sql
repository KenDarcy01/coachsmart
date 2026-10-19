-- A scouting pair names each side's competition (Ken, 2026-10-19: a specific team in a specific
-- division). Some codes list every team of a club under one name (LGFA), so the division is part
-- of what makes a side. comp_id is the opposition's competition; our_comp_id is ours.
ALTER TABLE public.scouting_reports ADD COLUMN IF NOT EXISTS our_comp_id text;
