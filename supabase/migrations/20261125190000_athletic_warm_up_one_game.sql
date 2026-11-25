-- Ken (2026-11-25): one warm-up game with four sections, not four games. Replaces the four rows
-- from 20261125180000 (same website-hosted images pattern). Re-runnable.
delete from public.games
 where game_name in ('Athletic Warm Up 1: Raise', 'Athletic Warm Up 2: Mobilise', 'Athletic Warm Up 3: Running Mechanics', 'Athletic Warm Up 4: Potentiate')
   and game_image like 'https://coachsmart.app/clontarf-gaa/games/athletic-warm-up-0%';

insert into public.games (game_name, game_image, game_details_image, game_age, game_code, game_skill, game_type,
  game_setup, game_how_to_play, game_variations, game_teaching_points, game_video, club_id, created_by, is_active)
select v.game_name, v.game_image, v.game_details_image, v.game_age, v.game_code, v.game_skill, v.game_type,
  v.game_setup, v.game_how_to_play, v.game_variations, v.game_teaching_points, v.game_video,
  1, (select id from auth.users where email = 'ken.darcy@gmail.com' limit 1), true
from (values
  ($q$Clontarf Athletic Warm Up$q$, $q$https://coachsmart.app/clontarf-gaa/games/athletic-warm-up.png$q$, $q$https://coachsmart.app/clontarf-gaa/games/athletic-warm-up-video.jpg$q$, array[$q$U14$q$,$q$U16$q$,$q$U18$q$,$q$Adult$q$]::text[], array[$q$Football$q$,$q$Hurling$q$]::text[], array[$q$Agility$q$,$q$Sprinting$q$,$q$Balance$q$]::text[], array[$q$Warmup$q$]::text[],
   $q$Whole squad, no ball, 12 to 15 minutes
20 m channel marked with cones at each end, plus 4 staggered cones for the zig zags
10 m walking channel for the mobility work
15 m sprint lane, walk back
Four sections in order: raise, mobilise, running mechanics, potentiate (23 exercises, times are where each one is in the video)$q$, $q$RAISE (0:00 to 0:40)
1. Forward jog, 20 m out (0:02)
2. Backward run back (0:07)
3. Side shuffle, face the same way out and back so both sides work (0:11)
4. High knees out, jog back (0:20)
5. Zig zags: cut hard off the outside foot around each staggered cone (0:31)
MOBILISE (0:40 to 2:08)
6. Open the gates, walking (0:40)
7. Walking lunges with an overhead reach (0:45)
8. Squat walk (0:57)
9. Walking quad stretch with a forward reach (1:04)
10. Walking knee hugs (1:14)
11. Single leg hinge, the deadlift shape (1:24)
12. Lateral lunges (1:32)
13. Inchworm (1:44)
14. World's greatest stretch (1:55)
RUNNING MECHANICS (2:08 to 2:45)
15. March on the spot: knee up, toe up, opposite arm (2:08)
16. A-skips over 10 m (2:10)
17. Lateral march on the spot (2:19)
18. Lateral marches and skips sideways along the line (2:24)
19. Carioca sideways, then back leading with the other leg (2:39)
POTENTIATE (2:45 to 3:20)
20. Lean and fall into a sprint (2:45)
21. Press-up position start, up and sprint (2:52)
22. Sprint variation: change the start on the coach's call (3:03)
23. Pogo hops on the spot, then sprint (3:09)$q$, $q$Two groups at once, one on each side of the channel
Older squads: a second length of each raise exercise and pairs racing the sprints
Cold night: hold each mobility end position for a count of two
Finish straight into the first ball drill$q$, $q$Raise: tall posture, eyes up, push off the outside foot on the shuffle and the zig zags
Mobilise: slow and controlled, chest up in the lunge, flat back on the hinge
Running mechanics: knee drives up, foot lands under the hip, arms at ninety degrees
Potentiate: full effort, drive the first three steps, full recovery between sprints$q$, $q$https://youtu.be/jEeqo_i7Kq8$q$)
) as v(game_name, game_image, game_details_image, game_age, game_code, game_skill, game_type,
  game_setup, game_how_to_play, game_variations, game_teaching_points, game_video)
where not exists (select 1 from public.games g where g.game_name = v.game_name);
