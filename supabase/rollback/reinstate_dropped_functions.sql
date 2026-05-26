-- =============================================================================
-- ROLLBACK SCRIPT: Reinstate functions dropped in migration
--                  20260526120000_drop_safe_deprecated_functions.sql
--
-- HOW TO USE: Only run this if you need to reverse the drop migration.
--   1. Copy this file into supabase/migrations/ with a new timestamp
--   2. Run: supabase db push
--   OR run directly against the database:
--      psql $DATABASE_URL -f reinstate_dropped_functions.sql
--
-- NOTE: get_event_attendance_details(uuid, bigint, integer) returns
--       SETOF view_event_attendance_details. If the view has also been
--       dropped by then, that function cannot be reinstated until the
--       view is recreated first.
-- =============================================================================


-- 1. get_unresponded_events() — no params, legacy attendees table
CREATE OR REPLACE FUNCTION "public"."get_unresponded_events"()
RETURNS TABLE("id" "uuid", "email_address" "text", "event_name" "text", "event_date_time" timestamp with time zone)
LANGUAGE "plpgsql"
AS $$
BEGIN
RETURN QUERY
SELECT
a.id,
a.email_address,
e.name AS event_name,
e.date_time AS event_date_time
FROM
attendees a
JOIN
events e ON a.event_id = e.id
WHERE
a.status = 'unresponded'
AND e.date_time > NOW();
END;
$$;

ALTER FUNCTION "public"."get_unresponded_events"() OWNER TO "postgres";


-- 2. get_unresponded_events(_event_id uuid) — legacy attendees table
CREATE OR REPLACE FUNCTION "public"."get_unresponded_events"("_event_id" "uuid")
RETURNS TABLE("id" "uuid", "email_address" "text", "event_name" "text", "event_date_time" timestamp with time zone)
LANGUAGE "plpgsql"
AS $$
BEGIN
  RETURN QUERY
  SELECT
    a.id,
    a.email_address,
    e.name AS event_name,
    e.date_time AS event_date_time
  FROM
    attendees a
  JOIN
    events e ON a.event_id = e.id
  WHERE
    a.event_id = _event_id
    AND a.status = 'unresponded'
    AND e.date_time > NOW();
END;
$$;

ALTER FUNCTION "public"."get_unresponded_events"("_event_id" "uuid") OWNER TO "postgres";


-- 3. get_event_attendance_details(p_event_id bigint) — returns jsonb, never invoked
CREATE OR REPLACE FUNCTION "public"."get_event_attendance_details"("p_event_id" bigint)
RETURNS "jsonb"
LANGUAGE "plpgsql" SECURITY DEFINER
AS $$
BEGIN
    RETURN (
        WITH
        event_config AS (
            SELECT
                e.event_id,
                e.team_id,
                e.event_title,
                e.event_date_time,
                e.event_code_id,
                t.team_name
            FROM public.events e
            JOIN public.teams t ON e.team_id = t.team_id
            WHERE e.event_id = p_event_id
        ),
        latest_accepted_only AS (
            SELECT DISTINCT ON (ea.member_id)
                ea.member_id,
                ea.response_id,
                ea.created_at
            FROM public.event_attendance ea
            WHERE ea.event_id = p_event_id
            ORDER BY ea.member_id, ea.created_at DESC
        ),
        member_details AS (
            SELECT DISTINCT ON (m.member_id)
                u.user_id,
                u.first_name || ' ' || u.last_name AS full_user_name,
                m.member_id,
                m.first_name || ' ' || m.last_name AS full_member_name,
                CASE WHEN s.team_id = ec.team_id THEN s.squad_id ELSE NULL END as squad_id,
                CASE WHEN s.team_id = ec.team_id THEN s.squad_name ELSE NULL END as squad_name,
                CASE WHEN s.team_id = ec.team_id THEN s.squad_image ELSE NULL END as squad_image,
                CASE WHEN sq_code.team_id = ec.team_id THEN msl.squad_id ELSE NULL END AS squad_code_id,
                CASE WHEN sq_code.team_id = ec.team_id THEN sq_code.squad_name ELSE NULL END AS squad_code_name,
                CASE WHEN sq_code.team_id = ec.team_id THEN sq_code.squad_image ELSE NULL END AS squad_code_image,
                r.role_id,
                r.role_name,
                r.role_list_seq,
                ert.response_icon,
                ert.display_value AS response_status,
                la.created_at AS attendance_date
            FROM event_config ec
            JOIN latest_accepted_only la ON la.response_id = 3
            JOIN public.members m ON la.member_id = m.member_id
            JOIN public.member_team_link mtl ON m.member_id = mtl.member_id AND mtl.team_id = ec.team_id
            JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
            JOIN public.roles r ON mtrl.role_id = r.role_id
            JOIN public.user_member_link uml ON m.member_id = uml.member_id
            JOIN public.users u ON uml.user_id = u.user_id
            JOIN public.event_response_type ert ON la.response_id = ert.response_id
            LEFT JOIN public.squads s ON mtl.squad_id = s.squad_id AND s.team_id = ec.team_id
            LEFT JOIN public.member_squad_link msl ON m.member_id = msl.member_id AND msl.code_id = ec.event_code_id AND msl.team_id = ec.team_id
            LEFT JOIN public.squads sq_code ON msl.squad_id = sq_code.squad_id AND sq_code.team_id = ec.team_id
            ORDER BY m.member_id, r.role_list_seq ASC
        )
        SELECT
            jsonb_build_object(
                'event_id', ec.event_id,
                'event_title', ec.event_title,
                'team_name', ec.team_name,
                'accepted_count', (SELECT count(*) FROM member_details),
                'attendees', COALESCE((
                    SELECT jsonb_agg(attendee_row ORDER BY role_list_seq ASC, full_member_name ASC)
                    FROM (
                        SELECT
                            md.user_id, md.full_user_name, md.member_id, md.full_member_name,
                            md.squad_id, md.squad_name, md.squad_image,
                            md.squad_code_id, md.squad_code_name, md.squad_code_image,
                            md.role_id, md.role_name, md.role_list_seq,
                            md.response_status AS status, md.response_icon AS icon, md.attendance_date
                        FROM member_details md
                    ) attendee_row
                ), '[]'::jsonb)
            )
        FROM event_config ec
    );
END;
$$;

ALTER FUNCTION "public"."get_event_attendance_details"("p_event_id" bigint) OWNER TO "postgres";


-- 4. get_event_attendance_details(p_user_id uuid, p_event_id bigint, p_role_level integer)
--    CAUTION: requires view_event_attendance_details to exist first
CREATE OR REPLACE FUNCTION "public"."get_event_attendance_details"("p_user_id" "uuid", "p_event_id" bigint, "p_role_level" integer)
RETURNS SETOF "public"."view_event_attendance_details"
LANGUAGE "plpgsql" STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM public.view_event_attendance_details
    WHERE
        view_event_attendance_details.user_id = p_user_id AND
        view_event_attendance_details.event_id = p_event_id AND
        view_event_attendance_details.role_level = p_role_level
    ORDER BY
        view_event_attendance_details.event_date_time DESC,
        view_event_attendance_details.event_id,
        view_event_attendance_details.user_id,
        view_event_attendance_details.squad_name,
        view_event_attendance_details.role_list_seq,
        view_event_attendance_details.role_grade DESC,
        view_event_attendance_details.role_level DESC,
        view_event_attendance_details.full_member_name;
END;
$$;

ALTER FUNCTION "public"."get_event_attendance_details"("p_user_id" "uuid", "p_event_id" bigint, "p_role_level" integer) OWNER TO "postgres";


-- 5. get_event_attendance_summary(p_event_id integer, p_role_level integer) — old superseded version
CREATE OR REPLACE FUNCTION "public"."get_event_attendance_summary"("p_event_id" integer, "p_role_level" integer)
RETURNS TABLE("event_id" bigint, "event_title" character varying, "event_date_time" timestamp without time zone, "meet_time" "text", "opposition" character varying, "location_name" character varying, "team_id" bigint, "team_name" character varying, "role_id" bigint, "role_name" character varying, "role_level" smallint, "role_grade" smallint, "role_name_plural" character varying, "role_list_seq" smallint, "accepted_attendees_count" bigint, "declined_attendees_count" bigint, "no_response_count" bigint)
LANGUAGE "plpgsql"
AS $$
begin
    return query
    with
    actual_member_roles_for_event as (
        select distinct
            e.event_id,
            mtl.member_id,
            mtrl.role_id
        from
            events e
            join member_team_link mtl on e.team_id = mtl.team_id
            and e.event_id = p_event_id
            join members m on mtl.member_id = m.member_id
            join member_team_role_link mtrl on mtl.member_team_id = mtrl.member_team_id
            join team_roles_link trl on mtl.team_id = trl.team_id and mtrl.role_id = trl.role_id
    ),
    latest_event_attendance as (
        select
            distinct on (ea.event_id, ea.member_id)
            ea.event_id,
            ea.member_id,
            ea.response_id
        from
            event_attendance ea
        where
            ea.event_id = p_event_id
        order by
            ea.event_id, ea.member_id, ea.created_at desc
    )
    select
        aetr.event_id,
        aetr.event_title::character varying,
        aetr.event_date_time::timestamp without time zone,
        aetr.meet_time,
        aetr.opposition::character varying,
        aetr.location_name::character varying,
        aetr.team_id,
        aetr.team_name::character varying,
        aetr.role_id,
        aetr.role_name::character varying,
        aetr.role_level,
        aetr.role_grade,
        aetr.role_name_plural::character varying,
        aetr.role_list_seq,
        coalesce(sum(case when lea.response_id = 3 then 1 else 0 end), 0::bigint) as accepted_attendees_count,
        coalesce(sum(case when lea.response_id = 4 then 1 else 0 end), 0::bigint) as declined_attendees_count,
        coalesce(sum(case when lea.response_id is null and amr.member_id is not null then 1 else 0 end), 0::bigint) as no_response_count
    from
        (
            select e.event_id, e.event_title, e.event_date_time, e.meet_time, e.opposition,
                   e.location_name, t.team_id, t.team_name, r.role_id, r.role_name,
                   r.role_level, r.role_grade, r.role_name_plural, r.role_list_seq
            from events e
            join teams t on e.team_id = t.team_id
            join team_roles_link trl on t.team_id = trl.team_id
            join roles r on trl.role_id = r.role_id
            where e.event_id = p_event_id and r.role_level = p_role_level
        ) aetr
        left join actual_member_roles_for_event amr on aetr.event_id = amr.event_id and aetr.role_id = amr.role_id
        left join latest_event_attendance lea on amr.event_id = lea.event_id and amr.member_id = lea.member_id
    group by
        aetr.event_id, aetr.event_title, aetr.event_date_time, aetr.meet_time, aetr.opposition,
        aetr.location_name, aetr.team_id, aetr.team_name, aetr.role_id, aetr.role_name,
        aetr.role_level, aetr.role_grade, aetr.role_name_plural, aetr.role_list_seq
    order by
        aetr.event_date_time desc, aetr.role_list_seq, aetr.role_grade desc, aetr.role_level desc;
end;
$$;

ALTER FUNCTION "public"."get_event_attendance_summary"("p_event_id" integer, "p_role_level" integer) OWNER TO "postgres";


-- 6. get_event_attendance_summary_by_role_and_squad(...) v1 — superseded by v2
CREATE OR REPLACE FUNCTION "public"."get_event_attendance_summary_by_role_and_squad"("p_event_id" bigint, "p_role_grade_filter" smallint DEFAULT NULL::smallint, "p_role_level_filter" smallint DEFAULT NULL::smallint, "p_role_level_exclude" smallint DEFAULT NULL::smallint, "p_response_id" bigint DEFAULT NULL::bigint)
RETURNS "jsonb"
LANGUAGE "plpgsql" SECURITY DEFINER
AS $$
DECLARE
    v_event_code_id bigint;
    v_team_id bigint;
BEGIN
    SELECT event_code_id, team_id INTO v_event_code_id, v_team_id
    FROM public.events WHERE event_id = p_event_id;

    RETURN (
    WITH
    latest_event_attendance AS (
        SELECT DISTINCT ON (ea.event_id, ea.member_id) ea.event_id, ea.member_id, ea.response_id
        FROM public.event_attendance ea WHERE ea.event_id = p_event_id
        ORDER BY ea.event_id, ea.member_id, ea.created_at DESC
    ),
    traditional_members AS (
        SELECT DISTINCT mtl.member_id, mtl.squad_id FROM public.member_team_link mtl
        WHERE mtl.team_id = v_team_id AND mtl.squad_id IS NOT NULL
    ),
    code_based_members AS (
        SELECT DISTINCT msl.member_id, msl.squad_id FROM public.member_squad_link msl
        WHERE msl.code_id = v_event_code_id AND msl.team_id = v_team_id AND msl.squad_id IS NOT NULL
    ),
    traditional_member_roles AS (
        SELECT DISTINCT tm.member_id, tm.squad_id, mtrl.role_id
        FROM traditional_members tm
        JOIN public.member_team_link mtl ON tm.member_id = mtl.member_id AND mtl.team_id = v_team_id
        JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
    ),
    code_based_member_roles AS (
        SELECT DISTINCT cbm.member_id, cbm.squad_id, mtrl.role_id
        FROM code_based_members cbm
        JOIN public.member_team_link mtl ON cbm.member_id = mtl.member_id AND mtl.team_id = v_team_id
        JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
    ),
    all_squad_roles_for_event AS (
        SELECT e.event_id, sq.squad_id, sq.squad_name, sq.grade, sq.squad_image, sq.squad_list_seq,
               r.role_id, r.role_name, r.role_level, r.role_grade, r.role_name_plural, r.role_list_seq
        FROM events e
        JOIN public.teams t ON e.team_id = t.team_id
        JOIN public.squads sq ON t.team_id = sq.team_id
        JOIN public.team_roles_link trl ON t.team_id = trl.team_id
        JOIN public.roles r ON trl.role_id = r.role_id
        WHERE e.event_id = p_event_id
          AND (p_role_grade_filter IS NULL OR p_role_grade_filter = 0 OR r.role_grade = p_role_grade_filter)
          AND (p_role_level_filter IS NULL OR p_role_level_filter = 0 OR r.role_level >= p_role_level_filter)
          AND (p_role_level_exclude IS NULL OR r.role_level != p_role_level_exclude)
    ),
    member_status_data_traditional AS (
        SELECT tmr.squad_id, tmr.role_id, tmr.member_id, lea.response_id,
            CASE WHEN lea.response_id = 3 THEN 'accepted' WHEN lea.response_id = 4 THEN 'declined'
                 WHEN lea.response_id IS NULL THEN 'no_response' ELSE 'irrelevant' END AS attendance_status
        FROM traditional_member_roles tmr
        LEFT JOIN latest_event_attendance lea ON p_event_id = lea.event_id AND tmr.member_id = lea.member_id
    ),
    member_status_data_code_based AS (
        SELECT cbmr.squad_id, cbmr.role_id, cbmr.member_id, lea.response_id,
            CASE WHEN lea.response_id = 3 THEN 'accepted' WHEN lea.response_id = 4 THEN 'declined'
                 WHEN lea.response_id IS NULL THEN 'no_response' ELSE 'irrelevant' END AS attendance_status
        FROM code_based_member_roles cbmr
        LEFT JOIN latest_event_attendance lea ON p_event_id = lea.event_id AND cbmr.member_id = lea.member_id
    ),
    squad_role_level_count AS (
        SELECT msd_trad.squad_id, r.role_level, COUNT(DISTINCT msd_trad.member_id) AS role_level_count
        FROM member_status_data_traditional msd_trad
        JOIN public.roles r ON msd_trad.role_id = r.role_id
        WHERE CASE WHEN p_response_id = 3 THEN msd_trad.response_id = 3
                   WHEN p_response_id = 4 THEN msd_trad.response_id = 4
                   ELSE msd_trad.response_id IS NULL END
        GROUP BY msd_trad.squad_id, r.role_level
    ),
    roles_with_counts AS (
        SELECT r.event_id, r.squad_id, r.squad_name, r.grade, r.squad_image, r.squad_list_seq,
               r.role_id, r.role_name, r.role_list_seq, r.role_grade, r.role_level, r.role_name_plural,
            COUNT(DISTINCT msd_trad.member_id) FILTER (WHERE CASE WHEN p_response_id = 3 THEN msd_trad.attendance_status = 'accepted' WHEN p_response_id = 4 THEN msd_trad.attendance_status = 'declined' ELSE msd_trad.attendance_status = 'no_response' END) AS member_count,
            COUNT(DISTINCT msd_code.member_id) FILTER (WHERE CASE WHEN p_response_id = 3 THEN msd_code.attendance_status = 'accepted' WHEN p_response_id = 4 THEN msd_code.attendance_status = 'declined' ELSE msd_code.attendance_status = 'no_response' END) AS squad_code_count,
            COUNT(DISTINCT msd_code.member_id) AS member_role_count
        FROM all_squad_roles_for_event r
        LEFT JOIN member_status_data_traditional msd_trad ON r.squad_id = msd_trad.squad_id AND r.role_id = msd_trad.role_id
        LEFT JOIN member_status_data_code_based msd_code ON r.squad_id = msd_code.squad_id AND r.role_id = msd_code.role_id
        GROUP BY r.event_id, r.squad_id, r.squad_name, r.grade, r.squad_image, r.squad_list_seq,
                 r.role_id, r.role_name, r.role_list_seq, r.role_grade, r.role_level, r.role_name_plural
    ),
    squads_with_roles AS (
        SELECT rwc.event_id, rwc.squad_id, rwc.squad_name, rwc.grade, rwc.squad_image, rwc.squad_list_seq,
            COALESCE((SELECT role_level_count FROM squad_role_level_count srlc WHERE srlc.squad_id = rwc.squad_id AND srlc.role_level = p_role_level_filter), 0) AS role_level_count,
            jsonb_agg(jsonb_build_object('role_id', rwc.role_id, 'role_name', rwc.role_name, 'role_name_plural', rwc.role_name_plural, 'role_list_seq', rwc.role_list_seq, 'role_grade', rwc.role_grade, 'role_level', rwc.role_level, 'member_count', rwc.member_count, 'squad_code_count', rwc.squad_code_count, 'member_role_count', rwc.member_role_count) ORDER BY rwc.role_list_seq, rwc.role_grade DESC, rwc.role_level DESC) AS roles_list
        FROM roles_with_counts rwc
        GROUP BY rwc.event_id, rwc.squad_id, rwc.squad_name, rwc.grade, rwc.squad_image, rwc.squad_list_seq
    )
    SELECT jsonb_build_object(
        'event_id', sq.event_id,
        'team_name', (SELECT t.team_name FROM public.events e JOIN public.teams t ON e.team_id = t.team_id WHERE e.event_id = p_event_id LIMIT 1),
        'response_id', p_response_id,
        'squads', jsonb_agg(jsonb_build_object('squad_id', sq.squad_id, 'squad_name', sq.squad_name, 'squad_grade', sq.grade, 'squad_image', sq.squad_image, 'role_level_count', sq.role_level_count, 'roles', sq.roles_list) ORDER BY sq.squad_list_seq, sq.grade, sq.squad_name)
    )
    FROM squads_with_roles sq GROUP BY sq.event_id
    );
END;
$$;

ALTER FUNCTION "public"."get_event_attendance_summary_by_role_and_squad"("p_event_id" bigint, "p_role_grade_filter" smallint, "p_role_level_filter" smallint, "p_role_level_exclude" smallint, "p_response_id" bigint) OWNER TO "postgres";


-- 7. get_event_payments_details(p_event_id bigint) — old, missing member columns
CREATE OR REPLACE FUNCTION "public"."get_event_payments_details"("p_event_id" bigint)
RETURNS TABLE("user_full_name" "text", "payment_date" "text", "payment_id" bigint, "event_id" bigint, "user_id" "uuid", "event_title" "text", "stripe_session_id" "text", "payment_status" "text", "amount_paid" integer, "stripe_payment_intent_id" "text", "stripe_checkout_url" "text", "fee_amount" smallint, "net_amount" smallint, "tax_amount" smallint, "gross_amount" smallint)
LANGUAGE "sql"
AS $$
    SELECT
        u.first_name || ' ' || u.last_name AS user_full_name,
        TO_CHAR(eup.created_at, 'DD Mon YYYY') AS payment_date,
        eup.payment_id, eup.event_id, eup.user_id, eup.event_title, eup.stripe_session_id,
        eup.payment_status, eup.amount_paid, eup.stripe_payment_intent_id, eup.stripe_checkout_url,
        eup.fee_amount, eup.net_amount, eup.tax_amount, eup.gross_amount
    FROM public.event_user_payment eup
    JOIN public.users u ON eup.user_id = u.user_id
    WHERE eup.event_id = p_event_id AND eup.payment_status = 'confirmed';
$$;

ALTER FUNCTION "public"."get_event_payments_details"("p_event_id" bigint) OWNER TO "postgres";


-- 8. get_members_attendance_for_event — exact duplicate of get_event_team_members_with_attendance
CREATE OR REPLACE FUNCTION "public"."get_members_attendance_for_event"("p_event_id" bigint, "p_user_id" "uuid")
RETURNS TABLE("member_id" bigint, "first_name" "text", "last_name" "text", "profile_pic" "text", "response_value" "text", "response_icon" "text", "display_value" "text", "icon_link" "text")
LANGUAGE "plpgsql"
AS $$
BEGIN
    RETURN QUERY
    SELECT m.member_id, m.first_name, m.last_name, m.profile_pic,
           ert.response_value, ert.response_icon, ert.display_value, ert.icon_link
    FROM public.events AS e
    INNER JOIN public.member_team_link AS mtl ON e.team_id = mtl.team_id
    INNER JOIN public.members AS m ON mtl.member_id = m.member_id
    INNER JOIN public.user_member_link AS uml ON m.member_id = uml.member_id
    LEFT JOIN (
        SELECT event_attendance.member_id, event_attendance.response_id,
               ROW_NUMBER() OVER(PARTITION BY event_attendance.member_id ORDER BY event_attendance.created_at DESC) as rn
        FROM public.event_attendance WHERE event_attendance.event_id = p_event_id
    ) AS ea ON m.member_id = ea.member_id AND ea.rn = 1
    LEFT JOIN public.event_response_type AS ert ON ea.response_id = ert.response_id
    WHERE e.event_id = p_event_id AND uml.user_id = p_user_id;
END;
$$;

ALTER FUNCTION "public"."get_members_attendance_for_event"("p_event_id" bigint, "p_user_id" "uuid") OWNER TO "postgres";


-- 9. get_user_events(user_id_param uuid) — older version, superseded by get_user_home_events
CREATE OR REPLACE FUNCTION "public"."get_user_events"("user_id_param" "uuid")
RETURNS "jsonb"
LANGUAGE "sql" SECURITY DEFINER
AS $$
WITH user_roles AS (
    SELECT mtl.team_id, MAX(r.role_level) AS user_highest_role_on_team
    FROM public.user_member_link AS uml
    JOIN public.member_team_link AS mtl ON uml.member_id = mtl.member_id
    JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.roles AS r ON mtrl.role_id = r.role_id
    WHERE uml.user_id = user_id_param
    GROUP BY mtl.team_id
),
user_max_any_role AS (
    SELECT MAX(user_highest_role_on_team) AS user_highest_role_on_any_team FROM user_roles
),
upcoming_events AS (
    SELECT e.*, t.team_name, t.team_female, t.club_id, et.event_type, ec.event_code,
        event_role.role_level AS event_role_level,
        to_char(e.event_date_time::timestamp, 'FMDay, DD Month, YYYY at HH24:MI') AS event_date_time_formatted,
        CASE
            WHEN t.team_female = TRUE AND e.event_title LIKE 'Hurling%' THEN
                CASE WHEN et.event_type = 'Match' THEN CONCAT(REPLACE(e.event_title, 'Hurling', 'Camogie'), ' (', e.opposition, ')')
                     ELSE REPLACE(e.event_title, 'Hurling', 'Camogie') END
            WHEN et.event_type = 'Match' THEN CONCAT(e.event_title, ' (', e.opposition, ')')
            ELSE e.event_title
        END AS effective_event_title
    FROM public.events AS e
    JOIN public.teams AS t ON e.team_id = t.team_id
    JOIN public.event_types AS et ON e.event_type_id = et.event_type_id
    LEFT JOIN public.event_codes AS ec ON e.event_code_id = ec.code_id
    LEFT JOIN public.roles AS event_role ON e.audience_id = event_role.role_id
    WHERE e.event_date_time >= CURRENT_DATE AND e.team_id IN (SELECT ur.team_id FROM user_roles ur)
),
relevant_member AS (
    SELECT DISTINCT ON (ue.event_id)
        ue.event_id, m.member_id, m.first_name AS member_first_name, m.last_name AS member_last_name,
        r.role_level AS member_role_level, ue.event_role_level
    FROM upcoming_events AS ue
    JOIN public.user_member_link AS uml ON uml.user_id = user_id_param
    JOIN public.members AS m ON uml.member_id = m.member_id
    JOIN public.member_team_link AS mtl ON m.member_id = mtl.member_id AND mtl.team_id = ue.team_id
    LEFT JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
    LEFT JOIN public.roles AS r ON mtrl.role_id = r.role_id
    WHERE r.role_level >= ue.event_role_level
    ORDER BY ue.event_id, r.role_level ASC, m.member_id ASC
),
all_team_members AS (
    SELECT ue.event_id, mtl.member_id
    FROM upcoming_events AS ue
    JOIN public.member_team_link AS mtl ON ue.team_id = mtl.team_id
    JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.roles AS r_member ON mtrl.role_id = r_member.role_id
    WHERE (ue.event_role_level = 10 AND r_member.role_level = 10)
       OR (ue.event_role_level > 10 AND r_member.role_level >= ue.event_role_level)
    GROUP BY ue.event_id, mtl.member_id
),
latest_event_attendance AS (
    SELECT DISTINCT ON (ea_sub.member_id, ea_sub.event_id)
        ea_sub.event_id, ea_sub.member_id, ea_sub.response_id, ea_sub.attendance_id
    FROM public.event_attendance AS ea_sub
    JOIN upcoming_events AS ue ON ea_sub.event_id = ue.event_id
    JOIN all_team_members AS atm ON ea_sub.member_id = atm.member_id AND ea_sub.event_id = atm.event_id
    ORDER BY ea_sub.member_id, ea_sub.event_id, ea_sub.created_at DESC, ea_sub.attendance_id DESC
),
attendance_summary AS (
    SELECT atm.event_id,
        COUNT(CASE WHEN lea.response_id = 3 THEN atm.member_id END) AS accepted_count,
        COUNT(CASE WHEN lea.response_id = 4 THEN atm.member_id END) AS declined_count,
        COUNT(CASE WHEN lea.response_id IS NULL THEN atm.member_id END) AS no_response_count
    FROM all_team_members AS atm
    LEFT JOIN latest_event_attendance AS lea ON atm.member_id = lea.member_id AND atm.event_id = lea.event_id
    GROUP BY atm.event_id
)
SELECT COALESCE(json_agg(final_result)::jsonb, '[]'::jsonb)
FROM (
    SELECT ue.event_id, ue.effective_event_title AS event_title, ue.meet_time, ue.event_date_time_formatted,
        ue.team_name, ue.team_id, ue.club_id, rm.member_id, lea_user.attendance_id,
        ert.display_value AS attendance_status, ert.icon_link AS attendance_icon, lea_user.response_id,
        ue.request_attendance, ue.event_type, ue.event_link, ue.event_code, ue.location_name,
        ue.location_pin, ue.opposition, ue.event_details, ue.home_away, ue.created_by,
        CONCAT(u.first_name, ' ', u.last_name) AS created_by_user_name,
        u.phone_number AS created_by_phone_number, rm.member_first_name, rm.member_last_name,
        rm.member_role_level, rm.event_role_level,
        COALESCE(asum.accepted_count, 0) AS accepted_count,
        COALESCE(asum.declined_count, 0) AS declined_count,
        COALESCE(asum.no_response_count, 0) AS no_response_count,
        ur.user_highest_role_on_team, umr.user_highest_role_on_any_team,
        ue.notify_admins_changes, ue.notify_admins_all
    FROM upcoming_events AS ue
    LEFT JOIN user_roles AS ur ON ue.team_id = ur.team_id
    CROSS JOIN user_max_any_role AS umr
    LEFT JOIN public.users AS u ON ue.created_by = u.user_id
    LEFT JOIN relevant_member AS rm ON ue.event_id = rm.event_id
    LEFT JOIN latest_event_attendance AS lea_user ON lea_user.member_id = rm.member_id AND lea_user.event_id = ue.event_id
    LEFT JOIN public.event_response_type AS ert ON lea_user.response_id = ert.response_id
    LEFT JOIN attendance_summary AS asum ON ue.event_id = asum.event_id
    WHERE rm.member_id IS NOT NULL
    ORDER BY ue.event_date_time ASC
) AS final_result;
$$;

ALTER FUNCTION "public"."get_user_events"("user_id_param" "uuid") OWNER TO "postgres";


-- 10. get_user_teams_debug(user_id_param uuid) — dev/debug function, no SECURITY DEFINER
CREATE OR REPLACE FUNCTION "public"."get_user_teams_debug"("user_id_param" "uuid")
RETURNS TABLE("team_id" bigint, "team_name" "text")
LANGUAGE "sql"
AS $$
SELECT DISTINCT t.team_id, t.team_name
FROM public.user_member_link AS uml
JOIN public.member_team_link AS mtl ON uml.member_id = mtl.member_id
JOIN public.teams AS t ON mtl.team_id = t.team_id
WHERE uml.user_id = user_id_param;
$$;

ALTER FUNCTION "public"."get_user_teams_debug"("user_id_param" "uuid") OWNER TO "postgres";
