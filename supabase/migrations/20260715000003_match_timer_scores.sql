-- Add GAA scoring columns to match_timer
alter table public.match_timer
  add column if not exists home_goals     integer not null default 0,
  add column if not exists home_points    integer not null default 0,
  add column if not exists home_two_ptrs  integer not null default 0,
  add column if not exists away_goals     integer not null default 0,
  add column if not exists away_points    integer not null default 0,
  add column if not exists away_two_ptrs  integer not null default 0;
