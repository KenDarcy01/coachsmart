-- Score keeper: more stats, voice-only stats, "against" a player, scores from a free
--
-- Ken (2026-11-07):
--  * New stat types Turnover, Throw in and 45 (Free and Wide already exist).
--  * Voice can record every active stat type for every team, but the Tap
--    buttons only show the team's own list (match_stat_type_team_link), or for
--    a team with no list, the types marked default_button (the original six,
--    so nothing changes on screen for any team).
--  * A player can be saved on an opposition-side stat that isn't a score:
--    side is whose ball it is now, so "free against Luke" = a free to them,
--    given away by Luke (member_id = Luke, side = 'opp').
--  * A score can say what it came from: "point Clontarf Murrough free" = a
--    point by Murrough from a free (match_stats_details.from_type = Free).
--    Only types marked score_source (Free, 45) can be a source.
-- Safe and additive: new nullable/defaulted columns, three new rows, and
-- CREATE OR REPLACE of two functions with the same signatures.

ALTER TABLE public.match_stat_types
  ADD COLUMN IF NOT EXISTS default_button boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS score_source   boolean NOT NULL DEFAULT false;

-- Today's types keep their buttons for teams without their own list
UPDATE public.match_stat_types SET default_button = true WHERE id IN (1, 2, 3, 4, 6, 8);
UPDATE public.match_stat_types SET score_source = true WHERE id = 8;   -- Free

INSERT INTO public.match_stat_types (score_type, abbreviated_name, score_category, status, score_value, default_button, score_source)
SELECT v.score_type, v.abbr, v.cat, true, NULL, false, v.src
  FROM (VALUES ('Turnover', 'TO', 2::bigint, false),
               ('Throw in', 'TI', 3::bigint, false),
               ('45',       '45', 3::bigint, true)) AS v(score_type, abbr, cat, src)
 WHERE NOT EXISTS (SELECT 1 FROM public.match_stat_types t WHERE lower(t.score_type) = lower(v.score_type));

ALTER TABLE public.match_stats_details
  ADD COLUMN IF NOT EXISTS from_type bigint REFERENCES public.match_stat_types(id);

CREATE OR REPLACE FUNCTION public.get_score_keeper_state(p_event_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_uid       uuid := auth.uid();
  v_team_id   bigint;
  v_member    boolean;
  v_session   public.match_stats%ROWTYPE;
  v_squad_id  bigint;
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
        'event_type',      et.event_type
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
    -- Every active stat type, so voice can record any of them. button = shown
    -- as a Tap button: the team's own list if it has one, else the types
    -- marked default_button (the original six).
    'score_types', COALESCE((
      WITH linked AS (
        SELECT l.match_score_type_id AS id
          FROM public.match_stat_type_team_link l
          JOIN public.match_stat_types mst ON mst.id = l.match_score_type_id
         WHERE l.team_id = v_team_id AND l.status IS TRUE AND mst.status IS TRUE
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
       WHERE mst.status IS TRUE
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
$$;
REVOKE ALL ON FUNCTION public.get_score_keeper_state(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_score_keeper_state(bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.sync_match_actions(p_match_stats_id bigint, p_actions jsonb, p_timer jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid     uuid := auth.uid();
  v_event   bigint;
  v_team    bigint;
  a         jsonb;
  v_id      uuid;
  v_target  uuid;
  v_row     bigint;
  v_member  bigint;
  v_from    bigint;
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

    -- What a score came from (Free, 45): only source types are kept
    v_from := (SELECT t.id FROM public.match_stat_types t
                WHERE t.id = NULLIF(a->>'from_type', '')::bigint AND t.score_source IS TRUE);

    CASE a->>'type'
      WHEN 'score', 'correction' THEN
        INSERT INTO public.match_stats_details (
          match_stats_id, score_type, side, count, event_second, timer_status, half,
          client_id, member_id, kind, from_type
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
          a->>'type',
          CASE WHEN a->>'type' = 'score' THEN v_from END
        )
        ON CONFLICT (client_id) DO NOTHING;

      WHEN 'edit' THEN
        UPDATE public.match_stats_details d
           SET score_type = COALESCE((a->>'score_type')::bigint, d.score_type),
               side       = COALESCE(a->>'side', d.side),
               member_id  = CASE WHEN a ? 'member_id' THEN v_member ELSE d.member_id END,
               from_type  = CASE WHEN a ? 'from_type' THEN v_from ELSE d.from_type END
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
           clock_offset_ms  = CASE WHEN COALESCE(p_timer->>'client_now', '') <> ''
                                   THEN round(extract(epoch FROM now() - (p_timer->>'client_now')::timestamptz) * 1000)::int
                                   ELSE mt.clock_offset_ms END,
           updated_at       = now()
     WHERE mt.event_id = v_event AND mt.user_id = v_uid;
  END IF;

  RETURN jsonb_build_object('done', v_done);
END;
$function$;
REVOKE ALL ON FUNCTION public.sync_match_actions(bigint, jsonb, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sync_match_actions(bigint, jsonb, jsonb) TO authenticated;

