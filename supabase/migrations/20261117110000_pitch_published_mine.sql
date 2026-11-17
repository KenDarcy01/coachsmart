-- Pitch planner, members' view (Ken, 2026-11-17): a week grid per pitch
-- and "Your teams this week". The published week now also returns
-- my_teams (the caller's teams at the club, own or via a linked member),
-- and each pitch's held slots and unavailable times (live, not snapshot).
CREATE OR REPLACE FUNCTION public.pitch_published_week(p_club bigint, p_monday date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = 'public' AS $$
DECLARE
  w pitch_weeks%ROWTYPE;
  v_week date := date_trunc('week', p_monday::timestamp)::date;
  v_mine jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT (
       coalesce(public.is_club_officer(p_club), false)
       OR EXISTS (SELECT 1 FROM teams t
                    JOIN member_team_link mtl ON mtl.team_id = t.team_id AND mtl.status = 'active'
                    JOIN members m ON m.member_id = mtl.member_id
                   WHERE m.user_id = auth.uid() AND t.club_id = p_club)) THEN
    RAISE EXCEPTION 'Only club members can see the pitch plan' USING ERRCODE = '42501';
  END IF;
  SELECT coalesce(jsonb_agg(DISTINCT t.team_id), '[]'::jsonb) INTO v_mine
    FROM teams t
    JOIN member_team_link mtl ON mtl.team_id = t.team_id AND mtl.status = 'active'
    JOIN members m ON m.member_id = mtl.member_id
   WHERE t.club_id = p_club
     AND (m.user_id = auth.uid()
          OR m.member_id IN (SELECT uml.member_id FROM user_member_link uml WHERE uml.user_id = auth.uid()));
  SELECT * INTO w FROM pitch_weeks WHERE club_id = p_club AND week_start = v_week AND published_at IS NOT NULL;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('week_start', v_week, 'published_at', NULL, 'my_teams', v_mine);
  END IF;
  RETURN w.snapshot || jsonb_build_object(
    'published_at', w.published_at,
    'my_teams', v_mine,
    'hours', coalesce((
      SELECT jsonb_agg(jsonb_build_object('pitch_id', h.pitch_id, 'weekday', h.weekday,
               'opens', to_char(h.opens, 'HH24:MI'), 'closes', to_char(h.closes, 'HH24:MI')))
        FROM pitch_hours h JOIN pitches p ON p.pitch_id = h.pitch_id
       WHERE p.club_id = p_club AND p.is_active), '[]'::jsonb),
    'blocks', coalesce((
      SELECT jsonb_agg(jsonb_build_object('pitch_id', b.pitch_id, 'weekday', b.weekday,
               'opens', to_char(b.opens, 'HH24:MI'), 'closes', to_char(b.closes, 'HH24:MI')))
        FROM pitch_blocks b JOIN pitches p ON p.pitch_id = b.pitch_id
       WHERE p.club_id = p_club AND p.is_active), '[]'::jsonb));
END $$;
