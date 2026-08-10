-- Replaces the fragile client-side upsert in the onboarding webview.
-- Handles three cases atomically in PL/pgSQL:
--   1. Record exists with matching user_id → update names only (normal path)
--   2. Record exists with matching email but old user_id → re-link all child
--      tables to new user_id, then fix users.user_id
--      (happens when auth user is deleted & recreated with the same email)
--   3. No record at all → insert fresh row
CREATE OR REPLACE FUNCTION public.save_onboarding_details(
    p_user_id    uuid,
    p_email      text,
    p_first_name text,
    p_last_name  text
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_old_user_id uuid;
BEGIN
    -- Case 1: update existing record by user_id
    UPDATE public.users
    SET first_name    = p_first_name,
        last_name     = p_last_name,
        email_address = COALESCE(NULLIF(p_email, ''), email_address)
    WHERE user_id = p_user_id;

    IF FOUND THEN RETURN; END IF;

    -- Case 2: orphaned record — same email, different user_id
    IF p_email <> '' THEN
        SELECT user_id INTO v_old_user_id
        FROM public.users
        WHERE email_address = p_email;

        IF FOUND THEN
            -- Re-link all child tables that don't have ON UPDATE CASCADE
            UPDATE public.user_member_link         SET user_id    = p_user_id WHERE user_id    = v_old_user_id;
            UPDATE public.car_pool                 SET user_id    = p_user_id WHERE user_id    = v_old_user_id;
            UPDATE public.invitations              SET user_id    = p_user_id WHERE user_id    = v_old_user_id;
            UPDATE public.reminders                SET user_id    = p_user_id WHERE user_id    = v_old_user_id;
            UPDATE public.events                   SET created_by = p_user_id WHERE created_by = v_old_user_id;
            UPDATE public.match_squads             SET user_id    = p_user_id WHERE user_id    = v_old_user_id;
            UPDATE public.match_squad_details      SET user_id    = p_user_id WHERE user_id    = v_old_user_id;
            UPDATE public.match_reports            SET user_id    = p_user_id WHERE user_id    = v_old_user_id;
            UPDATE public.match_scores             SET user_id    = p_user_id WHERE user_id    = v_old_user_id;
            UPDATE public.event_user_payment       SET user_id    = p_user_id WHERE user_id    = v_old_user_id;
            UPDATE public.event_user_member_payment SET user_id   = p_user_id WHERE user_id    = v_old_user_id;
            UPDATE public.user_game_link           SET user_id    = p_user_id WHERE user_id    = v_old_user_id;
            -- notifications & team_member already have ON UPDATE CASCADE

            -- Now safe to update users.user_id
            UPDATE public.users
            SET user_id    = p_user_id,
                first_name = p_first_name,
                last_name  = p_last_name
            WHERE user_id = v_old_user_id;

            RETURN;
        END IF;
    END IF;

    -- Case 3: truly new user — insert fresh row
    INSERT INTO public.users (user_id, email_address, first_name, last_name)
    VALUES (p_user_id, p_email, p_first_name, p_last_name);
END;
$$;

GRANT EXECUTE ON FUNCTION public.save_onboarding_details(uuid, text, text, text)
    TO authenticated, anon;
