-- Update confirm_member_join to accept multiple role IDs.
-- p_role_ids is an array of bigint e.g. ARRAY[3, 8]

CREATE OR REPLACE FUNCTION public.confirm_member_join(
    p_member_team_id bigint,
    p_role_ids       bigint[]
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_team_id    bigint;
    v_member_id  bigint;
    v_first_name text;
    v_last_name  text;
    v_team_name  text;
BEGIN
    IF p_role_ids IS NULL OR array_length(p_role_ids, 1) IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'At least one role must be provided.');
    END IF;

    SELECT mtl.team_id, mtl.member_id, m.first_name, m.last_name, t.team_name
      INTO v_team_id, v_member_id, v_first_name, v_last_name, v_team_name
      FROM public.member_team_link mtl
      JOIN public.members          m  ON mtl.member_id = m.member_id
      JOIN public.teams            t  ON mtl.team_id   = t.team_id
     WHERE mtl.member_team_id = p_member_team_id
       AND mtl.status         = 'pending';

    IF v_team_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Pending request not found.');
    END IF;

    -- Activate the membership
    UPDATE public.member_team_link
       SET status = 'active'
     WHERE member_team_id = p_member_team_id;

    -- Assign all selected roles
    INSERT INTO public.member_team_role_link (member_team_id, role_id)
    SELECT p_member_team_id, unnest(p_role_ids)
    ON CONFLICT DO NOTHING;

    -- Notify the member's linked user
    INSERT INTO public.notifications (
        recipient_user_id, team_id,
        app_title, app_body,
        push_title, push_body
    )
    SELECT uml.user_id,
           v_team_id,
           'Request Approved',
           v_first_name || ' ' || v_last_name || ' has been confirmed as a member of ' || v_team_name || '.',
           'Request Approved',
           v_first_name || ' ' || v_last_name || ' has been confirmed as a member of ' || v_team_name || '.'
      FROM public.user_member_link uml
     WHERE uml.member_id = v_member_id
       AND uml.status    = 'active';

    RETURN json_build_object(
        'success', true,
        'message', v_first_name || ' ' || v_last_name || ' confirmed as a member of ' || v_team_name || '.'
    );

EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.confirm_member_join(bigint, bigint[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_member_join(bigint, bigint[]) TO service_role;
