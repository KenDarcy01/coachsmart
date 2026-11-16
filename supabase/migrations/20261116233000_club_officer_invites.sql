-- Club officer invites (Ken, 2026-11-16): a SuperUser invites a club officer
-- (e.g. the chairperson) by email, even before they have a CoachSmart account.
-- The club-invite edge function emails a club-branded link with a one-off token
-- (valid 30 days). The link opens the dashboard on a "set up your account" form;
-- the edge function then creates and confirms the account (the existing
-- on_auth_user_confirmed trigger creates the public.users row) and turns the
-- invite into a club_officers row. club_officer_claim_invites() also claims any
-- pending invite when someone signs in with an account made another way.

CREATE TABLE IF NOT EXISTS public.club_officer_invites (
    invite_id   bigserial PRIMARY KEY,
    club_id     bigint      NOT NULL REFERENCES public.clubs(club_id),
    email       text        NOT NULL,
    title       text        NOT NULL DEFAULT 'Officer',
    first_name  text,
    last_name   text,
    created_by  uuid,
    created_at  timestamptz NOT NULL DEFAULT now(),
    sent_at     timestamptz,
    token       text UNIQUE,
    expires_at  timestamptz,
    accepted_at timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS club_officer_invites_club_email
    ON public.club_officer_invites (club_id, lower(email));
ALTER TABLE public.club_officer_invites ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.club_officer_invites FROM anon, authenticated;

-- Turn the caller's pending invites into officer rows.
CREATE OR REPLACE FUNCTION public.club_officer_claim_invites()
 RETURNS integer
 LANGUAGE plpgsql SECURITY DEFINER
 SET search_path TO 'public'
AS $$
DECLARE
    v_uid   uuid := auth.uid();
    v_email text;
    v_n     integer := 0;
    r       record;
BEGIN
    IF v_uid IS NULL THEN RETURN 0; END IF;
    SELECT au.email INTO v_email FROM auth.users au WHERE au.id = v_uid;
    IF v_email IS NULL OR NOT EXISTS (SELECT 1 FROM users WHERE user_id = v_uid) THEN
        RETURN 0;
    END IF;
    FOR r IN SELECT * FROM club_officer_invites
              WHERE lower(email) = lower(v_email) AND accepted_at IS NULL
    LOOP
        INSERT INTO club_officers (club_id, user_id, title, created_by)
        VALUES (r.club_id, v_uid, r.title, r.created_by)
        ON CONFLICT (club_id, user_id) DO UPDATE SET is_active = true, title = EXCLUDED.title;
        UPDATE users
           SET first_name = COALESCE(NULLIF(first_name, ''), r.first_name),
               last_name  = COALESCE(NULLIF(last_name, ''),  r.last_name)
         WHERE user_id = v_uid;
        UPDATE club_officer_invites SET accepted_at = now() WHERE invite_id = r.invite_id;
        v_n := v_n + 1;
    END LOOP;
    RETURN v_n;
END;
$$;

-- Officer list now also returns invites that haven't been accepted yet.
CREATE OR REPLACE FUNCTION public.club_officer_list(p_club_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $$
BEGIN
  IF NOT public.is_app_super_user() THEN
    RETURN jsonb_build_object('error', 'Only a SuperUser can manage club officers');
  END IF;
  RETURN jsonb_build_object(
    'officers', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'user_id', u.user_id,
               'name', trim(COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, '')),
               'email', u.email_address, 'title', co.title, 'created_at', co.created_at)
             ORDER BY co.created_at)
        FROM club_officers co JOIN users u ON u.user_id = co.user_id
       WHERE co.club_id = p_club_id AND co.is_active), '[]'::jsonb),
    'invites', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'email', i.email, 'title', i.title,
               'name', trim(COALESCE(i.first_name, '') || ' ' || COALESCE(i.last_name, '')),
               'sent_at', i.sent_at) ORDER BY i.created_at)
        FROM club_officer_invites i
       WHERE i.club_id = p_club_id AND i.accepted_at IS NULL), '[]'::jsonb));
END;
$$;

CREATE OR REPLACE FUNCTION public.club_officer_invite_cancel(p_club_id bigint, p_email text)
 RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER
 SET search_path TO 'public'
AS $$
BEGIN
  IF NOT public.is_app_super_user() THEN
    RETURN jsonb_build_object('error', 'Only a SuperUser can manage club officers');
  END IF;
  DELETE FROM club_officer_invites
   WHERE club_id = p_club_id AND lower(email) = lower(trim(p_email)) AND accepted_at IS NULL;
  RETURN jsonb_build_object('ok', true);
END;
$$;

-- For the club-invite edge function (service role only): the auth account for an email.
CREATE OR REPLACE FUNCTION public.club_invite_auth_user(p_email text)
 RETURNS TABLE(user_id uuid, confirmed boolean, has_profile boolean)
 LANGUAGE sql STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $$
  SELECT au.id, au.email_confirmed_at IS NOT NULL,
         EXISTS (SELECT 1 FROM users u WHERE u.user_id = au.id)
    FROM auth.users au
   WHERE lower(au.email) = lower(trim(p_email))
   ORDER BY au.created_at DESC LIMIT 1;
$$;
REVOKE ALL ON FUNCTION public.club_invite_auth_user(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.club_invite_auth_user(text) TO service_role;

REVOKE ALL ON FUNCTION public.club_officer_claim_invites()               FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.club_officer_invite_cancel(bigint, text)   FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.club_officer_claim_invites()            TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.club_officer_invite_cancel(bigint, text) TO authenticated, service_role;
