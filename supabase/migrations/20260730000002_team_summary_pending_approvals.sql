-- Add pending_approvals count to each team in get_user_team_summary.
-- Counts both pending member_team_link rows (new members awaiting join approval)
-- and pending user_member_link rows (second-user access requests) for that team.

CREATE OR REPLACE FUNCTION public.get_user_team_summary(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_overall_highest smallint;
    v_teams_json jsonb;
BEGIN
    SELECT MAX(r.role_level) INTO v_overall_highest
    FROM public.user_member_link uml
    JOIN public.member_team_link mtl ON uml.member_id = mtl.member_id AND mtl.status = 'active'
    JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.roles r ON mtrl.role_id = r.role_id
    WHERE uml.user_id = p_user_id
      AND uml.status = 'active';

    SELECT jsonb_agg(t_final) INTO v_teams_json
    FROM (
        SELECT DISTINCT ON (t.team_id)
            t.team_id,
            t.team_name,
            t.team_unique_code,
            r.role_level AS team_highest_role_level,
            r.role_name  AS team_role_name,
            (
                -- Pending new-member join requests
                SELECT COUNT(*)
                  FROM public.member_team_link mtl_p
                 WHERE mtl_p.team_id = t.team_id
                   AND mtl_p.status  = 'pending'
            ) + (
                -- Pending second-user access requests for members on this team
                SELECT COUNT(*)
                  FROM public.user_member_link uml_p
                  JOIN public.member_team_link mtl_a ON uml_p.member_id = mtl_a.member_id
                 WHERE mtl_a.team_id = t.team_id
                   AND mtl_a.status  = 'active'
                   AND uml_p.status  = 'pending'
            ) AS pending_approvals
        FROM public.user_member_link uml
        INNER JOIN public.member_team_link mtl ON uml.member_id = mtl.member_id AND mtl.status = 'active'
        INNER JOIN public.teams t ON mtl.team_id = t.team_id
        INNER JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        INNER JOIN public.roles r ON mtrl.role_id = r.role_id
        WHERE uml.user_id = p_user_id
          AND uml.status = 'active'
        ORDER BY t.team_id, r.role_level DESC
    ) t_final;

    RETURN jsonb_build_object(
        'overall_highest_role_level', COALESCE(v_overall_highest, 0),
        'teams', COALESCE(v_teams_json, '[]'::jsonb)
    );
END;
$$;
