-- Scouting reports are keyed by the pair of sides compared, not by the match event (Ken,
-- 2026-10-19): the coach picks the opposition club, age, code, division and team first, and a
-- match event is optional. Notes and the AI summary live with the pair, so the same pairing
-- opened from an event or from the browser shares them. The table was empty (cleared by
-- 20261019022000), so it is rebuilt. scouting_links is no longer used.

DROP TABLE IF EXISTS public.scouting_reports;
DROP TABLE IF EXISTS public.scouting_links;

CREATE TABLE public.scouting_reports (
  report_id     bigserial PRIMARY KEY,
  pair_key      text NOT NULL UNIQUE,                 -- our club|code|age|our team|opp club|opp team
  event_id      bigint UNIQUE REFERENCES public.events (event_id) ON DELETE SET NULL,
  code          text NOT NULL,
  age           text NOT NULL,
  our_club_id   int NOT NULL REFERENCES public.gaa_clubs (club_id),
  our_team      text NOT NULL,
  opp_club_id   int NOT NULL REFERENCES public.gaa_clubs (club_id),
  opp_team      text NOT NULL,
  comp_id       text,                                 -- the division picked, for the league table
  notes         text NOT NULL DEFAULT '',
  notes_by      uuid,
  notes_at      timestamptz,
  ai_summary    text,
  ai_key        text,
  ai_at         timestamptz,
  created_by    uuid,
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX scouting_reports_our_club ON public.scouting_reports (our_club_id);

ALTER TABLE public.scouting_reports ENABLE ROW LEVEL SECURITY;
