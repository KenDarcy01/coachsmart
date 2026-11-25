-- Club newsletter (2026-11-25, thread "Build The Tarbh Times club newsletter").
-- A weekly newspaper-style newsletter per club. Club officers (and super
-- users) open coachsmart.app/club/newsletter.html?club=ID: the `newsletter`
-- edge function suggests the week's stories from gaa_games and the club's
-- website, the officer ticks, orders and edits them, builds a phone PDF and
-- approves it. Approved issues are shared at coachsmart.app/club/news.html?i=<token>.
--
-- All reads and writes go through the edge function with the service role:
-- RLS is on with no policies. Nothing here is read by the app (v2 or v3).

CREATE TABLE IF NOT EXISTS public.newsletter_settings (
  club_id     bigint PRIMARY KEY REFERENCES public.clubs(club_id) ON DELETE CASCADE,
  title       text   NOT NULL,
  strap       text,
  website_url text,
  first_issue_no integer NOT NULL DEFAULT 1,
  updated_at  timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.newsletter_settings ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.newsletter_issues (
  issue_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  club_id      bigint NOT NULL REFERENCES public.clubs(club_id) ON DELETE CASCADE,
  week_start   date   NOT NULL,
  week_end     date   NOT NULL,
  issue_no     integer NOT NULL,
  status       text   NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'built', 'approved')),
  title        text   NOT NULL,
  pdf_path     text,
  share_token  uuid   NOT NULL DEFAULT gen_random_uuid(),
  suggested_at timestamptz,
  built_at     timestamptz,
  built_by     uuid,
  approved_at  timestamptz,
  approved_by  uuid,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (club_id, week_start)
);
CREATE UNIQUE INDEX IF NOT EXISTS newsletter_issues_token ON public.newsletter_issues (share_token);
ALTER TABLE public.newsletter_issues ENABLE ROW LEVEL SECURITY;

-- kind: lead/win/wins_box/final/club_news/event/fixtures/go_games/custom
-- placement: lead (one per issue), story, short
-- data: facts the story was made from (scores, competition, source url),
--       and for wins_box/fixtures the rows shown in the box.
CREATE TABLE IF NOT EXISTS public.newsletter_stories (
  story_id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  issue_id    bigint NOT NULL REFERENCES public.newsletter_issues(issue_id) ON DELETE CASCADE,
  kind        text   NOT NULL,
  source      text   NOT NULL DEFAULT 'results',
  kicker      text,
  headline    text   NOT NULL DEFAULT '',
  deck        text,
  body        text,
  placement   text   NOT NULL DEFAULT 'story' CHECK (placement IN ('lead', 'story', 'short')),
  included    boolean NOT NULL DEFAULT false,
  position    integer NOT NULL DEFAULT 0,
  photo_path  text,
  data        jsonb  NOT NULL DEFAULT '{}'::jsonb,
  edited      boolean NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS newsletter_stories_issue ON public.newsletter_stories (issue_id, position);
ALTER TABLE public.newsletter_stories ENABLE ROW LEVEL SECURITY;

-- Public bucket for story photos and built PDFs (uploads only through the
-- edge function with the service role).
INSERT INTO storage.buckets (id, name, public)
VALUES ('newsletter', 'newsletter', true)
ON CONFLICT (id) DO NOTHING;

-- Clontarf first (Ken, 2026-11-25).
-- Issues 1 and 2 (9-15 and 16-22 Nov) were made by hand, so the admin starts at 3.
INSERT INTO public.newsletter_settings (club_id, title, strap, website_url, first_issue_no)
VALUES (1, 'The Tarbh Times', 'Nuacht Chluain Tarbh · the week at Clontarf GAA', 'https://clontarfgaa.com', 3)
ON CONFLICT (club_id) DO NOTHING;

-- Access (Ken 2026-11-25: not every officer should see everything). Its own
-- tick per officer; existing officers start with it, new officers do not.
-- The officer access page (thread "Control what each club officer can see")
-- will manage this flag.
ALTER TABLE public.club_officers ADD COLUMN IF NOT EXISTS can_newsletter boolean NOT NULL DEFAULT false;
UPDATE public.club_officers SET can_newsletter = true WHERE is_active;

-- Super user anywhere, or an active officer of the club with the newsletter tick.
CREATE OR REPLACE FUNCTION public.newsletter_can_manage(p_uid uuid, p_club bigint)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1
    FROM user_member_link uml
    JOIN member_team_link mtl ON mtl.member_id = uml.member_id AND mtl.status = 'active'
    JOIN member_team_role_link mr ON mr.member_team_id = mtl.member_team_id
    JOIN roles r ON r.role_id = mr.role_id
    WHERE uml.user_id = p_uid AND coalesce(uml.status, 'active') = 'active' AND r.role_level >= 110
  ) OR EXISTS (
    SELECT 1 FROM club_officers o
    WHERE o.user_id = p_uid AND o.club_id = p_club AND o.is_active AND o.can_newsletter
  );
$$;
REVOKE ALL ON FUNCTION public.newsletter_can_manage(uuid, bigint) FROM PUBLIC, anon, authenticated;

-- For the chairperson dashboard: show the Newsletter link only to those who can use it.
CREATE OR REPLACE FUNCTION public.newsletter_has_access(p_club bigint)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT auth.uid() IS NOT NULL AND public.newsletter_can_manage(auth.uid(), p_club);
$$;
REVOKE ALL ON FUNCTION public.newsletter_has_access(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.newsletter_has_access(bigint) TO authenticated;
