-- Pitch planner Fixtures tab (Ken, 2026-11-16): the week's matches in two
-- buckets.
--   official    the club's games in the league feed (gaa_games), home and
--               away, with the pitch booking and the CoachSmart match event
--               that goes with each one
--   unofficial  CoachSmart match events with no game in the league feed
--               (go games, friendlies, blitzes ...)
-- An event goes with a game when it is within 90 minutes of it, its
-- opposition names the other side and (when known) the age group matches. gaa_games.start_at is a real instant
-- (shown in Irish time); events.event_date_time is the Irish clock time.

CREATE OR REPLACE FUNCTION public.pitch_fixtures_week(p_club bigint, p_monday date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = 'public' AS $$
DECLARE
  v_gaa  int;
  v_from timestamp := date_trunc('week', p_monday::timestamp);
  v_to   timestamp := date_trunc('week', p_monday::timestamp) + interval '7 days';
  r jsonb;
BEGIN
  PERFORM public.pitch_require_admin(p_club);
  SELECT gaa_club_id INTO v_gaa FROM clubs WHERE club_id = p_club;

  WITH gm AS (
    SELECT g.game_id, g.code, g.home_team, g.away_team, g.venue, g.referee, g.status, g.note,
           g.home_score, g.away_score,
           (g.home_club_id = v_gaa) AS is_home,
           CASE WHEN g.home_club_id = v_gaa THEN g.away_team ELSE g.home_team END AS other,
           (g.start_at AT TIME ZONE 'Europe/Dublin') AS starts_at,
           gc.age, gc.name AS comp_name
      FROM gaa_games g
      LEFT JOIN gaa_competitions gc ON gc.comp_id = g.comp_id
     WHERE v_gaa IS NOT NULL
       AND (g.home_club_id = v_gaa OR g.away_club_id = v_gaa)
       AND lower(coalesce(g.home_team, '')) NOT IN ('', 'bye')
       AND lower(coalesce(g.away_team, '')) NOT IN ('', 'bye')
       AND (g.start_at AT TIME ZONE 'Europe/Dublin') >= v_from
       AND (g.start_at AT TIME ZONE 'Europe/Dublin') <  v_to
  ), ev AS (
    SELECT e.event_id, e.team_id, t.team_name, t.team_female, ec.event_code,
           e.opposition, e.home_away, e.location_name, e.status,
           (e.event_date_time AT TIME ZONE 'UTC') AS starts_at
      FROM events e
      JOIN teams t ON t.team_id = e.team_id
      LEFT JOIN event_types et ON et.event_type_id = e.event_type_id
      LEFT JOIN event_codes ec ON ec.code_id = e.event_code_id
     WHERE t.club_id = p_club
       AND coalesce(et.event_type, '') ILIKE '%match%'
       AND coalesce(e.status, '') NOT ILIKE '%delete%'
       AND (e.event_date_time AT TIME ZONE 'UTC') >= v_from
       AND (e.event_date_time AT TIME ZONE 'UTC') <  v_to
  ), pair AS (
    SELECT DISTINCT ON (ev.event_id) ev.event_id, gm.game_id
      FROM ev JOIN gm
        ON abs(extract(epoch FROM ev.starts_at - gm.starts_at)) <= 5400
       AND coalesce(ev.opposition, '') <> ''
       -- Same age group when both are known (Boys 2013 in 2026 is U13).
       AND (substring(ev.team_name FROM '(20[0-9][0-9])') IS NULL OR coalesce(gm.age, '') !~ '^U[0-9]+$'
            OR 'U' || (extract(year FROM gm.starts_at)::int - substring(ev.team_name FROM '(20[0-9][0-9])')::int) = gm.age)
       AND (public.pitch_norm(ev.opposition) LIKE '%' || public.pitch_norm(split_part(gm.other, ' ', 1)) || '%'
            OR public.pitch_norm(gm.other) LIKE '%' || public.pitch_norm(ev.opposition) || '%')
     ORDER BY ev.event_id, abs(extract(epoch FROM ev.starts_at - gm.starts_at))
  ), bk AS (
    SELECT b.booking_id, b.gaa_game_id, b.event_id, b.status, p.name AS pitch_name,
           to_char(b.starts_at, 'YYYY-MM-DD"T"HH24:MI:SS') AS starts_at
      FROM pitch_bookings b LEFT JOIN pitches p ON p.pitch_id = b.pitch_id
     WHERE b.club_id = p_club
  )
  SELECT jsonb_build_object(
    'official', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
               'game_id', gm.game_id, 'code', gm.code, 'age', gm.age, 'comp', gm.comp_name,
               'home', gm.home_team, 'away', gm.away_team, 'is_home', gm.is_home,
               'venue', gm.venue, 'referee', gm.referee, 'status', gm.status, 'note', gm.note,
               'home_score', gm.home_score, 'away_score', gm.away_score,
               'starts_at', to_char(gm.starts_at, 'YYYY-MM-DD"T"HH24:MI:SS'),
               'event', (SELECT jsonb_build_object('event_id', ev.event_id, 'team_name', ev.team_name,
                                                   'location', ev.location_name)
                           FROM pair JOIN ev ON ev.event_id = pair.event_id
                          WHERE pair.game_id = gm.game_id LIMIT 1),
               'booking', (SELECT jsonb_build_object('booking_id', bk.booking_id, 'status', bk.status,
                                                     'pitch', bk.pitch_name, 'starts_at', bk.starts_at)
                             FROM bk
                            WHERE bk.gaa_game_id = gm.game_id
                               OR bk.event_id IN (SELECT pair.event_id FROM pair WHERE pair.game_id = gm.game_id)
                            LIMIT 1))
             ORDER BY gm.starts_at, gm.game_id)
        FROM gm), '[]'::jsonb),
    'unofficial', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
               'event_id', ev.event_id, 'team_id', ev.team_id, 'team_name', ev.team_name,
               'female', ev.team_female, 'code', ev.event_code, 'opposition', ev.opposition,
               'home_away', ev.home_away, 'location', ev.location_name, 'status', ev.status,
               'starts_at', to_char(ev.starts_at, 'YYYY-MM-DD"T"HH24:MI:SS'),
               'matched_pitch_id', public.pitch_match(p_club, ev.location_name),
               'booking', (SELECT jsonb_build_object('booking_id', bk.booking_id, 'status', bk.status,
                                                     'pitch', bk.pitch_name, 'starts_at', bk.starts_at)
                             FROM bk WHERE bk.event_id = ev.event_id LIMIT 1))
             ORDER BY ev.starts_at, ev.event_id)
        FROM ev WHERE NOT EXISTS (SELECT 1 FROM pair WHERE pair.event_id = ev.event_id)), '[]'::jsonb)
  ) INTO r;
  RETURN r;
END $$;

REVOKE ALL ON FUNCTION public.pitch_fixtures_week(bigint, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pitch_fixtures_week(bigint, date) TO authenticated;
