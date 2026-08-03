-- Returns the roles available for a specific team, ordered by list sequence.

CREATE OR REPLACE FUNCTION public.get_team_roles(p_team_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    RETURN COALESCE((
        SELECT jsonb_agg(
            jsonb_build_object(
                'role_id',          r.role_id,
                'role_name',        r.role_name,
                'role_name_plural', r.role_name_plural,
                'role_list_seq',    r.role_list_seq,
                'role_grade',       r.role_grade,
                'role_level',       r.role_level
            )
            ORDER BY r.role_list_seq ASC, r.role_grade DESC
        )
        FROM public.team_roles_link trl
        JOIN public.roles r ON r.role_id = trl.role_id
        WHERE trl.team_id = p_team_id
    ), '[]'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_team_roles(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_team_roles(bigint) TO service_role;
