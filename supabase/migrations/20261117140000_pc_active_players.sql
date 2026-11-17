-- Player check-ins: only active players go to the website.
-- The team sheet has a "Player status" column (Active / Inactive) that syncs to this flag.
-- Starting values (17 Nov 2026) come from CoachSmart attendance since 1 Aug 2026:
-- a girl is active in a code if she was named in a match squad for it, or accepted
-- 3 or more trainings in it. Coaches change it in the sheet from now on.
alter table public.pc_assessments add column if not exists active boolean not null default true;

update public.pc_assessments a
set active = false
from public.teams t
where t.team_id = a.team_id and t.team_unique_code = 'TMA47A5'
  and a.code = 'football'
  and a.player_name in ('Aisling Naughton', 'Aoibheann Heffernan', 'Daisy Byrne', 'Effie Coyne', 'Grace Fullam', 'Rachel Flood');

update public.pc_assessments a
set active = false
from public.teams t
where t.team_id = a.team_id and t.team_unique_code = 'TMA47A5'
  and a.code = 'camogie'
  and a.player_name in ('Aoibheann Heffernan', 'Daisy Byrne', 'Effie Coyne', 'Grace Fullam', 'Rachel Flood',
    'Aisling Fitzgerald', 'Alexandra Flynn', 'Aoife Smith', 'Holly Meagher', 'Orla Jennings', 'Sara Pierce',
    'Sophie O’Rourke Graça', 'Freya Gough', 'Ruth McKeown', 'Laura Commins', 'Sarah Macauley', 'Anna McGuire');
