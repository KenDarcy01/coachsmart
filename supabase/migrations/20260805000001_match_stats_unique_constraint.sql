-- Add a unique constraint on (event_id, user_id) so each coach has exactly
-- one stats session per event.  upsert_match_stats relies on this 1:1 mapping.
-- Also tidy up any duplicates first (keep the most recently created row).

DELETE FROM public.match_stats_details
 WHERE match_stats_id IN (
     SELECT id FROM public.match_stats ms
      WHERE EXISTS (
          SELECT 1 FROM public.match_stats ms2
           WHERE ms2.event_id = ms.event_id
             AND ms2.user_id  = ms.user_id
             AND ms2.id       > ms.id
      )
 );

DELETE FROM public.match_stats
 WHERE id NOT IN (
     SELECT MAX(id)
       FROM public.match_stats
      GROUP BY event_id, user_id
 );

ALTER TABLE public.match_stats
    ADD CONSTRAINT match_stats_event_user_unique UNIQUE (event_id, user_id);


-- Re-create upsert_match_stats with ORDER BY id DESC LIMIT 1 so it always
-- picks the newest row when (after dedup above) only one exists anyway.
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
       AND user_id  = v_user_id
     ORDER BY id DESC
     LIMIT 1;

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
