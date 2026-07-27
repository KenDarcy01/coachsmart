


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";






CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgsodium";








ALTER SCHEMA "public" OWNER TO "postgres";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "hypopg" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "index_advisor" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."check_and_send_notifications"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_signing_secret text;
  v_jwt            text;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.notifications WHERE is_delivered = false
  ) THEN
    RETURN;
  END IF;

  SELECT decrypted_secret
  INTO v_signing_secret
  FROM vault.decrypted_secrets
  WHERE name = 'jwt_signing_secret'
  LIMIT 1;

  IF v_signing_secret IS NULL THEN
    RAISE WARNING 'check_and_send_notifications: jwt_signing_secret not found in vault — aborting';
    RETURN;
  END IF;

  SELECT extensions.sign(
    json_build_object(
      'role', 'service_role',
      'iss',  'supabase',
      'ref',  'gyfporsbdftvtakdvukt',
      'iat',  extract(epoch from now())::integer,
      'exp',  (extract(epoch from now()) + 3600)::integer
    )::json,
    v_signing_secret
  ) INTO v_jwt;

  PERFORM net.http_post(
    url     := 'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/cron_batch_notification_send',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_jwt
    ),
    body    := '{}'::jsonb
  );
END;
$$;


ALTER FUNCTION "public"."check_and_send_notifications"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_match_squad_from_attendance"("p_event_id" bigint, "p_user_id" "uuid") RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_new_match_squad_id int8;
    v_team_id int8;
    v_lookup_code_id int8;
    v_member_record RECORD;
    v_squad_id_final int8;
BEGIN
    -- 1. Identify Team context
    SELECT e.team_id
    INTO v_team_id
    FROM public.events e
    WHERE e.event_id = p_event_id;

    -- 2. Use the helper function to determine the correct event code
    v_lookup_code_id := public.get_updated_event_code(p_event_id);

    -- 3. Create the parent Match Squad record
    INSERT INTO public.match_squads (event_id, user_id)
    VALUES (p_event_id, p_user_id)
    RETURNING match_squad_id INTO v_new_match_squad_id;

    -- 4. Loop through the MOST RECENT response for members with role_grade = 10
    FOR v_member_record IN 
        SELECT DISTINCT ON (ea.member_id) 
            ea.member_id, 
            ea.response_id,
            mtrl.role_id
        FROM public.event_attendance ea
        INNER JOIN public.member_team_link mtl ON (ea.member_id = mtl.member_id AND mtl.team_id = v_team_id)
        JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN public.roles r ON mtrl.role_id = r.role_id
        WHERE ea.event_id = p_event_id 
          AND r.role_grade = 10  -- Filtered to only include players/audience
        ORDER BY ea.member_id, ea.created_at DESC 
    LOOP
        -- 5. ONLY proceed if the latest response is "Accept" (3)
        IF v_member_record.response_id = 3 THEN
            
            -- Find the squad they belong to for this specific code/team
            v_squad_id_final := NULL;
            SELECT squad_id INTO v_squad_id_final
            FROM public.member_squad_link
            WHERE member_id = v_member_record.member_id 
              AND team_id = v_team_id 
              AND code_id = v_lookup_code_id
            LIMIT 1;

            -- Safety check: don't allow 0 to break foreign keys
            IF v_squad_id_final = 0 THEN v_squad_id_final := NULL; END IF;

            -- 6. Insert the detail record
            INSERT INTO public.match_squad_details (
                match_squad_id, 
                event_id, 
                user_id, 
                team_id, 
                squad_id, 
                member_id, 
                role_id
            )
            VALUES (
                v_new_match_squad_id, 
                p_event_id, 
                p_user_id, 
                v_team_id, 
                v_squad_id_final, 
                v_member_record.member_id, 
                v_member_record.role_id
            );
        END IF;
    END LOOP;

    RETURN v_new_match_squad_id;
END;
$$;


ALTER FUNCTION "public"."create_match_squad_from_attendance"("p_event_id" bigint, "p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_new_member_by_code"("p_first_name" "text", "p_last_name" "text", "p_joining_code" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_new_member_id bigint;
    v_new_member_team_id bigint;
    v_team_id bigint;
    v_club_id bigint;
    v_user_id uuid;
    v_team_name text;
    v_no_team_squad_id bigint;
    -- Standardize Data immediately
    v_clean_first text := INITCAP(TRIM(COALESCE(p_first_name, '')));
    v_clean_last text := INITCAP(TRIM(COALESCE(p_last_name, '')));
    v_clean_code text := UPPER(TRIM(COALESCE(p_joining_code, '')));
    v_default_pic text := 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/hvxmhKxoCA4XCjUFmpM6/assets/50b842h4zvrj/image-removebg-preview_(14).png';
BEGIN
    v_user_id := auth.uid();
    
    -- 1. STRICT VALIDATION: Blocks NULL, '', and '   '
    IF v_clean_first = '' OR v_clean_last = '' OR v_clean_code = '' THEN
        RETURN jsonb_build_object(
            'status', 'error', 
            'message', 'First name, Last name, and Joining Code are all required.'
        );
    END IF;

    -- 2. Find Team/Club via joining code
    SELECT team_id, club_id, team_name 
    INTO v_team_id, v_club_id, v_team_name
    FROM public.teams 
    WHERE UPPER(TRIM(team_unique_code)) = v_clean_code;

    -- 3. VALIDATION: Check if code exists
    IF v_team_id IS NULL THEN
        RETURN jsonb_build_object(
            'status', 'error', 
            'message', 'The joining code "' || p_joining_code || '" is not valid.'
        );
    END IF;

    -- 4. Find the "No Team" squad_id
    SELECT squad_id INTO v_no_team_squad_id
    FROM public.squads
    WHERE team_id = v_team_id AND squad_name = 'No Team'
    LIMIT 1;

    -- 5. DUP CHECK
    IF EXISTS (
        SELECT 1 FROM public.member_team_link mtl
        JOIN public.members m ON mtl.member_id = m.member_id
        WHERE mtl.team_id = v_team_id
          AND m.first_name = v_clean_first 
          AND m.last_name = v_clean_last
    ) THEN
        RETURN jsonb_build_object(
            'status', 'error', 
            'message', 'This person is already a member of this team.'
        );
    END IF;

    -- 6. CREATE MEMBER
    INSERT INTO public.members (first_name, last_name, user_id, profile_pic)
    VALUES (v_clean_first, v_clean_last, v_user_id, v_default_pic)
    RETURNING member_id INTO v_new_member_id;

    -- 7. CREATE USER-MEMBER LINK
    INSERT INTO public.user_member_link (user_id, member_id)
    VALUES (v_user_id, v_new_member_id);

    -- 8. CREATE PRIMARY TEAM LINK (Default to "No Team")
    INSERT INTO public.member_team_link (member_id, team_id, squad_id, member_team_code)
    VALUES (v_new_member_id, v_team_id, v_no_team_squad_id, v_clean_code)
    RETURNING member_team_id INTO v_new_member_team_id;

    -- 9. ASSIGN ROLE
    INSERT INTO public.member_team_role_link (member_team_id, role_id)
    VALUES (v_new_member_team_id, 6);

    -- 10. GENERATE SPORT SQUAD LINKS (Default to "No Team")
    INSERT INTO public.member_squad_link (member_id, team_id, code_id, squad_id)
    SELECT v_new_member_id, v_team_id, code_id, v_no_team_squad_id
    FROM public.club_code_link
    WHERE club_id = v_club_id AND code_id > 1;

    RETURN jsonb_build_object(
        'status', 'success', 
        'member_id', v_new_member_id,
        'team_name', v_team_name
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('status', 'error', 'message', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."create_new_member_by_code"("p_first_name" "text", "p_last_name" "text", "p_joining_code" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_unique_member_code"() RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    new_code TEXT;
    code_exists BOOLEAN;
BEGIN
    LOOP
        -- Generate a random 5-character uppercase alphanumeric string and prefix with "MB"
        new_code := 'MB' || UPPER(SUBSTR(MD5(RANDOM()::TEXT), 1, 5));

        -- Check if the generated code already exists in the public.members table
        SELECT EXISTS (
            SELECT 1
            FROM public.members
            WHERE unique_member_code = new_code -- Updated table and column here
        ) INTO code_exists;

        -- If the code does not exist, exit the loop
        IF NOT code_exists THEN
            EXIT;
        END IF;
    END LOOP;

    RETURN new_code;
END;
$$;


ALTER FUNCTION "public"."generate_unique_member_code"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_unique_team_code"() RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    new_code TEXT;
    code_exists BOOLEAN;
BEGIN
    LOOP
        -- Generate a random 5-character uppercase alphanumeric string and prefix with "TM"
        new_code := 'TM' || UPPER(SUBSTR(MD5(RANDOM()::TEXT), 1, 5));

        -- Check if the generated code already exists in the public.teams table
        SELECT EXISTS (
            SELECT 1
            FROM public.teams
            WHERE team_unique_code = new_code
        ) INTO code_exists;

        -- If the code does not exist, exit the loop
        IF NOT code_exists THEN
            EXIT;
        END IF;
    END LOOP;

    RETURN new_code;
END;
$$;


ALTER FUNCTION "public"."generate_unique_team_code"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_accepted_unpaid_members"("p_event_id" bigint) RETURNS TABLE("member_id" bigint, "member_full_name" "text", "role_name" "text", "role_level" smallint)
    LANGUAGE "sql"
    AS $$

WITH event_details AS (
    -- Get the team ID for the given event
    SELECT e.team_id
    FROM public.events AS e
    WHERE e.event_id = p_event_id
),
latest_event_attendance AS (
    -- Get the single latest attendance response for every member on the event's team
    WITH ranked_attendance AS (
        SELECT
            ea.member_id,
            ea.response_id,
            ROW_NUMBER() OVER(
                PARTITION BY ea.member_id
                ORDER BY ea.created_at DESC, ea.attendance_id DESC
            ) as rn
        FROM
            public.event_attendance AS ea
        WHERE
            ea.event_id = p_event_id
    )
    SELECT
        member_id,
        response_id
    FROM
        ranked_attendance
    WHERE
        rn = 1
        AND response_id = 3 -- CRITICAL FILTER: Only include members who ACCEPTED
),
member_primary_role AS (
    -- Determine the single primary role for all members on the event's team
    WITH ranked_roles AS (
        SELECT
            mtl.member_id,
            r.role_name,
            r.role_level,
            r.role_grade,
            ROW_NUMBER() OVER(
                PARTITION BY mtl.member_id
                ORDER BY r.role_level ASC -- Lowest level is highest privilege
            ) as rn
        FROM
            public.member_team_link AS mtl
        JOIN
            event_details AS ed ON mtl.team_id = ed.team_id
        JOIN
            public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN
            public.roles AS r ON mtrl.role_id = r.role_id
    )
    SELECT
        member_id,
        role_name,
        role_level,
        role_grade
    FROM
        ranked_roles
    WHERE
        rn = 1
        AND role_grade = 10 -- Only include Player/Member roles (grade 10)
),
latest_member_payment AS (
    -- Identify members who have a successful (confirmed) payment for this event
    WITH ranked_payment AS (
        SELECT
            eump.member_id,
            eump.payment_id,
            eump.payment_status,
            ROW_NUMBER() OVER(
                PARTITION BY eump.member_id
                ORDER BY eump.created_at DESC
            ) as rn
        FROM
            public.event_user_member_payment AS eump
        WHERE
            eump.event_id = p_event_id
            AND eump.payment_status <> 'pending' -- Ignore pending payments
    )
    SELECT
        member_id
    FROM
        ranked_payment
    WHERE
        rn = 1
        AND payment_status = 'confirmed' -- Only select members who have PAID
)

SELECT
    mpr.member_id,
    m.first_name || ' ' || m.last_name AS member_full_name,
    mpr.role_name,
    mpr.role_level
FROM
    latest_event_attendance AS lea -- Start with accepted attendance (response_id = 3)
JOIN
    member_primary_role AS mpr ON lea.member_id = mpr.member_id -- Join to get role details (and filter by role_grade 10)
JOIN
    public.members AS m ON lea.member_id = m.member_id -- Join to get the member's name
LEFT JOIN
    latest_member_payment AS lmp ON lea.member_id = lmp.member_id -- LEFT JOIN to find if a payment exists
WHERE
    lmp.member_id IS NULL -- CRITICAL FILTER 1: Exclude paid members (unpaid)
    AND mpr.role_level = 10 -- ⭐ NEW CRITICAL FILTER 2: Restrict to only roles with a level of 10
ORDER BY
    mpr.role_level ASC, m.last_name ASC;

$$;


ALTER FUNCTION "public"."get_accepted_unpaid_members"("p_event_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_club_comparison_dashboard"("p_club_id" integer, "p_start_date" timestamp with time zone DEFAULT ("now"() - '90 days'::interval), "p_end_date" timestamp with time zone DEFAULT "now"()) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_club_name text;
    v_result    jsonb;
BEGIN
    SELECT club_name INTO v_club_name
    FROM public.clubs
    WHERE club_id = p_club_id;

    IF v_club_name IS NULL THEN
        RETURN jsonb_build_object('error', 'Club not found');
    END IF;

    WITH club_teams AS (
        SELECT t.team_id, t.team_name, t.team_female
        FROM public.teams t
        WHERE t.club_id = p_club_id
    ),
    events_in_range AS (
        SELECT
            e.event_id,
            e.team_id,
            e.event_date_time,
            COALESCE(ec.event_code, '') AS event_code,
            COALESCE(et.event_type, '') AS event_type,
            e.opposition,
            CASE
                WHEN e.event_title IS NOT NULL AND trim(e.event_title) <> '' THEN e.event_title
                ELSE trim(
                    CASE WHEN ct.team_female = true AND ec.code_id = 3
                         THEN 'Camogie'
                         ELSE COALESCE(ec.event_code, '')
                    END
                    || ' ' || COALESCE(et.event_type, '')
                    || CASE
                        WHEN et.event_type_id = 2
                         AND e.opposition IS NOT NULL AND e.opposition <> ''
                        THEN ' v ' || e.opposition
                        ELSE ''
                       END
                )
            END AS display_title
        FROM public.events e
        JOIN club_teams ct              ON e.team_id       = ct.team_id
        LEFT JOIN public.event_codes ec ON e.event_code_id = ec.code_id
        LEFT JOIN public.event_types et ON e.event_type_id = et.event_type_id
        WHERE e.event_date_time >= p_start_date
          AND e.event_date_time <  p_end_date
    ),
    team_members AS (
        SELECT DISTINCT ON (mtl.team_id, m.member_id)
            mtl.team_id,
            m.member_id,
            trim(m.first_name || ' ' || COALESCE(m.last_name, '')) AS full_name,
            r.role_name
        FROM public.member_team_link mtl
        JOIN club_teams ct                     ON mtl.team_id       = ct.team_id
        JOIN public.members m                  ON mtl.member_id     = m.member_id
        JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN public.roles r                    ON mtrl.role_id      = r.role_id
        WHERE r.role_grade = 10
        ORDER BY mtl.team_id, m.member_id, r.role_list_seq
    ),
    latest_attendance AS (
        SELECT DISTINCT ON (ea.member_id, ea.event_id)
            ea.member_id,
            ea.event_id,
            ea.response_id
        FROM public.event_attendance ea
        JOIN events_in_range e ON ea.event_id = e.event_id
        ORDER BY ea.member_id, ea.event_id, ea.attendance_id DESC
    ),
    team_event_rows AS (
        SELECT
            e.team_id,
            e.event_id,
            e.event_date_time,
            e.display_title,
            e.event_code,
            e.event_type,
            e.opposition,
            COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'member_id', tm.member_id,
                        'name',      tm.full_name,
                        'role',      tm.role_name,
                        'response',  CASE la.response_id
                                         WHEN 3 THEN 'accepted'
                                         WHEN 4 THEN 'declined'
                                         ELSE        'no_response'
                                     END
                    )
                    ORDER BY tm.full_name
                ),
                '[]'::jsonb
            ) AS members
        FROM events_in_range e
        JOIN team_members tm ON tm.team_id = e.team_id
        LEFT JOIN latest_attendance la
            ON la.member_id = tm.member_id AND la.event_id = e.event_id
        GROUP BY e.team_id, e.event_id, e.event_date_time, e.display_title,
                 e.event_code, e.event_type, e.opposition
    ),
    team_roster AS (
        SELECT DISTINCT ON (mtl.team_id, m.member_id)
            mtl.team_id,
            m.member_id,
            trim(m.first_name || ' ' || COALESCE(m.last_name, '')) AS full_name,
            r.role_name,
            r.role_level
        FROM public.member_team_link mtl
        JOIN club_teams ct                     ON mtl.team_id       = ct.team_id
        JOIN public.members m                  ON mtl.member_id     = m.member_id
        JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN public.roles r                    ON mtrl.role_id      = r.role_id
        WHERE r.role_grade = 10
        ORDER BY mtl.team_id, m.member_id, r.role_list_seq
    ),
    team_roster_by_role AS (
        SELECT
            team_id,
            role_name,
            role_level,
            COUNT(*) AS member_count,
            jsonb_agg(jsonb_build_object('member_id', member_id, 'name', full_name) ORDER BY full_name) AS members
        FROM team_roster
        GROUP BY team_id, role_name, role_level
    ),
    team_member_roles AS (
        SELECT
            team_id,
            jsonb_agg(
                jsonb_build_object('role', role_name, 'count', member_count, 'members', members)
                ORDER BY role_level ASC
            ) AS member_roles
        FROM team_roster_by_role
        GROUP BY team_id
    )
    SELECT jsonb_build_object(
        'club_name',    v_club_name,
        'club_id',      p_club_id,
        'start_date',   p_start_date,
        'end_date',     p_end_date,
        'generated_at', now(),
        'teams', COALESCE(
            (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'team_id',      ct.team_id,
                        'team_name',    ct.team_name,
                        'team_female',  ct.team_female,
                        'member_roles', COALESCE(
                            (SELECT tmr.member_roles FROM team_member_roles tmr WHERE tmr.team_id = ct.team_id),
                            '[]'::jsonb
                        ),
                        'events', COALESCE(
                            (
                                SELECT jsonb_agg(
                                    jsonb_build_object(
                                        'event_id',   ter.event_id,
                                        'date',       ter.event_date_time,
                                        'title',      ter.display_title,
                                        'code',       ter.event_code,
                                        'type',       ter.event_type,
                                        'opposition', ter.opposition,
                                        'members',    ter.members
                                    )
                                    ORDER BY ter.event_date_time DESC
                                )
                                FROM team_event_rows ter
                                WHERE ter.team_id = ct.team_id
                            ),
                            '[]'::jsonb
                        )
                    )
                    ORDER BY ct.team_name
                )
                FROM club_teams ct
            ),
            '[]'::jsonb
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."get_club_comparison_dashboard"("p_club_id" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_event_admin_detail"("p_event_id" bigint) RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    result json;
BEGIN
    SELECT 
        json_build_object(
            'event_id', e.event_id,
            'event_title', e.event_title,
            'team_id', e.team_id,
            -- Fields from the events table
            'notify_admins_changes', e.notify_admins_changes,
            'notify_admins_all', e.notify_admins_all,
            'car_pooling', e.car_pooling,
            -- New field requested from the teams table
            'car_pooling_allowed', t.car_pooling_allowed,
            -- Friendly date formatting
            'created_at', to_char(e.created_at, 'FMDay, FMMonth DD, YYYY "at" HH12:MI AM'),
            'reminders', COALESCE(reminders_data.list, '[]'::json)
        )
    INTO result
    FROM public.events e
    -- Join to teams table to get the car_pooling_allowed status
    LEFT JOIN public.teams t ON e.team_id = t.team_id
    LEFT JOIN LATERAL (
        SELECT json_agg(
            json_build_object(
                'reminder_id', r.id,
                'result', r.result,
                'created_at', to_char(r.created_at, 'FMDay, FMMonth DD, YYYY "at" HH12:MI AM'),
                'user_full_name', trim(concat(u.first_name, ' ', u.last_name))
            )
        ) AS list
        FROM public.reminders r
        LEFT JOIN public.users u ON r.user_id = u.user_id 
        WHERE r.event_id = e.event_id
    ) AS reminders_data ON true
    WHERE e.event_id = p_event_id;

    RETURN COALESCE(result, '{}'::json);
END;
$$;


ALTER FUNCTION "public"."get_event_admin_detail"("p_event_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_event_attendance_by_role"("p_event_id" bigint, "p_role_grade_filter" smallint DEFAULT NULL::smallint, "p_role_level_filter" smallint DEFAULT NULL::smallint, "p_role_level_exclude" smallint DEFAULT NULL::smallint, "p_response_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
    RETURN (
    WITH
    latest_event_attendance AS (
        -- CTE 1: Find the single latest attendance response for *each* member on the event
        SELECT
            DISTINCT ON (ea.event_id, ea.member_id)
            ea.event_id,
            ea.member_id,
            ea.response_id
        FROM
            public.event_attendance ea
        WHERE
            ea.event_id = p_event_id
        ORDER BY
            ea.event_id,
            ea.member_id,
            ea.created_at DESC
    ),
    member_base_data AS (
        -- CTE 2: Finds all distinct Member/Squad/Role combinations, including squad details
        SELECT DISTINCT
            e.event_id,
            mtl.member_id,
            m.first_name,
            m.last_name,
            mtl.squad_id,
            sq.squad_name,
            sq.grade AS squad_grade,
            sq.squad_list_seq,
            sq.squad_image,
            mtrl.role_id
        FROM
            events e
            JOIN public.member_team_link mtl ON e.team_id = mtl.team_id AND e.event_id = p_event_id
            JOIN public.members m ON mtl.member_id = m.member_id
            JOIN public.squads sq ON mtl.squad_id = sq.squad_id
            JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        WHERE
            mtl.squad_id IS NOT NULL
    ),
    all_roles_for_event AS (
        -- CTE 3: Generates the base set of all Roles that should be reported on, including filtering
        SELECT DISTINCT
            e.event_id,
            r.role_id,
            r.role_name,
            r.role_level,
            r.role_grade,
            r.role_name_plural,
            r.role_list_seq
        FROM
            events e
            JOIN public.teams t ON e.team_id = t.team_id
            JOIN public.team_roles_link trl ON t.team_id = trl.team_id
            JOIN public.roles r ON trl.role_id = r.role_id
        WHERE
            e.event_id = p_event_id
            AND (p_role_grade_filter IS NULL OR p_role_grade_filter = 0 OR r.role_grade = p_role_grade_filter)
            AND (p_role_level_filter IS NULL OR p_role_level_filter = 0 OR r.role_level >= p_role_level_filter)
            AND (p_role_level_exclude IS NULL OR r.role_level != p_role_level_exclude)
    ),
    member_status_data AS (
        -- CTE 4: Links member details and attendance status, building the final member JSON object
        SELECT
            mbd.event_id,
            mbd.role_id,
            mbd.first_name,
            mbd.last_name,
            mbd.squad_grade,
            mbd.squad_list_seq,
            lea.response_id,
            jsonb_build_object(
                'member_id', mbd.member_id,
                'member_name', mbd.first_name || ' ' || mbd.last_name,
                'squad_id', mbd.squad_id,
                'squad_name', mbd.squad_name,
                'squad_grade', mbd.squad_grade,
                'squad_list_seq', mbd.squad_list_seq,
                'squad_image', mbd.squad_image
            ) AS member_json,
            CASE
                WHEN lea.response_id = 3 THEN 'accepted'
                WHEN lea.response_id = 4 THEN 'declined'
                WHEN lea.response_id IS NULL THEN 'no_response'
                ELSE 'irrelevant'
            END AS attendance_status
        FROM
            member_base_data mbd
            LEFT JOIN latest_event_attendance lea ON mbd.event_id = lea.event_id AND mbd.member_id = lea.member_id
    )
    -- CTE 5: Aggregates members into attendance lists within Role objects
    , roles_with_attendance AS (
        SELECT
            r.role_id,
            r.role_name,
            r.role_name_plural,
            r.role_grade,
            r.role_level,
            r.role_list_seq,
            -- Aggregate members by status into JSONB arrays, sorted by squad list sequence and first name
            COALESCE(jsonb_agg(msd.member_json ORDER BY msd.squad_list_seq ASC, msd.first_name ASC, msd.last_name ASC) FILTER (WHERE msd.attendance_status = 'accepted'), '[]'::jsonb) AS accepted_members,
            COALESCE(jsonb_agg(msd.member_json ORDER BY msd.squad_list_seq ASC, msd.first_name ASC, msd.last_name ASC) FILTER (WHERE msd.attendance_status = 'declined'), '[]'::jsonb) AS declined_members,
            COALESCE(jsonb_agg(msd.member_json ORDER BY msd.squad_list_seq ASC, msd.first_name ASC, msd.last_name ASC) FILTER (WHERE msd.attendance_status = 'no_response'), '[]'::jsonb) AS no_response_members
        FROM
            all_roles_for_event r
            LEFT JOIN member_status_data msd ON r.event_id = msd.event_id AND r.role_id = msd.role_id
        GROUP BY
            r.event_id, r.role_id, r.role_name, r.role_name_plural, r.role_list_seq, r.role_grade, r.role_level
    )
    -- Final SELECT: Aggregates roles into a JSON array, applying filter based on p_response_id
    SELECT
        jsonb_agg(
            CASE
                -- Case 1: Filter for Accepted members (p_response_id = 3)
                WHEN p_response_id = 3 THEN
                    jsonb_build_object(
                        'role_id', ra.role_id,
                        'role_name', ra.role_name,
                        'role_name_plural', ra.role_name_plural,
                        'role_grade', ra.role_grade,
                        'role_level', ra.role_level,
                        'member_count', jsonb_array_length(ra.accepted_members),
                        'members', ra.accepted_members
                    )
                -- Case 2: Filter for Declined members (p_response_id = 4)
                WHEN p_response_id = 4 THEN
                    jsonb_build_object(
                        'role_id', ra.role_id,
                        'role_name', ra.role_name,
                        'role_name_plural', ra.role_name_plural,
                        'role_grade', ra.role_grade,
                        'role_level', ra.role_level,
                        'member_count', jsonb_array_length(ra.declined_members),
                        'members', ra.declined_members
                    )
                -- Case 3: Filter for No Response members (p_response_id is anything else/NULL but not 3 or 4)
                WHEN p_response_id IS NOT NULL AND p_response_id NOT IN (3, 4) THEN
                    jsonb_build_object(
                        'role_id', ra.role_id,
                        'role_name', ra.role_name,
                        'role_name_plural', ra.role_name_plural,
                        'role_grade', ra.role_grade,
                        'role_level', ra.role_level,
                        'member_count', jsonb_array_length(ra.no_response_members),
                        'members', ra.no_response_members
                    )
                -- Case 4: Default - No filter (p_response_id is NULL or not provided), return all lists
                ELSE
                    jsonb_build_object(
                        'role_id', ra.role_id,
                        'role_name', ra.role_name,
                        'role_name_plural', ra.role_name_plural,
                        'role_grade', ra.role_grade,
                        'role_level', ra.role_level,
                        'accepted_count', jsonb_array_length(ra.accepted_members),
                        'no_response_count', jsonb_array_length(ra.no_response_members),
                        'declined_count', jsonb_array_length(ra.declined_members),
                        'accepted_members', ra.accepted_members,
                        'no_response_members', ra.no_response_members,
                        'declined_members', ra.declined_members
                    )
            END
            -- ROLE SORTING: Sorts by sequence, grade, and level
            ORDER BY ra.role_list_seq, ra.role_grade DESC, ra.role_level DESC
        )
    FROM roles_with_attendance ra
    );
END;
$$;


ALTER FUNCTION "public"."get_event_attendance_by_role"("p_event_id" bigint, "p_role_grade_filter" smallint, "p_role_level_filter" smallint, "p_role_level_exclude" smallint, "p_response_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_event_attendance_by_role_v2"("p_event_id" bigint, "p_role_grade_filter" smallint DEFAULT NULL::smallint, "p_role_level_filter" smallint DEFAULT NULL::smallint, "p_role_level_exclude" smallint DEFAULT NULL::smallint, "p_response_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_event_code_id bigint;
    v_effective_code_id bigint;
    v_team_id bigint;
    v_has_members_for_code boolean;
    v_next_code_id bigint;
BEGIN
    -- Get the event's code_id and team_id
    SELECT event_code_id, team_id INTO v_event_code_id, v_team_id
    FROM public.events
    WHERE event_id = p_event_id;
    
    -- Start with the event's code_id
    v_effective_code_id := v_event_code_id;
    
    -- If event has a code_id, check if it has any members
    IF v_event_code_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1 
            FROM public.member_squad_link 
            WHERE team_id = v_team_id 
              AND code_id = v_event_code_id
            LIMIT 1
        ) INTO v_has_members_for_code;
        
        -- If no members found with event's code_id, find the next valid code_id in ascending order
        IF NOT v_has_members_for_code THEN
            SELECT code_id INTO v_next_code_id
            FROM public.member_squad_link
            WHERE team_id = v_team_id
              AND code_id IS NOT NULL
              AND code_id > v_event_code_id
            ORDER BY code_id ASC
            LIMIT 1;
            
            IF v_next_code_id IS NOT NULL THEN
                v_effective_code_id := v_next_code_id;
            ELSE
                SELECT MIN(code_id) INTO v_effective_code_id
                FROM public.member_squad_link
                WHERE team_id = v_team_id
                  AND code_id IS NOT NULL;
            END IF;
        END IF;
    ELSE
        SELECT MIN(code_id) INTO v_effective_code_id
        FROM public.member_squad_link
        WHERE team_id = v_team_id
          AND code_id IS NOT NULL;
    END IF;
    
    -- If still no code found, try club_code_link
    IF v_effective_code_id IS NULL THEN
        SELECT ccl.code_id INTO v_effective_code_id
        FROM public.teams t
        JOIN public.clubs c ON t.club_id = c.club_id
        JOIN public.club_code_link ccl ON c.club_id = ccl.club_id
        WHERE t.team_id = v_team_id
        ORDER BY ccl.code_id ASC
        LIMIT 1;
    END IF;

    RETURN (
    WITH
    latest_event_attendance AS (
        SELECT
            DISTINCT ON (ea.event_id, ea.member_id)
            ea.event_id,
            ea.member_id,
            ea.response_id
        FROM
            public.event_attendance ea
        WHERE
            ea.event_id = p_event_id
        ORDER BY
            ea.event_id,
            ea.member_id,
            ea.created_at DESC
    ),
    member_base_data AS (
        SELECT DISTINCT
            e.event_id,
            msl.member_id,
            m.first_name,
            m.last_name,
            msl.squad_id,
            sq.squad_name,
            sq.grade AS squad_grade,
            sq.squad_list_seq,
            sq.squad_image,
            mtrl.role_id,
            msl.squad_id AS squad_code_id,
            sq.squad_name AS squad_code_name,
            sq.squad_image AS squad_code_image
        FROM
            events e
            JOIN public.member_squad_link msl ON e.team_id = msl.team_id 
                AND msl.code_id = v_effective_code_id
            JOIN public.members m ON msl.member_id = m.member_id
            JOIN public.squads sq ON msl.squad_id = sq.squad_id
            JOIN public.member_team_link mtl ON msl.member_id = mtl.member_id 
                AND msl.team_id = mtl.team_id
            JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        WHERE
            e.event_id = p_event_id
            AND msl.squad_id IS NOT NULL
    ),
    all_roles_for_event AS (
        SELECT DISTINCT
            e.event_id,
            r.role_id,
            r.role_name,
            r.role_level,
            r.role_grade,
            r.role_name_plural,
            r.role_list_seq
        FROM
            events e
            JOIN public.teams t ON e.team_id = t.team_id
            JOIN public.team_roles_link trl ON t.team_id = trl.team_id
            JOIN public.roles r ON trl.role_id = r.role_id
        WHERE
            e.event_id = p_event_id
            AND (p_role_grade_filter IS NULL OR p_role_grade_filter = 0 OR r.role_grade = p_role_grade_filter)
            AND (p_role_level_filter IS NULL OR p_role_level_filter = 0 OR r.role_level >= p_role_level_filter)
            AND (p_role_level_exclude IS NULL OR r.role_level != p_role_level_exclude)
    ),
    member_status_data AS (
        SELECT
            mbd.event_id,
            mbd.role_id,
            mbd.member_id,
            mbd.first_name,
            mbd.last_name,
            mbd.squad_id,
            mbd.squad_grade,
            mbd.squad_list_seq,
            mbd.squad_code_id,
            lea.response_id,
            jsonb_build_object(
                'member_id', mbd.member_id,
                'member_name', mbd.first_name || ' ' || mbd.last_name,
                'squad_id', mbd.squad_id,
                'squad_name', mbd.squad_name,
                'squad_grade', mbd.squad_grade,
                'squad_list_seq', mbd.squad_list_seq,
                'squad_image', mbd.squad_image,
                'squad_code_id', mbd.squad_code_id,
                'squad_code_name', mbd.squad_code_name,
                'squad_code_image', mbd.squad_code_image,
                'sort_key', LPAD(mbd.squad_list_seq::text, 10, '0') || ' ' || mbd.first_name || ' ' || mbd.last_name
            ) AS member_json,
            CASE
                WHEN lea.response_id = 3 THEN 'accepted'
                WHEN lea.response_id = 4 THEN 'declined'
                WHEN lea.response_id IS NULL THEN 'no_response'
                ELSE 'irrelevant'
            END AS attendance_status
        FROM
            member_base_data mbd
            LEFT JOIN latest_event_attendance lea ON mbd.event_id = lea.event_id AND mbd.member_id = lea.member_id
    ),
    roles_with_attendance AS (
        SELECT
            r.role_id,
            r.role_name,
            r.role_name_plural,
            r.role_grade,
            r.role_level,
            r.role_list_seq,
            -- Group level seq, using MIN to represent the general sequence for this role grouping
            MIN(msd.squad_list_seq) as min_squad_seq,
            COALESCE(jsonb_agg(msd.member_json ORDER BY msd.squad_id ASC, (msd.first_name || ' ' || msd.last_name) ASC) FILTER (WHERE msd.attendance_status = 'accepted'), '[]'::jsonb) AS accepted_members,
            COALESCE(jsonb_agg(msd.member_json ORDER BY msd.squad_id ASC, (msd.first_name || ' ' || msd.last_name) ASC) FILTER (WHERE msd.attendance_status = 'declined'), '[]'::jsonb) AS declined_members,
            COALESCE(jsonb_agg(msd.member_json ORDER BY msd.squad_id ASC, (msd.first_name || ' ' || msd.last_name) ASC) FILTER (WHERE msd.attendance_status = 'no_response'), '[]'::jsonb) AS no_response_members,
            COUNT(DISTINCT msd.member_id) FILTER (WHERE msd.squad_code_id IS NOT NULL) as squad_code_count,
            COUNT(DISTINCT msd.member_id) FILTER (WHERE msd.squad_code_id IS NOT NULL AND msd.attendance_status = 'accepted') as code_accepted_count,
            COUNT(DISTINCT msd.member_id) FILTER (WHERE msd.squad_code_id IS NOT NULL AND msd.attendance_status = 'declined') as code_declined_count,
            COUNT(DISTINCT msd.member_id) FILTER (WHERE msd.squad_code_id IS NOT NULL AND msd.attendance_status = 'no_response') as code_no_response_count
        FROM
            all_roles_for_event r
            LEFT JOIN member_status_data msd ON r.event_id = msd.event_id AND r.role_id = msd.role_id
        GROUP BY
            r.event_id, r.role_id, r.role_name, r.role_name_plural, r.role_list_seq, r.role_grade, r.role_level
    )
    SELECT
        jsonb_agg(
            CASE
                WHEN p_response_id = 3 THEN
                    jsonb_build_object(
                        'role_id', ra.role_id,
                        'role_name', ra.role_name,
                        'role_name_plural', ra.role_name_plural,
                        'role_grade', ra.role_grade,
                        'role_level', ra.role_level,
                        'squad_list_seq', ra.min_squad_seq,
                        'member_count', jsonb_array_length(ra.accepted_members),
                        'member_role_count', ra.code_accepted_count,
                        'members', ra.accepted_members
                    )
                WHEN p_response_id = 4 THEN
                    jsonb_build_object(
                        'role_id', ra.role_id,
                        'role_name', ra.role_name,
                        'role_name_plural', ra.role_name_plural,
                        'role_grade', ra.role_grade,
                        'role_level', ra.role_level,
                        'squad_list_seq', ra.min_squad_seq,
                        'member_count', jsonb_array_length(ra.declined_members),
                        'member_role_count', ra.code_declined_count,
                        'members', ra.declined_members
                    )
                WHEN p_response_id IS NOT NULL AND p_response_id NOT IN (3, 4) THEN
                    jsonb_build_object(
                        'role_id', ra.role_id,
                        'role_name', ra.role_name,
                        'role_name_plural', ra.role_name_plural,
                        'role_grade', ra.role_grade,
                        'role_level', ra.role_level,
                        'squad_list_seq', ra.min_squad_seq,
                        'member_count', jsonb_array_length(ra.no_response_members),
                        'member_role_count', ra.code_no_response_count,
                        'members', ra.no_response_members
                    )
                ELSE
                    jsonb_build_object(
                        'role_id', ra.role_id,
                        'role_name', ra.role_name,
                        'role_name_plural', ra.role_name_plural,
                        'role_grade', ra.role_grade,
                        'role_level', ra.role_level,
                        'squad_list_seq', ra.min_squad_seq,
                        'accepted_count', jsonb_array_length(ra.accepted_members),
                        'no_response_count', jsonb_array_length(ra.no_response_members),
                        'declined_count', jsonb_array_length(ra.declined_members),
                        'squad_code_count', ra.squad_code_count,
                        'accepted_members', ra.accepted_members,
                        'no_response_members', ra.no_response_members,
                        'declined_members', ra.declined_members
                    )
            END
            ORDER BY ra.role_list_seq, ra.role_grade DESC, ra.role_level DESC
        )
    FROM roles_with_attendance ra
    );
END;
$$;


ALTER FUNCTION "public"."get_event_attendance_by_role_v2"("p_event_id" bigint, "p_role_grade_filter" smallint, "p_role_level_filter" smallint, "p_role_level_exclude" smallint, "p_response_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_event_attendance_details"("p_event_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
    RETURN (
        WITH
        -- 1. Identify Event & Team Context
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
        -- 2. Find the absolute LATEST response for each member, filter for 'Accepted' (3)
        latest_accepted_only AS (
            SELECT DISTINCT ON (ea.member_id)
                ea.member_id,
                ea.response_id,
                ea.created_at
            FROM public.event_attendance ea
            WHERE ea.event_id = p_event_id
            ORDER BY ea.member_id, ea.created_at DESC
        ),
        -- 3. Gather details ONLY for members who have a role ON THIS SPECIFIC TEAM
        member_details AS (
            SELECT DISTINCT ON (m.member_id)
                u.user_id,
                u.first_name || ' ' || u.last_name AS full_user_name,
                m.member_id,
                m.first_name || ' ' || m.last_name AS full_member_name,
                -- Verify Squad belongs to THIS team
                CASE WHEN s.team_id = ec.team_id THEN s.squad_id ELSE NULL END as squad_id,
                CASE WHEN s.team_id = ec.team_id THEN s.squad_name ELSE NULL END as squad_name,
                CASE WHEN s.team_id = ec.team_id THEN s.squad_image ELSE NULL END as squad_image,
                -- Verify Event-specific code squad belongs to THIS team
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
            -- STRICT LINK: Only pull the team link for THIS event's team
            JOIN public.member_team_link mtl ON m.member_id = mtl.member_id AND mtl.team_id = ec.team_id
            -- STRICT LINK: Only pull the role associated with THAT specific team link
            JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
            JOIN public.roles r ON mtrl.role_id = r.role_id
            -- Standard joins
            JOIN public.user_member_link uml ON m.member_id = uml.member_id
            JOIN public.users u ON uml.user_id = u.user_id
            JOIN public.event_response_type ert ON la.response_id = ert.response_id
            -- Squad joins (with strict team_id safety check)
            LEFT JOIN public.squads s ON mtl.squad_id = s.squad_id AND s.team_id = ec.team_id
            LEFT JOIN public.member_squad_link msl ON m.member_id = msl.member_id AND msl.code_id = ec.event_code_id AND msl.team_id = ec.team_id
            LEFT JOIN public.squads sq_code ON msl.squad_id = sq_code.squad_id AND sq_code.team_id = ec.team_id
            ORDER BY m.member_id, r.role_list_seq ASC
        )
        -- 4. Build JSON
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
                            md.user_id,
                            md.full_user_name,
                            md.member_id,
                            md.full_member_name,
                            md.squad_id,
                            md.squad_name,
                            md.squad_image,
                            md.squad_code_id,
                            md.squad_code_name,
                            md.squad_code_image,
                            md.role_id,
                            md.role_name,
                            md.role_list_seq,
                            md.response_status AS status,
                            md.response_icon AS icon,
                            md.attendance_date
                        FROM member_details md
                    ) attendee_row
                ), '[]'::jsonb)
            )
        FROM event_config ec
    );
END;
$$;


ALTER FUNCTION "public"."get_event_attendance_details"("p_event_id" bigint) OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."event_attendance" (
    "attendance_id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "event_id" bigint,
    "member_id" bigint,
    "response_id" bigint
);


ALTER TABLE "public"."event_attendance" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."event_response_type" (
    "response_id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "response_value" "text",
    "response_icon" "text",
    "display_value" "text",
    "icon_link" "text"
);


ALTER TABLE "public"."event_response_type" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."events" (
    "event_id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "event_title" "text",
    "meet_time" "text",
    "opposition" "text",
    "event_details" "text",
    "location_pin" "text",
    "location_name" "text",
    "home_away" "text",
    "created_by" "uuid",
    "team_id" bigint,
    "event_date_time" timestamp with time zone,
    "event_code_id" bigint,
    "event_type_id" bigint,
    "audience_id" bigint,
    "request_attendance" boolean,
    "squad_id" bigint,
    "event_date_time_2" timestamp without time zone,
    "event_link" "text",
    "notify_admins_changes" boolean,
    "notify_admins_all" boolean,
    "payment_required" boolean,
    "payment_amount" smallint,
    "event_image" "text",
    "car_pooling" boolean
);


ALTER TABLE "public"."events" OWNER TO "postgres";


COMMENT ON COLUMN "public"."events"."event_code_id" IS 'Event Code';



COMMENT ON COLUMN "public"."events"."event_type_id" IS 'Event Type';



COMMENT ON COLUMN "public"."events"."audience_id" IS 'Audience is linked to the role';



CREATE TABLE IF NOT EXISTS "public"."member_team_link" (
    "member_team_id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "member_id" bigint,
    "team_id" bigint,
    "squad_id" bigint,
    "member_team_code" "text"
);


ALTER TABLE "public"."member_team_link" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."member_team_role_link" (
    "member_team_role_id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "member_team_id" bigint,
    "role_id" bigint
);


ALTER TABLE "public"."member_team_role_link" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."members" (
    "member_id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_id" "uuid",
    "first_name" "text",
    "last_name" "text",
    "profile_pic" "text",
    "unique_member_code" "text",
    "date_of_birth" "date",
    "membership_num" "text",
    "name_translated" "text"
);


ALTER TABLE "public"."members" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."roles" (
    "role_id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "role_name" "text",
    "role_level" smallint,
    "role_name_plural" "text",
    "role_grade" smallint,
    "role_list_seq" smallint,
    "show_audience" boolean
);


ALTER TABLE "public"."roles" OWNER TO "postgres";


COMMENT ON COLUMN "public"."roles"."role_level" IS 'A role has a level. For example a coach can also be an FLO but an FLO does not need to be a coach. So we need 2 different levels to cater for that flexibility';



COMMENT ON COLUMN "public"."roles"."role_list_seq" IS 'List Sequence for List Views etc';



CREATE TABLE IF NOT EXISTS "public"."squads" (
    "squad_id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "team_id" bigint,
    "squad_name" "text",
    "grade" "text",
    "squad_colour" "text",
    "squad_image" "text",
    "squad_list_seq" smallint
);


ALTER TABLE "public"."squads" OWNER TO "postgres";


COMMENT ON TABLE "public"."squads" IS 'A pod is a subset of a team';



CREATE TABLE IF NOT EXISTS "public"."teams" (
    "team_id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "team_name" "text",
    "dest_folder" "text",
    "team_unique_code" "text",
    "team_juvenile" boolean,
    "team_female" boolean,
    "club_id" bigint,
    "profile_pic" "text",
    "car_pooling_allowed" boolean,
    "show_advert" boolean,
    "allow_lineup" boolean
);


ALTER TABLE "public"."teams" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_member_link" (
    "user_member_id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_id" "uuid",
    "member_id" bigint
);


ALTER TABLE "public"."user_member_link" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users" (
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "email_address" "text" NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "first_name" "text",
    "last_name" "text",
    "phone_number" "text",
    "fcm_token" "text",
    "installation_id" "text",
    "supabaseToken" "text",
    "default_club" bigint
);


ALTER TABLE "public"."users" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_event_attendance_details" AS
 WITH "event_team_members_with_squads" AS (
         SELECT DISTINCT "u"."user_id",
            "u"."email_address",
            "u"."first_name" AS "user_first_name",
            "u"."last_name" AS "user_last_name",
            (("u"."first_name" || ' '::"text") || "u"."last_name") AS "full_user_name",
            "e"."team_id",
            "e"."event_id",
            "e"."event_title",
            "e"."event_date_time",
            "m"."member_id",
            "m"."first_name" AS "member_first_name",
            "m"."last_name" AS "member_last_name",
            (("m"."first_name" || ' '::"text") || "m"."last_name") AS "full_member_name",
            "mtl"."squad_id",
            "s"."squad_name",
            "s"."squad_image",
            "t"."team_name"
           FROM (((((("public"."users" "u"
             JOIN "public"."user_member_link" "uml" ON (("u"."user_id" = "uml"."user_id")))
             JOIN "public"."members" "m" ON (("uml"."member_id" = "m"."member_id")))
             JOIN "public"."member_team_link" "mtl" ON (("m"."member_id" = "mtl"."member_id")))
             JOIN "public"."teams" "t" ON (("mtl"."team_id" = "t"."team_id")))
             JOIN "public"."events" "e" ON (("mtl"."team_id" = "e"."team_id")))
             LEFT JOIN "public"."squads" "s" ON (("mtl"."squad_id" = "s"."squad_id")))
        ), "member_event_roles" AS (
         SELECT "etms_1"."user_id",
            "etms_1"."event_id",
            "etms_1"."member_id",
            "mtrl"."role_id",
            "r"."role_name",
            "r"."role_level",
            "r"."role_name_plural",
            "r"."role_grade",
            "r"."role_list_seq"
           FROM ((("event_team_members_with_squads" "etms_1"
             JOIN "public"."member_team_link" "mtl" ON ((("etms_1"."member_id" = "mtl"."member_id") AND ("etms_1"."team_id" = "mtl"."team_id"))))
             JOIN "public"."member_team_role_link" "mtrl" ON (("mtl"."member_team_id" = "mtrl"."member_team_id")))
             JOIN "public"."roles" "r" ON (("mtrl"."role_id" = "r"."role_id")))
        ), "latest_member_event_attendance" AS (
         SELECT "ea"."event_id",
            "ea"."member_id",
            "ea"."response_id",
            "ert"."response_value",
            "ert"."response_icon",
            "ert"."display_value",
            "ea"."created_at" AS "attendance_created_at",
            "row_number"() OVER (PARTITION BY "ea"."event_id", "ea"."member_id" ORDER BY "ea"."created_at" DESC) AS "rn"
           FROM ("public"."event_attendance" "ea"
             LEFT JOIN "public"."event_response_type" "ert" ON (("ea"."response_id" = "ert"."response_id")))
        )
 SELECT "etms"."user_id",
    "etms"."email_address",
    "etms"."user_first_name",
    "etms"."user_last_name",
    "etms"."full_user_name",
    "etms"."team_id",
    "etms"."team_name",
    "etms"."event_id",
    "etms"."event_title",
    "etms"."event_date_time",
    "etms"."member_id",
    "etms"."member_first_name",
    "etms"."member_last_name",
    "etms"."full_member_name",
    "mer"."role_id",
    "mer"."role_name",
    "mer"."role_level",
    "mer"."role_name_plural",
    "mer"."role_grade",
    "mer"."role_list_seq",
    "etms"."squad_id",
    "etms"."squad_name",
    "etms"."squad_image",
    "lmea"."response_id",
    "lmea"."attendance_created_at",
    "lmea"."response_icon",
    "lmea"."display_value",
        CASE
            WHEN ("lmea"."response_id" IS NULL) THEN 'No Response'::"text"
            ELSE "lmea"."display_value"
        END AS "response_status"
   FROM (("event_team_members_with_squads" "etms"
     JOIN "member_event_roles" "mer" ON ((("etms"."event_id" = "mer"."event_id") AND ("etms"."member_id" = "mer"."member_id") AND ("etms"."user_id" = "mer"."user_id"))))
     LEFT JOIN "latest_member_event_attendance" "lmea" ON ((("etms"."event_id" = "lmea"."event_id") AND ("etms"."member_id" = "lmea"."member_id") AND ("lmea"."rn" = 1))))
  ORDER BY "etms"."event_date_time" DESC, "etms"."event_id", "etms"."user_id", "etms"."squad_name", "mer"."role_list_seq", "mer"."role_grade" DESC, "mer"."role_level" DESC, "etms"."full_member_name";


ALTER VIEW "public"."view_event_attendance_details" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_event_attendance_details"("p_user_id" "uuid", "p_event_id" bigint, "p_role_level" integer) RETURNS SETOF "public"."view_event_attendance_details"
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


CREATE OR REPLACE FUNCTION "public"."get_event_attendance_summary"("p_event_id" integer, "p_role_level" integer) RETURNS TABLE("event_id" bigint, "event_title" character varying, "event_date_time" timestamp without time zone, "meet_time" "text", "opposition" character varying, "location_name" character varying, "team_id" bigint, "team_name" character varying, "role_id" bigint, "role_name" character varying, "role_level" smallint, "role_grade" smallint, "role_name_plural" character varying, "role_list_seq" smallint, "accepted_attendees_count" bigint, "declined_attendees_count" bigint, "no_response_count" bigint)
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
            ea.event_id,
            ea.member_id,
            ea.created_at desc
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
        coalesce(
            sum(
                case
                    when lea.response_id = 3 then 1
                    else 0
                end
            ),
            0::bigint
        ) as accepted_attendees_count,
        coalesce(
            sum(
                case
                    when lea.response_id = 4 then 1
                    else 0
                end
            ),
            0::bigint
        ) as declined_attendees_count,
        coalesce(
            sum(
                case
                    when lea.response_id is null
                    and amr.member_id is not null then 1
                    else 0
                end
            ),
            0::bigint
        ) as no_response_count
    from
        (
            select
                e.event_id,
                e.event_title,
                e.event_date_time,
                e.meet_time,
                e.opposition,
                e.location_name,
                t.team_id,
                t.team_name,
                r.role_id,
                r.role_name,
                r.role_level,
                r.role_grade,
                r.role_name_plural,
                r.role_list_seq
            from
                events e
                join teams t on e.team_id = t.team_id
                join team_roles_link trl on t.team_id = trl.team_id
                join roles r on trl.role_id = r.role_id
            where
                e.event_id = p_event_id
                and r.role_level = p_role_level
        ) aetr
        left join actual_member_roles_for_event amr on aetr.event_id = amr.event_id and aetr.role_id = amr.role_id
        left join latest_event_attendance lea on amr.event_id = lea.event_id and amr.member_id = lea.member_id
    group by
        aetr.event_id,
        aetr.event_title,
        aetr.event_date_time,
        aetr.meet_time,
        aetr.opposition,
        aetr.location_name,
        aetr.team_id,
        aetr.team_name,
        aetr.role_id,
        aetr.role_name,
        aetr.role_level,
        aetr.role_grade,
        aetr.role_name_plural,
        aetr.role_list_seq
    order by
        aetr.event_date_time desc,
        aetr.role_list_seq,
        aetr.role_grade desc,
        aetr.role_level desc;
end;
$$;


ALTER FUNCTION "public"."get_event_attendance_summary"("p_event_id" integer, "p_role_level" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_event_attendance_summary_by_role"("p_event_id" bigint, "p_role_grade_filter" smallint DEFAULT NULL::smallint, "p_role_level_filter" smallint DEFAULT NULL::smallint, "p_role_level_exclude" smallint DEFAULT NULL::smallint) RETURNS TABLE("event_id" bigint, "role_id" bigint, "role_name" "text", "role_level" smallint, "role_grade" smallint, "role_name_plural" "text", "role_list_seq" smallint, "accepted_attendees_count" bigint, "declined_attendees_count" bigint, "no_response_count" bigint)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
    RETURN QUERY
    WITH
    actual_member_roles_for_event AS (
        SELECT DISTINCT
            e.event_id,
            mtl.member_id,
            mtrl.role_id
        FROM
            events e
            JOIN member_team_link mtl ON e.team_id = mtl.team_id
            AND e.event_id = p_event_id
            JOIN members m ON mtl.member_id = m.member_id
            JOIN member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
            JOIN team_roles_link trl ON mtl.team_id = trl.team_id AND mtrl.role_id = trl.role_id
    ),
    latest_event_attendance AS (
        SELECT
            DISTINCT ON (ea.event_id, ea.member_id)
            ea.event_id,
            ea.member_id,
            ea.response_id
        FROM
            event_attendance ea
        WHERE
            ea.event_id = p_event_id
        ORDER BY
            ea.event_id,
            ea.member_id,
            ea.created_at DESC
    )
    SELECT
        aetr.event_id,
        aetr.role_id,
        aetr.role_name,
        aetr.role_level,
        aetr.role_grade,
        aetr.role_name_plural,
        aetr.role_list_seq,
        COALESCE(
            SUM(
                CASE
                    WHEN lea.response_id = 3 THEN 1
                    ELSE 0
                END
            ),
            0::bigint
        ) AS accepted_attendees_count,
        COALESCE(
            SUM(
                CASE
                    WHEN lea.response_id = 4 THEN 1
                    ELSE 0
                END
            ),
            0::bigint
        ) AS declined_attendees_count,
        COALESCE(
            SUM(
                CASE
                    WHEN lea.response_id IS NULL AND amr.member_id IS NOT NULL THEN 1
                    ELSE 0
                END
            ),
            0::bigint
        ) AS no_response_count
    FROM
        (
            SELECT
                e.event_id,
                t.team_id,
                r.role_id,
                r.role_name,
                r.role_level,
                r.role_grade,
                r.role_name_plural,
                r.role_list_seq
            FROM
                events e
                JOIN teams t ON e.team_id = t.team_id
                JOIN team_roles_link trl ON t.team_id = trl.team_id
                JOIN roles r ON trl.role_id = r.role_id
            WHERE
                e.event_id = p_event_id
                AND (p_role_grade_filter IS NULL OR p_role_grade_filter = 0 OR r.role_grade = p_role_grade_filter)
                -- UPDATED: Now checks for role_level >= p_role_level_filter
                AND (p_role_level_filter IS NULL OR p_role_level_filter = 0 OR r.role_level >= p_role_level_filter)
                AND (p_role_level_exclude IS NULL OR r.role_level != p_role_level_exclude)
        ) aetr
        LEFT JOIN actual_member_roles_for_event amr ON aetr.event_id = amr.event_id AND aetr.role_id = amr.role_id
        LEFT JOIN latest_event_attendance lea ON amr.event_id = lea.event_id AND amr.member_id = lea.member_id
    GROUP BY
        aetr.event_id,
        aetr.role_id,
        aetr.role_name,
        aetr.role_level,
        aetr.role_grade,
        aetr.role_name_plural,
        aetr.role_list_seq
    ORDER BY
        aetr.role_list_seq,
        aetr.role_grade DESC,
        aetr.role_level DESC;
END;
$$;


ALTER FUNCTION "public"."get_event_attendance_summary_by_role"("p_event_id" bigint, "p_role_grade_filter" smallint, "p_role_level_filter" smallint, "p_role_level_exclude" smallint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_event_attendance_summary_by_role_and_squad"("p_event_id" bigint, "p_role_grade_filter" smallint DEFAULT NULL::smallint, "p_role_level_filter" smallint DEFAULT NULL::smallint, "p_role_level_exclude" smallint DEFAULT NULL::smallint, "p_response_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_event_code_id bigint;
    v_team_id bigint;
BEGIN
    -- Get the code_id and team_id for the event
    SELECT event_code_id, team_id INTO v_event_code_id, v_team_id
    FROM public.events
    WHERE event_id = p_event_id;

    RETURN (
    WITH
    latest_event_attendance AS (
        -- CTE 1: Find the single latest attendance response for *each* member on the event
        SELECT
            DISTINCT ON (ea.event_id, ea.member_id)
            ea.event_id,
            ea.member_id,
            ea.response_id
        FROM
            public.event_attendance ea
        WHERE
            ea.event_id = p_event_id
        ORDER BY
            ea.event_id,
            ea.member_id,
            ea.created_at DESC
    ),
    -- Members from member_team_link (traditional assignments)
    traditional_members AS (
        SELECT DISTINCT
            mtl.member_id,
            mtl.squad_id
        FROM
            public.member_team_link mtl
        WHERE
            mtl.team_id = v_team_id
            AND mtl.squad_id IS NOT NULL
    ),
    -- Members from member_squad_link (code-based assignments)
    code_based_members AS (
        SELECT DISTINCT
            msl.member_id,
            msl.squad_id
        FROM
            public.member_squad_link msl
        WHERE
            msl.code_id = v_event_code_id
            AND msl.team_id = v_team_id
            AND msl.squad_id IS NOT NULL
    ),
    -- Traditional members with their roles
    traditional_member_roles AS (
        SELECT DISTINCT
            tm.member_id,
            tm.squad_id,
            mtrl.role_id
        FROM
            traditional_members tm
            JOIN public.member_team_link mtl ON tm.member_id = mtl.member_id AND mtl.team_id = v_team_id
            JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
    ),
    -- Code-based members with their roles
    code_based_member_roles AS (
        SELECT DISTINCT
            cbm.member_id,
            cbm.squad_id,
            mtrl.role_id
        FROM
            code_based_members cbm
            JOIN public.member_team_link mtl ON cbm.member_id = mtl.member_id AND mtl.team_id = v_team_id
            JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
    ),
    all_squad_roles_for_event AS (
        -- Generates the base set of all Squads and Roles
        SELECT
            e.event_id,
            sq.squad_id,
            sq.squad_name,
            sq.grade,
            sq.squad_image,
            sq.squad_list_seq,
            r.role_id,
            r.role_name,
            r.role_level,
            r.role_grade,
            r.role_name_plural,
            r.role_list_seq
        FROM
            events e
            JOIN public.teams t ON e.team_id = t.team_id
            JOIN public.squads sq ON t.team_id = sq.team_id
            JOIN public.team_roles_link trl ON t.team_id = trl.team_id
            JOIN public.roles r ON trl.role_id = r.role_id
        WHERE
            e.event_id = p_event_id
            AND (p_role_grade_filter IS NULL OR p_role_grade_filter = 0 OR r.role_grade = p_role_grade_filter)
            AND (p_role_level_filter IS NULL OR p_role_level_filter = 0 OR r.role_level >= p_role_level_filter)
            AND (p_role_level_exclude IS NULL OR r.role_level != p_role_level_exclude)
    ),
    member_status_data_traditional AS (
        -- Traditional members with attendance status
        SELECT
            tmr.squad_id,
            tmr.role_id,
            tmr.member_id,
            lea.response_id,
            CASE
                WHEN lea.response_id = 3 THEN 'accepted'
                WHEN lea.response_id = 4 THEN 'declined'
                WHEN lea.response_id IS NULL THEN 'no_response'
                ELSE 'irrelevant'
            END AS attendance_status
        FROM
            traditional_member_roles tmr
            LEFT JOIN latest_event_attendance lea ON p_event_id = lea.event_id AND tmr.member_id = lea.member_id
    ),
    member_status_data_code_based AS (
        -- Code-based members with attendance status
        SELECT
            cbmr.squad_id,
            cbmr.role_id,
            cbmr.member_id,
            lea.response_id,
            CASE
                WHEN lea.response_id = 3 THEN 'accepted'
                WHEN lea.response_id = 4 THEN 'declined'
                WHEN lea.response_id IS NULL THEN 'no_response'
                ELSE 'irrelevant'
            END AS attendance_status
        FROM
            code_based_member_roles cbmr
            LEFT JOIN latest_event_attendance lea ON p_event_id = lea.event_id AND cbmr.member_id = lea.member_id
    ),
    squad_role_level_count AS (
        -- NEW CTE: Count members at squad level with specific role level and response matching p_response_id
        SELECT
            msd_trad.squad_id,
            r.role_level,
            COUNT(DISTINCT msd_trad.member_id) AS role_level_count
        FROM
            member_status_data_traditional msd_trad
            JOIN public.roles r ON msd_trad.role_id = r.role_id
        WHERE
            -- Filter by response_id
            CASE
                WHEN p_response_id = 3 THEN msd_trad.response_id = 3
                WHEN p_response_id = 4 THEN msd_trad.response_id = 4
                ELSE msd_trad.response_id IS NULL
            END
        GROUP BY
            msd_trad.squad_id, r.role_level
    ),
    roles_with_counts AS (
        -- Aggregates counts for each role from both sources
        SELECT
            r.event_id,
            r.squad_id,
            r.squad_name,
            r.grade,
            r.squad_image,
            r.squad_list_seq,
            r.role_id,
            r.role_name,
            r.role_list_seq,
            r.role_grade,
            r.role_level,
            r.role_name_plural,
            
            -- Traditional counts filtered by response (for member_count)
            COUNT(DISTINCT msd_trad.member_id) FILTER (
                WHERE CASE
                    WHEN p_response_id = 3 THEN msd_trad.attendance_status = 'accepted'
                    WHEN p_response_id = 4 THEN msd_trad.attendance_status = 'declined'
                    ELSE msd_trad.attendance_status = 'no_response'
                END
            ) AS member_count,
            
            -- Code-based counts filtered by response (for squad_code_count)
            COUNT(DISTINCT msd_code.member_id) FILTER (
                WHERE CASE
                    WHEN p_response_id = 3 THEN msd_code.attendance_status = 'accepted'
                    WHEN p_response_id = 4 THEN msd_code.attendance_status = 'declined'
                    ELSE msd_code.attendance_status = 'no_response'
                END
            ) AS squad_code_count,
            
            -- Total code-based members (unfiltered)
            COUNT(DISTINCT msd_code.member_id) AS member_role_count
            
        FROM
            all_squad_roles_for_event r
            LEFT JOIN member_status_data_traditional msd_trad 
                ON r.squad_id = msd_trad.squad_id AND r.role_id = msd_trad.role_id
            LEFT JOIN member_status_data_code_based msd_code 
                ON r.squad_id = msd_code.squad_id AND r.role_id = msd_code.role_id
        GROUP BY
            r.event_id, r.squad_id, r.squad_name, r.grade, r.squad_image, r.squad_list_seq, 
            r.role_id, r.role_name, r.role_list_seq, r.role_grade, r.role_level, r.role_name_plural
    ),
    squads_with_roles AS (
        -- Aggregates roles into squads
        SELECT
            rwc.event_id,
            rwc.squad_id,
            rwc.squad_name,
            rwc.grade,
            rwc.squad_image,
            rwc.squad_list_seq,
            -- Get the role_level_count for this squad (filtered by p_role_level_filter and p_response_id)
            COALESCE(
                (SELECT role_level_count 
                 FROM squad_role_level_count srlc 
                 WHERE srlc.squad_id = rwc.squad_id 
                 AND srlc.role_level = p_role_level_filter),
                0
            ) AS role_level_count,
            jsonb_agg(
                jsonb_build_object(
                    'role_id', rwc.role_id,
                    'role_name', rwc.role_name,
                    'role_name_plural', rwc.role_name_plural,
                    'role_list_seq', rwc.role_list_seq,
                    'role_grade', rwc.role_grade,
                    'role_level', rwc.role_level,
                    'member_count', rwc.member_count,
                    'squad_code_count', rwc.squad_code_count,
                    'member_role_count', rwc.member_role_count
                )
                ORDER BY rwc.role_list_seq, rwc.role_grade DESC, rwc.role_level DESC
            ) AS roles_list
        FROM
            roles_with_counts rwc
        GROUP BY
            rwc.event_id, rwc.squad_id, rwc.squad_name, rwc.grade, rwc.squad_image, rwc.squad_list_seq
    )
    -- Final SELECT
    SELECT
        jsonb_build_object(
            'event_id', sq.event_id,
            'team_name', (SELECT t.team_name FROM public.events e JOIN public.teams t ON e.team_id = t.team_id WHERE e.event_id = p_event_id LIMIT 1),
            'response_id', p_response_id,
            'squads', jsonb_agg(
                jsonb_build_object(
                    'squad_id', sq.squad_id,
                    'squad_name', sq.squad_name,
                    'squad_grade', sq.grade,
                    'squad_image', sq.squad_image,
                    'role_level_count', sq.role_level_count,  -- New field at squad level
                    'roles', sq.roles_list
                )
                ORDER BY sq.squad_list_seq, sq.grade, sq.squad_name
            )
        )
    FROM squads_with_roles sq
    GROUP BY sq.event_id
    );
END;
$$;


ALTER FUNCTION "public"."get_event_attendance_summary_by_role_and_squad"("p_event_id" bigint, "p_role_grade_filter" smallint, "p_role_level_filter" smallint, "p_role_level_exclude" smallint, "p_response_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_event_attendance_summary_by_role_and_squad_v2"("p_event_id" bigint, "p_role_grade_filter" smallint DEFAULT NULL::smallint, "p_role_level_filter" smallint DEFAULT NULL::smallint, "p_role_level_exclude" smallint DEFAULT NULL::smallint, "p_response_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_event_code_id bigint;
    v_effective_code_id bigint;
    v_team_id bigint;
    v_has_members_for_code boolean;
    v_next_code_id bigint;
    v_match_squad_available boolean;
    v_allow_lineup boolean;
BEGIN
    -- Get the event's code_id, team_id, and allow_lineup from the team
    SELECT e.event_code_id, e.team_id, t.allow_lineup
    INTO v_event_code_id, v_team_id, v_allow_lineup
    FROM public.events e
    JOIN public.teams t ON e.team_id = t.team_id
    WHERE e.event_id = p_event_id;

    -- Start with the event's code_id
    v_effective_code_id := v_event_code_id;

    -- If event has a code_id, check if it has any members
    IF v_event_code_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1
            FROM public.member_squad_link
            WHERE team_id = v_team_id
              AND code_id = v_event_code_id
            LIMIT 1
        ) INTO v_has_members_for_code;

        -- If no members found with event's code_id, find the next valid code_id in ascending order
        IF NOT v_has_members_for_code THEN
            SELECT code_id INTO v_next_code_id
            FROM public.member_squad_link
            WHERE team_id = v_team_id
              AND code_id IS NOT NULL
              AND code_id > v_event_code_id
            ORDER BY code_id ASC
            LIMIT 1;

            IF v_next_code_id IS NOT NULL THEN
                v_effective_code_id := v_next_code_id;
            ELSE
                SELECT MIN(code_id) INTO v_effective_code_id
                FROM public.member_squad_link
                WHERE team_id = v_team_id
                  AND code_id IS NOT NULL;
            END IF;
        END IF;
    ELSE
        SELECT MIN(code_id) INTO v_effective_code_id
        FROM public.member_squad_link
        WHERE team_id = v_team_id
          AND code_id IS NOT NULL;
    END IF;

    -- If still no code found, try club_code_link
    IF v_effective_code_id IS NULL THEN
        SELECT ccl.code_id INTO v_effective_code_id
        FROM public.teams t
        JOIN public.clubs c ON t.club_id = c.club_id
        JOIN public.club_code_link ccl ON c.club_id = ccl.club_id
        WHERE t.team_id = v_team_id
        ORDER BY ccl.code_id ASC
        LIMIT 1;
    END IF;

    -- Check if a match squad exists for this event
    SELECT EXISTS (
        SELECT 1
        FROM public.match_squads
        WHERE event_id = p_event_id
        LIMIT 1
    ) INTO v_match_squad_available;

    RETURN (
    WITH
    latest_event_attendance AS (
        SELECT
            DISTINCT ON (ea.event_id, ea.member_id)
            ea.event_id,
            ea.member_id,
            ea.response_id
        FROM
            public.event_attendance ea
        WHERE
            ea.event_id = p_event_id
        ORDER BY
            ea.event_id,
            ea.member_id,
            ea.created_at DESC
    ),
    actual_member_squad_roles_for_event AS (
        SELECT DISTINCT
            e.event_id,
            msl.member_id,
            msl.squad_id,
            mtrl.role_id
        FROM
            events e
            JOIN public.member_squad_link msl ON e.team_id = msl.team_id
                AND msl.code_id = v_effective_code_id
            JOIN public.member_team_link mtl ON msl.member_id = mtl.member_id
                AND msl.team_id = mtl.team_id
            JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        WHERE
            e.event_id = p_event_id
            AND msl.squad_id IS NOT NULL
    ),
    all_squad_roles_for_event AS (
        SELECT
            e.event_id,
            sq.squad_id,
            sq.squad_name,
            sq.grade,
            sq.squad_image,
            sq.squad_list_seq,
            r.role_id,
            r.role_name,
            r.role_level,
            r.role_grade,
            r.role_name_plural,
            r.role_list_seq
        FROM
            events e
            JOIN public.teams t ON e.team_id = t.team_id
            JOIN public.squads sq ON t.team_id = sq.team_id
            JOIN public.team_roles_link trl ON t.team_id = trl.team_id
            JOIN public.roles r ON trl.role_id = r.role_id
        WHERE
            e.event_id = p_event_id
            AND (p_role_grade_filter IS NULL OR p_role_grade_filter = 0 OR r.role_grade = p_role_grade_filter)
            AND (p_role_level_filter IS NULL OR p_role_level_filter = 0 OR r.role_level >= p_role_level_filter)
            AND (p_role_level_exclude IS NULL OR r.role_level != p_role_level_exclude)
    ),
    member_status_data AS (
        SELECT
            amsr.event_id,
            amsr.squad_id,
            amsr.role_id,
            amsr.member_id,
            lea.response_id,
            CASE
                WHEN lea.response_id = 3 THEN 'accepted'
                WHEN lea.response_id = 4 THEN 'declined'
                WHEN lea.response_id IS NULL AND amsr.member_id IS NOT NULL THEN 'no_response'
                ELSE 'irrelevant'
            END AS attendance_status
        FROM
            actual_member_squad_roles_for_event amsr
            LEFT JOIN latest_event_attendance lea ON amsr.event_id = lea.event_id AND amsr.member_id = lea.member_id
        WHERE
            amsr.member_id IS NOT NULL
    ),
    squad_dynamic_role_count AS (
        SELECT
            msd.squad_id,
            COUNT(DISTINCT msd.member_id) AS dynamic_member_count
        FROM
            member_status_data msd
            JOIN public.roles r ON msd.role_id = r.role_id
        WHERE
            (p_role_level_filter IS NULL OR p_role_level_filter = 0 OR r.role_level = p_role_level_filter)
            AND (
                (p_response_id IN (3, 4) AND msd.response_id = p_response_id)
                OR (p_response_id IS NULL OR p_response_id NOT IN (3, 4) AND msd.response_id IS NULL)
            )
        GROUP BY
            msd.squad_id
    ),
    roles_with_counts AS (
        SELECT
            r.event_id,
            r.squad_id,
            r.squad_name,
            r.grade,
            r.squad_image,
            r.squad_list_seq,
            r.role_id,
            r.role_name,
            r.role_list_seq,
            r.role_grade,
            r.role_level,
            r.role_name_plural,
            COUNT(msd.member_id) FILTER (WHERE msd.attendance_status = 'accepted') AS accepted_count,
            COUNT(msd.member_id) FILTER (WHERE msd.attendance_status = 'declined') AS declined_count,
            COUNT(msd.member_id) FILTER (WHERE msd.attendance_status = 'no_response') AS no_response_count
        FROM
            all_squad_roles_for_event r
            LEFT JOIN member_status_data msd ON r.event_id = msd.event_id
                                            AND r.squad_id = msd.squad_id
                                            AND r.role_id = msd.role_id
        GROUP BY
            r.event_id, r.squad_id, r.squad_name, r.grade, r.squad_image, r.squad_list_seq,
            r.role_id, r.role_name, r.role_list_seq, r.role_grade, r.role_level, r.role_name_plural
    ),
    squads_with_roles AS (
        SELECT
            rwc.event_id,
            rwc.squad_id,
            rwc.squad_name,
            rwc.grade,
            rwc.squad_image,
            rwc.squad_list_seq,
            COALESCE(MAX(sdrc.dynamic_member_count), 0) AS role_level_count,
            jsonb_agg(
                jsonb_build_object(
                    'role_id', rwc.role_id,
                    'role_name', rwc.role_name,
                    'role_name_plural', rwc.role_name_plural,
                    'role_list_seq', rwc.role_list_seq,
                    'role_grade', rwc.role_grade,
                    'role_level', rwc.role_level,
                    'member_count', CASE
                        WHEN p_response_id = 3 THEN rwc.accepted_count
                        WHEN p_response_id = 4 THEN rwc.declined_count
                        ELSE rwc.no_response_count
                    END
                )
                ORDER BY rwc.role_list_seq, rwc.role_grade DESC, rwc.role_level DESC
            ) AS roles_list
        FROM
            roles_with_counts rwc
            LEFT JOIN squad_dynamic_role_count sdrc ON rwc.squad_id = sdrc.squad_id
        GROUP BY
            rwc.event_id, rwc.squad_id, rwc.squad_name, rwc.grade, rwc.squad_image, rwc.squad_list_seq
    )
    SELECT
        jsonb_build_object(
            'event_id',             sq.event_id,
            'team_name',            (SELECT t.team_name FROM public.events e JOIN public.teams t ON e.team_id = t.team_id WHERE e.event_id = p_event_id LIMIT 1),
            'allow_lineup',         v_allow_lineup,
            'response_id',          p_response_id,
            'event_code_id',        v_event_code_id,
            'effective_code_id',    v_effective_code_id,
            'used_fallback',        (v_effective_code_id != v_event_code_id OR v_event_code_id IS NULL),
            'match_squad_available', v_match_squad_available,
            'squads', jsonb_agg(
                jsonb_build_object(
                    'squad_id',         sq.squad_id,
                    'squad_name',       sq.squad_name,
                    'squad_grade',      sq.grade,
                    'squad_image',      sq.squad_image,
                    'role_level_count', sq.role_level_count,
                    'roles',            sq.roles_list
                )
                ORDER BY sq.squad_list_seq, sq.grade, sq.squad_name
            )
        )
    FROM squads_with_roles sq
    GROUP BY sq.event_id
    );
END;
$$;


ALTER FUNCTION "public"."get_event_attendance_summary_by_role_and_squad_v2"("p_event_id" bigint, "p_role_grade_filter" smallint, "p_role_level_filter" smallint, "p_role_level_exclude" smallint, "p_response_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_event_car_pools"("p_event_id" bigint, "p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    AS $$

WITH event_context AS (
    -- 1. Identify the Team for this event
    SELECT team_id FROM public.events WHERE event_id = p_event_id
),
open_car_pools AS (
    -- 2. Get all OPEN car pools for the event
    SELECT
        cp.car_pool_id,
        cp.user_id,
        cp.number_of_seats,
        cp.created_at
    FROM
        public.car_pool AS cp
    WHERE
        cp.event_id = p_event_id
        AND cp.status = 'open'
),
car_pool_reservations AS (
    -- 3. Calculate reserved seats
    SELECT
        cpd.car_pool_id,
        COUNT(cpd.id) AS reserved_count
    FROM
        public.car_pool_detail AS cpd
    WHERE
        EXISTS (SELECT 1 FROM open_car_pools ocp WHERE ocp.car_pool_id = cpd.car_pool_id)
    GROUP BY 1
),
user_stats AS (
    -- 4. Get the current user's role level and count their associated players
    SELECT 
        MAX(r.role_level) AS user_role_level, 
        COUNT(DISTINCT uml.member_id) FILTER (WHERE r.role_level = 10) AS player_count,
        EXISTS (
            SELECT 1 FROM open_car_pools ocp WHERE ocp.user_id = p_user_id
        ) AS has_open_pool
    FROM 
        public.user_member_link uml
    JOIN 
        public.member_team_link mtl ON uml.member_id = mtl.member_id
    JOIN 
        public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN 
        public.roles r ON mtrl.role_id = r.role_id
    WHERE 
        uml.user_id = p_user_id
        AND mtl.team_id = (SELECT team_id FROM event_context)
),
formatted_pools AS (
    -- 5. Format the list of car pools into a JSON array
    SELECT
        jsonb_agg(
            jsonb_build_object(
                'car_pool_id', ocp.car_pool_id,
                'driver_user_id', ocp.user_id,
                'driver_name', u.first_name || ' ' || u.last_name,
                'total_seats', ocp.number_of_seats,
                'reserved_seats', COALESCE(cpr.reserved_count, 0),
                'free_seats', (ocp.number_of_seats - COALESCE(cpr.reserved_count, 0)),
                'created_at', ocp.created_at
            ) ORDER BY ocp.created_at ASC
        ) AS pools_list
    FROM
        open_car_pools AS ocp
    JOIN
        public.users AS u ON ocp.user_id = u.user_id
    LEFT JOIN
        car_pool_reservations AS cpr ON ocp.car_pool_id = cpr.car_pool_id
)
SELECT
    jsonb_build_object(
        'current_user_has_pool', COALESCE(us.has_open_pool, false),
        'current_user_role_level', COALESCE(us.user_role_level, 0),
        'associated_players_count', COALESCE(us.player_count, 0),
        'car_pools', COALESCE(fp.pools_list, '[]'::jsonb)
    )
FROM
    user_stats AS us
CROSS JOIN
    formatted_pools AS fp;

$$;


ALTER FUNCTION "public"."get_event_car_pools"("p_event_id" bigint, "p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_event_context_and_next_code"("p_event_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_event_code_id bigint;
    v_team_id bigint;
    v_team_name text;
    v_club_id bigint;
    v_club_name text;
    v_effective_code_id bigint;
BEGIN
    -- 1. Get the base Event, Team, and Club info by assigning to explicit variables
    SELECT 
        e.event_code_id,
        t.team_id,
        t.team_name,
        c.club_id,
        c.club_name
    INTO 
        v_event_code_id, 
        v_team_id,
        v_team_name,
        v_club_id,
        v_club_name
    FROM public.events e
    JOIN public.teams t ON e.team_id = t.team_id
    JOIN public.clubs c ON t.club_id = c.club_id
    WHERE e.event_id = p_event_id;

    -- 2. Logic: If code is 1, find the "Next" code for this club via club_code_link
    IF v_event_code_id = 1 THEN
        SELECT ccl.code_id INTO v_effective_code_id
        FROM public.club_code_link ccl
        WHERE ccl.club_id = v_club_id
          AND ccl.code_id > 1
        ORDER BY ccl.code_id ASC
        LIMIT 1;

        -- Fallback: If no code exists > 1, take the lowest available code for the club
        IF v_effective_code_id IS NULL THEN
            SELECT MIN(code_id) INTO v_effective_code_id
            FROM public.club_code_link
            WHERE club_id = v_club_id;
        END IF;
    ELSE
        -- If it's not 1 (e.g., 2, 3, 4), use the actual assigned code
        v_effective_code_id := v_event_code_id;
    END IF;

    -- 3. Return the unified JSON object
    RETURN (
        SELECT jsonb_build_object(
            'event_id', p_event_id,
            'team_id', v_team_id,
            'team_name', v_team_name,
            'club_id', v_club_id,
            'club_name', v_club_name,
            'original_code_id', v_event_code_id,
            'effective_code_id', v_effective_code_id,
            'code_name', COALESCE(ec.event_code, 'Standard Squad')
        )
        FROM (SELECT v_effective_code_id as id) as lookup
        LEFT JOIN public.event_codes ec ON ec.code_id = lookup.id
    );
END;
$$;


ALTER FUNCTION "public"."get_event_context_and_next_code"("p_event_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_event_payment_details_v2"("p_event_id" bigint) RETURNS TABLE("user_full_name" "text", "member_full_name" "text", "payment_date" "text", "payment_id" bigint, "event_id" bigint, "user_id" "uuid", "event_title" "text", "stripe_session_id" "text", "payment_status" "text", "amount_paid" integer, "stripe_payment_intent_id" "text", "stripe_checkout_url" "text", "fee_amount" smallint, "net_amount" smallint, "tax_amount" smallint, "gross_amount" smallint, "member_id" bigint)
    LANGUAGE "sql"
    AS $$
    SELECT
        -- The User (Payer) Name
        u.first_name || ' ' || u.last_name AS user_full_name,

        -- The Member (Whose payment it is for) Name
        m.first_name || ' ' || m.last_name AS member_full_name,

        -- Format the timestamp into a pretty date string
        TO_CHAR(eump.created_at, 'DD Mon YYYY') AS payment_date, 

        -- Select remaining columns from event_user_member_payment (eump)
        eump.payment_id,
        eump.event_id,
        eump.user_id,
        eump.event_title,
        eump.stripe_session_id,
        eump.payment_status,
        eump.amount_paid,
        eump.stripe_payment_intent_id,
        eump.stripe_checkout_url,
        eump.fee_amount,
        eump.net_amount,
        eump.tax_amount,
        eump.gross_amount,
        eump.member_id
    FROM
        public.event_user_member_payment eump
    JOIN
        public.users u ON eump.user_id = u.user_id
    JOIN
        public.members m ON eump.member_id = m.member_id
    WHERE
        eump.event_id = p_event_id
        AND eump.payment_status = 'confirmed';
$$;


ALTER FUNCTION "public"."get_event_payment_details_v2"("p_event_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_event_payment_summary"("p_event_id" bigint) RETURNS TABLE("total_payments" bigint, "total_amount_paid" numeric, "total_net_amount" numeric)
    LANGUAGE "sql"
    AS $$
    SELECT
        -- 1. Count the number of successful payment records (identified by a session ID)
        COUNT(eup.stripe_session_id) AS total_payments,
        
        -- 2. Sum the gross amounts paid.
        COALESCE(SUM(eup.amount_paid), 0) AS total_amount_paid,
        
        -- 3. Calculate the Total Net Amount (Total Gross - Total Fees - Total Tax)
        COALESCE(
            SUM(eup.amount_paid)::numeric - 
            COALESCE(SUM(eup.fee_amount), 0)::numeric - 
            COALESCE(SUM(eup.tax_amount), 0)::numeric, 
            0
        ) AS total_net_amount
    FROM
        public.event_user_payment eup
    WHERE
        eup.event_id = p_event_id
        -- CRITICAL: Only include payments that have been confirmed as 'confirmed'
        AND eup.payment_status = 'confirmed';
$$;


ALTER FUNCTION "public"."get_event_payment_summary"("p_event_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_event_payments_details"("p_event_id" bigint) RETURNS TABLE("user_full_name" "text", "payment_date" "text", "payment_id" bigint, "event_id" bigint, "user_id" "uuid", "event_title" "text", "stripe_session_id" "text", "payment_status" "text", "amount_paid" integer, "stripe_payment_intent_id" "text", "stripe_checkout_url" "text", "fee_amount" smallint, "net_amount" smallint, "tax_amount" smallint, "gross_amount" smallint)
    LANGUAGE "sql"
    AS $$
    SELECT
        -- Concatenate first_name and last_name
        u.first_name || ' ' || u.last_name AS user_full_name,

        -- Format the timestamp into a pretty date string
        -- Example Output: '05 Nov 2025' or '05 November 2025'
        TO_CHAR(eup.created_at, 'DD Mon YYYY') AS payment_date, 

        -- Select remaining columns from event_user_payment (eup)
        eup.payment_id,
        eup.event_id,
        eup.user_id,
        eup.event_title,
        eup.stripe_session_id,
        eup.payment_status,
        eup.amount_paid,
        eup.stripe_payment_intent_id,
        eup.stripe_checkout_url,
        eup.fee_amount,
        eup.net_amount,
        eup.tax_amount,
        eup.gross_amount
    FROM
        public.event_user_payment eup
    JOIN
        public.users u ON eup.user_id = u.user_id
    WHERE
        eup.event_id = p_event_id
        AND eup.payment_status = 'confirmed';
$$;


ALTER FUNCTION "public"."get_event_payments_details"("p_event_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_event_team_members_for_user"("p_event_id" bigint, "p_user_id" "uuid") RETURNS TABLE("member_id" bigint, "first_name" "text", "last_name" "text", "event_team_id" bigint, "member_team_link_id" bigint)
    LANGUAGE "sql"
    AS $$
WITH event_team AS (
    -- 1. Find the primary Team ID associated with the Event (MUST have a value)
    SELECT team_id
    FROM public.events
    WHERE event_id = p_event_id
)
SELECT
    m.member_id,
    m.first_name,
    m.last_name,
    et.team_id AS event_team_id,
    mtl.member_team_id AS member_team_link_id
FROM
    public.members m
JOIN
    public.user_member_link uml ON m.member_id = uml.member_id -- Member linked to User (Filter 1)
JOIN
    public.member_team_link mtl ON m.member_id = mtl.member_id -- Member linked to Team (Link required for Filter 2)
JOIN
    event_team et ON mtl.team_id = et.team_id
WHERE
    uml.user_id = p_user_id
    AND et.team_id IS NOT NULL -- Ensures the event actually has a team assigned
ORDER BY
    m.last_name, m.first_name;
$$;


ALTER FUNCTION "public"."get_event_team_members_for_user"("p_event_id" bigint, "p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_event_team_members_with_attendance"("p_event_id" bigint, "p_user_id" "uuid") RETURNS TABLE("member_id" bigint, "first_name" "text", "last_name" "text", "profile_pic" "text", "response_value" "text", "response_icon" "text", "display_value" "text", "icon_link" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        m.member_id,
        m.first_name,
        m.last_name,
        m.profile_pic,
        ert.response_value,
        ert.response_icon,
        ert.display_value,
        ert.icon_link
    FROM
        public.events AS e
    INNER JOIN
        public.member_team_link AS mtl ON e.team_id = mtl.team_id
    INNER JOIN
        public.members AS m ON mtl.member_id = m.member_id
    INNER JOIN
        public.user_member_link AS uml ON m.member_id = uml.member_id
    LEFT JOIN (
        SELECT
            event_attendance.member_id,
            event_attendance.response_id,
            ROW_NUMBER() OVER(PARTITION BY event_attendance.member_id ORDER BY event_attendance.created_at DESC) as rn
        FROM
            public.event_attendance
        WHERE
            event_attendance.event_id = p_event_id
    ) AS ea ON m.member_id = ea.member_id AND ea.rn = 1
    LEFT JOIN
        public.event_response_type AS ert ON ea.response_id = ert.response_id
    WHERE
        e.event_id = p_event_id AND uml.user_id = p_user_id;
END;
$$;


ALTER FUNCTION "public"."get_event_team_members_with_attendance"("p_event_id" bigint, "p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_events_list"("p_date_from" "text" DEFAULT NULL::"text", "p_date_to" "text" DEFAULT NULL::"text", "p_team_id" bigint DEFAULT NULL::bigint, "p_code_id" bigint DEFAULT NULL::bigint, "p_type_id" bigint DEFAULT NULL::bigint, "p_opposition" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$

WITH sanitized_filters AS (
    -- Convert raw inputs: "" to NULL for dates, 0 to NULL for IDs.
    SELECT
        NULLIF(TRIM(p_date_from), '') AS filter_date_from,
        NULLIF(TRIM(p_date_to), '') AS filter_date_to,
        
        NULLIF(p_team_id, 0) AS filter_team_id,
        NULLIF(p_code_id, 0) AS filter_code_id,
        NULLIF(p_type_id, 0) AS filter_type_id,
        NULLIF(TRIM(p_opposition), '') AS filter_opposition -- NEW: Opposition filter value
),
filtered_events AS (
    -- Filter and pre-process event data
    SELECT
        e.*,
        t.team_name,
        t.team_female,
        t.club_id,
        et.event_type,
        ec.event_code,
        event_role.role_level AS event_role_level,
        -- The display format still uses the original date field
        to_char(e.event_date_time::timestamp, 'FMDay, DD Month, YYYY at HH24:MI') AS event_date_time_formatted,
        
        -- START MODIFIED LOGIC for effective_event_title (incorporates conditional opposition and gender swap)
        CASE
            -- 1. Check for Gender Substitution (Hurling/Camogie)
            WHEN t.team_female = TRUE AND 
                (
                    -- Logic to calculate base title for the LIKE check (this ensures all title generation paths are checked)
                    CASE
                        -- 1a. If event_title is populated, use it.
                        WHEN e.event_title IS NOT NULL AND TRIM(e.event_title) <> '' THEN e.event_title
                        -- 1b. If event_title is empty/NULL and it's a 'Match'
                        WHEN et.event_type = 'Match' THEN 
                            CASE
                                -- Opposition included for Match type if present
                                WHEN e.opposition IS NOT NULL AND TRIM(e.opposition) <> '' THEN
                                    CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type, ' (', e.opposition, ')')
                                -- No opposition
                                ELSE
                                    CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type)
                            END
                        -- 1c. If event_title is empty/NULL and it's NOT a 'Match'
                        ELSE CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type)
                    END
                ) LIKE '%Hurling%' 
            THEN
                -- If female team AND title contains 'Hurling', apply REPLACE to the base title
                REPLACE(
                    CASE
                        WHEN e.event_title IS NOT NULL AND TRIM(e.event_title) <> '' THEN e.event_title
                        WHEN et.event_type = 'Match' THEN 
                            CASE
                                WHEN e.opposition IS NOT NULL AND TRIM(e.opposition) <> '' THEN
                                    CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type, ' (', e.opposition, ')')
                                ELSE
                                    CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type)
                            END
                        ELSE CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type)
                    END
                , 'Hurling', 'Camogie')

            -- 2. ELSE: Use the base title calculation without substitution (Male team or non-Hurling event)
            ELSE
                CASE
                    WHEN e.event_title IS NOT NULL AND TRIM(e.event_title) <> '' THEN e.event_title
                    WHEN et.event_type = 'Match' THEN 
                        CASE
                            WHEN e.opposition IS NOT NULL AND TRIM(e.opposition) <> '' THEN
                                CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type, ' (', e.opposition, ')')
                            ELSE
                                CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type)
                        END
                    ELSE CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type)
                END
        END AS effective_event_title
        -- END MODIFIED LOGIC
    FROM
        public.events AS e
    CROSS JOIN 
        sanitized_filters AS sf
    JOIN
        public.teams AS t ON e.team_id = t.team_id
    JOIN
        public.event_types AS et ON e.event_type_id = et.event_type_id
    LEFT JOIN
        public.event_codes AS ec ON e.event_code_id = ec.code_id
    LEFT JOIN
        public.roles AS event_role ON e.audience_id = event_role.role_id
    WHERE
        -- 1. Date Range Filtering: NOW USING e.event_date_time_2
        e.event_date_time_2 >= COALESCE(sf.filter_date_from::timestamp with time zone, '1900-01-01 00:00:00'::timestamp with time zone)
        AND e.event_date_time_2 <= COALESCE(sf.filter_date_to::timestamp with time zone, '2100-01-01 00:00:00'::timestamp with time zone)
        
        -- 2. ID Filtering (Handles NULL/0 for no filter)
        AND (sf.filter_team_id IS NULL OR e.team_id = sf.filter_team_id)
        AND (sf.filter_code_id IS NULL OR e.event_code_id = sf.filter_code_id)
        AND (sf.filter_type_id IS NULL OR e.event_type_id = sf.filter_type_id)
        
        -- 3. NEW: Opposition Filtering (Case-insensitive partial match)
        AND (sf.filter_opposition IS NULL OR e.opposition ILIKE ('%' || sf.filter_opposition || '%'))
),
all_team_members AS (
    SELECT fe.event_id, mtl.member_id
    FROM filtered_events AS fe
    JOIN public.member_team_link AS mtl ON fe.team_id = mtl.team_id
    JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.roles AS r_member ON mtrl.role_id = r_member.role_id
    WHERE
        (
            (fe.event_role_level = 10 AND r_member.role_level = 10)
            OR (fe.event_role_level > 10 AND r_member.role_level >= fe.event_role_level)
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
    COALESCE(
        json_agg(final_result)::jsonb 
    , '[]'::jsonb) 
FROM
(
    SELECT
        fe.event_id, fe.effective_event_title AS event_title, fe.meet_time, fe.event_date_time_formatted,
        fe.team_name, fe.team_id, fe.club_id, fe.request_attendance, fe.event_type, fe.event_link,
        fe.event_code, fe.location_name, fe.location_pin, fe.opposition, fe.event_details,
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


ALTER FUNCTION "public"."get_events_list"("p_date_from" "text", "p_date_to" "text", "p_team_id" bigint, "p_code_id" bigint, "p_type_id" bigint, "p_opposition" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_full_car_pool_details"("p_car_pool_id" bigint, "p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    AS $$

WITH car_pool_context AS (
    SELECT
        cp.car_pool_id,
        u.user_id AS driver_user_id,
        u.first_name || ' ' || u.last_name AS driver_name,
        u.email_address AS driver_email,
        u.phone_number AS driver_phone,
        cp.number_of_seats AS total_seats,
        cp.status,
        cp.event_id,
        e.event_title,
        to_char(e.event_date_time_2::timestamp, 'FMDay, DD FMMonth, YYYY at HH24:MI') AS event_date_formatted,
        e.team_id,
        t.team_name,
        cp.created_at
    FROM
        public.car_pool AS cp
    JOIN
        public.users AS u ON cp.user_id = u.user_id
    LEFT JOIN 
        public.events AS e ON cp.event_id = e.event_id
    LEFT JOIN 
        public.teams AS t ON e.team_id = t.team_id
    WHERE
        cp.car_pool_id = p_car_pool_id
),
reserved_members AS (
    SELECT
        jsonb_agg(
            jsonb_build_object(
                'reservation_id', sub.reservation_id,
                'member_id', sub.member_id,
                'member_name', sub.member_name,
                'profile_pic', sub.profile_pic,
                'reserved_at', sub.reserved_at,
                'status', sub.status,
                -- ✅ Key changed back to singular 'associated_user_email'
                'associated_user_email', sub.emails_string, 
                'member_belongs_to_user', sub.belongs_to_user
            ) ORDER BY sub.reserved_at ASC
        ) AS members_list,
        COUNT(sub.member_id) AS reserved_count
    FROM (
        SELECT 
            cpd.id AS reservation_id,
            m.member_id,
            m.first_name || ' ' || m.last_name AS member_name,
            m.profile_pic,
            cpd.created_at AS reserved_at,
            cpd.status,
            -- ✅ Still comma-delimited for your Edge Function's split logic
            string_agg(DISTINCT u_assoc.email_address, ', ') FILTER (WHERE u_assoc.email_address IS NOT NULL) AS emails_string,
            BOOL_OR(u_assoc.user_id = p_user_id) AS belongs_to_user
        FROM
            public.car_pool_detail AS cpd
        JOIN
            public.members AS m ON cpd.member_id = m.member_id
        LEFT JOIN 
            public.user_member_link uml ON m.member_id = uml.member_id
        LEFT JOIN 
            public.users u_assoc ON uml.user_id = u_assoc.user_id
        WHERE
            cpd.car_pool_id = p_car_pool_id
        GROUP BY 
            cpd.id, m.member_id, m.first_name, m.last_name, m.profile_pic, cpd.created_at, cpd.status
    ) sub
),
user_eligible_members AS (
    SELECT 
        jsonb_agg(
            jsonb_build_object(
                'member_id', m.member_id,
                'member_name', m.first_name || ' ' || m.last_name,
                'profile_pic', m.profile_pic
            )
        ) AS eligible_list,
        COUNT(DISTINCT m.member_id) AS player_count
    FROM 
        public.user_member_link uml
    JOIN 
        public.members m ON uml.member_id = m.member_id
    JOIN 
        public.member_team_link mtl ON m.member_id = mtl.member_id
    JOIN 
        public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN 
        public.roles r ON mtrl.role_id = r.role_id
    WHERE 
        uml.user_id = p_user_id
        AND mtl.team_id = (SELECT team_id FROM car_pool_context)
        AND r.role_level = 10
)
SELECT
    jsonb_build_object(
        'car_pool_id', ctx.car_pool_id,
        'driver_user_id', ctx.driver_user_id,
        'driver_name', ctx.driver_name,
        'driver_email', ctx.driver_email,
        'driver_phone', ctx.driver_phone,
        'event_title', ctx.event_title,
        'event_date_formatted', ctx.event_date_formatted,
        'team_name', ctx.team_name,
        'total_seats', ctx.total_seats,
        'reserved_seats', COALESCE(rm.reserved_count, 0),
        'free_seats', (ctx.total_seats - COALESCE(rm.reserved_count, 0)),
        'status', ctx.status,
        'event_id', ctx.event_id,
        'team_id', ctx.team_id,
        'created_at', ctx.created_at,
        'reservations', COALESCE(rm.members_list, '[]'::jsonb),
        'user_associated_members', COALESCE(uem.eligible_list, '[]'::jsonb),
        'associated_players_count', COALESCE(uem.player_count, 0)
    )
FROM
    car_pool_context AS ctx
CROSS JOIN
    reserved_members AS rm
CROSS JOIN
    user_eligible_members AS uem;

$$;


ALTER FUNCTION "public"."get_full_car_pool_details"("p_car_pool_id" bigint, "p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_member_match_stats"("p_team_name" "text", "p_event_code" "text", "p_event_type" "text", "p_from_date" "date") RETURNS TABLE("result" json)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_squad_columns TEXT := '';
    v_squad_record RECORD;
    v_sql TEXT;
BEGIN
    -- Build a dynamic column for each squad belonging to this team
    FOR v_squad_record IN
        SELECT s.squad_name
        FROM public.squads s
        JOIN public.teams t ON s.team_id = t.team_id
        WHERE t.team_name = p_team_name
        ORDER BY s.squad_list_seq, s.squad_name
    LOOP
        v_squad_columns := v_squad_columns || format(
            ', COUNT(DISTINCT CASE WHEN s.squad_name = %L THEN msd.event_id END) AS %I',
            v_squad_record.squad_name,
            lower(replace(v_squad_record.squad_name, ' ', '_')) || '_appearances'
        );
    END LOOP;

    -- Build and execute the full dynamic query
    v_sql := format('
        SELECT json_agg(row_to_json(t)) FROM (
            SELECT
                m.first_name || '' '' || m.last_name AS member_name,

                -- Total matches for the team regardless of member response
                COUNT(DISTINCT e.event_id) AS all_matches
                %s,
                COUNT(DISTINCT msd.event_id) AS total_squad_selections

            FROM public.members m

            JOIN public.member_team_link mtl ON m.member_id = mtl.member_id
            JOIN public.teams t ON mtl.team_id = t.team_id

            JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
            JOIN public.roles r ON mtrl.role_id = r.role_id AND r.role_level = 10

            JOIN public.events e ON e.team_id = t.team_id
            JOIN public.event_codes ec ON e.event_code_id = ec.code_id
            JOIN public.event_types et ON e.event_type_id = et.event_type_id

            LEFT JOIN (
                SELECT DISTINCT ON (member_id, event_id)
                    id, event_id, member_id, squad_id, team_id
                FROM public.match_squad_details
                ORDER BY member_id, event_id, id DESC
            ) msd
                ON msd.event_id = e.event_id
                AND msd.member_id = m.member_id
                AND msd.team_id = t.team_id

            LEFT JOIN public.squads s ON msd.squad_id = s.squad_id

            WHERE
                t.team_name = %L
                AND ec.event_code = %L
                AND et.event_type = %L
                AND e.event_date_time >= %L
                AND e.event_date_time <= NOW()

            GROUP BY
                m.member_id,
                m.first_name,
                m.last_name

            ORDER BY
                total_squad_selections DESC,
                member_name ASC
        ) t',
        v_squad_columns,
        p_team_name,
        p_event_code,
        p_event_type,
        p_from_date
    );

    RETURN QUERY EXECUTE 'SELECT json_agg(row_to_json(t)) FROM (' || v_sql || ') t';
END;
$$;


ALTER FUNCTION "public"."get_member_match_stats"("p_team_name" "text", "p_event_code" "text", "p_event_type" "text", "p_from_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_member_match_stats_detail"("p_team_name" "text", "p_event_code" "text", "p_event_type" "text", "p_from_date" "date") RETURNS TABLE("result" json)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_sql TEXT;
BEGIN
    v_sql := format('
        SELECT json_agg(row_to_json(outer_t)) FROM (
            SELECT
                inner_t.member_name,
                totals.total_matches,
                totals.total_squad_selections,
                totals.total_accepted,
                totals.total_declined,
                totals.total_no_response,
                json_agg(
                    json_build_object(
                        ''event_id'', inner_t.event_id,
                        ''event_date_time'', inner_t.event_date_time,
                        ''opposition'', inner_t.opposition,
                        ''event_code'', inner_t.event_code,
                        ''event_type'', inner_t.event_type,
                        ''squad_name'', inner_t.squad_name,
                        ''attendance_response'', inner_t.attendance_response
                    )
                    ORDER BY inner_t.event_date_time ASC
                ) AS events

            FROM (
                SELECT
                    m.member_id,
                    m.first_name || '' '' || m.last_name AS member_name,
                    e.event_id,
                    e.event_date_time,
                    e.opposition,
                    ec.event_code,
                    et.event_type,
                    s.squad_name,
                    ert.display_value AS attendance_response,
                    ea.response_id

                FROM public.members m

                JOIN public.member_team_link mtl ON m.member_id = mtl.member_id
                JOIN public.teams t ON mtl.team_id = t.team_id

                JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
                JOIN public.roles r ON mtrl.role_id = r.role_id AND r.role_level = 10

                JOIN public.events e ON e.team_id = t.team_id
                JOIN public.event_codes ec ON e.event_code_id = ec.code_id
                JOIN public.event_types et ON e.event_type_id = et.event_type_id

                -- Latest attendance response per member per event
                LEFT JOIN (
                    SELECT event_id, member_id, response_id
                    FROM (
                        SELECT
                            event_id,
                            member_id,
                            response_id,
                            ROW_NUMBER() OVER (
                                PARTITION BY member_id, event_id
                                ORDER BY created_at DESC
                            ) AS rn
                        FROM public.event_attendance
                    ) latest
                    WHERE rn = 1
                ) ea
                    ON ea.event_id = e.event_id
                    AND ea.member_id = m.member_id

                LEFT JOIN public.event_response_type ert ON ea.response_id = ert.response_id

                -- Latest match_squad_details per member per event
                -- ordered by match_squad_id DESC to pick the most recently created squad run
                LEFT JOIN (
                    SELECT DISTINCT ON (member_id, event_id)
                        id, event_id, member_id, squad_id, team_id
                    FROM public.match_squad_details
                    ORDER BY member_id, event_id, match_squad_id DESC
                ) msd
                    ON msd.event_id = e.event_id
                    AND msd.member_id = m.member_id
                    AND msd.team_id = t.team_id

                -- Only show squad if member accepted (response_id = 3)
                LEFT JOIN public.squads s
                    ON msd.squad_id = s.squad_id
                    AND ea.response_id = 3

                WHERE
                    t.team_name = %L
                    AND ec.event_code = %L
                    AND et.event_type = %L
                    AND e.event_date_time >= %L
                    AND e.event_date_time <= NOW()

            ) inner_t

            -- Totals calculated separately
            JOIN (
                SELECT
                    m.member_id,
                    COUNT(DISTINCT e.event_id) AS total_matches,
                    COUNT(DISTINCT msd.event_id) AS total_squad_selections,

                    -- Attendance totals based on latest response per member per event
                    COUNT(DISTINCT CASE WHEN ea.response_id = 3 THEN e.event_id END) AS total_accepted,
                    COUNT(DISTINCT CASE WHEN ea.response_id = 4 THEN e.event_id END) AS total_declined,
                    COUNT(DISTINCT CASE WHEN ea.response_id IS NULL THEN e.event_id END) AS total_no_response

                FROM public.members m

                JOIN public.member_team_link mtl ON m.member_id = mtl.member_id
                JOIN public.teams t ON mtl.team_id = t.team_id

                JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
                JOIN public.roles r ON mtrl.role_id = r.role_id AND r.role_level = 10

                JOIN public.events e ON e.team_id = t.team_id
                JOIN public.event_codes ec ON e.event_code_id = ec.code_id
                JOIN public.event_types et ON e.event_type_id = et.event_type_id

                -- Latest attendance response per member per event
                LEFT JOIN (
                    SELECT event_id, member_id, response_id
                    FROM (
                        SELECT
                            event_id,
                            member_id,
                            response_id,
                            ROW_NUMBER() OVER (
                                PARTITION BY member_id, event_id
                                ORDER BY created_at DESC
                            ) AS rn
                        FROM public.event_attendance
                    ) latest
                    WHERE rn = 1
                ) ea
                    ON ea.event_id = e.event_id
                    AND ea.member_id = m.member_id

                -- Latest match_squad_details per member per event
                -- ordered by match_squad_id DESC to pick the most recently created squad run
                LEFT JOIN (
                    SELECT DISTINCT ON (member_id, event_id)
                        id, event_id, member_id, squad_id, team_id
                    FROM public.match_squad_details
                    ORDER BY member_id, event_id, match_squad_id DESC
                ) msd
                    ON msd.event_id = e.event_id
                    AND msd.member_id = m.member_id
                    AND msd.team_id = t.team_id

                WHERE
                    t.team_name = %L
                    AND ec.event_code = %L
                    AND et.event_type = %L
                    AND e.event_date_time >= %L
                    AND e.event_date_time <= NOW()

                GROUP BY m.member_id
            ) totals ON totals.member_id = inner_t.member_id

            GROUP BY
                inner_t.member_id,
                inner_t.member_name,
                totals.total_matches,
                totals.total_squad_selections,
                totals.total_accepted,
                totals.total_declined,
                totals.total_no_response

            ORDER BY
                totals.total_squad_selections DESC,
                inner_t.member_name ASC

        ) outer_t',
        p_team_name,
        p_event_code,
        p_event_type,
        p_from_date,
        p_team_name,
        p_event_code,
        p_event_type,
        p_from_date
    );

    RETURN QUERY EXECUTE 'SELECT json_agg(row_to_json(t)) FROM (' || v_sql || ') t';
END;
$$;


ALTER FUNCTION "public"."get_member_match_stats_detail"("p_team_name" "text", "p_event_code" "text", "p_event_type" "text", "p_from_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_member_team_details"("p_member_id" bigint, "p_team_id" bigint) RETURNS json
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    result json;
BEGIN
    SELECT json_build_object(
        -- Top Level Member Details
        'member_id', m.member_id,
        'first_name', m.first_name,
        'last_name', m.last_name,
        'profile_pic', m.profile_pic,
        'member_code', m.unique_member_code,
        
        -- Top Level Team Details
        'team_id', t.team_id,
        'team_name', t.team_name,
        'profile_pic_team', t.profile_pic,
        'team_code', t.team_unique_code,

        -- Level 2: Roles the member currently holds for this team
        'member_roles', (
            SELECT json_agg(json_build_object(
                'role_id', r.role_id,
                'role_name', r.role_name,
                'role_level', r.role_level,
                'role_grade', r.role_grade
            ))
            FROM public.member_team_link mtl
            JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
            JOIN public.roles r ON mtrl.role_id = r.role_id
            WHERE mtl.member_id = p_member_id 
              AND mtl.team_id = p_team_id
        ),

        -- Level 2: Valid roles available for this team (from team_roles_link)
        'valid_team_roles', (
            SELECT json_agg(json_build_object(
                'role_id', r.role_id,
                'role_name', r.role_name,
                'role_level', r.role_level,
                'role_grade', r.role_grade
            ))
            FROM public.team_roles_link trl
            JOIN public.roles r ON trl.role_id = r.role_id
            WHERE trl.team_id = p_team_id
        ),

        -- Level 2: Users linked to this member
        'linked_users', (
            SELECT json_agg(json_build_object(
                'user_id', u.user_id,
                'email', u.email_address,
                'first_name', u.first_name,
                'last_name', u.last_name
            ))
            FROM public.user_member_link uml
            JOIN public.users u ON uml.user_id = u.user_id
            WHERE uml.member_id = p_member_id
        )
    ) INTO result
    FROM public.members m, public.teams t
    WHERE m.member_id = p_member_id 
      AND t.team_id = p_team_id;

    RETURN result;
END;
$$;


ALTER FUNCTION "public"."get_member_team_details"("p_member_id" bigint, "p_team_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_members_attendance_latest"("p_event_id" bigint, "p_user_id" "uuid") RETURNS TABLE("member_id" bigint, "first_name" "text", "last_name" "text", "profile_pic" "text", "response_value" "text", "response_icon" "text", "display_value" "text", "icon_link" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        m.member_id,
        m.first_name,
        m.last_name,
        m.profile_pic,
        ert.response_value,
        ert.response_icon,
        ert.display_value,
        ert.icon_link
    FROM
        public.members AS m
    INNER JOIN
        public.user_member_link AS uml ON m.member_id = uml.member_id
    LEFT JOIN (
        SELECT
            event_attendance.member_id,
            event_attendance.event_id,
            event_attendance.response_id,
            event_attendance.created_at,
            ROW_NUMBER() OVER(PARTITION BY event_attendance.member_id ORDER BY event_attendance.created_at DESC) as rn
        FROM
            public.event_attendance
        WHERE
            event_attendance.event_id = p_event_id
    ) AS ea ON m.member_id = ea.member_id AND ea.rn = 1
    LEFT JOIN
        public.event_response_type AS ert ON ea.response_id = ert.response_id
    WHERE
        uml.user_id = p_user_id;
END;
$$;


ALTER FUNCTION "public"."get_members_attendance_latest"("p_event_id" bigint, "p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_player_squad_events_v2"("p_member_id" integer, "p_club_id" integer, "p_start_date" timestamp with time zone DEFAULT ("now"() - '90 days'::interval), "p_end_date" timestamp with time zone DEFAULT "now"(), "p_team_ids" integer[] DEFAULT NULL::integer[], "p_codes" "text"[] DEFAULT NULL::"text"[], "p_types" "text"[] DEFAULT NULL::"text"[], "p_att_min" integer DEFAULT 0, "p_att_max" integer DEFAULT NULL::integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
    RETURN (
        WITH
        club_teams AS (
            SELECT t.team_id
            FROM public.teams t
            WHERE t.club_id = p_club_id
              AND (p_team_ids IS NULL OR t.team_id = ANY(p_team_ids))
        ),
        event_att_counts AS (
            SELECT
                e.event_id,
                COUNT(*) FILTER (WHERE ea.response_id = 3) AS accepted_count
            FROM public.events e
            JOIN  club_teams ct                  ON e.team_id   = ct.team_id
            LEFT JOIN public.event_attendance ea ON ea.event_id = e.event_id
            WHERE e.event_date_time >= p_start_date
              AND e.event_date_time <  p_end_date
            GROUP BY e.event_id
        ),
        filtered_events AS (
            SELECT e.event_id, e.team_id
            FROM public.events e
            JOIN  club_teams ct              ON e.team_id        = ct.team_id
            JOIN  event_att_counts eac       ON e.event_id       = eac.event_id
            LEFT JOIN public.event_codes ec  ON e.event_code_id  = ec.code_id
            LEFT JOIN public.event_types et  ON e.event_type_id  = et.event_type_id
            WHERE e.event_date_time >= p_start_date
              AND e.event_date_time <  p_end_date
              AND (p_codes    IS NULL OR ec.event_code = ANY(p_codes))
              AND (p_types    IS NULL OR et.event_type = ANY(p_types))
              AND (p_att_min <= 0     OR eac.accepted_count >= p_att_min)
              AND (p_att_max  IS NULL OR eac.accepted_count <= p_att_max)
        ),
        latest_saves AS (
            SELECT DISTINCT ON (ms.event_id)
                ms.event_id,
                ms.match_squad_id
            FROM public.match_squads ms
            JOIN filtered_events fe ON ms.event_id = fe.event_id
            ORDER BY ms.event_id, ms.match_squad_id DESC
        ),
        player_appearances AS (
            SELECT DISTINCT
                msd.event_id,
                msd.squad_id
            FROM public.match_squad_details msd
            JOIN latest_saves ls
                ON  msd.event_id       = ls.event_id
                AND msd.match_squad_id = ls.match_squad_id
            WHERE msd.member_id = p_member_id
        )
        SELECT COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'event_id',        e.event_id,
                    'event_title',     e.event_title,
                    'event_date_time', e.event_date_time,
                    'opposition',      e.opposition,
                    'team_id',         fe.team_id,
                    'event_code',      ec2.event_code,
                    'squad_id',        pa.squad_id,
                    'squad_name',      s.squad_name
                ) ORDER BY e.event_date_time DESC
            ),
            '[]'::jsonb
        )
        FROM player_appearances pa
        JOIN filtered_events fe          ON fe.event_id  = pa.event_id
        JOIN public.events   e           ON e.event_id   = pa.event_id
        JOIN public.squads   s           ON s.squad_id   = pa.squad_id
        LEFT JOIN public.event_codes ec2 ON ec2.code_id  = e.event_code_id
    );
END;
$$;


ALTER FUNCTION "public"."get_player_squad_events_v2"("p_member_id" integer, "p_club_id" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_team_ids" integer[], "p_codes" "text"[], "p_types" "text"[], "p_att_min" integer, "p_att_max" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_single_user_event"("p_user_id" "uuid", "p_event_id" bigint) RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    AS $$

WITH user_roles AS (
    SELECT
        mtl.team_id,
        t.show_advert,
        MAX(r.role_level) AS user_highest_role_on_team
    FROM public.user_member_link AS uml
    JOIN public.member_team_link AS mtl ON uml.member_id = mtl.member_id
    JOIN public.teams AS t ON mtl.team_id = t.team_id
    JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.roles AS r ON mtrl.role_id = r.role_id
    WHERE uml.user_id = p_user_id
    GROUP BY mtl.team_id, t.show_advert
),
target_event AS (
    SELECT
        e.*, t.team_name, t.team_female, t.club_id, et.event_type, ec.event_code,
        COALESCE(event_role.role_level, 0) AS event_role_level,
        to_char(e.event_date_time::timestamp, 'FMDay, DD FMMonth, YYYY at HH24:MI') AS event_date_time_formatted,
        CASE
            WHEN t.team_female = TRUE THEN 
                REPLACE(
                    COALESCE(
                        NULLIF(TRIM(e.event_title), ''), 
                        CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type, 
                            CASE WHEN COALESCE(e.opposition, '') <> '' THEN ' (' || e.opposition || ')' ELSE '' END)
                    ), 
                    'Hurling', 'Camogie'
                )
            ELSE 
                COALESCE(
                    NULLIF(TRIM(e.event_title), ''), 
                    CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type, 
                        CASE WHEN COALESCE(e.opposition, '') <> '' THEN ' (' || e.opposition || ')' ELSE '' END)
                )
        END AS effective_event_title
    FROM public.events AS e
    JOIN public.teams AS t ON e.team_id = t.team_id
    JOIN user_roles ur ON e.team_id = ur.team_id
    JOIN public.event_types AS et ON e.event_type_id = et.event_type_id
    LEFT JOIN public.event_codes AS ec ON e.event_code_id = ec.code_id
    LEFT JOIN public.roles AS event_role ON e.audience_id = event_role.role_id
    WHERE e.event_id = p_event_id
),
eligible_attendees AS (
    SELECT DISTINCT
        te.event_id,
        mtl.member_id
    FROM target_event te
    JOIN public.member_team_link mtl ON te.team_id = mtl.team_id
    JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.roles r_member ON mtrl.role_id = r_member.role_id
    WHERE (
        (te.event_role_level > 10 AND r_member.role_level >= te.event_role_level)
        OR (te.event_role_level = 10 AND r_member.role_level = 10)
        OR (te.event_role_level = 0 OR te.event_role_level IS NULL)
    )
),
latest_attendance_records AS (
    SELECT DISTINCT ON (ea.event_id, ea.member_id)
        ea.event_id, ea.member_id, ea.response_id, ea.attendance_id
    FROM public.event_attendance ea
    INNER JOIN eligible_attendees el ON ea.event_id = el.event_id AND ea.member_id = el.member_id
    ORDER BY ea.event_id, ea.member_id, ea.created_at DESC
),
attendance_summary AS (
    SELECT
        el.event_id,
        COUNT(CASE WHEN lar.response_id = 3 THEN 1 END) AS accepted_count,
        COUNT(CASE WHEN lar.response_id = 4 THEN 1 END) AS declined_count,
        COUNT(el.member_id) - COUNT(lar.response_id) AS no_response_count
    FROM eligible_attendees el
    LEFT JOIN latest_attendance_records lar ON el.event_id = lar.event_id AND el.member_id = lar.member_id
    GROUP BY el.event_id
),
final_event_data AS (
    SELECT
        te.event_id, te.effective_event_title AS event_title, te.meet_time, te.event_date_time_formatted, te.team_name, te.team_id, te.club_id,
        rm.member_id, lar_user.attendance_id, ert.display_value AS attendance_status, ert.icon_link AS attendance_icon, lar_user.response_id,
        te.request_attendance, te.event_type, te.event_link, te.event_code, te.location_name, te.location_pin, te.opposition, te.event_details,
        te.home_away, te.created_by, CONCAT(u.first_name, ' ', u.last_name) AS created_by_user_name, u.phone_number AS created_by_phone_number,
        rm.member_first_name, rm.member_last_name, rm.member_role_level, rm.event_role_level,
        COALESCE(asum.accepted_count, 0) AS accepted_count, 
        COALESCE(asum.declined_count, 0) AS declined_count, 
        COALESCE(asum.no_response_count, 0) AS no_response_count,
        ur.user_highest_role_on_team, te.notify_admins_changes, te.notify_admins_all, te.payment_required, 
        COALESCE((
            SELECT TRUE 
            FROM public.event_user_member_payment eup 
            WHERE eup.event_id = te.event_id 
              AND eup.user_id = p_user_id 
              AND eup.payment_status = 'confirmed' 
            LIMIT 1
        ), FALSE) AS event_paid
    FROM target_event AS te
    LEFT JOIN user_roles AS ur ON te.team_id = ur.team_id
    LEFT JOIN public.users AS u ON te.created_by = u.user_id 
    LEFT JOIN (
        SELECT DISTINCT ON (te.event_id)
            te.event_id, m.member_id, m.first_name AS member_first_name, m.last_name AS member_last_name, r.role_level AS member_role_level, te.event_role_level
        FROM target_event AS te
        JOIN public.user_member_link AS uml ON uml.user_id = p_user_id
        JOIN public.members AS m ON uml.member_id = m.member_id
        JOIN public.member_team_link AS mtl ON m.member_id = mtl.member_id AND mtl.team_id = te.team_id
        JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN public.roles AS r ON mtrl.role_id = r.role_id
        WHERE r.role_level >= te.event_role_level
        ORDER BY te.event_id, r.role_level ASC
    ) AS rm ON te.event_id = rm.event_id
    LEFT JOIN latest_attendance_records AS lar_user ON lar_user.member_id = rm.member_id AND lar_user.event_id = te.event_id
    LEFT JOIN public.event_response_type AS ert ON lar_user.response_id = ert.response_id
    LEFT JOIN attendance_summary AS asum ON te.event_id = asum.event_id
    WHERE rm.member_id IS NOT NULL
)
SELECT
    COALESCE(
        (SELECT jsonb_agg(fed) FROM final_event_data fed),
        '[]'::jsonb
    )
FROM final_event_data;

$$;


ALTER FUNCTION "public"."get_single_user_event"("p_user_id" "uuid", "p_event_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_squad_dashboard"("p_club_id" integer, "p_start_date" timestamp with time zone DEFAULT ("now"() - '90 days'::interval), "p_end_date" timestamp with time zone DEFAULT "now"(), "p_codes" "text"[] DEFAULT NULL::"text"[], "p_types" "text"[] DEFAULT NULL::"text"[], "p_att_min" integer DEFAULT 0, "p_att_max" integer DEFAULT NULL::integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_club_name text;
    v_result    jsonb;
BEGIN
    SELECT club_name INTO v_club_name
    FROM public.clubs
    WHERE club_id = p_club_id;

    IF v_club_name IS NULL THEN
        RETURN jsonb_build_object('error', 'Club not found');
    END IF;

    WITH
    club_teams AS (
        SELECT t.team_id, t.team_name, t.team_female
        FROM public.teams t
        WHERE t.club_id = p_club_id
    ),
    team_member_roles AS (
        SELECT DISTINCT ON (mtl.team_id, m.member_id)
            mtl.team_id,
            m.member_id,
            trim(m.first_name || ' ' || COALESCE(m.last_name, '')) AS full_name,
            r.role_name
        FROM public.member_team_link mtl
        JOIN club_teams ct                     ON mtl.team_id        = ct.team_id
        JOIN public.members m                  ON mtl.member_id      = m.member_id
        JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN public.roles r                    ON mtrl.role_id       = r.role_id
        WHERE r.role_grade = 10
        ORDER BY mtl.team_id, m.member_id, r.role_list_seq
    ),
    -- One row per (team, squad, member) — DISTINCT drops code_id to prevent fan-out
    squad_assignments AS (
        SELECT DISTINCT
            msl.team_id,
            msl.squad_id,
            msl.member_id,
            s.squad_name,
            s.grade,
            s.squad_list_seq
        FROM public.member_squad_link msl
        JOIN club_teams ct   ON msl.team_id  = ct.team_id
        JOIN public.squads s ON msl.squad_id = s.squad_id
    ),
    event_att_counts AS (
        SELECT
            e.event_id,
            COUNT(*) FILTER (WHERE ea.response_id = 3) AS accepted_count
        FROM public.events e
        JOIN  club_teams ct                  ON e.team_id   = ct.team_id
        LEFT JOIN public.event_attendance ea ON ea.event_id = e.event_id
        WHERE e.event_date_time >= p_start_date
          AND e.event_date_time <  p_end_date
        GROUP BY e.event_id
    ),
    latest_att AS (
        SELECT DISTINCT ON (ea.member_id, ea.event_id)
            ea.member_id,
            e.team_id,
            ea.response_id
        FROM public.event_attendance ea
        JOIN public.events e            ON ea.event_id      = e.event_id
        JOIN club_teams ct              ON e.team_id        = ct.team_id
        JOIN event_att_counts eac       ON ea.event_id      = eac.event_id
        LEFT JOIN public.event_codes ec ON e.event_code_id  = ec.code_id
        LEFT JOIN public.event_types et ON e.event_type_id  = et.event_type_id
        WHERE e.event_date_time >= p_start_date
          AND e.event_date_time <  p_end_date
          AND (p_codes    IS NULL OR ec.event_code = ANY(p_codes))
          AND (p_types    IS NULL OR et.event_type = ANY(p_types))
          AND (p_att_min <= 0     OR eac.accepted_count >= p_att_min)
          AND (p_att_max  IS NULL OR eac.accepted_count <= p_att_max)
        ORDER BY ea.member_id, ea.event_id, ea.attendance_id DESC
    ),
    -- Per-member attendance totals across all filtered events (no code_id split)
    member_att AS (
        SELECT
            member_id,
            team_id,
            COUNT(*) FILTER (WHERE response_id = 3) AS accepted,
            COUNT(*)                                  AS total_events
        FROM latest_att
        GROUP BY member_id, team_id
    ),
    filtered_events AS (
        SELECT e.event_id
        FROM public.events e
        JOIN club_teams ct               ON e.team_id        = ct.team_id
        JOIN event_att_counts eac        ON e.event_id       = eac.event_id
        LEFT JOIN public.event_codes ec  ON e.event_code_id  = ec.code_id
        LEFT JOIN public.event_types et  ON e.event_type_id  = et.event_type_id
        WHERE e.event_date_time >= p_start_date
          AND e.event_date_time <  p_end_date
          AND (p_codes    IS NULL OR ec.event_code = ANY(p_codes))
          AND (p_types    IS NULL OR et.event_type = ANY(p_types))
          AND (p_att_min <= 0     OR eac.accepted_count >= p_att_min)
          AND (p_att_max  IS NULL OR eac.accepted_count <= p_att_max)
    ),
    -- Single authoritative latest save per event — uses match_squads (one row per
    -- save action), not match_squad_details. Mirrors the drawer's client-side logic.
    latest_saves AS (
        SELECT DISTINCT ON (ms.event_id)
            ms.event_id,
            ms.match_squad_id
        FROM public.match_squads ms
        JOIN filtered_events fe ON ms.event_id = fe.event_id
        ORDER BY ms.event_id, ms.match_squad_id DESC
    ),
    -- Only rows from the latest save survive (join on both event_id AND match_squad_id)
    match_sels AS (
        SELECT
            msd.member_id,
            msd.team_id,
            msd.squad_id,
            COUNT(DISTINCT msd.event_id) AS match_count
        FROM public.match_squad_details msd
        JOIN latest_saves ls
            ON  msd.event_id       = ls.event_id
            AND msd.match_squad_id = ls.match_squad_id
        GROUP BY msd.member_id, msd.team_id, msd.squad_id
    ),
    -- Global distinct events per member across ALL squads and ALL teams.
    -- Grouped by member_id only (not team_id) so that saves recorded under
    -- different team_ids for the same player are all counted — matching the
    -- drawer which counts events regardless of team_id via seenEvIds dedup.
    member_distinct_events AS (
        SELECT
            msd.member_id,
            COUNT(DISTINCT msd.event_id) AS total_event_count
        FROM public.match_squad_details msd
        JOIN latest_saves ls
            ON  msd.event_id       = ls.event_id
            AND msd.match_squad_id = ls.match_squad_id
        GROUP BY msd.member_id
    ),
    -- One row per (team, squad) — no code_id dimension
    squad_stats AS (
        SELECT
            sa.team_id,
            sa.squad_id,
            sa.squad_name,
            sa.grade,
            sa.squad_list_seq,
            COUNT(DISTINCT sa.member_id) AS member_count,
            COALESCE(SUM(ms.match_count), 0) AS match_appearances,
            CASE
                WHEN SUM(COALESCE(ma.total_events, 0)) > 0
                THEN ROUND(
                    SUM(COALESCE(ma.accepted, 0))::numeric
                    / SUM(COALESCE(ma.total_events, 0)) * 100, 1)
                ELSE 0
            END AS acceptance_rate,
            CASE
                WHEN COUNT(DISTINCT sa.member_id) > 0
                THEN ROUND(
                    COALESCE(SUM(ma.accepted), 0)::numeric
                    / COUNT(DISTINCT sa.member_id), 1)
                ELSE 0
            END AS avg_accepted
        FROM squad_assignments sa
        LEFT JOIN member_att ma
            ON  sa.member_id = ma.member_id
            AND sa.team_id   = ma.team_id
        LEFT JOIN match_sels ms
            ON  sa.member_id = ms.member_id
            AND sa.team_id   = ms.team_id
            AND sa.squad_id  = ms.squad_id
        GROUP BY sa.team_id, sa.squad_id, sa.squad_name,
                 sa.grade, sa.squad_list_seq
    ),
    squad_member_rows AS (
        SELECT
            ms.team_id,
            ms.squad_id,
            COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'member_id',         ms.member_id,
                        'name',              COALESCE(tmr.full_name, ''),
                        'role',              COALESCE(tmr.role_name, ''),
                        'match_selections',  ms.match_count,
                        'total_event_count', COALESCE(mde.total_event_count, ms.match_count)
                    ) ORDER BY tmr.full_name
                ) FILTER (WHERE tmr.full_name IS NOT NULL AND trim(tmr.full_name) <> ''),
                '[]'::jsonb
            ) AS members
        FROM match_sels ms
        LEFT JOIN team_member_roles tmr
            ON  ms.member_id = tmr.member_id
            AND ms.team_id   = tmr.team_id
        LEFT JOIN member_distinct_events mde
            ON  ms.member_id = mde.member_id
        GROUP BY ms.team_id, ms.squad_id
    ),
    squad_rows AS (
        SELECT
            ss.team_id,
            COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'squad_id',          ss.squad_id,
                        'squad_name',        ss.squad_name,
                        'squad_list_seq',    ss.squad_list_seq,
                        'grade',             ss.grade,
                        'member_count',      ss.member_count,
                        'match_appearances', ss.match_appearances,
                        'acceptance_rate',   ss.acceptance_rate,
                        'avg_accepted',      ss.avg_accepted,
                        'members',           COALESCE(smr.members, '[]'::jsonb)
                    ) ORDER BY ss.squad_list_seq NULLS LAST, ss.squad_name
                ),
                '[]'::jsonb
            ) AS squads
        FROM squad_stats ss
        LEFT JOIN squad_member_rows smr
            ON  ss.team_id  = smr.team_id
            AND ss.squad_id = smr.squad_id
        GROUP BY ss.team_id
    ),
    team_squad_counts AS (
        SELECT team_id, COUNT(DISTINCT member_id) AS total_squad_members
        FROM squad_assignments
        GROUP BY team_id
    ),
    team_rows AS (
        SELECT
            COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'team_id',             ct.team_id,
                        'team_name',           ct.team_name,
                        'team_female',         ct.team_female,
                        'total_squad_members', COALESCE(tsc.total_squad_members, 0),
                        'squads',              COALESCE(sr.squads, '[]'::jsonb)
                    ) ORDER BY ct.team_name
                ),
                '[]'::jsonb
            ) AS teams
        FROM club_teams ct
        LEFT JOIN team_squad_counts tsc ON ct.team_id = tsc.team_id
        LEFT JOIN squad_rows sr         ON ct.team_id = sr.team_id
    )
    SELECT jsonb_build_object(
        'club_name',    v_club_name,
        'club_id',      p_club_id,
        'start_date',   p_start_date,
        'end_date',     p_end_date,
        'generated_at', now(),
        'teams',        (SELECT teams FROM team_rows)
    ) INTO v_result;

    RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."get_squad_dashboard"("p_club_id" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_codes" "text"[], "p_types" "text"[], "p_att_min" integer, "p_att_max" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_squad_dashboard_v2"("p_club_id" integer, "p_start_date" timestamp with time zone DEFAULT ("now"() - '90 days'::interval), "p_end_date" timestamp with time zone DEFAULT "now"(), "p_team_ids" integer[] DEFAULT NULL::integer[], "p_codes" "text"[] DEFAULT NULL::"text"[], "p_types" "text"[] DEFAULT NULL::"text"[], "p_att_min" integer DEFAULT 0, "p_att_max" integer DEFAULT NULL::integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_club_name text;
    v_result    jsonb;
BEGIN
    SELECT club_name INTO v_club_name
    FROM public.clubs
    WHERE club_id = p_club_id;

    IF v_club_name IS NULL THEN
        RETURN jsonb_build_object('error', 'Club not found');
    END IF;

    WITH
    club_teams AS (
        SELECT t.team_id, t.team_name, t.team_female
        FROM public.teams t
        WHERE t.club_id = p_club_id
          AND (p_team_ids IS NULL OR t.team_id = ANY(p_team_ids))
    ),
    team_member_roles AS (
        SELECT DISTINCT ON (mtl.team_id, m.member_id)
            mtl.team_id,
            m.member_id,
            trim(m.first_name || ' ' || COALESCE(m.last_name, '')) AS full_name,
            r.role_name
        FROM public.member_team_link mtl
        JOIN club_teams ct                     ON mtl.team_id        = ct.team_id
        JOIN public.members m                  ON mtl.member_id      = m.member_id
        JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN public.roles r                    ON mtrl.role_id       = r.role_id
        WHERE r.role_grade = 10
        ORDER BY mtl.team_id, m.member_id, r.role_list_seq
    ),
    squad_assignments AS (
        SELECT DISTINCT
            msl.team_id,
            msl.squad_id,
            msl.member_id,
            s.squad_name,
            s.grade,
            s.squad_list_seq
        FROM public.member_squad_link msl
        JOIN club_teams ct   ON msl.team_id  = ct.team_id
        JOIN public.squads s ON msl.squad_id = s.squad_id
    ),
    event_att_counts AS (
        SELECT
            e.event_id,
            COUNT(*) FILTER (WHERE ea.response_id = 3) AS accepted_count
        FROM public.events e
        JOIN  club_teams ct                  ON e.team_id   = ct.team_id
        LEFT JOIN public.event_attendance ea ON ea.event_id = e.event_id
        WHERE e.event_date_time >= p_start_date
          AND e.event_date_time <  p_end_date
        GROUP BY e.event_id
    ),
    latest_att AS (
        SELECT DISTINCT ON (ea.member_id, ea.event_id)
            ea.member_id,
            e.team_id,
            ea.response_id
        FROM public.event_attendance ea
        JOIN public.events e            ON ea.event_id      = e.event_id
        JOIN club_teams ct              ON e.team_id        = ct.team_id
        JOIN event_att_counts eac       ON ea.event_id      = eac.event_id
        LEFT JOIN public.event_codes ec ON e.event_code_id  = ec.code_id
        LEFT JOIN public.event_types et ON e.event_type_id  = et.event_type_id
        WHERE e.event_date_time >= p_start_date
          AND e.event_date_time <  p_end_date
          AND (p_codes    IS NULL OR ec.event_code = ANY(p_codes))
          AND (p_types    IS NULL OR et.event_type = ANY(p_types))
          AND (p_att_min <= 0     OR eac.accepted_count >= p_att_min)
          AND (p_att_max  IS NULL OR eac.accepted_count <= p_att_max)
        ORDER BY ea.member_id, ea.event_id, ea.attendance_id DESC
    ),
    member_att AS (
        SELECT
            member_id,
            team_id,
            COUNT(*) FILTER (WHERE response_id = 3) AS accepted,
            COUNT(*)                                  AS total_events
        FROM latest_att
        GROUP BY member_id, team_id
    ),
    filtered_events AS (
        SELECT e.event_id
        FROM public.events e
        JOIN club_teams ct               ON e.team_id        = ct.team_id
        JOIN event_att_counts eac        ON e.event_id       = eac.event_id
        LEFT JOIN public.event_codes ec  ON e.event_code_id  = ec.code_id
        LEFT JOIN public.event_types et  ON e.event_type_id  = et.event_type_id
        WHERE e.event_date_time >= p_start_date
          AND e.event_date_time <  p_end_date
          AND (p_codes    IS NULL OR ec.event_code = ANY(p_codes))
          AND (p_types    IS NULL OR et.event_type = ANY(p_types))
          AND (p_att_min <= 0     OR eac.accepted_count >= p_att_min)
          AND (p_att_max  IS NULL OR eac.accepted_count <= p_att_max)
    ),
    latest_saves AS (
        SELECT DISTINCT ON (ms.event_id)
            ms.event_id,
            ms.match_squad_id
        FROM public.match_squads ms
        JOIN filtered_events fe ON ms.event_id = fe.event_id
        ORDER BY ms.event_id, ms.match_squad_id DESC
    ),
    match_sels AS (
        SELECT
            msd.member_id,
            msd.team_id,
            msd.squad_id,
            COUNT(DISTINCT msd.event_id) AS match_count
        FROM public.match_squad_details msd
        JOIN latest_saves ls
            ON  msd.event_id       = ls.event_id
            AND msd.match_squad_id = ls.match_squad_id
        GROUP BY msd.member_id, msd.team_id, msd.squad_id
    ),
    member_distinct_events AS (
        SELECT
            msd.member_id,
            COUNT(DISTINCT msd.event_id) AS total_event_count
        FROM public.match_squad_details msd
        JOIN latest_saves ls
            ON  msd.event_id       = ls.event_id
            AND msd.match_squad_id = ls.match_squad_id
        GROUP BY msd.member_id
    ),
    squad_stats AS (
        SELECT
            sa.team_id,
            sa.squad_id,
            sa.squad_name,
            sa.grade,
            sa.squad_list_seq,
            COUNT(DISTINCT sa.member_id) AS member_count,
            COALESCE(SUM(ms.match_count), 0) AS match_appearances,
            CASE
                WHEN SUM(COALESCE(ma.total_events, 0)) > 0
                THEN ROUND(
                    SUM(COALESCE(ma.accepted, 0))::numeric
                    / SUM(COALESCE(ma.total_events, 0)) * 100, 1)
                ELSE 0
            END AS acceptance_rate,
            CASE
                WHEN COUNT(DISTINCT sa.member_id) > 0
                THEN ROUND(
                    COALESCE(SUM(ma.accepted), 0)::numeric
                    / COUNT(DISTINCT sa.member_id), 1)
                ELSE 0
            END AS avg_accepted
        FROM squad_assignments sa
        LEFT JOIN member_att ma
            ON  sa.member_id = ma.member_id
            AND sa.team_id   = ma.team_id
        LEFT JOIN match_sels ms
            ON  sa.member_id = ms.member_id
            AND sa.team_id   = ms.team_id
            AND sa.squad_id  = ms.squad_id
        GROUP BY sa.team_id, sa.squad_id, sa.squad_name,
                 sa.grade, sa.squad_list_seq
    ),
    squad_member_rows AS (
        SELECT
            ms.team_id,
            ms.squad_id,
            COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'member_id',         ms.member_id,
                        'name',              COALESCE(tmr.full_name, ''),
                        'role',              COALESCE(tmr.role_name, ''),
                        'match_selections',  ms.match_count,
                        'total_event_count', COALESCE(mde.total_event_count, ms.match_count)
                    ) ORDER BY tmr.full_name
                ) FILTER (WHERE tmr.full_name IS NOT NULL AND trim(tmr.full_name) <> ''),
                '[]'::jsonb
            ) AS members
        FROM match_sels ms
        LEFT JOIN team_member_roles tmr
            ON  ms.member_id = tmr.member_id
            AND ms.team_id   = tmr.team_id
        LEFT JOIN member_distinct_events mde
            ON  ms.member_id = mde.member_id
        GROUP BY ms.team_id, ms.squad_id
    ),
    squad_rows AS (
        SELECT
            ss.team_id,
            COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'squad_id',          ss.squad_id,
                        'squad_name',        ss.squad_name,
                        'squad_list_seq',    ss.squad_list_seq,
                        'grade',             ss.grade,
                        'member_count',      ss.member_count,
                        'match_appearances', ss.match_appearances,
                        'acceptance_rate',   ss.acceptance_rate,
                        'avg_accepted',      ss.avg_accepted,
                        'members',           COALESCE(smr.members, '[]'::jsonb)
                    ) ORDER BY ss.squad_list_seq NULLS LAST, ss.squad_name
                ),
                '[]'::jsonb
            ) AS squads
        FROM squad_stats ss
        LEFT JOIN squad_member_rows smr
            ON  ss.team_id  = smr.team_id
            AND ss.squad_id = smr.squad_id
        GROUP BY ss.team_id
    ),
    team_squad_counts AS (
        SELECT team_id, COUNT(DISTINCT member_id) AS total_squad_members
        FROM squad_assignments
        GROUP BY team_id
    ),
    team_rows AS (
        SELECT
            COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'team_id',             ct.team_id,
                        'team_name',           ct.team_name,
                        'team_female',         ct.team_female,
                        'total_squad_members', COALESCE(tsc.total_squad_members, 0),
                        'squads',              COALESCE(sr.squads, '[]'::jsonb)
                    ) ORDER BY ct.team_name
                ),
                '[]'::jsonb
            ) AS teams
        FROM club_teams ct
        LEFT JOIN team_squad_counts tsc ON ct.team_id = tsc.team_id
        LEFT JOIN squad_rows sr         ON ct.team_id = sr.team_id
    )
    SELECT jsonb_build_object(
        'club_name',    v_club_name,
        'club_id',      p_club_id,
        'start_date',   p_start_date,
        'end_date',     p_end_date,
        'generated_at', now(),
        'teams',        (SELECT teams FROM team_rows)
    ) INTO v_result;

    RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."get_squad_dashboard_v2"("p_club_id" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_team_ids" integer[], "p_codes" "text"[], "p_types" "text"[], "p_att_min" integer, "p_att_max" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_team_attendance_dashboard"("p_team_id" integer, "p_start_date" timestamp with time zone DEFAULT ("now"() - '90 days'::interval), "p_end_date" timestamp with time zone DEFAULT "now"()) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_team_name    text;
    v_total_events integer;
    v_result       jsonb;
BEGIN
    SELECT team_name INTO v_team_name
    FROM public.teams
    WHERE team_id = p_team_id;

    IF v_team_name IS NULL THEN
        RETURN jsonb_build_object('error', 'Team not found');
    END IF;

    SELECT COUNT(DISTINCT event_id) INTO v_total_events
    FROM public.events
    WHERE team_id        = p_team_id
      AND event_date_time >= p_start_date
      AND event_date_time <  p_end_date;

    WITH events_in_range AS (
        SELECT
            e.event_id,
            e.event_date_time,
            COALESCE(ec.event_code, '') AS event_code,
            COALESCE(et.event_type, '') AS event_type,
            CASE
                WHEN e.event_title IS NOT NULL AND trim(e.event_title) <> '' THEN e.event_title
                ELSE trim(
                    CASE WHEN t.team_female = true AND ec.code_id = 3
                         THEN 'Camogie'
                         ELSE COALESCE(ec.event_code, '')
                    END
                    || ' ' || COALESCE(et.event_type, '')
                    || CASE
                        WHEN et.event_type_id = 2
                         AND e.opposition IS NOT NULL
                         AND e.opposition <> ''
                        THEN ' v ' || e.opposition
                        ELSE ''
                       END
                )
            END AS display_title
        FROM public.events e
        JOIN public.teams t             ON e.team_id       = t.team_id
        LEFT JOIN public.event_codes ec ON e.event_code_id = ec.code_id
        LEFT JOIN public.event_types et ON e.event_type_id = et.event_type_id
        WHERE e.team_id        = p_team_id
          AND e.event_date_time >= p_start_date
          AND e.event_date_time <  p_end_date
    ),
    team_players AS (
        -- role_list_seq picks the primary role when a member has more than one
        SELECT DISTINCT ON (m.member_id)
            m.member_id,
            trim(m.first_name || ' ' || COALESCE(m.last_name, '')) AS full_name,
            r.role_name
        FROM public.member_team_link mtl
        JOIN public.members               m    ON mtl.member_id      = m.member_id
        JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN public.roles                 r    ON mtrl.role_id        = r.role_id
        WHERE mtl.team_id  = p_team_id
          AND r.role_grade = 10
        ORDER BY m.member_id, r.role_list_seq
    ),
    latest_attendance AS (
        SELECT DISTINCT ON (ea.member_id, ea.event_id)
            ea.member_id,
            ea.event_id,
            ea.response_id
        FROM public.event_attendance ea
        JOIN events_in_range e ON ea.event_id = e.event_id
        ORDER BY ea.member_id, ea.event_id, ea.attendance_id DESC
    ),
    player_stats AS (
        SELECT
            tp.member_id,
            tp.full_name,
            tp.role_name,
            COUNT(e.event_id)                                                AS total_events,
            COUNT(la.response_id) FILTER (WHERE la.response_id = 3)         AS accepted,
            COUNT(la.response_id) FILTER (WHERE la.response_id = 4)         AS declined,
            COUNT(e.event_id)
                - COUNT(la.response_id) FILTER (WHERE la.response_id IN (3,4)) AS no_response,
            CASE WHEN COUNT(e.event_id) = 0 THEN 0
                 ELSE ROUND(
                     COUNT(la.response_id) FILTER (WHERE la.response_id = 3)::numeric
                     / COUNT(e.event_id) * 100
                 )
            END                                                              AS attendance_rate,
            COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'event_id', e.event_id,
                        'date',     e.event_date_time,
                        'title',    e.display_title,
                        'code',     e.event_code,
                        'type',     e.event_type,
                        'response', CASE la.response_id
                                        WHEN 3 THEN 'accepted'
                                        WHEN 4 THEN 'declined'
                                        ELSE        'no_response'
                                    END
                    )
                    ORDER BY e.event_date_time DESC
                ),
                '[]'::jsonb
            )                                                                AS events
        FROM team_players tp
        CROSS JOIN events_in_range e
        LEFT JOIN latest_attendance la
            ON la.member_id = tp.member_id AND la.event_id = e.event_id
        GROUP BY tp.member_id, tp.full_name, tp.role_name
    )
    SELECT jsonb_build_object(
        'team_name',    v_team_name,
        'team_id',      p_team_id,
        'total_events', v_total_events,
        'start_date',   p_start_date,
        'end_date',     p_end_date,
        'generated_at', now(),
        'players',      COALESCE(
            (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'member_id',       ps.member_id,
                        'name',            ps.full_name,
                        'role',            ps.role_name,
                        'accepted',        ps.accepted,
                        'declined',        ps.declined,
                        'no_response',     ps.no_response,
                        'total_events',    ps.total_events,
                        'attendance_rate', ps.attendance_rate,
                        'events',          ps.events
                    )
                    ORDER BY ps.attendance_rate DESC NULLS LAST, ps.full_name ASC
                )
                FROM player_stats ps
            ),
            '[]'::jsonb
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."get_team_attendance_dashboard"("p_team_id" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_team_event_dashboard"("p_team_id" integer, "p_start_date" timestamp with time zone DEFAULT ("now"() - '90 days'::interval), "p_end_date" timestamp with time zone DEFAULT "now"()) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_team_name text;
    v_result    jsonb;
BEGIN
    SELECT team_name INTO v_team_name
    FROM public.teams
    WHERE team_id = p_team_id;

    IF v_team_name IS NULL THEN
        RETURN jsonb_build_object('error', 'Team not found');
    END IF;

    WITH events_in_range AS (
        SELECT
            e.event_id,
            e.event_date_time,
            COALESCE(ec.event_code, '') AS event_code,
            COALESCE(et.event_type, '') AS event_type,
            e.opposition,
            CASE
                WHEN e.event_title IS NOT NULL AND trim(e.event_title) <> '' THEN e.event_title
                ELSE trim(
                    CASE WHEN t.team_female = true AND ec.code_id = 3
                         THEN 'Camogie'
                         ELSE COALESCE(ec.event_code, '')
                    END
                    || ' ' || COALESCE(et.event_type, '')
                    || CASE
                        WHEN et.event_type_id = 2
                         AND e.opposition IS NOT NULL AND e.opposition <> ''
                        THEN ' v ' || e.opposition
                        ELSE ''
                       END
                )
            END AS display_title
        FROM public.events e
        JOIN public.teams t             ON e.team_id       = t.team_id
        LEFT JOIN public.event_codes ec ON e.event_code_id = ec.code_id
        LEFT JOIN public.event_types et ON e.event_type_id = et.event_type_id
        WHERE e.team_id         = p_team_id
          AND e.event_date_time >= p_start_date
          AND e.event_date_time <  p_end_date
    ),
    team_members AS (
        SELECT DISTINCT ON (m.member_id)
            m.member_id,
            trim(m.first_name || ' ' || COALESCE(m.last_name, '')) AS full_name,
            r.role_name
        FROM public.member_team_link mtl
        JOIN public.members               m    ON mtl.member_id      = m.member_id
        JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN public.roles                 r    ON mtrl.role_id        = r.role_id
        WHERE mtl.team_id  = p_team_id
          AND r.role_grade = 10
        ORDER BY m.member_id, r.role_list_seq
    ),
    latest_attendance AS (
        SELECT DISTINCT ON (ea.member_id, ea.event_id)
            ea.member_id,
            ea.event_id,
            ea.response_id
        FROM public.event_attendance ea
        JOIN events_in_range e ON ea.event_id = e.event_id
        ORDER BY ea.member_id, ea.event_id, ea.attendance_id DESC
    ),
    event_stats AS (
        SELECT
            e.event_id,
            e.event_date_time,
            e.event_code,
            e.event_type,
            e.opposition,
            e.display_title,
            COUNT(la.response_id) FILTER (WHERE la.response_id = 3)             AS accepted,
            COUNT(la.response_id) FILTER (WHERE la.response_id = 4)             AS declined,
            COUNT(tm.member_id)
                - COUNT(la.response_id) FILTER (WHERE la.response_id IN (3,4))  AS no_response,
            COUNT(tm.member_id) AS total_members,
            COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'member_id', tm.member_id,
                        'name',      tm.full_name,
                        'role',      tm.role_name,
                        'response',  CASE la.response_id
                                         WHEN 3 THEN 'accepted'
                                         WHEN 4 THEN 'declined'
                                         ELSE        'no_response'
                                     END
                    )
                    ORDER BY tm.full_name
                ),
                '[]'::jsonb
            ) AS members
        FROM events_in_range e
        CROSS JOIN team_members tm
        LEFT JOIN latest_attendance la
            ON la.member_id = tm.member_id AND la.event_id = e.event_id
        GROUP BY e.event_id, e.event_date_time, e.event_code, e.event_type,
                 e.opposition, e.display_title
    )
    SELECT jsonb_build_object(
        'team_name',     v_team_name,
        'team_id',       p_team_id,
        'start_date',    p_start_date,
        'end_date',      p_end_date,
        'generated_at',  now(),
        'total_members', (SELECT COUNT(*) FROM team_members),
        'events',        COALESCE(
            (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'event_id',      es.event_id,
                        'date',          es.event_date_time,
                        'title',         es.display_title,
                        'code',          es.event_code,
                        'type',          es.event_type,
                        'opposition',    es.opposition,
                        'accepted',      es.accepted,
                        'declined',      es.declined,
                        'no_response',   es.no_response,
                        'total_members', es.total_members,
                        'members',       es.members
                    )
                    ORDER BY es.event_date_time DESC
                )
                FROM event_stats es
            ),
            '[]'::jsonb
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."get_team_event_dashboard"("p_team_id" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_team_members_by_role"("p_user_id" "uuid", "p_team_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_highest_role smallint;
    v_team_info RECORD;
    v_roles_json jsonb;
    v_club_codes_json jsonb;
BEGIN
    -- 1. Get highest role level
    SELECT MAX(r.role_level) INTO v_user_highest_role
    FROM public.roles r
    JOIN public.member_team_role_link mtrl ON r.role_id = mtrl.role_id
    JOIN public.member_team_link mtl ON mtrl.member_team_id = mtl.member_team_id
    JOIN public.members m ON mtl.member_id = m.member_id
    WHERE m.user_id = p_user_id;

    -- 2. Get team details
    SELECT team_id, team_name, team_unique_code, club_id, team_female 
    INTO v_team_info
    FROM public.teams
    WHERE team_id = p_team_id;

    -- 3. Get club codes (with Camogie logic)
    SELECT jsonb_agg(
        jsonb_build_object(
            'code_id', ec.code_id::bigint,
            'event_code', CASE 
                WHEN v_team_info.team_female = TRUE AND ec.event_code = 'Hurling' THEN 'Camogie'
                ELSE ec.event_code 
            END::text
        )
    ) INTO v_club_codes_json
    FROM public.club_code_link ccl
    JOIN public.event_codes ec ON ccl.code_id = ec.code_id
    WHERE ccl.club_id = v_team_info.club_id;

    -- 4. Create the grouped list of members
    SELECT jsonb_agg(role_group) INTO v_roles_json
    FROM (
        SELECT 
            r.role_name,
            r.role_level,
            CASE 
                WHEN r.role_name ILIKE '%y' THEN LEFT(r.role_name, -1) || 'ies'
                WHEN r.role_name ILIKE '%ch' OR r.role_name ILIKE '%sh' OR r.role_name ILIKE '%x' OR r.role_name ILIKE '%s' THEN r.role_name || 'es'
                ELSE r.role_name || 's'
            END as role_name_plural,
            COUNT(DISTINCT m.member_id) as member_count,
            jsonb_agg(
                jsonb_build_object(
                    'member_id', m.member_id::bigint,
                    'first_name', m.first_name::text,
                    'last_name', m.last_name::text,
                    'full_name', (m.first_name || ' ' || m.last_name)::text,
                    'squad_image', s.squad_image, 
                    'squad_id', mtl.squad_id::bigint,
                    'squad_name', s.squad_name::text,
                    'squad_codes', (
                        SELECT jsonb_agg(
                            jsonb_build_object(
                                'code_id', ec_sub.code_id::bigint,
                                'code_name', CASE 
                                    WHEN v_team_info.team_female = TRUE AND ec_sub.event_code = 'Hurling' THEN 'Camogie'
                                    ELSE ec_sub.event_code 
                                END::text,
                                'squad_id', COALESCE(s_sub.squad_id, 0)::bigint,
                                'squad_name', COALESCE(s_sub.squad_name, '')::text,
                                'squad_image', COALESCE(s_sub.squad_image, '')::text
                            )
                        )
                        FROM public.club_code_link ccl_sub
                        JOIN public.event_codes ec_sub ON ccl_sub.code_id = ec_sub.code_id
                        LEFT JOIN public.member_squad_link msl_sub ON (
                            msl_sub.code_id = ec_sub.code_id 
                            AND msl_sub.member_id = m.member_id
                            AND msl_sub.team_id = p_team_id
                        )
                        LEFT JOIN public.squads s_sub ON msl_sub.squad_id = s_sub.squad_id
                        WHERE ccl_sub.club_id = v_team_info.club_id
                    )
                )
            ) as members
        FROM public.roles r
        JOIN public.member_team_role_link mtrl ON r.role_id = mtrl.role_id
        JOIN public.member_team_link mtl ON mtrl.member_team_id = mtl.member_team_id
        JOIN public.members m ON mtl.member_id = m.member_id
        LEFT JOIN public.squads s ON mtl.squad_id = s.squad_id
        WHERE mtl.team_id = p_team_id
        GROUP BY r.role_name, r.role_level
        ORDER BY r.role_level DESC 
    ) role_group;

    RETURN jsonb_build_object(
        'team_id', v_team_info.team_id::bigint,
        'team_name', v_team_info.team_name::text,
        'team_unique_code', v_team_info.team_unique_code::text,
        'club_id', v_team_info.club_id::bigint,
        'user_highest_role_level', COALESCE(v_user_highest_role, 0)::int,
        'role_groups', COALESCE(v_roles_json, '[]'::jsonb),
        'club_codes', COALESCE(v_club_codes_json, '[]'::jsonb)
    );
END;
$$;


ALTER FUNCTION "public"."get_team_members_by_role"("p_user_id" "uuid", "p_team_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_unresponded_events"("event_id_param" bigint) RETURNS SETOF "jsonb"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  WITH latest_attendance AS (
    SELECT
      ea.event_id,
      ea.member_id,
      ea.response_id,
      row_number() OVER (
        PARTITION BY ea.event_id, ea.member_id
        ORDER BY ea.created_at DESC
      ) AS rn
    FROM public.event_attendance ea
  )
  SELECT DISTINCT
    jsonb_build_object(
      'email',             u.email_address,
      'team_name',         t.team_name,
      'event_title',       e.event_title,
      'event_date_time',   e.event_date_time,
      'full_name',         u.first_name || ' ' || u.last_name,
      'first_name',        u.first_name,
      'last_name',         u.last_name,
      'member_first_name', m.first_name,
      'member_last_name',  m.last_name
    )
  FROM public.events e
  JOIN public.teams t    ON t.team_id    = e.team_id
  JOIN public.member_team_link mtl ON mtl.team_id = t.team_id
  JOIN public.members m  ON m.member_id  = mtl.member_id
  JOIN public.user_member_link uml ON uml.member_id = m.member_id
  JOIN public.users u    ON u.user_id    = uml.user_id
  LEFT JOIN latest_attendance la
         ON la.event_id  = e.event_id
        AND la.member_id = m.member_id
        AND la.rn = 1
  WHERE e.event_id = event_id_param
    AND (la.response_id IS NULL OR la.response_id = 0);
END;
$$;


ALTER FUNCTION "public"."get_unresponded_events"("event_id_param" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_unresponded_events_v2"("event_id_param" bigint, "p_role_grade" smallint DEFAULT NULL::smallint, "p_role_level" smallint DEFAULT NULL::smallint) RETURNS SETOF "jsonb"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    WITH
    -- 1. CTE: Find ALL members linked to the event's team (The foundation set).
    all_team_members AS (
        SELECT DISTINCT ON (e.event_id, m.member_id, u.user_id)
            e.event_id,
            e.event_title,
            e.event_date_time,
            t.team_name,
            u.email_address,
            u.first_name AS user_first_name,
            u.last_name AS user_last_name,
            u.first_name || ' ' || u.last_name AS full_user_name,
            m.member_id,
            m.first_name AS member_first_name,
            m.last_name AS member_last_name,
            r.role_grade, -- Needed for filtering
            r.role_level  -- Needed for filtering
        FROM
            public.events e
        INNER JOIN
            public.teams t ON e.team_id = t.team_id
        INNER JOIN
            public.member_team_link mtl ON t.team_id = mtl.team_id
        INNER JOIN
            public.members m ON mtl.member_id = m.member_id
        INNER JOIN
            public.user_member_link uml ON m.member_id = uml.member_id
        INNER JOIN
            public.users u ON uml.user_id = u.user_id
        LEFT JOIN
            public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        LEFT JOIN
            public.roles r ON mtrl.role_id = r.role_id
        WHERE
            e.event_id = event_id_param
    ),
    -- 2. CTE: Find the latest attendance response for each distinct event-member combination.
    -- This identifies the member's CURRENT status.
    latest_member_event_attendance AS (
        SELECT
            ea.event_id,
            ea.member_id,
            ea.response_id,
            ROW_NUMBER() OVER (
                PARTITION BY ea.event_id, ea.member_id
                ORDER BY ea.created_at DESC
            ) AS rn
        FROM
            public.event_attendance ea
        WHERE
            ea.event_id = event_id_param
    )
    SELECT
        jsonb_build_object(
            'email', atm.email_address,
            'team_name', atm.team_name,
            'event_title', atm.event_title,
            'event_date_time', atm.event_date_time,
            'full_name', atm.full_user_name,
            'first_name', atm.user_first_name,
            'last_name', atm.user_last_name,
            'member_first_name', atm.member_first_name,
            'member_last_name', atm.member_last_name
        )
    FROM
        all_team_members atm -- Step 1: Start with ALL members
    LEFT JOIN
        latest_member_event_attendance lmea
        ON atm.event_id = lmea.event_id
        AND atm.member_id = lmea.member_id
        AND lmea.rn = 1 -- Only join the latest response status (Step 2 Prep)
    WHERE
        -- Filter 1: Check for members who are UNRESPONDED (latest status is NULL or 0)
        (lmea.response_id IS NULL OR lmea.response_id = 0)
        -- Filter 2: Conditional Role Grade filter (exact match if provided)
        AND (p_role_grade IS NULL OR atm.role_grade = p_role_grade)
        -- Filter 3: Conditional Role Level filter (minimum level if provided)
        AND (p_role_level IS NULL OR atm.role_level >= p_role_level);
END;
$$;


ALTER FUNCTION "public"."get_unresponded_events_v2"("event_id_param" bigint, "p_role_grade" smallint, "p_role_level" smallint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_updated_event_code"("p_event_id" bigint) RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_event_code_id int8;
    v_team_id int8;
    v_club_id int8;
    v_fallback_code_id int8;
BEGIN
    -- 1. Get the current event_code_id and the team_id for the event
    SELECT event_code_id, team_id 
    INTO v_event_code_id, v_team_id
    FROM public.events
    WHERE event_id = p_event_id;

    -- 2. Logic Check: If event_code > 1, return it immediately
    IF v_event_code_id > 1 THEN
        RETURN v_event_code_id;
    END IF;

    -- 3. Fallback Logic: event_code is <= 1 (or NULL)
    -- Find the club associated with the team
    SELECT club_id INTO v_club_id
    FROM public.teams
    WHERE team_id = v_team_id;

    -- 4. Find the first code for that club where code_id > 1, ordered ascending
    SELECT ccl.code_id INTO v_fallback_code_id
    FROM public.club_code_link ccl
    WHERE ccl.club_id = v_club_id 
      AND ccl.code_id > 1
    ORDER BY ccl.code_id ASC
    LIMIT 1;

    -- 5. Return the fallback code (or the original if no fallback exists)
    RETURN COALESCE(v_fallback_code_id, v_event_code_id);
END;
$$;


ALTER FUNCTION "public"."get_updated_event_code"("p_event_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_clubs"() RETURNS TABLE("user_id" "uuid", "email_address" "text", "user_first_name" "text", "user_last_name" "text", "user_full_name" "text", "club_id" bigint, "club_name" "text", "county" "text", "banner" "text", "crest" "text", "sort_order" integer)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
SELECT DISTINCT
    u.user_id,
    u.email_address,
    u.first_name AS user_first_name,
    u.last_name AS user_last_name,
    CONCAT(
        COALESCE(u.first_name, ''::text),
        ' ',
        COALESCE(u.last_name, ''::text)
    ) AS user_full_name,
    c.club_id,
    c.club_name,
    c.county,
    c.banner,
    c.crest,
    CASE
        WHEN c.club_name = 'All Clubs'::text THEN 0
        ELSE 1
    END AS sort_order
FROM
    public.users u
JOIN
    public.user_member_link uml ON u.user_id = uml.user_id
JOIN
    public.member_team_link mtl ON uml.member_id = mtl.member_id
JOIN
    public.teams t ON mtl.team_id = t.team_id
JOIN
    public.clubs c ON t.club_id = c.club_id
WHERE
    u.user_id = auth.uid() -- SECURE: Filters by the currently authenticated user ID from the session JWT
UNION ALL
SELECT
    u.user_id,
    u.email_address,
    u.first_name AS user_first_name,
    u.last_name AS user_last_name,
    CONCAT(
        COALESCE(u.first_name, ''::text),
        ' ',
        COALESCE(u.last_name, ''::text)
    ) AS user_full_name,
    NULL::bigint AS club_id,
    'All Clubs'::text AS club_name,
    NULL::text AS county,
    NULL::text AS banner,
    'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/coach-smart-new-mpqa5l/assets/yk304zt4r8kj/Launcher_Icon_v2-removebg-preview.png'::text AS crest,
    0 AS sort_order
FROM
    public.users u
WHERE
    u.user_id = auth.uid() -- SECURE: Filters by the currently authenticated user ID from the session JWT
ORDER BY
    1,
    11,
    7;
$$;


ALTER FUNCTION "public"."get_user_clubs"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_clubs"("p_user_id" "uuid") RETURNS TABLE("user_id" "uuid", "email_address" "text", "user_first_name" "text", "user_last_name" "text", "user_full_name" "text", "club_id" bigint, "club_name" "text", "county" "text", "banner" "text", "crest" "text", "sort_order" integer)
    LANGUAGE "sql" SECURITY DEFINER
    AS $$
SELECT DISTINCT
    u.user_id,
    u.email_address,
    u.first_name AS user_first_name,
    u.last_name AS user_last_name,
    CONCAT(
        COALESCE(u.first_name, ''::text),
        ' ',
        COALESCE(u.last_name, ''::text)
    ) AS user_full_name,
    c.club_id,
    c.club_name,
    c.county,
    c.banner,
    c.crest,
    CASE
        WHEN c.club_name = 'All Clubs'::text THEN 0
        ELSE 1
    END AS sort_order
FROM
    public.users u
JOIN
    public.user_member_link uml ON u.user_id = uml.user_id
JOIN
    public.member_team_link mtl ON uml.member_id = mtl.member_id
JOIN
    public.teams t ON mtl.team_id = t.team_id
JOIN
    public.clubs c ON t.club_id = c.club_id
WHERE
    u.user_id = p_user_id -- REVERTED: Now uses the passed parameter
UNION ALL
SELECT
    u.user_id,
    u.email_address,
    u.first_name AS user_first_name,
    u.last_name AS user_last_name,
    CONCAT(
        COALESCE(u.first_name, ''::text),
        ' ',
        COALESCE(u.last_name, ''::text)
    ) AS user_full_name,
    NULL::bigint AS club_id,
    'All Clubs'::text AS club_name,
    NULL::text AS county,
    NULL::text AS banner,
    'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/coach-smart-new-mpqa5l/assets/yk304zt4r8kj/Launcher_Icon_v2-removebg-preview.png'::text AS crest,
    0 AS sort_order
FROM
    public.users u
WHERE
    u.user_id = p_user_id -- REVERTED: Now uses the passed parameter
ORDER BY
    1,
    11,
    7;
$$;


ALTER FUNCTION "public"."get_user_clubs"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_event_create_detail"("p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_result jsonb;
    v_default_team_id bigint;
BEGIN
    -- 1. Determine the default team
    -- Count distinct teams where the user is a member. 
    -- If count is exactly 1, return the ID, else NULL.
    SELECT 
        CASE 
            WHEN COUNT(DISTINCT mtl.team_id) = 1 THEN MAX(mtl.team_id)
            ELSE NULL 
        END INTO v_default_team_id
    FROM public.members m
    JOIN public.member_team_link mtl ON m.member_id = mtl.member_id
    WHERE m.user_id = p_user_id;

    -- 2. Build the full result object
    SELECT jsonb_build_object(
        'user_id', p_user_id,
        'default_team_id', v_default_team_id, -- New top-level field
        'create_teams', (
            SELECT jsonb_agg(team_data)
            FROM (
                SELECT DISTINCT ON (t.team_id)
                    t.team_id,
                    t.team_name,
                    t.club_id,
                    c.club_name,
                    m.member_id,
                    (m.first_name || ' ' || m.last_name) AS authorized_member_name,
                    r.role_id,
                    r.role_name AS admin_role,
                    r.role_level AS admin_level,
                    -- Nested List of Event Types
                    (SELECT jsonb_agg(jsonb_build_object('id', et.event_type_id, 'name', et.event_type))
                     FROM public.event_types et) AS event_types,
                    -- Nested List of Event Codes specific to this team's Club
                    (SELECT jsonb_agg(jsonb_build_object('id', ec.code_id, 'name', ec.event_code))
                     FROM public.club_code_link ccl
                     JOIN public.event_codes ec ON ccl.code_id = ec.code_id
                     WHERE ccl.club_id = t.club_id) AS event_codes,
                    -- Nested List of Team Roles
                    (SELECT jsonb_agg(jsonb_build_object(
                        'id', r_inner.role_id, 
                        'name', r_inner.role_name,
                        'name_plural', r_inner.role_name_plural
                     ))
                     FROM public.team_roles_link trl
                     JOIN public.roles r_inner ON trl.role_id = r_inner.role_id
                     WHERE trl.team_id = t.team_id 
                       AND r_inner.role_grade = 10
                       AND r_inner.show_audience = true) AS team_roles 
                FROM public.members m
                JOIN public.member_team_link mtl ON m.member_id = mtl.member_id
                JOIN public.teams t ON mtl.team_id = t.team_id
                LEFT JOIN public.clubs c ON t.club_id = c.club_id
                JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
                JOIN public.roles r ON mtrl.role_id = r.role_id
                WHERE m.user_id = p_user_id
                  AND r.role_grade = 100
                ORDER BY t.team_id, r.role_level DESC
            ) team_data
        )
    )
    INTO v_result;

    RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."get_user_event_create_detail"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_event_details"("p_event_id" bigint, "p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    AS $$

WITH event_details AS (
    -- Level 1: Get core event details, including the new car_pooling flag
    SELECT
        e.event_id,
        e.team_id,
        e.meet_time,
        e.event_link,
        e.location_name,
        e.location_pin,
        e.opposition,
        e.event_details,
        e.home_away,
        e.request_attendance,
        e.notify_admins_changes,
        e.notify_admins_all,
        e.payment_required,
        e.payment_amount,
        e.event_image,
        e.car_pooling, 
        t.team_name,
        t.team_female,
        et.event_type,
        ec.event_code,
        ec.code_id, -- CHANGED: Added code_id
        e.audience_id,
        event_role.role_level AS event_role_level,
        to_char(e.event_date_time::timestamp, 'FMDay, DD FMMonth, YYYY at HH24:MI') AS event_date_time_formatted,
        
        CASE
            WHEN t.team_female = TRUE AND
                (
                    CASE
                        WHEN e.event_title IS NOT NULL AND TRIM(e.event_title) <> '' THEN e.event_title
                        WHEN et.event_type = 'Match' THEN
                            CASE
                                WHEN e.opposition IS NOT NULL AND TRIM(e.opposition) <> '' THEN
                                    CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type, ' (', e.opposition, ')')
                                ELSE
                                    CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type)
                            END
                        ELSE CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type)
                    END
                ) LIKE '%Hurling%'
            THEN
                REPLACE(
                    CASE
                        WHEN e.event_title IS NOT NULL AND TRIM(e.event_title) <> '' THEN e.event_title
                        WHEN et.event_type = 'Match' THEN
                            CASE
                                WHEN e.opposition IS NOT NULL AND TRIM(e.opposition) <> '' THEN
                                    CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type, ' (', e.opposition, ')')
                                ELSE
                                    CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type)
                            END
                        ELSE CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type)
                    END
                , 'Hurling', 'Camogie')
            ELSE
                CASE
                    WHEN e.event_title IS NOT NULL AND TRIM(e.event_title) <> '' THEN e.event_title
                    WHEN et.event_type = 'Match' THEN
                        CASE
                            WHEN e.opposition IS NOT NULL AND TRIM(e.opposition) <> '' THEN
                                CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type, ' (', e.opposition, ')')
                            ELSE
                                CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type)
                        END
                    ELSE CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type)
                END
        END AS effective_event_title,
        
        CONCAT(u.first_name, ' ', u.last_name) AS created_by_user_name,
        u.phone_number AS created_by_phone_number
    FROM
        public.events AS e
    JOIN
        public.teams AS t ON e.team_id = t.team_id
    JOIN
        public.event_types AS et ON e.event_type_id = et.event_type_id
    LEFT JOIN
        public.event_codes AS ec ON e.event_code_id = ec.code_id
    LEFT JOIN
        public.roles AS event_role ON e.audience_id = event_role.role_id
    LEFT JOIN
        public.users AS u ON e.created_by = u.user_id
    WHERE
        e.event_id = p_event_id
),
latest_event_attendance AS (
    SELECT
        ea.member_id,
        ea.response_id,
        ROW_NUMBER() OVER(PARTITION BY ea.member_id ORDER BY ea.created_at DESC, ea.attendance_id DESC) as rn
    FROM
        public.event_attendance AS ea
    WHERE
        ea.event_id = p_event_id
),
member_primary_role AS (
    WITH ranked_roles AS (
        SELECT
            mtl.member_id,
            r.role_id,
            r.role_level,
            r.role_name,
            r.role_name_plural,
            r.role_grade,
            ROW_NUMBER() OVER(
                PARTITION BY mtl.member_id
                ORDER BY
                    CASE WHEN r.role_level BETWEEN 20 AND 99 THEN 0 ELSE 1 END ASC,
                    r.role_level ASC,
                    r.role_id ASC
            ) as rn
        FROM
            public.member_team_link AS mtl
        JOIN
            public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN
            public.roles AS r ON mtrl.role_id = r.role_id
        JOIN
            event_details AS ed ON mtl.team_id = ed.team_id
    )
    SELECT member_id, role_id, role_level, role_name, role_name_plural, role_grade FROM ranked_roles WHERE rn = 1
),
categorized_eligible_members AS (
    SELECT DISTINCT mtl.member_id
    FROM public.member_team_link AS mtl
    JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.roles AS r ON mtrl.role_id = r.role_id
    CROSS JOIN event_details AS ed
    WHERE mtl.team_id = ed.team_id AND r.role_grade = 10 AND r.role_level >= ed.event_role_level
),
total_eligible_count AS (
    SELECT COUNT(cem.member_id) AS total_count FROM categorized_eligible_members AS cem
),
member_role_attendance AS (
    SELECT cem.member_id, lea.response_id FROM categorized_eligible_members AS cem
    LEFT JOIN latest_event_attendance AS lea ON cem.member_id = lea.member_id AND lea.rn = 1
),
strictly_matched_members AS (
    SELECT mpr.member_id FROM member_primary_role AS mpr
    CROSS JOIN event_details AS ed
    WHERE mpr.role_grade = 10 AND mpr.role_level = ed.event_role_level
),
matched_role_attendance AS (
    SELECT smm.member_id, lea.response_id FROM strictly_matched_members AS smm
    LEFT JOIN latest_event_attendance AS lea ON smm.member_id = lea.member_id AND lea.rn = 1
),
matched_attendance_totals AS (
    SELECT COALESCE(mra.response_id, 0) AS response_id, COUNT(mra.member_id) AS member_count
    FROM matched_role_attendance AS mra GROUP BY 1
),
team_squad_check AS (
    SELECT EXISTS (SELECT 1 FROM public.squads AS s JOIN event_details AS ed ON s.team_id = ed.team_id) AS team_has_squads LIMIT 1
),
attendance_by_response_and_role AS (
    SELECT mpr.role_id, mpr.role_level, mpr.role_name, mpr.role_grade, COALESCE(mra.response_id, 0) AS response_id, COUNT(mra.member_id) AS member_count
    FROM member_role_attendance AS mra JOIN member_primary_role AS mpr ON mra.member_id = mpr.member_id GROUP BY 1, 2, 3, 4, 5
),
event_distinct_primary_roles AS (
    SELECT DISTINCT mpr.role_id, mpr.role_level, mpr.role_name, mpr.role_name_plural, mpr.role_grade
    FROM member_primary_role AS mpr CROSS JOIN event_details AS ed
    WHERE mpr.role_grade = 10 AND mpr.role_level >= ed.event_role_level
),
event_response_types AS (
    SELECT response_id FROM public.event_response_type UNION ALL SELECT 0 AS response_id
),
zero_filled_attendance_by_role AS (
    SELECT ert.response_id, edpr.role_id, edpr.role_level, edpr.role_name, edpr.role_name_plural, edpr.role_grade, COALESCE(abrr.member_count, 0) AS member_count
    FROM event_response_types AS ert CROSS JOIN event_distinct_primary_roles AS edpr
    LEFT JOIN attendance_by_response_and_role AS abrr ON ert.response_id = abrr.response_id AND edpr.role_id = abrr.role_id
),
dynamic_role_attendance_summary AS (
    SELECT zfar.response_id, jsonb_agg(jsonb_build_object('role_id', zfar.role_id, 'role_level', zfar.role_level, 'role_name', zfar.role_name, 'role_name_plural', zfar.role_name_plural, 'member_count', zfar.member_count) ORDER BY zfar.role_level ASC, zfar.role_name ASC) AS filtered_response_by_role
    FROM zero_filled_attendance_by_role AS zfar GROUP BY 1
),
summary_data AS (
    SELECT
        ed.event_role_level,
        COALESCE((SELECT filtered_response_by_role FROM dynamic_role_attendance_summary WHERE response_id = 3), '[]'::jsonb) AS accepted_attendance_summary,
        COALESCE((SELECT filtered_response_by_role FROM dynamic_role_attendance_summary WHERE response_id = 0), '[]'::jsonb) AS no_response_attendance_summary,
        COALESCE((SELECT filtered_response_by_role FROM dynamic_role_attendance_summary WHERE response_id = 4), '[]'::jsonb) AS declined_attendance_summary,
        COALESCE((SELECT member_count FROM matched_attendance_totals WHERE response_id = 3), 0) AS accepted_exact_match_count,
        COALESCE((SELECT member_count FROM matched_attendance_totals WHERE response_id = 0), 0) AS no_response_exact_match_count,
        COALESCE((SELECT member_count FROM matched_attendance_totals WHERE response_id = 4), 0) AS declined_exact_match_count
    FROM event_details AS ed LIMIT 1
),
member_payment_status AS (
    SELECT eump.member_id, eump.payment_id, eump.payment_status, CASE WHEN eump.payment_status = 'confirmed' THEN 1 ELSE 0 END AS member_paid,
    ROW_NUMBER() OVER(PARTITION BY eump.member_id ORDER BY eump.created_at DESC) as rn
    FROM public.event_user_member_payment AS eump WHERE eump.event_id = p_event_id AND eump.user_id = p_user_id AND eump.payment_status <> 'pending'
),
latest_member_payment AS (
    SELECT member_id, payment_id, member_paid, payment_status FROM member_payment_status WHERE rn = 1
),
event_team_members AS (
    SELECT m.member_id, m.first_name, m.last_name, m.profile_pic, r.role_name, r.role_level, ROW_NUMBER() OVER(PARTITION BY m.member_id ORDER BY r.role_level ASC) as role_rn
    FROM public.members AS m
    INNER JOIN public.user_member_link AS uml ON m.member_id = uml.member_id
    INNER JOIN public.member_team_link AS mtl ON m.member_id = mtl.member_id
    INNER JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
    INNER JOIN public.roles AS r ON mtrl.role_id = r.role_id
    INNER JOIN event_details AS ed ON mtl.team_id = ed.team_id
    WHERE uml.user_id = p_user_id
),
user_highest_role AS (
    SELECT MAX(etm.role_level) AS highest_role_level_for_user FROM event_team_members AS etm
),
user_payment_status AS (
    SELECT COALESCE(COUNT(eup.payment_id), 0)::integer AS event_paid FROM public.event_user_payment AS eup WHERE eup.event_id = p_event_id AND eup.user_id = p_user_id AND eup.payment_status = 'confirmed'
),
event_payment_summary AS (
    SELECT COUNT(eup.stripe_session_id) AS total_payments, COALESCE(SUM(eup.amount_paid), 0) AS total_amount_paid,
    COALESCE(SUM(eup.amount_paid)::numeric - COALESCE(SUM(eup.fee_amount), 0)::numeric - COALESCE(SUM(eup.tax_amount), 0)::numeric, 0) AS total_net_amount
    FROM public.event_user_payment eup WHERE eup.event_id = p_event_id AND eup.payment_status = 'confirmed'
),
event_member_payment_summary AS (
    SELECT COALESCE(COUNT(eump.payment_id) FILTER (WHERE eump.payment_status = 'confirmed'), 0)::integer AS new_num_payments,
    COALESCE(SUM(eump.gross_amount), 0) AS new_gross_amount, COALESCE(SUM(eump.net_amount), 0) AS new_net_amount
    FROM public.event_user_member_payment eump WHERE eump.event_id = p_event_id AND eump.payment_status = 'confirmed'
)
SELECT
    jsonb_build_object(
        'event_id', ed.event_id,
        'team_id', ed.team_id,
        'team_has_squads', tsc.team_has_squads,
        'audience_id', ed.audience_id,
        'event_role_level', ed.event_role_level,
        'event_link', ed.event_link,
        'event_title', ed.effective_event_title,
        'team_name', ed.team_name,
        'event_date_time_formatted', ed.event_date_time_formatted,
        'meet_time', ed.meet_time,
        'event_type', ed.event_type,
        'event_code', ed.event_code,
        'code_id', ed.code_id, -- CHANGED: Added code_id
        'location_name', ed.location_name,
        'location_pin', ed.location_pin,
        'opposition', ed.opposition,
        'event_details', ed.event_details,
        'home_away', ed.home_away,
        'request_attendance', ed.request_attendance,
        'notify_admins_changes', ed.notify_admins_changes,
        'notify_admins_all', ed.notify_admins_all,
        'created_by', ed.created_by_user_name,
        'created_by_phone_number', ed.created_by_phone_number,
        'total_count', tec.total_count,
        'user_highest_role_level', uhr.highest_role_level_for_user,
        'car_pooling_enabled', COALESCE(ed.car_pooling, false),
        'payment_required', ed.payment_required,
        'payment_amount', ed.payment_amount,
        'event_paid', ups.event_paid,
        'total_payments', eps.total_payments,
        'total_amount_paid', eps.total_amount_paid,
        'total_net_amount', eps.total_net_amount,
        'event_image', ed.event_image,
        'new_gross_amount', emps.new_gross_amount,
        'new_net_amount', emps.new_net_amount,
        'new_num_payments', emps.new_num_payments,
        'team_members', (
            SELECT COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'member_id', etm.member_id,
                        'first_name', etm.first_name,
                        'last_name', etm.last_name,
                        'profile_pic', etm.profile_pic,
                        'role_name', etm.role_name,
                        'role_level', etm.role_level,
                        'response_id', lea.response_id,
                        'attendance_status', ert.display_value,
                        'attendance_icon', ert.icon_link,
                        'member_paid', COALESCE(lmp.member_paid, 0),
                        'member_payment_id', lmp.payment_id,
                        'member_payment_status', lmp.payment_status
                    ) ORDER BY etm.role_level ASC, etm.last_name ASC
                ) FILTER (WHERE etm.role_rn = 1), '[]'::jsonb
            )
            FROM event_team_members AS etm
            LEFT JOIN latest_event_attendance AS lea ON etm.member_id = lea.member_id AND lea.rn = 1
            LEFT JOIN public.event_response_type AS ert ON lea.response_id = ert.response_id
            LEFT JOIN latest_member_payment AS lmp ON etm.member_id = lmp.member_id
            WHERE etm.role_rn = 1
        ),
        'accepted_attendance_summary', sd.accepted_attendance_summary,
        'no_response_attendance_summary', sd.no_response_attendance_summary,
        'declined_attendance_summary', sd.declined_attendance_summary,
        'accepted_player_count', sd.accepted_exact_match_count,
        'no_response_player_count', sd.no_response_exact_match_count,
        'declined_player_count', sd.declined_exact_match_count
    )
FROM
    event_details AS ed
CROSS JOIN user_highest_role AS uhr
CROSS JOIN total_eligible_count AS tec
CROSS JOIN team_squad_check AS tsc
CROSS JOIN summary_data AS sd
CROSS JOIN user_payment_status AS ups
CROSS JOIN event_payment_summary AS eps
CROSS JOIN event_member_payment_summary AS emps
LIMIT 1;

$$;


ALTER FUNCTION "public"."get_user_event_details"("p_event_id" bigint, "p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_event_edit_detail"("p_user_id" "uuid", "p_event_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_result jsonb;
    v_default_team_id bigint;
    v_current_event jsonb;
BEGIN
    -- 1. Determine the default team
    SELECT 
        CASE 
            WHEN COUNT(DISTINCT mtl.team_id) = 1 THEN MAX(mtl.team_id)
            ELSE NULL 
        END INTO v_default_team_id
    FROM public.members m
    JOIN public.member_team_link mtl ON m.member_id = mtl.member_id
    WHERE m.user_id = p_user_id;

    -- 2. Fetch Existing Event Data
    IF p_event_id IS NOT NULL THEN
        SELECT jsonb_build_object(
            'event_id', e.event_id,
            'event_title', e.event_title,
            'event_type_id', e.event_type_id,
            -- Explicitly ensuring this is treated as a timestamp
            'event_date_time', e.event_date_time_2, 
            'meet_time', e.meet_time,
            'event_code_id', e.event_code_id,
            'opposition', e.opposition,
            'home_away', e.home_away,
            'location_name', e.location_name,
            'location_pin', e.location_pin,
            'event_link', e.event_link,
            'audience_id', e.audience_id,
            'request_attendance', e.request_attendance,
            'event_details', e.event_details,
            'team_id', e.team_id,
            'event_image', e.event_image,
            'payment_required', e.payment_required,
            'payment_amount', e.payment_amount
        ) INTO v_current_event
        FROM public.events e
        WHERE e.event_id = p_event_id;
    END IF;

    -- 3. Build the final response
    SELECT jsonb_build_object(
        'user_id', p_user_id,
        'default_team_id', v_default_team_id,
        'current_event', v_current_event,
        'create_teams', (
            SELECT jsonb_agg(team_data)
            FROM (
                SELECT DISTINCT ON (t.team_id)
                    t.team_id,
                    t.team_name,
                    t.club_id,
                    c.club_name,
                    m.member_id,
                    (m.first_name || ' ' || m.last_name) AS authorized_member_name,
                    r.role_id,
                    r.role_name AS admin_role,
                    r.role_level AS admin_level,
                    (SELECT jsonb_agg(jsonb_build_object('id', et.event_type_id, 'name', et.event_type))
                     FROM public.event_types et) AS event_types,
                    (SELECT jsonb_agg(jsonb_build_object('id', ec.code_id, 'name', ec.event_code))
                     FROM public.club_code_link ccl
                     JOIN public.event_codes ec ON ccl.code_id = ec.code_id
                     WHERE ccl.club_id = t.club_id) AS event_codes,
                    (SELECT jsonb_agg(jsonb_build_object(
                        'id', r_inner.role_id, 
                        'name', r_inner.role_name,
                        'name_plural', r_inner.role_name_plural
                     ))
                     FROM public.team_roles_link trl
                     JOIN public.roles r_inner ON trl.role_id = r_inner.role_id
                     WHERE trl.team_id = t.team_id 
                       AND r_inner.role_grade = 10
                       AND r_inner.show_audience = true) AS team_roles 
                FROM public.members m
                JOIN public.member_team_link mtl ON m.member_id = mtl.member_id
                JOIN public.teams t ON mtl.team_id = t.team_id
                LEFT JOIN public.clubs c ON t.club_id = c.club_id
                JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
                JOIN public.roles r ON mtrl.role_id = r.role_id
                WHERE m.user_id = p_user_id
                  AND r.role_grade = 100
                ORDER BY t.team_id, r.role_level DESC
            ) team_data
        )
    )
    INTO v_result;

    RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."get_user_event_edit_detail"("p_user_id" "uuid", "p_event_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_event_members_with_attendance"("p_event_id" bigint, "p_user_id" "uuid") RETURNS TABLE("member_id" bigint, "first_name" "text", "last_name" "text", "profile_pic" "text", "response_value" "text", "response_icon" "text", "display_value" "text", "icon_link" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        m.member_id,
        m.first_name,
        m.last_name,
        m.profile_pic,
        ert.response_value,
        ert.response_icon,
        ert.display_value,
        ert.icon_link
    FROM
        public.members AS m
    INNER JOIN
        public.user_member_link AS uml ON m.member_id = uml.member_id
    INNER JOIN
        public.member_team_link AS mtl ON m.member_id = mtl.member_id
    INNER JOIN
        public.events AS e ON mtl.team_id = e.team_id
    LEFT JOIN (
        SELECT
            event_attendance.member_id,
            event_attendance.response_id,
            ROW_NUMBER() OVER(PARTITION BY event_attendance.member_id ORDER BY event_attendance.created_at DESC) as rn
        FROM
            public.event_attendance
        WHERE
            event_attendance.event_id = p_event_id
    ) AS ea ON m.member_id = ea.member_id AND ea.rn = 1
    LEFT JOIN
        public.event_response_type AS ert ON ea.response_id = ert.response_id
    WHERE
        uml.user_id = p_user_id AND e.event_id = p_event_id;
END;
$$;


ALTER FUNCTION "public"."get_user_event_members_with_attendance"("p_event_id" bigint, "p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_event_team_members"("p_event_id" bigint, "p_user_id" "uuid", "p_role_grade" "text" DEFAULT NULL::"text", "p_role_level" "text" DEFAULT NULL::"text") RETURNS TABLE("member_id" bigint, "first_name" "text", "last_name" "text", "profile_pic" "text", "response_value" "text", "response_icon" "text", "display_value" "text", "icon_link" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Removed explicit authentication check to allow use with p_user_id for temporary testing.

    RETURN QUERY
    WITH latest_event_attendance AS (
        -- CTE 1: Find the single latest attendance response for *each* member on the event (Fix for NULL responses)
        SELECT
            ea_sub.member_id,
            ea_sub.response_id,
            -- Use ROW_NUMBER partitioned by member_id to identify the latest entry
            ROW_NUMBER() OVER(PARTITION BY ea_sub.member_id ORDER BY ea_sub.created_at DESC, ea_sub.attendance_id DESC) as rn
        FROM
            public.event_attendance AS ea_sub
        WHERE
            ea_sub.event_id = p_event_id -- Filter to the current event
    ),
    distinct_members AS (
        -- Step 2: Find the member's highest privilege role (lowest role_level)
        -- and link it to the latest attendance response.
        SELECT
            m.member_id,
            m.first_name,
            m.last_name,
            m.profile_pic,
            r.role_level, -- Keep the role_level for the final ordering
            lea.response_id, -- Use the response_id from the fixed CTE
            -- ROW_NUMBER to select the member's highest role (lowest role_level).
            ROW_NUMBER() OVER(PARTITION BY m.member_id ORDER BY r.role_level ASC) as role_rn
        FROM
            public.members AS m
        INNER JOIN
            public.user_member_link AS uml ON m.member_id = uml.member_id
        INNER JOIN
            public.member_team_link AS mtl ON m.member_id = mtl.member_id
        INNER JOIN
            public.events AS e ON mtl.team_id = e.team_id
        INNER JOIN
            public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
        INNER JOIN
            public.roles AS r ON mtrl.role_id = r.role_id
        -- Join the correct latest attendance data
        LEFT JOIN
            latest_event_attendance AS lea ON m.member_id = lea.member_id AND lea.rn = 1
        WHERE
            -- *** REVERTED SECURITY FIX: Using the insecure p_user_id parameter. ***
            uml.user_id = p_user_id
            AND e.event_id = p_event_id
            -- Filters to limit members by role grade and level (>=)
            AND (p_role_grade IS NULL OR p_role_grade = '' OR r.role_grade = p_role_grade::INT)
            AND (p_role_level IS NULL OR p_role_level = '' OR r.role_level >= p_role_level::INT)
    )
    SELECT
        dm.member_id,
        dm.first_name,
        dm.last_name,
        dm.profile_pic,
        ert.response_value,
        ert.response_icon,
        ert.display_value,
        ert.icon_link
    FROM
        distinct_members AS dm
    LEFT JOIN
        public.event_response_type AS ert ON dm.response_id = ert.response_id
    WHERE
        dm.role_rn = 1 -- Select only the row associated with the member's highest role
    ORDER BY
        dm.role_level ASC,
        dm.last_name ASC,
        dm.first_name ASC;
END;
$$;


ALTER FUNCTION "public"."get_user_event_team_members"("p_event_id" bigint, "p_user_id" "uuid", "p_role_grade" "text", "p_role_level" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_events"("user_id_param" "uuid") RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    AS $$

WITH user_roles AS (
    -- Pre-calculate the user's highest role on each team they are a member of
    -- (This eliminates correlated subqueries for user roles)
    SELECT
        mtl.team_id,
        MAX(r.role_level) AS user_highest_role_on_team
    FROM
        public.user_member_link AS uml
    JOIN
        public.member_team_link AS mtl ON uml.member_id = mtl.member_id
    JOIN
        public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN
        public.roles AS r ON mtrl.role_id = r.role_id
    WHERE
        uml.user_id = user_id_param
    GROUP BY
        mtl.team_id
),
user_max_any_role AS (
    -- Calculate the user's single highest role across ALL teams once
    SELECT
        MAX(user_highest_role_on_team) AS user_highest_role_on_any_team
    FROM
        user_roles
),
upcoming_events AS (
    -- Filter and pre-process event data, including event role level.
    SELECT
        e.*,
        t.team_name,
        t.team_female,
        t.club_id, -- ADDED: Select club_id from the teams table
        et.event_type,
        ec.event_code,
        event_role.role_level AS event_role_level,
        to_char(e.event_date_time::timestamp, 'FMDay, DD Month, YYYY at HH24:MI') AS event_date_time_formatted,
        -- START MODIFIED LOGIC for effective_event_title
        CASE
            -- 1. Check for Gender Substitution (Hurling/Camogie)
            WHEN t.team_female = TRUE AND e.event_title LIKE 'Hurling%' THEN
                -- Apply Gender Substitution first
                CASE
                    -- 2. Check if the newly-substituted title should include Opposition
                    WHEN et.event_type = 'Match' THEN 
                        CONCAT(REPLACE(e.event_title, 'Hurling', 'Camogie'), ' (', e.opposition, ')')
                    ELSE 
                        REPLACE(e.event_title, 'Hurling', 'Camogie')
                END
            -- 3. If no Gender Substitution needed, apply Opposition logic directly
            WHEN et.event_type = 'Match' THEN 
                CONCAT(e.event_title, ' (', e.opposition, ')')
            -- 4. Default case: use the original title
            ELSE e.event_title
        END AS effective_event_title
        -- END MODIFIED LOGIC
    FROM
        public.events AS e
    JOIN
        public.teams AS t ON e.team_id = t.team_id
    JOIN
        public.event_types AS et ON e.event_type_id = et.event_type_id
    LEFT JOIN
        public.event_codes AS ec ON e.event_code_id = ec.code_id
    LEFT JOIN
        public.roles AS event_role ON e.audience_id = event_role.role_id
    WHERE
        e.event_date_time >= CURRENT_DATE
        -- Early filtering to only include events for the user's teams
        AND e.team_id IN (SELECT ur.team_id FROM user_roles ur)
),
relevant_member AS (
    -- Identify the single 'most relevant' member (lowest role_level, then lowest member_id)
    -- linked to the user for each upcoming event's team, ensuring their role meets the event's audience level.
    SELECT DISTINCT ON (ue.event_id)
        ue.event_id,
        m.member_id,
        m.first_name AS member_first_name,
        m.last_name AS member_last_name,
        r.role_level AS member_role_level,
        ue.event_role_level
    FROM
        upcoming_events AS ue
    JOIN
        public.user_member_link AS uml ON uml.user_id = user_id_param
    JOIN
        public.members AS m ON uml.member_id = m.member_id
    JOIN
        public.member_team_link AS mtl ON m.member_id = mtl.member_id AND mtl.team_id = ue.team_id
    LEFT JOIN
        public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
    LEFT JOIN
        public.roles AS r ON mtrl.role_id = r.role_id
    WHERE
        -- Logic for the *user's* eligibility (must meet or exceed the audience role)
        r.role_level >= ue.event_role_level
    ORDER BY
        ue.event_id, r.role_level ASC, m.member_id ASC
),
all_team_members AS (
    -- **CRITICAL FIX:** Select all members eligible for the attendance summary count.
    -- This CTE implements the complex role-level filtering logic from the original EXISTS clause.
    SELECT
        ue.event_id,
        mtl.member_id
    FROM
        upcoming_events AS ue
    JOIN
        public.member_team_link AS mtl ON ue.team_id = mtl.team_id
    JOIN
        public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN
        public.roles AS r_member ON mtrl.role_id = r_member.role_id
    WHERE
        (
            -- Original complex logic:
            -- If event role is 10 (Player), only count members whose role is exactly 10
            (ue.event_role_level = 10 AND r_member.role_level = 10)
            -- If event role is > 10, count members whose role is >= event role
            OR (ue.event_role_level > 10 AND r_member.role_level >= ue.event_role_level)
        )
    GROUP BY
        ue.event_id, mtl.member_id
),
latest_event_attendance AS (
    -- Calculate the latest attendance response for ALL relevant members on ALL upcoming events once
    -- (This eliminates redundant window function calls)
    SELECT DISTINCT ON (ea_sub.member_id, ea_sub.event_id)
        ea_sub.event_id,
        ea_sub.member_id,
        ea_sub.response_id,
        ea_sub.attendance_id
    FROM
        public.event_attendance AS ea_sub
    JOIN
        upcoming_events AS ue ON ea_sub.event_id = ue.event_id
    -- Only check attendance for members identified as relevant for the count
    JOIN
        all_team_members AS atm ON ea_sub.member_id = atm.member_id AND ea_sub.event_id = atm.event_id
    ORDER BY
        ea_sub.member_id, ea_sub.event_id, ea_sub.created_at DESC, ea_sub.attendance_id DESC
),
attendance_summary AS (
    -- Calculate the accepted, declined, and no-response counts for each event
    SELECT
        atm.event_id,
        COUNT(CASE WHEN lea.response_id = 3 THEN atm.member_id END) AS accepted_count,
        COUNT(CASE WHEN lea.response_id = 4 THEN atm.member_id END) AS declined_count,
        COUNT(CASE WHEN lea.response_id IS NULL THEN atm.member_id END) AS no_response_count
    FROM
        all_team_members AS atm
    LEFT JOIN
        latest_event_attendance AS lea ON atm.member_id = lea.member_id AND atm.event_id = lea.event_id
    GROUP BY
        atm.event_id
)
SELECT
    -- FIX: Cast json_agg result to jsonb to match the '[]'::jsonb type
    COALESCE(
        json_agg(final_result)::jsonb 
    , '[]'::jsonb) -- ⬅️ THIS ENSURES AN EMPTY ARRAY '[]' IS RETURNED INSTEAD OF NULL
FROM
(
    SELECT
        ue.event_id,
        ue.effective_event_title AS event_title,
        ue.meet_time,
        ue.event_date_time_formatted,
        ue.team_name,
        ue.team_id,
        ue.club_id,
        rm.member_id,
        lea_user.attendance_id,
        ert.display_value AS attendance_status,
        ert.icon_link AS attendance_icon,
        lea_user.response_id,
        ue.request_attendance,
        ue.event_type,
        ue.event_link,
        ue.event_code,
        ue.location_name,
        ue.location_pin,
        ue.opposition,
        ue.event_details,
        ue.home_away,
        ue.created_by,
        CONCAT(u.first_name, ' ', u.last_name) AS created_by_user_name,
        u.phone_number AS created_by_phone_number,
        rm.member_first_name,
        rm.member_last_name,
        rm.member_role_level,
        rm.event_role_level,
        COALESCE(asum.accepted_count, 0) AS accepted_count,
        COALESCE(asum.declined_count, 0) AS declined_count,
        COALESCE(asum.no_response_count, 0) AS no_response_count,
        ur.user_highest_role_on_team,
        umr.user_highest_role_on_any_team,
        ue.notify_admins_changes,
        ue.notify_admins_all
    FROM
        upcoming_events AS ue
    -- Join pre-calculated highest roles for the team and overall
    LEFT JOIN
        user_roles AS ur ON ue.team_id = ur.team_id
    CROSS JOIN
        user_max_any_role AS umr
    -- Join event creator details
    LEFT JOIN
        public.users AS u ON ue.created_by = u.user_id 
    -- Join the relevant member and their role details (for the specific user's view)
    LEFT JOIN
        relevant_member AS rm ON ue.event_id = rm.event_id
    -- Join the *user's* latest attendance from the pre-calculated set
    LEFT JOIN
        latest_event_attendance AS lea_user ON lea_user.member_id = rm.member_id AND lea_user.event_id = ue.event_id
    LEFT JOIN
        public.event_response_type AS ert ON lea_user.response_id = ert.response_id
    -- Join the attendance summary counts
    LEFT JOIN
        attendance_summary AS asum ON ue.event_id = asum.event_id
    WHERE
        rm.member_id IS NOT NULL -- Only include events the user has an eligible member for
    ORDER BY
        ue.event_date_time ASC
) AS final_result;

$$;


ALTER FUNCTION "public"."get_user_events"("user_id_param" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_favourites"() RETURNS TABLE("link_id" bigint, "game_id" bigint, "game_name" "text", "game_image" "text", "game_skill" "text", "sort_order" integer)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  return query
  select
    ugl.id                               as link_id,
    g.game_id,
    g.game_name,
    g.game_image,
    array_to_string(g.game_skill, ', ')  as game_skill,
    ugl."position"                       as sort_order
  from public.user_game_link ugl
  join public.games g on g.game_id = ugl.game_id
  where ugl.user_id = auth.uid()
  order by ugl."position" asc, ugl.created_at asc;
end;
$$;


ALTER FUNCTION "public"."get_user_favourites"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_home_events"("p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$

WITH user_roles AS (
    SELECT
        mtl.team_id,
        t.show_advert,
        MAX(r.role_level) AS user_highest_role_on_team
    FROM public.user_member_link AS uml
    JOIN public.member_team_link AS mtl ON uml.member_id = mtl.member_id
    JOIN public.teams AS t ON mtl.team_id = t.team_id
    JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.roles AS r ON mtrl.role_id = r.role_id
    WHERE uml.user_id = p_user_id
    GROUP BY mtl.team_id, t.show_advert
),
user_details AS (
    SELECT
        u.user_id, u.first_name, u.last_name, u.email_address, u.phone_number,
        COALESCE(MAX(ur.user_highest_role_on_team), 0) AS highest_role_level,
        COALESCE(BOOL_OR(ur.show_advert), FALSE) AS show_advert,
        (SELECT COUNT(*)::int FROM public.notifications WHERE recipient_user_id = p_user_id AND is_read = false) AS unread_notifications,
        (COALESCE(u.first_name, '') <> '' AND EXISTS (SELECT 1 FROM user_roles)) AS user_onboarded
    FROM public.users AS u
    LEFT JOIN user_roles AS ur ON TRUE
    WHERE u.user_id = p_user_id
    GROUP BY u.user_id
),
upcoming_events AS (
    SELECT
        e.*, t.team_name, t.team_female, t.club_id, et.event_type, ec.event_code,
        COALESCE(event_role.role_level, 0) AS event_role_level,
        to_char(e.event_date_time::timestamp, 'FMDay, DD FMMonth, YYYY at HH24:MI') AS event_date_time_formatted,
        CASE
            WHEN t.team_female = TRUE THEN 
                REPLACE(
                    COALESCE(
                        NULLIF(TRIM(e.event_title), ''), 
                        CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type, 
                            CASE WHEN COALESCE(e.opposition, '') <> '' THEN ' (' || e.opposition || ')' ELSE '' END)
                    ), 
                    'Hurling', 'Camogie'
                )
            ELSE 
                COALESCE(
                    NULLIF(TRIM(e.event_title), ''), 
                    CONCAT(COALESCE(ec.event_code, ''), ' ', et.event_type, 
                        CASE WHEN COALESCE(e.opposition, '') <> '' THEN ' (' || e.opposition || ')' ELSE '' END)
                )
        END AS effective_event_title
    FROM public.events AS e
    JOIN public.teams AS t ON e.team_id = t.team_id
    JOIN user_roles ur ON e.team_id = ur.team_id
    JOIN public.event_types AS et ON e.event_type_id = et.event_type_id
    LEFT JOIN public.event_codes AS ec ON e.event_code_id = ec.code_id
    LEFT JOIN public.roles AS event_role ON e.audience_id = event_role.role_id
    WHERE e.event_date_time >= CURRENT_DATE
),
eligible_attendees AS (
    SELECT DISTINCT
        ue.event_id,
        mtl.member_id
    FROM upcoming_events ue
    JOIN public.member_team_link mtl ON ue.team_id = mtl.team_id
    JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.roles r_member ON mtrl.role_id = r_member.role_id
    WHERE (
        (ue.event_role_level > 10 AND r_member.role_level >= ue.event_role_level)
        OR (ue.event_role_level = 10 AND r_member.role_level = 10)
        OR (ue.event_role_level = 0 OR ue.event_role_level IS NULL)
    )
),
latest_attendance_records AS (
    SELECT DISTINCT ON (ea.event_id, ea.member_id)
        ea.event_id, ea.member_id, ea.response_id, ea.attendance_id
    FROM public.event_attendance ea
    INNER JOIN eligible_attendees el ON ea.event_id = el.event_id AND ea.member_id = el.member_id
    ORDER BY ea.event_id, ea.member_id, ea.created_at DESC
),
attendance_summary AS (
    SELECT
        el.event_id,
        COUNT(CASE WHEN lar.response_id = 3 THEN 1 END) AS accepted_count,
        COUNT(CASE WHEN lar.response_id = 4 THEN 1 END) AS declined_count,
        COUNT(el.member_id) - COUNT(lar.response_id) AS no_response_count
    FROM eligible_attendees el
    LEFT JOIN latest_attendance_records lar ON el.event_id = lar.event_id AND el.member_id = lar.member_id
    GROUP BY el.event_id
),
final_events_data AS (
    SELECT
        ue.event_id, ue.effective_event_title AS event_title, ue.meet_time, ue.event_date_time_formatted, ue.team_name, ue.team_id, ue.club_id,
        rm.member_id, lar_user.attendance_id, ert.display_value AS attendance_status, ert.icon_link AS attendance_icon, lar_user.response_id,
        ue.request_attendance, ue.event_type, ue.event_link, ue.event_code, ue.location_name, ue.location_pin, ue.opposition, ue.event_details,
        ue.home_away, ue.created_by, CONCAT(u.first_name, ' ', u.last_name) AS created_by_user_name, u.phone_number AS created_by_phone_number,
        rm.member_first_name, rm.member_last_name, rm.member_role_level, rm.event_role_level,
        COALESCE(asum.accepted_count, 0) AS accepted_count, 
        COALESCE(asum.declined_count, 0) AS declined_count, 
        COALESCE(asum.no_response_count, 0) AS no_response_count,
        ur.user_highest_role_on_team, ue.notify_admins_changes, ue.notify_admins_all, ue.payment_required, 
        -- Updated Logic: Checks for ANY completed payment for this User and Event
        COALESCE((
            SELECT TRUE 
            FROM public.event_user_member_payment eup 
            WHERE eup.event_id = ue.event_id 
              AND eup.user_id = p_user_id 
              AND eup.payment_status = 'confirmed' 
            LIMIT 1
        ), FALSE) AS event_paid
    FROM upcoming_events AS ue
    LEFT JOIN user_roles AS ur ON ue.team_id = ur.team_id
    LEFT JOIN public.users AS u ON ue.created_by = u.user_id 
    LEFT JOIN (
        SELECT DISTINCT ON (ue.event_id)
            ue.event_id, m.member_id, m.first_name AS member_first_name, m.last_name AS member_last_name, r.role_level AS member_role_level, ue.event_role_level
        FROM upcoming_events AS ue
        JOIN public.user_member_link AS uml ON uml.user_id = p_user_id
        JOIN public.members AS m ON uml.member_id = m.member_id
        JOIN public.member_team_link AS mtl ON m.member_id = mtl.member_id AND mtl.team_id = ue.team_id
        JOIN public.member_team_role_link AS mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN public.roles AS r ON mtrl.role_id = r.role_id
        WHERE r.role_level >= ue.event_role_level
        ORDER BY ue.event_id, r.role_level ASC
    ) AS rm ON ue.event_id = rm.event_id
    LEFT JOIN latest_attendance_records AS lar_user ON lar_user.member_id = rm.member_id AND lar_user.event_id = ue.event_id
    LEFT JOIN public.event_response_type AS ert ON lar_user.response_id = ert.response_id
    LEFT JOIN attendance_summary AS asum ON ue.event_id = asum.event_id
    WHERE rm.member_id IS NOT NULL 
    ORDER BY ue.event_date_time ASC
)
SELECT
    jsonb_build_object(
        'user_id', ud.user_id, 'first_name', ud.first_name, 'last_name', ud.last_name, 'email_address', ud.email_address, 'phone_number', ud.phone_number,
        'highest_role_level', ud.highest_role_level, 'user_onboarded', ud.user_onboarded, 'unread_notifications', ud.unread_notifications,
        'show_advert', ud.show_advert,
        'user_team_count', (SELECT COUNT(DISTINCT team_id) + 1 FROM user_roles),
        'user_teams', (
            SELECT jsonb_agg(t) FROM (
                SELECT team_id, team_name, team_unique_code, profile_pic, team_female, club_id, user_highest_role_on_team, sort_order 
                FROM (
                    SELECT 0::bigint AS team_id, 'All Teams'::text AS team_name, NULL::text AS team_unique_code, NULL::text AS profile_pic, FALSE AS team_female, 0::bigint AS club_id, 0::smallint AS user_highest_role_on_team, 0 AS sort_order
                    UNION ALL
                    SELECT t.team_id, t.team_name, t.team_unique_code, t.profile_pic, t.team_female, t.club_id, ur.user_highest_role_on_team, 1 AS sort_order
                    FROM public.teams t 
                    JOIN user_roles ur ON t.team_id = ur.team_id
                ) teams_union ORDER BY sort_order, team_name
            ) t
        ),
        'clubs', (
            SELECT jsonb_agg(c) FROM (
                SELECT DISTINCT club_id, club_name, county, banner, crest, sort_order FROM (
                    SELECT c.club_id, c.club_name, c.county, c.banner, c.crest, 1 AS sort_order
                    FROM public.teams t
                    JOIN user_roles ur ON t.team_id = ur.team_id
                    JOIN public.clubs c ON t.club_id = c.club_id
                    UNION ALL
                    SELECT NULL, 'All Clubs', NULL, NULL, 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/coach-smart-new-mpqa5l/assets/yk304zt4r8kj/Launcher_Icon_v2-removebg-preview.png', 0
                ) clubs_union ORDER BY sort_order, club_name
            ) c
        ),
        'events', (SELECT COALESCE(jsonb_agg(fed), '[]'::jsonb) FROM final_events_data fed)
    )
FROM user_details AS ud;
$$;


ALTER FUNCTION "public"."get_user_home_events"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_members_event_attendance"("p_event_id" bigint, "p_user_id" "uuid") RETURNS TABLE("member_id" bigint, "first_name" "text", "last_name" "text", "latest_response_value" "text", "response_created_at" timestamp with time zone, "is_accepted" boolean)
    LANGUAGE "sql"
    AS $$
WITH event_team AS (
    -- 1. Get the single team_id associated with the Event
    SELECT team_id
    FROM public.events
    WHERE event_id = p_event_id
),
latest_member_attendance AS (
    -- 2. Find the single latest attendance record for ALL members for this event
    SELECT
        ea.member_id,
        ea.response_id, -- NOW SELECTING THE ID
        ert.response_value,
        ea.created_at AS response_created_at,
        ROW_NUMBER() OVER (
            PARTITION BY ea.member_id
            ORDER BY ea.created_at DESC
        ) as rn
    FROM
        public.event_attendance ea
    JOIN
        public.event_response_type ert ON ea.response_id = ert.response_id
    WHERE
        ea.event_id = p_event_id
)
SELECT
    m.member_id,
    m.first_name,
    m.last_name,
    lta.response_value AS latest_response_value,
    lta.response_created_at,
    CASE
        -- Use the ID for the boolean check
        WHEN lta.response_id = 3 THEN TRUE
        -- If an attendance record exists (response_id is NOT NULL) but isn't 3 (Accepted), assume FALSE (Declined/Maybe)
        WHEN lta.response_id IS NOT NULL THEN FALSE
        ELSE NULL -- If no attendance record (lta is NULL from LEFT JOIN)
    END AS is_accepted
FROM
    public.members m
JOIN
    public.user_member_link uml ON m.member_id = uml.member_id
JOIN
    public.member_team_link mtl ON m.member_id = mtl.member_id
JOIN
    event_team et ON mtl.team_id = et.team_id AND et.team_id IS NOT NULL
LEFT JOIN
    latest_member_attendance lta ON m.member_id = lta.member_id AND lta.rn = 1
WHERE
    uml.user_id = p_user_id
ORDER BY
    m.last_name, m.first_name;
$$;


ALTER FUNCTION "public"."get_user_members_event_attendance"("p_event_id" bigint, "p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_notifications"("p_user_id" "uuid") RETURNS TABLE("id" bigint, "created_at" "text", "time_label" "text", "app_title" "text", "app_body" "text", "is_read" boolean, "link_page" "text", "team_id" bigint, "team_name" "text", "event_id" bigint)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        n.id,
        to_char(n.created_at, 'Dy, DD Mon YYYY "at" HH12:MI AM')::text,
        -- Refined Time Ago Logic
        CASE 
            WHEN n.created_at > now() - interval '2 minutes' 
                THEN 'Just now'
            WHEN n.created_at > now() - interval '1 hour' 
                THEN floor(extract(epoch from (now() - n.created_at)) / 60)::text || 'm ago'
            WHEN n.created_at > now() - interval '24 hours' THEN 
                CASE 
                    WHEN floor(extract(epoch from (now() - n.created_at)) / 3600) = 1 THEN '1 hour ago'
                    ELSE floor(extract(epoch from (now() - n.created_at)) / 3600)::text || ' hours ago'
                END
            ELSE 
                CASE 
                    WHEN floor(extract(epoch from (now() - n.created_at)) / 86400) = 1 THEN '1 day ago'
                    ELSE floor(extract(epoch from (now() - n.created_at)) / 86400)::text || ' days ago'
                END
        END as time_label,
        
        COALESCE(n.app_title, n.push_title, 'Notification') as title,
        COALESCE(n.app_body, n.push_body, '') as body,
        n.is_read,
        n.link_page,
        n.team_id,
        COALESCE(t.team_name, 'General') as team_name,
        n.event_id    
    FROM 
        public.notifications n
    LEFT JOIN 
        public.teams t ON n.team_id = t.team_id
    WHERE 
        n.recipient_user_id = p_user_id
    ORDER BY 
        n.created_at DESC;
END;
$$;


ALTER FUNCTION "public"."get_user_notifications"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_team_summary"("p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_overall_highest smallint;
    v_teams_json jsonb;
BEGIN
    -- 1. Get the absolute MAX role level across all members LINKED to this user
    SELECT MAX(r.role_level) INTO v_overall_highest
    FROM public.user_member_link uml
    JOIN public.member_team_link mtl ON uml.member_id = mtl.member_id
    JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.roles r ON mtrl.role_id = r.role_id
    WHERE uml.user_id = p_user_id;

    -- 2. Build the flat team list for members explicitly linked to this user
    SELECT jsonb_agg(t_final) INTO v_teams_json
    FROM (
        SELECT DISTINCT ON (t.team_id)
            t.team_id,
            t.team_name,
            t.team_unique_code,
            r.role_level as team_highest_role_level,
            r.role_name as team_role_name
        FROM public.user_member_link uml
        INNER JOIN public.member_team_link mtl ON uml.member_id = mtl.member_id
        INNER JOIN public.teams t ON mtl.team_id = t.team_id
        INNER JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        INNER JOIN public.roles r ON mtrl.role_id = r.role_id
        WHERE uml.user_id = p_user_id
        ORDER BY t.team_id, r.role_level DESC 
    ) t_final;

    RETURN jsonb_build_object(
        'overall_highest_role_level', COALESCE(v_overall_highest, 0),
        'teams', COALESCE(v_teams_json, '[]'::jsonb)
    );
END;
$$;


ALTER FUNCTION "public"."get_user_team_summary"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  -- Call the existing function to migrate the legacy user data.
  PERFORM public.migrate_legacy_user_on_signup();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_owner_of_member_team_role"("role_link_id" bigint) RETURNS boolean
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.member_team_role_link mtrl
    JOIN public.member_team_link mtl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.members m ON mtl.member_id = m.member_id
    WHERE mtrl.member_team_role_id = role_link_id
    AND m.user_id = (SELECT auth.uid())
  );
$$;


ALTER FUNCTION "public"."is_owner_of_member_team_role"("role_link_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."migrate_legacy_user_on_signup"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    legacy_user_rec public.legacy_users%rowtype;
    existing_user_id UUID;
    new_member_id bigint;
    coach_admin_member_id bigint;
    player_member_team_id bigint;
    coach_admin_member_team_id bigint;
    player_role_id bigint := 6;      -- Role ID for a Player
    coach_role_id bigint := 8;        -- Role ID for a Coach
    admin_role_id bigint := 7;        -- Role ID for an Admin
    found_legacy_users BOOLEAN := FALSE; -- A flag to check if any legacy users were found.
BEGIN
    -- STEP 1: Check if a user with this email already exists in public.users.
    SELECT user_id
    INTO existing_user_id
    FROM public.users
    WHERE email_address = NEW.email;

    -- If a user already exists, we do nothing and exit the function.
    IF existing_user_id IS NOT NULL THEN
        RAISE NOTICE 'User profile for "%" already exists. No action needed.', NEW.email;
        RETURN NEW;
    END IF;

    -- STEP 2: Find all matching legacy user records.
    -- We'll use a `SELECT...INTO` statement to find the first matching legacy user
    -- to get the first name, last name, and phone number for the user profile.
    SELECT *
    INTO legacy_user_rec
    FROM public.legacy_users
    WHERE email_address = NEW.email AND (processed = false OR processed IS NULL)
    LIMIT 1;

    -- STEP 3: Create the user profile in public.users.
    -- This block runs only if a legacy user record was found.
    IF legacy_user_rec.id IS NOT NULL THEN
        found_legacy_users := TRUE;
        -- Create the new user profile using the data from the first legacy record.
        INSERT INTO public.users (user_id, email_address, first_name, last_name, phone_number)
        VALUES (NEW.id, NEW.email, legacy_user_rec.user_first_name, legacy_user_rec.user_last_name, legacy_user_rec.phone_number);
    ELSE
        -- If no legacy users were found, this is a new sign-up. Create a new public.users record.
        INSERT INTO public.users (user_id, email_address)
        VALUES (NEW.id, NEW.email);
        RAISE NOTICE 'Created new user profile for email "%" with new user ID %.', NEW.email, NEW.id;
    END IF;

    -- STEP 4: Iterate through all matching legacy user records using a FOR loop.
    -- The main user profile has already been created above.
    FOR legacy_user_rec IN
        SELECT *
        FROM public.legacy_users
        WHERE email_address = NEW.email AND (processed = false OR processed IS NULL)
    LOOP
        -- Create the primary member record for the player.
        INSERT INTO public.members (first_name, last_name, user_id, profile_pic)
        VALUES (legacy_user_rec.member_first_name, legacy_user_rec.member_last_name, NEW.id, 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/hvxmhKxoCA4XCjUFmpM6/assets/50b842h4zvrj/image-removebg-preview_(14).png')
        RETURNING member_id INTO new_member_id;

        -- Link the new user to this new member.
        INSERT INTO public.user_member_link (user_id, member_id)
        VALUES (NEW.id, new_member_id);

        -- Link the new member to the team from the legacy record.
        INSERT INTO public.member_team_link (member_id, team_id)
        VALUES (new_member_id, legacy_user_rec.team_id::bigint)
        RETURNING member_team_id INTO player_member_team_id;

        -- Link the player member-team record to the 'Player' role (ID 6).
        INSERT INTO public.member_team_role_link (member_team_id, role_id)
        VALUES (player_member_team_id, player_role_id);

        -- Check for 'Coach' or 'Admin' roles to create a second member record.
        IF legacy_user_rec.role IN ('Coach', 'Admin') THEN
            -- Check if a member record already exists for the user (the coach/admin).
            -- We're looking for a member with the same user ID and first/last name.
            SELECT member_id
            INTO coach_admin_member_id
            FROM public.members
            WHERE user_id = NEW.id
            AND first_name = legacy_user_rec.user_first_name
            AND last_name = legacy_user_rec.user_last_name
            LIMIT 1;

            -- If a member doesn't already exist for this user, create one.
            IF coach_admin_member_id IS NULL THEN
                -- Create a second member record for the user (the coach/admin).
                INSERT INTO public.members (first_name, last_name, user_id, profile_pic)
                VALUES (legacy_user_rec.user_first_name, legacy_user_rec.user_last_name, NEW.id, 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/hvxmhKxoCA4XCjUFmpM6/assets/50b842h4zvrj/image-removebg-preview_(14).png')
                RETURNING member_id INTO coach_admin_member_id;

                -- Link the new user to this second member record.
                INSERT INTO public.user_member_link (user_id, member_id)
                VALUES (NEW.id, coach_admin_member_id);
            END IF;

            -- Link this coach/admin member to the team.
            INSERT INTO public.member_team_link (member_id, team_id)
            VALUES (coach_admin_member_id, legacy_user_rec.team_id::bigint)
            RETURNING member_team_id INTO coach_admin_member_team_id;

            -- Always link this second member to the 'Coach' role (ID 8).
            INSERT INTO public.member_team_role_link (member_team_id, role_id)
            VALUES (coach_admin_member_team_id, coach_role_id);

            -- If the role is 'Admin', also link them to the 'Admin' role (ID 7).
            IF legacy_user_rec.role = 'Admin' THEN
                INSERT INTO public.member_team_role_link (member_team_id, role_id)
                VALUES (coach_admin_member_team_id, admin_role_id);
            END IF;
        END IF;

        -- Mark the specific legacy user record as processed.
        UPDATE public.legacy_users
        SET processed = true
        WHERE id = legacy_user_rec.id;

        RAISE NOTICE 'Successfully migrated legacy user record with ID % for email "%" with new user ID %.', legacy_user_rec.id, NEW.email, NEW.id;
    END LOOP;

    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."migrate_legacy_user_on_signup"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_admins_attendance_change"("p_event_id_param" integer, "p_member_id_param" integer, "p_response_id" integer, "p_attendance_id" bigint) RETURNS TABLE("notifications_created" integer)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    created_count         INT := 0;
    v_logo_url            TEXT := 'https://gyfporsbdftvtakdvukt.supabase.co/storage/v1/object/sign/coachsmartimages/CoachSmart%20Logo%20Transparent.png?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV82OTA4NmRkYy01MWQ3LTQ1NzUtYWYwMC1mZjQxYmMyNDU2YWMiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJjb2FjaHNtYXJ0aW1hZ2VzL0NvYWNoU21hcnQgTG9nbyBUcmFuc3BhcmVudC5wbmciLCJpYXQiOjE3NzQ2MDYzOTksImV4cCI6MjYzODYwNjM5OX0.20yMzSYnG08kYjMK6cmGMvwA6VPGvm9_yHG-CmEfSIs';
    v_notify_all          BOOLEAN;
    v_notify_changes      BOOLEAN;
    v_prev_response_id    BIGINT;
    v_is_change_of_mind   BOOLEAN := false;
    v_response_word       TEXT;
    v_prev_response_word  TEXT;
    v_response_colour     TEXT;
    v_prev_response_colour TEXT;
    v_badge_label         TEXT;
    v_admin_count         INT := 0;
    v_event_exists        BOOLEAN := false;
    v_member_exists       BOOLEAN := false;
    v_actor_user_id       UUID;
BEGIN

    RAISE NOTICE '=== notify_admins_attendance_change START ===';
    RAISE NOTICE 'Inputs: p_event_id_param=%, p_member_id_param=%, p_response_id=%, p_attendance_id=%',
        p_event_id_param, p_member_id_param, p_response_id, p_attendance_id;

    -- -------------------------------------------------------------------------
    -- STEP 1: Check event exists and read notification flags
    -- -------------------------------------------------------------------------
    SELECT
        true,
        COALESCE(notify_admins_all, false),
        COALESCE(notify_admins_changes, false)
    INTO v_event_exists, v_notify_all, v_notify_changes
    FROM public.events
    WHERE event_id = p_event_id_param;

    IF NOT v_event_exists THEN
        RAISE NOTICE 'EXIT: Event % not found', p_event_id_param;
        RETURN QUERY SELECT 0;
        RETURN;
    END IF;

    RAISE NOTICE 'Event found: notify_admins_all=%, notify_admins_changes=%', v_notify_all, v_notify_changes;

    IF NOT v_notify_all AND NOT v_notify_changes THEN
        RAISE NOTICE 'EXIT: Both notification flags are false/null — nothing to do';
        RETURN QUERY SELECT 0;
        RETURN;
    END IF;

    -- -------------------------------------------------------------------------
    -- STEP 2: Check member exists
    -- -------------------------------------------------------------------------
    SELECT true INTO v_member_exists
    FROM public.members
    WHERE member_id = p_member_id_param;

    IF NOT v_member_exists THEN
        RAISE NOTICE 'EXIT: Member % not found', p_member_id_param;
        RETURN QUERY SELECT 0;
        RETURN;
    END IF;

    RAISE NOTICE 'Member % found', p_member_id_param;

    -- -------------------------------------------------------------------------
    -- STEP 2b: Resolve the actor's user_id so we can exclude them regardless
    --          of which member record they hold an admin role under.
    -- -------------------------------------------------------------------------
    SELECT uml.user_id INTO v_actor_user_id
    FROM public.user_member_link uml
    WHERE uml.member_id = p_member_id_param
    LIMIT 1;

    RAISE NOTICE 'Actor user_id resolved: %', v_actor_user_id;

    -- -------------------------------------------------------------------------
    -- STEP 3: Look up previous attendance record (strictly before p_attendance_id)
    -- -------------------------------------------------------------------------
    SELECT response_id
    INTO v_prev_response_id
    FROM public.event_attendance
    WHERE event_id    = p_event_id_param
      AND member_id   = p_member_id_param
      AND attendance_id < p_attendance_id
    ORDER BY attendance_id DESC
    LIMIT 1;

    RAISE NOTICE 'Previous attendance lookup: attendance_id < % → prev_response_id=%',
        p_attendance_id, v_prev_response_id;

    -- -------------------------------------------------------------------------
    -- STEP 4: Apply flag logic gate
    -- -------------------------------------------------------------------------
    IF NOT v_notify_all AND v_notify_changes THEN
        RAISE NOTICE 'Mode: notify_changes only — checking for genuine change of mind';
        IF v_prev_response_id IS NULL THEN
            RAISE NOTICE 'EXIT: No previous response found — first time responding, skipping';
            RETURN QUERY SELECT 0;
            RETURN;
        END IF;
        IF v_prev_response_id = p_response_id THEN
            RAISE NOTICE 'EXIT: Previous response (%) = current response (%) — no change of mind, skipping',
                v_prev_response_id, p_response_id;
            RETURN QUERY SELECT 0;
            RETURN;
        END IF;
        v_is_change_of_mind := true;
        RAISE NOTICE 'Change of mind confirmed: % → %', v_prev_response_id, p_response_id;
    END IF;

    IF v_notify_all THEN
        RAISE NOTICE 'Mode: notify_all — will create notification regardless';
        IF v_prev_response_id IS NOT NULL AND v_prev_response_id <> p_response_id THEN
            v_is_change_of_mind := true;
            RAISE NOTICE 'Also a change of mind: % → %', v_prev_response_id, p_response_id;
        END IF;
    END IF;

    -- -------------------------------------------------------------------------
    -- STEP 5: Resolve messaging variables
    -- -------------------------------------------------------------------------
    v_response_word := CASE p_response_id
        WHEN 3 THEN 'accepted'
        WHEN 4 THEN 'declined'
        ELSE        'updated'
    END;

    v_prev_response_word := CASE v_prev_response_id
        WHEN 3 THEN 'accepted'
        WHEN 4 THEN 'declined'
        ELSE        'updated'
    END;

    v_response_colour := CASE p_response_id
        WHEN 3 THEN '#87C232'
        WHEN 4 THEN '#e05252'
        ELSE        '#e7ebee'
    END;

    v_prev_response_colour := CASE v_prev_response_id
        WHEN 3 THEN '#87C232'
        WHEN 4 THEN '#e05252'
        ELSE        '#e7ebee'
    END;

    v_badge_label := CASE
        WHEN v_is_change_of_mind THEN 'CHANGE OF ATTENDANCE'
        WHEN p_response_id = 3   THEN 'ATTENDANCE ACCEPTED'
        WHEN p_response_id = 4   THEN 'ATTENDANCE DECLINED'
        ELSE                          'ATTENDANCE UPDATED'
    END;

    RAISE NOTICE 'Messaging: response_word=%, prev_response_word=%, badge_label=%, is_change_of_mind=%',
        v_response_word, v_prev_response_word, v_badge_label, v_is_change_of_mind;

    -- -------------------------------------------------------------------------
    -- STEP 6: Check admin count before attempting insert (excluding actor by user_id)
    -- -------------------------------------------------------------------------
    SELECT COUNT(DISTINCT u.user_id)
    INTO v_admin_count
    FROM public.member_team_link mtl
    JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.members m                  ON mtl.member_id = m.member_id
    JOIN public.user_member_link uml       ON m.member_id = uml.member_id
    JOIN public.users u                    ON uml.user_id = u.user_id
    JOIN public.events e                   ON e.team_id = mtl.team_id
    WHERE e.event_id = p_event_id_param
      AND mtrl.role_id = 7
      AND u.user_id != v_actor_user_id;

    RAISE NOTICE 'Admin users found for team (excluding actor user_id=%): %', v_actor_user_id, v_admin_count;

    IF v_admin_count = 0 THEN
        RAISE NOTICE 'WARN: No other admin users (role_id=7) found for this team — no notifications will be created';
    END IF;

    -- -------------------------------------------------------------------------
    -- STEP 7: Insert one notification record per team admin (excluding actor by user_id)
    -- -------------------------------------------------------------------------
    RAISE NOTICE 'Proceeding with INSERT...';

    INSERT INTO public.notifications (
        recipient_user_id,
        team_id,
        event_id,
        link_page,
        is_delivered,
        is_read,
        delivery_method,
        created_at,
        push_title,
        push_body,
        email_title,
        email_body,
        app_title,
        app_body
    )
    WITH target_event AS (
        SELECT
            e.event_id,
            e.event_date_time,
            e.team_id,
            t.team_name,
            CASE
                WHEN e.event_title IS NOT NULL AND e.event_title <> '' THEN e.event_title
                ELSE (
                    CASE
                        WHEN t.team_female = true AND ec.code_id = 3 THEN 'Camogie'
                        ELSE COALESCE(ec.event_code, '')
                    END || ' ' ||
                    COALESCE(et.event_type, '') ||
                    CASE
                        WHEN et.event_type_id = 2
                         AND e.opposition IS NOT NULL
                         AND e.opposition <> ''
                        THEN ' - ' || e.opposition
                        ELSE ''
                    END
                )
            END AS display_title,
            trim(to_char(e.event_date_time, 'Day, Mon DD, YYYY "at" HH24:MI')) AS date_time_formatted
        FROM public.events e
        JOIN public.teams t ON e.team_id = t.team_id
        LEFT JOIN public.event_codes ec ON e.event_code_id = ec.code_id
        LEFT JOIN public.event_types et ON e.event_type_id = et.event_type_id
        WHERE e.event_id = p_event_id_param
    ),
    changing_member AS (
        SELECT
            COALESCE(
                NULLIF(trim(m.first_name || ' ' || COALESCE(m.last_name, '')), ''),
                'A member'
            ) AS full_name
        FROM public.members m
        WHERE m.member_id = p_member_id_param
    ),
    admin_users AS (
        SELECT DISTINCT
            u.user_id,
            u.first_name AS user_fname,
            u.fcm_token
        FROM target_event te
        JOIN public.member_team_link mtl       ON te.team_id = mtl.team_id
        JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        JOIN public.members m                  ON mtl.member_id = m.member_id
        JOIN public.user_member_link uml       ON m.member_id = uml.member_id
        JOIN public.users u                    ON uml.user_id = u.user_id
        WHERE mtrl.role_id = 7
          AND u.user_id != v_actor_user_id  -- exclude the user who made the change (by user_id, handles multiple member records)
    )
    SELECT
        au.user_id,
        te.team_id,
        te.event_id,

        'coachsmartv2://coachsmartv2.com/eventDetails?eventID=' || te.event_id::text || '&fromSearch=false',

        false,  -- is_delivered

        -- is_read: true for email (user sees it in inbox), false for push (requires app interaction)
        CASE
            WHEN au.fcm_token IS NOT NULL AND au.fcm_token <> '' THEN false
            ELSE true
        END,

        CASE
            WHEN au.fcm_token IS NOT NULL AND au.fcm_token <> '' THEN 'push'
            ELSE 'email'
        END,

        NOW(),

        -- push_title
        te.team_name || ': Change of Attendance',

        -- push_body
        CASE
            WHEN v_is_change_of_mind THEN
                cm.full_name || ' has changed their attendance from ' ||
                v_prev_response_word || ' to ' || v_response_word || ' for ' ||
                trim(te.display_title) || ' on ' || te.date_time_formatted
            ELSE
                cm.full_name || ' has ' || v_response_word || ' attendance for ' ||
                trim(te.display_title) || ' on ' || te.date_time_formatted
        END,

        -- email_title
        CASE
            WHEN v_is_change_of_mind THEN
                te.team_name || ': Change of Attendance — ' || cm.full_name
            ELSE
                te.team_name || ': ' ||
                CASE p_response_id
                    WHEN 3 THEN 'Attendance Accepted'
                    WHEN 4 THEN 'Attendance Declined'
                    ELSE        'Attendance Updated'
                END || ' — ' || cm.full_name
        END,

        -- email_body HTML
        '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>CoachSmart</title></head>' ||
        '<body style="margin:0;padding:0;background-color:#111418;font-family:Arial,Helvetica,sans-serif;">' ||
        '<table width="100%" cellpadding="0" cellspacing="0" style="padding:40px 20px;"><tr><td align="center">' ||
        '<table width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background-color:#212529;border-radius:16px;overflow:hidden;border:1px solid #3a3f4b;">' ||

        -- Header
        '<tr><td style="background-color:#1E222B;padding:28px 24px;text-align:center;border-bottom:3px solid #87C232;">' ||
        '<table cellpadding="0" cellspacing="0" style="margin:0 auto;"><tr>' ||
        '<td style="padding-right:16px;vertical-align:middle;">' ||
        '<img src="' || v_logo_url || '" alt="CoachSmart" width="80" style="display:block;height:auto;border:0;"></td>' ||
        '<td style="vertical-align:middle;text-align:left;">' ||
        '<p style="margin:0;font-size:26px;font-weight:900;letter-spacing:2.5px;line-height:1;font-family:Arial,Helvetica,sans-serif;">' ||
        '<span style="color:#c8ccd0;">COACH</span><span style="color:#87C232;">SMART</span></p>' ||
        '<p style="margin:5px 0 0 0;font-size:9px;font-weight:700;letter-spacing:4px;color:#87C232;font-family:Arial,Helvetica,sans-serif;">COACHING&nbsp;&nbsp;MADE&nbsp;&nbsp;SIMPLE</p>' ||
        '</td></tr></table></td></tr>' ||

        -- Body
        '<tr><td style="padding:28px 28px 24px;">' ||
        '<p style="margin:0 0 6px 0;font-size:15px;color:#e7ebee;font-family:Arial,Helvetica,sans-serif;">Hi ' || au.user_fname || ',</p>' ||

        CASE
            WHEN v_is_change_of_mind THEN
                '<p style="margin:0 0 20px 0;font-size:14px;color:#a3a3a3;line-height:1.6;font-family:Arial,Helvetica,sans-serif;">' ||
                '<strong style="color:#e7ebee;">' || cm.full_name || '</strong> has changed their attendance from ' ||
                '<strong style="color:' || v_prev_response_colour || ';">' || v_prev_response_word || '</strong>' ||
                ' to <strong style="color:' || v_response_colour || ';">' || v_response_word || '</strong> for the following event:</p>'
            ELSE
                '<p style="margin:0 0 20px 0;font-size:14px;color:#a3a3a3;line-height:1.6;font-family:Arial,Helvetica,sans-serif;">' ||
                '<strong style="color:#e7ebee;">' || cm.full_name || '</strong> has <strong style="color:' || v_response_colour || ';">' || v_response_word || '</strong> attendance for the following event:</p>'
        END ||

        -- Event card
        '<table width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 22px 0;"><tr>' ||
        '<td style="background:#2c313a;border-left:3px solid #87C232;padding:16px 18px;border-radius:0 8px 8px 0;">' ||
        '<p style="margin:0 0 5px 0;color:#e7ebee;font-size:15px;font-weight:700;font-family:Arial,Helvetica,sans-serif;">' || trim(te.display_title) || '</p>' ||
        '<p style="margin:0;color:#a3a3a3;font-size:13px;font-family:Arial,Helvetica,sans-serif;">' || te.date_time_formatted || '</p>' ||
        '</td></tr></table>' ||

        -- Status badge
        '<table width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 4px 0;"><tr>' ||
        '<td style="background:#2c313a;border-radius:8px;padding:16px 18px;border:1px solid #3a3f4b;">' ||
        '<p style="margin:0 0 4px 0;font-size:13px;font-weight:700;color:#87C232;font-family:Arial,Helvetica,sans-serif;letter-spacing:0.5px;">' || v_badge_label || '</p>' ||
        '<p style="margin:0;font-size:13px;color:#a3a3a3;line-height:1.6;font-family:Arial,Helvetica,sans-serif;">' ||
        CASE
            WHEN v_is_change_of_mind THEN
                cm.full_name || ' has changed their mind. You may wish to review your squad in the CoachSmart app.'
            ELSE
                cm.full_name || ' has ' || v_response_word || ' their attendance. You may wish to review your squad in the CoachSmart app.'
        END ||
        '</p></td></tr></table>' ||

        '</td></tr>' ||

        -- Footer
        '<tr><td style="padding:16px 28px;border-top:1px solid #3a3f4b;text-align:center;">' ||
        '<p style="margin:0 0 4px 0;font-size:11px;color:#555;letter-spacing:1.5px;font-family:Arial,Helvetica,sans-serif;">COACHSMART &middot; COACHING MADE SIMPLE</p>' ||
        '<p style="margin:0;font-size:11px;color:#444;font-family:Arial,Helvetica,sans-serif;">You received this because you are a team admin on CoachSmart.</p>' ||
        '</td></tr>' ||

        '</table></td></tr></table></body></html>',

        -- app_title
        CASE
            WHEN v_is_change_of_mind THEN
                'Change of Attendance — ' || cm.full_name
            ELSE
                CASE p_response_id
                    WHEN 3 THEN 'Attendance Accepted'
                    WHEN 4 THEN 'Attendance Declined'
                    ELSE        'Attendance Updated'
                END || ' — ' || cm.full_name
        END,

        -- app_body
        CASE
            WHEN v_is_change_of_mind THEN
                cm.full_name || ' has changed their attendance from ' ||
                v_prev_response_word || ' to ' || v_response_word || ' for ' ||
                trim(te.display_title) || ' on ' || te.date_time_formatted
            ELSE
                cm.full_name || ' has ' || v_response_word || ' attendance for ' ||
                trim(te.display_title) || ' on ' || te.date_time_formatted
        END

    FROM admin_users au
    CROSS JOIN target_event te
    CROSS JOIN changing_member cm;

    GET DIAGNOSTICS created_count = ROW_COUNT;

    RAISE NOTICE 'INSERT complete: % notification row(s) created', created_count;
    RAISE NOTICE '=== notify_admins_attendance_change END ===';

    RETURN QUERY SELECT created_count;
END;
$$;


ALTER FUNCTION "public"."notify_admins_attendance_change"("p_event_id_param" integer, "p_member_id_param" integer, "p_response_id" integer, "p_attendance_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."populate_event_notifications"("p_event_id_param" integer, "p_role_grade" integer DEFAULT NULL::integer, "p_role_level" integer DEFAULT NULL::integer) RETURNS TABLE("notifications_created" integer)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    created_count INT := 0;
    v_logo_url TEXT := 'https://gyfporsbdftvtakdvukt.supabase.co/storage/v1/object/sign/coachsmartimages/CoachSmart%20Logo%20Transparent.png?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV82OTA4NmRkYy01MWQ3LTQ1NzUtYWYwMC1mZjQxYmMyNDU2YWMiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJjb2FjaHNtYXJ0aW1hZ2VzL0NvYWNoU21hcnQgTG9nbyBUcmFuc3BhcmVudC5wbmciLCJpYXQiOjE3NzQ2MDYzOTksImV4cCI6MjYzODYwNjM5OX0.20yMzSYnG08kYjMK6cmGMvwA6VPGvm9_yHG-CmEfSIs';
BEGIN
    INSERT INTO public.notifications (
        recipient_user_id,
        team_id,
        event_id,
        link_page,
        is_delivered,
        is_read,
        delivery_method,
        created_at,
        push_title,
        push_body,
        email_title,
        email_body,
        app_title,
        app_body
    )
    WITH target_event AS (
        SELECT
            e.event_id,
            e.event_date_time,
            e.team_id,
            t.team_name,
            CASE
                WHEN e.event_title IS NOT NULL AND e.event_title <> '' THEN e.event_title
                ELSE (
                    CASE
                        WHEN t.team_female = true AND ec.code_id = 3 THEN 'Camogie'
                        ELSE COALESCE(ec.event_code, '')
                    END || ' ' ||
                    COALESCE(et.event_type, '') ||
                    CASE
                        WHEN et.event_type_id = 2 AND e.opposition IS NOT NULL AND e.opposition <> ''
                        THEN ' - ' || e.opposition
                        ELSE ''
                    END
                )
            END AS display_title,
            trim(to_char(e.event_date_time, 'Day, Mon DD, YYYY "at" HH24:MI')) AS date_time_formatted
        FROM public.events e
        JOIN public.teams t ON e.team_id = t.team_id
        LEFT JOIN public.event_codes ec ON e.event_code_id = ec.code_id
        LEFT JOIN public.event_types et ON e.event_type_id = et.event_type_id
        WHERE e.event_id = p_event_id_param
    ),
    -- Find all unresponded members per user for this event
    unresponded_members AS (
        SELECT
            m.member_id,
            m.first_name AS member_fname,
            u.user_id,
            u.first_name AS user_fname,
            u.fcm_token,
            r.role_grade,
            r.role_level
        FROM target_event te
        JOIN public.member_team_link mtl ON te.team_id = mtl.team_id
        JOIN public.members m ON mtl.member_id = m.member_id
        JOIN public.user_member_link uml ON m.member_id = uml.member_id
        JOIN public.users u ON uml.user_id = u.user_id
        LEFT JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
        LEFT JOIN public.roles r ON mtrl.role_id = r.role_id
        WHERE
            NOT EXISTS (
                SELECT 1
                FROM public.event_attendance ea
                WHERE ea.event_id = p_event_id_param
                AND ea.member_id = m.member_id
                AND ea.response_id IS NOT NULL
                AND ea.response_id > 0
            )
            AND (p_role_grade IS NULL OR r.role_grade = p_role_grade)
            AND (p_role_level IS NULL OR r.role_level >= p_role_level)
    ),
    -- Consolidate all unresponded members into one row per user
    consolidated_per_user AS (
        SELECT
            um.user_id,
            um.user_fname,
            um.fcm_token,
            te.team_id,
            te.event_id,
            te.team_name,
            te.display_title,
            te.date_time_formatted,
            COUNT(um.member_id) AS member_count,
            CASE
                WHEN COUNT(um.member_id) = 1 THEN
                    MAX(um.member_fname)
                WHEN COUNT(um.member_id) = 2 THEN
                    MIN(um.member_fname) || ' and ' || MAX(um.member_fname)
                ELSE
                    (
                        SELECT string_agg(member_fname, ', ' ORDER BY member_fname)
                        FROM (
                            SELECT member_fname
                            FROM unresponded_members um2
                            WHERE um2.user_id = um.user_id
                            ORDER BY member_fname
                            LIMIT (COUNT(um.member_id) - 1)
                        ) all_but_last
                    ) || ' and ' || (
                        SELECT member_fname
                        FROM unresponded_members um3
                        WHERE um3.user_id = um.user_id
                        ORDER BY member_fname DESC
                        LIMIT 1
                    )
            END AS member_name_list
        FROM unresponded_members um
        CROSS JOIN target_event te
        GROUP BY
            um.user_id,
            um.user_fname,
            um.fcm_token,
            te.team_id,
            te.event_id,
            te.team_name,
            te.display_title,
            te.date_time_formatted
    )
    SELECT
        cpu.user_id,
        cpu.team_id,
        cpu.event_id,

        -- Native deep link — used for banner tap and backgrounded tap.
        -- Edge function converts to Netlify Universal Link in
        -- apns.fcm_options.link for iOS cold start only.
        'coachsmartv2://coachsmartv2.com/eventDetails?eventID=' || cpu.event_id::text || '&fromSearch=false',

        false,  -- is_delivered
        false,  -- is_read

        CASE
            WHEN cpu.fcm_token IS NOT NULL AND cpu.fcm_token <> ''
            THEN 'push'
            ELSE 'email'
        END,

        NOW(),

        -- push_title
        cpu.team_name,

        -- push_body
        CASE
            WHEN cpu.member_count = 1 THEN
                'Attendance response needed for ' || cpu.member_name_list || ' — ' || trim(cpu.display_title)
            ELSE
                'Attendance responses needed for ' || cpu.member_name_list || ' — ' || trim(cpu.display_title)
        END,

        -- email_title
        cpu.team_name || ': ' ||
        CASE
            WHEN cpu.member_count = 1 THEN 'Response needed for ' || cpu.member_name_list
            ELSE 'Responses needed for ' || cpu.member_name_list
        END,

        -- email_body HTML — logo and wordmark side by side in header
        '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>CoachSmart</title></head>' ||
        '<body style="margin:0;padding:0;background-color:#111418;font-family:Arial,Helvetica,sans-serif;">' ||
        '<table width="100%" cellpadding="0" cellspacing="0" style="padding:40px 20px;"><tr><td align="center">' ||
        '<table width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background-color:#212529;border-radius:16px;overflow:hidden;border:1px solid #3a3f4b;">' ||

        -- Header: logo left, wordmark right, side by side
        '<tr><td style="background-color:#1E222B;padding:28px 24px;text-align:center;border-bottom:3px solid #87C232;">' ||
        '<table cellpadding="0" cellspacing="0" style="margin:0 auto;"><tr>' ||
        '<td style="padding-right:16px;vertical-align:middle;">' ||
        '<img src="' || v_logo_url || '" alt="CoachSmart" width="80" style="display:block;height:auto;border:0;"></td>' ||
        '<td style="vertical-align:middle;text-align:left;">' ||
        '<p style="margin:0;font-size:26px;font-weight:900;letter-spacing:2.5px;line-height:1;font-family:Arial,Helvetica,sans-serif;">' ||
        '<span style="color:#c8ccd0;">COACH</span><span style="color:#87C232;">SMART</span></p>' ||
        '<p style="margin:5px 0 0 0;font-size:9px;font-weight:700;letter-spacing:4px;color:#87C232;font-family:Arial,Helvetica,sans-serif;">COACHING&nbsp;&nbsp;MADE&nbsp;&nbsp;SIMPLE</p>' ||
        '</td></tr></table></td></tr>' ||

        -- Body
        '<tr><td style="padding:28px 28px 24px;">' ||
        '<p style="margin:0 0 6px 0;font-size:15px;color:#e7ebee;font-family:Arial,Helvetica,sans-serif;">Hi ' || cpu.user_fname || ',</p>' ||

        CASE
            WHEN cpu.member_count = 1 THEN
                '<p style="margin:0 0 20px 0;font-size:14px;color:#a3a3a3;line-height:1.6;font-family:Arial,Helvetica,sans-serif;">' ||
                'A response is still needed for <strong style="color:#e7ebee;">' || cpu.member_name_list || '</strong> for the following event:</p>'
            ELSE
                '<p style="margin:0 0 20px 0;font-size:14px;color:#a3a3a3;line-height:1.6;font-family:Arial,Helvetica,sans-serif;">' ||
                'Responses are still needed for <strong style="color:#e7ebee;">' || cpu.member_name_list || '</strong> for the following event:</p>'
        END ||

        -- Event card
        '<table width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 22px 0;"><tr>' ||
        '<td style="background:#2c313a;border-left:3px solid #87C232;padding:16px 18px;border-radius:0 8px 8px 0;">' ||
        '<p style="margin:0 0 5px 0;color:#e7ebee;font-size:15px;font-weight:700;font-family:Arial,Helvetica,sans-serif;">' || trim(cpu.display_title) || '</p>' ||
        '<p style="margin:0;color:#a3a3a3;font-size:13px;font-family:Arial,Helvetica,sans-serif;">' || cpu.date_time_formatted || '</p>' ||
        '</td></tr></table>' ||

        -- Action required box
        '<table width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 4px 0;"><tr>' ||
        '<td style="background:#2c313a;border-radius:8px;padding:16px 18px;border:1px solid #3a3f4b;">' ||
        '<p style="margin:0 0 4px 0;font-size:13px;font-weight:700;color:#87C232;font-family:Arial,Helvetica,sans-serif;letter-spacing:0.5px;">ACTION REQUIRED</p>' ||
        '<p style="margin:0;font-size:13px;color:#a3a3a3;line-height:1.6;font-family:Arial,Helvetica,sans-serif;">' ||
        'Please open the <strong style="color:#e7ebee;">CoachSmart app</strong> on your device to confirm attendance. ' ||
        'Your team manager is waiting on your response.</p>' ||
        '</td></tr></table>' ||

        '</td></tr>' ||

        -- Footer
        '<tr><td style="padding:16px 28px;border-top:1px solid #3a3f4b;text-align:center;">' ||
        '<p style="margin:0 0 4px 0;font-size:11px;color:#555;letter-spacing:1.5px;font-family:Arial,Helvetica,sans-serif;">COACHSMART &middot; COACHING MADE SIMPLE</p>' ||
        '<p style="margin:0;font-size:11px;color:#444;font-family:Arial,Helvetica,sans-serif;">You received this because you are a member of a CoachSmart team.</p>' ||
        '</td></tr>' ||

        '</table></td></tr></table></body></html>',

        -- app_title
        CASE
            WHEN cpu.member_count = 1 THEN
                'Response needed for ' || cpu.member_name_list
            ELSE
                'Responses needed for ' || cpu.member_name_list
        END,

        -- app_body
        CASE
            WHEN cpu.member_count = 1 THEN
                'Please confirm attendance for ' || cpu.member_name_list ||
                ' for: ' || trim(cpu.display_title) || ' on ' || cpu.date_time_formatted
            ELSE
                'Please confirm attendance for ' || cpu.member_name_list ||
                ' for: ' || trim(cpu.display_title) || ' on ' || cpu.date_time_formatted
        END

    FROM consolidated_per_user cpu;

    GET DIAGNOSTICS created_count = ROW_COUNT;

    IF created_count > 0 AND auth.uid() IS NOT NULL THEN
        INSERT INTO public.reminders (event_id, user_id, result)
        VALUES (p_event_id_param, auth.uid(), created_count::text || ' reminders sent.');
    END IF;

    RETURN QUERY SELECT created_count;
END;
$$;


ALTER FUNCTION "public"."populate_event_notifications"("p_event_id_param" integer, "p_role_grade" integer, "p_role_level" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."remove_member_from_team"("p_member_id" bigint, "p_team_id" bigint) RETURNS json
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_member_team_id bigint;
    v_other_team_count int;
BEGIN
    -- Get the member_team_id for this member/team combination
    SELECT member_team_id INTO v_member_team_id
    FROM public.member_team_link
    WHERE member_id = p_member_id AND team_id = p_team_id;

    IF v_member_team_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Member is not linked to this team');
    END IF;

    -- Step 1: Delete all member_team_role_link records for this member/team
    DELETE FROM public.member_team_role_link
    WHERE member_team_id = v_member_team_id;

    -- Step 2: Delete the member_team_link record
    DELETE FROM public.member_team_link
    WHERE member_team_id = v_member_team_id;

    -- Step 3: Check if the member belongs to any other teams
    SELECT COUNT(*) INTO v_other_team_count
    FROM public.member_team_link
    WHERE member_id = p_member_id;

    -- Step 4: If no other team memberships, clean up all member references then delete member
    IF v_other_team_count = 0 THEN

        DELETE FROM public.event_attendance
        WHERE member_id = p_member_id;

        DELETE FROM public.car_pool_detail
        WHERE member_id = p_member_id;

        DELETE FROM public.member_squad_link
        WHERE member_id = p_member_id;

        DELETE FROM public.match_squad_details
        WHERE member_id = p_member_id;

        DELETE FROM public.event_user_member_payment
        WHERE member_id = p_member_id;

        DELETE FROM public.user_member_link
        WHERE member_id = p_member_id;

        DELETE FROM public.members
        WHERE member_id = p_member_id;

    END IF;

    RETURN json_build_object('success', true, 'message', 'Member removed successfully');

EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."remove_member_from_team"("p_member_id" bigint, "p_team_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_match_timer_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


ALTER FUNCTION "public"."set_match_timer_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_member_code"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$BEGIN
    -- Only set the code if it's not already provided (e.g., if it's NULL)
    IF NEW.unique_member_code IS NULL THEN
        NEW.unique_member_code := public.generate_unique_member_code(); -- Updated function call
    END IF;
    RETURN NEW;
END;$$;


ALTER FUNCTION "public"."set_member_code"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_team_code_on_insert"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$BEGIN
    -- Check if the team_unique_code for the new row is NULL.
    -- Assign the generated code to the 'team_unique_code' column.
    IF NEW.team_unique_code IS NULL THEN
        NEW.team_unique_code := public.generate_unique_team_code();
    END IF;
    RETURN NEW; -- Return the (potentially modified) new row
END;$$;


ALTER FUNCTION "public"."set_team_code_on_insert"() OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."car_pool" (
    "car_pool_id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_id" "uuid",
    "number_of_seats" smallint,
    "event_id" bigint,
    "status" "text"
);


ALTER TABLE "public"."car_pool" OWNER TO "postgres";


ALTER TABLE "public"."car_pool" ALTER COLUMN "car_pool_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."car_pool_car_pool_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."car_pool_detail" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "car_pool_id" bigint,
    "member_id" bigint,
    "status" "text"
);


ALTER TABLE "public"."car_pool_detail" OWNER TO "postgres";


ALTER TABLE "public"."car_pool_detail" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."car_pool_detail_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."club_code_link" (
    "club_code_id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "club_id" bigint,
    "code_id" bigint
);


ALTER TABLE "public"."club_code_link" OWNER TO "postgres";


ALTER TABLE "public"."club_code_link" ALTER COLUMN "club_code_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."club_code_link_club_code_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."clubs" (
    "club_id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "club_name" "text",
    "county" "text",
    "banner" "text",
    "crest" "text",
    "sport_id" bigint,
    "default_club" bigint,
    "chairperson" "text",
    "secretary" "text",
    "club_name_translated" "text",
    "primary_colour" "text",
    "secondary_colour" "text",
    "third_colour" "text"
);


ALTER TABLE "public"."clubs" OWNER TO "postgres";


ALTER TABLE "public"."clubs" ALTER COLUMN "club_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."clubs_club_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."event_attendance" ALTER COLUMN "attendance_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."event_attendance_attendance_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."event_codes" (
    "code_id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "event_code" "text"
);


ALTER TABLE "public"."event_codes" OWNER TO "postgres";


ALTER TABLE "public"."event_codes" ALTER COLUMN "code_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."event_codes_code_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."event_response_type" ALTER COLUMN "response_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."event_responses_response_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."event_types" (
    "event_type_id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "event_type" "text"
);


ALTER TABLE "public"."event_types" OWNER TO "postgres";


ALTER TABLE "public"."event_types" ALTER COLUMN "event_type_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."event_types_event_type_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."event_user_member_payment" (
    "payment_id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "event_id" bigint,
    "user_id" "uuid",
    "event_title" "text",
    "stripe_session_id" "text",
    "payment_status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "amount_paid" integer,
    "stripe_payment_intent_id" "text",
    "stripe_checkout_url" "text",
    "fee_amount" bigint,
    "net_amount" bigint,
    "tax_amount" bigint,
    "gross_amount" bigint,
    "member_id" bigint
);


ALTER TABLE "public"."event_user_member_payment" OWNER TO "postgres";


COMMENT ON COLUMN "public"."event_user_member_payment"."stripe_session_id" IS 'The ID of the corresponding Stripe Checkout Session.';



COMMENT ON COLUMN "public"."event_user_member_payment"."payment_status" IS 'The status of the payment/booking (e.g., pending, confirmed, failed, expired).';



COMMENT ON COLUMN "public"."event_user_member_payment"."amount_paid" IS 'The amount paid in the smallest currency unit (e.g., cents).';



ALTER TABLE "public"."event_user_member_payment" ALTER COLUMN "payment_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."event_user_member_payment_payment_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."event_user_payment" (
    "payment_id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "event_id" bigint,
    "user_id" "uuid",
    "event_title" "text",
    "stripe_session_id" "text",
    "payment_status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "amount_paid" bigint,
    "stripe_payment_intent_id" "text",
    "stripe_checkout_url" "text",
    "fee_amount" bigint,
    "net_amount" bigint,
    "tax_amount" bigint,
    "gross_amount" bigint
);


ALTER TABLE "public"."event_user_payment" OWNER TO "postgres";


COMMENT ON COLUMN "public"."event_user_payment"."stripe_session_id" IS 'The ID of the corresponding Stripe Checkout Session.';



COMMENT ON COLUMN "public"."event_user_payment"."payment_status" IS 'The status of the payment/booking (e.g., pending, confirmed, failed, expired).';



COMMENT ON COLUMN "public"."event_user_payment"."amount_paid" IS 'The amount paid in the smallest currency unit (e.g., cents).';



ALTER TABLE "public"."event_user_payment" ALTER COLUMN "payment_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."event_user_payment_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."events" ALTER COLUMN "event_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."events_event_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."game_ages" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "age" "text",
    "comment" "text",
    "description" "text"
);


ALTER TABLE "public"."game_ages" OWNER TO "postgres";


ALTER TABLE "public"."game_ages" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."game_ages_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."games" (
    "game_id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "game_name" "text",
    "game_image" "text",
    "game_age" "text"[],
    "game_code" "text"[],
    "game_skill" "text"[],
    "game_type" "text"[],
    "game_setup" "text",
    "game_how_to_play" "text",
    "game_variations" "text",
    "game_teaching_points" "text",
    "game_pdf" "text",
    "game_video" "text",
    "game_link" "text",
    "game_details_image" "text"
);


ALTER TABLE "public"."games" OWNER TO "postgres";


ALTER TABLE "public"."games" ALTER COLUMN "game_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."games_game_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."invitations" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_id" "uuid",
    "email_address_sent" "text"
);


ALTER TABLE "public"."invitations" OWNER TO "postgres";


COMMENT ON TABLE "public"."invitations" IS 'Record of the invitations sent';



ALTER TABLE "public"."invitations" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."invitations_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."legacy_users" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "legacy_userid" "text",
    "email_address" "text",
    "member_first_name" "text",
    "member_last_name" "text",
    "user_first_name" "text",
    "user_last_name" "text",
    "team_id" "text",
    "role" "text",
    "processed" boolean,
    "phone_number" "text"
);


ALTER TABLE "public"."legacy_users" OWNER TO "postgres";


ALTER TABLE "public"."legacy_users" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."legacy_users_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."lineup" (
    "lineup_id" bigint NOT NULL,
    "event_id" bigint NOT NULL,
    "team_id" bigint NOT NULL,
    "squad_id" bigint,
    "format" smallint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_by" "uuid"
);


ALTER TABLE "public"."lineup" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."lineup_details" (
    "lineup_detail_id" bigint NOT NULL,
    "lineup_id" bigint NOT NULL,
    "member_id" bigint NOT NULL,
    "position_num" smallint NOT NULL,
    "is_sub" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "position_label" character varying(5)
);


ALTER TABLE "public"."lineup_details" OWNER TO "postgres";


ALTER TABLE "public"."lineup_details" ALTER COLUMN "lineup_detail_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."lineup_details_lineup_detail_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."lineup" ALTER COLUMN "lineup_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."lineup_lineup_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."match_squads" (
    "match_squad_id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_id" "uuid",
    "event_id" bigint
);


ALTER TABLE "public"."match_squads" OWNER TO "postgres";


ALTER TABLE "public"."match_squads" ALTER COLUMN "match_squad_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."match _squads_match_squad_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."match_reports" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "event_id" bigint,
    "user_id" "uuid",
    "match_report" "text"
);


ALTER TABLE "public"."match_reports" OWNER TO "postgres";


ALTER TABLE "public"."match_reports" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."match_reports_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."match_stat_categories" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "score_category" "text"
);


ALTER TABLE "public"."match_stat_categories" OWNER TO "postgres";


ALTER TABLE "public"."match_stat_categories" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."match_score_catregories_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."match_stat_type_team_link" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "match_score_type_id" bigint,
    "team_id" bigint,
    "status" boolean
);


ALTER TABLE "public"."match_stat_type_team_link" OWNER TO "postgres";


ALTER TABLE "public"."match_stat_type_team_link" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."match_score_type_team_link_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."match_stat_types" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "score_type" "text",
    "score_category" bigint,
    "status" boolean,
    "score_value" smallint,
    "abbreviated_name" "text"
);


ALTER TABLE "public"."match_stat_types" OWNER TO "postgres";


ALTER TABLE "public"."match_stat_types" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."match_score_types_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."match_stats_details" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "match_stats_id" bigint,
    "count" smallint,
    "score_type" bigint,
    "side" "text" DEFAULT 'us'::"text" NOT NULL,
    "event_minute" smallint,
    "timer_status" "text",
    CONSTRAINT "match_scores_details_side_check" CHECK (("side" = ANY (ARRAY['us'::"text", 'opp'::"text"]))),
    CONSTRAINT "match_stats_details_timer_status_check" CHECK (("timer_status" = ANY (ARRAY['running'::"text", 'paused'::"text", 'stopped'::"text"])))
);


ALTER TABLE "public"."match_stats_details" OWNER TO "postgres";


ALTER TABLE "public"."match_stats_details" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."match_scores_details_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."match_stats" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "event_id" bigint,
    "opposition" "text",
    "user_id" "uuid",
    "squad_id" bigint,
    "timer_start" smallint,
    "timer_end" smallint,
    "timer_running" boolean,
    "finalised_at" timestamp with time zone
);


ALTER TABLE "public"."match_stats" OWNER TO "postgres";


ALTER TABLE "public"."match_stats" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."match_scores_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."match_squad_details" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_id" "uuid",
    "team_id" bigint,
    "squad_id" bigint,
    "member_id" bigint,
    "event_id" bigint,
    "role_id" bigint,
    "match_squad_id" bigint
);


ALTER TABLE "public"."match_squad_details" OWNER TO "postgres";


ALTER TABLE "public"."match_squad_details" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."match_squad_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."match_timer" (
    "id" bigint NOT NULL,
    "event_id" bigint NOT NULL,
    "user_id" "uuid" NOT NULL,
    "started_at" timestamp with time zone,
    "elapsed_seconds" integer DEFAULT 0 NOT NULL,
    "status" "text" DEFAULT 'paused'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "duration_seconds" integer DEFAULT 1800 NOT NULL,
    "opposition" "text",
    "squad_id" bigint,
    "home_goals" integer DEFAULT 0 NOT NULL,
    "home_points" integer DEFAULT 0 NOT NULL,
    "home_two_ptrs" integer DEFAULT 0 NOT NULL,
    "away_goals" integer DEFAULT 0 NOT NULL,
    "away_points" integer DEFAULT 0 NOT NULL,
    "away_two_ptrs" integer DEFAULT 0 NOT NULL,
    "injury_seconds" integer DEFAULT 600 NOT NULL,
    CONSTRAINT "match_timer_status_check" CHECK (("status" = ANY (ARRAY['running'::"text", 'paused'::"text"])))
);


ALTER TABLE "public"."match_timer" OWNER TO "postgres";


ALTER TABLE "public"."match_timer" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."match_timer_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."member_squad_link" (
    "member_squad_id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "member_id" bigint,
    "squad_id" bigint,
    "code_id" bigint,
    "team_id" bigint
);


ALTER TABLE "public"."member_squad_link" OWNER TO "postgres";


ALTER TABLE "public"."member_squad_link" ALTER COLUMN "member_squad_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."member_squad_link_member_squad_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."member_team_link" ALTER COLUMN "member_team_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."member_team_link_member_team_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."member_team_role_link" ALTER COLUMN "member_team_role_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."member_team_role_link_member_team_role_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" bigint NOT NULL,
    "created_at" timestamp without time zone DEFAULT ("now"() AT TIME ZONE 'utc'::"text") NOT NULL,
    "recipient_user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "is_read" boolean DEFAULT false NOT NULL,
    "when_read" timestamp without time zone,
    "link_page" "text",
    "image" "text",
    "is_delivered" boolean DEFAULT false,
    "delivery_method" "text",
    "push_title" "text",
    "push_body" "text",
    "email_title" "text",
    "email_body" "text",
    "app_title" "text",
    "app_body" "text",
    "team_id" bigint,
    "event_id" bigint
);


ALTER TABLE "public"."notifications" OWNER TO "postgres";


ALTER TABLE "public"."notifications" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."notifications_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."reminders" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "event_id" bigint,
    "user_id" "uuid",
    "result" "text"
);


ALTER TABLE "public"."reminders" OWNER TO "postgres";


ALTER TABLE "public"."reminders" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."reminders_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."roles" ALTER COLUMN "role_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."roles_role_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."sport" (
    "sport_id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "sport_name" "text",
    "sport_crest" "text"
);


ALTER TABLE "public"."sport" OWNER TO "postgres";


ALTER TABLE "public"."sport" ALTER COLUMN "sport_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."sport_sport_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."squads" ALTER COLUMN "squad_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."squad_squad_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."members" ALTER COLUMN "member_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."team_member_member_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."team_roles_link" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "team_id" bigint,
    "role_id" bigint
);


ALTER TABLE "public"."team_roles_link" OWNER TO "postgres";


ALTER TABLE "public"."team_roles_link" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."team_role_link_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."teams" ALTER COLUMN "team_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."teams_team_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."user_game_link" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_id" "uuid",
    "game_id" bigint,
    "position" integer DEFAULT 0 NOT NULL
);


ALTER TABLE "public"."user_game_link" OWNER TO "postgres";


ALTER TABLE "public"."user_game_link" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."user_game_link_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."user_member_link" ALTER COLUMN "user_member_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."user_member_link_user_member_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE OR REPLACE VIEW "public"."view_attendee_details" AS
 WITH "event_team_members_with_squads" AS (
         SELECT DISTINCT "e"."team_id",
            "e"."event_id",
            "e"."event_title",
            "e"."event_date_time",
            "m"."member_id",
            "m"."first_name",
            "m"."last_name",
            (("m"."first_name" || ' '::"text") || "m"."last_name") AS "full_member_name",
            "mtl"."squad_id",
            "s"."squad_name",
            "s"."squad_image",
            "s"."grade" AS "squad_grade"
           FROM ((("public"."members" "m"
             JOIN "public"."member_team_link" "mtl" ON (("m"."member_id" = "mtl"."member_id")))
             JOIN "public"."events" "e" ON (("mtl"."team_id" = "e"."team_id")))
             LEFT JOIN "public"."squads" "s" ON (("mtl"."squad_id" = "s"."squad_id")))
        ), "member_event_roles" AS (
         SELECT "etms_1"."event_id",
            "etms_1"."member_id",
            "mtrl"."role_id",
            "r"."role_name",
            "r"."role_level",
            "r"."role_name_plural",
            "r"."role_grade",
            "r"."role_list_seq"
           FROM ((("event_team_members_with_squads" "etms_1"
             JOIN "public"."member_team_link" "mtl" ON ((("etms_1"."member_id" = "mtl"."member_id") AND ("etms_1"."team_id" = "mtl"."team_id"))))
             JOIN "public"."member_team_role_link" "mtrl" ON (("mtl"."member_team_id" = "mtrl"."member_team_id")))
             JOIN "public"."roles" "r" ON (("mtrl"."role_id" = "r"."role_id")))
        ), "latest_member_event_attendance" AS (
         SELECT "ea"."event_id",
            "ea"."member_id",
            "ea"."response_id",
            "ert"."response_value",
            "ert"."response_icon",
            "ert"."display_value",
            "ea"."created_at" AS "attendance_created_at",
            "row_number"() OVER (PARTITION BY "ea"."event_id", "ea"."member_id" ORDER BY "ea"."created_at" DESC) AS "rn"
           FROM ("public"."event_attendance" "ea"
             LEFT JOIN "public"."event_response_type" "ert" ON (("ea"."response_id" = "ert"."response_id")))
        ), "member_primary_user" AS (
         SELECT "uml"."member_id",
            "u"."user_id",
            "u"."email_address",
            "row_number"() OVER (PARTITION BY "uml"."member_id" ORDER BY "uml"."created_at") AS "rn_user"
           FROM ("public"."user_member_link" "uml"
             JOIN "public"."users" "u" ON (("uml"."user_id" = "u"."user_id")))
        )
 SELECT "etms"."team_id",
    "etms"."event_id",
    "etms"."event_title",
    "etms"."event_date_time",
    "etms"."member_id",
    "etms"."first_name",
    "etms"."last_name",
    "etms"."full_member_name",
    "mpu"."user_id",
    "mpu"."email_address",
    "mer"."role_id",
    "mer"."role_name",
    "mer"."role_level",
    "mer"."role_name_plural",
    "mer"."role_grade",
    "mer"."role_list_seq",
    "etms"."squad_id",
    "etms"."squad_name",
    "etms"."squad_image",
    "etms"."squad_grade",
    "lmea"."response_id",
    "lmea"."attendance_created_at",
    "lmea"."response_icon",
    "lmea"."display_value",
        CASE
            WHEN ("lmea"."response_id" IS NULL) THEN 'No Response'::"text"
            ELSE "lmea"."display_value"
        END AS "response_status"
   FROM ((("event_team_members_with_squads" "etms"
     JOIN "member_event_roles" "mer" ON ((("etms"."event_id" = "mer"."event_id") AND ("etms"."member_id" = "mer"."member_id"))))
     LEFT JOIN "latest_member_event_attendance" "lmea" ON ((("etms"."event_id" = "lmea"."event_id") AND ("etms"."member_id" = "lmea"."member_id") AND ("lmea"."rn" = 1))))
     LEFT JOIN "member_primary_user" "mpu" ON ((("etms"."member_id" = "mpu"."member_id") AND ("mpu"."rn_user" = 1))))
  ORDER BY "etms"."event_date_time" DESC, "etms"."event_id", "etms"."squad_name", "mer"."role_list_seq", "mer"."role_grade" DESC, "mer"."role_level" DESC, "etms"."full_member_name";


ALTER VIEW "public"."view_attendee_details" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_event_attendance_summary" AS
 WITH "all_event_team_roles" AS (
         SELECT "e"."event_id",
            "e"."event_title",
            "e"."event_date_time",
            "e"."meet_time",
            "e"."opposition",
            "e"."location_name",
            "t"."team_id",
            "t"."team_name",
            "r"."role_id",
            "r"."role_name",
            "r"."role_level",
            "r"."role_grade",
            "r"."role_name_plural",
            "r"."role_list_seq"
           FROM ((("public"."events" "e"
             JOIN "public"."teams" "t" ON (("e"."team_id" = "t"."team_id")))
             JOIN "public"."team_roles_link" "trl" ON (("t"."team_id" = "trl"."team_id")))
             JOIN "public"."roles" "r" ON (("trl"."role_id" = "r"."role_id")))
        ), "actual_member_roles_for_event" AS (
         SELECT "e"."event_id",
            "mtl"."member_id",
            "mtrl"."role_id"
           FROM (((("public"."events" "e"
             JOIN "public"."member_team_link" "mtl" ON (("e"."team_id" = "mtl"."team_id")))
             JOIN "public"."members" "m" ON (("mtl"."member_id" = "m"."member_id")))
             JOIN "public"."member_team_role_link" "mtrl" ON (("mtl"."member_team_id" = "mtrl"."member_team_id")))
             JOIN "public"."team_roles_link" "trl" ON ((("mtl"."team_id" = "trl"."team_id") AND ("mtrl"."role_id" = "trl"."role_id"))))
          GROUP BY "e"."event_id", "mtl"."member_id", "mtrl"."role_id"
        ), "latest_event_attendance" AS (
         SELECT "ranked_attendance"."event_id",
            "ranked_attendance"."member_id",
            "ranked_attendance"."response_id"
           FROM ( SELECT "ea_sub"."event_id",
                    "ea_sub"."member_id",
                    "ea_sub"."response_id",
                    "row_number"() OVER (PARTITION BY "ea_sub"."event_id", "ea_sub"."member_id" ORDER BY "ea_sub"."created_at" DESC) AS "rn"
                   FROM "public"."event_attendance" "ea_sub") "ranked_attendance"
          WHERE ("ranked_attendance"."rn" = 1)
        )
 SELECT "aetr"."event_id",
    "aetr"."event_title",
    "aetr"."event_date_time",
    "aetr"."meet_time",
    "aetr"."opposition",
    "aetr"."location_name",
    "aetr"."team_id",
    "aetr"."team_name",
    "aetr"."role_id",
    "aetr"."role_name",
    "aetr"."role_level",
    "aetr"."role_grade",
    "aetr"."role_name_plural",
    "aetr"."role_list_seq",
    COALESCE("sum"(
        CASE
            WHEN ("lea"."response_id" = 3) THEN 1
            ELSE 0
        END), (0)::bigint) AS "accepted_attendees_count",
    COALESCE("sum"(
        CASE
            WHEN ("lea"."response_id" = 4) THEN 1
            ELSE 0
        END), (0)::bigint) AS "declined_attendees_count",
    COALESCE("sum"(
        CASE
            WHEN (("lea"."response_id" IS NULL) AND ("amr"."member_id" IS NOT NULL)) THEN 1
            ELSE 0
        END), (0)::bigint) AS "no_response_count"
   FROM (("all_event_team_roles" "aetr"
     LEFT JOIN "actual_member_roles_for_event" "amr" ON ((("aetr"."event_id" = "amr"."event_id") AND ("aetr"."role_id" = "amr"."role_id"))))
     LEFT JOIN "latest_event_attendance" "lea" ON ((("amr"."event_id" = "lea"."event_id") AND ("amr"."member_id" = "lea"."member_id"))))
  GROUP BY "aetr"."event_id", "aetr"."event_title", "aetr"."event_date_time", "aetr"."meet_time", "aetr"."opposition", "aetr"."location_name", "aetr"."team_id", "aetr"."team_name", "aetr"."role_id", "aetr"."role_name", "aetr"."role_level", "aetr"."role_grade", "aetr"."role_name_plural", "aetr"."role_list_seq"
  ORDER BY "aetr"."event_date_time" DESC, "aetr"."role_list_seq", "aetr"."role_grade" DESC, "aetr"."role_level" DESC;


ALTER VIEW "public"."view_event_attendance_summary" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_event_reminders" AS
 SELECT "r"."id",
    "r"."created_at",
    "r"."event_id",
    "r"."user_id",
    "r"."result",
    (("u"."first_name" || ' '::"text") || "u"."last_name") AS "users_full_name",
    "u"."email_address"
   FROM ("public"."reminders" "r"
     JOIN "public"."users" "u" ON (("r"."user_id" = "u"."user_id")));


ALTER VIEW "public"."view_event_reminders" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_event_squad_summary" AS
 WITH "latest_event_member_attendance" AS (
         SELECT "ea"."event_id",
            "ea"."member_id",
            "ea"."response_id",
            "row_number"() OVER (PARTITION BY "ea"."event_id", "ea"."member_id" ORDER BY "ea"."created_at" DESC) AS "rn"
           FROM "public"."event_attendance" "ea"
        ), "event_member_team_squad_roles" AS (
         SELECT "e_1"."event_id",
            "e_1"."team_id",
            "mtl"."member_id",
            "mtl"."squad_id",
            "mtrl"."role_id"
           FROM (("public"."events" "e_1"
             JOIN "public"."member_team_link" "mtl" ON (("e_1"."team_id" = "mtl"."team_id")))
             LEFT JOIN "public"."member_team_role_link" "mtrl" ON (("mtl"."member_team_id" = "mtrl"."member_team_id")))
        ), "event_member_summary_base" AS (
         SELECT "emtsr"."event_id",
            "emtsr"."team_id",
            "emtsr"."member_id",
            "emtsr"."squad_id",
            "emtsr"."role_id",
            "lem_att"."response_id"
           FROM ("event_member_team_squad_roles" "emtsr"
             LEFT JOIN "latest_event_member_attendance" "lem_att" ON ((("emtsr"."event_id" = "lem_att"."event_id") AND ("emtsr"."member_id" = "lem_att"."member_id"))))
          WHERE (("lem_att"."rn" = 1) OR ("lem_att"."rn" IS NULL))
        )
 SELECT "emsb"."event_id",
    "e"."event_title",
    "e"."event_date_time",
    "e"."meet_time",
    "e"."opposition",
    "e"."location_name",
    "emsb"."team_id",
    "t"."team_name",
    "t"."team_unique_code",
    COALESCE("s"."squad_name", 'No Squad'::"text") AS "squad_name",
    COALESCE("s"."grade", 'N/A'::"text") AS "squad_grade",
    COALESCE("s"."squad_colour", '#E9EEF6'::"text") AS "squad_colour",
    COALESCE("s"."squad_image", 'https://gyfporsbdftvtakdvukt.supabase.co/storage/v1/object/sign/coachsmartimages/Grey%20Team.png?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV82OTA4NmRkYy01MWQ3LTQ1NzUtYWYwMC1mZjQxYmNiNDU2YWMiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJjb2FjaHNtYXJ0aW1hZ2VzL0dyZXkgVGVhbS5wbmciLCJpYXQiOjE3NTE4MDQ4MDMsImV4cCI6MjYxNTgwNDgwM30.FwtTTM6vzogcgdgze6d3ETxEl_PiJkLGZsaYK9mn6MI'::"text") AS "squad_image",
    COALESCE("emsb"."squad_id", (0)::bigint) AS "squad_id",
    COALESCE("emsb"."role_id", (0)::bigint) AS "role_id",
    COALESCE("r"."role_name", 'No Role'::"text") AS "role_name",
    COALESCE(("r"."role_level")::integer, 0) AS "role_level",
    COALESCE(("r"."role_grade")::integer, 0) AS "role_grade",
    COALESCE("r"."role_name_plural", 'No Roles'::"text") AS "role_name_plural",
    COALESCE(("r"."role_list_seq")::integer, 9999) AS "role_list_seq",
    "count"(DISTINCT "emsb"."member_id") AS "assigned_member_count",
    "count"(DISTINCT
        CASE
            WHEN ("emsb"."response_id" = 3) THEN "emsb"."member_id"
            ELSE NULL::bigint
        END) AS "accepted_attendees_count",
    "count"(DISTINCT
        CASE
            WHEN ("emsb"."response_id" = 4) THEN "emsb"."member_id"
            ELSE NULL::bigint
        END) AS "declined_attendees_count",
    "count"(DISTINCT
        CASE
            WHEN ("emsb"."response_id" IS NULL) THEN "emsb"."member_id"
            ELSE NULL::bigint
        END) AS "no_response_count"
   FROM (((("event_member_summary_base" "emsb"
     JOIN "public"."events" "e" ON (("emsb"."event_id" = "e"."event_id")))
     JOIN "public"."teams" "t" ON (("emsb"."team_id" = "t"."team_id")))
     LEFT JOIN "public"."roles" "r" ON (("emsb"."role_id" = "r"."role_id")))
     LEFT JOIN "public"."squads" "s" ON (("emsb"."squad_id" = "s"."squad_id")))
  GROUP BY "emsb"."event_id", "e"."event_title", "e"."event_date_time", "e"."meet_time", "e"."opposition", "e"."location_name", "emsb"."team_id", "t"."team_name", "t"."team_unique_code", COALESCE("s"."squad_name", 'No Squad'::"text"), COALESCE("s"."grade", 'N/A'::"text"), COALESCE("s"."squad_colour", '#E9EEF6'::"text"), COALESCE("s"."squad_image", 'https://gyfporsbdftvtakdvukt.supabase.co/storage/v1/object/sign/coachsmartimages/Grey%20Team.png?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV82OTA4NmRkYy01MWQ3LTQ1NzUtYWYwMC1mZjQxYmNiNDU2YWMiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJjb2FjaHNtYXJ0aW1hZ2VzL0dyZXkgVGVhbS5wbmciLCJpYXQiOjE3NTE4MDQ4MDMsImV4cCI6MjYxNTgwNDgwM30.FwtTTM6vzogcgdgze6d3ETxEl_PiJkLGZsaYK9mn6MI'::"text"), COALESCE("emsb"."squad_id", (0)::bigint), COALESCE("emsb"."role_id", (0)::bigint), COALESCE("r"."role_name", 'No Role'::"text"), COALESCE(("r"."role_level")::integer, 0), COALESCE(("r"."role_grade")::integer, 0), COALESCE("r"."role_name_plural", 'No Roles'::"text"), COALESCE(("r"."role_list_seq")::integer, 9999)
  ORDER BY "e"."event_date_time" DESC, COALESCE("s"."squad_name", 'No Squad'::"text"), COALESCE(("r"."role_list_seq")::integer, 9999), COALESCE(("r"."role_grade")::integer, 0) DESC, COALESCE(("r"."role_level")::integer, 0) DESC;


ALTER VIEW "public"."view_event_squad_summary" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_homepage_listview" AS
 WITH "user_highest_role_per_team" AS (
         SELECT "u"."user_id",
            "t"."team_id",
            "max"("r"."role_level") AS "user_max_team_role_level"
           FROM (((((("public"."users" "u"
             JOIN "public"."user_member_link" "uml" ON (("u"."user_id" = "uml"."user_id")))
             JOIN "public"."members" "m" ON (("uml"."member_id" = "m"."member_id")))
             JOIN "public"."member_team_link" "mtl" ON (("m"."member_id" = "mtl"."member_id")))
             JOIN "public"."teams" "t" ON (("mtl"."team_id" = "t"."team_id")))
             JOIN "public"."member_team_role_link" "mtrl" ON (("mtl"."member_team_id" = "mtrl"."member_team_id")))
             JOIN "public"."roles" "r" ON (("mtrl"."role_id" = "r"."role_id")))
          GROUP BY "u"."user_id", "t"."team_id"
        ), "eventteammembers" AS (
         SELECT "e"."event_id",
            "array_agg"(DISTINCT "combined_members"."member_id" ORDER BY "combined_members"."member_id") AS "team_members"
           FROM (("public"."events" "e"
             JOIN "public"."teams" "t" ON (("e"."team_id" = "t"."team_id")))
             JOIN ( SELECT "mtl_sub"."team_id",
                    "mtl_sub"."member_id"
                   FROM "public"."member_team_link" "mtl_sub"
                UNION ALL
                 SELECT "t_sub"."team_id",
                    (0)::bigint AS "member_id"
                   FROM "public"."teams" "t_sub") "combined_members" ON (("t"."team_id" = "combined_members"."team_id")))
          GROUP BY "e"."event_id"
        ), "usermembereventrolecontext" AS (
         SELECT "u"."user_id",
            "u"."first_name" AS "user_first_name",
            "u"."last_name" AS "user_last_name",
            "u"."phone_number",
            "u"."email_address",
            "m"."member_id",
            "m"."first_name" AS "member_first_name",
            "m"."last_name" AS "member_last_name",
            "m"."created_at" AS "member_created_at",
            "t"."team_id",
            "t"."team_name",
            "t"."club_id",
            "t"."team_female",
            "c"."club_name",
            "r"."role_id",
            "r"."role_name",
            "r"."role_level",
            "r"."role_grade",
            "r"."role_name_plural",
            "e"."event_id",
            "e"."event_title",
            ("e"."event_date_time")::timestamp without time zone AS "event_date_time",
            (("date_trunc"('day'::"text", "e"."event_date_time") + '23:59:00'::interval))::timestamp without time zone AS "event_date_compare",
            "e"."meet_time",
            "e"."event_link",
            "e"."opposition",
            "e"."location_name",
            "e"."event_details",
            "e"."audience_id",
            "e"."request_attendance",
            "audience_role"."role_grade" AS "event_role_grade",
            "audience_role"."role_level" AS "event_role_level",
            "uhrt"."user_max_team_role_level",
                CASE
                    WHEN (("t"."team_female" = true) AND ("e"."event_code_id" = 3)) THEN 'Camogie'::"text"
                    ELSE "ec"."event_code"
                END AS "event_code",
            "et"."event_type",
            "et"."event_type_id",
            "creator"."user_id" AS "created_by_user_id",
            "creator"."first_name" AS "created_by_first_name",
            "creator"."last_name" AS "created_by_last_name",
            "creator"."phone_number" AS "created_by_phone_number",
            "creator"."email_address" AS "created_by_email_address",
            "etm"."team_members",
            "row_number"() OVER (PARTITION BY "u"."user_id", "e"."event_id" ORDER BY "r"."role_grade" DESC, "r"."role_level" DESC, "m"."created_at" DESC, "m"."member_id") AS "rn"
           FROM (((((((((((((("public"."users" "u"
             JOIN "public"."user_member_link" "uml" ON (("u"."user_id" = "uml"."user_id")))
             JOIN "public"."members" "m" ON (("uml"."member_id" = "m"."member_id")))
             JOIN "public"."member_team_link" "mtl" ON (("m"."member_id" = "mtl"."member_id")))
             JOIN "public"."member_team_role_link" "mtrl" ON (("mtl"."member_team_id" = "mtrl"."member_team_id")))
             JOIN "public"."roles" "r" ON (("mtrl"."role_id" = "r"."role_id")))
             JOIN "public"."teams" "t" ON (("mtl"."team_id" = "t"."team_id")))
             JOIN "public"."clubs" "c" ON (("t"."club_id" = "c"."club_id")))
             JOIN "public"."events" "e" ON (("e"."team_id" = "t"."team_id")))
             LEFT JOIN "public"."roles" "audience_role" ON (("e"."audience_id" = "audience_role"."role_id")))
             JOIN "public"."event_codes" "ec" ON (("e"."event_code_id" = "ec"."code_id")))
             JOIN "public"."event_types" "et" ON (("e"."event_type_id" = "et"."event_type_id")))
             JOIN "public"."users" "creator" ON (("e"."created_by" = "creator"."user_id")))
             LEFT JOIN "eventteammembers" "etm" ON (("e"."event_id" = "etm"."event_id")))
             LEFT JOIN "user_highest_role_per_team" "uhrt" ON ((("u"."user_id" = "uhrt"."user_id") AND ("e"."team_id" = "uhrt"."team_id"))))
        )
 SELECT "user_id",
    "user_first_name",
    "user_last_name",
    "phone_number",
    "email_address",
    "member_id",
    "member_first_name",
    "member_last_name",
    "team_id",
    "team_name",
    "club_id",
    "club_name",
    "role_id",
    "role_name",
    "role_level",
    "role_grade",
    "role_name_plural",
    "event_id",
        CASE
            WHEN ("event_type_id" = 2) THEN (((
            CASE
                WHEN (("team_female" = true) AND ("event_title" ~~* '%Hurling%'::"text")) THEN "replace"("event_title", 'Hurling'::"text", 'Camogie'::"text")
                ELSE "event_title"
            END || ' ('::"text") || "opposition") || ')'::"text")
            ELSE
            CASE
                WHEN (("team_female" = true) AND ("event_title" ~~* '%Hurling%'::"text")) THEN "replace"("event_title", 'Hurling'::"text", 'Camogie'::"text")
                ELSE "event_title"
            END
        END AS "event_title",
    "event_date_time",
    "event_date_compare",
    "meet_time",
    "opposition",
    "location_name",
    "event_link",
    "event_details",
    "audience_id",
    "request_attendance",
    "event_role_grade",
    "event_role_level",
    "event_code",
    "event_type",
    "created_by_user_id",
    "created_by_first_name",
    "created_by_last_name",
    "created_by_phone_number",
    "created_by_email_address",
    "team_members"
   FROM "usermembereventrolecontext"
  WHERE (("rn" = 1) AND (("event_role_level" IS NULL) OR ("user_max_team_role_level" IS NULL) OR ("event_role_level" <= "user_max_team_role_level")))
  ORDER BY "event_date_time" DESC, "user_last_name", "user_first_name";


ALTER VIEW "public"."view_homepage_listview" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_latest_member_event_attendance" AS
 WITH "latest_event_attendance" AS (
         SELECT "ea"."member_id",
            "ea"."event_id",
            "ea"."created_at" AS "response_created_at",
            "ea"."attendance_id",
            "ea"."response_id",
            "row_number"() OVER (PARTITION BY "ea"."event_id", "ea"."member_id" ORDER BY "ea"."created_at" DESC) AS "rn"
           FROM "public"."event_attendance" "ea"
        ), "member_team_highest_role" AS (
         SELECT "mtl"."member_id",
            "mtl"."team_id",
            "r"."role_id",
            "r"."role_name",
            "r"."role_level",
            "r"."role_name_plural",
            "r"."role_grade",
            "row_number"() OVER (PARTITION BY "mtl"."member_id", "mtl"."team_id" ORDER BY "r"."role_grade" DESC, "r"."role_level" DESC, "r"."role_id") AS "rn_role"
           FROM (("public"."member_team_link" "mtl"
             JOIN "public"."member_team_role_link" "mtrl" ON (("mtl"."member_team_id" = "mtrl"."member_team_id")))
             JOIN "public"."roles" "r" ON (("mtrl"."role_id" = "r"."role_id")))
        )
 SELECT "u"."user_id",
    "m"."member_id",
    "m"."first_name",
    "m"."last_name",
    "mthr"."role_id" AS "highest_role_id",
    "mthr"."role_name" AS "highest_role_name",
    "mthr"."role_level" AS "highest_role_level",
    "mthr"."role_name_plural" AS "highest_role_name_plural",
    "mthr"."role_grade" AS "highest_role_grade",
    "e"."event_id",
    "e"."event_title",
    "lea"."response_created_at",
    "lea"."attendance_id",
    "ert"."response_id",
    "ert"."response_value",
    "t"."team_id",
    "t"."team_name"
   FROM ((((((("latest_event_attendance" "lea"
     JOIN "public"."members" "m" ON (("lea"."member_id" = "m"."member_id")))
     JOIN "public"."events" "e" ON (("lea"."event_id" = "e"."event_id")))
     JOIN "public"."teams" "t" ON (("e"."team_id" = "t"."team_id")))
     JOIN "member_team_highest_role" "mthr" ON ((("m"."member_id" = "mthr"."member_id") AND ("t"."team_id" = "mthr"."team_id") AND ("mthr"."rn_role" = 1))))
     JOIN "public"."event_response_type" "ert" ON (("ert"."response_id" = "lea"."response_id")))
     JOIN "public"."user_member_link" "uml" ON (("m"."member_id" = "uml"."member_id")))
     JOIN "public"."users" "u" ON (("uml"."user_id" = "u"."user_id")))
  WHERE ("lea"."rn" = 1)
  ORDER BY "e"."event_date_time" DESC, "t"."team_name", "m"."last_name", "m"."first_name";


ALTER VIEW "public"."view_latest_member_event_attendance" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_match_reports" AS
 SELECT "u"."user_id",
    "concat"("u"."first_name", ' ', "u"."last_name") AS "report_author",
    "mr"."created_at",
    "e"."event_id",
    "e"."event_title",
    "e"."event_date_time",
    "mr"."match_report",
    "mr"."id"
   FROM (("public"."match_reports" "mr"
     JOIN "public"."users" "u" ON (("mr"."user_id" = "u"."user_id")))
     JOIN "public"."events" "e" ON (("mr"."event_id" = "e"."event_id")));


ALTER VIEW "public"."view_match_reports" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_match_squads" AS
 SELECT "ms"."match_squad_id",
    "msd"."event_id",
    "msd"."created_at",
    "e"."event_title",
    "e"."event_date_time",
    "to_char"("e"."event_date_time", 'Month DD, YYYY HH:MI AM'::"text") AS "formatted_event_date_time",
    (("m"."first_name" || ' '::"text") || "m"."last_name") AS "full_member_name",
    "t"."team_name",
    "s"."squad_name",
    "s"."grade",
    "s"."squad_id",
    "s"."squad_list_seq",
    "r"."role_name",
    "r"."role_name_plural",
    "r"."role_list_seq",
    "r"."role_level",
    "r"."role_id"
   FROM (((((("public"."match_squad_details" "msd"
     JOIN "public"."match_squads" "ms" ON (("msd"."match_squad_id" = "ms"."match_squad_id")))
     JOIN "public"."members" "m" ON (("msd"."member_id" = "m"."member_id")))
     JOIN "public"."roles" "r" ON (("msd"."role_id" = "r"."role_id")))
     JOIN "public"."events" "e" ON (("ms"."event_id" = "e"."event_id")))
     LEFT JOIN "public"."squads" "s" ON (("msd"."squad_id" = "s"."squad_id")))
     LEFT JOIN "public"."teams" "t" ON (("s"."team_id" = "t"."team_id")));


ALTER VIEW "public"."view_match_squads" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_member_event_count" AS
 WITH "membereventresponses" AS (
         SELECT "m"."member_id",
            "m"."first_name",
            "m"."last_name",
            "count"(DISTINCT
                CASE
                    WHEN ("latest_att"."response_id" = 3) THEN "latest_att"."event_id"
                    ELSE NULL::bigint
                END) AS "accepted_count",
            "count"(DISTINCT
                CASE
                    WHEN ("latest_att"."response_id" = 4) THEN "latest_att"."event_id"
                    ELSE NULL::bigint
                END) AS "declined_count",
            "count"(DISTINCT "latest_att"."event_id") AS "total_events_responded"
           FROM ("public"."members" "m"
             LEFT JOIN LATERAL ( SELECT DISTINCT ON ("ea"."event_id") "ea"."event_id",
                    "ea"."response_id"
                   FROM "public"."event_attendance" "ea"
                  WHERE ("ea"."member_id" = "m"."member_id")
                  ORDER BY "ea"."event_id", "ea"."created_at" DESC) "latest_att" ON (true))
          GROUP BY "m"."member_id", "m"."first_name", "m"."last_name"
        )
 SELECT "member_id",
    "first_name",
    "last_name",
    "accepted_count",
    "declined_count",
    "total_events_responded",
        CASE
            WHEN ("total_events_responded" > 0) THEN "round"(((("accepted_count")::numeric * 100.0) / ("total_events_responded")::numeric), 2)
            ELSE (0)::numeric
        END AS "acceptance_rate",
        CASE
            WHEN ("total_events_responded" > 0) THEN "round"(((("declined_count")::numeric * 100.0) / ("total_events_responded")::numeric), 2)
            ELSE (0)::numeric
        END AS "decline_rate",
    "accepted_count" AS "event_count"
   FROM "membereventresponses"
  ORDER BY "member_id";


ALTER VIEW "public"."view_member_event_count" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_member_response_list" AS
 WITH "unique_member_teams" AS (
         SELECT DISTINCT ON ("member_team_link"."member_id", "member_team_link"."team_id") "member_team_link"."member_team_id",
            "member_team_link"."member_id",
            "member_team_link"."team_id"
           FROM "public"."member_team_link"
          ORDER BY "member_team_link"."member_id", "member_team_link"."team_id", "member_team_link"."member_team_id"
        ), "ranked_roles" AS (
         SELECT "mtrl"."member_team_id",
            "mtrl"."role_id",
            "r"."role_name",
            "r"."role_level",
            "r"."role_grade",
            "row_number"() OVER (PARTITION BY "umt_1"."member_id", "umt_1"."team_id" ORDER BY "r"."role_grade" DESC, "r"."role_level" DESC, "mtrl"."role_id") AS "role_rank"
           FROM (("unique_member_teams" "umt_1"
             JOIN "public"."member_team_role_link" "mtrl" ON (("umt_1"."member_team_id" = "mtrl"."member_team_id")))
             JOIN "public"."roles" "r" ON (("mtrl"."role_id" = "r"."role_id")))
        )
 SELECT "row_number"() OVER (ORDER BY "u"."user_id", "m"."member_id", "t"."team_id") AS "idx",
    "u"."user_id",
    "u"."email_address",
    "u"."phone_number",
    "u"."first_name" AS "user_first_name",
    "u"."last_name" AS "user_last_name",
    "concat"(COALESCE("u"."first_name", ''::"text"), ' ', COALESCE("u"."last_name", ''::"text")) AS "user_full_name",
    "m"."member_id",
    "m"."first_name" AS "member_first_name",
    "m"."last_name" AS "member_last_name",
    "concat"(COALESCE("m"."first_name", ''::"text"), ' ', COALESCE("m"."last_name", ''::"text")) AS "member_full_name",
    "m"."profile_pic" AS "member_profile_pic",
    "t"."team_id",
    "t"."team_name",
    "rr"."role_id",
    "rr"."role_name",
    "rr"."role_level",
    "rr"."role_grade"
   FROM ((((("public"."users" "u"
     JOIN "public"."user_member_link" "uml" ON (("u"."user_id" = "uml"."user_id")))
     JOIN "public"."members" "m" ON (("uml"."member_id" = "m"."member_id")))
     JOIN "unique_member_teams" "umt" ON (("m"."member_id" = "umt"."member_id")))
     JOIN "public"."teams" "t" ON (("umt"."team_id" = "t"."team_id")))
     LEFT JOIN "ranked_roles" "rr" ON ((("umt"."member_team_id" = "rr"."member_team_id") AND ("rr"."role_rank" = 1))))
  ORDER BY "u"."user_id", "m"."member_id", "t"."team_id";


ALTER VIEW "public"."view_member_response_list" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_members_no_response" AS
 SELECT "m"."member_id",
    "m"."first_name",
    "m"."last_name",
    "t"."team_id",
    "t"."team_name",
    "s"."squad_id",
    "s"."squad_name",
    "e"."event_id",
    "e"."event_title",
    "e"."event_date_time"
   FROM ((((("public"."members" "m"
     JOIN "public"."member_team_link" "mtl" ON (("m"."member_id" = "mtl"."member_id")))
     JOIN "public"."teams" "t" ON (("mtl"."team_id" = "t"."team_id")))
     JOIN "public"."squads" "s" ON (("mtl"."squad_id" = "s"."squad_id")))
     JOIN "public"."events" "e" ON (("t"."team_id" = "e"."team_id")))
     LEFT JOIN "public"."event_attendance" "ea" ON ((("m"."member_id" = "ea"."member_id") AND ("e"."event_id" = "ea"."event_id"))))
  WHERE ("ea"."attendance_id" IS NULL);


ALTER VIEW "public"."view_members_no_response" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_team_details" AS
 SELECT "team_id",
    "team_name",
    "lower"("team_name") AS "team_name_lowercase",
    "team_unique_code" AS "team_code",
    "lower"("team_unique_code") AS "team_code_lowercase",
    "created_at"
   FROM "public"."teams"
  ORDER BY "team_name";


ALTER VIEW "public"."view_team_details" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_team_members" AS
 SELECT "m"."user_id",
    "m"."member_id",
    "m"."unique_member_code",
    "m"."first_name",
    "m"."last_name",
    "concat"("m"."first_name", ' ', "m"."last_name") AS "member_full_name",
    (("lower"(TRIM(BOTH FROM "m"."first_name")) || ' '::"text") || "lower"(TRIM(BOTH FROM "m"."last_name"))) AS "lower_case_fullname",
    "r"."role_id",
    "r"."role_name",
    "r"."role_level",
    "r"."role_name_plural",
    "r"."role_grade",
    "t"."team_id",
    "t"."team_name",
    "s"."squad_id",
    "s"."squad_name"
   FROM ((((("public"."members" "m"
     JOIN "public"."member_team_link" "mtl" ON (("m"."member_id" = "mtl"."member_id")))
     JOIN "public"."teams" "t" ON (("mtl"."team_id" = "t"."team_id")))
     JOIN "public"."member_team_role_link" "mtrl" ON (("mtl"."member_team_id" = "mtrl"."member_team_id")))
     JOIN "public"."roles" "r" ON (("mtrl"."role_id" = "r"."role_id")))
     LEFT JOIN "public"."squads" "s" ON ((("mtl"."squad_id" = "s"."squad_id") AND ("s"."team_id" = "t"."team_id"))))
  ORDER BY "t"."team_name", "s"."squad_name", "r"."role_grade" DESC, "r"."role_level" DESC, "m"."last_name", "m"."first_name";


ALTER VIEW "public"."view_team_members" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_team_roles" AS
 SELECT "t"."team_id",
    "t"."team_name",
    "t"."team_unique_code",
    "lower"("t"."team_unique_code") AS "team_unique_code_lowercase",
    "r"."role_id",
    "r"."role_name",
    "r"."role_name_plural",
    "r"."role_level",
    "r"."role_grade",
    "r"."role_list_seq",
    COALESCE("role_counts"."member_count", (0)::bigint) AS "member_count"
   FROM ((("public"."teams" "t"
     JOIN "public"."team_roles_link" "trl" ON (("t"."team_id" = "trl"."team_id")))
     JOIN "public"."roles" "r" ON (("trl"."role_id" = "r"."role_id")))
     LEFT JOIN ( SELECT "mtl"."team_id",
            "mtrl"."role_id",
            "count"(DISTINCT "mtl"."member_id") AS "member_count"
           FROM ("public"."member_team_link" "mtl"
             JOIN "public"."member_team_role_link" "mtrl" ON (("mtl"."member_team_id" = "mtrl"."member_team_id")))
          GROUP BY "mtl"."team_id", "mtrl"."role_id") "role_counts" ON ((("t"."team_id" = "role_counts"."team_id") AND ("r"."role_id" = "role_counts"."role_id"))))
  ORDER BY "t"."team_name", "r"."role_list_seq", "r"."role_grade" DESC, "r"."role_level" DESC;


ALTER VIEW "public"."view_team_roles" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_test_data" AS
 WITH "member_teams_roles" AS (
         SELECT "uml"."user_id",
            "uml"."member_id",
            "string_agg"(DISTINCT "t"."team_name", ', '::"text") AS "team_name",
            "string_agg"(DISTINCT "r"."role_name", ', '::"text") AS "role_name",
            "max"("r"."role_level") AS "role_level",
            "max"("r"."role_grade") AS "role_grade"
           FROM (((("public"."user_member_link" "uml"
             JOIN "public"."member_team_link" "mtl" ON (("uml"."member_id" = "mtl"."member_id")))
             JOIN "public"."teams" "t" ON (("mtl"."team_id" = "t"."team_id")))
             JOIN "public"."member_team_role_link" "mtrl" ON (("mtl"."member_team_id" = "mtrl"."member_team_id")))
             JOIN "public"."roles" "r" ON (("mtrl"."role_id" = "r"."role_id")))
          GROUP BY "uml"."user_id", "uml"."member_id"
        ), "base_data" AS (
         SELECT "u"."user_id",
            "u"."email_address",
            "u"."phone_number",
            "u"."first_name" AS "user_first_name",
            "u"."last_name" AS "user_last_name",
            "concat"("u"."first_name", ' ', "u"."last_name") AS "user_full_name",
            "m"."member_id",
            "m"."first_name" AS "member_first_name",
            "m"."last_name" AS "member_last_name",
            "concat"("m"."first_name", ' ', "m"."last_name") AS "member_full_name",
            "mt"."team_name",
            "mt"."role_name",
            "mt"."role_level",
            "mt"."role_grade",
            "m"."profile_pic" AS "member_profile_pic"
           FROM (("public"."users" "u"
             JOIN "member_teams_roles" "mt" ON (("u"."user_id" = "mt"."user_id")))
             JOIN "public"."members" "m" ON (("mt"."member_id" = "m"."member_id")))
        ), "all_members_data" AS (
         SELECT "u"."user_id",
            "u"."email_address",
            "u"."phone_number",
            "u"."first_name" AS "user_first_name",
            "u"."last_name" AS "user_last_name",
            "concat"("u"."first_name", ' ', "u"."last_name") AS "user_full_name",
            999999 AS "member_id",
            NULL::"text" AS "member_first_name",
            NULL::"text" AS "member_last_name",
            'All Members'::"text" AS "member_full_name",
            'All Teams'::"text" AS "team_name",
            'All Roles'::"text" AS "role_name",
            999 AS "role_level",
            999 AS "role_grade",
            'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/hvxmhKxoCA4XCjUFmpM6/assets/50b842h4zvrj/image-removebg-preview_(14).png'::"text" AS "member_profile_pic"
           FROM "public"."users" "u"
          WHERE ("u"."user_id" IN ( SELECT DISTINCT "user_member_link"."user_id"
                   FROM "public"."user_member_link"))
        )
 SELECT "base_data"."user_id",
    "base_data"."email_address",
    "base_data"."phone_number",
    "base_data"."user_first_name",
    "base_data"."user_last_name",
    "base_data"."user_full_name",
    "base_data"."member_id",
    "base_data"."member_first_name",
    "base_data"."member_last_name",
    "base_data"."member_full_name",
    "base_data"."team_name",
    "base_data"."role_name",
    "base_data"."role_level",
    "base_data"."role_grade",
    "base_data"."member_profile_pic"
   FROM "base_data"
UNION ALL
 SELECT "all_members_data"."user_id",
    "all_members_data"."email_address",
    "all_members_data"."phone_number",
    "all_members_data"."user_first_name",
    "all_members_data"."user_last_name",
    "all_members_data"."user_full_name",
    "all_members_data"."member_id",
    "all_members_data"."member_first_name",
    "all_members_data"."member_last_name",
    "all_members_data"."member_full_name",
    "all_members_data"."team_name",
    "all_members_data"."role_name",
    "all_members_data"."role_level",
    "all_members_data"."role_grade",
    "all_members_data"."member_profile_pic"
   FROM "all_members_data"
  ORDER BY 1, 10;


ALTER VIEW "public"."view_test_data" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_unique_user_team_members" AS
 WITH "member_teams_roles" AS (
         SELECT "uml"."user_id",
            "uml"."member_id",
            "string_agg"(DISTINCT "t"."team_name", ', '::"text") AS "team_name",
            "string_agg"(DISTINCT "r"."role_name", ', '::"text") AS "role_name",
            "max"("r"."role_level") AS "role_level",
            "max"("r"."role_grade") AS "role_grade"
           FROM (((("public"."user_member_link" "uml"
             JOIN "public"."member_team_link" "mtl" ON (("uml"."member_id" = "mtl"."member_id")))
             JOIN "public"."teams" "t" ON (("mtl"."team_id" = "t"."team_id")))
             JOIN "public"."member_team_role_link" "mtrl" ON (("mtl"."member_team_id" = "mtrl"."member_team_id")))
             JOIN "public"."roles" "r" ON (("mtrl"."role_id" = "r"."role_id")))
          GROUP BY "uml"."user_id", "uml"."member_id"
        ), "base_data" AS (
         SELECT "u"."user_id",
            "u"."email_address",
            "u"."phone_number",
            "u"."first_name" AS "user_first_name",
            "u"."last_name" AS "user_last_name",
            "concat"("u"."first_name", ' ', "u"."last_name") AS "user_full_name",
            "m"."member_id",
            "m"."first_name" AS "member_first_name",
            "m"."last_name" AS "member_last_name",
            "concat"("m"."first_name", ' ', "m"."last_name") AS "member_full_name",
            "mt"."team_name",
            "mt"."role_name",
            "mt"."role_level",
            "mt"."role_grade",
            "m"."profile_pic" AS "member_profile_pic"
           FROM (("public"."users" "u"
             JOIN "member_teams_roles" "mt" ON (("u"."user_id" = "mt"."user_id")))
             JOIN "public"."members" "m" ON (("mt"."member_id" = "m"."member_id")))
        ), "all_members_data" AS (
         SELECT "bd"."user_id",
            "bd"."email_address",
            "bd"."phone_number",
            "bd"."user_first_name",
            "bd"."user_last_name",
            "bd"."user_full_name",
            (0)::bigint AS "member_id",
            'All Members'::"text" AS "member_first_name",
            'All Members'::"text" AS "member_last_name",
            'All Members'::"text" AS "member_full_name",
            'All Teams'::"text" AS "team_name",
            'All Roles'::"text" AS "role_name",
            999 AS "role_level",
            999 AS "role_grade",
            'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/hvxmhKxoCA4XCjUFmpM6/assets/50b842h4zvrj/image-removebg-preview_(14).png'::"text" AS "member_profile_pic"
           FROM ( SELECT DISTINCT "base_data"."user_id",
                    "base_data"."email_address",
                    "base_data"."phone_number",
                    "base_data"."user_first_name",
                    "base_data"."user_last_name",
                    "base_data"."user_full_name"
                   FROM "base_data") "bd"
        )
 SELECT "base_data"."user_id",
    "base_data"."email_address",
    "base_data"."phone_number",
    "base_data"."user_first_name",
    "base_data"."user_last_name",
    "base_data"."user_full_name",
    "base_data"."member_id",
    "base_data"."member_first_name",
    "base_data"."member_last_name",
    "base_data"."member_full_name",
    "base_data"."team_name",
    "base_data"."role_name",
    "base_data"."role_level",
    "base_data"."role_grade",
    "base_data"."member_profile_pic"
   FROM "base_data"
UNION ALL
 SELECT "all_members_data"."user_id",
    "all_members_data"."email_address",
    "all_members_data"."phone_number",
    "all_members_data"."user_first_name",
    "all_members_data"."user_last_name",
    "all_members_data"."user_full_name",
    "all_members_data"."member_id",
    "all_members_data"."member_first_name",
    "all_members_data"."member_last_name",
    "all_members_data"."member_full_name",
    "all_members_data"."team_name",
    "all_members_data"."role_name",
    "all_members_data"."role_level",
    "all_members_data"."role_grade",
    "all_members_data"."member_profile_pic"
   FROM "all_members_data"
  ORDER BY 1, 10;


ALTER VIEW "public"."view_unique_user_team_members" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_unique_user_teams" AS
 WITH "member_team_highest_role" AS (
         SELECT "mtl"."member_id",
            "mtl"."team_id",
            "mtl"."member_team_id",
            "r"."role_id",
            "r"."role_name",
            "r"."role_level",
            "r"."role_grade",
            "r"."role_name_plural",
            "row_number"() OVER (PARTITION BY "mtl"."member_id", "mtl"."team_id" ORDER BY "r"."role_level" DESC, "r"."role_grade" DESC, "r"."role_id") AS "rn"
           FROM (("public"."member_team_link" "mtl"
             LEFT JOIN "public"."member_team_role_link" "mtrl" ON (("mtl"."member_team_id" = "mtrl"."member_team_id")))
             LEFT JOIN "public"."roles" "r" ON (("mtrl"."role_id" = "r"."role_id")))
        ), "user_member_team_data" AS (
         SELECT "u"."user_id",
            "u"."email_address",
            "u"."phone_number",
            "u"."first_name" AS "user_first_name",
            "u"."last_name" AS "user_last_name",
            "concat"(COALESCE("u"."first_name", ''::"text"), ' ', COALESCE("u"."last_name", ''::"text")) AS "user_full_name",
            "m"."member_id",
            "m"."first_name" AS "member_first_name",
            "m"."last_name" AS "member_last_name",
            "concat"(COALESCE("m"."first_name", ''::"text"), ' ', COALESCE("m"."last_name", ''::"text")) AS "member_full_name",
            "m"."profile_pic" AS "member_profile_pic",
            "t"."team_id",
            "t"."team_name",
            "t"."team_unique_code",
            "lower"("t"."team_unique_code") AS "lower_case_team_code",
            "t"."profile_pic" AS "team_profile_pic",
            "mthr"."role_id",
            "mthr"."role_name",
            "mthr"."role_level",
            "mthr"."role_grade",
            "mthr"."role_name_plural"
           FROM ((((("public"."users" "u"
             JOIN "public"."user_member_link" "uml" ON (("u"."user_id" = "uml"."user_id")))
             JOIN "public"."members" "m" ON (("uml"."member_id" = "m"."member_id")))
             LEFT JOIN "public"."member_team_link" "mtl" ON (("m"."member_id" = "mtl"."member_id")))
             LEFT JOIN "public"."teams" "t" ON (("mtl"."team_id" = "t"."team_id")))
             LEFT JOIN "member_team_highest_role" "mthr" ON ((("mtl"."member_id" = "mthr"."member_id") AND ("mtl"."team_id" = "mthr"."team_id") AND ("mthr"."rn" = 1))))
        ), "unique_team_entry" AS (
         SELECT "user_member_team_data"."user_id",
            "user_member_team_data"."email_address",
            "user_member_team_data"."phone_number",
            "user_member_team_data"."user_first_name",
            "user_member_team_data"."user_last_name",
            "user_member_team_data"."user_full_name",
            "user_member_team_data"."member_id",
            "user_member_team_data"."member_first_name",
            "user_member_team_data"."member_last_name",
            "user_member_team_data"."member_full_name",
            "user_member_team_data"."member_profile_pic",
            "user_member_team_data"."team_id",
            "user_member_team_data"."team_name",
            "user_member_team_data"."team_unique_code",
            "user_member_team_data"."lower_case_team_code",
            "user_member_team_data"."team_profile_pic",
            "user_member_team_data"."role_id",
            "user_member_team_data"."role_name",
            "user_member_team_data"."role_level",
            "user_member_team_data"."role_grade",
            "user_member_team_data"."role_name_plural",
            "row_number"() OVER (PARTITION BY "user_member_team_data"."user_id", "user_member_team_data"."team_id" ORDER BY "user_member_team_data"."role_level" DESC, "user_member_team_data"."role_grade" DESC, "user_member_team_data"."member_id") AS "team_rn"
           FROM "user_member_team_data"
        ), "all_teams_summary" AS (
         SELECT DISTINCT "u"."user_id",
            "u"."email_address",
            "u"."phone_number",
            "u"."first_name" AS "user_first_name",
            "u"."last_name" AS "user_last_name",
            "concat"(COALESCE("u"."first_name", ''::"text"), ' ', COALESCE("u"."last_name", ''::"text")) AS "user_full_name",
            NULL::bigint AS "member_id",
            NULL::"text" AS "member_first_name",
            NULL::"text" AS "member_last_name",
            NULL::"text" AS "member_full_name",
            NULL::"text" AS "member_profile_pic",
            NULL::bigint AS "team_id",
            'All Teams'::"text" AS "team_name",
            NULL::"text" AS "team_unique_code",
            NULL::"text" AS "lower_case_team_code",
            'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/hvxmhKxoCA4XCjUFmpM6/assets/ym9wy9g2glk2/group.png'::"text" AS "team_profile_pic",
            NULL::bigint AS "role_id",
            NULL::"text" AS "role_name",
            NULL::smallint AS "role_level",
            NULL::smallint AS "role_grade",
            NULL::"text" AS "role_name_plural"
           FROM "public"."users" "u"
        )
 SELECT "unique_team_entry"."user_id",
    "unique_team_entry"."email_address",
    "unique_team_entry"."phone_number",
    "unique_team_entry"."user_first_name",
    "unique_team_entry"."user_last_name",
    "unique_team_entry"."user_full_name",
    "unique_team_entry"."member_id",
    "unique_team_entry"."member_first_name",
    "unique_team_entry"."member_last_name",
    "unique_team_entry"."member_full_name",
    "unique_team_entry"."member_profile_pic",
    "unique_team_entry"."team_id",
    "unique_team_entry"."team_name",
    "unique_team_entry"."team_unique_code",
    "unique_team_entry"."lower_case_team_code",
    "unique_team_entry"."team_profile_pic",
    "unique_team_entry"."role_id",
    "unique_team_entry"."role_name",
    "unique_team_entry"."role_level",
    "unique_team_entry"."role_grade",
    "unique_team_entry"."role_name_plural",
        CASE
            WHEN ("unique_team_entry"."team_id" IS NULL) THEN 0
            ELSE 1
        END AS "sort_order"
   FROM "unique_team_entry"
  WHERE ("unique_team_entry"."team_rn" = 1)
UNION ALL
 SELECT "all_teams_summary"."user_id",
    "all_teams_summary"."email_address",
    "all_teams_summary"."phone_number",
    "all_teams_summary"."user_first_name",
    "all_teams_summary"."user_last_name",
    "all_teams_summary"."user_full_name",
    "all_teams_summary"."member_id",
    "all_teams_summary"."member_first_name",
    "all_teams_summary"."member_last_name",
    "all_teams_summary"."member_full_name",
    "all_teams_summary"."member_profile_pic",
    "all_teams_summary"."team_id",
    "all_teams_summary"."team_name",
    "all_teams_summary"."team_unique_code",
    "all_teams_summary"."lower_case_team_code",
    "all_teams_summary"."team_profile_pic",
    "all_teams_summary"."role_id",
    "all_teams_summary"."role_name",
    "all_teams_summary"."role_level",
    "all_teams_summary"."role_grade",
    "all_teams_summary"."role_name_plural",
        CASE
            WHEN ("all_teams_summary"."team_id" IS NULL) THEN 0
            ELSE 1
        END AS "sort_order"
   FROM "all_teams_summary"
  ORDER BY 1, 22, 12, 20 DESC, 19 DESC, 7, 17;


ALTER VIEW "public"."view_unique_user_teams" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_user_clubs" AS
 SELECT DISTINCT "u"."user_id",
    "u"."email_address",
    "u"."first_name" AS "user_first_name",
    "u"."last_name" AS "user_last_name",
    "concat"(COALESCE("u"."first_name", ''::"text"), ' ', COALESCE("u"."last_name", ''::"text")) AS "user_full_name",
    "c"."club_id",
    "c"."club_name",
    "c"."county",
    "c"."banner",
    "c"."crest",
        CASE
            WHEN ("c"."club_name" = 'All Clubs'::"text") THEN 0
            ELSE 1
        END AS "sort_order"
   FROM (((("public"."users" "u"
     JOIN "public"."user_member_link" "uml" ON (("u"."user_id" = "uml"."user_id")))
     JOIN "public"."member_team_link" "mtl" ON (("uml"."member_id" = "mtl"."member_id")))
     JOIN "public"."teams" "t" ON (("mtl"."team_id" = "t"."team_id")))
     JOIN "public"."clubs" "c" ON (("t"."club_id" = "c"."club_id")))
UNION ALL
 SELECT "u"."user_id",
    "u"."email_address",
    "u"."first_name" AS "user_first_name",
    "u"."last_name" AS "user_last_name",
    "concat"(COALESCE("u"."first_name", ''::"text"), ' ', COALESCE("u"."last_name", ''::"text")) AS "user_full_name",
    NULL::bigint AS "club_id",
    'All Clubs'::"text" AS "club_name",
    NULL::"text" AS "county",
    NULL::"text" AS "banner",
    'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/coach-smart-new-mpqa5l/assets/yk304zt4r8kj/Launcher_Icon_v2-removebg-preview.png'::"text" AS "crest",
    0 AS "sort_order"
   FROM "public"."users" "u"
  ORDER BY 1, 11, 7;


ALTER VIEW "public"."view_user_clubs" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_user_highest_role" AS
 WITH "useralldetails" AS (
         SELECT "u"."user_id",
            "u"."first_name",
            "u"."last_name",
            "u"."phone_number",
            "r"."role_id",
            "r"."role_name",
            "r"."role_level",
            "r"."role_name_plural",
            "r"."role_grade",
            ( SELECT ("count"(*) > 0)
                   FROM "public"."user_member_link"
                  WHERE ("user_member_link"."user_id" = "u"."user_id")) AS "has_joined_team"
           FROM ((((("public"."users" "u"
             LEFT JOIN "public"."user_member_link" "uml" ON (("u"."user_id" = "uml"."user_id")))
             LEFT JOIN "public"."members" "m" ON (("uml"."member_id" = "m"."member_id")))
             LEFT JOIN "public"."member_team_link" "mtl" ON (("m"."member_id" = "mtl"."member_id")))
             LEFT JOIN "public"."member_team_role_link" "mtrl" ON (("mtl"."member_team_id" = "mtrl"."member_team_id")))
             LEFT JOIN "public"."roles" "r" ON (("mtrl"."role_id" = "r"."role_id")))
        ), "rankeduserroles" AS (
         SELECT "useralldetails"."user_id",
            "useralldetails"."first_name",
            "useralldetails"."last_name",
            "useralldetails"."phone_number",
            "useralldetails"."role_id",
            "useralldetails"."role_name",
            "useralldetails"."role_level",
            "useralldetails"."role_name_plural",
            "useralldetails"."role_grade",
            "useralldetails"."has_joined_team",
            "row_number"() OVER (PARTITION BY "useralldetails"."user_id" ORDER BY "useralldetails"."role_grade" DESC NULLS LAST, "useralldetails"."role_level" DESC NULLS LAST, "useralldetails"."role_id") AS "rn"
           FROM "useralldetails"
        )
 SELECT "user_id",
    "concat"(COALESCE("first_name", ''::"text"), ' ', COALESCE("last_name", ''::"text")) AS "full_name",
    COALESCE("role_id", (0)::bigint) AS "highest_role_id",
    COALESCE("role_name", 'No Role'::"text") AS "highest_role_name",
    COALESCE(("role_level")::integer, 10) AS "highest_role_level",
    COALESCE("role_name_plural", 'None'::"text") AS "highest_role_name_plural",
    COALESCE(("role_grade")::integer, 10) AS "highest_role_grade",
    ( SELECT "array_agg"(DISTINCT "user_member_link"."member_id" ORDER BY "user_member_link"."member_id") AS "array_agg"
           FROM "public"."user_member_link"
          WHERE ("user_member_link"."user_id" = "rar"."user_id")) AS "user_members",
        CASE
            WHEN (("first_name" IS NOT NULL) AND ("last_name" IS NOT NULL) AND "has_joined_team") THEN 'Yes'::"text"
            ELSE 'No'::"text"
        END AS "onboarded"
   FROM "rankeduserroles" "rar"
  WHERE ("rn" = 1)
  ORDER BY "user_id";


ALTER VIEW "public"."view_user_highest_role" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_user_member_team_events" AS
 WITH "member_team_highest_role" AS (
         SELECT "mtl_1"."member_id",
            "mtl_1"."team_id",
            "r"."role_id",
            "r"."role_name",
            "r"."role_level",
            "r"."role_grade",
            "r"."role_name_plural",
            "row_number"() OVER (PARTITION BY "mtl_1"."member_id", "mtl_1"."team_id" ORDER BY "r"."role_grade" DESC, "r"."role_level" DESC, "r"."role_id") AS "rn_role"
           FROM (("public"."member_team_link" "mtl_1"
             JOIN "public"."member_team_role_link" "mtrl" ON (("mtl_1"."member_team_id" = "mtrl"."member_team_id")))
             JOIN "public"."roles" "r" ON (("mtrl"."role_id" = "r"."role_id")))
        )
 SELECT DISTINCT ON ("u"."user_id", "m"."member_id", "e"."event_id") "u"."user_id",
    "u"."email_address",
    "m"."member_id",
    "m"."first_name",
    "m"."last_name",
    "mthr"."role_id" AS "highest_role_id",
    "mthr"."role_name" AS "highest_role_name",
    "mthr"."role_level" AS "highest_role_level",
    "mthr"."role_grade" AS "highest_role_grade",
    "mthr"."role_name_plural" AS "highest_role_name_plural",
    "t"."team_id",
    "t"."team_name",
    "e"."event_id",
    "e"."event_title",
    "e"."event_date_time",
    "e"."meet_time",
    "e"."opposition",
    "e"."location_name"
   FROM (((((("public"."events" "e"
     JOIN "public"."teams" "t" ON (("e"."team_id" = "t"."team_id")))
     JOIN "public"."member_team_link" "mtl" ON (("t"."team_id" = "mtl"."team_id")))
     JOIN "public"."members" "m" ON (("mtl"."member_id" = "m"."member_id")))
     JOIN "public"."user_member_link" "uml" ON (("m"."member_id" = "uml"."member_id")))
     JOIN "public"."users" "u" ON (("uml"."user_id" = "u"."user_id")))
     JOIN "member_team_highest_role" "mthr" ON ((("m"."member_id" = "mthr"."member_id") AND ("t"."team_id" = "mthr"."team_id") AND ("mthr"."rn_role" = 1))))
  ORDER BY "u"."user_id", "m"."member_id", "e"."event_id", "mthr"."role_grade" DESC, "mthr"."role_level" DESC, "e"."event_date_time" DESC;


ALTER VIEW "public"."view_user_member_team_events" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_user_members" AS
 SELECT "u"."user_id",
    "u"."email_address",
    "u"."phone_number",
    "u"."first_name" AS "user_first_name",
    "u"."last_name" AS "user_last_name",
    "concat"(COALESCE("u"."first_name", ''::"text"), ' ', COALESCE("u"."last_name", ''::"text")) AS "user_full_name",
    "m"."member_id",
    "m"."first_name" AS "member_first_name",
    "m"."last_name" AS "member_last_name",
    "concat"(COALESCE("m"."first_name", ''::"text"), ' ', COALESCE("m"."last_name", ''::"text")) AS "member_full_name",
    "m"."profile_pic" AS "member_profile_pic",
    "t"."team_id",
    "t"."team_name",
    "r"."role_id",
    "r"."role_name",
    "r"."role_level",
    "r"."role_grade"
   FROM (((((("public"."user_member_link" "uml"
     JOIN "public"."users" "u" ON (("uml"."user_id" = "u"."user_id")))
     JOIN "public"."members" "m" ON (("uml"."member_id" = "m"."member_id")))
     LEFT JOIN "public"."member_team_link" "mtl" ON (("m"."member_id" = "mtl"."member_id")))
     LEFT JOIN "public"."teams" "t" ON (("mtl"."team_id" = "t"."team_id")))
     LEFT JOIN "public"."member_team_role_link" "mtrl" ON (("mtl"."member_team_id" = "mtrl"."member_team_id")))
     LEFT JOIN "public"."roles" "r" ON (("mtrl"."role_id" = "r"."role_id")));


ALTER VIEW "public"."view_user_members" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_user_members_new" AS
 SELECT "u"."user_id",
    "uml"."user_member_id",
    "uml"."created_at",
    "m"."member_id",
    "m"."first_name" AS "member_first_name",
    "m"."last_name" AS "member_last_name",
    "m"."profile_pic" AS "member_profile_pic",
    "m"."unique_member_code",
    "u"."email_address",
    "u"."first_name" AS "user_first_name",
    "u"."last_name" AS "user_last_name",
    "u"."phone_number",
    "t"."team_id",
    "t"."team_name",
    "mtl"."member_team_id",
    "r"."role_id",
    "r"."role_name"
   FROM (((((("public"."user_member_link" "uml"
     JOIN "public"."users" "u" ON (("uml"."user_id" = "u"."user_id")))
     JOIN "public"."members" "m" ON (("uml"."member_id" = "m"."member_id")))
     LEFT JOIN "public"."member_team_link" "mtl" ON (("m"."member_id" = "mtl"."member_id")))
     LEFT JOIN "public"."teams" "t" ON (("mtl"."team_id" = "t"."team_id")))
     LEFT JOIN "public"."member_team_role_link" "mtrl" ON (("mtl"."member_team_id" = "mtrl"."member_team_id")))
     LEFT JOIN "public"."roles" "r" ON (("mtrl"."role_id" = "r"."role_id")));


ALTER VIEW "public"."view_user_members_new" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_user_team_highest_role" AS
 WITH "user_team_member_roles_data" AS (
         SELECT "u"."user_id",
            "u"."first_name" AS "user_first_name",
            "u"."last_name" AS "user_last_name",
            "u"."email_address",
            "u"."phone_number",
            "m"."member_id",
            "m"."first_name" AS "member_first_name",
            "m"."last_name" AS "member_last_name",
            "t"."team_id",
            "t"."team_name",
            "t"."team_unique_code",
            "lower"("t"."team_unique_code") AS "lower_case_team_code",
            "r"."role_id",
            "r"."role_name",
            "r"."role_level",
            "r"."role_grade",
            "r"."role_name_plural"
           FROM (((((("public"."users" "u"
             JOIN "public"."user_member_link" "uml" ON (("u"."user_id" = "uml"."user_id")))
             JOIN "public"."members" "m" ON (("uml"."member_id" = "m"."member_id")))
             JOIN "public"."member_team_link" "mtl" ON (("m"."member_id" = "mtl"."member_id")))
             JOIN "public"."teams" "t" ON (("mtl"."team_id" = "t"."team_id")))
             JOIN "public"."member_team_role_link" "mtrl" ON (("mtl"."member_team_id" = "mtrl"."member_team_id")))
             JOIN "public"."roles" "r" ON (("mtrl"."role_id" = "r"."role_id")))
        ), "ranked_roles_per_user_team" AS (
         SELECT "user_team_member_roles_data"."user_id",
            "user_team_member_roles_data"."user_first_name",
            "user_team_member_roles_data"."user_last_name",
            "user_team_member_roles_data"."email_address",
            "user_team_member_roles_data"."phone_number",
            "user_team_member_roles_data"."member_id",
            "user_team_member_roles_data"."member_first_name",
            "user_team_member_roles_data"."member_last_name",
            "user_team_member_roles_data"."team_id",
            "user_team_member_roles_data"."team_name",
            "user_team_member_roles_data"."team_unique_code",
            "user_team_member_roles_data"."lower_case_team_code",
            "user_team_member_roles_data"."role_id",
            "user_team_member_roles_data"."role_name",
            "user_team_member_roles_data"."role_level",
            "user_team_member_roles_data"."role_grade",
            "user_team_member_roles_data"."role_name_plural",
            "row_number"() OVER (PARTITION BY "user_team_member_roles_data"."user_id", "user_team_member_roles_data"."team_id" ORDER BY "user_team_member_roles_data"."role_level" DESC, "user_team_member_roles_data"."role_grade" DESC, "user_team_member_roles_data"."role_id") AS "rn"
           FROM "user_team_member_roles_data"
        )
 SELECT "user_id",
    "concat"("user_first_name", ' ', "user_last_name") AS "user_full_name",
    "email_address",
    "phone_number",
    "team_id",
    "team_name",
    "team_unique_code",
    "lower_case_team_code",
    "role_id",
    "role_name" AS "highest_role_name",
    "role_level" AS "highest_role_level",
    "role_grade" AS "highest_role_grade",
    "role_name_plural" AS "highest_role_name_plural"
   FROM "ranked_roles_per_user_team"
  WHERE ("rn" = 1)
  ORDER BY "user_id", "team_id";


ALTER VIEW "public"."view_user_team_highest_role" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_user_team_member_squad" AS
 WITH "member_team_highest_role" AS (
         SELECT "mtl"."member_id",
            "mtl"."team_id",
            "mtl"."member_team_id",
            "r"."role_id",
            "r"."role_name",
            "r"."role_level",
            "r"."role_grade",
            "r"."role_name_plural",
            "row_number"() OVER (PARTITION BY "mtl"."member_id", "mtl"."team_id" ORDER BY "r"."role_level" DESC, "r"."role_grade" DESC, "r"."role_id") AS "rn"
           FROM (("public"."member_team_link" "mtl"
             LEFT JOIN "public"."member_team_role_link" "mtrl" ON (("mtl"."member_team_id" = "mtrl"."member_team_id")))
             LEFT JOIN "public"."roles" "r" ON (("mtrl"."role_id" = "r"."role_id")))
        ), "user_member_team_data" AS (
         SELECT "u"."user_id",
            "u"."email_address",
            "u"."phone_number",
            "u"."first_name" AS "user_first_name",
            "u"."last_name" AS "user_last_name",
            "concat"(COALESCE("u"."first_name", ''::"text"), ' ', COALESCE("u"."last_name", ''::"text")) AS "user_full_name",
            "m"."member_id",
            "m"."first_name" AS "member_first_name",
            "m"."last_name" AS "member_last_name",
            "concat"(COALESCE("m"."first_name", ''::"text"), ' ', COALESCE("m"."last_name", ''::"text")) AS "member_full_name",
            "t"."team_id",
            "t"."team_name",
            "t"."team_unique_code",
            "lower"("t"."team_unique_code") AS "lower_case_team_code",
            "s"."squad_id",
            "s"."squad_name",
            "mthr"."role_id",
            "mthr"."role_name",
            "mthr"."role_level",
            "mthr"."role_grade",
            "mthr"."role_name_plural"
           FROM (((((("public"."users" "u"
             JOIN "public"."user_member_link" "uml" ON (("u"."user_id" = "uml"."user_id")))
             JOIN "public"."members" "m" ON (("uml"."member_id" = "m"."member_id")))
             LEFT JOIN "public"."member_team_link" "mtl" ON (("m"."member_id" = "mtl"."member_id")))
             LEFT JOIN "public"."teams" "t" ON (("mtl"."team_id" = "t"."team_id")))
             LEFT JOIN "public"."squads" "s" ON (("mtl"."squad_id" = "s"."squad_id")))
             LEFT JOIN "member_team_highest_role" "mthr" ON ((("mtl"."member_id" = "mthr"."member_id") AND ("mtl"."team_id" = "mthr"."team_id") AND ("mthr"."rn" = 1))))
        )
 SELECT DISTINCT "user_id",
    "email_address",
    "phone_number",
    "user_first_name",
    "user_last_name",
    "user_full_name",
    "member_id",
    "member_first_name",
    "member_last_name",
    "member_full_name",
    "team_id",
    "team_name",
    "team_unique_code",
    "lower_case_team_code",
    "squad_id",
    "squad_name",
    "role_id",
    "role_name",
    "role_level",
    "role_grade",
    "role_name_plural"
   FROM "user_member_team_data"
  ORDER BY "user_id", "team_id", "squad_name", "role_grade" DESC, "role_level" DESC, "role_id";


ALTER VIEW "public"."view_user_team_member_squad" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_user_team_members" AS
 SELECT "u"."user_id",
    "u"."email_address",
    "u"."phone_number",
    "u"."first_name" AS "user_first_name",
    "u"."last_name" AS "user_last_name",
    "concat"(COALESCE("u"."first_name", ''::"text"), ' ', COALESCE("u"."last_name", ''::"text")) AS "user_full_name",
    "m"."member_id",
    "m"."first_name" AS "member_first_name",
    "m"."last_name" AS "member_last_name",
    "concat"(COALESCE("m"."first_name", ''::"text"), ' ', COALESCE("m"."last_name", ''::"text")) AS "member_full_name",
    "m"."profile_pic" AS "member_profile_pic",
    "t"."team_id",
    "t"."team_name",
    "r"."role_id",
    "r"."role_name",
    "r"."role_level",
    "r"."role_grade",
    "r"."role_name_plural"
   FROM (((((("public"."members" "m"
     JOIN "public"."user_member_link" "uml" ON (("m"."member_id" = "uml"."member_id")))
     JOIN "public"."users" "u" ON (("uml"."user_id" = "u"."user_id")))
     LEFT JOIN "public"."member_team_link" "mtl" ON (("m"."member_id" = "mtl"."member_id")))
     LEFT JOIN "public"."teams" "t" ON (("mtl"."team_id" = "t"."team_id")))
     LEFT JOIN "public"."member_team_role_link" "mtrl" ON (("mtl"."member_team_id" = "mtrl"."member_team_id")))
     LEFT JOIN "public"."roles" "r" ON (("mtrl"."role_id" = "r"."role_id")))
  ORDER BY "u"."user_id", "m"."member_id", "t"."team_id", "r"."role_grade" DESC, "r"."role_level" DESC, "r"."role_id";


ALTER VIEW "public"."view_user_team_members" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_user_teams" AS
 SELECT DISTINCT "u"."user_id",
    "u"."email_address",
    "t"."team_id",
    "t"."team_name",
    "t"."team_unique_code",
    "r"."role_id",
    "r"."role_name",
    "r"."role_level",
    "r"."role_name_plural",
    "r"."role_grade"
   FROM (((((("public"."users" "u"
     JOIN "public"."user_member_link" "uml" ON (("u"."user_id" = "uml"."user_id")))
     JOIN "public"."members" "m" ON (("uml"."member_id" = "m"."member_id")))
     JOIN "public"."member_team_link" "mtl" ON (("m"."member_id" = "mtl"."member_id")))
     JOIN "public"."teams" "t" ON (("mtl"."team_id" = "t"."team_id")))
     JOIN "public"."member_team_role_link" "mtrl" ON (("mtl"."member_team_id" = "mtrl"."member_team_id")))
     JOIN "public"."roles" "r" ON (("mtrl"."role_id" = "r"."role_id")));


ALTER VIEW "public"."view_user_teams" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_user_teams_grade" AS
 SELECT DISTINCT "u"."user_id",
    "u"."email_address",
    "u"."first_name" AS "user_first_name",
    "u"."last_name" AS "user_last_name",
    "m"."member_id",
    "m"."first_name" AS "member_first_name",
    "m"."last_name" AS "member_last_name",
    "t"."team_id",
    "t"."team_name",
    "t"."team_unique_code",
    "r"."role_id",
    "r"."role_name",
    "r"."role_level",
    "r"."role_grade",
    "r"."role_name_plural"
   FROM (((((("public"."users" "u"
     JOIN "public"."user_member_link" "uml" ON (("u"."user_id" = "uml"."user_id")))
     JOIN "public"."members" "m" ON (("uml"."member_id" = "m"."member_id")))
     JOIN "public"."member_team_link" "mtl" ON (("m"."member_id" = "mtl"."member_id")))
     JOIN "public"."teams" "t" ON (("mtl"."team_id" = "t"."team_id")))
     JOIN "public"."member_team_role_link" "mtrl" ON (("mtl"."member_team_id" = "mtrl"."member_team_id")))
     JOIN "public"."roles" "r" ON (("mtrl"."role_id" = "r"."role_id")))
  ORDER BY "u"."user_id", "m"."member_id", "t"."team_id", "r"."role_level" DESC, "r"."role_id";


ALTER VIEW "public"."view_user_teams_grade" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_user_unique_member_team_events" AS
 WITH "eventteammembers" AS (
         SELECT "e"."event_id",
            "array_agg"(DISTINCT "combined_members"."member_id" ORDER BY "combined_members"."member_id") AS "team_members"
           FROM (("public"."events" "e"
             JOIN "public"."teams" "t" ON (("e"."team_id" = "t"."team_id")))
             JOIN ( SELECT "mtl_sub"."team_id",
                    "mtl_sub"."member_id"
                   FROM "public"."member_team_link" "mtl_sub"
                UNION ALL
                 SELECT "t_sub"."team_id",
                    (0)::bigint AS "member_id"
                   FROM "public"."teams" "t_sub") "combined_members" ON (("t"."team_id" = "combined_members"."team_id")))
          GROUP BY "e"."event_id"
        ), "usermembereventrolecontext" AS (
         SELECT "u"."user_id",
            "u"."first_name" AS "user_first_name",
            "u"."last_name" AS "user_last_name",
            "u"."phone_number",
            "u"."email_address",
            "m"."member_id",
            "m"."first_name" AS "member_first_name",
            "m"."last_name" AS "member_last_name",
            "m"."created_at" AS "member_created_at",
            "t"."team_id",
            "t"."team_name",
            "t"."club_id",
            "c"."club_name",
            "r"."role_id",
            "r"."role_name",
            "r"."role_level",
            "r"."role_grade",
            "r"."role_name_plural",
            "e"."event_id",
            "e"."event_title",
            "e"."event_date_time",
            "e"."meet_time",
            "e"."opposition",
            "e"."location_name",
            "e"."event_details",
            "e"."audience_id",
            "e"."request_attendance",
            "audience_role"."role_grade" AS "event_role_grade",
            "audience_role"."role_level" AS "event_role_level",
            "ec"."event_code",
            "et"."event_type",
            "creator"."user_id" AS "created_by_user_id",
            "creator"."first_name" AS "created_by_first_name",
            "creator"."last_name" AS "created_by_last_name",
            "creator"."phone_number" AS "created_by_phone_number",
            "creator"."email_address" AS "created_by_email_address",
            "etm"."team_members",
            "row_number"() OVER (PARTITION BY "u"."user_id", "e"."event_id" ORDER BY "r"."role_grade" DESC, "r"."role_level" DESC, "m"."created_at" DESC, "m"."member_id") AS "rn"
           FROM ((((((((((((("public"."users" "u"
             JOIN "public"."user_member_link" "uml" ON (("u"."user_id" = "uml"."user_id")))
             JOIN "public"."members" "m" ON (("uml"."member_id" = "m"."member_id")))
             JOIN "public"."member_team_link" "mtl" ON (("m"."member_id" = "mtl"."member_id")))
             JOIN "public"."member_team_role_link" "mtrl" ON (("mtl"."member_team_id" = "mtrl"."member_team_id")))
             JOIN "public"."roles" "r" ON (("mtrl"."role_id" = "r"."role_id")))
             JOIN "public"."teams" "t" ON (("mtl"."team_id" = "t"."team_id")))
             JOIN "public"."clubs" "c" ON (("t"."club_id" = "c"."club_id")))
             JOIN "public"."events" "e" ON (("e"."team_id" = "t"."team_id")))
             LEFT JOIN "public"."roles" "audience_role" ON (("e"."audience_id" = "audience_role"."role_id")))
             JOIN "public"."event_codes" "ec" ON (("e"."event_code_id" = "ec"."code_id")))
             JOIN "public"."event_types" "et" ON (("e"."event_type_id" = "et"."event_type_id")))
             JOIN "public"."users" "creator" ON (("e"."created_by" = "creator"."user_id")))
             LEFT JOIN "eventteammembers" "etm" ON (("e"."event_id" = "etm"."event_id")))
        )
 SELECT "user_id",
    "user_first_name",
    "user_last_name",
    "phone_number",
    "email_address",
    "member_id",
    "member_first_name",
    "member_last_name",
    "team_id",
    "team_name",
    "club_id",
    "club_name",
    "role_id",
    "role_name",
    "role_level",
    "role_grade",
    "role_name_plural",
    "event_id",
    "event_title",
    "event_date_time",
    "meet_time",
    "opposition",
    "location_name",
    "event_details",
    "audience_id",
    "request_attendance",
    "event_role_grade",
    "event_role_level",
    "event_code",
    "event_type",
    "created_by_user_id",
    "created_by_first_name",
    "created_by_last_name",
    "created_by_phone_number",
    "created_by_email_address",
    "team_members"
   FROM "usermembereventrolecontext"
  WHERE ("rn" = 1)
  ORDER BY "event_date_time" DESC, "user_last_name", "user_first_name";


ALTER VIEW "public"."view_user_unique_member_team_events" OWNER TO "postgres";


ALTER TABLE ONLY "public"."car_pool_detail"
    ADD CONSTRAINT "car_pool_detail_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."car_pool"
    ADD CONSTRAINT "car_pool_pkey" PRIMARY KEY ("car_pool_id");



ALTER TABLE ONLY "public"."club_code_link"
    ADD CONSTRAINT "club_code_link_pkey" PRIMARY KEY ("club_code_id");



ALTER TABLE ONLY "public"."clubs"
    ADD CONSTRAINT "clubs_pkey" PRIMARY KEY ("club_id");



ALTER TABLE ONLY "public"."event_attendance"
    ADD CONSTRAINT "event_attendance_pkey" PRIMARY KEY ("attendance_id");



ALTER TABLE ONLY "public"."event_codes"
    ADD CONSTRAINT "event_codes_pkey" PRIMARY KEY ("code_id");



ALTER TABLE ONLY "public"."event_response_type"
    ADD CONSTRAINT "event_responses_pkey" PRIMARY KEY ("response_id");



ALTER TABLE ONLY "public"."event_types"
    ADD CONSTRAINT "event_types_pkey" PRIMARY KEY ("event_type_id");



ALTER TABLE ONLY "public"."event_user_member_payment"
    ADD CONSTRAINT "event_user_member_payment_pkey" PRIMARY KEY ("payment_id");



ALTER TABLE ONLY "public"."event_user_payment"
    ADD CONSTRAINT "event_user_payment_pkey" PRIMARY KEY ("payment_id");



ALTER TABLE ONLY "public"."event_user_payment"
    ADD CONSTRAINT "event_user_payment_stripe_session_id_key" UNIQUE ("stripe_session_id");



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_pkey" PRIMARY KEY ("event_id");



ALTER TABLE ONLY "public"."game_ages"
    ADD CONSTRAINT "game_ages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."games"
    ADD CONSTRAINT "games_pkey" PRIMARY KEY ("game_id");



ALTER TABLE ONLY "public"."invitations"
    ADD CONSTRAINT "invitations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."legacy_users"
    ADD CONSTRAINT "legacy_users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."lineup_details"
    ADD CONSTRAINT "lineup_details_pkey" PRIMARY KEY ("lineup_detail_id");



ALTER TABLE ONLY "public"."lineup"
    ADD CONSTRAINT "lineup_pkey" PRIMARY KEY ("lineup_id");



ALTER TABLE ONLY "public"."match_squads"
    ADD CONSTRAINT "match _squads_pkey" PRIMARY KEY ("match_squad_id");



ALTER TABLE ONLY "public"."match_reports"
    ADD CONSTRAINT "match_reports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."match_stat_categories"
    ADD CONSTRAINT "match_score_catregories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."match_stat_type_team_link"
    ADD CONSTRAINT "match_score_type_team_link_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."match_stat_types"
    ADD CONSTRAINT "match_score_types_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."match_stats_details"
    ADD CONSTRAINT "match_scores_details_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."match_stats"
    ADD CONSTRAINT "match_scores_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."match_squad_details"
    ADD CONSTRAINT "match_squad_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."match_timer"
    ADD CONSTRAINT "match_timer_event_user_unique" UNIQUE ("event_id", "user_id");



ALTER TABLE ONLY "public"."match_timer"
    ADD CONSTRAINT "match_timer_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."member_squad_link"
    ADD CONSTRAINT "member_squad_link_pkey" PRIMARY KEY ("member_squad_id");



ALTER TABLE ONLY "public"."member_team_link"
    ADD CONSTRAINT "member_team_link_pkey" PRIMARY KEY ("member_team_id");



ALTER TABLE ONLY "public"."member_team_role_link"
    ADD CONSTRAINT "member_team_role_link_pkey" PRIMARY KEY ("member_team_role_id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."reminders"
    ADD CONSTRAINT "reminders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."roles"
    ADD CONSTRAINT "roles_pkey" PRIMARY KEY ("role_id");



ALTER TABLE ONLY "public"."sport"
    ADD CONSTRAINT "sport_pkey" PRIMARY KEY ("sport_id");



ALTER TABLE ONLY "public"."squads"
    ADD CONSTRAINT "squad_pkey" PRIMARY KEY ("squad_id");



ALTER TABLE ONLY "public"."members"
    ADD CONSTRAINT "team_member_pkey" PRIMARY KEY ("member_id");



ALTER TABLE ONLY "public"."team_roles_link"
    ADD CONSTRAINT "team_role_link_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."teams"
    ADD CONSTRAINT "teams_pkey" PRIMARY KEY ("team_id");



ALTER TABLE ONLY "public"."teams"
    ADD CONSTRAINT "teams_team_code_key" UNIQUE ("team_unique_code");



ALTER TABLE ONLY "public"."event_user_member_payment"
    ADD CONSTRAINT "unique_member_payment_session" UNIQUE ("stripe_session_id", "member_id");



ALTER TABLE ONLY "public"."user_game_link"
    ADD CONSTRAINT "user_game_link_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_member_link"
    ADD CONSTRAINT "user_member_link_pkey" PRIMARY KEY ("user_member_id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_email_address_key" UNIQUE ("email_address");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("user_id");



CREATE INDEX "events_created_by_idx" ON "public"."events" USING "btree" ("created_by");



CREATE INDEX "idx_car_pool_detail_car_pool_id" ON "public"."car_pool_detail" USING "btree" ("car_pool_id");



CREATE INDEX "idx_car_pool_detail_member_id" ON "public"."car_pool_detail" USING "btree" ("member_id");



CREATE INDEX "idx_car_pool_detail_status" ON "public"."car_pool_detail" USING "btree" ("status");



CREATE INDEX "idx_car_pool_event_id" ON "public"."car_pool" USING "btree" ("event_id");



CREATE INDEX "idx_car_pool_user_id" ON "public"."car_pool" USING "btree" ("user_id");



CREATE INDEX "idx_clubs_default_club" ON "public"."clubs" USING "btree" ("default_club");



CREATE INDEX "idx_clubs_sport_id" ON "public"."clubs" USING "btree" ("sport_id");



CREATE INDEX "idx_event_att_dedup" ON "public"."event_attendance" USING "btree" ("event_id", "member_id", "attendance_id" DESC);



CREATE INDEX "idx_event_attendance_accepted" ON "public"."event_attendance" USING "btree" ("event_id", "member_id") WHERE ("response_id" = 3);



CREATE INDEX "idx_event_attendance_declined" ON "public"."event_attendance" USING "btree" ("event_id", "member_id") WHERE ("response_id" = 4);



CREATE INDEX "idx_event_attendance_event_id" ON "public"."event_attendance" USING "btree" ("event_id");



CREATE INDEX "idx_event_attendance_lookup" ON "public"."event_attendance" USING "btree" ("event_id", "member_id", "created_at" DESC);



CREATE INDEX "idx_event_attendance_member_id" ON "public"."event_attendance" USING "btree" ("member_id");



CREATE INDEX "idx_event_attendance_no_response" ON "public"."event_attendance" USING "btree" ("event_id", "member_id") WHERE ("response_id" IS NULL);



CREATE INDEX "idx_event_attendance_response_id" ON "public"."event_attendance" USING "btree" ("response_id");



CREATE INDEX "idx_event_payment_confirmed_lookup" ON "public"."event_user_member_payment" USING "btree" ("event_id", "user_id") WHERE ("payment_status" = 'confirmed'::"text");



CREATE INDEX "idx_event_response_type_id" ON "public"."event_response_type" USING "btree" ("response_id");



CREATE INDEX "idx_event_user_member_payment_event_id" ON "public"."event_user_member_payment" USING "btree" ("event_id");



CREATE INDEX "idx_event_user_member_payment_member_id" ON "public"."event_user_member_payment" USING "btree" ("member_id");



CREATE INDEX "idx_event_user_member_payment_status" ON "public"."event_user_member_payment" USING "btree" ("payment_status");



CREATE INDEX "idx_event_user_payment_event_id" ON "public"."event_user_payment" USING "btree" ("event_id");



CREATE INDEX "idx_event_user_payment_status" ON "public"."event_user_payment" USING "btree" ("payment_status");



CREATE INDEX "idx_event_user_payment_user_id" ON "public"."event_user_payment" USING "btree" ("user_id");



CREATE INDEX "idx_events_audience_id" ON "public"."events" USING "btree" ("audience_id");



CREATE INDEX "idx_events_date_team" ON "public"."events" USING "btree" ("event_date_time", "team_id") WHERE ("event_date_time" IS NOT NULL);



CREATE INDEX "idx_events_event_code_id" ON "public"."events" USING "btree" ("event_code_id");



CREATE INDEX "idx_events_event_type_id" ON "public"."events" USING "btree" ("event_type_id");



CREATE INDEX "idx_events_report_data" ON "public"."events" USING "btree" ("team_id", "event_date_time", "event_id") INCLUDE ("event_title", "event_type_id", "event_code_id", "opposition");



CREATE INDEX "idx_events_squad_id" ON "public"."events" USING "btree" ("squad_id");



CREATE INDEX "idx_events_team_date" ON "public"."events" USING "btree" ("team_id", "event_date_time" DESC);



CREATE INDEX "idx_events_team_id" ON "public"."events" USING "btree" ("team_id");



CREATE INDEX "idx_export_match_details" ON "public"."match_squad_details" USING "btree" ("match_squad_id", "squad_id", "role_id", "member_id") INCLUDE ("user_id", "team_id", "event_id");



CREATE INDEX "idx_games_game_age" ON "public"."games" USING "gin" ("game_age");



CREATE INDEX "idx_games_game_code" ON "public"."games" USING "gin" ("game_code");



CREATE INDEX "idx_games_game_skill" ON "public"."games" USING "gin" ("game_skill");



CREATE INDEX "idx_games_game_type" ON "public"."games" USING "gin" ("game_type");



CREATE INDEX "idx_invitations_user_id" ON "public"."invitations" USING "btree" ("user_id");



CREATE INDEX "idx_lineup_details_lineup_id" ON "public"."lineup_details" USING "btree" ("lineup_id");



CREATE INDEX "idx_lineup_event_id" ON "public"."lineup" USING "btree" ("event_id");



CREATE INDEX "idx_lineup_team_id" ON "public"."lineup" USING "btree" ("team_id");



CREATE INDEX "idx_match_scores_details_score_id" ON "public"."match_stats_details" USING "btree" ("match_stats_id");



CREATE INDEX "idx_match_scores_details_score_type" ON "public"."match_stats_details" USING "btree" ("score_type");



CREATE INDEX "idx_match_scores_event_id" ON "public"."match_stats" USING "btree" ("event_id");



CREATE INDEX "idx_match_scores_squad_id" ON "public"."match_stats" USING "btree" ("squad_id");



CREATE INDEX "idx_match_scores_user_id" ON "public"."match_stats" USING "btree" ("user_id");



CREATE INDEX "idx_match_squad_details_complete" ON "public"."match_squad_details" USING "btree" ("match_squad_id", "squad_id", "role_id", "member_id") INCLUDE ("user_id", "team_id");



CREATE INDEX "idx_match_squad_details_event_id" ON "public"."match_squad_details" USING "btree" ("event_id");



CREATE INDEX "idx_match_squad_details_lookup" ON "public"."match_squad_details" USING "btree" ("match_squad_id", "squad_id", "role_id", "member_id");



CREATE INDEX "idx_match_squad_details_match_squad_id" ON "public"."match_squad_details" USING "btree" ("match_squad_id");



CREATE INDEX "idx_match_squad_details_member_id" ON "public"."match_squad_details" USING "btree" ("member_id");



CREATE INDEX "idx_match_squad_details_role_id" ON "public"."match_squad_details" USING "btree" ("role_id");



CREATE INDEX "idx_match_squad_details_squad_id" ON "public"."match_squad_details" USING "btree" ("squad_id");



CREATE INDEX "idx_match_squad_details_team_id" ON "public"."match_squad_details" USING "btree" ("team_id");



CREATE INDEX "idx_match_squad_details_user_id" ON "public"."match_squad_details" USING "btree" ("user_id");



CREATE INDEX "idx_match_squad_details_view" ON "public"."match_squad_details" USING "btree" ("event_id", "squad_id", "role_id", "member_id");



CREATE INDEX "idx_match_squads_event_squad_desc" ON "public"."match_squads" USING "btree" ("event_id", "match_squad_id" DESC);



CREATE INDEX "idx_match_squads_user_id" ON "public"."match_squads" USING "btree" ("user_id");



CREATE INDEX "idx_member_squad_link_code_fallback" ON "public"."member_squad_link" USING "btree" ("team_id", "code_id") WHERE ("code_id" IS NOT NULL);



CREATE INDEX "idx_member_squad_link_code_id" ON "public"."member_squad_link" USING "btree" ("code_id");



CREATE INDEX "idx_member_squad_link_lookup" ON "public"."member_squad_link" USING "btree" ("team_id", "code_id", "squad_id") WHERE ("squad_id" IS NOT NULL);



CREATE INDEX "idx_member_squad_link_member_id" ON "public"."member_squad_link" USING "btree" ("member_id");



CREATE INDEX "idx_member_squad_link_squad_id" ON "public"."member_squad_link" USING "btree" ("squad_id");



CREATE INDEX "idx_member_squad_link_team_id" ON "public"."member_squad_link" USING "btree" ("team_id");



CREATE INDEX "idx_member_squad_link_view" ON "public"."member_squad_link" USING "btree" ("member_id", "squad_id", "code_id");



CREATE INDEX "idx_member_team_link_member_id" ON "public"."member_team_link" USING "btree" ("member_id");



CREATE INDEX "idx_member_team_link_squad_id" ON "public"."member_team_link" USING "btree" ("squad_id");



CREATE INDEX "idx_member_team_link_team_id" ON "public"."member_team_link" USING "btree" ("team_id");



CREATE INDEX "idx_member_team_link_team_member" ON "public"."member_team_link" USING "btree" ("team_id", "member_id");



CREATE INDEX "idx_member_team_member" ON "public"."member_team_link" USING "btree" ("member_id", "team_id");



CREATE INDEX "idx_member_team_role_link_role_id" ON "public"."member_team_role_link" USING "btree" ("role_id");



CREATE INDEX "idx_members_name_lookup" ON "public"."members" USING "btree" ("member_id") INCLUDE ("first_name", "last_name", "profile_pic");



CREATE INDEX "idx_members_on_user_id" ON "public"."members" USING "btree" ("user_id");



CREATE INDEX "idx_msd_team_event_squad_member" ON "public"."match_squad_details" USING "btree" ("team_id", "event_id", "squad_id", "member_id");



CREATE INDEX "idx_mtrl_member_team_id" ON "public"."member_team_role_link" USING "btree" ("member_team_id");



CREATE INDEX "idx_notifications_is_read" ON "public"."notifications" USING "btree" ("is_read") WHERE ("is_read" = false);



CREATE INDEX "idx_notifications_recipient_all" ON "public"."notifications" USING "btree" ("recipient_user_id", "created_at" DESC);



CREATE INDEX "idx_notifications_recipient_unread" ON "public"."notifications" USING "btree" ("recipient_user_id") WHERE ("is_read" = false);



CREATE INDEX "idx_payment_user_id" ON "public"."event_user_member_payment" USING "btree" ("user_id");



CREATE INDEX "idx_reminders_event_id" ON "public"."reminders" USING "btree" ("event_id");



CREATE INDEX "idx_reminders_user_id" ON "public"."reminders" USING "btree" ("user_id");



CREATE INDEX "idx_role_attendance_members" ON "public"."member_squad_link" USING "btree" ("team_id", "code_id", "member_id", "squad_id");



CREATE INDEX "idx_roles_grade_level" ON "public"."roles" USING "btree" ("role_grade" DESC, "role_level" DESC, "role_id");



CREATE INDEX "idx_roles_lookup" ON "public"."roles" USING "btree" ("role_level", "role_grade") INCLUDE ("role_name", "role_name_plural");



CREATE INDEX "idx_squads_grade_lookup" ON "public"."squads" USING "btree" ("team_id", "grade") WHERE ("grade" IS NOT NULL);



CREATE INDEX "idx_squads_team_id" ON "public"."squads" USING "btree" ("team_id");



CREATE INDEX "idx_summary_function_roles" ON "public"."member_team_role_link" USING "btree" ("member_team_id", "role_id");



CREATE INDEX "idx_summary_function_squad" ON "public"."member_squad_link" USING "btree" ("team_id", "code_id", "squad_id", "member_id");



CREATE INDEX "idx_team_roles_link_lookup" ON "public"."team_roles_link" USING "btree" ("team_id", "role_id");



CREATE INDEX "idx_team_roles_link_role_id" ON "public"."team_roles_link" USING "btree" ("role_id");



CREATE INDEX "idx_teams_club_id" ON "public"."teams" USING "btree" ("club_id");



CREATE INDEX "idx_uml_user_member" ON "public"."user_member_link" USING "btree" ("user_id", "member_id");



CREATE INDEX "idx_user_member_link_member_id" ON "public"."user_member_link" USING "btree" ("member_id");



CREATE INDEX "idx_user_member_link_user_id" ON "public"."user_member_link" USING "btree" ("user_id");



CREATE INDEX "match_squads_event_id_idx" ON "public"."match_squads" USING "btree" ("event_id");



CREATE INDEX "member_team_link_member_team_id_idx" ON "public"."member_team_link" USING "btree" ("member_id", "team_id", "member_team_id");



CREATE INDEX "member_team_role_link_mtl_id_created_at_desc" ON "public"."member_team_role_link" USING "btree" ("member_team_id", "created_at" DESC);



CREATE INDEX "team_roles_link_team_id_idx" ON "public"."team_roles_link" USING "btree" ("team_id");



CREATE OR REPLACE TRIGGER "match_timer_updated_at" BEFORE UPDATE ON "public"."match_timer" FOR EACH ROW EXECUTE FUNCTION "public"."set_match_timer_updated_at"();



CREATE OR REPLACE TRIGGER "set_member_code_trigger" BEFORE INSERT ON "public"."members" FOR EACH ROW EXECUTE FUNCTION "public"."set_member_code"();



CREATE OR REPLACE TRIGGER "set_team_code_trigger" BEFORE INSERT ON "public"."teams" FOR EACH ROW EXECUTE FUNCTION "public"."set_team_code_on_insert"();



ALTER TABLE ONLY "public"."car_pool_detail"
    ADD CONSTRAINT "car_pool_detail_car_pool_id_fkey" FOREIGN KEY ("car_pool_id") REFERENCES "public"."car_pool"("car_pool_id");



ALTER TABLE ONLY "public"."car_pool_detail"
    ADD CONSTRAINT "car_pool_detail_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "public"."members"("member_id");



ALTER TABLE ONLY "public"."car_pool"
    ADD CONSTRAINT "car_pool_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("event_id");



ALTER TABLE ONLY "public"."car_pool"
    ADD CONSTRAINT "car_pool_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("user_id");



ALTER TABLE ONLY "public"."club_code_link"
    ADD CONSTRAINT "club_code_link_club_id_fkey" FOREIGN KEY ("club_id") REFERENCES "public"."clubs"("club_id");



ALTER TABLE ONLY "public"."club_code_link"
    ADD CONSTRAINT "club_code_link_code_id_fkey" FOREIGN KEY ("code_id") REFERENCES "public"."event_codes"("code_id");



ALTER TABLE ONLY "public"."clubs"
    ADD CONSTRAINT "clubs_default club_fkey" FOREIGN KEY ("default_club") REFERENCES "public"."clubs"("club_id");



ALTER TABLE ONLY "public"."clubs"
    ADD CONSTRAINT "clubs_sport_id_fkey" FOREIGN KEY ("sport_id") REFERENCES "public"."sport"("sport_id");



ALTER TABLE ONLY "public"."event_attendance"
    ADD CONSTRAINT "event_attendance_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("event_id");



ALTER TABLE ONLY "public"."event_attendance"
    ADD CONSTRAINT "event_attendance_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "public"."members"("member_id");



ALTER TABLE ONLY "public"."event_attendance"
    ADD CONSTRAINT "event_attendance_response_id_fkey" FOREIGN KEY ("response_id") REFERENCES "public"."event_response_type"("response_id");



ALTER TABLE ONLY "public"."event_user_member_payment"
    ADD CONSTRAINT "event_user_member_payment_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("event_id");



ALTER TABLE ONLY "public"."event_user_member_payment"
    ADD CONSTRAINT "event_user_member_payment_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "public"."members"("member_id");



ALTER TABLE ONLY "public"."event_user_member_payment"
    ADD CONSTRAINT "event_user_member_payment_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("user_id");



ALTER TABLE ONLY "public"."event_user_payment"
    ADD CONSTRAINT "event_user_payment_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("event_id");



ALTER TABLE ONLY "public"."event_user_payment"
    ADD CONSTRAINT "event_user_payment_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("user_id");



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_audience_id_fkey" FOREIGN KEY ("audience_id") REFERENCES "public"."roles"("role_id");



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."users"("user_id");



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_event_code_id_fkey" FOREIGN KEY ("event_code_id") REFERENCES "public"."event_codes"("code_id");



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_event_type_id_fkey" FOREIGN KEY ("event_type_id") REFERENCES "public"."event_types"("event_type_id");



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_squad_id_fkey" FOREIGN KEY ("squad_id") REFERENCES "public"."squads"("squad_id");



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("team_id");



ALTER TABLE ONLY "public"."invitations"
    ADD CONSTRAINT "invitations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("user_id");



ALTER TABLE ONLY "public"."lineup"
    ADD CONSTRAINT "lineup_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."lineup_details"
    ADD CONSTRAINT "lineup_details_lineup_id_fkey" FOREIGN KEY ("lineup_id") REFERENCES "public"."lineup"("lineup_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."lineup_details"
    ADD CONSTRAINT "lineup_details_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "public"."members"("member_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."lineup"
    ADD CONSTRAINT "lineup_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("event_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."lineup"
    ADD CONSTRAINT "lineup_squad_id_fkey" FOREIGN KEY ("squad_id") REFERENCES "public"."squads"("squad_id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."lineup"
    ADD CONSTRAINT "lineup_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("team_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."match_squads"
    ADD CONSTRAINT "match _squads_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("event_id");



ALTER TABLE ONLY "public"."match_squads"
    ADD CONSTRAINT "match _squads_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("user_id");



ALTER TABLE ONLY "public"."match_reports"
    ADD CONSTRAINT "match_reports_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("event_id");



ALTER TABLE ONLY "public"."match_reports"
    ADD CONSTRAINT "match_reports_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("user_id");



ALTER TABLE ONLY "public"."match_stat_type_team_link"
    ADD CONSTRAINT "match_score_type_team_link_match_score_type_id_fkey" FOREIGN KEY ("match_score_type_id") REFERENCES "public"."match_stat_types"("id");



ALTER TABLE ONLY "public"."match_stat_type_team_link"
    ADD CONSTRAINT "match_score_type_team_link_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("team_id");



ALTER TABLE ONLY "public"."match_stat_types"
    ADD CONSTRAINT "match_score_types_score_category_fkey" FOREIGN KEY ("score_category") REFERENCES "public"."match_stat_categories"("id");



ALTER TABLE ONLY "public"."match_stats_details"
    ADD CONSTRAINT "match_scores_details_match_scores_id_fkey" FOREIGN KEY ("match_stats_id") REFERENCES "public"."match_stats"("id");



ALTER TABLE ONLY "public"."match_stats_details"
    ADD CONSTRAINT "match_scores_details_score_type_fkey" FOREIGN KEY ("score_type") REFERENCES "public"."match_stat_types"("id");



ALTER TABLE ONLY "public"."match_stats"
    ADD CONSTRAINT "match_scores_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("event_id");



ALTER TABLE ONLY "public"."match_stats"
    ADD CONSTRAINT "match_scores_squad_id_fkey" FOREIGN KEY ("squad_id") REFERENCES "public"."squads"("squad_id");



ALTER TABLE ONLY "public"."match_stats"
    ADD CONSTRAINT "match_scores_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("user_id");



ALTER TABLE ONLY "public"."match_squad_details"
    ADD CONSTRAINT "match_squad_details_match_squad_id_fkey" FOREIGN KEY ("match_squad_id") REFERENCES "public"."match_squads"("match_squad_id");



ALTER TABLE ONLY "public"."match_squad_details"
    ADD CONSTRAINT "match_squad_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("event_id");



ALTER TABLE ONLY "public"."match_squad_details"
    ADD CONSTRAINT "match_squad_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "public"."members"("member_id");



ALTER TABLE ONLY "public"."match_squad_details"
    ADD CONSTRAINT "match_squad_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "public"."roles"("role_id");



ALTER TABLE ONLY "public"."match_squad_details"
    ADD CONSTRAINT "match_squad_squad_id_fkey" FOREIGN KEY ("squad_id") REFERENCES "public"."squads"("squad_id");



ALTER TABLE ONLY "public"."match_squad_details"
    ADD CONSTRAINT "match_squad_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("team_id");



ALTER TABLE ONLY "public"."match_squad_details"
    ADD CONSTRAINT "match_squad_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("user_id");



ALTER TABLE ONLY "public"."match_timer"
    ADD CONSTRAINT "match_timer_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("event_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."match_timer"
    ADD CONSTRAINT "match_timer_squad_id_fkey" FOREIGN KEY ("squad_id") REFERENCES "public"."squads"("squad_id");



ALTER TABLE ONLY "public"."match_timer"
    ADD CONSTRAINT "match_timer_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."member_squad_link"
    ADD CONSTRAINT "member_squad_link_code_id_fkey" FOREIGN KEY ("code_id") REFERENCES "public"."event_codes"("code_id");



ALTER TABLE ONLY "public"."member_squad_link"
    ADD CONSTRAINT "member_squad_link_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "public"."members"("member_id");



ALTER TABLE ONLY "public"."member_squad_link"
    ADD CONSTRAINT "member_squad_link_squad_id_fkey" FOREIGN KEY ("squad_id") REFERENCES "public"."squads"("squad_id");



ALTER TABLE ONLY "public"."member_squad_link"
    ADD CONSTRAINT "member_squad_link_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("team_id");



ALTER TABLE ONLY "public"."member_team_link"
    ADD CONSTRAINT "member_team_link_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "public"."members"("member_id");



ALTER TABLE ONLY "public"."member_team_link"
    ADD CONSTRAINT "member_team_link_squad_id_fkey" FOREIGN KEY ("squad_id") REFERENCES "public"."squads"("squad_id");



ALTER TABLE ONLY "public"."member_team_link"
    ADD CONSTRAINT "member_team_link_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("team_id");



ALTER TABLE ONLY "public"."member_team_role_link"
    ADD CONSTRAINT "member_team_role_link_member_team_id_fkey" FOREIGN KEY ("member_team_id") REFERENCES "public"."member_team_link"("member_team_id");



ALTER TABLE ONLY "public"."member_team_role_link"
    ADD CONSTRAINT "member_team_role_link_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "public"."roles"("role_id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_recipient_user_id_fkey" FOREIGN KEY ("recipient_user_id") REFERENCES "public"."users"("user_id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("team_id");



ALTER TABLE ONLY "public"."reminders"
    ADD CONSTRAINT "reminders_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("event_id");



ALTER TABLE ONLY "public"."reminders"
    ADD CONSTRAINT "reminders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("user_id");



ALTER TABLE ONLY "public"."squads"
    ADD CONSTRAINT "squad_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("team_id");



ALTER TABLE ONLY "public"."members"
    ADD CONSTRAINT "team_member_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("user_id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."team_roles_link"
    ADD CONSTRAINT "team_role_link_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "public"."roles"("role_id");



ALTER TABLE ONLY "public"."team_roles_link"
    ADD CONSTRAINT "team_role_link_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("team_id");



ALTER TABLE ONLY "public"."teams"
    ADD CONSTRAINT "teams_club_id_fkey" FOREIGN KEY ("club_id") REFERENCES "public"."clubs"("club_id");



ALTER TABLE ONLY "public"."user_game_link"
    ADD CONSTRAINT "user_game_link_game_id_fkey" FOREIGN KEY ("game_id") REFERENCES "public"."games"("game_id");



ALTER TABLE ONLY "public"."user_game_link"
    ADD CONSTRAINT "user_game_link_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("user_id");



ALTER TABLE ONLY "public"."user_member_link"
    ADD CONSTRAINT "user_member_link_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "public"."members"("member_id");



ALTER TABLE ONLY "public"."user_member_link"
    ADD CONSTRAINT "user_member_link_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("user_id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_default_club_fkey" FOREIGN KEY ("default_club") REFERENCES "public"."clubs"("club_id");



CREATE POLICY "Authenticated users can manage their own match_squads." ON "public"."match_squad_details" TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Authenticated users can manage their own match_squads." ON "public"."match_squads" TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Authenticated users can manage their own reminders." ON "public"."reminders" TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Authenticated users can read event attendance." ON "public"."event_attendance" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Drivers can modify their own car pools" ON "public"."car_pool" TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can add their members to a car pool" ON "public"."car_pool_detail" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."members" "m"
  WHERE (("m"."member_id" = "car_pool_detail"."member_id") AND ("m"."user_id" = "auth"."uid"())))));



CREATE POLICY "Users can create their own car pools" ON "public"."car_pool" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can remove their members from a car pool" ON "public"."car_pool_detail" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."members" "m"
  WHERE (("m"."member_id" = "car_pool_detail"."member_id") AND ("m"."user_id" = "auth"."uid"())))));



CREATE POLICY "Users can view all car pool details" ON "public"."car_pool_detail" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Users can view all car pools" ON "public"."car_pool" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Users manage own timers" ON "public"."match_timer" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "authenticated_insert_lineup" ON "public"."lineup" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "authenticated_insert_lineup_details" ON "public"."lineup_details" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "authenticated_read_lineup" ON "public"."lineup" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "authenticated_read_lineup_details" ON "public"."lineup_details" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "authenticated_users_can_delete" ON "public"."clubs" FOR DELETE TO "authenticated" USING ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_delete" ON "public"."event_attendance" FOR DELETE TO "authenticated" USING ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_delete" ON "public"."event_codes" FOR DELETE TO "authenticated" USING ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_delete" ON "public"."event_response_type" FOR DELETE TO "authenticated" USING ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_delete" ON "public"."event_types" FOR DELETE TO "authenticated" USING ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_delete" ON "public"."events" FOR DELETE TO "authenticated" USING ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_delete" ON "public"."game_ages" FOR DELETE TO "authenticated" USING ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_delete" ON "public"."games" FOR DELETE TO "authenticated" USING ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_delete" ON "public"."invitations" FOR DELETE TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "authenticated_users_can_delete" ON "public"."member_team_link" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."members" "m"
  WHERE (("m"."member_id" = "member_team_link"."member_id") AND ("m"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "authenticated_users_can_delete" ON "public"."member_team_role_link" FOR DELETE TO "authenticated" USING ("public"."is_owner_of_member_team_role"("member_team_role_id"));



CREATE POLICY "authenticated_users_can_delete" ON "public"."members" FOR DELETE TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "authenticated_users_can_delete" ON "public"."notifications" FOR DELETE TO "authenticated" USING (("recipient_user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "authenticated_users_can_delete" ON "public"."roles" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "authenticated_users_can_delete" ON "public"."sport" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "authenticated_users_can_delete" ON "public"."squads" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "authenticated_users_can_delete" ON "public"."team_roles_link" FOR DELETE USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "authenticated_users_can_delete" ON "public"."teams" FOR DELETE USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "authenticated_users_can_delete" ON "public"."user_member_link" FOR DELETE USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "authenticated_users_can_delete" ON "public"."users" FOR DELETE USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "authenticated_users_can_insert" ON "public"."clubs" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_insert" ON "public"."event_attendance" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_insert" ON "public"."event_codes" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_insert" ON "public"."event_response_type" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_insert" ON "public"."event_types" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_insert" ON "public"."events" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_insert" ON "public"."game_ages" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_insert" ON "public"."games" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_insert" ON "public"."invitations" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "authenticated_users_can_insert" ON "public"."member_team_link" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."members" "m"
  WHERE (("m"."member_id" = "member_team_link"."member_id") AND ("m"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "authenticated_users_can_insert" ON "public"."member_team_role_link" FOR INSERT TO "authenticated" WITH CHECK ("public"."is_owner_of_member_team_role"("member_team_role_id"));



CREATE POLICY "authenticated_users_can_insert" ON "public"."members" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "authenticated_users_can_insert" ON "public"."notifications" FOR INSERT TO "authenticated" WITH CHECK (("recipient_user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "authenticated_users_can_insert" ON "public"."roles" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "authenticated_users_can_insert" ON "public"."sport" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "authenticated_users_can_insert" ON "public"."squads" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "authenticated_users_can_insert" ON "public"."team_roles_link" FOR INSERT WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "authenticated_users_can_insert" ON "public"."teams" FOR INSERT WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "authenticated_users_can_insert" ON "public"."user_member_link" FOR INSERT WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "authenticated_users_can_insert" ON "public"."users" FOR INSERT WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "authenticated_users_can_read" ON "public"."clubs" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_read" ON "public"."event_codes" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_read" ON "public"."event_response_type" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_read" ON "public"."event_types" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_read" ON "public"."events" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_read" ON "public"."game_ages" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_read" ON "public"."games" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_read" ON "public"."invitations" FOR SELECT TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "authenticated_users_can_read" ON "public"."member_team_link" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."members" "m"
  WHERE (("m"."member_id" = "member_team_link"."member_id") AND ("m"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "authenticated_users_can_read" ON "public"."member_team_role_link" FOR SELECT TO "authenticated" USING ("public"."is_owner_of_member_team_role"("member_team_role_id"));



CREATE POLICY "authenticated_users_can_read" ON "public"."members" FOR SELECT TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "authenticated_users_can_read" ON "public"."notifications" FOR SELECT TO "authenticated" USING (("recipient_user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "authenticated_users_can_read" ON "public"."roles" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "authenticated_users_can_read" ON "public"."sport" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "authenticated_users_can_read" ON "public"."squads" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "authenticated_users_can_read" ON "public"."team_roles_link" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "authenticated_users_can_read" ON "public"."teams" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "authenticated_users_can_read" ON "public"."user_member_link" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "authenticated_users_can_read" ON "public"."users" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "authenticated_users_can_update" ON "public"."clubs" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text")) WITH CHECK ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_update" ON "public"."event_attendance" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text")) WITH CHECK ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_update" ON "public"."event_codes" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text")) WITH CHECK ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_update" ON "public"."event_response_type" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text")) WITH CHECK ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_update" ON "public"."event_types" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text")) WITH CHECK ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_update" ON "public"."events" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text")) WITH CHECK ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_update" ON "public"."game_ages" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text")) WITH CHECK ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_update" ON "public"."games" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text")) WITH CHECK ((( SELECT "auth"."role"() AS "role") = 'authenticated'::"text"));



CREATE POLICY "authenticated_users_can_update" ON "public"."invitations" FOR UPDATE TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "authenticated_users_can_update" ON "public"."member_team_link" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."members" "m"
  WHERE (("m"."member_id" = "member_team_link"."member_id") AND ("m"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "authenticated_users_can_update" ON "public"."member_team_role_link" FOR UPDATE TO "authenticated" USING ("public"."is_owner_of_member_team_role"("member_team_role_id"));



CREATE POLICY "authenticated_users_can_update" ON "public"."members" FOR UPDATE TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "authenticated_users_can_update" ON "public"."notifications" FOR UPDATE TO "authenticated" USING (("recipient_user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "authenticated_users_can_update" ON "public"."roles" FOR UPDATE TO "authenticated" USING (true);



CREATE POLICY "authenticated_users_can_update" ON "public"."sport" FOR UPDATE TO "authenticated" USING (true);



CREATE POLICY "authenticated_users_can_update" ON "public"."squads" FOR UPDATE TO "authenticated" USING (true);



CREATE POLICY "authenticated_users_can_update" ON "public"."team_roles_link" FOR UPDATE USING (("auth"."uid"() IS NOT NULL)) WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "authenticated_users_can_update" ON "public"."teams" FOR UPDATE USING (("auth"."uid"() IS NOT NULL)) WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "authenticated_users_can_update" ON "public"."user_member_link" FOR UPDATE USING (("auth"."uid"() IS NOT NULL)) WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "authenticated_users_can_update" ON "public"."users" FOR UPDATE USING (("auth"."uid"() IS NOT NULL)) WITH CHECK (("auth"."uid"() IS NOT NULL));



ALTER TABLE "public"."car_pool" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."car_pool_detail" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."club_code_link" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."lineup" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."lineup_details" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."match_stat_categories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."match_stat_type_team_link" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."match_timer" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";






ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."event_attendance";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."notifications";









GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";
















































































































































































































































GRANT ALL ON FUNCTION "public"."check_and_send_notifications"() TO "anon";
GRANT ALL ON FUNCTION "public"."check_and_send_notifications"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_and_send_notifications"() TO "service_role";



GRANT ALL ON FUNCTION "public"."create_match_squad_from_attendance"("p_event_id" bigint, "p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."create_match_squad_from_attendance"("p_event_id" bigint, "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_match_squad_from_attendance"("p_event_id" bigint, "p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_new_member_by_code"("p_first_name" "text", "p_last_name" "text", "p_joining_code" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_new_member_by_code"("p_first_name" "text", "p_last_name" "text", "p_joining_code" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_new_member_by_code"("p_first_name" "text", "p_last_name" "text", "p_joining_code" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_unique_member_code"() TO "anon";
GRANT ALL ON FUNCTION "public"."generate_unique_member_code"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_unique_member_code"() TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_unique_team_code"() TO "anon";
GRANT ALL ON FUNCTION "public"."generate_unique_team_code"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_unique_team_code"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_accepted_unpaid_members"("p_event_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."get_accepted_unpaid_members"("p_event_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_accepted_unpaid_members"("p_event_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_club_comparison_dashboard"("p_club_id" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."get_club_comparison_dashboard"("p_club_id" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_club_comparison_dashboard"("p_club_id" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_event_admin_detail"("p_event_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."get_event_admin_detail"("p_event_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_event_admin_detail"("p_event_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_event_attendance_by_role"("p_event_id" bigint, "p_role_grade_filter" smallint, "p_role_level_filter" smallint, "p_role_level_exclude" smallint, "p_response_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."get_event_attendance_by_role"("p_event_id" bigint, "p_role_grade_filter" smallint, "p_role_level_filter" smallint, "p_role_level_exclude" smallint, "p_response_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_event_attendance_by_role"("p_event_id" bigint, "p_role_grade_filter" smallint, "p_role_level_filter" smallint, "p_role_level_exclude" smallint, "p_response_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_event_attendance_by_role_v2"("p_event_id" bigint, "p_role_grade_filter" smallint, "p_role_level_filter" smallint, "p_role_level_exclude" smallint, "p_response_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."get_event_attendance_by_role_v2"("p_event_id" bigint, "p_role_grade_filter" smallint, "p_role_level_filter" smallint, "p_role_level_exclude" smallint, "p_response_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_event_attendance_by_role_v2"("p_event_id" bigint, "p_role_grade_filter" smallint, "p_role_level_filter" smallint, "p_role_level_exclude" smallint, "p_response_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_event_attendance_details"("p_event_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."get_event_attendance_details"("p_event_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_event_attendance_details"("p_event_id" bigint) TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."event_attendance" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."event_attendance" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."event_attendance" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."event_response_type" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."event_response_type" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."event_response_type" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."events" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."events" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."events" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."member_team_link" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."member_team_link" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."member_team_link" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."member_team_role_link" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."member_team_role_link" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."member_team_role_link" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."members" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."members" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."members" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."roles" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."roles" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."roles" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."squads" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."squads" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."squads" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."teams" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."teams" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."teams" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."user_member_link" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."user_member_link" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."user_member_link" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."users" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."users" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."users" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_event_attendance_details" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_event_attendance_details" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_event_attendance_details" TO "service_role";



GRANT ALL ON FUNCTION "public"."get_event_attendance_details"("p_user_id" "uuid", "p_event_id" bigint, "p_role_level" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_event_attendance_details"("p_user_id" "uuid", "p_event_id" bigint, "p_role_level" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_event_attendance_details"("p_user_id" "uuid", "p_event_id" bigint, "p_role_level" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_event_attendance_summary"("p_event_id" integer, "p_role_level" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_event_attendance_summary"("p_event_id" integer, "p_role_level" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_event_attendance_summary"("p_event_id" integer, "p_role_level" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_event_attendance_summary_by_role"("p_event_id" bigint, "p_role_grade_filter" smallint, "p_role_level_filter" smallint, "p_role_level_exclude" smallint) TO "anon";
GRANT ALL ON FUNCTION "public"."get_event_attendance_summary_by_role"("p_event_id" bigint, "p_role_grade_filter" smallint, "p_role_level_filter" smallint, "p_role_level_exclude" smallint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_event_attendance_summary_by_role"("p_event_id" bigint, "p_role_grade_filter" smallint, "p_role_level_filter" smallint, "p_role_level_exclude" smallint) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_event_attendance_summary_by_role_and_squad"("p_event_id" bigint, "p_role_grade_filter" smallint, "p_role_level_filter" smallint, "p_role_level_exclude" smallint, "p_response_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."get_event_attendance_summary_by_role_and_squad"("p_event_id" bigint, "p_role_grade_filter" smallint, "p_role_level_filter" smallint, "p_role_level_exclude" smallint, "p_response_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_event_attendance_summary_by_role_and_squad"("p_event_id" bigint, "p_role_grade_filter" smallint, "p_role_level_filter" smallint, "p_role_level_exclude" smallint, "p_response_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_event_attendance_summary_by_role_and_squad_v2"("p_event_id" bigint, "p_role_grade_filter" smallint, "p_role_level_filter" smallint, "p_role_level_exclude" smallint, "p_response_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."get_event_attendance_summary_by_role_and_squad_v2"("p_event_id" bigint, "p_role_grade_filter" smallint, "p_role_level_filter" smallint, "p_role_level_exclude" smallint, "p_response_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_event_attendance_summary_by_role_and_squad_v2"("p_event_id" bigint, "p_role_grade_filter" smallint, "p_role_level_filter" smallint, "p_role_level_exclude" smallint, "p_response_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_event_car_pools"("p_event_id" bigint, "p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_event_car_pools"("p_event_id" bigint, "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_event_car_pools"("p_event_id" bigint, "p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_event_context_and_next_code"("p_event_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."get_event_context_and_next_code"("p_event_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_event_context_and_next_code"("p_event_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_event_payment_details_v2"("p_event_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."get_event_payment_details_v2"("p_event_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_event_payment_details_v2"("p_event_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_event_payment_summary"("p_event_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."get_event_payment_summary"("p_event_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_event_payment_summary"("p_event_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_event_payments_details"("p_event_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."get_event_payments_details"("p_event_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_event_payments_details"("p_event_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_event_team_members_for_user"("p_event_id" bigint, "p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_event_team_members_for_user"("p_event_id" bigint, "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_event_team_members_for_user"("p_event_id" bigint, "p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_event_team_members_with_attendance"("p_event_id" bigint, "p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_event_team_members_with_attendance"("p_event_id" bigint, "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_event_team_members_with_attendance"("p_event_id" bigint, "p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_events_list"("p_date_from" "text", "p_date_to" "text", "p_team_id" bigint, "p_code_id" bigint, "p_type_id" bigint, "p_opposition" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_events_list"("p_date_from" "text", "p_date_to" "text", "p_team_id" bigint, "p_code_id" bigint, "p_type_id" bigint, "p_opposition" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_events_list"("p_date_from" "text", "p_date_to" "text", "p_team_id" bigint, "p_code_id" bigint, "p_type_id" bigint, "p_opposition" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_full_car_pool_details"("p_car_pool_id" bigint, "p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_full_car_pool_details"("p_car_pool_id" bigint, "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_full_car_pool_details"("p_car_pool_id" bigint, "p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_member_match_stats"("p_team_name" "text", "p_event_code" "text", "p_event_type" "text", "p_from_date" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_member_match_stats"("p_team_name" "text", "p_event_code" "text", "p_event_type" "text", "p_from_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_member_match_stats"("p_team_name" "text", "p_event_code" "text", "p_event_type" "text", "p_from_date" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_member_match_stats_detail"("p_team_name" "text", "p_event_code" "text", "p_event_type" "text", "p_from_date" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_member_match_stats_detail"("p_team_name" "text", "p_event_code" "text", "p_event_type" "text", "p_from_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_member_match_stats_detail"("p_team_name" "text", "p_event_code" "text", "p_event_type" "text", "p_from_date" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_member_team_details"("p_member_id" bigint, "p_team_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."get_member_team_details"("p_member_id" bigint, "p_team_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_member_team_details"("p_member_id" bigint, "p_team_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_members_attendance_latest"("p_event_id" bigint, "p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_members_attendance_latest"("p_event_id" bigint, "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_members_attendance_latest"("p_event_id" bigint, "p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_player_squad_events_v2"("p_member_id" integer, "p_club_id" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_team_ids" integer[], "p_codes" "text"[], "p_types" "text"[], "p_att_min" integer, "p_att_max" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_player_squad_events_v2"("p_member_id" integer, "p_club_id" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_team_ids" integer[], "p_codes" "text"[], "p_types" "text"[], "p_att_min" integer, "p_att_max" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_player_squad_events_v2"("p_member_id" integer, "p_club_id" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_team_ids" integer[], "p_codes" "text"[], "p_types" "text"[], "p_att_min" integer, "p_att_max" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_single_user_event"("p_user_id" "uuid", "p_event_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."get_single_user_event"("p_user_id" "uuid", "p_event_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_single_user_event"("p_user_id" "uuid", "p_event_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_squad_dashboard"("p_club_id" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_codes" "text"[], "p_types" "text"[], "p_att_min" integer, "p_att_max" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_squad_dashboard"("p_club_id" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_codes" "text"[], "p_types" "text"[], "p_att_min" integer, "p_att_max" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_squad_dashboard"("p_club_id" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_codes" "text"[], "p_types" "text"[], "p_att_min" integer, "p_att_max" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_squad_dashboard_v2"("p_club_id" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_team_ids" integer[], "p_codes" "text"[], "p_types" "text"[], "p_att_min" integer, "p_att_max" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_squad_dashboard_v2"("p_club_id" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_team_ids" integer[], "p_codes" "text"[], "p_types" "text"[], "p_att_min" integer, "p_att_max" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_squad_dashboard_v2"("p_club_id" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_team_ids" integer[], "p_codes" "text"[], "p_types" "text"[], "p_att_min" integer, "p_att_max" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_team_attendance_dashboard"("p_team_id" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."get_team_attendance_dashboard"("p_team_id" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_team_attendance_dashboard"("p_team_id" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_team_event_dashboard"("p_team_id" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."get_team_event_dashboard"("p_team_id" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_team_event_dashboard"("p_team_id" integer, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_team_members_by_role"("p_user_id" "uuid", "p_team_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."get_team_members_by_role"("p_user_id" "uuid", "p_team_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_team_members_by_role"("p_user_id" "uuid", "p_team_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_unresponded_events"("event_id_param" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."get_unresponded_events"("event_id_param" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_unresponded_events"("event_id_param" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_unresponded_events_v2"("event_id_param" bigint, "p_role_grade" smallint, "p_role_level" smallint) TO "anon";
GRANT ALL ON FUNCTION "public"."get_unresponded_events_v2"("event_id_param" bigint, "p_role_grade" smallint, "p_role_level" smallint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_unresponded_events_v2"("event_id_param" bigint, "p_role_grade" smallint, "p_role_level" smallint) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_updated_event_code"("p_event_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."get_updated_event_code"("p_event_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_updated_event_code"("p_event_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_clubs"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_clubs"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_clubs"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_clubs"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_clubs"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_clubs"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_event_create_detail"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_event_create_detail"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_event_create_detail"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_event_details"("p_event_id" bigint, "p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_event_details"("p_event_id" bigint, "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_event_details"("p_event_id" bigint, "p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_event_edit_detail"("p_user_id" "uuid", "p_event_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_event_edit_detail"("p_user_id" "uuid", "p_event_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_event_edit_detail"("p_user_id" "uuid", "p_event_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_event_members_with_attendance"("p_event_id" bigint, "p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_event_members_with_attendance"("p_event_id" bigint, "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_event_members_with_attendance"("p_event_id" bigint, "p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_event_team_members"("p_event_id" bigint, "p_user_id" "uuid", "p_role_grade" "text", "p_role_level" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_event_team_members"("p_event_id" bigint, "p_user_id" "uuid", "p_role_grade" "text", "p_role_level" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_event_team_members"("p_event_id" bigint, "p_user_id" "uuid", "p_role_grade" "text", "p_role_level" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_events"("user_id_param" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_events"("user_id_param" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_events"("user_id_param" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_favourites"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_favourites"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_favourites"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_home_events"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_home_events"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_home_events"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_members_event_attendance"("p_event_id" bigint, "p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_members_event_attendance"("p_event_id" bigint, "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_members_event_attendance"("p_event_id" bigint, "p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_notifications"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_notifications"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_notifications"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_team_summary"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_team_summary"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_team_summary"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_owner_of_member_team_role"("role_link_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."is_owner_of_member_team_role"("role_link_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_owner_of_member_team_role"("role_link_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."migrate_legacy_user_on_signup"() TO "anon";
GRANT ALL ON FUNCTION "public"."migrate_legacy_user_on_signup"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."migrate_legacy_user_on_signup"() TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_admins_attendance_change"("p_event_id_param" integer, "p_member_id_param" integer, "p_response_id" integer, "p_attendance_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."notify_admins_attendance_change"("p_event_id_param" integer, "p_member_id_param" integer, "p_response_id" integer, "p_attendance_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_admins_attendance_change"("p_event_id_param" integer, "p_member_id_param" integer, "p_response_id" integer, "p_attendance_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."populate_event_notifications"("p_event_id_param" integer, "p_role_grade" integer, "p_role_level" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."populate_event_notifications"("p_event_id_param" integer, "p_role_grade" integer, "p_role_level" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."populate_event_notifications"("p_event_id_param" integer, "p_role_grade" integer, "p_role_level" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."remove_member_from_team"("p_member_id" bigint, "p_team_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."remove_member_from_team"("p_member_id" bigint, "p_team_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."remove_member_from_team"("p_member_id" bigint, "p_team_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_match_timer_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_match_timer_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_match_timer_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_member_code"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_member_code"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_member_code"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_team_code_on_insert"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_team_code_on_insert"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_team_code_on_insert"() TO "service_role";




































GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."car_pool" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."car_pool" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."car_pool" TO "service_role";



GRANT ALL ON SEQUENCE "public"."car_pool_car_pool_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."car_pool_car_pool_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."car_pool_car_pool_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."car_pool_detail" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."car_pool_detail" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."car_pool_detail" TO "service_role";



GRANT ALL ON SEQUENCE "public"."car_pool_detail_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."car_pool_detail_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."car_pool_detail_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."club_code_link" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."club_code_link" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."club_code_link" TO "service_role";



GRANT ALL ON SEQUENCE "public"."club_code_link_club_code_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."club_code_link_club_code_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."club_code_link_club_code_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."clubs" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."clubs" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."clubs" TO "service_role";



GRANT ALL ON SEQUENCE "public"."clubs_club_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."clubs_club_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."clubs_club_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."event_attendance_attendance_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."event_attendance_attendance_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."event_attendance_attendance_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."event_codes" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."event_codes" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."event_codes" TO "service_role";



GRANT ALL ON SEQUENCE "public"."event_codes_code_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."event_codes_code_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."event_codes_code_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."event_responses_response_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."event_responses_response_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."event_responses_response_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."event_types" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."event_types" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."event_types" TO "service_role";



GRANT ALL ON SEQUENCE "public"."event_types_event_type_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."event_types_event_type_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."event_types_event_type_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."event_user_member_payment" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."event_user_member_payment" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."event_user_member_payment" TO "service_role";



GRANT ALL ON SEQUENCE "public"."event_user_member_payment_payment_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."event_user_member_payment_payment_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."event_user_member_payment_payment_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."event_user_payment" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."event_user_payment" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."event_user_payment" TO "service_role";



GRANT ALL ON SEQUENCE "public"."event_user_payment_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."event_user_payment_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."event_user_payment_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."events_event_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."events_event_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."events_event_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."game_ages" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."game_ages" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."game_ages" TO "service_role";



GRANT ALL ON SEQUENCE "public"."game_ages_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."game_ages_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."game_ages_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."games" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."games" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."games" TO "service_role";



GRANT ALL ON SEQUENCE "public"."games_game_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."games_game_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."games_game_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."invitations" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."invitations" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."invitations" TO "service_role";



GRANT ALL ON SEQUENCE "public"."invitations_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."invitations_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."invitations_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."legacy_users" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."legacy_users" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."legacy_users" TO "service_role";



GRANT ALL ON SEQUENCE "public"."legacy_users_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."legacy_users_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."legacy_users_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."lineup" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."lineup" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."lineup" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."lineup_details" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."lineup_details" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."lineup_details" TO "service_role";



GRANT ALL ON SEQUENCE "public"."lineup_details_lineup_detail_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."lineup_details_lineup_detail_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."lineup_details_lineup_detail_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."lineup_lineup_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."lineup_lineup_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."lineup_lineup_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."match_squads" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."match_squads" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."match_squads" TO "service_role";



GRANT ALL ON SEQUENCE "public"."match _squads_match_squad_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."match _squads_match_squad_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."match _squads_match_squad_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."match_reports" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."match_reports" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."match_reports" TO "service_role";



GRANT ALL ON SEQUENCE "public"."match_reports_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."match_reports_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."match_reports_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."match_stat_categories" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."match_stat_categories" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."match_stat_categories" TO "service_role";



GRANT ALL ON SEQUENCE "public"."match_score_catregories_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."match_score_catregories_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."match_score_catregories_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."match_stat_type_team_link" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."match_stat_type_team_link" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."match_stat_type_team_link" TO "service_role";



GRANT ALL ON SEQUENCE "public"."match_score_type_team_link_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."match_score_type_team_link_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."match_score_type_team_link_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."match_stat_types" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."match_stat_types" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."match_stat_types" TO "service_role";



GRANT ALL ON SEQUENCE "public"."match_score_types_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."match_score_types_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."match_score_types_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."match_stats_details" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."match_stats_details" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."match_stats_details" TO "service_role";



GRANT ALL ON SEQUENCE "public"."match_scores_details_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."match_scores_details_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."match_scores_details_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."match_stats" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."match_stats" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."match_stats" TO "service_role";



GRANT ALL ON SEQUENCE "public"."match_scores_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."match_scores_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."match_scores_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."match_squad_details" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."match_squad_details" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."match_squad_details" TO "service_role";



GRANT ALL ON SEQUENCE "public"."match_squad_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."match_squad_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."match_squad_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."match_timer" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."match_timer" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."match_timer" TO "service_role";



GRANT ALL ON SEQUENCE "public"."match_timer_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."match_timer_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."match_timer_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."member_squad_link" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."member_squad_link" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."member_squad_link" TO "service_role";



GRANT ALL ON SEQUENCE "public"."member_squad_link_member_squad_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."member_squad_link_member_squad_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."member_squad_link_member_squad_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."member_team_link_member_team_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."member_team_link_member_team_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."member_team_link_member_team_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."member_team_role_link_member_team_role_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."member_team_role_link_member_team_role_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."member_team_role_link_member_team_role_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."notifications" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."notifications" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."notifications" TO "service_role";



GRANT ALL ON SEQUENCE "public"."notifications_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."notifications_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."notifications_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."reminders" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."reminders" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."reminders" TO "service_role";



GRANT ALL ON SEQUENCE "public"."reminders_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."reminders_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."reminders_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."roles_role_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."roles_role_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."roles_role_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."sport" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."sport" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."sport" TO "service_role";



GRANT ALL ON SEQUENCE "public"."sport_sport_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."sport_sport_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."sport_sport_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."squad_squad_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."squad_squad_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."squad_squad_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."team_member_member_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."team_member_member_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."team_member_member_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."team_roles_link" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."team_roles_link" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."team_roles_link" TO "service_role";



GRANT ALL ON SEQUENCE "public"."team_role_link_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."team_role_link_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."team_role_link_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."teams_team_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."teams_team_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."teams_team_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."user_game_link" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."user_game_link" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."user_game_link" TO "service_role";



GRANT ALL ON SEQUENCE "public"."user_game_link_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."user_game_link_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."user_game_link_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."user_member_link_user_member_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."user_member_link_user_member_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."user_member_link_user_member_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_attendee_details" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_attendee_details" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_attendee_details" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_event_attendance_summary" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_event_attendance_summary" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_event_attendance_summary" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_event_reminders" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_event_reminders" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_event_reminders" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_event_squad_summary" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_event_squad_summary" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_event_squad_summary" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_homepage_listview" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_homepage_listview" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_homepage_listview" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_latest_member_event_attendance" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_latest_member_event_attendance" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_latest_member_event_attendance" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_match_reports" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_match_reports" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_match_reports" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_match_squads" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_match_squads" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_match_squads" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_member_event_count" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_member_event_count" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_member_event_count" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_member_response_list" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_member_response_list" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_member_response_list" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_members_no_response" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_members_no_response" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_members_no_response" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_team_details" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_team_details" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_team_details" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_team_members" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_team_members" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_team_members" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_team_roles" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_team_roles" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_team_roles" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_test_data" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_test_data" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_test_data" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_unique_user_team_members" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_unique_user_team_members" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_unique_user_team_members" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_unique_user_teams" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_unique_user_teams" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_unique_user_teams" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_clubs" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_clubs" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_clubs" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_highest_role" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_highest_role" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_highest_role" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_member_team_events" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_member_team_events" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_member_team_events" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_members" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_members" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_members" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_members_new" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_members_new" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_members_new" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_team_highest_role" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_team_highest_role" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_team_highest_role" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_team_member_squad" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_team_member_squad" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_team_member_squad" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_team_members" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_team_members" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_team_members" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_teams" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_teams" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_teams" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_teams_grade" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_teams_grade" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_teams_grade" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_unique_member_team_events" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_unique_member_team_events" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_unique_member_team_events" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO "service_role";































