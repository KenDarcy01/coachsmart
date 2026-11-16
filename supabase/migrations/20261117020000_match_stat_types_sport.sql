-- Multi-sport step 4: score keeper types for soccer and rugby (v3 only).
--
-- match_stat_types gets a sport (default 1 = GAA, so every existing type stays
-- GAA). Soccer (2) and rugby (3) types are added. A RESTRICTIVE select policy
-- hides non-GAA types from direct table reads, so the old app (match-timer
-- webview, which reads the table) sees exactly the types it sees today. v3
-- gets its types from get_score_keeper_state, which now returns only the
-- types of the team's club sport and says which sport that is.
--
-- lm_score (live score, shared link, alerts) stays identical for GAA. For
-- soccer and rugby there are no goals in the GAA sense: g is 0, p and t are
-- the total, and the result carries "sport" so pages show a plain total.

ALTER TABLE public.match_stat_types
  ADD COLUMN IF NOT EXISTS sport_id bigint NOT NULL DEFAULT 1 REFERENCES public.sport(sport_id);

CREATE INDEX IF NOT EXISTS match_stat_types_sport_id_idx ON public.match_stat_types (sport_id);

-- Soccer and rugby types (categories: 1 scores, 2 errors, 3 set plays)
INSERT INTO public.match_stat_types
  (score_type, abbreviated_name, score_category, score_value, status, default_button, score_source, sport_id)
SELECT v.* FROM (VALUES
  -- Soccer
  ('Goal',           'G',   1::bigint, 1::smallint,    true, true,  false, 2::bigint),
  ('Shot on target', 'ON',  1, NULL::smallint,          true, true,  false, 2),
  ('Shot off target','OFF', 1, NULL,                    true, true,  false, 2),
  ('Corner',         'C',   3, NULL,                    true, true,  true,  2),
  ('Free kick',      'FK',  2, NULL,                    true, true,  true,  2),
  ('Penalty',        'PEN', 2, NULL,                    true, false, true,  2),
  ('Yellow card',    'YC',  2, NULL,                    true, true,  false, 2),
  ('Red card',       'RC',  2, NULL,                    true, false, false, 2),
  ('Offside',        'OS',  2, NULL,                    true, false, false, 2),
  ('Turnover',       'TO',  2, NULL,                    true, false, false, 2),
  ('Goal kick',      'GK',  3, NULL,                    true, false, false, 2),
  ('Throw-in',       'TI',  3, NULL,                    true, false, false, 2),
  -- Rugby
  ('Try',            'T',   1, 5,                       true, true,  false, 3),
  ('Conversion',     'C',   1, 2,                       true, true,  false, 3),
  ('Penalty goal',   'PG',  1, 3,                       true, true,  false, 3),
  ('Drop goal',      'DG',  1, 3,                       true, false, false, 3),
  ('Penalty try',    'PT',  1, 7,                       true, false, false, 3),
  ('Missed kick',    'MK',  1, NULL,                    true, true,  false, 3),
  ('Penalty',        'P',   2, NULL,                    true, true,  false, 3),
  ('Yellow card',    'YC',  2, NULL,                    true, true,  false, 3),
  ('Red card',       'RC',  2, NULL,                    true, false, false, 3),
  ('Turnover',       'TO',  2, NULL,                    true, false, false, 3),
  ('Lineout',        'LO',  3, NULL,                    true, false, false, 3),
  ('Scrum',          'SC',  3, NULL,                    true, false, false, 3)
) AS v(score_type, abbreviated_name, score_category, score_value, status, default_button, score_source, sport_id)
WHERE NOT EXISTS (
  SELECT 1 FROM public.match_stat_types t
   WHERE t.score_type = v.score_type AND t.sport_id = v.sport_id
);

-- Direct reads (the old app) only ever see GAA types
DROP POLICY IF EXISTS match_stat_types_gaa_only ON public.match_stat_types;
CREATE POLICY match_stat_types_gaa_only ON public.match_stat_types
  AS RESTRICTIVE FOR SELECT TO anon, authenticated
  USING (sport_id = 1);

-- The sport a team plays (its club's), GAA when not set
CREATE OR REPLACE FUNCTION public.team_sport_id(p_team_id bigint)
RETURNS bigint
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT COALESCE((SELECT c.sport_id FROM public.teams t JOIN public.clubs c ON c.club_id = t.club_id
                    WHERE t.team_id = p_team_id), 1);
$$;
REVOKE ALL ON FUNCTION public.team_sport_id(bigint) FROM PUBLIC, anon, authenticated;

-- Live score. GAA: unchanged. Soccer/rugby: total only, plus "sport".
CREATE OR REPLACE FUNCTION public.lm_score(p_session bigint)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = 'public'
AS $function$
  WITH sp AS (
    SELECT COALESCE((SELECT public.team_sport_id(e.team_id)
                       FROM public.match_stats ms JOIN public.events e ON e.event_id = ms.event_id
                      WHERE ms.id = p_session), 1) AS id
  ), r AS (
    SELECT d.side,
           SUM(CASE WHEN sp.id = 1 AND mst.score_value = 3 THEN COALESCE(d.count, 1) ELSE 0 END) AS g,
           SUM(CASE WHEN sp.id = 1 AND mst.score_value IN (1, 2) THEN COALESCE(d.count, 1) * mst.score_value
                    WHEN sp.id <> 1 THEN COALESCE(d.count, 1) * mst.score_value
                    ELSE 0 END) AS p
      FROM public.match_stats_details d
      JOIN public.match_stat_types mst ON mst.id = d.score_type
      CROSS JOIN sp
     WHERE d.match_stats_id = p_session AND mst.score_value IS NOT NULL
     GROUP BY d.side
  )
  -- Soccer/rugby: "sport" on the score and on each side, so pages that only
  -- see one side ({g, p, t}) can still show a plain total.
  SELECT jsonb_build_object(
    'us',  jsonb_build_object('g', COALESCE(u.g, 0), 'p', COALESCE(u.p, 0), 't', COALESCE(u.g, 0) * 3 + COALESCE(u.p, 0)) || x.tag,
    'opp', jsonb_build_object('g', COALESCE(o.g, 0), 'p', COALESCE(o.p, 0), 't', COALESCE(o.g, 0) * 3 + COALESCE(o.p, 0)) || x.tag
  ) || x.tag
  FROM sp
  CROSS JOIN LATERAL (SELECT CASE WHEN sp.id <> 1 THEN jsonb_build_object('sport', sp.id) ELSE '{}'::jsonb END AS tag) x
  LEFT JOIN r u ON u.side = 'us'
  LEFT JOIN r o ON o.side = 'opp';
$function$;

-- Score keeper state: the types of the team's sport only, and the sport.
CREATE OR REPLACE FUNCTION public.get_score_keeper_state(p_event_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_uid       uuid := auth.uid();
  v_team_id   bigint;
  v_member    boolean;
  v_session   public.match_stats%ROWTYPE;
  v_squad_id  bigint;
  v_sport     bigint;
  v_result    jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('error', 'not_signed_in');
  END IF;

  SELECT e.team_id INTO v_team_id FROM public.events e WHERE e.event_id = p_event_id;
  IF v_team_id IS NULL THEN
    RETURN jsonb_build_object('error', 'event_not_found');
  END IF;

  v_member := public.sk_is_team_member(v_team_id);
  v_sport  := public.team_sport_id(v_team_id);

  -- The caller's active session, else their most recent finalised one
  SELECT * INTO v_session
    FROM public.match_stats ms
   WHERE ms.event_id = p_event_id AND ms.user_id = v_uid AND ms.status IN ('active', 'finalised')
   ORDER BY (ms.status = 'active') DESC, ms.id DESC
   LIMIT 1;

  SELECT mt.squad_id INTO v_squad_id
    FROM public.match_timer mt
   WHERE mt.event_id = p_event_id AND mt.user_id = v_uid;
  v_squad_id := COALESCE(v_session.squad_id, v_squad_id);

  SELECT jsonb_build_object(
    'event', (
      SELECT jsonb_build_object(
        'event_id',        e.event_id,
        'event_date_time', e.event_date_time,
        'event_title',     e.event_title,
        'opposition',      e.opposition,
        'team_id',         e.team_id,
        'team_name',       t.team_name,
        'club_name',       c.club_name,
        'primary_colour',  c.primary_colour,
        'secondary_colour',c.secondary_colour,
        'event_code',      ec.event_code,
        'event_type',      et.event_type,
        'sport_id',        v_sport
      )
      FROM public.events e
      LEFT JOIN public.teams t        ON t.team_id = e.team_id
      LEFT JOIN public.clubs c        ON c.club_id = t.club_id
      LEFT JOIN public.event_codes ec ON ec.code_id = e.event_code_id
      LEFT JOIN public.event_types et ON et.event_type_id = e.event_type_id
      WHERE e.event_id = p_event_id
    ),
    'is_member', v_member,
    'timer', (
      SELECT to_jsonb(mt) - 'user_id'
        FROM public.match_timer mt
       WHERE mt.event_id = p_event_id AND mt.user_id = v_uid
    ),
    'session', CASE WHEN v_session.id IS NULL THEN NULL ELSE jsonb_build_object(
      'id',           v_session.id,
      'status',       v_session.status,
      'opposition',   v_session.opposition,
      'squad_id',     v_session.squad_id,
      'finalised_at', v_session.finalised_at
    ) END,
    'squads', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('squad_id', s.squad_id, 'squad_name', s.squad_name)
                       ORDER BY s.squad_list_seq NULLS LAST, s.squad_name)
        FROM public.squads s WHERE s.team_id = v_team_id
    ), '[]'::jsonb),
    -- Every active stat type of the team's sport, so voice can record any of
    -- them. button = shown as a Tap button: the team's own list if it has one,
    -- else the types marked default_button.
    'score_types', COALESCE((
      WITH linked AS (
        SELECT l.match_score_type_id AS id
          FROM public.match_stat_type_team_link l
          JOIN public.match_stat_types mst ON mst.id = l.match_score_type_id
         WHERE l.team_id = v_team_id AND l.status IS TRUE AND mst.status IS TRUE
           AND mst.sport_id = v_sport
      )
      SELECT jsonb_agg(jsonb_build_object(
               'id',               mst.id,
               'score_type',       mst.score_type,
               'abbreviated_name', mst.abbreviated_name,
               'score_value',      mst.score_value,
               'category',         COALESCE(cat.score_category, 'other'),
               'source',           mst.score_source,
               'button',           CASE WHEN EXISTS (SELECT 1 FROM linked)
                                        THEN mst.id IN (SELECT id FROM linked)
                                        ELSE mst.default_button END
             ) ORDER BY mst.score_category NULLS LAST, mst.score_value DESC NULLS LAST, mst.id)
        FROM public.match_stat_types mst
        LEFT JOIN public.match_stat_categories cat ON cat.id = mst.score_category
       WHERE mst.status IS TRUE AND mst.sport_id = v_sport
    ), '[]'::jsonb),
    'actions', CASE WHEN v_session.id IS NULL THEN '[]'::jsonb ELSE COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'id',          COALESCE(d.client_id::text, 'srv-' || d.id),
               'kind',        d.kind,
               'score_type',  d.score_type,
               'side',        d.side,
               'count',       COALESCE(d.count, 1),
               'second',      d.event_second,
               'half',        d.half,
               'member_id',   d.member_id,
               'from_type',   d.from_type,
               'created_at',  d.created_at
             ) ORDER BY d.half, d.event_second, d.created_at)
        FROM public.match_stats_details d
       WHERE d.match_stats_id = v_session.id
    ), '[]'::jsonb) END,
    'subs', CASE WHEN v_session.id IS NULL THEN '[]'::jsonb ELSE COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'id',         COALESCE(s.client_id::text, 'srv-' || s.id),
               'half',       s.half,
               'second',     s.event_second,
               'member_off', s.member_off,
               'member_on',  s.member_on
             ) ORDER BY s.half, s.event_second, s.created_at)
        FROM public.match_subs s
       WHERE s.match_stats_id = v_session.id
    ), '[]'::jsonb) END,
    -- Latest saved line-up from the team selector (for this squad if one is set)
    'lineup', CASE WHEN NOT v_member THEN NULL ELSE (
      SELECT jsonb_build_object(
        'lineup_id', l.lineup_id,
        'format',    l.format,
        'squad_id',  l.squad_id,
        'players', COALESCE((
          SELECT jsonb_agg(jsonb_build_object(
                   'member_id', ld.member_id,
                   'number',    CASE WHEN ld.is_sub THEN l.format + ld.position_num ELSE ld.position_num END,
                   'position',  ld.position_label,
                   'is_sub',    ld.is_sub,
                   'first_name',m.first_name,
                   'last_name', m.last_name
                 ) ORDER BY ld.is_sub, ld.position_num)
            FROM public.lineup_details ld
            JOIN public.members m ON m.member_id = ld.member_id
           WHERE ld.lineup_id = l.lineup_id
        ), '[]'::jsonb)
      )
        FROM public.lineup l
       WHERE l.event_id = p_event_id AND l.team_id = v_team_id
         AND (v_squad_id IS NULL OR l.squad_id = v_squad_id OR l.squad_id IS NULL)
       ORDER BY (l.squad_id IS NOT DISTINCT FROM v_squad_id) DESC, l.lineup_id DESC
       LIMIT 1
    ) END,
    -- Everyone on the team's player list (role grade 10 = player), for naming scorers without a line-up
    'players', CASE WHEN NOT v_member THEN '[]'::jsonb ELSE COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'member_id',  pl.member_id,
               'first_name', pl.first_name,
               'last_name',  pl.last_name,
               'squads',     COALESCE((
                 SELECT jsonb_agg(DISTINCT msl.squad_id)
                   FROM public.member_squad_link msl
                  WHERE msl.member_id = pl.member_id AND msl.team_id = v_team_id AND msl.squad_id IS NOT NULL
               ), '[]'::jsonb)
             ))
        FROM (
          SELECT DISTINCT m.member_id, m.first_name, m.last_name
            FROM public.member_team_link mtl
            JOIN public.members m ON m.member_id = mtl.member_id
            JOIN public.member_team_role_link mtrl ON mtrl.member_team_id = mtl.member_team_id
            JOIN public.roles r ON r.role_id = mtrl.role_id
           WHERE mtl.team_id = v_team_id AND mtl.status = 'active' AND (r.role_grade = 10 OR r.role_level = 10)
        ) pl
    ), '[]'::jsonb) END
  ) INTO v_result;

  RETURN v_result;
END;
$function$;

-- Match stats page: say the team's sport so v3 shows totals for soccer/rugby.
CREATE OR REPLACE FUNCTION public.get_match_stats_session(p_match_stats_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_event_id    bigint;
    v_owner_id    uuid;
    v_opposition  text;
    v_title       text;
    v_finalised   timestamptz;
    v_timer       jsonb;
    v_team_name   text;
    v_member      boolean;
    v_sport       bigint;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN '{}'::jsonb;
    END IF;

    SELECT ms.event_id, ms.user_id, ms.opposition, e.event_title, ms.finalised_at, t.team_name,
           public.sk_is_team_member(e.team_id), public.team_sport_id(e.team_id)
      INTO v_event_id, v_owner_id, v_opposition, v_title, v_finalised, v_team_name, v_member, v_sport
      FROM public.match_stats ms
      JOIN public.events      e ON e.event_id = ms.event_id
      LEFT JOIN public.teams  t ON t.team_id  = e.team_id
     WHERE ms.id = p_match_stats_id;

    IF v_event_id IS NULL THEN
        RETURN '{}'::jsonb;
    END IF;

    SELECT jsonb_build_object(
               'elapsed_seconds',  COALESCE(mt.elapsed_seconds, 0),
               'started_at',       mt.started_at,
               'status',           COALESCE(mt.status, 'paused'),
               'duration_seconds', COALESCE(mt.duration_seconds, 1800),
               'current_half',     COALESCE(mt.current_half, 1)
           )
      INTO v_timer
      FROM public.match_timer mt
     WHERE mt.event_id = v_event_id
       AND mt.user_id  = v_owner_id;

    RETURN jsonb_build_object(
        'match_stats_id', p_match_stats_id,
        'event_id',       v_event_id,
        'team_name',      v_team_name,
        'sport_id',       v_sport,
        'opposition',     COALESCE(v_opposition, 'Opposition'),
        'event_title',    COALESCE(v_title, 'Match'),
        'finalised_at',   v_finalised,
        'timer',          COALESCE(v_timer,
                              '{"elapsed_seconds":0,"status":"paused","duration_seconds":1800,"current_half":1}'::jsonb),
        'events', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id',               msd.id,
                    'half',             msd.half,
                    'second',           msd.event_second,
                    'side',             msd.side,
                    'score_value',      mst.score_value,
                    'abbreviated_name', mst.abbreviated_name,
                    'score_type_name',  mst.score_type,
                    'kind',             msd.kind,
                    'count',            COALESCE(msd.count, 1),
                    'member_id',        msd.member_id,
                    'member_name',      CASE WHEN v_member THEN TRIM(CONCAT(m.first_name, ' ', m.last_name)) END,
                    'created_at',       msd.created_at
                )
                ORDER BY msd.half, msd.event_second, msd.created_at
            )
            FROM public.match_stats_details msd
            JOIN public.match_stat_types    mst ON mst.id = msd.score_type
            LEFT JOIN public.members        m   ON m.member_id = msd.member_id
            WHERE msd.match_stats_id = p_match_stats_id
        ), '[]'::jsonb),
        'subs', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'half',     s.half,
                    'second',   s.event_second,
                    'off_name', CASE WHEN v_member THEN TRIM(CONCAT(moff.first_name, ' ', moff.last_name)) END,
                    'on_name',  CASE WHEN v_member THEN TRIM(CONCAT(mon.first_name, ' ', mon.last_name)) END
                )
                ORDER BY s.half, s.event_second, s.created_at
            )
            FROM public.match_subs s
            LEFT JOIN public.members moff ON moff.member_id = s.member_off
            LEFT JOIN public.members mon  ON mon.member_id  = s.member_on
            WHERE s.match_stats_id = p_match_stats_id
        ), '[]'::jsonb)
    );
END;
$function$;
