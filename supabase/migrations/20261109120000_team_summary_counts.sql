-- get_user_team_summary: add club, role list and member counts per team for
-- the v3 Teams screen. Existing keys are unchanged, so the v2 app (which
-- reads team_id, team_name, team_unique_code, team_highest_role_level,
-- team_role_name, pending_approvals) is unaffected.
CREATE OR REPLACE FUNCTION public.get_user_team_summary(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

    SELECT jsonb_agg(t_final ORDER BY t_final.team_name) INTO v_teams_json
    FROM (
        SELECT DISTINCT ON (t.team_id)
            t.team_id,
            t.team_name,
            t.team_unique_code,
            t.profile_pic                       AS team_profile_pic,
            t.team_female,
            c.club_id,
            c.club_name,
            c.crest                             AS club_crest,
            r.role_level AS team_highest_role_level,
            r.role_name  AS team_role_name,
            (
                -- Every role this user holds on the team, highest first
                SELECT jsonb_agg(DISTINCT r2.role_name)
                  FROM public.user_member_link uml2
                  JOIN public.member_team_link mtl2 ON uml2.member_id = mtl2.member_id AND mtl2.status = 'active'
                  JOIN public.member_team_role_link mtrl2 ON mtl2.member_team_id = mtrl2.member_team_id
                  JOIN public.roles r2 ON mtrl2.role_id = r2.role_id
                 WHERE uml2.user_id = p_user_id AND uml2.status = 'active'
                   AND mtl2.team_id = t.team_id
            ) AS role_names,
            (
                SELECT COUNT(DISTINCT mtl_c.member_id)
                  FROM public.member_team_link mtl_c
                  JOIN public.member_team_role_link mtrl_c ON mtl_c.member_team_id = mtrl_c.member_team_id
                  JOIN public.roles r_c ON mtrl_c.role_id = r_c.role_id
                  JOIN public.members m_c ON mtl_c.member_id = m_c.member_id
                 WHERE mtl_c.team_id = t.team_id AND mtl_c.status = 'active'
                   AND m_c.status = 'active' AND r_c.role_level = 10
            ) AS player_count,
            (
                SELECT COUNT(DISTINCT mtl_c.member_id)
                  FROM public.member_team_link mtl_c
                  JOIN public.member_team_role_link mtrl_c ON mtl_c.member_team_id = mtrl_c.member_team_id
                  JOIN public.roles r_c ON mtrl_c.role_id = r_c.role_id
                  JOIN public.members m_c ON mtl_c.member_id = m_c.member_id
                 WHERE mtl_c.team_id = t.team_id AND mtl_c.status = 'active'
                   AND m_c.status = 'active' AND r_c.role_level BETWEEN 20 AND 99
            ) AS coach_count,
            (
                SELECT COUNT(DISTINCT mtl_c.member_id)
                  FROM public.member_team_link mtl_c
                  JOIN public.member_team_role_link mtrl_c ON mtl_c.member_team_id = mtrl_c.member_team_id
                  JOIN public.roles r_c ON mtrl_c.role_id = r_c.role_id
                  JOIN public.members m_c ON mtl_c.member_id = m_c.member_id
                 WHERE mtl_c.team_id = t.team_id AND mtl_c.status = 'active'
                   AND m_c.status = 'active' AND r_c.role_level >= 100
            ) AS admin_count,
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
        LEFT JOIN public.clubs c ON t.club_id = c.club_id
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
$function$;
