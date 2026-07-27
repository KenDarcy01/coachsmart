-- Emergency restore: 6 views dropped in 20260727000001 are still actively
-- queried by FlutterFlow pages and must be recreated.
--
-- Pages affected:
--   view_team_details      → join_team_widget.dart
--   view_user_team_members → join_team_widget.dart
--   view_user_members      → edit_user_widget.dart
--   view_user_members_new  → user_member_details_widget.dart
--   view_team_members      → select_teams_widget.dart
--   view_match_reports     → match_report_widget.dart

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

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_match_reports" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_match_reports" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_match_reports" TO "service_role";


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

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_team_details" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_team_details" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_team_details" TO "service_role";


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

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_team_members" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_team_members" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_team_members" TO "service_role";


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

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_members" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_members" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_members" TO "service_role";


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

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_members_new" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_members_new" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_members_new" TO "service_role";


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

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_team_members" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_team_members" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."view_user_team_members" TO "service_role";
