-- Live match: follow a match, get score alerts, watch it live
-- (webviews/match-live.html, webviews/matches.html, edge function live-match-alerts)
--
-- Everything is fed by the score keeper. Nothing here changes what the score
-- keeper saves; it only adds:
--   1. match_timer.phase: the score keeper says when it is half time / full time
--   2. live_follows:      who wants alerts for which match (or for all their teams)
--   3. live_links:        view-only share links (no account needed, no names)
--   4. live_pulse:        a tiny public "something changed" row per match that
--                         viewers listen to with Realtime, then re-read
--   5. live_alert_log:    which scores / phases have been alerted already
--   6. triggers that bump the pulse and wake the alert function
--   7. RPCs for the live screen, the Matches list and follow settings
--
-- The triggers never let an alert problem stop a score from saving: every
-- side effect is wrapped and only raises a warning.

-- ── 1. match_timer.phase ──────────────────────────────────────────────────────
ALTER TABLE public.match_timer ADD COLUMN IF NOT EXISTS phase text;

-- sync_match_actions: same as 20261015000200, plus the phone's phase
CREATE OR REPLACE FUNCTION public.sync_match_actions(
  p_match_stats_id bigint,
  p_actions        jsonb,
  p_timer          jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_uid     uuid := auth.uid();
  v_event   bigint;
  v_team    bigint;
  a         jsonb;
  v_id      uuid;
  v_target  uuid;
  v_row     bigint;
  v_member  bigint;
  v_done    jsonb := '[]'::jsonb;
BEGIN
  SELECT ms.event_id, e.team_id INTO v_event, v_team
    FROM public.match_stats ms
    JOIN public.events e ON e.event_id = ms.event_id
   WHERE ms.id = p_match_stats_id AND ms.user_id = v_uid;
  IF v_event IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  FOR a IN SELECT * FROM jsonb_array_elements(COALESCE(p_actions, '[]'::jsonb)) LOOP
    v_id := (a->>'id')::uuid;
    v_target := CASE WHEN a->>'target' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
                     THEN (a->>'target')::uuid END;
    v_row    := CASE WHEN a->>'target' ~ '^srv-[0-9]+$' THEN substring(a->>'target' FROM 5)::bigint END;

    v_member := NULLIF(a->>'member_id', '')::bigint;
    IF v_member IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM public.member_team_link mtl
       WHERE mtl.member_id = v_member AND mtl.team_id = v_team
    ) THEN
      v_member := NULL;
    END IF;

    CASE a->>'type'
      WHEN 'score', 'correction' THEN
        INSERT INTO public.match_stats_details (
          match_stats_id, score_type, side, count, event_second, timer_status, half,
          client_id, member_id, kind
        ) VALUES (
          p_match_stats_id,
          (a->>'score_type')::bigint,
          a->>'side',
          CASE WHEN a->>'type' = 'correction' THEN COALESCE((a->>'count')::smallint, 0) ELSE 1 END,
          LEAST(GREATEST(COALESCE((a->>'second')::int, 0), 0), 32767)::smallint,
          CASE WHEN a->>'timer_status' IN ('running', 'paused', 'stopped') THEN a->>'timer_status' ELSE 'paused' END,
          COALESCE((a->>'half')::int, 1),
          v_id,
          v_member,
          a->>'type'
        )
        ON CONFLICT (client_id) DO NOTHING;

      WHEN 'edit' THEN
        UPDATE public.match_stats_details d
           SET score_type = COALESCE((a->>'score_type')::bigint, d.score_type),
               side       = COALESCE(a->>'side', d.side),
               member_id  = CASE WHEN a ? 'member_id' THEN v_member ELSE d.member_id END
         WHERE d.match_stats_id = p_match_stats_id AND (d.client_id = v_target OR d.id = v_row);

      WHEN 'remove' THEN
        DELETE FROM public.match_stats_details d
         WHERE d.match_stats_id = p_match_stats_id AND (d.client_id = v_target OR d.id = v_row);

      WHEN 'sub' THEN
        INSERT INTO public.match_subs (match_stats_id, client_id, half, event_second, member_off, member_on)
        VALUES (
          p_match_stats_id, v_id,
          COALESCE((a->>'half')::int, 1),
          GREATEST(COALESCE((a->>'second')::int, 0), 0),
          (SELECT mtl.member_id FROM public.member_team_link mtl
            WHERE mtl.member_id = NULLIF(a->>'member_off', '')::bigint AND mtl.team_id = v_team LIMIT 1),
          (SELECT mtl.member_id FROM public.member_team_link mtl
            WHERE mtl.member_id = NULLIF(a->>'member_on', '')::bigint AND mtl.team_id = v_team LIMIT 1)
        )
        ON CONFLICT (client_id) DO NOTHING;

      WHEN 'remove_sub' THEN
        DELETE FROM public.match_subs s
         WHERE s.match_stats_id = p_match_stats_id AND (s.client_id = v_target OR s.id = v_row);

      ELSE
        NULL;
    END CASE;

    v_done := v_done || to_jsonb(v_id::text);
  END LOOP;

  IF p_timer IS NOT NULL THEN
    UPDATE public.match_timer mt
       SET status           = CASE WHEN p_timer->>'status' IN ('running', 'paused') THEN p_timer->>'status' ELSE mt.status END,
           started_at       = NULLIF(p_timer->>'started_at', '')::timestamptz,
           elapsed_seconds  = COALESCE((p_timer->>'elapsed_seconds')::int, mt.elapsed_seconds),
           current_half     = COALESCE((p_timer->>'current_half')::int, mt.current_half),
           duration_seconds = COALESCE((p_timer->>'duration_seconds')::int, mt.duration_seconds),
           injury_seconds   = COALESCE((p_timer->>'injury_seconds')::int, mt.injury_seconds),
           phase            = CASE WHEN p_timer->>'phase' IN ('setup', 'play', 'ht', 'ft', 'done')
                                   THEN p_timer->>'phase' ELSE mt.phase END,
           updated_at       = now()
     WHERE mt.event_id = v_event AND mt.user_id = v_uid;
  END IF;

  RETURN jsonb_build_object('done', v_done);
END;
$$;
REVOKE ALL ON FUNCTION public.sync_match_actions(bigint, jsonb, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sync_match_actions(bigint, jsonb, jsonb) TO authenticated;

-- ── 2. Tables ────────────────────────────────────────────────────────────────
-- event_id NULL = the user's default for all their own teams' matches.
-- level: all (every score) | goals (goals + HT/FT) | result (HT/FT) | off
CREATE TABLE IF NOT EXISTS public.live_follows (
  id         bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  user_id    uuid NOT NULL,
  event_id   bigint REFERENCES public.events(event_id) ON DELETE CASCADE,
  level      text NOT NULL DEFAULT 'result' CHECK (level IN ('all', 'goals', 'result', 'off')),
  kickoff    boolean NOT NULL DEFAULT true,
  names      boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS live_follows_user_event_key
  ON public.live_follows (user_id, COALESCE(event_id, 0));
CREATE INDEX IF NOT EXISTS live_follows_event_idx ON public.live_follows (event_id);

CREATE TABLE IF NOT EXISTS public.live_links (
  event_id   bigint PRIMARY KEY REFERENCES public.events(event_id) ON DELETE CASCADE,
  token      uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.live_pulse (
  event_id   bigint PRIMARY KEY,
  ver        bigint NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.live_alert_log (
  match_stats_id bigint PRIMARY KEY REFERENCES public.match_stats(id) ON DELETE CASCADE,
  last_detail_id bigint NOT NULL DEFAULT 0,
  phases         text[] NOT NULL DEFAULT '{}',
  pending_since  timestamptz,
  updated_at     timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.live_follows   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_links     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_pulse     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_alert_log ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.live_follows, public.live_links, public.live_alert_log FROM anon, authenticated;
REVOKE ALL ON public.live_pulse FROM anon, authenticated;
GRANT SELECT ON public.live_pulse TO anon, authenticated;

-- The pulse holds only an event id and a counter, so anyone may read it.
-- Viewers listen to it with Realtime and then fetch through the RPCs below.
DROP POLICY IF EXISTS live_pulse_read ON public.live_pulse;
CREATE POLICY live_pulse_read ON public.live_pulse FOR SELECT TO anon, authenticated USING (true);

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime')
     AND NOT EXISTS (SELECT 1 FROM pg_publication_tables
                      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'live_pulse') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.live_pulse;
  END IF;
END $$;

-- ── 3. Helpers ───────────────────────────────────────────────────────────────
-- Can the caller see this match? Anyone with an active place in any team of
-- the same club.
CREATE OR REPLACE FUNCTION public.lm_can_view(p_event_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT EXISTS (
    SELECT 1
      FROM public.events e
      JOIN public.teams et ON et.team_id = e.team_id
      JOIN public.teams t  ON t.club_id = et.club_id
      JOIN public.member_team_link mtl ON mtl.team_id = t.team_id AND mtl.status = 'active'
      JOIN public.user_member_link uml ON uml.member_id = mtl.member_id
     WHERE e.event_id = p_event_id
       AND uml.user_id = auth.uid()
  );
$$;
REVOKE ALL ON FUNCTION public.lm_can_view(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.lm_can_view(bigint) TO authenticated;

-- The score keeper session to show for a match: the active one with the most
-- recent activity, else the latest finalised one.
CREATE OR REPLACE FUNCTION public.lm_session_id(p_event_id bigint)
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT ms.id
    FROM public.match_stats ms
    LEFT JOIN public.match_timer mt ON mt.event_id = ms.event_id AND mt.user_id = ms.user_id
   WHERE ms.event_id = p_event_id AND ms.status IN ('active', 'finalised')
   ORDER BY (ms.status = 'active') DESC,
            GREATEST(mt.updated_at, (SELECT max(d.created_at) FROM public.match_stats_details d WHERE d.match_stats_id = ms.id), ms.created_at) DESC NULLS LAST,
            ms.id DESC
   LIMIT 1;
$$;
REVOKE ALL ON FUNCTION public.lm_session_id(bigint) FROM PUBLIC, anon, authenticated;

-- pre | play | ht | ft | done
CREATE OR REPLACE FUNCTION public.lm_phase(p_session bigint)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT CASE
    WHEN ms.id IS NULL THEN 'pre'
    WHEN ms.status = 'finalised' THEN 'done'
    WHEN mt.id IS NULL THEN 'pre'
    WHEN mt.phase = 'setup' THEN 'pre'
    WHEN mt.phase IN ('play', 'ht', 'ft', 'done') THEN mt.phase
    WHEN mt.status = 'running' THEN 'play'
    WHEN mt.elapsed_seconds >= mt.duration_seconds + mt.injury_seconds AND mt.duration_seconds > 0
      THEN CASE WHEN mt.current_half >= 2 THEN 'ft' ELSE 'ht' END
    WHEN mt.elapsed_seconds = 0 AND mt.current_half = 1
         AND NOT EXISTS (SELECT 1 FROM public.match_stats_details d WHERE d.match_stats_id = ms.id) THEN 'pre'
    ELSE 'play'
  END
    FROM (SELECT p_session AS sid) x
    LEFT JOIN public.match_stats ms ON ms.id = x.sid
    LEFT JOIN public.match_timer mt ON mt.event_id = ms.event_id AND mt.user_id = ms.user_id;
$$;
REVOKE ALL ON FUNCTION public.lm_phase(bigint) FROM PUBLIC, anon, authenticated;

-- Running score for a session: {us:{g,p,t}, opp:{g,p,t}}
CREATE OR REPLACE FUNCTION public.lm_score(p_session bigint)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  WITH r AS (
    SELECT d.side,
           SUM(CASE WHEN mst.score_value = 3 THEN COALESCE(d.count, 1) ELSE 0 END) AS g,
           SUM(CASE WHEN mst.score_value IN (1, 2) THEN COALESCE(d.count, 1) * mst.score_value ELSE 0 END) AS p
      FROM public.match_stats_details d
      JOIN public.match_stat_types mst ON mst.id = d.score_type
     WHERE d.match_stats_id = p_session AND mst.score_value IS NOT NULL
     GROUP BY d.side
  )
  SELECT jsonb_build_object(
    'us',  jsonb_build_object('g', COALESCE(u.g, 0), 'p', COALESCE(u.p, 0), 't', COALESCE(u.g, 0) * 3 + COALESCE(u.p, 0)),
    'opp', jsonb_build_object('g', COALESCE(o.g, 0), 'p', COALESCE(o.p, 0), 't', COALESCE(o.g, 0) * 3 + COALESCE(o.p, 0))
  )
  FROM (SELECT 1) one
  LEFT JOIN r u ON u.side = 'us'
  LEFT JOIN r o ON o.side = 'opp';
$$;
REVOKE ALL ON FUNCTION public.lm_score(bigint) FROM PUBLIC, anon, authenticated;

-- Everything the live screen shows. p_names = false hides player names
-- (public share links).
CREATE OR REPLACE FUNCTION public.lm_state(p_event_id bigint, p_names boolean)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_sid  bigint := public.lm_session_id(p_event_id);
  v_ms   public.match_stats%ROWTYPE;
  v_team bigint;
BEGIN
  SELECT * INTO v_ms FROM public.match_stats WHERE id = v_sid;
  SELECT team_id INTO v_team FROM public.events WHERE event_id = p_event_id;

  RETURN jsonb_build_object(
    'server_now', now(),
    'phase',      public.lm_phase(v_sid),
    'event', (
      SELECT jsonb_build_object(
        'event_id',         e.event_id,
        'event_date_time',  e.event_date_time,
        'event_title',      e.event_title,
        'opposition',       COALESCE(NULLIF(v_ms.opposition, ''), NULLIF(mt.opposition, ''), e.opposition),
        'home_away',        e.home_away,
        'location_name',    e.location_name,
        'team_id',          e.team_id,
        'team_name',        t.team_name,
        'club_name',        c.club_name,
        'crest',            c.crest,
        'primary_colour',   c.primary_colour,
        'secondary_colour', c.secondary_colour,
        'event_code',       ec.event_code,
        'event_type',       et.event_type
      )
      FROM public.events e
      LEFT JOIN public.teams t        ON t.team_id = e.team_id
      LEFT JOIN public.clubs c        ON c.club_id = t.club_id
      LEFT JOIN public.event_codes ec ON ec.code_id = e.event_code_id
      LEFT JOIN public.event_types et ON et.event_type_id = e.event_type_id
      LEFT JOIN public.match_timer mt ON mt.event_id = e.event_id AND mt.user_id = v_ms.user_id
      WHERE e.event_id = p_event_id
    ),
    'timer', (
      SELECT jsonb_build_object(
        'status',           mt.status,
        'started_at',       mt.started_at,
        'elapsed_seconds',  mt.elapsed_seconds,
        'current_half',     mt.current_half,
        'duration_seconds', mt.duration_seconds,
        'injury_seconds',   mt.injury_seconds
      )
      FROM public.match_timer mt
      WHERE mt.event_id = p_event_id AND mt.user_id = v_ms.user_id
    ),
    'score', public.lm_score(v_sid),
    'score_types', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('id', mst.id, 'name', mst.score_type, 'value', mst.score_value))
        FROM public.match_stat_types mst
       WHERE mst.id IN (SELECT DISTINCT d.score_type FROM public.match_stats_details d WHERE d.match_stats_id = v_sid)
    ), '[]'::jsonb),
    'actions', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'id',     d.id,
               'type',   d.score_type,
               'side',   d.side,
               'kind',   d.kind,
               'count',  COALESCE(d.count, 1),
               'half',   d.half,
               'second', d.event_second,
               'member', CASE WHEN p_names AND d.side = 'us' THEN NULLIF(TRIM(CONCAT(m.first_name, ' ', m.last_name)), '') END
             ) ORDER BY d.half, d.event_second, d.created_at)
        FROM public.match_stats_details d
        LEFT JOIN public.members m ON m.member_id = d.member_id
       WHERE d.match_stats_id = v_sid
    ), '[]'::jsonb),
    'subs', CASE WHEN NOT p_names THEN '[]'::jsonb ELSE COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'half',   s.half,
               'second', s.event_second,
               'off',    NULLIF(TRIM(CONCAT(moff.first_name, ' ', moff.last_name)), ''),
               'on',     NULLIF(TRIM(CONCAT(mon.first_name, ' ', mon.last_name)), '')
             ) ORDER BY s.half, s.event_second, s.created_at)
        FROM public.match_subs s
        LEFT JOIN public.members moff ON moff.member_id = s.member_off
        LEFT JOIN public.members mon  ON mon.member_id  = s.member_on
       WHERE s.match_stats_id = v_sid
    ), '[]'::jsonb) END
  );
END;
$$;
REVOKE ALL ON FUNCTION public.lm_state(bigint, boolean) FROM PUBLIC, anon, authenticated;

-- The caller's alert setting for a match: their own choice for it, else their
-- default for their teams (team members only), else nothing.
CREATE OR REPLACE FUNCTION public.lm_my_follow(p_event_id bigint)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  WITH me AS (SELECT auth.uid() AS uid),
  own AS (
    SELECT EXISTS (
      SELECT 1 FROM public.events e
        JOIN public.member_team_link mtl ON mtl.team_id = e.team_id AND mtl.status = 'active'
        JOIN public.user_member_link uml ON uml.member_id = mtl.member_id
       WHERE e.event_id = p_event_id AND uml.user_id = (SELECT uid FROM me)
    ) AS is_own
  ),
  ev AS (SELECT * FROM public.live_follows f WHERE f.user_id = (SELECT uid FROM me) AND f.event_id = p_event_id),
  df AS (SELECT * FROM public.live_follows f WHERE f.user_id = (SELECT uid FROM me) AND f.event_id IS NULL)
  SELECT CASE
    WHEN EXISTS (SELECT 1 FROM ev) THEN
      (SELECT jsonb_build_object('level', level, 'kickoff', kickoff, 'names', names, 'source', 'match', 'own_team', (SELECT is_own FROM own)) FROM ev)
    WHEN (SELECT is_own FROM own) THEN
      COALESCE((SELECT jsonb_build_object('level', level, 'kickoff', kickoff, 'names', names, 'source', 'default', 'own_team', true) FROM df),
               jsonb_build_object('level', 'result', 'kickoff', true, 'names', true, 'source', 'default', 'own_team', true))
    ELSE jsonb_build_object('level', 'off', 'kickoff', false, 'names', true, 'source', 'none', 'own_team', false)
  END;
$$;
REVOKE ALL ON FUNCTION public.lm_my_follow(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.lm_my_follow(bigint) TO authenticated;

-- ── 4. RPCs for the pages ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_live_match(p_event_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN jsonb_build_object('error', 'not_signed_in'); END IF;
  IF NOT public.lm_can_view(p_event_id) THEN RETURN jsonb_build_object('error', 'not_allowed'); END IF;
  RETURN public.lm_state(p_event_id, true)
    || jsonb_build_object('follow', public.lm_my_follow(p_event_id),
                          'pulse', (SELECT ver FROM public.live_pulse WHERE event_id = p_event_id));
END;
$$;
REVOKE ALL ON FUNCTION public.get_live_match(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_live_match(bigint) TO authenticated;

-- Share links: view only, no player names, no account needed
CREATE OR REPLACE FUNCTION public.get_live_match_public(p_token uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_event bigint;
BEGIN
  SELECT l.event_id INTO v_event FROM public.live_links l WHERE l.token = p_token;
  IF v_event IS NULL THEN RETURN jsonb_build_object('error', 'link_not_found'); END IF;
  RETURN public.lm_state(v_event, false)
    || jsonb_build_object('public', true, 'pulse', (SELECT ver FROM public.live_pulse WHERE event_id = v_event));
END;
$$;
REVOKE ALL ON FUNCTION public.get_live_match_public(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_live_match_public(uuid) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_live_share_link(p_event_id bigint)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_token uuid;
BEGIN
  IF NOT public.lm_can_view(p_event_id) THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.live_links (event_id, created_by) VALUES (p_event_id, auth.uid())
  ON CONFLICT (event_id) DO NOTHING;
  SELECT token INTO v_token FROM public.live_links WHERE event_id = p_event_id;
  RETURN v_token;
END;
$$;
REVOKE ALL ON FUNCTION public.get_live_share_link(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_live_share_link(bigint) TO authenticated;

-- p_event_id NULL sets the default for all the caller's own teams.
-- p_level NULL with an event removes the match's own setting (back to default).
CREATE OR REPLACE FUNCTION public.set_live_follow(
  p_event_id bigint,
  p_level    text,
  p_kickoff  boolean DEFAULT true,
  p_names    boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501'; END IF;
  IF p_event_id IS NOT NULL AND NOT public.lm_can_view(p_event_id) THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;
  IF p_level IS NOT NULL AND p_level NOT IN ('all', 'goals', 'result', 'off') THEN
    RAISE EXCEPTION 'Bad level' USING ERRCODE = '22023';
  END IF;

  IF p_level IS NULL THEN
    DELETE FROM public.live_follows WHERE user_id = v_uid AND event_id IS NOT DISTINCT FROM p_event_id;
  ELSE
    UPDATE public.live_follows
       SET level = p_level, kickoff = COALESCE(p_kickoff, true), names = COALESCE(p_names, true), updated_at = now()
     WHERE user_id = v_uid AND event_id IS NOT DISTINCT FROM p_event_id;
    IF NOT FOUND THEN
      INSERT INTO public.live_follows (user_id, event_id, level, kickoff, names)
      VALUES (v_uid, p_event_id, p_level, COALESCE(p_kickoff, true), COALESCE(p_names, true));
    END IF;
  END IF;

  RETURN CASE WHEN p_event_id IS NULL THEN '{}'::jsonb ELSE public.lm_my_follow(p_event_id) END;
END;
$$;
REVOKE ALL ON FUNCTION public.set_live_follow(bigint, text, boolean, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_live_follow(bigint, text, boolean, boolean) TO authenticated;

-- The Matches list: today's matches across the caller's clubs, anything live
-- now (started in the last 8 hours), and upcoming matches they follow.
CREATE OR REPLACE FUNCTION public.get_live_matches()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_uid   uuid := auth.uid();
  v_today date := (now() AT TIME ZONE 'Europe/Dublin')::date;
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
      ),
      cand AS (
        SELECT e.event_id, public.lm_session_id(e.event_id) AS sid
          FROM public.events e
          JOIN public.teams t ON t.team_id = e.team_id
          LEFT JOIN public.event_types et ON et.event_type_id = e.event_type_id
         WHERE t.club_id IN (SELECT club_id FROM my_clubs)
           AND COALESCE(e.status, 'active') = 'active'
           AND (
             -- today's matches
             ((e.event_date_time AT TIME ZONE 'Europe/Dublin')::date = v_today
               AND (et.event_type IN ('Match', 'Friendly') OR EXISTS (SELECT 1 FROM public.match_stats ms WHERE ms.event_id = e.event_id)))
             -- live now
             OR EXISTS (SELECT 1 FROM public.match_timer mt
                         WHERE mt.event_id = e.event_id AND mt.updated_at > now() - interval '8 hours'
                           AND (mt.status = 'running' OR mt.phase IN ('play', 'ht')))
             -- upcoming matches I follow (next 14 days)
             OR (e.event_id IN (SELECT f.event_id FROM public.live_follows f WHERE f.user_id = v_uid AND f.level <> 'off')
                 AND e.event_date_time BETWEEN now() - interval '1 day' AND now() + interval '14 days')
           )
      )
      SELECT jsonb_agg(jsonb_build_object(
               'event_id',        e.event_id,
               'event_date_time', e.event_date_time,
               'team_name',       t.team_name,
               'club_name',       c.club_name,
               'opposition',      COALESCE(NULLIF(ms.opposition, ''), NULLIF(mt.opposition, ''), e.opposition),
               'home_away',       e.home_away,
               'phase',           public.lm_phase(cand.sid),
               'timer', CASE WHEN mt.id IS NULL THEN NULL ELSE jsonb_build_object(
                   'status', mt.status, 'started_at', mt.started_at, 'elapsed_seconds', mt.elapsed_seconds,
                   'current_half', mt.current_half, 'duration_seconds', mt.duration_seconds) END,
               'score',  CASE WHEN cand.sid IS NULL THEN NULL ELSE public.lm_score(cand.sid) END,
               'follow', public.lm_my_follow(e.event_id)
             ) ORDER BY e.event_date_time)
        FROM cand
        JOIN public.events e ON e.event_id = cand.event_id
        LEFT JOIN public.teams t ON t.team_id = e.team_id
        LEFT JOIN public.clubs c ON c.club_id = t.club_id
        LEFT JOIN public.match_stats ms ON ms.id = cand.sid
        LEFT JOIN public.match_timer mt ON mt.event_id = e.event_id AND mt.user_id = ms.user_id
    ), '[]'::jsonb)
  );
END;
$$;
REVOKE ALL ON FUNCTION public.get_live_matches() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_live_matches() TO authenticated;

-- ── 5. Alerts ────────────────────────────────────────────────────────────────
-- Who gets alerts for a match, and how: explicit choices for the match, else
-- team members on their default (result + kick-off unless they changed it).
-- Never the person keeping score. Only people with a phone registered.
CREATE OR REPLACE FUNCTION public.lm_alert_targets(p_event_id bigint, p_scorer uuid)
RETURNS TABLE (user_id uuid, level text, kickoff boolean, names boolean, fcm_token text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  WITH team_users AS (
    SELECT DISTINCT uml.user_id
      FROM public.events e
      JOIN public.member_team_link mtl ON mtl.team_id = e.team_id AND mtl.status = 'active'
      JOIN public.user_member_link uml ON uml.member_id = mtl.member_id
     WHERE e.event_id = p_event_id
  ),
  everyone AS (
    SELECT user_id FROM team_users
    UNION
    SELECT f.user_id FROM public.live_follows f WHERE f.event_id = p_event_id
  ),
  resolved AS (
    SELECT ev.user_id,
           COALESCE(fe.level,   CASE WHEN tu.user_id IS NOT NULL THEN COALESCE(fd.level, 'result') ELSE 'off' END) AS level,
           COALESCE(fe.kickoff, fd.kickoff, true) AS kickoff,
           COALESCE(fe.names,   fd.names,   true) AS names
      FROM everyone ev
      LEFT JOIN team_users tu ON tu.user_id = ev.user_id
      LEFT JOIN public.live_follows fe ON fe.user_id = ev.user_id AND fe.event_id = p_event_id
      LEFT JOIN public.live_follows fd ON fd.user_id = ev.user_id AND fd.event_id IS NULL
  )
  SELECT r.user_id, r.level, r.kickoff, r.names, u.fcm_token
    FROM resolved r
    JOIN public.users u ON u.user_id = r.user_id
   WHERE r.level <> 'off'
     AND r.user_id IS DISTINCT FROM p_scorer
     AND COALESCE(u.fcm_token, '') <> '';
$$;
REVOKE ALL ON FUNCTION public.lm_alert_targets(bigint, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.lm_alert_targets(bigint, uuid) TO service_role;

-- The alert function calls this to take the new scores and phases it should
-- tell people about. Scores are only taken once they are p_settle seconds old,
-- so a score undone straight away is never sent. Each score and each phase is
-- handed out once, even if several calls run at the same time.
-- more = true means newer scores are still settling: call again shortly.
CREATE OR REPLACE FUNCTION public.lm_alert_claim(p_match_stats_id bigint, p_settle int DEFAULT 8)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_log    public.live_alert_log%ROWTYPE;
  v_ms     public.match_stats%ROWTYPE;
  v_phase  text;
  v_new    jsonb;
  v_max    bigint;
  v_more   boolean;
  v_phases text[] := '{}';
  v_mt     public.match_timer%ROWTYPE;
BEGIN
  SELECT * INTO v_ms FROM public.match_stats WHERE id = p_match_stats_id;
  IF v_ms.id IS NULL THEN RETURN jsonb_build_object('items', '[]'::jsonb, 'phases', '[]'::jsonb, 'more', false); END IF;

  INSERT INTO public.live_alert_log (match_stats_id) VALUES (p_match_stats_id) ON CONFLICT DO NOTHING;
  SELECT * INTO v_log FROM public.live_alert_log WHERE match_stats_id = p_match_stats_id FOR UPDATE;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'id', d.id, 'type', mst.score_type, 'value', mst.score_value, 'side', d.side,
           'half', d.half, 'second', d.event_second,
           'member', NULLIF(TRIM(CONCAT(m.first_name, ' ', m.last_name)), '')
         ) ORDER BY d.id), '[]'::jsonb),
         max(d.id)
    INTO v_new, v_max
    FROM public.match_stats_details d
    JOIN public.match_stat_types mst ON mst.id = d.score_type
    LEFT JOIN public.members m ON m.member_id = d.member_id
   WHERE d.match_stats_id = p_match_stats_id
     AND d.id > v_log.last_detail_id
     AND d.kind = 'score'
     AND mst.score_value IS NOT NULL AND mst.score_value > 0
     AND d.created_at <= now() - make_interval(secs => p_settle);

  v_more := EXISTS (
    SELECT 1 FROM public.match_stats_details d
     WHERE d.match_stats_id = p_match_stats_id AND d.id > GREATEST(v_log.last_detail_id, COALESCE(v_max, 0))
       AND d.kind = 'score' AND d.created_at > now() - make_interval(secs => p_settle)
  );

  -- Phases: kick-off once the first half is under way, then HT and FT
  v_phase := public.lm_phase(p_match_stats_id);
  SELECT * INTO v_mt FROM public.match_timer mt WHERE mt.event_id = v_ms.event_id AND mt.user_id = v_ms.user_id;
  IF NOT ('ko' = ANY (v_log.phases)) AND (v_phase IN ('play', 'ht', 'ft', 'done')) THEN v_phases := v_phases || 'ko'::text; END IF;
  IF NOT ('ht' = ANY (v_log.phases)) AND (v_phase = 'ht' OR (v_phase IN ('play', 'ft', 'done') AND COALESCE(v_mt.current_half, 1) >= 2)) THEN
    -- Only alert half time while it is half time; a missed one is just marked done
    v_phases := v_phases || CASE WHEN v_phase = 'ht' THEN 'ht' ELSE 'ht-skip' END;
  END IF;
  IF NOT ('ft' = ANY (v_log.phases)) AND v_phase IN ('ft', 'done') THEN v_phases := v_phases || 'ft'::text; END IF;
  -- Half time / full time wait until the last scores have settled, so the
  -- result alert carries the final score and comes after them
  IF v_more THEN
    v_phases := array_remove(array_remove(v_phases, 'ht'), 'ft');
  END IF;
  -- A kick-off alert after the match is well under way is no use
  IF 'ko' = ANY (v_phases) AND (v_phase <> 'play' OR COALESCE(v_mt.current_half, 1) > 1) THEN
    v_phases := array_replace(v_phases, 'ko', 'ko-skip');
  END IF;

  UPDATE public.live_alert_log
     SET last_detail_id = GREATEST(last_detail_id, COALESCE(v_max, 0)),
         phases         = phases || array_replace(array_replace(v_phases, 'ht-skip', 'ht'), 'ko-skip', 'ko'),
         pending_since  = CASE WHEN v_more THEN pending_since ELSE NULL END,
         updated_at     = now()
   WHERE match_stats_id = p_match_stats_id;

  RETURN jsonb_build_object(
    'event_id', v_ms.event_id,
    'scorer',   v_ms.user_id,
    'phase',    v_phase,
    'items',    v_new,
    'phases',   to_jsonb(array_remove(array_remove(v_phases, 'ht-skip'), 'ko-skip')),
    'more',     v_more,
    'state',    public.lm_state(v_ms.event_id, true)
  );
END;
$$;
REVOKE ALL ON FUNCTION public.lm_alert_claim(bigint, int) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.lm_alert_claim(bigint, int) TO service_role;

-- Wake the alert function for a session (at most once while one is pending).
-- Uses the same vault signing key as check_and_send_notifications.
CREATE OR REPLACE FUNCTION public.lm_alert_wake(p_match_stats_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_secret text;
  v_jwt    text;
  v_go     boolean;
BEGIN
  INSERT INTO public.live_alert_log (match_stats_id, pending_since)
  VALUES (p_match_stats_id, now())
  ON CONFLICT (match_stats_id) DO UPDATE
     SET pending_since = now()
   WHERE live_alert_log.pending_since IS NULL OR live_alert_log.pending_since < now() - interval '2 minutes'
  RETURNING true INTO v_go;
  IF v_go IS NOT TRUE THEN RETURN; END IF;

  SELECT decrypted_secret INTO v_secret FROM vault.decrypted_secrets WHERE name = 'jwt_signing_secret' LIMIT 1;
  IF v_secret IS NULL THEN
    RAISE WARNING 'lm_alert_wake: jwt_signing_secret not found in vault';
    RETURN;
  END IF;
  SELECT extensions.sign(json_build_object(
           'role', 'service_role', 'iss', 'supabase', 'ref', 'gyfporsbdftvtakdvukt',
           'iat', extract(epoch from now())::integer, 'exp', (extract(epoch from now()) + 600)::integer
         )::json, v_secret) INTO v_jwt;

  PERFORM net.http_post(
    url     := 'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/live-match-alerts',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_jwt),
    body    := jsonb_build_object('match_stats_id', p_match_stats_id)
  );
END;
$$;
REVOKE ALL ON FUNCTION public.lm_alert_wake(bigint) FROM PUBLIC, anon, authenticated;

-- ── 6. Triggers ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.lm_bump(p_event_id bigint)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = 'public'
AS $$
  INSERT INTO public.live_pulse (event_id, ver, updated_at) VALUES (p_event_id, 1, now())
  ON CONFLICT (event_id) DO UPDATE SET ver = live_pulse.ver + 1, updated_at = now();
$$;
REVOKE ALL ON FUNCTION public.lm_bump(bigint) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.lm_on_detail()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_ms bigint := COALESCE(NEW.match_stats_id, OLD.match_stats_id);
BEGIN
  BEGIN
    PERFORM public.lm_bump((SELECT event_id FROM public.match_stats WHERE id = v_ms));
    IF TG_OP = 'INSERT' AND NEW.kind = 'score' THEN
      PERFORM public.lm_alert_wake(v_ms);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'lm_on_detail: %', SQLERRM;
  END;
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.lm_on_sub()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  BEGIN
    PERFORM public.lm_bump((SELECT event_id FROM public.match_stats WHERE id = COALESCE(NEW.match_stats_id, OLD.match_stats_id)));
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'lm_on_sub: %', SQLERRM;
  END;
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.lm_on_timer()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_ms bigint;
BEGIN
  BEGIN
    PERFORM public.lm_bump(NEW.event_id);
    IF TG_OP = 'INSERT'
       OR NEW.status IS DISTINCT FROM OLD.status
       OR NEW.phase IS DISTINCT FROM OLD.phase
       OR NEW.current_half IS DISTINCT FROM OLD.current_half THEN
      SELECT ms.id INTO v_ms FROM public.match_stats ms
       WHERE ms.event_id = NEW.event_id AND ms.user_id = NEW.user_id AND ms.status = 'active'
       ORDER BY ms.id DESC LIMIT 1;
      IF v_ms IS NOT NULL THEN PERFORM public.lm_alert_wake(v_ms); END IF;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'lm_on_timer: %', SQLERRM;
  END;
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.lm_on_session()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  BEGIN
    PERFORM public.lm_bump(NEW.event_id);
    IF NEW.status = 'finalised' AND OLD.status IS DISTINCT FROM 'finalised' THEN
      PERFORM public.lm_alert_wake(NEW.id);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'lm_on_session: %', SQLERRM;
  END;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS lm_detail_trg  ON public.match_stats_details;
DROP TRIGGER IF EXISTS lm_sub_trg     ON public.match_subs;
DROP TRIGGER IF EXISTS lm_timer_trg   ON public.match_timer;
DROP TRIGGER IF EXISTS lm_session_trg ON public.match_stats;
CREATE TRIGGER lm_detail_trg  AFTER INSERT OR UPDATE OR DELETE ON public.match_stats_details FOR EACH ROW EXECUTE FUNCTION public.lm_on_detail();
CREATE TRIGGER lm_sub_trg     AFTER INSERT OR DELETE ON public.match_subs FOR EACH ROW EXECUTE FUNCTION public.lm_on_sub();
CREATE TRIGGER lm_timer_trg   AFTER INSERT OR UPDATE ON public.match_timer FOR EACH ROW EXECUTE FUNCTION public.lm_on_timer();
CREATE TRIGGER lm_session_trg AFTER UPDATE OF status ON public.match_stats FOR EACH ROW EXECUTE FUNCTION public.lm_on_session();

-- The alert function calls this when it has been running a long time while
-- scores keep coming in: it hands over to a fresh run.
CREATE OR REPLACE FUNCTION public.lm_alert_rewake(p_match_stats_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  UPDATE public.live_alert_log SET pending_since = NULL WHERE match_stats_id = p_match_stats_id;
  PERFORM public.lm_alert_wake(p_match_stats_id);
END;
$$;
REVOKE ALL ON FUNCTION public.lm_alert_rewake(bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.lm_alert_rewake(bigint) TO service_role;
