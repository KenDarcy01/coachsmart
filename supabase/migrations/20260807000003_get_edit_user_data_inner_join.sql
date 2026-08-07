-- Exclude members with no active team links from get_edit_user_data.
-- Changed LEFT JOIN → JOIN on member_team_link/teams/clubs in the userMembers query.

CREATE OR REPLACE FUNCTION public.get_edit_user_data(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  RETURN jsonb_build_object(

    'user', (
      SELECT jsonb_build_object(
        'user_id',       u.user_id,
        'email_address', u.email_address,
        'first_name',    u.first_name,
        'last_name',     u.last_name,
        'phone_number',  u.phone_number,
        'default_club',  u.default_club
      )
      FROM public.users u
      WHERE u.user_id = p_user_id
    ),

    'clubs', (
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object('club_id', c.club_id, 'club_name', c.club_name)
          ORDER BY c.club_name
        ),
        '[]'::jsonb
      )
      FROM (
        SELECT DISTINCT c.club_id, c.club_name
        FROM public.clubs              c
        JOIN public.teams              t   ON t.club_id     = c.club_id
        JOIN public.member_team_link   mtl ON mtl.team_id   = t.team_id
                                          AND mtl.status    = 'active'
        JOIN public.user_member_link   uml ON uml.member_id = mtl.member_id
                                          AND uml.status    = 'active'
        WHERE uml.user_id = p_user_id
      ) c
    ),

    'userMembers', (
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'member_id',          m.member_id,
            'member_team_id',     mtl.member_team_id,
            'first_name',         m.first_name,
            'last_name',          m.last_name,
            'full_name',          TRIM(CONCAT(m.first_name, ' ', m.last_name)),
            'unique_member_code', m.unique_member_code,
            'team_id',            mtl.team_id,
            'team_name',          t.team_name,
            'club_id',            c.club_id,
            'club_name',          c.club_name
          )
          ORDER BY m.first_name, t.team_name
        ),
        '[]'::jsonb
      )
      FROM public.user_member_link  uml
      JOIN public.members           m   ON m.member_id    = uml.member_id
                                       AND m.status       = 'active'
      JOIN public.member_team_link  mtl ON mtl.member_id  = m.member_id
                                       AND mtl.status     = 'active'
      JOIN public.teams             t   ON t.team_id      = mtl.team_id
      JOIN public.clubs             c   ON c.club_id      = t.club_id
      WHERE uml.user_id = p_user_id
        AND uml.status  = 'active'
    )

  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_edit_user_data(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_edit_user_data(uuid) TO anon;
