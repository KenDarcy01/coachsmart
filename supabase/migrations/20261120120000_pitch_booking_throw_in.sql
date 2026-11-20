-- Pitch planner (Ken, 2026-11-20): a match booking can start before the
-- throw-in (pitch from 10:30 for an 11:00 throw-in). The board now also
-- returns each match booking's throw-in so the planner can show both:
-- the league fixture's time (Irish time) or the CoachSmart match event's
-- time. Same output as before plus 'throw_ins'. v2 untouched.
CREATE OR REPLACE FUNCTION public.pitch_board_v2(p_club bigint, p_from date, p_to date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = 'public' AS $$
DECLARE v_monday date := date_trunc('week', p_from::timestamp)::date;
BEGIN
  PERFORM public.pitch_require_admin(p_club);
  RETURN public.pitch_board(p_club, p_from, p_to) || jsonb_build_object(
    'groups', public.pitch_groups_get(p_club, v_monday),
    'booking_groups', coalesce((
      SELECT jsonb_object_agg(b.booking_id::text, b.group_id)
        FROM pitch_bookings b
       WHERE b.club_id = p_club AND b.group_id IS NOT NULL
         AND b.starts_at < (p_to + 1)::timestamp AND b.ends_at > p_from::timestamp), '{}'::jsonb),
    'throw_ins', coalesce((
      SELECT jsonb_object_agg(b.booking_id::text,
               to_char(coalesce(g.start_at AT TIME ZONE 'Europe/Dublin',
                                e.event_date_time AT TIME ZONE 'UTC'), 'YYYY-MM-DD"T"HH24:MI:SS'))
        FROM pitch_bookings b
        LEFT JOIN gaa_games g ON g.game_id = b.gaa_game_id
        LEFT JOIN events e ON e.event_id = b.event_id
       WHERE b.club_id = p_club AND b.kind = 'match'
         AND (g.start_at IS NOT NULL OR e.event_date_time IS NOT NULL)
         AND b.starts_at < (p_to + 1)::timestamp AND b.ends_at > p_from::timestamp), '{}'::jsonb),
    'week', public.pitch_week_status(p_club, v_monday));
END $$;

REVOKE ALL ON FUNCTION public.pitch_board_v2(bigint,date,date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pitch_board_v2(bigint,date,date) TO authenticated;
