-- Keep member_team_role_link rows when a member is removed from a team.
-- Previously hard-deleted; now preserved alongside member_team_link.
-- No status column needed on member_team_role_link — all RPCs reach it
-- by joining through member_team_link (via member_team_id), so the
-- mtl.status = 'active' filter on the parent makes these rows unreachable
-- through normal app queries without any additional filtering.

CREATE OR REPLACE FUNCTION public.remove_member_from_team(
    p_member_id bigint,
    p_team_id   bigint
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_member_team_id   bigint;
    v_other_team_count int;
BEGIN
    SELECT member_team_id
      INTO v_member_team_id
      FROM member_team_link
     WHERE member_id = p_member_id
       AND team_id   = p_team_id;

    IF v_member_team_id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Member is not linked to this team'
        );
    END IF;

    -- Soft-delete the team membership (role links are kept — unreachable
    -- through the app once the parent mtl row has status = 'removed')
    UPDATE member_team_link
       SET status = 'removed'
     WHERE member_team_id = v_member_team_id;

    SELECT COUNT(*)
      INTO v_other_team_count
      FROM member_team_link
     WHERE member_id = p_member_id
       AND status    = 'active';

    IF v_other_team_count = 0 THEN
        UPDATE members
           SET status = 'deleted'
         WHERE member_id = p_member_id;

        DELETE FROM user_member_link
         WHERE member_id = p_member_id;

        DELETE FROM car_pool_detail
         WHERE member_id = p_member_id;

        DELETE FROM member_squad_link
         WHERE member_id = p_member_id;

        -- event_attendance, match_squad_details, event_user_member_payment,
        -- and member_team_role_link are intentionally preserved.
    END IF;

    RETURN json_build_object(
        'success', true,
        'message', 'Member removed successfully'
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'message', SQLERRM
        );
END;
$$;

GRANT EXECUTE ON FUNCTION public.remove_member_from_team(bigint, bigint) TO anon;
GRANT EXECUTE ON FUNCTION public.remove_member_from_team(bigint, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_member_from_team(bigint, bigint) TO service_role;
