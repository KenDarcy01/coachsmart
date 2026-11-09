-- v3 attendance page: one call for the attendee lists of an event
-- (Ken, 2026-11-09: squad cards at the top as today, squad under each name,
-- Lineup on the event page with a squad choice). Additive: the v2 app keeps
-- using get_event_attendance_by_role_v2 and the summary function.
--
-- Returns, for the signed-in team member:
--   event_title, is_match, user_role_level (caller's highest role in the team)
--   code_id          the code whose squads apply (get_updated_event_code)
--   event_squad_id   the event's own squad, or null for the whole team
--   event_role_level roles at or above this level are listed (grade 10 only)
--   allow_lineup     teams.allow_lineup
--   match_squad_id / published_at   latest published match squad, if any
--   squads  [{squad_id, squad_name, squad_image, squad_colour, squad_list_seq}]
--   roles   [{role_id, role_name, role_name_plural, role_level, role_list_seq}]
--   members [{member_id, member_name, first_name, last_name, role_id,
--             role_level, squad_id, squad_name, response_id}]
--           one row per member and listed role; response_id 3 = attending,
--           4 = declined, null = no reply yet. Members with no squad for the
--           code are included with squad_id null (v2 left them out).
CREATE OR REPLACE FUNCTION public.get_event_attendance_v3(p_event_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 STABLE
 SET search_path TO 'public'
AS $function$
DECLARE
    v_team_id bigint;
    v_event_squad_id bigint;
    v_code_id bigint;
    v_event_role_level smallint;
    v_allow_lineup boolean;
    v_is_member boolean;
    v_event_title text;
    v_is_match boolean;
    v_user_role_level smallint;
BEGIN
    SELECT e.team_id, e.squad_id, COALESCE(r.role_level, 10), COALESCE(t.allow_lineup, false),
           e.event_title, COALESCE(et.event_type ILIKE 'match', false)
      INTO v_team_id, v_event_squad_id, v_event_role_level, v_allow_lineup, v_event_title, v_is_match
    FROM public.events e
    JOIN public.teams t ON t.team_id = e.team_id
    LEFT JOIN public.roles r ON r.role_id = e.audience_id
    LEFT JOIN public.event_types et ON et.event_type_id = e.event_type_id
    WHERE e.event_id = p_event_id;

    IF v_team_id IS NULL THEN
        RETURN jsonb_build_object('error', 'Event not found.');
    END IF;

    -- Any active member of the team may read the lists (as the v2 pages).
    SELECT EXISTS (
        SELECT 1
        FROM public.member_team_link mtl
        JOIN public.user_member_link uml ON uml.member_id = mtl.member_id AND uml.status = 'active'
        WHERE mtl.team_id = v_team_id AND mtl.status = 'active' AND uml.user_id = auth.uid()
    ) INTO v_is_member;
    IF auth.uid() IS NULL OR NOT v_is_member THEN
        RETURN jsonb_build_object('error', 'You are not a member of this team.');
    END IF;

    -- The caller's highest role level in the team (100+ = admin actions).
    SELECT COALESCE(MAX(r.role_level), 0) INTO v_user_role_level
    FROM public.member_team_link mtl
    JOIN public.user_member_link uml ON uml.member_id = mtl.member_id AND uml.status = 'active'
    JOIN public.member_team_role_link mtrl ON mtrl.member_team_id = mtl.member_team_id
    JOIN public.roles r ON r.role_id = mtrl.role_id
    WHERE mtl.team_id = v_team_id AND mtl.status = 'active' AND uml.user_id = auth.uid();

    v_code_id := public.get_updated_event_code(p_event_id);

    RETURN (
    WITH visible_roles AS (
        SELECT r.role_id, r.role_name, r.role_name_plural, r.role_level, r.role_list_seq
        FROM public.team_roles_link trl
        JOIN public.roles r ON r.role_id = trl.role_id
        WHERE trl.team_id = v_team_id
          AND r.role_grade = 10
          AND r.role_level >= v_event_role_level
    ),
    team_squads AS (
        SELECT sq.squad_id, sq.squad_name, sq.squad_image, sq.squad_colour, sq.squad_list_seq
        FROM public.squads sq
        WHERE sq.team_id = v_team_id
          AND (v_event_squad_id IS NULL OR sq.squad_id = v_event_squad_id)
    ),
    latest_reply AS (
        SELECT DISTINCT ON (ea.member_id) ea.member_id, ea.response_id
        FROM public.event_attendance ea
        WHERE ea.event_id = p_event_id
        ORDER BY ea.member_id, ea.created_at DESC
    ),
    member_squad AS (
        SELECT DISTINCT ON (msl.member_id) msl.member_id, msl.squad_id
        FROM public.member_squad_link msl
        WHERE msl.team_id = v_team_id AND msl.code_id = v_code_id
        ORDER BY msl.member_id, msl.created_at DESC
    ),
    member_rows AS (
        SELECT DISTINCT
            m.member_id, m.first_name, m.last_name,
            vr.role_id, vr.role_level, vr.role_list_seq,
            ms.squad_id, sq.squad_name,
            lr.response_id
        FROM public.member_team_link mtl
        JOIN public.members m ON m.member_id = mtl.member_id AND COALESCE(m.status, '') <> 'deleted'
        JOIN public.member_team_role_link mtrl ON mtrl.member_team_id = mtl.member_team_id
        JOIN visible_roles vr ON vr.role_id = mtrl.role_id
        LEFT JOIN member_squad ms ON ms.member_id = m.member_id
        LEFT JOIN public.squads sq ON sq.squad_id = ms.squad_id
        LEFT JOIN latest_reply lr ON lr.member_id = m.member_id
        WHERE mtl.team_id = v_team_id
          AND mtl.status = 'active'
          AND (v_event_squad_id IS NULL OR ms.squad_id = v_event_squad_id)
    ),
    published AS (
        SELECT msq.match_squad_id, msq.created_at
        FROM public.match_squads msq
        WHERE msq.event_id = p_event_id
        ORDER BY msq.created_at DESC
        LIMIT 1
    )
    SELECT jsonb_build_object(
        'event_id', p_event_id,
        'event_title', v_event_title,
        'is_match', v_is_match,
        'user_role_level', v_user_role_level,
        'team_id', v_team_id,
        'code_id', v_code_id,
        'event_squad_id', v_event_squad_id,
        'event_role_level', v_event_role_level,
        'allow_lineup', v_allow_lineup,
        'match_squad_id', (SELECT match_squad_id FROM published),
        'published_at', (SELECT created_at FROM published),
        'squads', COALESCE((
            SELECT jsonb_agg(to_jsonb(ts) ORDER BY ts.squad_list_seq NULLS LAST, ts.squad_name)
            FROM team_squads ts), '[]'::jsonb),
        'roles', COALESCE((
            SELECT jsonb_agg(to_jsonb(vr) ORDER BY vr.role_list_seq NULLS LAST, vr.role_level)
            FROM visible_roles vr), '[]'::jsonb),
        'members', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'member_id', mr.member_id,
                'member_name', trim(COALESCE(mr.first_name, '') || ' ' || COALESCE(mr.last_name, '')),
                'first_name', mr.first_name,
                'last_name', mr.last_name,
                'role_id', mr.role_id,
                'role_level', mr.role_level,
                'squad_id', mr.squad_id,
                'squad_name', mr.squad_name,
                'response_id', mr.response_id
            ) ORDER BY mr.role_list_seq NULLS LAST, mr.role_level, mr.first_name, mr.last_name)
            FROM member_rows mr), '[]'::jsonb)
    ));
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_event_attendance_v3(bigint) TO authenticated;
