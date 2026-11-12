-- Fix: roles.role_level/role_grade are smallint; cast to the declared int.
CREATE OR REPLACE FUNCTION public.event_invitee_members(
    p_team_id bigint, p_audience_id bigint, p_squad_id bigint, p_code_id bigint)
RETURNS TABLE(member_id bigint, role_level int, role_grade int)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_level int := 0;
    v_code  bigint := p_code_id;
    v_club  bigint;
BEGIN
    SELECT COALESCE(r.role_level, 0) INTO v_level
    FROM public.roles r WHERE r.role_id = p_audience_id;
    v_level := COALESCE(v_level, 0);

    -- Same code fallback as get_updated_event_code.
    IF p_squad_id IS NOT NULL AND COALESCE(v_code, 0) <= 1 THEN
        SELECT t.club_id INTO v_club FROM public.teams t WHERE t.team_id = p_team_id;
        SELECT COALESCE((
            SELECT ccl.code_id FROM public.club_code_link ccl
            WHERE ccl.club_id = v_club AND ccl.code_id > 1
              AND (ccl.team_id IS NULL OR ccl.team_id = p_team_id)
              AND public.team_has_code(p_team_id, ccl.code_id)
            ORDER BY ccl.code_id LIMIT 1), v_code) INTO v_code;
    END IF;

    RETURN QUERY
    SELECT DISTINCT mtl.member_id::bigint, r.role_level::int, r.role_grade::int
    FROM public.member_team_link mtl
    JOIN public.member_team_role_link mtrl ON mtrl.member_team_id = mtl.member_team_id
    JOIN public.roles r ON r.role_id = mtrl.role_id
    WHERE mtl.team_id = p_team_id
      AND mtl.status = 'active'
      AND (v_level <= 10 OR r.role_level >= v_level)
      AND (p_squad_id IS NULL OR EXISTS (
          SELECT 1 FROM public.member_squad_link msl
          WHERE msl.member_id = mtl.member_id
            AND msl.squad_id = p_squad_id
            AND msl.code_id = v_code));
END;
$$;
