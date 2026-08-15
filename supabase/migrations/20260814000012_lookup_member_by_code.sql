-- Add lookup_member_by_code RPC.
-- Allows the onboarding webview to find an existing active member by their
-- unique_member_code, bypassing the name-entry step.
-- unique_member_code is globally unique per member so no team code is needed.
-- Returns team_code (teams.team_unique_code) so the caller can pass it to
-- request_member_access without a second lookup.
--
-- Return shapes:
--   { status: 'found',     member_id, first_name, last_name, team_name, team_code }
--   { status: 'not_found' }
--   { status: 'error',     message }

CREATE OR REPLACE FUNCTION public.lookup_member_by_code(
    p_unique_member_code text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_clean_code text := UPPER(TRIM(COALESCE(p_unique_member_code, '')));
    v_member_id  bigint;
    v_first_name text;
    v_last_name  text;
    v_team_id    bigint;
    v_team_name  text;
    v_team_code  text;
BEGIN
    IF v_clean_code = '' THEN
        RETURN jsonb_build_object('status', 'error',
            'message', 'Member code is required.');
    END IF;

    -- Find the member (unique_member_code is globally unique)
    SELECT m.member_id, m.first_name, m.last_name
      INTO v_member_id, v_first_name, v_last_name
      FROM public.members m
     WHERE UPPER(m.unique_member_code) = v_clean_code
       AND m.status != 'deleted'
     LIMIT 1;

    IF v_member_id IS NULL THEN
        RETURN jsonb_build_object('status', 'not_found');
    END IF;

    -- Resolve their active team and joining code
    SELECT mtl.team_id, t.team_name, t.team_unique_code
      INTO v_team_id, v_team_name, v_team_code
      FROM public.member_team_link mtl
      JOIN public.teams            t ON mtl.team_id = t.team_id
     WHERE mtl.member_id = v_member_id
       AND mtl.status    = 'active'
     LIMIT 1;

    IF v_team_id IS NULL THEN
        RETURN jsonb_build_object('status', 'not_found');
    END IF;

    RETURN jsonb_build_object(
        'status',     'found',
        'member_id',  v_member_id,
        'first_name', v_first_name,
        'last_name',  v_last_name,
        'team_name',  v_team_name,
        'team_code',  v_team_code
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('status', 'error', 'message', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.lookup_member_by_code(text) TO anon;
GRANT EXECUTE ON FUNCTION public.lookup_member_by_code(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.lookup_member_by_code(text) TO service_role;
