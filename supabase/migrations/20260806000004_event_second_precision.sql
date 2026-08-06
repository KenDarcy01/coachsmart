-- Store scoring events at second-level precision instead of minute.
-- Existing minute values are multiplied by 60 so history is preserved
-- (approximately — sub-minute detail was already lost at write time).

-- ── 1. Rename column and back-fill existing data ──────────────────────────────
ALTER TABLE public.match_stats_details
  RENAME COLUMN event_minute TO event_second;

UPDATE public.match_stats_details
   SET event_second = event_second * 60;

-- ── 2. log_match_stat — accept seconds instead of minutes ─────────────────────
-- Must DROP first — CREATE OR REPLACE cannot rename existing parameters.
DROP FUNCTION IF EXISTS public.log_match_stat(bigint, bigint, text, int, text, int);

CREATE FUNCTION public.log_match_stat(
    p_match_stats_id bigint,
    p_score_type     bigint,
    p_side           text,
    p_event_second   int,
    p_timer_status   text,
    p_half           int
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE v_id bigint;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.match_stats
         WHERE id = p_match_stats_id AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    INSERT INTO public.match_stats_details (
        match_stats_id, score_type, side, count, event_second, timer_status, half
    ) VALUES (
        p_match_stats_id, p_score_type, p_side, 1,
        p_event_second::smallint,
        p_timer_status,
        p_half
    )
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.log_match_stat(bigint, bigint, text, int, text, int) TO authenticated;

-- ── 3. get_match_stats_session — return 'second' field ───────────────────────
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

-- ── 4. get_match_stats_timeline — return 'second' field ──────────────────────
-- (Used by the live chart webview; mirrors the change above.)
CREATE OR REPLACE FUNCTION public.get_match_stats_timeline(
    p_event_id bigint,
    p_user_id  uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_user_id    uuid;
    v_opposition text;
    v_title      text;
    v_timer      jsonb;
    v_ms_id      bigint;
BEGIN
    v_user_id := COALESCE(p_user_id, auth.uid());

    IF v_user_id IS NULL THEN
        RETURN '{}'::jsonb;
    END IF;

    SELECT ms.id, ms.opposition INTO v_ms_id, v_opposition
      FROM public.match_stats ms
     WHERE ms.event_id = p_event_id
       AND ms.user_id  = v_user_id
       AND ms.status   = 'active'
     LIMIT 1;

    SELECT e.event_title INTO v_title
      FROM public.events e WHERE e.event_id = p_event_id;

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
       AND mt.user_id  = v_user_id;

    RETURN jsonb_build_object(
        'match_stats_id', v_ms_id,
        'opposition',     COALESCE(v_opposition, 'Opposition'),
        'event_title',    COALESCE(v_title, 'Match'),
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
            WHERE msd.match_stats_id = v_ms_id
        ), '[]'::jsonb)
    );
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_match_stats_timeline(bigint, uuid) TO authenticated;
