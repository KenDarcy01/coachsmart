-- ── 1. Enable realtime on the tables the live chart subscribes to ─────────────
-- The DO blocks swallow "already a member" errors so this is safe to re-run.
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.match_stats_details;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.match_timer;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── 2. Add event_id to get_match_stats_session ────────────────────────────────
-- The chart uses it to subscribe to match_timer changes (pause/resume/half).
CREATE OR REPLACE FUNCTION public.get_match_stats_session(p_match_stats_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_event_id    bigint;
    v_owner_id    uuid;
    v_opposition  text;
    v_title       text;
    v_finalised   timestamptz;
    v_timer       jsonb;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN '{}'::jsonb;
    END IF;

    SELECT ms.event_id, ms.user_id, ms.opposition, e.event_title, ms.finalised_at
      INTO v_event_id, v_owner_id, v_opposition, v_title, v_finalised
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
        'event_id',       v_event_id,
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
                    'created_at',       msd.created_at
                )
                ORDER BY msd.half, msd.event_second, msd.created_at
            )
            FROM public.match_stats_details msd
            JOIN public.match_stat_types    mst ON mst.id = msd.score_type
            WHERE msd.match_stats_id = p_match_stats_id
        ), '[]'::jsonb)
    );
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_match_stats_session(bigint) TO authenticated;
