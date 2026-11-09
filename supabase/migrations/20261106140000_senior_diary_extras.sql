-- Senior diary: events and activities from the coaches' sheet (Events and
-- Activities tabs). Squad-wide ones live in diary_plan.plan (extras, notes);
-- ones for a single player go in diary_player_days.extras, which RLS
-- already limits to that player's own email.

ALTER TABLE public.diary_player_days
  ADD COLUMN IF NOT EXISTS extras jsonb NOT NULL DEFAULT '[]'::jsonb;

CREATE OR REPLACE FUNCTION public.diary_publish(p_plan jsonb, p_players jsonb, p_by text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_id bigint;
  v_unmatched jsonb;
BEGIN
  DELETE FROM public.diary_player_days WHERE true;

  INSERT INTO public.diary_player_days (email, day, slots, notes, extras)
  SELECT lower(r ->> 'email'), (r ->> 'day')::date,
         CASE WHEN r ? 'slots' AND jsonb_typeof(r -> 'slots') = 'array' THEN r -> 'slots' END,
         COALESCE(r -> 'notes', '[]'::jsonb),
         CASE WHEN jsonb_typeof(r -> 'extras') = 'array' THEN r -> 'extras' ELSE '[]'::jsonb END
  FROM jsonb_array_elements(COALESCE(p_players, '[]'::jsonb)) r;

  INSERT INTO public.diary_plan (plan, published_by) VALUES (p_plan, p_by)
  RETURNING id INTO v_id;

  SELECT COALESCE(jsonb_agg(e ORDER BY e), '[]'::jsonb) INTO v_unmatched
  FROM (SELECT DISTINCT email AS e FROM public.diary_player_days) x
  WHERE NOT EXISTS (SELECT 1 FROM auth.users u WHERE lower(u.email) = x.e);

  RETURN jsonb_build_object('plan_id', v_id, 'unmatched', v_unmatched);
END;
$$;

REVOKE ALL ON FUNCTION public.diary_publish(jsonb, jsonb, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.diary_publish(jsonb, jsonb, text) TO service_role;
