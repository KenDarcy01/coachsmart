-- CREATE OR REPLACE cannot rename parameters in an existing function.
-- Drop and recreate log_match_stat with p_event_second instead of p_event_minute.

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
