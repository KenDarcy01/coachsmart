-- get_edit_user_data: single call to populate the EditUser page app state.
-- Replaces three separate queries (users, clubs, view_user_members) and the
-- view itself. Returns user profile, clubs associated via active member-team
-- links, and a flat list of (member × team) rows for the member list.
--
-- Auth: enforces auth.uid() = p_user_id. Returns NULL for any other caller.
-- Clubs: only clubs reachable via the user's own active member-team chain.
-- Members: LEFT JOIN to teams so a member with no active team links still
--          appears (with null team fields) — shouldn't happen in practice.
-- Duplicates: uses user_member_link exclusively, never members.user_id,
--             so members the user both owns and has a link for appear once.

CREATE OR REPLACE FUNCTION public.get_edit_user_data(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  IF auth.uid() IS NULL OR auth.uid() != p_user_id THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object(

    -- ── User profile ──────────────────────────────────────────────────────
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

    -- ── Clubs dropdown (only clubs linked via active member-team chain) ───
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
        JOIN public.teams              t   ON t.club_id    = c.club_id
        JOIN public.member_team_link   mtl ON mtl.team_id  = t.team_id
                                          AND mtl.status   = 'active'
        JOIN public.user_member_link   uml ON uml.member_id = mtl.member_id
                                          AND uml.status   = 'active'
        WHERE uml.user_id = p_user_id
      ) c
    ),

    -- ── Member list (one row per active member × active team) ─────────────
    -- LEFT JOIN to teams/clubs so members with no active team still appear.
    'members', (
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
          ORDER BY m.first_name, t.team_name NULLS LAST
        ),
        '[]'::jsonb
      )
      FROM public.user_member_link  uml
      JOIN public.members           m   ON m.member_id   = uml.member_id
                                       AND m.status      = 'active'
      LEFT JOIN public.member_team_link mtl ON mtl.member_id = m.member_id
                                           AND mtl.status    = 'active'
      LEFT JOIN public.teams        t   ON t.team_id     = mtl.team_id
      LEFT JOIN public.clubs        c   ON c.club_id     = t.club_id
      WHERE uml.user_id = p_user_id
        AND uml.status  = 'active'
    )

  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_edit_user_data(uuid) TO authenticated;
