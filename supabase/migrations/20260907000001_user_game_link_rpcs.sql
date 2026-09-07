-- RPCs for webview favourites sync with user_game_link table.

-- ── get_user_game_links ───────────────────────────────────────────────────────
-- Return all game_ids the calling user has favourited.
CREATE OR REPLACE FUNCTION public.get_user_game_links()
RETURNS bigint[]
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    RETURN COALESCE(
        ARRAY(
            SELECT game_id
              FROM public.user_game_link
             WHERE user_id = auth.uid()
             ORDER BY position, created_at
        ),
        ARRAY[]::bigint[]
    );
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_user_game_links() TO authenticated;


-- ── toggle_user_game_link ─────────────────────────────────────────────────────
-- Add or remove a game from the calling user's favourites.
-- Returns true if the game was added, false if it was removed.
CREATE OR REPLACE FUNCTION public.toggle_user_game_link(p_game_id bigint)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_exists boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM public.user_game_link
         WHERE user_id = auth.uid()
           AND game_id = p_game_id
    ) INTO v_exists;

    IF v_exists THEN
        DELETE FROM public.user_game_link
         WHERE user_id = auth.uid()
           AND game_id = p_game_id;
        RETURN false;
    ELSE
        INSERT INTO public.user_game_link (user_id, game_id, position)
        VALUES (auth.uid(), p_game_id, 0);
        RETURN true;
    END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.toggle_user_game_link(bigint) TO authenticated;
