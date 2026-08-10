-- Replaces the fragile client-side upsert in the onboarding webview.
-- Handles three cases atomically in PL/pgSQL:
--   1. Record exists with matching user_id → update names only (normal path)
--   2. Record exists with matching email but a different (old) user_id →
--      re-link all child tables and swap the user_id without breaking FKs
--      (happens when auth user is deleted and recreated with the same email)
--   3. No record at all → insert fresh row
--
-- Case 2 ordering (avoids FK deadlock):
--   a. Rename old row's email to a temp value → frees the unique email slot
--   b. Insert new users row with new uuid + real email
--   c. Re-link all child tables from old uuid → new uuid (new uuid now exists)
--   d. Delete old users row (no longer referenced)
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
    v_temp_email  text;
BEGIN
    -- Case 1: update existing record by user_id (normal path)
    UPDATE public.users
    SET first_name    = p_first_name,
        last_name     = p_last_name,
        email_address = COALESCE(NULLIF(p_email, ''), email_address)
    WHERE user_id = p_user_id;

    IF FOUND THEN RETURN; END IF;

    -- Case 2: orphaned record — same email exists but with a different user_id
    IF p_email <> '' THEN
        SELECT user_id INTO v_old_user_id
        FROM public.users
        WHERE email_address = p_email;

        IF FOUND THEN
            -- Step a: temporarily rename the old row's email to free the unique slot
            v_temp_email := p_email || '__migrating__' || v_old_user_id::text;
            UPDATE public.users
            SET email_address = v_temp_email
            WHERE user_id = v_old_user_id;

            -- Step b: insert the new users row (new uuid + real email now free)
            INSERT INTO public.users (user_id, email_address, first_name, last_name)
            VALUES (p_user_id, p_email, p_first_name, p_last_name);

            -- Step c: re-link all child tables (new uuid now exists in users)
            UPDATE public.user_member_link          SET user_id    = p_user_id WHERE user_id    = v_old_user_id;
            UPDATE public.car_pool                  SET user_id    = p_user_id WHERE user_id    = v_old_user_id;
            UPDATE public.invitations               SET user_id    = p_user_id WHERE user_id    = v_old_user_id;
            UPDATE public.reminders                 SET user_id    = p_user_id WHERE user_id    = v_old_user_id;
            UPDATE public.events                    SET created_by = p_user_id WHERE created_by = v_old_user_id;
            UPDATE public.match_squads              SET user_id    = p_user_id WHERE user_id    = v_old_user_id;
            UPDATE public.match_squad_details       SET user_id    = p_user_id WHERE user_id    = v_old_user_id;
            UPDATE public.match_reports             SET user_id    = p_user_id WHERE user_id    = v_old_user_id;
            UPDATE public.match_scores              SET user_id    = p_user_id WHERE user_id    = v_old_user_id;
            UPDATE public.event_user_payment        SET user_id    = p_user_id WHERE user_id    = v_old_user_id;
            UPDATE public.event_user_member_payment SET user_id    = p_user_id WHERE user_id    = v_old_user_id;
            UPDATE public.user_game_link            SET user_id    = p_user_id WHERE user_id    = v_old_user_id;
            -- notifications & team_member have ON UPDATE CASCADE — handled automatically

            -- Step d: delete the now-orphaned old users row
            DELETE FROM public.users WHERE user_id = v_old_user_id;

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
