-- Safety: re-grant permissions after get_squad_dashboard was created.
GRANT EXECUTE ON FUNCTION public.get_squad_dashboard(integer, timestamptz, timestamptz)
    TO anon, authenticated, service_role;
