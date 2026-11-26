-- Club followers (Ken, 2026-11-26, thread "Let members follow a club without a team").
--
-- A club that is set up for it (clubs.followers_open) has a club code
-- (clubs.follow_code, e.g. CLONTARFGAA). Anyone with the code can follow the
-- club straight away, no approval and no team. There is no club search: no
-- code, no club. Team codes keep the coach's approval as today.
--
-- Followers see club-level things only: club news and important messages
-- sent to Everyone at the club, the club partner, and the club's matches
-- (live scores, coming up). Never rosters, attendance or names.
--
-- Everything here is additive. The old app never follows a club, so v2
-- behaves exactly as before for everybody.

ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS follow_code text;
ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS followers_open boolean NOT NULL DEFAULT false;

CREATE UNIQUE INDEX IF NOT EXISTS clubs_follow_code_key
  ON public.clubs (upper(follow_code)) WHERE follow_code IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.club_followers (
  user_id    uuid        NOT NULL,
  club_id    bigint      NOT NULL REFERENCES public.clubs(club_id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, club_id)
);
CREATE INDEX IF NOT EXISTS club_followers_club_idx ON public.club_followers (club_id);
ALTER TABLE public.club_followers ENABLE ROW LEVEL SECURITY;  -- no policies: RPCs only
REVOKE ALL ON public.club_followers FROM anon, authenticated;

-- First clubs: Clontarf GAA open to followers; Clontarf Rugby has its code
-- ready but stays closed until it is set up.
UPDATE public.clubs SET follow_code = 'CLONTARFGAA', followers_open = true
 WHERE club_id = 1 AND follow_code IS NULL;
UPDATE public.clubs SET follow_code = 'CLONTARFRUGBY'
 WHERE club_id = 2 AND follow_code IS NULL;

-- Clubs a user follows (only while the club is open to followers).
CREATE OR REPLACE FUNCTION public.user_followed_clubs(p_uid uuid)
RETURNS TABLE(club_id bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = 'public'
AS $$
  SELECT f.club_id
    FROM club_followers f
    JOIN clubs c ON c.club_id = f.club_id AND c.followers_open
   WHERE f.user_id = p_uid;
$$;

CREATE OR REPLACE FUNCTION public.club_follow_json(p_club bigint, p_uid uuid)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = 'public'
AS $$
  SELECT jsonb_build_object(
           'club_id', c.club_id,
           'club_name', c.club_name,
           'crest', COALESCE(c.crest, ''),
           'county', COALESCE(c.county, ''),
           'sport_id', COALESCE(c.sport_id, 1),
           'primary_colour', COALESCE(c.primary_colour, ''),
           'secondary_colour', COALESCE(c.secondary_colour, ''),
           'following', EXISTS (SELECT 1 FROM club_followers f
                                 WHERE f.club_id = c.club_id AND f.user_id = p_uid))
    FROM clubs c WHERE c.club_id = p_club;
$$;

-- What a code is: a club code (open club) or a team joining code. Used by
-- the "Got a code?" box, which takes both.
CREATE OR REPLACE FUNCTION public.lookup_join_code(p_code text)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = 'public'
AS $$
DECLARE
  v_uid  uuid := auth.uid();
  v_code text := upper(regexp_replace(COALESCE(p_code, ''), '\s', '', 'g'));
  v_club bigint;
  v_team record;
BEGIN
  IF v_uid IS NULL THEN RETURN jsonb_build_object('kind', 'none'); END IF;
  IF length(v_code) < 3 THEN RETURN jsonb_build_object('kind', 'none'); END IF;

  SELECT c.club_id INTO v_club FROM clubs c
   WHERE c.followers_open AND upper(c.follow_code) = v_code;
  IF v_club IS NOT NULL THEN
    RETURN jsonb_build_object('kind', 'club', 'club', club_follow_json(v_club, v_uid));
  END IF;

  SELECT t.team_id, t.team_name INTO v_team FROM teams t
   WHERE upper(trim(t.team_unique_code)) = v_code LIMIT 1;
  IF FOUND THEN
    RETURN jsonb_build_object('kind', 'team', 'team_id', v_team.team_id,
                              'team_name', v_team.team_name);
  END IF;
  RETURN jsonb_build_object('kind', 'none');
END $$;

CREATE OR REPLACE FUNCTION public.follow_club_by_code(p_code text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public'
AS $$
DECLARE
  v_uid  uuid := auth.uid();
  v_code text := upper(regexp_replace(COALESCE(p_code, ''), '\s', '', 'g'));
  v_club bigint;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501'; END IF;
  SELECT c.club_id INTO v_club FROM clubs c
   WHERE c.followers_open AND upper(c.follow_code) = v_code;
  IF v_club IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'unknown_code');
  END IF;
  INSERT INTO club_followers (user_id, club_id) VALUES (v_uid, v_club)
  ON CONFLICT DO NOTHING;
  RETURN jsonb_build_object('ok', true, 'club', club_follow_json(v_club, v_uid));
END $$;

CREATE OR REPLACE FUNCTION public.unfollow_club(p_club_id bigint)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public'
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501'; END IF;
  DELETE FROM club_followers WHERE user_id = auth.uid() AND club_id = p_club_id;
  RETURN jsonb_build_object('ok', true);
END $$;

-- Clubs the signed-in user follows, for v3 Home and the menu.
CREATE OR REPLACE FUNCTION public.get_my_followed_clubs()
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = 'public'
AS $$
  SELECT COALESCE(jsonb_agg(club_follow_json(f.club_id, auth.uid()) ORDER BY f.created_at), '[]'::jsonb)
    FROM club_followers f
    JOIN clubs c ON c.club_id = f.club_id AND c.followers_open
   WHERE f.user_id = auth.uid();
$$;

REVOKE ALL ON FUNCTION public.user_followed_clubs(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.club_follow_json(bigint, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.lookup_join_code(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.follow_club_by_code(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.unfollow_club(bigint) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_my_followed_clubs() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.lookup_join_code(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.follow_club_by_code(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unfollow_club(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_followed_clubs() TO authenticated;

-- ---------------------------------------------------------------------------
-- Messages: followers get club-wide messages sent to Everyone (and
-- CoachSmart-wide ones). Never team messages or role audiences. Same
-- signature; the member part is unchanged.
CREATE OR REPLACE FUNCTION public.app_message_audience(p_club_id bigint, p_team_ids bigint[], p_audience text, p_user uuid DEFAULT NULL::uuid)
 RETURNS TABLE(user_id uuid)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT DISTINCT uml.user_id
    FROM user_member_link uml
    JOIN users u            ON u.user_id = uml.user_id AND u.deleted_at IS NULL
    JOIN member_team_link mtl ON mtl.member_id = uml.member_id
                             AND COALESCE(mtl.status, 'active') = 'active'
    JOIN teams t            ON t.team_id = mtl.team_id
   WHERE COALESCE(uml.status, 'active') = 'active'
     AND (p_user IS NULL OR uml.user_id = p_user)
     AND CASE
           WHEN COALESCE(cardinality(p_team_ids), 0) > 0 THEN mtl.team_id = ANY (p_team_ids)
           WHEN p_club_id IS NOT NULL THEN t.club_id = p_club_id
           ELSE true
         END
     AND (COALESCE(p_audience, 'all') = 'all' OR EXISTS (
           SELECT 1
             FROM member_team_role_link mtrl
             JOIN roles r ON r.role_id = mtrl.role_id
            WHERE mtrl.member_team_id = mtl.member_team_id
              AND ((p_audience = 'players' AND r.role_level < 30)
                OR (p_audience = 'staff'   AND r.role_level >= 30))))
  UNION
  SELECT f.user_id
    FROM club_followers f
    JOIN clubs c ON c.club_id = f.club_id AND c.followers_open
    JOIN users u ON u.user_id = f.user_id AND u.deleted_at IS NULL
   WHERE COALESCE(cardinality(p_team_ids), 0) = 0
     AND COALESCE(p_audience, 'all') = 'all'
     AND (p_club_id IS NULL OR f.club_id = p_club_id)
     AND (p_user IS NULL OR f.user_id = p_user);
$function$;

-- ---------------------------------------------------------------------------
-- Club partner: followers see the club-wide sponsor of the clubs they follow.
CREATE OR REPLACE FUNCTION public.get_my_sponsors()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_today date := (now() AT TIME ZONE 'Europe/Dublin')::date;
  v_teams jsonb;
  v_sponsors jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('teams', '[]'::jsonb, 'sponsors', '[]'::jsonb);
  END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object('team_id', team_id, 'club_id', club_id)), '[]'::jsonb)
  INTO v_teams FROM sponsor_user_teams(v_uid);

  IF sponsor_is_child_login(v_uid) THEN
    RETURN jsonb_build_object('teams', v_teams, 'sponsors', '[]'::jsonb);
  END IF;

  SELECT coalesce(jsonb_agg(x ORDER BY x->>'club_id', x->>'team_id'), '[]'::jsonb) INTO v_sponsors
  FROM (
    SELECT DISTINCT ON (s.club_id, coalesce(s.team_id, 0)) jsonb_build_object(
      'sponsor_id', s.sponsor_id, 'club_id', s.club_id, 'team_id', s.team_id, 'name', s.name,
      'tagline', coalesce(s.tagline, ''), 'link_url', coalesce(s.link_url, ''),
      'logo_url', CASE WHEN s.logo_path IS NULL THEN ''
                       ELSE 'https://gyfporsbdftvtakdvukt.supabase.co/storage/v1/object/public/sponsors/' || s.logo_path END,
      'card_colour', coalesce(s.card_colour, ''), 'status', s.status,
      'on_home', s.on_home AND s.team_id IS NULL, 'on_events', s.on_events, 'on_live', s.on_live) AS x
    FROM club_sponsors s
    WHERE (s.club_id IN (SELECT club_id FROM sponsor_user_teams(v_uid))
           OR (s.team_id IS NULL AND s.club_id IN (SELECT club_id FROM user_followed_clubs(v_uid))))
      AND (s.starts_on IS NULL OR s.starts_on <= v_today)
      AND (s.ends_on IS NULL OR s.ends_on >= v_today)
      AND (s.status = 'live' OR (s.status = 'draft' AND sponsor_can_manage(v_uid, s.club_id)))
    ORDER BY s.club_id, coalesce(s.team_id, 0), (s.status = 'live') DESC, s.sponsor_id DESC
  ) q;

  RETURN jsonb_build_object('teams', v_teams, 'sponsors', v_sponsors);
END $function$;

-- ---------------------------------------------------------------------------
-- Live matches: a follower can watch and follow the club's matches, like
-- any club member (lm_can_view also gates get_live_match_v2 and
-- set_live_follow).
CREATE OR REPLACE FUNCTION public.lm_can_view(p_event_id bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1
      FROM public.events e
      JOIN public.teams et ON et.team_id = e.team_id
      JOIN public.teams t  ON t.club_id = et.club_id
      JOIN public.member_team_link mtl ON mtl.team_id = t.team_id AND mtl.status = 'active'
      JOIN public.user_member_link uml ON uml.member_id = mtl.member_id
     WHERE e.event_id = p_event_id
       AND uml.user_id = auth.uid()
  ) OR EXISTS (
    SELECT 1
      FROM public.events e
      JOIN public.teams et ON et.team_id = e.team_id
     WHERE e.event_id = p_event_id
       AND et.club_id IN (SELECT club_id FROM public.user_followed_clubs(auth.uid()))
  );
$function$;

-- Matches list: the clubs of my teams plus the clubs I follow; each row
-- now also carries club_id (v3 Home groups followed clubs by it).
CREATE OR REPLACE FUNCTION public.get_live_matches(p_upcoming_days integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid   uuid := auth.uid();
  v_today date := (now() AT TIME ZONE 'Europe/Dublin')::date;
  v_days  int  := LEAST(GREATEST(COALESCE(p_upcoming_days, 0), 0), 31);
BEGIN
  IF v_uid IS NULL THEN RETURN jsonb_build_object('error', 'not_signed_in'); END IF;

  RETURN jsonb_build_object(
    'server_now', now(),
    'default', COALESCE((SELECT jsonb_build_object('level', level, 'kickoff', kickoff, 'names', names)
                           FROM public.live_follows WHERE user_id = v_uid AND event_id IS NULL),
                        jsonb_build_object('level', 'result', 'kickoff', true, 'names', true)),
    'matches', COALESCE((
      WITH my_clubs AS (
        SELECT DISTINCT t.club_id
          FROM public.user_member_link uml
          JOIN public.member_team_link mtl ON mtl.member_id = uml.member_id AND mtl.status = 'active'
          JOIN public.teams t ON t.team_id = mtl.team_id
         WHERE uml.user_id = v_uid AND t.club_id IS NOT NULL
        UNION
        SELECT club_id FROM public.user_followed_clubs(v_uid)
      ),
      cand AS (
        SELECT e.event_id
          FROM public.events e
          JOIN public.teams t ON t.team_id = e.team_id
          LEFT JOIN public.event_types et ON et.event_type_id = e.event_type_id
         WHERE t.club_id IN (SELECT club_id FROM my_clubs)
           AND COALESCE(e.status, 'active') = 'active'
           AND (
             -- today's matches, or (v3 Upcoming) the next p_upcoming_days days
             ((e.event_date_time AT TIME ZONE 'UTC')::date BETWEEN v_today AND v_today + v_days
               AND (et.event_type IN ('Match', 'Friendly') OR EXISTS (SELECT 1 FROM public.match_stats ms WHERE ms.event_id = e.event_id)))
             -- live now, or finished in the last 12 hours (shown under Results)
             OR EXISTS (SELECT 1 FROM public.match_timer mt
                         WHERE mt.event_id = e.event_id
                           AND mt.kicked_off_at > now() - interval '12 hours')
             -- upcoming matches I follow (next 14 days)
             OR (e.event_id IN (SELECT f.event_id FROM public.live_follows f WHERE f.user_id = v_uid AND f.level <> 'off')
                 AND public.lm_event_at(e.event_date_time) BETWEEN now() - interval '1 day' AND now() + interval '14 days')
           )
      ),
      rows AS (
        SELECT cand.event_id, g.gkey, g.sid, g.summary, g.ord,
               count(g.gkey) OVER (PARTITION BY cand.event_id) AS n_groups
          FROM cand
          LEFT JOIN LATERAL (
            SELECT x.gkey, x.sid, x.summary, row_number() OVER () AS ord FROM public.lm_groups(cand.event_id) x
          ) g ON true
      )
      SELECT jsonb_agg(jsonb_build_object(
               'event_id',        e.event_id,
               'squad_key',       r.gkey,
               'squad_name',      CASE WHEN r.n_groups > 1 OR r.gkey > 0 THEN r.summary->>'name' END,
               'squad_colour',    r.summary->>'colour',
               'squads_in_event', r.n_groups,
               'event_date_time', COALESCE((r.summary->>'throw_in_at')::timestamptz, public.lm_event_at(e.event_date_time)),
               'team_name',       t.team_name,
               'club_id',         t.club_id,
               'club_name',       c.club_name,
               'sport',           COALESCE(c.sport_id, 1),
               'opposition',      COALESCE(r.summary->>'opposition', e.opposition),
               'venue',           COALESCE(r.summary->>'venue', e.location_name),
               'home_away',       e.home_away,
               'phase',           public.lm_phase(r.sid),
               'timer',           r.summary->'timer',
               'score',           CASE WHEN r.sid IS NULL THEN NULL ELSE r.summary->'score' END,
               'follow',          public.lm_my_follow(e.event_id)
             ) ORDER BY e.event_date_time, e.event_id, r.ord)
        FROM rows r
        JOIN public.events e ON e.event_id = r.event_id
        LEFT JOIN public.teams t ON t.team_id = e.team_id
        LEFT JOIN public.clubs c ON c.club_id = t.club_id
    ), '[]'::jsonb)
  );
END;
$function$;
