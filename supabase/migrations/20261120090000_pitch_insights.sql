-- Pitch planner Insights (Ken, 2026-11-20): utilisation over time, busiest
-- times, closures, teams, and what unused rented slots cost. Rented pitches
-- get an hourly cost (set by the admin). Data starts when the planner did
-- (16 Nov 2026). Additive only; v2 untouched.

ALTER TABLE public.pitches ADD COLUMN IF NOT EXISTS hourly_cost numeric(8,2);

CREATE OR REPLACE FUNCTION public.pitch_cost_save(p_club bigint, p_pitch bigint, p_cost numeric)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $$
BEGIN
  PERFORM public.pitch_require_admin(p_club);
  UPDATE pitches SET hourly_cost = CASE WHEN p_cost IS NULL OR p_cost <= 0 THEN NULL ELSE p_cost END
   WHERE pitch_id = p_pitch AND club_id = p_club;
  IF NOT FOUND THEN RAISE EXCEPTION 'Pitch not found'; END IF;
END $$;

-- One call for the Insights tab. Minutes throughout; a half-pitch booking
-- counts half. held = slots the club holds (today's slot list) per day;
-- closed days count their held time as closed, not free.
CREATE OR REPLACE FUNCTION public.pitch_insights(p_club bigint, p_from date, p_to date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = 'public' AS $$
BEGIN
  PERFORM public.pitch_require_admin(p_club);
  IF p_to < p_from OR p_to - p_from > 400 THEN
    RAISE EXCEPTION 'Pick a period of up to a year';
  END IF;
  RETURN (
WITH p AS (
  SELECT p.pitch_id, p.name, p.surface, p.sort, v.name AS venue, coalesce(v.rented, false) AS rented, p.hourly_cost
    FROM pitches p JOIN pitch_venues v ON v.venue_id = p.venue_id
   WHERE p.club_id = p_club AND p.is_active),
d AS (SELECT gs::date AS day FROM generate_series(p_from, p_to, interval '1 day') gs),
held AS (
  SELECT p.pitch_id, d.day,
         coalesce((SELECT sum(extract(epoch FROM (h.closes - h.opens)) / 60)
                     FROM pitch_hours h WHERE h.pitch_id = p.pitch_id
                      AND h.weekday = extract(isodow FROM d.day)), 0)::int AS held,
         EXISTS (SELECT 1 FROM pitch_closures c WHERE c.pitch_id = p.pitch_id
                  AND d.day BETWEEN c.starts_on AND c.ends_on) AS closed
    FROM p CROSS JOIN d),
bk AS (
  SELECT b.* , b.starts_at::date AS day,
         extract(epoch FROM (b.ends_at - b.starts_at)) / 60
           * length(replace((b.part::int::bit(4))::text, '0', '')) / 4.0 AS mins
    FROM pitch_bookings b
   WHERE b.club_id = p_club AND b.status = 'confirmed' AND b.pitch_id IS NOT NULL
     AND b.starts_at >= p_from AND b.starts_at < p_to + 1),
daily AS (
  SELECT h.pitch_id, h.day, h.held, h.closed,
         coalesce((SELECT sum(mins) FROM bk WHERE bk.pitch_id = h.pitch_id AND bk.day = h.day), 0)::int AS booked
    FROM held h)
SELECT jsonb_build_object(
  'from', p_from, 'to', p_to,
  'pitches', (SELECT coalesce(jsonb_agg(jsonb_build_object('pitch_id', pitch_id, 'name', name, 'surface', surface,
        'venue', venue, 'rented', rented, 'cost', hourly_cost) ORDER BY sort, name), '[]') FROM p),
  'weeks', (SELECT coalesce(jsonb_agg(x ORDER BY x->>'week', (x->>'pitch_id')::bigint), '[]') FROM (
      SELECT jsonb_build_object('week', date_trunc('week', day)::date, 'pitch_id', pitch_id,
               'held', sum(held), 'booked', sum(CASE WHEN closed THEN 0 ELSE booked END),
               'closed', sum(CASE WHEN closed THEN held ELSE 0 END)) x
        FROM daily GROUP BY date_trunc('week', day), pitch_id) q),
  'heat', (SELECT coalesce(jsonb_agg(jsonb_build_object('dow', dow, 'hour', hr, 'mins', m)), '[]') FROM (
      SELECT extract(isodow FROM g.t)::int dow, extract(hour FROM g.t)::int hr, count(*) * 15 m
        FROM bk, generate_series(bk.starts_at, bk.ends_at - interval '1 minute', interval '15 minutes') g(t)
       GROUP BY 1, 2) q),
  'closures', (SELECT coalesce(jsonb_agg(jsonb_build_object('pitch_id', c.pitch_id, 'starts_on', c.starts_on,
        'ends_on', c.ends_on, 'reason', coalesce(c.reason, ''),
        'days', least(c.ends_on, p_to) - greatest(c.starts_on, p_from) + 1,
        'still_on', (SELECT count(*) FROM pitch_bookings b WHERE b.pitch_id = c.pitch_id
                   AND b.status = 'confirmed' AND b.starts_at::date BETWEEN c.starts_on AND c.ends_on))
        ORDER BY c.starts_on DESC), '[]')
      FROM pitch_closures c JOIN p ON p.pitch_id = c.pitch_id
     WHERE c.starts_on <= p_to AND c.ends_on >= p_from),
  'kinds', (SELECT jsonb_build_object(
      'matches', count(*) FILTER (WHERE kind = 'match'),
      'training_min', coalesce(sum(mins) FILTER (WHERE kind = 'training'), 0)::int,
      'training', count(*) FILTER (WHERE kind = 'training'),
      'other', count(*) FILTER (WHERE kind = 'other')) FROM bk),
  'groups', (SELECT coalesce(jsonb_agg(jsonb_build_object('group_id', g.group_id, 'name', g.name,
        'target', g.sessions, 'sessions', coalesce(s.n, 0), 'mins', coalesce(s.m, 0)) ORDER BY coalesce(s.m, 0) DESC, g.name), '[]')
      FROM pitch_groups g
      LEFT JOIN (SELECT group_id, count(*) n, sum(mins)::int m FROM bk WHERE kind = 'training' GROUP BY group_id) s
        ON s.group_id = g.group_id
     WHERE g.club_id = p_club AND g.is_active)
)

  );
END $$;

REVOKE ALL ON FUNCTION public.pitch_cost_save(bigint, bigint, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pitch_cost_save(bigint, bigint, numeric) TO authenticated;
REVOKE ALL ON FUNCTION public.pitch_insights(bigint, date, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pitch_insights(bigint, date, date) TO authenticated;
