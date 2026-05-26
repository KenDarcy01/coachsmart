-- Replace get_unresponded_events(bigint) to remove dependency on view_event_attendance_details.
-- The view's role-join CTEs are unused by this function; only user/member/event/attendance
-- columns were referenced, so the replacement query is simpler than the original view.

CREATE OR REPLACE FUNCTION "public"."get_unresponded_events"("event_id_param" bigint)
RETURNS SETOF "jsonb"
LANGUAGE "plpgsql"
AS $$
BEGIN
  RETURN QUERY
  WITH latest_attendance AS (
    SELECT
      ea.event_id,
      ea.member_id,
      ea.response_id,
      row_number() OVER (
        PARTITION BY ea.event_id, ea.member_id
        ORDER BY ea.created_at DESC
      ) AS rn
    FROM public.event_attendance ea
  )
  SELECT DISTINCT
    jsonb_build_object(
      'email',             u.email_address,
      'team_name',         t.team_name,
      'event_title',       e.event_title,
      'event_date_time',   e.event_date_time,
      'full_name',         u.first_name || ' ' || u.last_name,
      'first_name',        u.first_name,
      'last_name',         u.last_name,
      'member_first_name', m.first_name,
      'member_last_name',  m.last_name
    )
  FROM public.events e
  JOIN public.teams t    ON t.team_id    = e.team_id
  JOIN public.member_team_link mtl ON mtl.team_id = t.team_id
  JOIN public.members m  ON m.member_id  = mtl.member_id
  JOIN public.user_member_link uml ON uml.member_id = m.member_id
  JOIN public.users u    ON u.user_id    = uml.user_id
  LEFT JOIN latest_attendance la
         ON la.event_id  = e.event_id
        AND la.member_id = m.member_id
        AND la.rn = 1
  WHERE e.event_id = event_id_param
    AND (la.response_id IS NULL OR la.response_id = 0);
END;
$$;
