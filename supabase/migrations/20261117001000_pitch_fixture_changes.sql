-- Pitch planner: track changes to the club's fixtures in the league feed
-- (Ken, 2026-11-16: "show clearly if an update has happened"). The season store (gaa_games) is reloaded by deleting
-- and re-inserting a club's games, so a game's id changes on every sync.
-- A fixture is therefore known by its key (competition, home team, away
-- team), and a scan every 15 minutes compares the club's fixtures (home and
-- away) for
-- the next six weeks with what it saw last time:
--   new      a home fixture that wasn't there before
--   moved    the date or time changed
--   venue    the venue changed
--   referee  a referee was named or changed
--   status   e.g. postponed or cancelled
--   removed  the fixture is no longer listed at all
-- Each change is a row in pitch_alerts, shown in the planner's Alerts
-- panel and against the fixture on the Fixtures tab. A push to the club's
-- officers is off until pitch_club_settings.fixture_push is switched on.
-- The scan also re-links bookings to the fixture's current game id.
-- gaa_games.start_at is a real instant, shown in Irish time.

ALTER TABLE public.pitch_bookings ADD COLUMN IF NOT EXISTS fixture_key text;
ALTER TABLE public.pitch_club_settings ADD COLUMN IF NOT EXISTS fixtures_watched_at timestamptz;
ALTER TABLE public.pitch_club_settings ADD COLUMN IF NOT EXISTS fixture_push boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.pitch_fixture_key(p_comp text, p_home text, p_away text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path = 'public' AS $$
  SELECT coalesce(p_comp, '') || '|' || lower(coalesce(p_home, '')) || '|' || lower(coalesce(p_away, ''));
$$;

UPDATE public.pitch_bookings b
   SET fixture_key = public.pitch_fixture_key(g.comp_id::text, g.home_team, g.away_team)
  FROM public.gaa_games g
 WHERE g.game_id = b.gaa_game_id AND b.fixture_key IS NULL;

CREATE OR REPLACE FUNCTION public.pitch_bookings_fixture_fill()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $$
BEGIN
  IF NEW.gaa_game_id IS NULL THEN
    NEW.fixture_key := NULL;
  ELSIF TG_OP = 'INSERT' OR NEW.gaa_game_id IS DISTINCT FROM OLD.gaa_game_id THEN
    NEW.fixture_key := coalesce(
      (SELECT public.pitch_fixture_key(g.comp_id::text, g.home_team, g.away_team)
         FROM gaa_games g WHERE g.game_id = NEW.gaa_game_id),
      NEW.fixture_key);
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS pitch_bookings_fixture_fill ON public.pitch_bookings;
CREATE TRIGGER pitch_bookings_fixture_fill BEFORE INSERT OR UPDATE OF gaa_game_id ON public.pitch_bookings
  FOR EACH ROW EXECUTE FUNCTION public.pitch_bookings_fixture_fill();

CREATE TABLE IF NOT EXISTS public.pitch_fixture_watch (
  club_id     bigint NOT NULL REFERENCES public.clubs(club_id) ON DELETE CASCADE,
  fixture_key text   NOT NULL,
  game_id     bigint,
  starts_at   timestamp NOT NULL,
  title       text   NOT NULL DEFAULT '',
  venue       text   NOT NULL DEFAULT '',
  referee     text   NOT NULL DEFAULT '',
  status      text   NOT NULL DEFAULT '',
  seen_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (club_id, fixture_key)
);

CREATE TABLE IF NOT EXISTS public.pitch_alerts (
  alert_id    bigserial PRIMARY KEY,
  club_id     bigint NOT NULL REFERENCES public.clubs(club_id) ON DELETE CASCADE,
  kind        text   NOT NULL CHECK (kind IN ('new','moved','venue','referee','status','removed')),
  fixture_key text,
  title       text   NOT NULL,
  detail      text   NOT NULL DEFAULT '',
  old_start   timestamp,
  new_start   timestamp,
  booking_id  bigint REFERENCES public.pitch_bookings(booking_id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS pitch_alerts_club_idx ON public.pitch_alerts(club_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.pitch_alert_reads (
  club_id bigint NOT NULL REFERENCES public.clubs(club_id) ON DELETE CASCADE,
  user_id uuid   NOT NULL,
  seen_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (club_id, user_id)
);

ALTER TABLE public.pitch_fixture_watch ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pitch_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pitch_alert_reads ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.pitch_fixture_watch, public.pitch_alerts, public.pitch_alert_reads FROM anon, authenticated;

-- "Sat 21 Nov 14:00"
CREATE OR REPLACE FUNCTION public.pitch_when(t timestamp)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path = 'public' AS $$
  SELECT to_char(t, 'Dy FMDD Mon HH24:MI');
$$;

CREATE OR REPLACE FUNCTION public.pitch_fixture_scan()
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $$
DECLARE
  c      record;
  v_n    int;
  v_all  int := 0;
  v_first boolean;
  v_today date := (now() AT TIME ZONE 'Europe/Dublin')::date;
  v_title text;
BEGIN
  FOR c IN
    SELECT cl.club_id, cl.club_name, cl.gaa_club_id
      FROM clubs cl
     WHERE cl.gaa_club_id IS NOT NULL
       AND EXISTS (SELECT 1 FROM pitches p WHERE p.club_id = cl.club_id AND p.is_active)
  LOOP
    v_first := NOT EXISTS (SELECT 1 FROM pitch_club_settings s
                            WHERE s.club_id = c.club_id AND s.fixtures_watched_at IS NOT NULL);

    DROP TABLE IF EXISTS pg_temp.pitch_cur;
    CREATE TEMP TABLE pitch_cur ON COMMIT DROP AS
    SELECT DISTINCT ON (k) k AS fixture_key, game_id, starts_at, title, venue, referee, status
      FROM (SELECT public.pitch_fixture_key(g.comp_id::text, g.home_team, g.away_team) AS k,
                   g.game_id, (g.start_at AT TIME ZONE 'Europe/Dublin') AS starts_at,
                   trim(coalesce(gc.age || ' ', '') || coalesce(g.code, '') || ': ' ||
                        g.home_team || ' v ' || g.away_team) AS title,
                   coalesce(g.venue, '') AS venue, coalesce(g.referee, '') AS referee,
                   coalesce(g.status, '') AS status
              FROM gaa_games g
              LEFT JOIN gaa_competitions gc ON gc.comp_id = g.comp_id
             WHERE (g.home_club_id = c.gaa_club_id OR g.away_club_id = c.gaa_club_id)
               AND lower(coalesce(g.home_team, '')) NOT IN ('', 'bye')
               AND lower(coalesce(g.away_team, '')) NOT IN ('', 'bye')
               AND (g.start_at AT TIME ZONE 'Europe/Dublin')::date BETWEEN v_today AND v_today + 42) x
     ORDER BY k, starts_at;

    -- Keep bookings pointing at the fixture's current game row.
    UPDATE pitch_bookings b SET gaa_game_id = cur.game_id
      FROM pitch_cur cur
     WHERE b.club_id = c.club_id AND b.fixture_key = cur.fixture_key
       AND b.gaa_game_id IS DISTINCT FROM cur.game_id;

    IF NOT v_first THEN
      -- New home fixtures.
      INSERT INTO pitch_alerts(club_id, kind, fixture_key, title, detail, new_start)
      SELECT c.club_id, 'new', cur.fixture_key, cur.title,
             'New fixture: ' || public.pitch_when(cur.starts_at) ||
               CASE WHEN cur.venue <> '' THEN ' · ' || cur.venue ELSE '' END,
             cur.starts_at
        FROM pitch_cur cur
       WHERE NOT EXISTS (SELECT 1 FROM pitch_fixture_watch w
                          WHERE w.club_id = c.club_id AND w.fixture_key = cur.fixture_key);

      -- Date or time changed.
      INSERT INTO pitch_alerts(club_id, kind, fixture_key, title, detail, old_start, new_start, booking_id)
      SELECT c.club_id, 'moved', cur.fixture_key, cur.title,
             'Moved from ' || public.pitch_when(w.starts_at) || ' to ' || public.pitch_when(cur.starts_at) ||
               CASE WHEN b.booking_id IS NOT NULL AND b.starts_at <> cur.starts_at
                    THEN '. Still booked on ' || coalesce(p.name, 'a pitch') || ' at the old time.' ELSE '' END,
             w.starts_at, cur.starts_at, b.booking_id
        FROM pitch_cur cur
        JOIN pitch_fixture_watch w ON w.club_id = c.club_id AND w.fixture_key = cur.fixture_key
        LEFT JOIN LATERAL (SELECT bb.booking_id, bb.starts_at, bb.pitch_id FROM pitch_bookings bb
                            WHERE bb.club_id = c.club_id AND bb.fixture_key = cur.fixture_key
                            LIMIT 1) b ON true
        LEFT JOIN pitches p ON p.pitch_id = b.pitch_id
       WHERE w.starts_at <> cur.starts_at;

      -- Venue changed.
      INSERT INTO pitch_alerts(club_id, kind, fixture_key, title, detail, new_start)
      SELECT c.club_id, 'venue', cur.fixture_key, cur.title,
             'Venue changed from ' || coalesce(nullif(w.venue, ''), 'none') || ' to ' ||
               coalesce(nullif(cur.venue, ''), 'none') || ' · ' || public.pitch_when(cur.starts_at),
             cur.starts_at
        FROM pitch_cur cur
        JOIN pitch_fixture_watch w ON w.club_id = c.club_id AND w.fixture_key = cur.fixture_key
       WHERE public.pitch_norm(w.venue) <> public.pitch_norm(cur.venue);

      -- Referee named or changed.
      INSERT INTO pitch_alerts(club_id, kind, fixture_key, title, detail, new_start)
      SELECT c.club_id, 'referee', cur.fixture_key, cur.title,
             'Referee: ' || cur.referee || ' · ' || public.pitch_when(cur.starts_at), cur.starts_at
        FROM pitch_cur cur
        JOIN pitch_fixture_watch w ON w.club_id = c.club_id AND w.fixture_key = cur.fixture_key
       WHERE cur.referee <> '' AND public.pitch_norm(w.referee) <> public.pitch_norm(cur.referee);

      -- Status changed (postponed, cancelled, conceded ...); results are not alerts.
      INSERT INTO pitch_alerts(club_id, kind, fixture_key, title, detail, new_start)
      SELECT c.club_id, 'status', cur.fixture_key, cur.title,
             initcap(cur.status) || ' · ' || public.pitch_when(cur.starts_at), cur.starts_at
        FROM pitch_cur cur
        JOIN pitch_fixture_watch w ON w.club_id = c.club_id AND w.fixture_key = cur.fixture_key
       WHERE lower(w.status) IS DISTINCT FROM lower(cur.status)
         AND cur.status ~* '(postpon|cancel|conced|walkover|refix|tbc|abandon)';

      -- No longer listed in the next six weeks: moved further out, or gone.
      INSERT INTO pitch_alerts(club_id, kind, fixture_key, title, detail, old_start, new_start, booking_id)
      SELECT c.club_id,
             CASE WHEN o.starts_at IS NULL THEN 'removed' ELSE 'moved' END,
             w.fixture_key, w.title,
             CASE WHEN o.starts_at IS NULL
                  THEN 'No longer listed (was ' || public.pitch_when(w.starts_at) || '). Postponed or cancelled?'
                  ELSE 'Moved from ' || public.pitch_when(w.starts_at) || ' to ' || public.pitch_when(o.starts_at) END ||
               CASE WHEN b.booking_id IS NOT NULL THEN ' Still booked on ' || coalesce(p.name, 'a pitch') || '.' ELSE '' END,
             w.starts_at, o.starts_at, b.booking_id
        FROM pitch_fixture_watch w
        LEFT JOIN LATERAL (SELECT (g.start_at AT TIME ZONE 'Europe/Dublin') AS starts_at FROM gaa_games g
                            WHERE (g.home_club_id = c.gaa_club_id OR g.away_club_id = c.gaa_club_id)
                              AND public.pitch_fixture_key(g.comp_id::text, g.home_team, g.away_team) = w.fixture_key
                            ORDER BY g.start_at LIMIT 1) o ON true
        LEFT JOIN LATERAL (SELECT bb.booking_id, bb.pitch_id FROM pitch_bookings bb
                            WHERE bb.club_id = c.club_id AND bb.fixture_key = w.fixture_key
                            LIMIT 1) b ON true
        LEFT JOIN pitches p ON p.pitch_id = b.pitch_id
       WHERE w.club_id = c.club_id
         AND w.starts_at::date >= v_today
         AND NOT EXISTS (SELECT 1 FROM pitch_cur cur WHERE cur.fixture_key = w.fixture_key)
         AND (o.starts_at IS NULL OR o.starts_at::date > v_today + 42);
    END IF;

    SELECT count(*) INTO v_n FROM pitch_alerts a
     WHERE a.club_id = c.club_id AND a.created_at = now();  -- made in this run
    v_all := v_all + v_n;

    -- One push per scan to the club's named officers (not every SuperUser),
    -- only when the club has switched it on.
    IF v_n > 0 AND EXISTS (SELECT 1 FROM pitch_club_settings s
                            WHERE s.club_id = c.club_id AND s.fixture_push) THEN
      SELECT CASE WHEN v_n = 1 THEN (SELECT a.title || ': ' || a.detail FROM pitch_alerts a
                                      WHERE a.club_id = c.club_id AND a.created_at = now() LIMIT 1)
                  ELSE v_n || ' fixture changes. Open the pitch planner to see them.' END
        INTO v_title;
      INSERT INTO notifications(recipient_user_id, app_title, app_body, push_title, push_body, delivery_method)
      SELECT co.user_id, 'Fixture changes', v_title, c.club_name || ': fixture changes', v_title, 'push'
        FROM club_officers co
       WHERE co.club_id = c.club_id AND co.is_active;
    END IF;

    DELETE FROM pitch_fixture_watch w WHERE w.club_id = c.club_id;
    INSERT INTO pitch_fixture_watch(club_id, fixture_key, game_id, starts_at, title, venue, referee, status)
    SELECT c.club_id, cur.fixture_key, cur.game_id, cur.starts_at, cur.title, cur.venue, cur.referee, cur.status
      FROM pitch_cur cur;

    INSERT INTO pitch_club_settings(club_id, fixtures_watched_at) VALUES (c.club_id, now())
    ON CONFLICT (club_id) DO UPDATE SET fixtures_watched_at = now();
  END LOOP;
  RETURN v_all;
END $$;
REVOKE ALL ON FUNCTION public.pitch_fixture_scan() FROM PUBLIC, anon, authenticated;

-- The planner's Alerts panel: newest first, with what this user hasn't seen.
CREATE OR REPLACE FUNCTION public.pitch_alerts_get(p_club bigint, p_limit int DEFAULT 60)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = 'public' AS $$
DECLARE v_seen timestamptz;
BEGIN
  PERFORM public.pitch_require_admin(p_club);
  SELECT seen_at INTO v_seen FROM pitch_alert_reads WHERE club_id = p_club AND user_id = auth.uid();
  RETURN jsonb_build_object(
    'seen_at', v_seen,
    'unread', (SELECT count(*) FROM pitch_alerts a
                WHERE a.club_id = p_club AND (v_seen IS NULL OR a.created_at > v_seen)),
    'watching_since', (SELECT fixtures_watched_at FROM pitch_club_settings WHERE club_id = p_club),
    'alerts', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
               'alert_id', a.alert_id, 'kind', a.kind, 'title', a.title, 'detail', a.detail,
               'old_start', to_char(a.old_start, 'YYYY-MM-DD"T"HH24:MI:SS'),
               'new_start', to_char(a.new_start, 'YYYY-MM-DD"T"HH24:MI:SS'),
               'booking_id', a.booking_id,
               'created_at', a.created_at,
               'unread', v_seen IS NULL OR a.created_at > v_seen) ORDER BY a.created_at DESC, a.alert_id DESC)
        FROM (SELECT * FROM pitch_alerts WHERE club_id = p_club
               ORDER BY created_at DESC, alert_id DESC LIMIT greatest(1, least(p_limit, 200))) a), '[]'::jsonb));
END $$;

CREATE OR REPLACE FUNCTION public.pitch_alerts_seen(p_club bigint)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $$
BEGIN
  PERFORM public.pitch_require_admin(p_club);
  INSERT INTO pitch_alert_reads(club_id, user_id, seen_at) VALUES (p_club, auth.uid(), now())
  ON CONFLICT (club_id, user_id) DO UPDATE SET seen_at = now();
END $$;

REVOKE ALL ON FUNCTION public.pitch_alerts_get(bigint, int), public.pitch_alerts_seen(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pitch_alerts_get(bigint, int), public.pitch_alerts_seen(bigint) TO authenticated;
REVOKE ALL ON FUNCTION public.pitch_bookings_fixture_fill() FROM PUBLIC, anon, authenticated;

-- The Fixtures tab: each league fixture now carries its recent changes.
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
           gc.age, gc.name AS comp_name,
           public.pitch_fixture_key(g.comp_id::text, g.home_team, g.away_team) AS fkey
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
               -- Changes seen in the league feed over the last 14 days.
               'changes', coalesce((SELECT jsonb_agg(jsonb_build_object(
                                             'kind', a.kind, 'detail', a.detail,
                                             'created_at', a.created_at) ORDER BY a.created_at DESC)
                                      FROM (SELECT * FROM pitch_alerts a
                                             WHERE a.club_id = p_club AND a.fixture_key = gm.fkey
                                               AND a.created_at > now() - interval '14 days'
                                             ORDER BY a.created_at DESC LIMIT 5) a), '[]'::jsonb),
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

-- Every 15 minutes; the syncs run at 04:10-04:35 and 13:30 Irish time.
SELECT cron.unschedule('pitch-fixture-scan') WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'pitch-fixture-scan');
SELECT cron.schedule('pitch-fixture-scan', '*/15 * * * *', $$SELECT public.pitch_fixture_scan()$$);

-- First scan now records today's fixtures without alerting.
SELECT public.pitch_fixture_scan();

-- Slot review against Clontarf's sheet (Ken, 2026-11-16): the Clubhouse
-- Astro 12:00 slots on Tuesday and Wednesday were only for Belgrove and
-- Schools, which Ken asked to ignore.
DELETE FROM public.pitch_hours h
 USING public.pitches p
 WHERE p.pitch_id = h.pitch_id AND p.club_id = 1 AND p.name = 'Clubhouse Astro'
   AND h.weekday IN (2, 3) AND h.opens = '12:00';
