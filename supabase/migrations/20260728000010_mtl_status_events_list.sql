-- Add mtl.status = 'active' filter to get_events_list all_team_members CTE so soft-deleted team members are excluded from attendance counts.

-- ─── get_events_list (admin) ──────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_events_list(
    p_date_from  text    DEFAULT NULL,
    p_date_to    text    DEFAULT NULL,
    p_team_id    bigint  DEFAULT NULL,
    p_code_id    bigint  DEFAULT NULL,
    p_type_id    bigint  DEFAULT NULL,
    p_opposition text    DEFAULT NULL
)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = 'public'
AS $$

WITH sanitized_filters AS (
    SELECT
        NULLIF(TRIM(p_date_from), '')  AS filter_date_from,
        NULLIF(TRIM(p_date_to), '')    AS filter_date_to,
        NULLIF(p_team_id, 0)           AS filter_team_id,
        NULLIF(p_code_id, 0)           AS filter_code_id,
        NULLIF(p_type_id, 0)           AS filter_type_id,
        NULLIF(TRIM(p_opposition), '') AS filter_opposition
),
filtered_events AS (
    SELECT
        e.*, t.team_name, t.team_female, t.club_id, et.event_type, ec.event_code,
        event_role.role_level AS event_role_level,
        to_char(e.event_date_time::timestamp, 'FMDay, DD Month, YYYY at HH24:MI') AS event_date_time_formatted,
        CASE
            WHEN t.team_female = TRUE AND (
                CASE
                    WHEN e.event_title IS NOT NULL AND TRIM(e.event_title) <> '' THEN e.event_title
                    WHEN et.event_type = 'Match' THEN
                        CASE WHEN e.opposition IS NOT NULL AND TRIM(e.opposition) <> ''
                             THEN CONCAT(COALESCE(ec.event_code,''),' ',et.event_type,' (',e.opposition,')')
                             ELSE CONCAT(COALESCE(ec.event_code,''),' ',et.event_type) END
                    ELSE CONCAT(COALESCE(ec.event_code,''),' ',et.event_type)
                END
            ) LIKE '%Hurling%' THEN
                REPLACE(
                    CASE
                        WHEN e.event_title IS NOT NULL AND TRIM(e.event_title) <> '' THEN e.event_title
                        WHEN et.event_type = 'Match' THEN
                            CASE WHEN e.opposition IS NOT NULL AND TRIM(e.opposition) <> ''
                                 THEN CONCAT(COALESCE(ec.event_code,''),' ',et.event_type,' (',e.opposition,')')
                                 ELSE CONCAT(COALESCE(ec.event_code,''),' ',et.event_type) END
                        ELSE CONCAT(COALESCE(ec.event_code,''),' ',et.event_type)
                    END, 'Hurling', 'Camogie')
            ELSE
                CASE
                    WHEN e.event_title IS NOT NULL AND TRIM(e.event_title) <> '' THEN e.event_title
                    WHEN et.event_type = 'Match' THEN
                        CASE WHEN e.opposition IS NOT NULL AND TRIM(e.opposition) <> ''
                             THEN CONCAT(COALESCE(ec.event_code,''),' ',et.event_type,' (',e.opposition,')')
                             ELSE CONCAT(COALESCE(ec.event_code,''),' ',et.event_type) END
                    ELSE CONCAT(COALESCE(ec.event_code,''),' ',et.event_type)
                END
        END AS effective_event_title
    FROM public.events AS e
    CROSS JOIN sanitized_filters AS sf
    JOIN public.teams AS t ON e.team_id = t.team_id
    JOIN public.event_types AS et ON e.event_type_id = et.event_type_id
    LEFT JOIN public.event_codes AS ec ON e.event_code_id = ec.code_id
    LEFT JOIN public.roles AS event_role ON e.audience_id = event_role.role_id
    WHERE e.event_date_time_2 >= COALESCE(sf.filter_date_from::timestamp with time zone, '1900-01-01'::timestamp with time zone)
      AND e.event_date_time_2 <= COALESCE(sf.filter_date_to::timestamp with time zone,   '2100-01-01'::timestamp with time zone)
      AND (sf.filter_team_id    IS NULL OR e.team_id        = sf.filter_team_id)
      AND (sf.filter_code_id    IS NULL OR e.event_code_id  = sf.filter_code_id)
      AND (sf.filter_type_id    IS NULL OR e.event_type_id  = sf.filter_type_id)
      AND (sf.filter_opposition IS NULL OR e.opposition ILIKE ('%' || sf.filter_opposition || '%'))
      AND e.status != 'deleted'
),
all_team_members AS (
    SELECT fe.event_id, mtl.member_id
    FROM filtered_events AS fe
    JOIN public.member_team_link AS mtl ON fe.team_id = mtl.team_id AND mtl.status = 'active'
    JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.roles AS r_member ON mtrl.role_id = r_member.role_id
    WHERE (
        (fe.event_role_level = 10 AND r_member.role_level = 10)
        OR (fe.event_role_level > 10 AND r_member.role_level >= fe.event_role_level)
    )
      AND (
        fe.squad_id IS NULL
        OR EXISTS (
            SELECT 1 FROM public.member_squad_link msl
            WHERE msl.member_id = mtl.member_id
              AND msl.squad_id  = fe.squad_id
        )
    )
    GROUP BY fe.event_id, mtl.member_id
),
latest_event_attendance AS (
    SELECT DISTINCT ON (ea_sub.member_id, ea_sub.event_id)
        ea_sub.event_id, ea_sub.member_id, ea_sub.response_id, ea_sub.attendance_id
    FROM public.event_attendance AS ea_sub
    JOIN filtered_events AS fe ON ea_sub.event_id = fe.event_id
    JOIN all_team_members AS atm ON ea_sub.member_id = atm.member_id AND ea_sub.event_id = atm.event_id
    ORDER BY ea_sub.member_id, ea_sub.event_id, ea_sub.created_at DESC, ea_sub.attendance_id DESC
),
attendance_summary AS (
    SELECT
        atm.event_id,
        COUNT(CASE WHEN lea.response_id = 3 THEN atm.member_id END) AS accepted_count,
        COUNT(CASE WHEN lea.response_id = 4 THEN atm.member_id END) AS declined_count,
        COUNT(CASE WHEN lea.response_id IS NULL THEN atm.member_id END) AS no_response_count,
        COUNT(atm.member_id) AS total_eligible_members
    FROM all_team_members AS atm
    LEFT JOIN latest_event_attendance AS lea ON atm.member_id = lea.member_id AND atm.event_id = lea.event_id
    GROUP BY atm.event_id
)
SELECT
    COALESCE(json_agg(final_result)::jsonb, '[]'::jsonb)
FROM (
    SELECT
        fe.event_id, fe.effective_event_title AS event_title, fe.meet_time,
        fe.event_date_time_formatted, fe.team_name, fe.team_id, fe.club_id,
        fe.status AS event_status,
        fe.request_attendance, fe.event_type, fe.event_link, fe.event_code,
        fe.location_name, fe.location_pin, fe.opposition, fe.event_details,
        fe.home_away, fe.created_by,
        CONCAT(u.first_name, ' ', u.last_name) AS created_by_user_name,
        u.phone_number AS created_by_phone_number,
        COALESCE(asum.accepted_count, 0) AS accepted_count,
        COALESCE(asum.declined_count, 0) AS declined_count,
        COALESCE(asum.no_response_count, 0) AS no_response_count,
        COALESCE(asum.total_eligible_members, 0) AS total_eligible_members,
        fe.notify_admins_changes, fe.notify_admins_all
    FROM filtered_events AS fe
    LEFT JOIN public.users AS u ON fe.created_by = u.user_id
    LEFT JOIN attendance_summary AS asum ON fe.event_id = asum.event_id
    ORDER BY fe.event_date_time DESC
) AS final_result;
$$;
