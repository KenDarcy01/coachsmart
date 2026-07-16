-- Rewrite get_event_attendance_details(uuid, bigint, int) to inline the
-- view_event_attendance_details CTE logic, then drop the view.
-- Filters pushed into CTEs early for performance.

CREATE OR REPLACE FUNCTION public.get_event_attendance_details(
    p_user_id    uuid,
    p_event_id   bigint,
    p_role_level integer
)
RETURNS TABLE (
    user_id               uuid,
    email_address         character varying,
    user_first_name       character varying,
    user_last_name        character varying,
    full_user_name        text,
    team_id               bigint,
    team_name             character varying,
    event_id              bigint,
    event_title           character varying,
    event_date_time       timestamp without time zone,
    member_id             bigint,
    member_first_name     character varying,
    member_last_name      character varying,
    full_member_name      text,
    role_id               bigint,
    role_name             character varying,
    role_level            smallint,
    role_name_plural      character varying,
    role_grade            smallint,
    role_list_seq         smallint,
    squad_id              bigint,
    squad_name            character varying,
    squad_image           text,
    response_id           bigint,
    attendance_created_at timestamp with time zone,
    response_icon         text,
    display_value         text,
    response_status       text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    RETURN QUERY
    WITH event_team_members_with_squads AS (
        SELECT DISTINCT
            u.user_id,
            u.email_address,
            u.first_name                              AS user_first_name,
            u.last_name                               AS user_last_name,
            (u.first_name || ' ' || u.last_name)     AS full_user_name,
            e.team_id,
            e.event_id,
            e.event_title,
            e.event_date_time,
            m.member_id,
            m.first_name                              AS member_first_name,
            m.last_name                               AS member_last_name,
            (m.first_name || ' ' || m.last_name)     AS full_member_name,
            mtl.squad_id,
            s.squad_name,
            s.squad_image,
            t.team_name
        FROM users u
        JOIN user_member_link uml ON u.user_id  = uml.user_id
        JOIN members m            ON uml.member_id = m.member_id
        JOIN member_team_link mtl ON m.member_id = mtl.member_id
        JOIN teams t              ON mtl.team_id  = t.team_id
        JOIN events e             ON mtl.team_id  = e.team_id
        LEFT JOIN squads s        ON mtl.squad_id = s.squad_id
        WHERE u.user_id  = p_user_id
          AND e.event_id = p_event_id
    ),
    member_event_roles AS (
        SELECT
            etms.user_id,
            etms.event_id,
            etms.member_id,
            mtrl.role_id,
            r.role_name,
            r.role_level,
            r.role_name_plural,
            r.role_grade,
            r.role_list_seq
        FROM event_team_members_with_squads etms
        JOIN member_team_link mtl       ON etms.member_id  = mtl.member_id
                                       AND etms.team_id    = mtl.team_id
        JOIN member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN roles r                    ON mtrl.role_id = r.role_id
    ),
    latest_member_event_attendance AS (
        SELECT
            ea.event_id,
            ea.member_id,
            ea.response_id,
            ert.response_icon,
            ert.display_value,
            ea.created_at AS attendance_created_at,
            ROW_NUMBER() OVER (
                PARTITION BY ea.event_id, ea.member_id
                ORDER BY ea.created_at DESC
            ) AS rn
        FROM event_attendance ea
        LEFT JOIN event_response_type ert ON ea.response_id = ert.response_id
        WHERE ea.event_id = p_event_id
    )
    SELECT
        etms.user_id,
        etms.email_address,
        etms.user_first_name,
        etms.user_last_name,
        etms.full_user_name,
        etms.team_id,
        etms.team_name,
        etms.event_id,
        etms.event_title,
        etms.event_date_time,
        etms.member_id,
        etms.member_first_name,
        etms.member_last_name,
        etms.full_member_name,
        mer.role_id,
        mer.role_name,
        mer.role_level,
        mer.role_name_plural,
        mer.role_grade,
        mer.role_list_seq,
        etms.squad_id,
        etms.squad_name,
        etms.squad_image,
        lmea.response_id,
        lmea.attendance_created_at,
        lmea.response_icon,
        lmea.display_value,
        CASE
            WHEN lmea.response_id IS NULL THEN 'No Response'
            ELSE lmea.display_value
        END AS response_status
    FROM event_team_members_with_squads etms
    JOIN member_event_roles mer
        ON etms.event_id  = mer.event_id
       AND etms.member_id = mer.member_id
       AND etms.user_id   = mer.user_id
    LEFT JOIN latest_member_event_attendance lmea
        ON etms.event_id  = lmea.event_id
       AND etms.member_id = lmea.member_id
       AND lmea.rn = 1
    WHERE mer.role_level = p_role_level
    ORDER BY
        etms.event_date_time DESC,
        etms.event_id,
        etms.user_id,
        etms.squad_name,
        mer.role_list_seq,
        mer.role_grade DESC,
        mer.role_level DESC,
        etms.full_member_name;
END;
$$;

DROP VIEW IF EXISTS public.view_event_attendance_details;
