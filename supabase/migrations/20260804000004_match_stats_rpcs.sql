-- SECURITY DEFINER RPCs for match stats operations.
-- Direct table access to match_stats and match_stats_details is blocked
-- (anon SELECT revoked → PostgREST marks tables API DISABLED for all roles).
-- These functions bypass that restriction and own the security boundary.

-- ── upsert_match_stats ────────────────────────────────────────────────────────
-- Get or create the match_stats session row for the calling user + event.
CREATE OR REPLACE FUNCTION public.upsert_match_stats(
    p_event_id   bigint,
    p_opposition text,
    p_squad_id   bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_id      bigint;
BEGIN
    SELECT id INTO v_id
      FROM public.match_stats
     WHERE event_id = p_event_id
       AND user_id  = v_user_id;

    IF v_id IS NOT NULL THEN
        UPDATE public.match_stats
           SET opposition = p_opposition,
               squad_id   = p_squad_id
         WHERE id = v_id;
    ELSE
        INSERT INTO public.match_stats (event_id, user_id, opposition, squad_id)
        VALUES (p_event_id, v_user_id, p_opposition, p_squad_id)
        RETURNING id INTO v_id;
    END IF;

    RETURN jsonb_build_object('id', v_id);
END;
$$;
GRANT EXECUTE ON FUNCTION public.upsert_match_stats(bigint, text, bigint) TO authenticated;


-- ── get_match_stat_counts ─────────────────────────────────────────────────────
-- Return aggregated us/opp counts per score_type for a session.
CREATE OR REPLACE FUNCTION public.get_match_stat_counts(p_match_stats_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.match_stats
         WHERE id = p_match_stats_id AND user_id = auth.uid()
    ) THEN
        RETURN '{}'::jsonb;
    END IF;

    RETURN COALESCE((
        SELECT jsonb_object_agg(
            score_type::text,
            jsonb_build_object('us', us_count, 'opp', opp_count)
        )
        FROM (
            SELECT score_type,
                   SUM(CASE WHEN side = 'us'  THEN count ELSE 0 END) AS us_count,
                   SUM(CASE WHEN side = 'opp' THEN count ELSE 0 END) AS opp_count
              FROM public.match_stats_details
             WHERE match_stats_id = p_match_stats_id
             GROUP BY score_type
        ) t
    ), '{}'::jsonb);
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_match_stat_counts(bigint) TO authenticated;


-- ── log_match_stat ────────────────────────────────────────────────────────────
-- Insert a single scoring event. Returns the new row id.
CREATE OR REPLACE FUNCTION public.log_match_stat(
    p_match_stats_id bigint,
    p_score_type     bigint,
    p_side           text,
    p_event_minute   int,
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
        match_stats_id, score_type, side, count, event_minute, timer_status, half
    ) VALUES (
        p_match_stats_id, p_score_type, p_side, 1,
        p_event_minute::smallint,
        p_timer_status,
        p_half
    )
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.log_match_stat(bigint, bigint, text, int, text, int) TO authenticated;


-- ── delete_last_match_stat ────────────────────────────────────────────────────
-- Remove the most recent detail row for a given type + side.
CREATE OR REPLACE FUNCTION public.delete_last_match_stat(
    p_match_stats_id bigint,
    p_score_type     bigint,
    p_side           text
)
RETURNS boolean
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
        RETURN false;
    END IF;

    SELECT id INTO v_id
      FROM public.match_stats_details
     WHERE match_stats_id = p_match_stats_id
       AND score_type     = p_score_type
       AND side           = p_side
     ORDER BY created_at DESC
     LIMIT 1;

    IF v_id IS NULL THEN RETURN false; END IF;

    DELETE FROM public.match_stats_details WHERE id = v_id;
    RETURN true;
END;
$$;
GRANT EXECUTE ON FUNCTION public.delete_last_match_stat(bigint, bigint, text) TO authenticated;


-- ── finalise_match_stats ──────────────────────────────────────────────────────
-- Mark the session as finalised (end of match save).
CREATE OR REPLACE FUNCTION public.finalise_match_stats(p_match_stats_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    UPDATE public.match_stats
       SET finalised_at = now()
     WHERE id      = p_match_stats_id
       AND user_id = auth.uid();
END;
$$;
GRANT EXECUTE ON FUNCTION public.finalise_match_stats(bigint) TO authenticated;


-- ── reset_match_stats_details ─────────────────────────────────────────────────
-- Delete all detail rows for a session (used on timer reset).
CREATE OR REPLACE FUNCTION public.reset_match_stats_details(p_match_stats_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.match_stats
         WHERE id = p_match_stats_id AND user_id = auth.uid()
    ) THEN
        RETURN;
    END IF;

    DELETE FROM public.match_stats_details WHERE match_stats_id = p_match_stats_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.reset_match_stats_details(bigint) TO authenticated;
