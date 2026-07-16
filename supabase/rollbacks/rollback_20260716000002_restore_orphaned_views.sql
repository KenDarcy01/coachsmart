-- Rollback: restore 14 dropped orphaned views
-- Source: supabase/schema_current.sql (schema dump before migration 20260716000002)

-- view_homepage_listview
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

-- view_latest_member_event_attendance
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

-- view_member_event_count
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

-- view_member_response_list
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

-- view_members_no_response
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

-- view_test_data
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

-- view_unique_user_team_members
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

-- view_unique_user_teams
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

-- view_user_clubs
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

-- view_user_highest_role
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

-- view_user_member_team_events
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

-- view_user_team_member_squad
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

-- view_user_teams
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

-- view_user_teams_grade
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
