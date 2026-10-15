-- Score keeper: each player in get_score_keeper_state now lists the squads they
-- are in, so the page can show only the chosen squad's players. Otherwise the
-- same as 20261015000200.

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
    'score_types', COALESCE((
      WITH linked AS (
        SELECT mst.*
          FROM public.match_stat_type_team_link l
          JOIN public.match_stat_types mst ON mst.id = l.match_score_type_id
         WHERE l.team_id = v_team_id AND l.status IS TRUE AND mst.status IS TRUE
      ), chosen AS (
        SELECT * FROM linked
        UNION ALL
        SELECT mst.* FROM public.match_stat_types mst
         WHERE mst.status IS TRUE AND NOT EXISTS (SELECT 1 FROM linked)
      )
      SELECT jsonb_agg(jsonb_build_object(
               'id',               ch.id,
               'score_type',       ch.score_type,
               'abbreviated_name', ch.abbreviated_name,
               'score_value',      ch.score_value,
               'category',         COALESCE(cat.score_category, 'other')
             ) ORDER BY ch.score_category NULLS LAST, ch.score_value DESC NULLS LAST, ch.id)
        FROM chosen ch
        LEFT JOIN public.match_stat_categories cat ON cat.id = ch.score_category
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
    -- Everyone on the team's player list, for naming scorers without a line-up
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
           WHERE mtl.team_id = v_team_id AND mtl.status = 'active' AND r.role_level = 10
        ) pl
    ), '[]'::jsonb) END
  ) INTO v_result;

  RETURN v_result;
END;
$$;
REVOKE ALL ON FUNCTION public.get_score_keeper_state(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_score_keeper_state(bigint) TO authenticated;
