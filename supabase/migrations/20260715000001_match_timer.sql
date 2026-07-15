-- Match timer: persists per-user per-event so closing and reopening resumes correctly.
-- elapsed_seconds banks time before each pause; started_at marks when the current run began.
-- Current time = elapsed_seconds + (now() - started_at) when running, else elapsed_seconds.

create table if not exists public.match_timer (
  id               bigint generated always as identity primary key,
  event_id         bigint       not null references public.events(event_id) on delete cascade,
  user_id          uuid         not null references auth.users(id) on delete cascade,
  started_at       timestamptz,
  elapsed_seconds  integer      not null default 0,
  status           text         not null default 'paused',
  created_at       timestamptz  not null default now(),
  updated_at       timestamptz  not null default now(),
  constraint match_timer_event_user_unique unique (event_id, user_id),
  constraint match_timer_status_check check (status in ('running', 'paused'))
);

alter table public.match_timer enable row level security;

create policy "Users manage own timers"
  on public.match_timer
  for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Keep updated_at current automatically
create or replace function public.set_match_timer_updated_at()
returns trigger language plpgsql set search_path = 'public' as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger match_timer_updated_at
  before update on public.match_timer
  for each row execute function public.set_match_timer_updated_at();
