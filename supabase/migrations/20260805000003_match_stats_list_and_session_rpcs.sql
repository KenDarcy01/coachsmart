-- Two RPCs that power the event-level session picker on the chart webview.
-- list_match_stats_for_event: returns ALL sessions for an event (no ownership filter)
--   so a coach can browse stats recorded by other coaches/squads.
-- get_match_stats_session: returns full chart data for ONE session by match_stats_id,
--   using the session owner's match_timer (no ownership filter for read access).

-- ── list_match_stats_for_event ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.list_match_stats_for_event(p_event_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN '[]'::jsonb;
    END IF;

    RETURN COALESCE((
        SELECT jsonb_agg(
            jsonb_build_object(
                'id',           ms.id,
                'user_name',    TRIM(CONCAT(u.first_name, ' ', u.last_name)),
                'squad_name',   sq.squad_name,
                'squad_colour', sq.squad_colour,
                'opposition',   COALESCE(ms.opposition, 'Opposition'),
                'finalised_at', ms.finalised_at,
                'score_count',  COALESCE(cnt.n, 0),
                'is_mine',      (ms.user_id = auth.uid())
            )
            ORDER BY ms.id
        )
        FROM public.match_stats ms
        LEFT JOIN public.users  u  ON u.user_id   = ms.user_id
        LEFT JOIN public.squads sq ON sq.squad_id  = ms.squad_id
        LEFT JOIN (
            SELECT match_stats_id, COUNT(*) AS n
              FROM public.match_stats_details
             GROUP BY match_stats_id
        ) cnt ON cnt.match_stats_id = ms.id
        WHERE ms.event_id = p_event_id
    ), '[]'::jsonb);
END;
$$;
GRANT EXECUTE ON FUNCTION public.list_match_stats_for_event(bigint) TO authenticated;


-- ── get_match_stats_session ───────────────────────────────────────────────────
-- Same return shape as get_match_stats_timeline but addressed by match_stats_id.
-- Joins match_timer on the session owner's user_id (not the caller's).
CREATE OR REPLACE FUNCTION public.get_match_stats_session(p_match_stats_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_event_id   bigint;
    v_owner_id   uuid;
    v_opposition text;
    v_title      text;
    v_timer      jsonb;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN '{}'::jsonb;
    END IF;

    SELECT ms.event_id, ms.user_id, ms.opposition, e.event_title
      INTO v_event_id, v_owner_id, v_opposition, v_title
      FROM public.match_stats ms
      JOIN public.events      e ON e.event_id = ms.event_id
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
        'opposition',     COALESCE(v_opposition, 'Opposition'),
        'event_title',    COALESCE(v_title, 'Match'),
        'timer',          COALESCE(v_timer,
                              '{"elapsed_seconds":0,"status":"paused","duration_seconds":1800,"current_half":1}'::jsonb),
        'events', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id',               msd.id,
                    'half',             msd.half,
                    'minute',           msd.event_minute,
                    'side',             msd.side,
                    'score_value',      mst.score_value,
                    'abbreviated_name', mst.abbreviated_name,
                    'created_at',       msd.created_at
                )
                ORDER BY msd.half, msd.event_minute, msd.created_at
            )
            FROM public.match_stats_details msd
            JOIN public.match_stat_types    mst ON mst.id = msd.score_type
            WHERE msd.match_stats_id = p_match_stats_id
        ), '[]'::jsonb)
    );
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_match_stats_session(bigint) TO authenticated;
