-- Games library: an is_active switch so low quality games can be hidden
-- without deleting them (Ken, 2026-11-11). Every game stays active by default.
alter table public.games
  add column if not exists is_active boolean not null default true;

comment on column public.games.is_active is
  'false = hidden from the games library and session plan picker. Never delete games; switch this off instead.';

-- Hide games that do not have (an image or a video) AND some text.
-- On 2026-11-11 this hides 101 of 199 games and keeps 98.
update public.games
set is_active = false
where not (
  (coalesce(trim(game_image), '') <> '' or coalesce(trim(game_video), '') <> '')
  and (
    coalesce(trim(game_setup), '') <> ''
    or coalesce(trim(game_how_to_play), '') <> ''
    or coalesce(trim(game_teaching_points), '') <> ''
    or coalesce(trim(game_variations), '') <> ''
  )
);
