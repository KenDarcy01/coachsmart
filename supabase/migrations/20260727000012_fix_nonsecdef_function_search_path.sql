-- Migration 000008 pinned search_path on SECURITY DEFINER functions only.
-- The Supabase linter also flags non-SECURITY DEFINER functions with mutable
-- search_path. This migration runs the same dynamic fix over ALL public
-- functions (no prosecdef filter) to catch the remaining cases.
-- ALTER FUNCTION does not touch the function body — no behaviour change.

DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT
            p.proname,
            pg_get_function_identity_arguments(p.oid) AS args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
          AND NOT EXISTS (
              SELECT 1
              FROM pg_options_to_table(p.proconfig)
              WHERE option_name = 'search_path'
          )
    LOOP
        EXECUTE format(
            'ALTER FUNCTION public.%I(%s) SET search_path = ''public''',
            r.proname,
            r.args
        );
        RAISE NOTICE 'Pinned search_path: public.%(%)', r.proname, r.args;
    END LOOP;
END
$$;
