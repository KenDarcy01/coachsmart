-- Multi-sport step 5: soccer lineups have a formation pick list (Ken,
-- 2026-11-16). v3 saves the chosen shape ('4-3-3' etc.) so the lineup
-- reopens on it. GAA and rugby leave it empty; the old app never reads it.
ALTER TABLE public.lineup ADD COLUMN IF NOT EXISTS formation text;
