-- Player check-ins (Clontarf Girls 2012, Féile 2027).
--
-- A coach assesses each girl per code (football, camogie): Superpower,
-- Development, How and an optional help video. A second admin approves it.
-- An admin then publishes every approved card at once; the family sees only
-- the published copy (published_card), so later edits stay private until the
-- next publish. Check-ins (27 Jan to 24 Mar) are notes against the assessment
-- and go out with the next publish too.
--
-- Only the player-checkins edge function reads or writes these tables
-- (service role). RLS is on with no policies, so the anon and authenticated
-- roles can do nothing directly. Who may see what (assessor, admin, parent)
-- is decided in the function from the team's CoachSmart roles.

create table if not exists public.pc_assessments (
  id               bigint generated always as identity primary key,
  team_id          bigint not null references public.teams(team_id) on delete cascade,
  member_id        bigint references public.members(member_id) on delete set null,
  player_name      text   not null,
  code             text   not null check (code in ('football', 'camogie')),
  assessor_name    text,
  assessor_email   text,
  superpower       text,
  development      text,
  how              text,
  video_url        text,
  coach_note       text,          -- coaches only, never on the card
  status           text   not null default 'todo'
                   check (status in ('todo', 'draft', 'review', 'changes', 'approved')),
  review_comment   text,
  reviewed_by      text,
  reviewed_at      timestamptz,
  updated_by       text,
  updated_at       timestamptz not null default now(),
  published_card   jsonb,         -- what the family sees
  published_at     timestamptz,
  published_by     text,
  created_at       timestamptz not null default now(),
  unique (team_id, player_name, code)
);

create index if not exists pc_assessments_member_idx on public.pc_assessments (member_id);
create index if not exists pc_assessments_assessor_idx on public.pc_assessments (team_id, lower(assessor_email));

create table if not exists public.pc_checkins (
  id             bigint generated always as identity primary key,
  assessment_id  bigint not null references public.pc_assessments(id) on delete cascade,
  check_date     date   not null,
  progress       text   check (progress in ('starting', 'coming', 'nailed')),
  note           text,
  updated_by     text,
  updated_at     timestamptz not null default now(),
  unique (assessment_id, check_date)
);

create table if not exists public.pc_releases (
  id            bigint generated always as identity primary key,
  team_id       bigint not null references public.teams(team_id) on delete cascade,
  published_at  timestamptz not null default now(),
  published_by  text,
  cards         int not null default 0
);

alter table public.pc_assessments enable row level security;
alter table public.pc_checkins    enable row level security;
alter table public.pc_releases    enable row level security;

revoke all on public.pc_assessments, public.pc_checkins, public.pc_releases from anon, authenticated;
