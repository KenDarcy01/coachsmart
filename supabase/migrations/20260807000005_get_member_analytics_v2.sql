-- get_member_analytics v2:
-- 1. Deduplicate event_attendance using DISTINCT ON (event_id) ORDER BY attendance_id DESC
--    so only the member's latest response per event is returned.
-- 2. Add event_code from event_codes table for client-side code filter chips.

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
            'team_id',   t.team_id,
            'team_name', t.team_name,
            'club_id',   c.club_id,
            'club_name', c.club_name
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

    -- Latest response per event only (DISTINCT ON deduplicates changed responses)
    'events', (
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'event_id',         e.event_id,
            'event_title',      e.event_title,
            'event_date_time',  e.event_date_time,
            'event_type',       et.event_type,
            'event_code',       ec.event_code,
            'team_id',          e.team_id,
            'team_name',        t.team_name,
            'opposition',       e.opposition,
            'home_away',        e.home_away,
            'response_id',      ea_latest.response_id,
            'response',         ert.response_value,
            'response_label',   ert.display_value
          )
          ORDER BY e.event_date_time DESC
        ),
        '[]'::jsonb
      )
      FROM (
        SELECT DISTINCT ON (ea.event_id)
               ea.event_id,
               ea.response_id
        FROM   public.event_attendance ea
        WHERE  ea.member_id = p_member_id
        ORDER  BY ea.event_id, ea.attendance_id DESC
      ) ea_latest
      JOIN public.events            e   ON e.event_id        = ea_latest.event_id
      JOIN public.event_types       et  ON et.event_type_id  = e.event_type_id
      JOIN public.teams             t   ON t.team_id         = e.team_id
      LEFT JOIN public.event_codes  ec  ON ec.event_code_id  = e.event_code_id
      LEFT JOIN public.event_response_type ert ON ert.response_id = ea_latest.response_id
      WHERE (e.status IS NULL OR e.status = 'active')
    ),

    'matchSelections', (
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'event_id',        e.event_id,
            'event_title',     e.event_title,
            'event_date_time', e.event_date_time,
            'opposition',      e.opposition,
            'home_away',       e.home_away,
            'team_id',         e.team_id,
            'team_name',       t.team_name,
            'squad_id',        s.squad_id,
            'squad_name',      s.squad_name,
            'role_id',         r.role_id,
            'role_name',       r.role_name
          )
          ORDER BY e.event_date_time DESC
        ),
        '[]'::jsonb
      )
      FROM public.match_squad_details msd
      JOIN public.match_squads        ms  ON ms.match_squad_id = msd.match_squad_id
      JOIN public.events              e   ON e.event_id        = ms.event_id
      JOIN public.teams               t   ON t.team_id         = e.team_id
      LEFT JOIN public.squads         s   ON s.squad_id        = msd.squad_id
      LEFT JOIN public.roles          r   ON r.role_id         = msd.role_id
      WHERE msd.member_id = p_member_id
        AND (e.status IS NULL OR e.status = 'active')
    )

  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_member_analytics(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_member_analytics(bigint) TO anon;
