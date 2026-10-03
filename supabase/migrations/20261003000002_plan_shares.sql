-- plan_shares: coach-to-coach plan sharing
CREATE TABLE IF NOT EXISTS public.plan_shares (
  share_id        bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  created_at      timestamp with time zone NOT NULL DEFAULT now(),
  from_user_id    uuid   NOT NULL,
  to_user_id      uuid   NOT NULL,
  plan_json       jsonb  NOT NULL,
  session_title   text   NOT NULL,
  message         text,
  status          text   NOT NULL DEFAULT 'pending',  -- pending | accepted | dismissed
  CONSTRAINT plan_shares_pkey PRIMARY KEY (share_id),
  CONSTRAINT plan_shares_from_user_fkey FOREIGN KEY (from_user_id) REFERENCES public.users(user_id),
  CONSTRAINT plan_shares_to_user_fkey   FOREIGN KEY (to_user_id)   REFERENCES public.users(user_id),
  CONSTRAINT plan_shares_status_check   CHECK (status IN ('pending','accepted','dismissed'))
);

CREATE INDEX IF NOT EXISTS plan_shares_to_user_idx   ON public.plan_shares (to_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS plan_shares_from_user_idx ON public.plan_shares (from_user_id, created_at DESC);

ALTER TABLE public.plan_shares ENABLE ROW LEVEL SECURITY;

-- Sender can see their own outbox
CREATE POLICY "plan_shares_sender_select" ON public.plan_shares
  FOR SELECT USING (auth.uid() = from_user_id);

-- Recipient can see their own inbox
CREATE POLICY "plan_shares_recipient_select" ON public.plan_shares
  FOR SELECT USING (auth.uid() = to_user_id);

-- Only sender can insert
CREATE POLICY "plan_shares_insert" ON public.plan_shares
  FOR INSERT WITH CHECK (auth.uid() = from_user_id);

-- Recipient can update status (accept / dismiss)
CREATE POLICY "plan_shares_recipient_update" ON public.plan_shares
  FOR UPDATE USING (auth.uid() = to_user_id);
