-- Add setup fields to match_timer: duration, opposition, squad
alter table public.match_timer
  add column if not exists duration_seconds integer not null default 1800,
  add column if not exists opposition       text,
  add column if not exists squad_id         bigint references public.squads(squad_id);
