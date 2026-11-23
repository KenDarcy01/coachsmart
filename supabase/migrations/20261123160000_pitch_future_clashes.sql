-- Pitch planner (Ken, 2026-11-23): when training is saved it rolls into the
-- following weeks, so warn if that weekly slot clashes with a booking
-- already made in a later week (e.g. a match booked well ahead). Read only;
-- additive; v2 untouched.

CREATE OR REPLACE FUNCTION public.pitch_future_clashes(
  p_club bigint, p_pitch bigint, p_part int, p_start timestamp, p_end timestamp,
  p_booking bigint DEFAULT NULL, p_group bigint DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = 'public' AS $$
DECLARE
  v_group bigint := p_group;
BEGIN
  PERFORM public.pitch_require_admin(p_club);
  IF p_booking IS NOT NULL AND v_group IS NULL THEN
    SELECT group_id INTO v_group FROM pitch_bookings WHERE booking_id = p_booking AND club_id = p_club;
  END IF;
  RETURN coalesce((
    WITH RECURSIVE chain AS (
      SELECT booking_id FROM pitch_bookings WHERE booking_id = p_booking
      UNION ALL
      SELECT c.booking_id FROM pitch_bookings c JOIN chain ON c.rolled_from = chain.booking_id),
    weeks AS (SELECT k FROM generate_series(1, 26) k),
    near AS (
      SELECT p_pitch AS pitch_id, true AS same
      UNION ALL
      SELECT CASE WHEN s.pitch_a = p_pitch THEN s.pitch_b ELSE s.pitch_a END, false
        FROM pitch_shared_ground s
       WHERE s.club_id = p_club AND p_pitch IN (s.pitch_a, s.pitch_b)),
    hits AS (
      SELECT DISTINCT ON (b.booking_id) b.*, p.name AS pitch_name, g.name AS group_name
        FROM weeks w
        JOIN near n ON true
        JOIN pitch_bookings b
          ON b.club_id = p_club AND b.pitch_id = n.pitch_id AND b.status = 'confirmed'
         AND b.starts_at < p_end + make_interval(weeks => w.k)
         AND p_start + make_interval(weeks => w.k) < b.ends_at
         AND (NOT n.same OR (b.part & p_part) <> 0)
        JOIN pitches p ON p.pitch_id = b.pitch_id
        LEFT JOIN pitch_groups g ON g.group_id = b.group_id
       WHERE b.booking_id NOT IN (SELECT booking_id FROM chain)
         AND (v_group IS NULL OR b.group_id IS DISTINCT FROM v_group)
       ORDER BY b.booking_id)
    SELECT jsonb_agg(jsonb_build_object(
             'booking_id', h.booking_id, 'kind', h.kind,
             'title', coalesce(nullif(h.title, ''), h.group_name, initcap(h.kind)),
             'pitch', h.pitch_name, 'starts_at', h.starts_at, 'ends_at', h.ends_at)
           ORDER BY h.starts_at)
      FROM hits h), '[]'::jsonb);
END $$;
REVOKE ALL ON FUNCTION public.pitch_future_clashes(bigint, bigint, int, timestamp, timestamp, bigint, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pitch_future_clashes(bigint, bigint, int, timestamp, timestamp, bigint, bigint) TO authenticated;
