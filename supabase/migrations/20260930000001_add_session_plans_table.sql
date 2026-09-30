-- session_plans: AI-generated training session plans linked to events
CREATE TABLE IF NOT EXISTS public.session_plans (
  plan_id    bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  event_id   bigint NOT NULL,
  created_by uuid   NOT NULL,
  plan_json  jsonb  NOT NULL,
  is_active  boolean NOT NULL DEFAULT true,
  CONSTRAINT session_plans_pkey PRIMARY KEY (plan_id),
  CONSTRAINT session_plans_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(event_id),
  CONSTRAINT session_plans_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(user_id)
);

CREATE INDEX IF NOT EXISTS session_plans_event_id_idx   ON public.session_plans (event_id);
CREATE INDEX IF NOT EXISTS session_plans_created_by_idx ON public.session_plans (created_by);

ALTER TABLE public.session_plans ENABLE ROW LEVEL SECURITY;

-- Anyone authenticated can read session plans
CREATE POLICY "session_plans_select" ON public.session_plans
  FOR SELECT USING (true);

-- Only the creator can insert or update their own plans
CREATE POLICY "session_plans_insert" ON public.session_plans
  FOR INSERT WITH CHECK (auth.uid() = created_by);

CREATE POLICY "session_plans_update" ON public.session_plans
  FOR UPDATE USING (auth.uid() = created_by);
