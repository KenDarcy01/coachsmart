-- Unify field names across member_requests and access_requests.
-- Also switch to LEFT JOIN on user_member_link so member requests
-- appear even if the linked user account is still pending.

CREATE OR REPLACE FUNCTION public.get_pending_team_requests(p_team_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
    RETURN jsonb_build_object(
        'success', true,
        'member_requests', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'member_team_id',        mtl.member_team_id,
                    'member_id',             m.member_id,
                    'first_name',            m.first_name,
                    'last_name',             m.last_name,
                    'requested_at',          mtl.created_at,
                    'requesting_user_id',    u.user_id,
                    'requesting_user_name',  u.first_name || ' ' || u.last_name,
                    'requesting_user_email', u.email_address
                )
                ORDER BY mtl.created_at ASC
            )
              FROM public.member_team_link        mtl
              JOIN public.members                 m   ON mtl.member_id = m.member_id
              LEFT JOIN public.user_member_link   uml ON m.member_id   = uml.member_id
              LEFT JOIN public.users              u   ON uml.user_id   = u.user_id
             WHERE mtl.team_id = p_team_id
               AND mtl.status  = 'pending'
        ), '[]'::jsonb),
        'access_requests', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'user_member_id',        uml.user_member_id,
                    'member_id',             m.member_id,
                    'first_name',            m.first_name,
                    'last_name',             m.last_name,
                    'requested_at',          uml.created_at,
                    'requesting_user_id',    u.user_id,
                    'requesting_user_name',  u.first_name || ' ' || u.last_name,
                    'requesting_user_email', u.email_address
                )
                ORDER BY uml.created_at ASC
            )
              FROM public.user_member_link uml
              JOIN public.members          m   ON uml.member_id = m.member_id
              JOIN public.users            u   ON uml.user_id   = u.user_id
              JOIN public.member_team_link mtl ON m.member_id   = mtl.member_id
             WHERE mtl.team_id = p_team_id
               AND mtl.status  = 'active'
               AND uml.status  = 'pending'
        ), '[]'::jsonb),
        'available_roles', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'role_id',    r.role_id,
                    'role_name',  r.role_name,
                    'role_grade', r.role_grade,
                    'role_level', r.role_level
                )
                ORDER BY r.role_grade DESC, r.role_level DESC
            )
              FROM public.team_roles_link trl
              JOIN public.roles           r ON trl.role_id = r.role_id
             WHERE trl.team_id = p_team_id
        ), '[]'::jsonb)
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_pending_team_requests(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_pending_team_requests(bigint) TO service_role;
