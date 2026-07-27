-- Enable RLS on 15 tables whose existing policies are already permissive
-- (any authenticated user can read/write). This stops unauthenticated
-- PostgREST access without affecting any app functionality.
--
-- Not included here (Group 2): members, match_squads, match_squad_details,
-- member_team_link, member_team_role_link, invitations, reminders —
-- those have restrictive SELECT policies that need fixing first.

ALTER TABLE "public"."clubs"                ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."event_attendance"     ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."event_codes"          ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."event_response_type"  ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."event_types"          ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."events"               ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."game_ages"            ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."games"               ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."roles"               ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."sport"               ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."squads"              ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."team_roles_link"     ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."teams"               ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."user_member_link"    ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."users"               ENABLE ROW LEVEL SECURITY;
