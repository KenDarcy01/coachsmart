-- Migration 000011 revoked SELECT from anon on ALL public tables.
-- The published PWA (older FlutterFlow build) queries some lookup/reference
-- tables directly via PostgREST rather than through RPCs. Since the PWA
-- runs as the anon role (no JWT), those queries now fail with 403.
--
-- Re-grant SELECT to anon on tables that:
--   a) contain no PII or sensitive club data, and
--   b) are needed by the published PWA to populate form dropdowns.
--
-- Sensitive tables (members, events, teams, payments, attendance etc.)
-- remain revoked from anon — only static reference lists are re-opened.

GRANT SELECT ON public.event_types         TO anon;
GRANT SELECT ON public.event_response_type TO anon;
GRANT SELECT ON public.event_codes         TO anon;
GRANT SELECT ON public.roles               TO anon;
GRANT SELECT ON public.game_ages           TO anon;
GRANT SELECT ON public.sport               TO anon;
