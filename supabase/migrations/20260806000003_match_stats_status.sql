-- Add status column to match_stats and switch from a hard unique constraint
-- to a partial unique index (one active session per user per event; multiple
-- finalised/reset records are allowed for history).

-- ── 1. Add status column ──────────────────────────────────────────────────────
ALTER TABLE public.match_stats
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active';

ALTER TABLE public.match_stats
  DROP CONSTRAINT IF EXISTS match_stats_status_check;

ALTER TABLE public.match_stats
  ADD CONSTRAINT match_stats_status_check
  CHECK (status IN ('active', 'finalised', 'reset'));

-- ── 2. Back-fill existing finalised rows ──────────────────────────────────────
UPDATE public.match_stats SET status = 'finalised' WHERE finalised_at IS NOT NULL;

-- ── 3. Drop the old hard UNIQUE(event_id, user_id) constraint ─────────────────
DO $$
DECLARE v_conname text;
BEGIN
  SELECT c.conname INTO v_conname
    FROM pg_constraint c
    JOIN pg_class     r ON r.oid = c.conrelid
   WHERE r.relname        = 'match_stats'
     AND r.relnamespace   = 'public'::regnamespace
     AND c.contype        = 'u'
     AND array_length(c.conkey, 1) = 2
     AND EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = r.oid AND a.attname = 'event_id' AND a.attnum = ANY(c.conkey))
     AND EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = r.oid AND a.attname = 'user_id'  AND a.attnum = ANY(c.conkey));
  IF v_conname IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.match_stats DROP CONSTRAINT %I', v_conname);
  END IF;
END$$;

-- ── 4. Partial unique index — only one active session per user per event ───────
CREATE UNIQUE INDEX IF NOT EXISTS match_stats_one_active_per_user
  ON public.match_stats (event_id, user_id)
  WHERE status = 'active';

-- ── 5. upsert_match_stats — filter to active sessions only ────────────────────
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
       AND status   = 'active';

    IF v_id IS NOT NULL THEN
        UPDATE public.match_stats
           SET opposition = p_opposition,
               squad_id   = p_squad_id
         WHERE id = v_id;
    ELSE
        INSERT INTO public.match_stats (event_id, user_id, opposition, squad_id, status)
        VALUES (p_event_id, v_user_id, p_opposition, p_squad_id, 'active')
        RETURNING id INTO v_id;
    END IF;

    RETURN jsonb_build_object('id', v_id);
END;
$$;
GRANT EXECUTE ON FUNCTION public.upsert_match_stats(bigint, text, bigint) TO authenticated;

-- ── 6. finalise_match_stats — also set status = 'finalised' ──────────────────
CREATE OR REPLACE FUNCTION public.finalise_match_stats(p_match_stats_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    UPDATE public.match_stats
       SET finalised_at = now(),
           status       = 'finalised'
     WHERE id      = p_match_stats_id
       AND user_id = auth.uid();
END;
$$;
GRANT EXECUTE ON FUNCTION public.finalise_match_stats(bigint) TO authenticated;

-- ── 7. reset_match_stats_session ──────────────────────────────────────────────
-- Marks the current session as 'reset', deletes its details, and creates a
-- fresh active session. Returns the new session id.
CREATE OR REPLACE FUNCTION public.reset_match_stats_session(p_match_stats_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_user_id    uuid := auth.uid();
    v_event_id   bigint;
    v_opposition text;
    v_squad_id   bigint;
    v_new_id     bigint;
BEGIN
    SELECT event_id, opposition, squad_id
      INTO v_event_id, v_opposition, v_squad_id
      FROM public.match_stats
     WHERE id = p_match_stats_id AND user_id = v_user_id;

    IF v_event_id IS NULL THEN
        RETURN jsonb_build_object('id', null);
    END IF;

    DELETE FROM public.match_stats_details WHERE match_stats_id = p_match_stats_id;
    UPDATE public.match_stats SET status = 'reset' WHERE id = p_match_stats_id;

    INSERT INTO public.match_stats (event_id, user_id, opposition, squad_id, status)
    VALUES (v_event_id, v_user_id, v_opposition, v_squad_id, 'active')
    RETURNING id INTO v_new_id;

    RETURN jsonb_build_object('id', v_new_id);
END;
$$;
GRANT EXECUTE ON FUNCTION public.reset_match_stats_session(bigint) TO authenticated;

-- ── 8. list_match_stats_for_event — include status, hide reset sessions ────────
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
                'status',       ms.status,
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
          AND ms.status  != 'reset'
    ), '[]'::jsonb);
END;
$$;
GRANT EXECUTE ON FUNCTION public.list_match_stats_for_event(bigint) TO authenticated;
