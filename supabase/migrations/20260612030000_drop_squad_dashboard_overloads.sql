-- Drop orphaned overloads of get_squad_dashboard that cause PGRST203 ambiguity.
--
-- When each successive migration added parameters (3→5→7), PostgreSQL treated
-- each new signature as a SEPARATE function rather than replacing the old one,
-- because CREATE OR REPLACE only replaces an exact signature match.
-- PostgREST then can't choose between them, returning HTTP 300/PGRST203.
--
-- Fix: drop the 3-param and 5-param overloads; keep only the 7-param (v5) version.

DROP FUNCTION IF EXISTS public.get_squad_dashboard(integer, timestamptz, timestamptz);
DROP FUNCTION IF EXISTS public.get_squad_dashboard(integer, timestamptz, timestamptz, text[], text[]);
