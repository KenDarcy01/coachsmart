-- Update the squads subquery in get_user_event_create_detail and
-- get_user_event_edit_detail to:
--   1. Include squad_list_seq in every squad object.
--   2. Prepend a sentinel "All Members" row (id = NULL, squad_list_seq = 0)
--      so FlutterFlow can offer whole-team visibility without special-casing NULL.
-- Results are ordered by squad_list_seq so "All Members" always appears first.

-- ─── get_user_event_create_detail ────────────────────────────────────────────

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
    JOIN public.member_team_link mtl ON m.member_id = mtl.member_id
    WHERE m.user_id = p_user_id;

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
                    (SELECT jsonb_agg(squad_row ORDER BY seq)
                     FROM (
                         SELECT jsonb_build_object(
                             'id',             NULL,
                             'name',           'All Members',
                             'image',          NULL,
                             'squad_list_seq', 0
                         ) AS squad_row, 0 AS seq
                         UNION ALL
                         SELECT jsonb_build_object(
                             'id',             s.squad_id,
                             'name',           s.squad_name,
                             'image',          s.squad_image,
                             'squad_list_seq', s.squad_list_seq
                         ), s.squad_list_seq
                         FROM public.squads s
                         WHERE s.team_id = t.team_id
                     ) sq_data(squad_row, seq)
                    ) AS squads
                FROM public.members m
                JOIN public.member_team_link mtl ON m.member_id = mtl.member_id
                JOIN public.teams t ON mtl.team_id = t.team_id
                LEFT JOIN public.clubs c ON t.club_id = c.club_id
                JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
                JOIN public.roles r ON mtrl.role_id = r.role_id
                WHERE m.user_id = p_user_id AND r.role_grade = 100
                ORDER BY t.team_id, r.role_level DESC
            ) team_data
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$;


-- ─── get_user_event_edit_detail ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_user_event_edit_detail(
    p_user_id  uuid,
    p_event_id bigint DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_result          jsonb;
    v_default_team_id bigint;
    v_current_event   jsonb;
BEGIN
    SELECT
        CASE WHEN COUNT(DISTINCT mtl.team_id) = 1 THEN MAX(mtl.team_id) ELSE NULL END
    INTO v_default_team_id
    FROM public.members m
    JOIN public.member_team_link mtl ON m.member_id = mtl.member_id
    WHERE m.user_id = p_user_id;

    IF p_event_id IS NOT NULL THEN
        SELECT jsonb_build_object(
            'event_id',          e.event_id,
            'event_title',       e.event_title,
            'event_type_id',     e.event_type_id,
            'event_date_time',   e.event_date_time_2,
            'meet_time',         e.meet_time,
            'event_code_id',     e.event_code_id,
            'opposition',        e.opposition,
            'home_away',         e.home_away,
            'location_name',     e.location_name,
            'location_pin',      e.location_pin,
            'event_link',        e.event_link,
            'audience_id',       e.audience_id,
            'request_attendance',e.request_attendance,
            'event_details',     e.event_details,
            'team_id',           e.team_id,
            'event_image',       e.event_image,
            'payment_required',  e.payment_required,
            'payment_amount',    e.payment_amount,
            'squad_id',          e.squad_id,
            'status',            e.status
        ) INTO v_current_event
        FROM public.events e
        WHERE e.event_id = p_event_id;
    END IF;

    SELECT jsonb_build_object(
        'user_id',         p_user_id,
        'default_team_id', v_default_team_id,
        'current_event',   v_current_event,
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
                    (SELECT jsonb_agg(squad_row ORDER BY seq)
                     FROM (
                         SELECT jsonb_build_object(
                             'id',             NULL,
                             'name',           'All Members',
                             'image',          NULL,
                             'squad_list_seq', 0
                         ) AS squad_row, 0 AS seq
                         UNION ALL
                         SELECT jsonb_build_object(
                             'id',             s.squad_id,
                             'name',           s.squad_name,
                             'image',          s.squad_image,
                             'squad_list_seq', s.squad_list_seq
                         ), s.squad_list_seq
                         FROM public.squads s
                         WHERE s.team_id = t.team_id
                     ) sq_data(squad_row, seq)
                    ) AS squads
                FROM public.members m
                JOIN public.member_team_link mtl ON m.member_id = mtl.member_id
                JOIN public.teams t ON mtl.team_id = t.team_id
                LEFT JOIN public.clubs c ON t.club_id = c.club_id
                JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
                JOIN public.roles r ON mtrl.role_id = r.role_id
                WHERE m.user_id = p_user_id AND r.role_grade = 100
                ORDER BY t.team_id, r.role_level DESC
            ) team_data
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$;
