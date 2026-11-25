-- One-off (Ken, 2026-11-25): the Clontarf Athletic Warm Up video (https://youtu.be/jEeqo_i7Kq8) as four
-- games, one per phase, made by the "Training deck to games (Fable)" thread as a mock of drills-from-a-video.
-- Images are served from the website (clontarf-gaa/games/), not the coachsmartimages bucket.
-- Re-runnable: inserts only the names that are not there yet.
insert into public.games (game_name, game_image, game_details_image, game_age, game_code, game_skill, game_type,
  game_setup, game_how_to_play, game_variations, game_teaching_points, game_video, club_id, created_by, is_active)
select v.game_name, v.game_image, v.game_details_image, v.game_age, v.game_code, v.game_skill, v.game_type,
  v.game_setup, v.game_how_to_play, v.game_variations, v.game_teaching_points, v.game_video,
  1, (select id from auth.users where email = 'ken.darcy@gmail.com' limit 1), true
from (values
  ($q$Athletic Warm Up 1: Raise$q$, $q$https://coachsmart.app/clontarf-gaa/games/athletic-warm-up-01-raise.png$q$, $q$https://coachsmart.app/clontarf-gaa/games/athletic-warm-up-01-raise-video.jpg$q$, array[$q$U14$q$,$q$U16$q$,$q$U18$q$,$q$Adult$q$]::text[], array[$q$Football$q$,$q$Hurling$q$]::text[], array[$q$Agility$q$,$q$Sprinting$q$]::text[], array[$q$Warmup$q$]::text[],
   $q$Whole squad, no ball
20 m channel marked with cones at each end
4 staggered cones for the zig zags
About 40 seconds in the video (0:00 to 0:40)$q$, $q$1. Forward jog out, 20 m (0:02)
2. Backward run back (0:07)
3. Side shuffle, face the same way out and back so both sides work (0:11)
4. High knees out, jog back (0:20)
5. Zig zags: cut hard off the outside foot around each staggered cone (0:31)$q$, $q$Two groups at once, one on each side of the channel
Add a second length of each exercise for an older squad$q$, $q$Tall posture, eyes up, arms driving
Soft knees on the backward run
Push off the outside foot on the shuffle and the zig zags$q$, $q$https://youtu.be/jEeqo_i7Kq8?t=0$q$),
  ($q$Athletic Warm Up 2: Mobilise$q$, $q$https://coachsmart.app/clontarf-gaa/games/athletic-warm-up-02-mobilise.png$q$, $q$https://coachsmart.app/clontarf-gaa/games/athletic-warm-up-02-mobilise-video.jpg$q$, array[$q$U14$q$,$q$U16$q$,$q$U18$q$,$q$Adult$q$]::text[], array[$q$Football$q$,$q$Hurling$q$]::text[], array[$q$Balance$q$]::text[], array[$q$Warmup$q$]::text[],
   $q$Whole squad, no ball
10 m channel marked with cones
About 90 seconds in the video (0:40 to 2:08)$q$, $q$1. Open the gates, walking (0:40)
2. Walking lunges with an overhead reach (0:45)
3. Squat walk (0:57)
4. Walking quad stretch with a forward reach (1:04)
5. Walking knee hugs (1:14)
6. Single leg hinge, the deadlift shape (1:24)
7. Lateral lunges (1:32)
8. Inchworm (1:44)
9. World's greatest stretch (1:55)$q$, $q$Hold each end position for a count of two on a cold night
Pairs: one leads, the other mirrors$q$, $q$Slow and controlled: this is range of movement, not speed
Chest up in the lunge, knee over the toe, not past it
Flat back on the hinge, reach the free leg behind$q$, $q$https://youtu.be/jEeqo_i7Kq8?t=40$q$),
  ($q$Athletic Warm Up 3: Running Mechanics$q$, $q$https://coachsmart.app/clontarf-gaa/games/athletic-warm-up-03-running-mechanics.png$q$, $q$https://coachsmart.app/clontarf-gaa/games/athletic-warm-up-03-running-mechanics-video.jpg$q$, array[$q$U14$q$,$q$U16$q$,$q$U18$q$,$q$Adult$q$]::text[], array[$q$Football$q$,$q$Hurling$q$]::text[], array[$q$Agility$q$,$q$Running Lines$q$]::text[], array[$q$Warmup$q$]::text[],
   $q$Whole squad, no ball
Start on the spot, then a 10 m channel
About 35 seconds in the video (2:08 to 2:45)$q$, $q$1. March on the spot: knee up, toe up, opposite arm (2:08)
2. A-skips over 10 m (2:10)
3. Lateral march on the spot (2:19)
4. Lateral marches and skips sideways along the line (2:24)
5. Carioca sideways, then back leading with the other leg (2:39)$q$, $q$Count the rhythm out loud: one-two, one-two
Add a 5 m jog out of the last skip$q$, $q$Knee drives up, foot lands under the hip
Arms at ninety degrees, drive from the shoulder
Stay on the balls of the feet$q$, $q$https://youtu.be/jEeqo_i7Kq8?t=128$q$),
  ($q$Athletic Warm Up 4: Potentiate$q$, $q$https://coachsmart.app/clontarf-gaa/games/athletic-warm-up-04-potentiate.png$q$, $q$https://coachsmart.app/clontarf-gaa/games/athletic-warm-up-04-potentiate-video.jpg$q$, array[$q$U14$q$,$q$U16$q$,$q$U18$q$,$q$Adult$q$]::text[], array[$q$Football$q$,$q$Hurling$q$]::text[], array[$q$Sprinting$q$]::text[], array[$q$Warmup$q$]::text[],
   $q$Whole squad, no ball
15 m sprint lane marked with cones, walk back
About 35 seconds in the video (2:45 to 3:20)$q$, $q$1. Lean and fall into a sprint (2:45)
2. Press-up position start, up and sprint (2:52)
3. Sprint variation: change the start on the coach's call (3:03)
4. Pogo hops on the spot, then sprint (3:09)$q$, $q$Pairs racing from the same start
Finish into the first ball drill straight away$q$, $q$Full effort: this is the switch-on before training
Drive the first three steps, then open the stride
Walk back, no jogging, full recovery between sprints$q$, $q$https://youtu.be/jEeqo_i7Kq8?t=165$q$)
) as v(game_name, game_image, game_details_image, game_age, game_code, game_skill, game_type,
  game_setup, game_how_to_play, game_variations, game_teaching_points, game_video)
where not exists (select 1 from public.games g where g.game_name = v.game_name);
