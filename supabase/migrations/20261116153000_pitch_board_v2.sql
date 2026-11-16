-- Pitch planner: one call for the v3 board. pitch_board plus the club's
-- groups (with training slots booked that week), each booking's group, and
-- the week's publish state.
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
    'week', public.pitch_week_status(p_club, v_monday));
END $$;

REVOKE ALL ON FUNCTION public.pitch_board_v2(bigint,date,date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pitch_board_v2(bigint,date,date) TO authenticated;
