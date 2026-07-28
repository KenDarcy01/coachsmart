-- Migration: 20260728000004_soft_delete_remove_member
--
-- Rewrites remove_member_from_team() as a soft delete operation.
--
-- Key changes vs the previous hard-delete version:
--   - member_team_link.status is set to 'removed' instead of the row being deleted,
--     preserving the link for audit and historical reporting.
--   - members.status is set to 'deleted' only when the member has no remaining active
--     team memberships; the row itself is never deleted.
--   - Historical and financial data is intentionally preserved:
--       event_attendance        — attendance history must not be lost
--       match_squad_details     — match participation records must not be lost
--       event_user_member_payment — financial records must not be lost
--   - member_team_role_link rows are hard-deleted (no historical value once the
--     team membership is ended).
--   - user_member_link, car_pool_detail, and member_squad_link are hard-deleted
--     when the member has no remaining active teams (removes app access and
--     clears operational/transient data that has no historical value).

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
    -- 1. Locate the member_team_link row
    SELECT member_team_id
      INTO v_member_team_id
      FROM member_team_link
     WHERE member_id = p_member_id
       AND team_id   = p_team_id;

    -- 2. Guard: member must actually be linked to this team
    IF v_member_team_id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Member is not linked to this team'
        );
    END IF;

    -- 3. Hard-delete role assignments (no historical value)
    DELETE FROM member_team_role_link
     WHERE member_team_id = v_member_team_id;

    -- 4. Soft-delete the team membership
    UPDATE member_team_link
       SET status = 'removed'
     WHERE member_team_id = v_member_team_id;

    -- 5. Check whether the member still belongs to any other active team
    SELECT COUNT(*)
      INTO v_other_team_count
      FROM member_team_link
     WHERE member_id = p_member_id
       AND status    = 'active';

    -- 6. If no active teams remain, revoke app access and clear operational data
    IF v_other_team_count = 0 THEN
        -- Soft-delete the member record
        UPDATE members
           SET status = 'deleted'
         WHERE member_id = p_member_id;

        -- Remove app login link (revokes access)
        DELETE FROM user_member_link
         WHERE member_id = p_member_id;

        -- Remove car-pool assignments (operational, not historical)
        DELETE FROM car_pool_detail
         WHERE member_id = p_member_id;

        -- Remove squad assignments (operational, not historical)
        DELETE FROM member_squad_link
         WHERE member_id = p_member_id;

        -- NOTE: event_attendance, match_squad_details, and event_user_member_payment
        -- are intentionally NOT deleted — they are historical / financial records.
    END IF;

    -- 7. Success
    RETURN json_build_object(
        'success', true,
        'message', 'Member removed successfully'
    );

EXCEPTION
    WHEN OTHERS THEN
        -- 8. Surface any unexpected error to the caller
        RETURN json_build_object(
            'success', false,
            'message', SQLERRM
        );
END;
$$;

GRANT EXECUTE ON FUNCTION public.remove_member_from_team(bigint, bigint) TO anon;
GRANT EXECUTE ON FUNCTION public.remove_member_from_team(bigint, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_member_from_team(bigint, bigint) TO service_role;
