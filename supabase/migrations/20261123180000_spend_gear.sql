-- Coach expenses and gear requests (thread "Explore coach expenses and gear
-- orders", Ken 2026-11-23 "Build it. Only give me access for now").
-- Coaches log expenses (receipt photo) and request gear in v3; club officers
-- approve, track pay-backs and group gear orders on coachsmart.app/club/spend.html.
-- Records only: CoachSmart never moves club money, the treasurer pays back
-- outside the app. All tables RLS on with no policies: only the `spend` edge
-- function (service role) reads or writes them. Nothing here touches v2.

-- Who can use it while it is being tried (Ken only for now).
CREATE TABLE IF NOT EXISTS public.spend_access (
  user_id   uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  added_at  timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.spend_access ENABLE ROW LEVEL SECURITY;
INSERT INTO public.spend_access (user_id)
SELECT u.user_id FROM public.users u
 WHERE lower(u.email_address) = 'ken.darcy@gmail.com' AND u.user_id IS NOT NULL
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION public.spend_has_access()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = 'public' AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (SELECT 1 FROM spend_access WHERE user_id = auth.uid());
$$;
REVOKE ALL ON FUNCTION public.spend_has_access() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.spend_has_access() TO authenticated, service_role;

-- Team budget per calendar season, set by a club officer.
CREATE TABLE IF NOT EXISTS public.spend_budgets (
  team_id  bigint NOT NULL REFERENCES public.teams(team_id) ON DELETE CASCADE,
  season   int    NOT NULL,
  amount   numeric(10,2) NOT NULL CHECK (amount >= 0),
  set_by   uuid,
  set_at   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (team_id, season)
);
ALTER TABLE public.spend_budgets ENABLE ROW LEVEL SECURITY;

-- The club's gear stock list.
CREATE TABLE IF NOT EXISTS public.gear_items (
  gear_item_id bigserial PRIMARY KEY,
  club_id      bigint NOT NULL REFERENCES public.clubs(club_id) ON DELETE CASCADE,
  name         text   NOT NULL,
  category     text   NOT NULL DEFAULT 'Other',
  unit_price   numeric(10,2) CHECK (unit_price IS NULL OR unit_price >= 0),
  detail       text,
  sort         int    NOT NULL DEFAULT 0,
  is_active    boolean NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS gear_items_club_idx ON public.gear_items (club_id);
ALTER TABLE public.gear_items ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.team_expenses (
  expense_id   bigserial PRIMARY KEY,
  team_id      bigint NOT NULL REFERENCES public.teams(team_id) ON DELETE CASCADE,
  club_id      bigint REFERENCES public.clubs(club_id),
  event_id     bigint REFERENCES public.events(event_id) ON DELETE SET NULL,
  created_by   uuid   NOT NULL,
  spent_on     date   NOT NULL,
  amount       numeric(10,2) NOT NULL CHECK (amount > 0 AND amount < 100000),
  shop         text,
  category     text   NOT NULL,
  note         text,
  payback      text   NOT NULL DEFAULT 'bank' CHECK (payback IN ('bank','cash','none')),
  receipt_path text,
  ai_read      jsonb,
  status       text   NOT NULL DEFAULT 'submitted'
               CHECK (status IN ('submitted','approved','queried','rejected','paid')),
  status_note  text,
  decided_by   uuid,
  decided_at   timestamptz,
  paid_at      timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now(),
  deleted_at   timestamptz
);
CREATE INDEX IF NOT EXISTS team_expenses_team_idx ON public.team_expenses (team_id, spent_on);
CREATE INDEX IF NOT EXISTS team_expenses_club_idx ON public.team_expenses (club_id, spent_on);
ALTER TABLE public.team_expenses ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.gear_requests (
  gear_request_id bigserial PRIMARY KEY,
  team_id      bigint NOT NULL REFERENCES public.teams(team_id) ON DELETE CASCADE,
  club_id      bigint REFERENCES public.clubs(club_id),
  created_by   uuid   NOT NULL,
  note         text,
  status       text   NOT NULL DEFAULT 'requested'
               CHECK (status IN ('requested','approved','queried','rejected','ordered','delivered')),
  status_note  text,
  decided_by   uuid,
  decided_at   timestamptz,
  ordered_at   timestamptz,
  delivered_at timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now(),
  deleted_at   timestamptz
);
CREATE INDEX IF NOT EXISTS gear_requests_team_idx ON public.gear_requests (team_id, created_at);
CREATE INDEX IF NOT EXISTS gear_requests_club_idx ON public.gear_requests (club_id, created_at);
ALTER TABLE public.gear_requests ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.gear_request_lines (
  line_id         bigserial PRIMARY KEY,
  gear_request_id bigint NOT NULL REFERENCES public.gear_requests(gear_request_id) ON DELETE CASCADE,
  gear_item_id    bigint REFERENCES public.gear_items(gear_item_id) ON DELETE SET NULL,
  name            text NOT NULL,
  qty             int  NOT NULL CHECK (qty BETWEEN 1 AND 999),
  unit_price      numeric(10,2)
);
CREATE INDEX IF NOT EXISTS gear_request_lines_req_idx ON public.gear_request_lines (gear_request_id);
ALTER TABLE public.gear_request_lines ENABLE ROW LEVEL SECURITY;

-- Private bucket for receipt photos (signed links only).
INSERT INTO storage.buckets (id, name, public)
VALUES ('receipts', 'receipts', false)
ON CONFLICT (id) DO NOTHING;

-- Starter stock list for Clontarf (club 1). No prices: the club sets them on
-- the spend page.
INSERT INTO public.gear_items (club_id, name, category, sort)
SELECT 1, v.name, v.cat, v.sort
  FROM (VALUES
    ('Footballs, size 3', 'Balls', 10), ('Footballs, size 4', 'Balls', 11), ('Footballs, size 5', 'Balls', 12),
    ('Sliotars (dozen)', 'Balls', 13), ('Ball bag', 'Balls', 14), ('Pump and needles', 'Balls', 15),
    ('Bibs (set of 10)', 'Training kit', 20), ('Cones (set of 50)', 'Training kit', 21),
    ('Training poles', 'Training kit', 22), ('Agility ladder', 'Training kit', 23),
    ('Water bottles and carrier', 'Training kit', 24), ('Kit bag', 'Training kit', 25),
    ('Hurling helmet', 'Safety', 30), ('Hurl', 'Safety', 31),
    ('First aid kit refill', 'First aid', 40), ('Ice packs', 'First aid', 41)
  ) AS v(name, cat, sort)
 WHERE EXISTS (SELECT 1 FROM public.clubs WHERE club_id = 1)
   AND NOT EXISTS (SELECT 1 FROM public.gear_items WHERE club_id = 1);
