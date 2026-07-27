-- Pin search_path on all SECURITY DEFINER functions that don't have it set.
-- Uses a dynamic loop over pg_proc so it catches any function we've missed,
-- including functions added by future migrations before this one runs.
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
          AND p.prosecdef = true
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
