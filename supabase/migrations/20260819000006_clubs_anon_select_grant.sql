-- Belt-and-braces: ensure anon has table-level SELECT on clubs.
-- This is idempotent if 20260819000004 already ran with the GRANT included.
GRANT SELECT ON public.clubs TO anon;
