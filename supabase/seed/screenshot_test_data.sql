-- =============================================================
-- CoachSmart — Screenshot Test Data
-- =============================================================
-- Purpose : Fictional data for generating realistic screenshots.
--           Safe to run — all IDs use 9000+ range to avoid
--           colliding with real data.
--
-- Steps:
--   1. Open Supabase Dashboard → SQL Editor
--   2. Run this first to get your user UUID:
--        SELECT auth.uid();
--   3. Replace 'YOUR-USER-UUID-HERE' below with that value
--   4. Run this entire script
--   5. To remove all test data, run the CLEANUP block at the bottom
-- =============================================================

DO $$
DECLARE
  -- ⚠️  REPLACE THIS with your UUID from: SELECT auth.uid();
  v_user_id   UUID    := 'YOUR-USER-UUID-HERE';

  v_coach_id  BIGINT  := 9000;  -- member_id for the logged-in coach
  v_mtl_id    BIGINT;
BEGIN

-- =============================================================
-- 1. REFERENCE DATA (safe inserts — skips if already present)
-- =============================================================

INSERT INTO public.sport (sport_id, sport_name) VALUES
  (1, 'GAA')
ON CONFLICT (sport_id) DO NOTHING;

INSERT INTO public.event_codes (code_id, event_code) VALUES
  (1, 'Football'),
  (2, 'Hurling'),
  (3, 'Camogie'),
  (4, 'Ladies Football')
ON CONFLICT (code_id) DO NOTHING;

INSERT INTO public.event_types (event_type_id, event_type) VALUES
  (1, 'Training'),
  (2, 'Match'),
  (3, 'Meeting'),
  (4, 'Friendly')
ON CONFLICT (event_type_id) DO NOTHING;

INSERT INTO public.event_response_type (response_id, response_value, display_value) VALUES
  (1, 'no_response', 'No Response'),
  (2, 'maybe',       'Maybe'),
  (3, 'attending',   'Attending'),
  (4, 'declined',    'Declined')
ON CONFLICT (response_id) DO NOTHING;

INSERT INTO public.roles (role_id, role_name, role_name_plural, role_level, role_grade, role_list_seq, show_audience) VALUES
  (1, 'Super Admin',  'Super Admins',  1, 1, 1, false),
  (2, 'Club Admin',   'Club Admins',   2, 2, 2, false),
  (3, 'Club Manager', 'Club Managers', 3, 3, 3, true),
  (4, 'Treasurer',    'Treasurers',    4, 4, 4, false),
  (5, 'Secretary',    'Secretaries',   5, 5, 5, false),
  (6, 'Player',       'Players',       6, 10, 6, true),
  (7, 'Admin',        'Admins',        7, 7, 7, true),
  (8, 'Coach',        'Coaches',       8, 8, 8, true)
ON CONFLICT (role_id) DO NOTHING;

-- =============================================================
-- 2. CLUB
-- =============================================================

INSERT INTO public.clubs (club_id, club_name, county, sport_id) VALUES
  (9001, 'Kilmore GAA', 'Dublin', 1)
ON CONFLICT (club_id) DO NOTHING;

INSERT INTO public.club_code_link (club_id, code_id) VALUES
  (9001, 1),
  (9001, 2)
ON CONFLICT DO NOTHING;

-- =============================================================
-- 3. TEAMS
-- =============================================================

INSERT INTO public.teams (team_id, team_name, team_unique_code, club_id, team_juvenile, team_female) VALUES
  (9001, 'Kilmore Boys 2013', 'TM9001X', 9001, true, false),
  (9002, 'Kilmore Boys 2016', 'TM9002X', 9001, true, false)
ON CONFLICT (team_id) DO NOTHING;

-- =============================================================
-- 4. SQUADS
-- =============================================================

INSERT INTO public.squads (squad_id, team_id, squad_name, grade) VALUES
  (9001, 9001, 'Main Squad', 'Under 13'),
  (9002, 9002, 'Main Squad', 'Under 10')
ON CONFLICT (squad_id) DO NOTHING;

-- =============================================================
-- 5. LOGGED-IN COACH (links your account to both test teams)
-- =============================================================

INSERT INTO public.users (user_id, email_address, first_name, last_name)
VALUES (v_user_id, 'coach@kilmoregaa.ie', 'Demo', 'Coach')
ON CONFLICT (user_id) DO UPDATE SET email_address = EXCLUDED.email_address;

INSERT INTO public.members (member_id, first_name, last_name, unique_member_code, user_id)
VALUES (v_coach_id, 'Demo', 'Coach', 'MB9000X', v_user_id)
ON CONFLICT (member_id) DO NOTHING;

INSERT INTO public.user_member_link (user_id, member_id)
VALUES (v_user_id, v_coach_id)
ON CONFLICT DO NOTHING;

-- Link coach to Team 1
INSERT INTO public.member_team_link (member_id, team_id, squad_id)
VALUES (v_coach_id, 9001, 9001)
RETURNING member_team_id INTO v_mtl_id;
INSERT INTO public.member_team_role_link (member_team_id, role_id) VALUES (v_mtl_id, 8);

-- Link coach to Team 2
INSERT INTO public.member_team_link (member_id, team_id, squad_id)
VALUES (v_coach_id, 9002, 9002)
RETURNING member_team_id INTO v_mtl_id;
INSERT INTO public.member_team_role_link (member_team_id, role_id) VALUES (v_mtl_id, 8);

-- =============================================================
-- 6. MEMBERS — Kilmore Boys 2013 (15 players + 2 coaches)
-- =============================================================

INSERT INTO public.members (member_id, first_name, last_name, unique_member_code) VALUES
  (9001, 'Ciarán',   'O''Brien',    'MB9001X'),
  (9002, 'Seán',     'McCarthy',    'MB9002X'),
  (9003, 'Darragh',  'Murphy',      'MB9003X'),
  (9004, 'Fionn',    'O''Donnell',  'MB9004X'),
  (9005, 'Pádraig',  'Connell',     'MB9005X'),
  (9006, 'Oisín',    'Gilchrist',   'MB9006X'),
  (9007, 'Cathal',   'Farrell',     'MB9007X'),
  (9008, 'Conor',    'Lehane',      'MB9008X'),
  (9009, 'Ruairí',   'Martin',      'MB9009X'),
  (9010, 'Tadhg',    'Kelly',       'MB9010X'),
  (9011, 'Eoin',     'Walsh',       'MB9011X'),
  (9012, 'Brian',    'McDermott',   'MB9012X'),
  (9013, 'Liam',     'Molloy',      'MB9013X'),
  (9014, 'Niall',    'McBride',     'MB9014X'),
  (9015, 'Donal',    'Flynn',       'MB9015X'),
  (9031, 'Michael',  'Walsh',       'MB9031X'),
  (9032, 'David',    'Ryan',        'MB9032X')
ON CONFLICT (member_id) DO NOTHING;

-- Link Team 1 players to team
INSERT INTO public.member_team_link (member_id, team_id, squad_id)
SELECT m, 9001, 9001 FROM unnest(ARRAY[9001,9002,9003,9004,9005,9006,9007,9008,
  9009,9010,9011,9012,9013,9014,9015,9031,9032]::BIGINT[]) AS m
ON CONFLICT DO NOTHING;

-- Assign roles for Team 1
INSERT INTO public.member_team_role_link (member_team_id, role_id)
SELECT mtl.member_team_id,
  CASE WHEN mtl.member_id IN (9031, 9032) THEN 8 ELSE 6 END
FROM public.member_team_link mtl
WHERE mtl.team_id = 9001
  AND mtl.member_id IN (9001,9002,9003,9004,9005,9006,9007,9008,
    9009,9010,9011,9012,9013,9014,9015,9031,9032)
ON CONFLICT DO NOTHING;

-- Link Team 1 members to squad
INSERT INTO public.member_squad_link (member_id, squad_id, code_id, team_id)
SELECT m, 9001, 1, 9001 FROM unnest(ARRAY[9001,9002,9003,9004,9005,9006,9007,9008,
  9009,9010,9011,9012,9013,9014,9015]::BIGINT[]) AS m
ON CONFLICT DO NOTHING;

-- =============================================================
-- 7. MEMBERS — Kilmore Boys 2016 (15 players + 2 coaches)
-- =============================================================

INSERT INTO public.members (member_id, first_name, last_name, unique_member_code) VALUES
  (9016, 'Aaron',    'Burke',        'MB9016X'),
  (9017, 'Josh',     'McCarthy',     'MB9017X'),
  (9018, 'Luke',     'Murphy',       'MB9018X'),
  (9019, 'Evan',     'O''Donnell',   'MB9019X'),
  (9020, 'Harry',    'Connell',      'MB9020X'),
  (9021, 'Cian',     'Gilchrist',    'MB9021X'),
  (9022, 'Jamie',    'Farrell',      'MB9022X'),
  (9023, 'Alex',     'Lehane',       'MB9023X'),
  (9024, 'Ben',      'Martin',       'MB9024X'),
  (9025, 'Sam',      'Kelly',        'MB9025X'),
  (9026, 'Tom',      'O''Brien',     'MB9026X'),
  (9027, 'Joe',      'McDermott',    'MB9027X'),
  (9028, 'Mark',     'Molloy',       'MB9028X'),
  (9029, 'Jake',     'McBride',      'MB9029X'),
  (9030, 'Ryan',     'Flynn',        'MB9030X'),
  (9033, 'Patrick',  'Byrne',        'MB9033X'),
  (9034, 'Kevin',    'O''Sullivan',  'MB9034X')
ON CONFLICT (member_id) DO NOTHING;

-- Link Team 2 players to team
INSERT INTO public.member_team_link (member_id, team_id, squad_id)
SELECT m, 9002, 9002 FROM unnest(ARRAY[9016,9017,9018,9019,9020,9021,9022,9023,
  9024,9025,9026,9027,9028,9029,9030,9033,9034]::BIGINT[]) AS m
ON CONFLICT DO NOTHING;

-- Assign roles for Team 2
INSERT INTO public.member_team_role_link (member_team_id, role_id)
SELECT mtl.member_team_id,
  CASE WHEN mtl.member_id IN (9033, 9034) THEN 8 ELSE 6 END
FROM public.member_team_link mtl
WHERE mtl.team_id = 9002
  AND mtl.member_id IN (9016,9017,9018,9019,9020,9021,9022,9023,
    9024,9025,9026,9027,9028,9029,9030,9033,9034)
ON CONFLICT DO NOTHING;

-- Link Team 2 members to squad
INSERT INTO public.member_squad_link (member_id, squad_id, code_id, team_id)
SELECT m, 9002, 1, 9002 FROM unnest(ARRAY[9016,9017,9018,9019,9020,9021,9022,9023,
  9024,9025,9026,9027,9028,9029,9030]::BIGINT[]) AS m
ON CONFLICT DO NOTHING;

-- =============================================================
-- 8. EVENTS (upcoming — dates relative to now)
-- =============================================================

INSERT INTO public.events (
  event_id, event_title, event_date_time, event_date_time_2,
  meet_time, team_id, event_type_id, event_code_id,
  location_name, opposition, home_away,
  request_attendance, squad_id, created_by, audience_id
) VALUES
  (9001, 'Football Training',
    NOW() + INTERVAL '1 day' + TIME '18:30',
    NOW() + INTERVAL '1 day' + TIME '18:30',
    '18:15', 9001, 1, 1, 'Kilmore Park', NULL, NULL,
    true, 9001, v_user_id, 6),

  (9002, 'Hurling Match vs St Brigid''s',
    NOW() + INTERVAL '3 days' + TIME '14:00',
    NOW() + INTERVAL '3 days' + TIME '14:00',
    '13:30', 9001, 2, 2, 'Parnell Park', 'St Brigid''s', 'Away',
    true, 9001, v_user_id, 6),

  (9003, 'Football Training',
    NOW() + INTERVAL '5 days' + TIME '18:30',
    NOW() + INTERVAL '5 days' + TIME '18:30',
    '18:15', 9001, 1, 1, 'Kilmore Park', NULL, NULL,
    true, 9001, v_user_id, 6),

  (9004, 'Football Training',
    NOW() + INTERVAL '1 day' + TIME '17:00',
    NOW() + INTERVAL '1 day' + TIME '17:00',
    '16:45', 9002, 1, 1, 'Kilmore Park', NULL, NULL,
    true, 9002, v_user_id, 6),

  (9005, 'Football Match vs Na Fianna',
    NOW() + INTERVAL '6 days' + TIME '11:00',
    NOW() + INTERVAL '6 days' + TIME '11:00',
    '10:30', 9002, 2, 1, 'Mobhi Road', 'Na Fianna', 'Home',
    true, 9002, v_user_id, 6),

  (9006, 'Hurling Training',
    NOW() + INTERVAL '8 days' + TIME '18:30',
    NOW() + INTERVAL '8 days' + TIME '18:30',
    '18:15', 9001, 1, 2, 'Kilmore Park', NULL, NULL,
    true, 9001, v_user_id, 6)
ON CONFLICT (event_id) DO NOTHING;

-- =============================================================
-- 9. ATTENDANCE — Event 9001 (Training, Team 1)
--    29 attending · 15 no response · 12 declined
-- =============================================================

-- Attending (players 9001–9012 + coaches 9031,9032 + coach 9000 = 15)
INSERT INTO public.event_attendance (event_id, member_id, response_id)
SELECT 9001, m, 3 FROM unnest(ARRAY[
  9001,9002,9003,9004,9005,9006,9007,9008,9009,9010,9011,9012,9031,9032,v_coach_id
]::BIGINT[]) AS m
ON CONFLICT DO NOTHING;

-- No Response (9013, 9014, 9015)
INSERT INTO public.event_attendance (event_id, member_id, response_id)
SELECT 9001, m, 1 FROM unnest(ARRAY[9013,9014,9015]::BIGINT[]) AS m
ON CONFLICT DO NOTHING;

-- =============================================================
-- 10. ATTENDANCE — Event 9002 (Match, Team 1)
--     33 attending · 16 no response · 14 declined
-- =============================================================

-- Attending
INSERT INTO public.event_attendance (event_id, member_id, response_id)
SELECT 9002, m, 3 FROM unnest(ARRAY[
  9001,9002,9003,9004,9005,9006,9007,9008,9009,9010,9011,9031,9032,v_coach_id
]::BIGINT[]) AS m
ON CONFLICT DO NOTHING;

-- No Response
INSERT INTO public.event_attendance (event_id, member_id, response_id)
SELECT 9002, m, 1 FROM unnest(ARRAY[9012,9013,9014]::BIGINT[]) AS m
ON CONFLICT DO NOTHING;

-- Declined
INSERT INTO public.event_attendance (event_id, member_id, response_id)
SELECT 9002, m, 4 FROM unnest(ARRAY[9015]::BIGINT[]) AS m
ON CONFLICT DO NOTHING;

-- =============================================================
-- 11. ATTENDANCE — Event 9004 (Training, Team 2)
-- =============================================================

-- Attending
INSERT INTO public.event_attendance (event_id, member_id, response_id)
SELECT 9004, m, 3 FROM unnest(ARRAY[
  9016,9017,9018,9019,9020,9021,9022,9023,9024,9033,9034,v_coach_id
]::BIGINT[]) AS m
ON CONFLICT DO NOTHING;

-- No Response
INSERT INTO public.event_attendance (event_id, member_id, response_id)
SELECT 9004, m, 1 FROM unnest(ARRAY[9025,9026,9027]::BIGINT[]) AS m
ON CONFLICT DO NOTHING;

-- Declined
INSERT INTO public.event_attendance (event_id, member_id, response_id)
SELECT 9004, m, 4 FROM unnest(ARRAY[9028,9029,9030]::BIGINT[]) AS m
ON CONFLICT DO NOTHING;

RAISE NOTICE '✅ Test data inserted successfully. Teams: Kilmore Boys 2013 & 2016.';
RAISE NOTICE '   Log in as your account to see the data in the app.';

END $$;


-- =============================================================
-- CLEANUP — Run this block to remove all test data
-- (Uncomment and run separately when done with screenshots)
-- =============================================================
/*
DO $$
BEGIN
  DELETE FROM public.event_attendance   WHERE event_id   BETWEEN 9001 AND 9099;
  DELETE FROM public.events             WHERE event_id   BETWEEN 9001 AND 9099;
  DELETE FROM public.member_squad_link  WHERE team_id    IN (9001, 9002);
  DELETE FROM public.member_team_role_link
    WHERE member_team_id IN (
      SELECT member_team_id FROM public.member_team_link
      WHERE team_id IN (9001, 9002) OR member_id BETWEEN 9000 AND 9099
    );
  DELETE FROM public.member_team_link   WHERE team_id    IN (9001, 9002)
                                           OR member_id  BETWEEN 9000 AND 9099;
  DELETE FROM public.user_member_link   WHERE member_id  = 9000;
  DELETE FROM public.members            WHERE member_id  BETWEEN 9000 AND 9099;
  DELETE FROM public.squads             WHERE squad_id   IN (9001, 9002);
  DELETE FROM public.teams              WHERE team_id    IN (9001, 9002);
  DELETE FROM public.club_code_link     WHERE club_id    = 9001;
  DELETE FROM public.clubs              WHERE club_id    = 9001;
  RAISE NOTICE '🧹 Test data removed.';
END $$;
*/
