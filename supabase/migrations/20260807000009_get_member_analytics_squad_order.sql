-- Fix match selection dedup order:
-- DISTINCT ON (event_id) now orders by match_squad_id DESC first (latest squad
-- version per event), then msd.id DESC (latest detail row within that squad).

CREATE OR REPLACE FUNCTION public.get_member_analytics(p_member_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  RETURN jsonb_build_object(

    'teams', (
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'team_id',     t.team_id,
            'team_name',   t.team_name,
            'team_female', t.team_female,
            'club_id',     c.club_id,
            'club_name',   c.club_name
          )
          ORDER BY c.club_name, t.team_name
        ),
        '[]'::jsonb
      )
      FROM public.member_team_link mtl
      JOIN public.teams            t  ON t.team_id  = mtl.team_id
      JOIN public.clubs            c  ON c.club_id  = t.club_id
      WHERE mtl.member_id = p_member_id
        AND mtl.status    = 'active'
    ),

    'events', (
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'event_id',        e.event_id,
            'event_title',     e.event_title,
            'event_date_time', e.event_date_time,
            'event_type',      e.event_type,
            'event_code',      e.event_code,
            'team_id',         e.team_id,
            'team_name',       e.team_name,
            'opposition',      e.opposition,
            'home_away',       e.home_away,
            'response_id',     e.response_id,
            'response',        e.response,
            'response_label',  e.response_label
          )
          ORDER BY e.event_date_time DESC
        ),
        '[]'::jsonb
      )
      FROM (
        SELECT DISTINCT ON (ev.event_id)
               ev.event_id,
               ev.event_title,
               ev.event_date_time,
               et.event_type,
               ec.event_code,
               ev.team_id,
               t.team_name,
               ev.opposition,
               ev.home_away,
               ea_latest.response_id,
               ert.response_value  AS response,
               ert.display_value   AS response_label
        FROM (
          SELECT DISTINCT ON (ea.event_id)
                 ea.event_id,
                 ea.response_id
          FROM   public.event_attendance ea
          WHERE  ea.member_id = p_member_id
          ORDER  BY ea.event_id, ea.attendance_id DESC
        ) ea_latest
        JOIN public.events           ev  ON ev.event_id       = ea_latest.event_id
        JOIN public.event_types      et  ON et.event_type_id  = ev.event_type_id
        JOIN public.teams            t   ON t.team_id         = ev.team_id
        LEFT JOIN public.event_codes ec  ON ec.code_id        = ev.event_code_id
        LEFT JOIN public.event_response_type ert ON ert.response_id = ea_latest.response_id
        WHERE (ev.status IS NULL OR ev.status = 'active')
        ORDER BY ev.event_id
      ) e
    ),

    -- Latest match_squad per event (highest match_squad_id), then latest
    -- detail row within that squad (highest msd.id)
    'matchSelections', (
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'event_id',        ms.event_id,
            'event_title',     ms.event_title,
            'event_date_time', ms.event_date_time,
            'event_type',      ms.event_type,
            'event_code',      ms.event_code,
            'opposition',      ms.opposition,
            'home_away',       ms.home_away,
            'team_id',         ms.team_id,
            'team_name',       ms.team_name,
            'squad_id',        ms.squad_id,
            'squad_name',      ms.squad_name,
            'role_id',         ms.role_id,
            'role_name',       ms.role_name
          )
          ORDER BY ms.event_date_time DESC
        ),
        '[]'::jsonb
      )
      FROM (
        SELECT DISTINCT ON (e.event_id)
               e.event_id,
               e.event_title,
               e.event_date_time,
               et.event_type,
               ec.event_code,
               e.opposition,
               e.home_away,
               e.team_id,
               t.team_name,
               s.squad_id,
               s.squad_name,
               r.role_id,
               r.role_name
        FROM public.match_squad_details msd
        JOIN public.match_squads        msq ON msq.match_squad_id = msd.match_squad_id
        JOIN public.events              e   ON e.event_id         = msq.event_id
        JOIN public.event_types         et  ON et.event_type_id   = e.event_type_id
        JOIN public.teams               t   ON t.team_id          = e.team_id
        LEFT JOIN public.event_codes    ec  ON ec.code_id         = e.event_code_id
        LEFT JOIN public.squads         s   ON s.squad_id         = msd.squad_id
        LEFT JOIN public.roles          r   ON r.role_id          = msd.role_id
        WHERE msd.member_id = p_member_id
          AND (e.status IS NULL OR e.status = 'active')
        ORDER BY e.event_id, msq.match_squad_id DESC, msd.id DESC
      ) ms
    )

  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_member_analytics(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_member_analytics(bigint) TO anon;
