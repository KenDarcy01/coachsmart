-- Migration 20260825000001 cast default_team_id to text in both functions.
-- That fixed get_user_event_edit_detail (EditEventDetailsStruct casts as String?)
-- but broke get_user_event_create_detail (CreateEventDetailStruct uses
-- castToType<int> which returns null for a string, stateEventTeamID stays 0,
-- and the create form body is hidden behind stateEventTeamID != 0).
--
-- Fix: revert get_user_event_create_detail to return default_team_id as bigint.
-- get_user_event_edit_detail keeps ::text (correct for EditEventDetailsStruct).

CREATE OR REPLACE FUNCTION public.get_user_event_create_detail(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_result jsonb;
    v_default_team_id bigint;
BEGIN
    SELECT
        CASE WHEN COUNT(DISTINCT mtl.team_id) = 1 THEN MAX(mtl.team_id) ELSE NULL END
    INTO v_default_team_id
    FROM public.members m
    JOIN public.user_member_link uml ON m.member_id = uml.member_id
    JOIN public.member_team_link mtl ON m.member_id = mtl.member_id AND mtl.status = 'active'
    WHERE uml.user_id = p_user_id;

    SELECT jsonb_build_object(
        'user_id',         p_user_id,
        'default_team_id', v_default_team_id,
        'create_teams', (
            SELECT jsonb_agg(team_data)
            FROM (
                SELECT DISTINCT ON (t.team_id)
                    t.team_id, t.team_name, t.club_id, c.club_name,
                    m.member_id,
                    (m.first_name || ' ' || m.last_name) AS authorized_member_name,
                    r.role_id,
                    r.role_name  AS admin_role,
                    r.role_level AS admin_level,
                    (SELECT jsonb_agg(jsonb_build_object('id', et.event_type_id, 'name', et.event_type))
                     FROM public.event_types et) AS event_types,
                    (SELECT jsonb_agg(jsonb_build_object('id', ec.code_id, 'name', ec.event_code))
                     FROM public.club_code_link ccl
                     JOIN public.event_codes ec ON ccl.code_id = ec.code_id
                     WHERE ccl.club_id = t.club_id) AS event_codes,
                    (SELECT jsonb_agg(jsonb_build_object(
                         'id', r_inner.role_id, 'name', r_inner.role_name,
                         'name_plural', r_inner.role_name_plural))
                     FROM public.team_roles_link trl
                     JOIN public.roles r_inner ON trl.role_id = r_inner.role_id
                     WHERE trl.team_id = t.team_id
                       AND r_inner.role_grade = 10 AND r_inner.show_audience = true) AS team_roles,
                    (SELECT jsonb_agg(jsonb_build_object(
                         'id', s.squad_id, 'name', s.squad_name, 'image', s.squad_image))
                     FROM public.squads s
                     WHERE s.team_id = t.team_id) AS squads
                FROM public.members m
                JOIN public.user_member_link uml ON m.member_id = uml.member_id
                JOIN public.member_team_link mtl ON m.member_id = mtl.member_id AND mtl.status = 'active'
                JOIN public.teams t ON mtl.team_id = t.team_id
                LEFT JOIN public.clubs c ON t.club_id = c.club_id
                JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
                JOIN public.roles r ON mtrl.role_id = r.role_id
                WHERE uml.user_id = p_user_id AND r.role_grade = 100
                ORDER BY t.team_id, r.role_level DESC
            ) team_data
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$;
