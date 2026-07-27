-- The published PWA queries view_user_team_highest_role to determine which
-- teams a user is an admin of (filter: highest_role_level >= 100) when
-- populating the Create Event team dropdown. This view was dropped from
-- production but is defined in schema_current.sql. Recreate it.

CREATE OR REPLACE VIEW public.view_user_team_highest_role
WITH (security_invoker = true)
AS
WITH user_team_member_roles_data AS (
    SELECT
        u.user_id,
        u.first_name  AS user_first_name,
        u.last_name   AS user_last_name,
        u.email_address,
        u.phone_number,
        m.member_id,
        m.first_name  AS member_first_name,
        m.last_name   AS member_last_name,
        t.team_id,
        t.team_name,
        t.team_unique_code,
        lower(t.team_unique_code) AS lower_case_team_code,
        r.role_id,
        r.role_name,
        r.role_level,
        r.role_grade,
        r.role_name_plural
    FROM public.users u
    JOIN public.user_member_link  uml  ON u.user_id        = uml.user_id
    JOIN public.members           m    ON uml.member_id     = m.member_id
    JOIN public.member_team_link  mtl  ON m.member_id       = mtl.member_id
    JOIN public.teams             t    ON mtl.team_id        = t.team_id
    JOIN public.member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id
    JOIN public.roles             r    ON mtrl.role_id       = r.role_id
),
ranked_roles_per_user_team AS (
    SELECT
        user_id, user_first_name, user_last_name, email_address, phone_number,
        member_id, member_first_name, member_last_name,
        team_id, team_name, team_unique_code, lower_case_team_code,
        role_id, role_name, role_level, role_grade, role_name_plural,
        row_number() OVER (
            PARTITION BY user_id, team_id
            ORDER BY role_level DESC, role_grade DESC, role_id
        ) AS rn
    FROM user_team_member_roles_data
)
SELECT
    user_id,
    concat(user_first_name, ' ', user_last_name) AS user_full_name,
    email_address,
    phone_number,
    team_id,
    team_name,
    team_unique_code,
    lower_case_team_code,
    role_id,
    role_name        AS highest_role_name,
    role_level       AS highest_role_level,
    role_grade       AS highest_role_grade,
    role_name_plural AS highest_role_name_plural
FROM ranked_roles_per_user_team
WHERE rn = 1
ORDER BY user_id, team_id;

ALTER VIEW public.view_user_team_highest_role OWNER TO postgres;

GRANT SELECT ON public.view_user_team_highest_role TO anon;
GRANT SELECT ON public.view_user_team_highest_role TO authenticated;
GRANT SELECT ON public.view_user_team_highest_role TO service_role;
