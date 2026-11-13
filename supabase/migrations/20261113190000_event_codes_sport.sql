-- Multi-sport (Ken, 2026-11-13): each code belongs to a sport, so a soccer
-- or rugby team only ever sees its own codes. Add-only: v2 never reads the
-- new column. NULL = any sport ("-" and S&C).
ALTER TABLE public.event_codes
  ADD COLUMN IF NOT EXISTS sport_id bigint REFERENCES public.sport (sport_id);

UPDATE public.event_codes SET sport_id = 1 WHERE event_code IN ('Football', 'Hurling') AND sport_id IS NULL;
UPDATE public.event_codes SET sport_id = 2 WHERE event_code = 'Soccer' AND sport_id IS NULL;
UPDATE public.event_codes SET sport_id = 3 WHERE event_code = 'Rugby' AND sport_id IS NULL;

COMMENT ON COLUMN public.event_codes.sport_id IS
  'Sport this code belongs to (sport.sport_id). NULL = any sport, e.g. "-" and S&C.';
