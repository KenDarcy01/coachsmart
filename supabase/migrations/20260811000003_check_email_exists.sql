-- Lightweight helper called after a failed signInWithPassword to determine
-- whether the email is unknown (show "no account found") or the password
-- was wrong (show "incorrect password"). Returns a boolean only — no
-- personal data exposed. Granted to anon so the login screen can call it
-- before a session exists.

CREATE OR REPLACE FUNCTION public.check_email_exists(p_email text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = 'public'
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE email_address = lower(trim(p_email))
    );
$$;

GRANT EXECUTE ON FUNCTION public.check_email_exists(text) TO anon, authenticated;
