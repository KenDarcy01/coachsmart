-- Lightweight team lookup by joining code for the onboarding webview.
-- Returns team_name and team_id so the UI can confirm the correct team
-- before the user submits their join request.

CREATE OR REPLACE FUNCTION public.get_team_by_code(p_joining_code text)
RETURNS json
LANGUAGE sql
SECURITY DEFINER
SET search_path = 'public'
AS $$
    SELECT json_build_object(
        'team_name', team_name,
        'team_id',   team_id
    )
    FROM public.teams
    WHERE UPPER(TRIM(team_unique_code)) = UPPER(TRIM(COALESCE(p_joining_code, '')))
    LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.get_team_by_code(text) TO anon;
GRANT EXECUTE ON FUNCTION public.get_team_by_code(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_team_by_code(text) TO service_role;
