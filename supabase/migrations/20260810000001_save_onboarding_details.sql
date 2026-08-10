-- Replaces the fragile client-side upsert in the onboarding webview.
-- Handles three cases atomically:
--   1. Record exists with matching user_id → update names only (normal path)
--   2. Record exists with matching email but old user_id → fix user_id + names
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
        UPDATE public.users
        SET user_id    = p_user_id,
            first_name = p_first_name,
            last_name  = p_last_name
        WHERE email_address = p_email;

        IF FOUND THEN RETURN; END IF;
    END IF;

    -- Case 3: truly new user
    INSERT INTO public.users (user_id, email_address, first_name, last_name)
    VALUES (p_user_id, p_email, p_first_name, p_last_name);
END;
$$;

GRANT EXECUTE ON FUNCTION public.save_onboarding_details(uuid, text, text, text)
    TO authenticated, anon;
