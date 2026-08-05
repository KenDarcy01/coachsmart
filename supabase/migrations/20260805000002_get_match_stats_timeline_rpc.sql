-- Return full time-series data for the match stats chart webview.
-- Includes the timer state (for current-time cursor) and all scoring events.
CREATE OR REPLACE FUNCTION public.get_match_stats_timeline(p_event_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_stats_id   bigint;
    v_opposition text;
    v_title      text;
    v_timer      jsonb;
BEGIN
    SELECT ms.id, ms.opposition, e.event_title
      INTO v_stats_id, v_opposition, v_title
      FROM public.match_stats ms
      JOIN public.events      e ON e.event_id = ms.event_id
     WHERE ms.event_id = p_event_id
       AND ms.user_id  = auth.uid();

    IF v_stats_id IS NULL THEN
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
     WHERE mt.event_id = p_event_id
       AND mt.user_id  = auth.uid();

    RETURN jsonb_build_object(
        'match_stats_id', v_stats_id,
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
            WHERE msd.match_stats_id = v_stats_id
        ), '[]'::jsonb)
    );
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_match_stats_timeline(bigint) TO authenticated;
