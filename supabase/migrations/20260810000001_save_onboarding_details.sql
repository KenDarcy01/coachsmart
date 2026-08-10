-- Handles saving name details during onboarding.
-- Case 1: record exists with matching user_id → update names (normal path)
-- Case 2: no record at all → insert fresh row
-- Orphaned-record scenarios (auth user deleted and recreated) are handled
-- by manual DB cleanup, not auto-replaced here.
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

    -- Case 2: no record exists — insert fresh row
    INSERT INTO public.users (user_id, email_address, first_name, last_name)
    VALUES (p_user_id, p_email, p_first_name, p_last_name);
END;
$$;

GRANT EXECUTE ON FUNCTION public.save_onboarding_details(uuid, text, text, text)
    TO authenticated, anon;
