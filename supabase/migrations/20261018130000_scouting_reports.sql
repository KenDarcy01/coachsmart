-- Scouting reports (webviews/scouting.html + the scouting edge function).
--   teams.scouting      : team switch, off by default. FlutterFlow shows the "Scout opposition"
--                         button on match events for managers (role 100+) when it is on.
--                         users.ai_features also allows it, so Ken can try it on any team.
--   clubs.gaa_club_id   : the club's row in the season store (public.gaa_clubs), learned the first
--                         time a report is linked, so later reports find the club straight away.
--   scouting_links      : which Sportlomo side a team (and squad) plays as in each code,
--                         e.g. U13 Boys squad B, Football = "Clontarf B". Used to pre-select next time.
--   scouting_reports    : one per match event: the two sides the report compares, the managers'
--                         shared notes, and the cached AI summary.
-- RLS on with no policies: only the scouting edge function (service role) reads or writes them.

ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS scouting boolean NOT NULL DEFAULT false;
ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS gaa_club_id int REFERENCES public.gaa_clubs (club_id);

CREATE TABLE IF NOT EXISTS public.scouting_links (
  link_id     bigserial PRIMARY KEY,
  team_id     bigint NOT NULL REFERENCES public.teams (team_id) ON DELETE CASCADE,
  squad_id    bigint NOT NULL DEFAULT 0,               -- 0 when the event has no squad
  code        text NOT NULL,                            -- Football, Hurling, Camogie, Ladies Football
  gaa_team    text NOT NULL,                            -- as Sportlomo lists it, e.g. "Clontarf B"
  age         text NOT NULL,                            -- competition age, e.g. U13
  updated_by  uuid,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (team_id, squad_id, code)
);

CREATE TABLE IF NOT EXISTS public.scouting_reports (
  event_id      bigint PRIMARY KEY REFERENCES public.events (event_id) ON DELETE CASCADE,
  code          text NOT NULL,
  age           text NOT NULL,
  our_club_id   int NOT NULL REFERENCES public.gaa_clubs (club_id),
  our_team      text NOT NULL,
  opp_club_id   int NOT NULL REFERENCES public.gaa_clubs (club_id),
  opp_team      text NOT NULL,
  comp_id       text,                                   -- the fixture's competition when it was found
  notes         text NOT NULL DEFAULT '',
  notes_by      uuid,
  notes_at      timestamptz,
  ai_summary    text,
  ai_key        text,                                   -- what the summary was written from; rewritten when results change
  ai_at         timestamptz,
  created_by    uuid,
  created_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.scouting_links   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scouting_reports ENABLE ROW LEVEL SECURITY;
