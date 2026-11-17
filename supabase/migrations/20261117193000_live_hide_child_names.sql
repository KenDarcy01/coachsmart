-- Live scores never show children's names (Ken, 2026-11-17).
-- Scorer and substitution names show only for adult teams (teams.team_juvenile = false).
-- Under-18 or unset teams get no names, so the app, the share link and alerts
-- fall back to the club name. The score keeper is unaffected.

CREATE OR REPLACE FUNCTION public.lm_show_names(p_event_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
  SELECT COALESCE((
    SELECT t.team_juvenile = false
      FROM public.events e
      JOIN public.teams t ON t.team_id = e.team_id
     WHERE e.event_id = p_event_id
  ), false);
$$;
REVOKE ALL ON FUNCTION public.lm_show_names(bigint) FROM PUBLIC, anon, authenticated;

-- Patch the live function text in place so other edits to these functions survive.
DO $mig$
DECLARE
  v_def text;
  v_new text;
BEGIN
  -- lm_state(bigint, boolean, bigint): scorer names and subs
  SELECT pg_get_functiondef('public.lm_state(bigint,boolean,bigint)'::regprocedure) INTO v_def;
  IF position('lm_show_names' in v_def) = 0 THEN
    v_new := replace(v_def, 'p_names AND d.side', 'p_names AND public.lm_show_names(p_event_id) AND d.side');
    v_new := replace(v_new, 'WHEN NOT p_names THEN', 'WHEN NOT (p_names AND public.lm_show_names(p_event_id)) THEN');
    IF position('p_names AND public.lm_show_names(p_event_id) AND d.side' in v_new) = 0
       OR position('WHEN NOT (p_names AND public.lm_show_names(p_event_id)) THEN' in v_new) = 0 THEN
      RAISE EXCEPTION 'lm_state text not as expected';
    END IF;
    EXECUTE v_new;
  END IF;

  -- lm_alert_claim(bigint, integer): scorer name in push alerts
  SELECT pg_get_functiondef('public.lm_alert_claim(bigint,integer)'::regprocedure) INTO v_def;
  IF position('lm_show_names' in v_def) = 0 THEN
    v_new := replace(v_def,
      'LEFT JOIN public.members m ON m.member_id = d.member_id',
      'LEFT JOIN public.members m ON m.member_id = d.member_id AND public.lm_show_names(v_ms.event_id)');
    IF v_new = v_def THEN
      RAISE EXCEPTION 'lm_alert_claim text not as expected';
    END IF;
    EXECUTE v_new;
  END IF;
END
$mig$;
