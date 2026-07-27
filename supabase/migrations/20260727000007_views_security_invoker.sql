-- Recreate the 6 active views with security_invoker = true.
-- By default views run as the view owner (postgres superuser) which bypasses
-- RLS. security_invoker makes them run as the querying user so RLS on the
-- underlying tables is enforced correctly.

CREATE OR REPLACE VIEW public.view_match_reports
WITH (security_invoker = true)
AS
SELECT u.user_id,
    concat(u.first_name, ' ', u.last_name) AS report_author,
    mr.created_at,
    e.event_id,
    e.event_title,
    e.event_date_time,
    mr.match_report,
    mr.id
FROM (match_reports mr
    JOIN users u ON mr.user_id = u.user_id)
    JOIN events e ON mr.event_id = e.event_id;


CREATE OR REPLACE VIEW public.view_team_details
WITH (security_invoker = true)
AS
SELECT team_id,
    team_name,
    lower(team_name) AS team_name_lowercase,
    team_unique_code AS team_code,
    lower(team_unique_code) AS team_code_lowercase,
    created_at
FROM teams
ORDER BY team_name;


CREATE OR REPLACE VIEW public.view_team_members
WITH (security_invoker = true)
AS
SELECT m.user_id,
    m.member_id,
    m.unique_member_code,
    m.first_name,
    m.last_name,
    concat(m.first_name, ' ', m.last_name) AS member_full_name,
    (lower(trim(m.first_name)) || ' ' || lower(trim(m.last_name))) AS lower_case_fullname,
    r.role_id,
    r.role_name,
    r.role_level,
    r.role_name_plural,
    r.role_grade,
    t.team_id,
    t.team_name,
    s.squad_id,
    s.squad_name
FROM ((((members m
    JOIN member_team_link mtl ON m.member_id = mtl.member_id)
    JOIN teams t ON mtl.team_id = t.team_id)
    JOIN member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id)
    JOIN roles r ON mtrl.role_id = r.role_id)
    LEFT JOIN squads s ON (mtl.squad_id = s.squad_id AND s.team_id = t.team_id)
ORDER BY t.team_name, s.squad_name, r.role_grade DESC, r.role_level DESC, m.last_name, m.first_name;


CREATE OR REPLACE VIEW public.view_user_members
WITH (security_invoker = true)
AS
SELECT u.user_id,
    u.email_address,
    u.phone_number,
    u.first_name AS user_first_name,
    u.last_name AS user_last_name,
    concat(COALESCE(u.first_name, ''), ' ', COALESCE(u.last_name, '')) AS user_full_name,
    m.member_id,
    m.first_name AS member_first_name,
    m.last_name AS member_last_name,
    concat(COALESCE(m.first_name, ''), ' ', COALESCE(m.last_name, '')) AS member_full_name,
    m.profile_pic AS member_profile_pic,
    t.team_id,
    t.team_name,
    r.role_id,
    r.role_name,
    r.role_level,
    r.role_grade
FROM (((((user_member_link uml
    JOIN users u ON uml.user_id = u.user_id)
    JOIN members m ON uml.member_id = m.member_id)
    LEFT JOIN member_team_link mtl ON m.member_id = mtl.member_id)
    LEFT JOIN teams t ON mtl.team_id = t.team_id)
    LEFT JOIN member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id)
    LEFT JOIN roles r ON mtrl.role_id = r.role_id;


CREATE OR REPLACE VIEW public.view_user_members_new
WITH (security_invoker = true)
AS
SELECT u.user_id,
    uml.user_member_id,
    uml.created_at,
    m.member_id,
    m.first_name AS member_first_name,
    m.last_name AS member_last_name,
    m.profile_pic AS member_profile_pic,
    m.unique_member_code,
    u.email_address,
    u.first_name AS user_first_name,
    u.last_name AS user_last_name,
    u.phone_number,
    t.team_id,
    t.team_name,
    mtl.member_team_id,
    r.role_id,
    r.role_name
FROM (((((user_member_link uml
    JOIN users u ON uml.user_id = u.user_id)
    JOIN members m ON uml.member_id = m.member_id)
    LEFT JOIN member_team_link mtl ON m.member_id = mtl.member_id)
    LEFT JOIN teams t ON mtl.team_id = t.team_id)
    LEFT JOIN member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id)
    LEFT JOIN roles r ON mtrl.role_id = r.role_id;


CREATE OR REPLACE VIEW public.view_user_team_members
WITH (security_invoker = true)
AS
SELECT u.user_id,
    u.email_address,
    u.phone_number,
    u.first_name AS user_first_name,
    u.last_name AS user_last_name,
    concat(COALESCE(u.first_name, ''), ' ', COALESCE(u.last_name, '')) AS user_full_name,
    m.member_id,
    m.first_name AS member_first_name,
    m.last_name AS member_last_name,
    concat(COALESCE(m.first_name, ''), ' ', COALESCE(m.last_name, '')) AS member_full_name,
    m.profile_pic AS member_profile_pic,
    t.team_id,
    t.team_name,
    r.role_id,
    r.role_name,
    r.role_level,
    r.role_grade,
    r.role_name_plural
FROM (((((members m
    JOIN user_member_link uml ON m.member_id = uml.member_id)
    JOIN users u ON uml.user_id = u.user_id)
    LEFT JOIN member_team_link mtl ON m.member_id = mtl.member_id)
    LEFT JOIN teams t ON mtl.team_id = t.team_id)
    LEFT JOIN member_team_role_link mtrl ON mtl.member_team_id = mtrl.member_team_id)
    LEFT JOIN roles r ON mtrl.role_id = r.role_id
ORDER BY u.user_id, m.member_id, t.team_id, r.role_grade DESC, r.role_level DESC, r.role_id;
