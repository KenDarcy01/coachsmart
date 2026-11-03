-- Senior team diary: the training plan now comes from a Google Sheet.
-- Coaches press Diary > Publish in the sheet; the diary-sheet-publish edge
-- function checks it and calls diary_publish() below. Who can publish is
-- controlled by edit access to the sheet (plus a shared secret the sheet
-- script holds), not by RLS: nobody writes these tables from the browser.
--
--   diary_plan         one row per publish (kept as history); the page reads
--                      the newest. Holds blocks, sessions and the team
--                      schedule. Any signed-in user may read it.
--   diary_player_days  per-player schedule overrides and coach notes, one row
--                      per player email per day. A player reads only the
--                      rows for their own sign-in email.

CREATE TABLE IF NOT EXISTS public.diary_plan (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  published_at timestamptz NOT NULL DEFAULT now(),
  published_by text,
  plan jsonb NOT NULL
);

CREATE TABLE IF NOT EXISTS public.diary_player_days (
  email text NOT NULL,
  day date NOT NULL,
  slots jsonb,            -- null = follow the team plan that day
  notes jsonb NOT NULL DEFAULT '[]'::jsonb,
  PRIMARY KEY (email, day)
);

ALTER TABLE public.diary_plan ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.diary_player_days ENABLE ROW LEVEL SECURITY;

CREATE POLICY diary_plan_read ON public.diary_plan
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY diary_player_days_own ON public.diary_player_days
  FOR SELECT TO authenticated
  USING (email = lower(auth.jwt() ->> 'email'));

GRANT SELECT ON public.diary_plan TO authenticated;
GRANT SELECT ON public.diary_player_days TO authenticated;

-- Replaces the player rows and adds a new plan version in one transaction.
-- Returns the player emails that have no CoachSmart login yet (their rows
-- are still saved, so they appear once the player signs up).
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

  INSERT INTO public.diary_player_days (email, day, slots, notes)
  SELECT lower(r ->> 'email'), (r ->> 'day')::date,
         CASE WHEN r ? 'slots' AND jsonb_typeof(r -> 'slots') = 'array' THEN r -> 'slots' END,
         COALESCE(r -> 'notes', '[]'::jsonb)
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
