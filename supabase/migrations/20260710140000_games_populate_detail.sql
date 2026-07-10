-- Game detail population — 154 games from Google Sheet (July 2026)
-- Match key: lower(trim(game_name))
-- Fields updated: game_setup, game_how_to_play, game_variations,
--   game_teaching_points, game_image, game_video, game_pdf

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Mark out a grid 15m x 15m * Put 2 players in the middle of the grid as “taggers” (or a coach) * Place the rest of the players on one side of the grid * Any player that’s not a tagger will have a football * Players with a ball must get from one side of the grid to the other without being tagged * Players must Solo every 4 steps * The last player in the Games without being tagged is the winner',
  game_variations       = '**Variations:** * Give footballs to the taggers also * Put more/less taggers on to make the Games harder/easier * Give players lives so if they''re tagged they''re not straight out of the Games (some kids are stronger than others) * Make the area bigger or smaller to suit * Coaches can be taggers and put in a token tag so the players feel they are involved in the Games * Ask players to use their opposite foot * Tackle the ball instead of tagging',
  game_teaching_points  = '**Teaching Points:** * Taggers should concentrate on quick lateral movements from side to side * Players stepping off both feet to change direction quickly * Players to conrinue right throug hthe cones to the end',
  game_image            = 'https://drive.google.com/file/d/1JU9lUfCG5j71InnPk31pgnHwUXBUvsdF/view?usp=sharing',
  game_video            = 'https://youtu.be/z_FGdryDK0E',
  game_pdf              = 'https://drive.google.com/file/d/1gL5R6TSwsc7-BlcZJaETjJGinvtVZi-C'
WHERE lower(trim(game_name)) = lower(trim('Pass the Guard'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 25m x 25m * Cones are placed in the centre of the grid (like a castle) * 4 players are selected to protect the castle in the centre of the grid * Remaining players will attack the castle from the perimeter of the grid * The players in the middle of the grid must protect the castle from attack by the players on the perimiter * Players roll the ball along the ground from the perimiter in order to try and knock down the castle * Attacking team score when they knock over a cone * Games is played for 2 mins and then the teams swap * The team with the highest score wins',
  game_variations       = '**Variations:** * Instead of rolling the balls the attacking team can _throw_ the balls * Instead of rolling the balls the attacking team can _kick_ the balls * Take a player off the defending team and put them with the attackers * Take a player off the attacking team and put them with the defenders',
  game_teaching_points  = '**Teaching Points:** * Defending players should concentrate on lateral movements to either side when defending the castle being sure to push off both legs equally * Attackers are focused on accuracy over power to avoid the defenders and still hit the castle',
  game_image            = 'https://drive.google.com/file/d/1lZblcrDLiqX086YaXMccUJ23vFBymmq7/view?usp=sharing',
  game_video            = 'https://youtu.be/xt8SNj8bGdo',
  game_pdf              = 'https://drive.google.com/file/d/1bbQN3xSJhEbvOtPAiIT7qvbynmBEtjVS'
WHERE lower(trim(game_name)) = lower(trim('Knock The Castle'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set up a large grid 30m x 30m.  * Nominate 2 players to be defenders. Place all other players on the line at the end of the grid with a ball each.  * On the coaches call ‘Hike’ players with the balls start moving off the line and Solo every 4 steps.  * Defenders attempt to tackle and dispossess attackers. Attackers who make it to the other side of the grid without being dispossessed and are awarded a touchdown. * Player with the most touchdowns wins.  * After a set time switch the 2 defenders.',
  game_variations       = '**Variations:** * Place more or less defenders in the Games. * If a player is dispossessed they are knocked out of the Games. * Instead of dispossessing just get defenders to tag attackers.',
  game_teaching_points  = '**Teaching Points:** * Defenders tackle the ball not the player. * Attackers move from side to side. * Attackers protect the ball.',
  game_image            = 'https://drive.google.com/file/d/1P2eIbJHCkJumt2LCqRysRLTXyJRmtntK/view?usp=sharing',
  game_video            = 'https://youtu.be/dxAvN080Hgo',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Touchdown'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Mark out a grid 20m x 20m but place cones as a point at one of the grid to create a ship shape. * Every player has a ball. Coach names each part of the grid so players know where to run. (Bow, port, stern, starboard). * Players begin moving around the grid (ship) bouncing the ball. * Coach calls out a part of the ship and players must run and bounce the ball to that part of the ship. * Players return to centre of ships, continue to move and bounce the ball while waiting for the coaches next call.',
  game_variations       = '**Variations:** * Play a knockout Games. Last player left is the winner.   * Introduce movement skills like jumping, hopping, skipping, etc.  * Coach calls out more that one part of the ship at a time.  * Players bounce with one hand and opposite hand.',
  game_teaching_points  = '**Teaching Points:** * Looking for pushing the ball into the ground and catching with hands only. * Players turn direction both directions. * Bouncing the ball every 4 steps even when running at full speed.',
  game_image            = 'https://drive.google.com/file/d/1aobrumext6bscJK8AvZnYAljZl2JwB-_/view?usp=sharing',
  game_video            = 'https://youtu.be/jiBzE4fZeT0',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Pirates Of The Caribbean'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Mark out a grid  * Split players into teams of 3 * Place a basket or bin in the middle of the grid with a circle of cones around it 5m away. * Place lots of footballs in the grid.  * 5 Players work together by trying to hand pass the ball into the basket. * After a set time the team with the most balls in the basket is the winner.',
  game_variations       = '**Variations:** * Place defenders in from of the basket to internet shots. * Increase the distance from the basket. * Increase or decrease the size of the basket. * Give double points for using opposite hand.',
  game_teaching_points  = '**Teaching Points:** * Encourage accurate hand passing. * Players need to move quickly. * Encourage players to use opposite hand to pass the ball. * Coach should know players hand passing range.',
  game_image            = 'https://drive.google.com/file/d/1-PyagaGmmq0h4Pr_cM9OJFjq8jlZRHTk/view?usp=sharing',
  game_video            = 'https://youtu.be/w_JjbvB-Iy0',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Fill The Volcano'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Make a grid 10m x 10m.  * Split players into 2 teams.  * Place a football in the middle or preferably a Swiss (exercise) ball.  * Each player has a ball, Each team tries to kick or strike the ball (Swiss) in the middle to the other side in order to win the Games. 5. Players can only kick or strike when they are standing behind their own line. 6. They may retrieve balls from inside the grid but can only kick or strike outside it.',
  game_variations       = '**Variations:** * Increase or decrease the size of the ball in the middle. * Move the striking/kicking line of cones back further. * Place 2 or 3 Swiss or Exercise balls in the middle.',
  game_teaching_points  = '**Teaching Points:** * Encourage players to use accurate kicking and striking. * Encourage players to work as a team. * Players need to be quick at retrieving the balls.',
  game_image            = 'https://drive.google.com/file/d/1Yijeay6WFP_BSmAOB2dTF-Lijt0osDNL/view?usp=sharing',
  game_video            = 'https://youtu.be/Vt-e3LRFWh0',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Wrecking Ball'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Divide players into 2 teams Team A and Team B 4 v * * Scatter lots of pointed cones inside the area. * Full playing rules apply except no kicking. * Team A starts with the ball and has 3 minutes to knock down as many cones as they can. 5. Only the player in possession of the ball may knock down a cone by touching ball of it. 6. If Team B gains possession back or intercepts a cone is placed back upright. 7. Swap after set time',
  game_variations       = '**Variations:** * Introduce a kick to knock the cones down * Remove set time for each team and just play a normal Games and team that knocks down most cones wins. * Introduce everyone on the team must receive a pass.',
  game_teaching_points  = '**Teaching Points:** * Encourage movement before and after the pass. * Encourage players to use their team mates around them. * Players should tackle and intercept using good technique',
  game_image            = 'https://drive.google.com/file/d/15SJyuMF-c5dbIKMRyoBzUq2CXpmgqxK9/view?usp=sharing',
  game_video            = 'https://youtu.be/0oso-Ad68vI',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Knock The Cone'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Small Sided Games 6 v 6. * Players play a normal Games trying to score. After a few minutes coach introduces the ‘Shush’ rule. * No noise, no calling for passes/ anything. * The team that breaks the rule give away a free to the other team. * The Games should encourage players to look up and play a pass to the player in the best position.',
  game_variations       = '**Variations:** * Increase or Decrease the size of the area. * Introduce more rules like 2 touches, all players must receive a pass, kicking only, etc.',
  game_teaching_points  = '**Teaching Points:** * We are creating decision making with this Games so coaches should also do their best to stay quiet. * Encourage players when talking to them during breaks to play the ball quickly. * Encourage players to play with their head up.',
  game_image            = 'https://drive.google.com/file/d/1PxOW_D08cQSttAt1DQkmVHmp_igYpa7B/view?usp=sharing',
  game_video            = 'https://youtu.be/eYTkTLBl2VI',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Shush!'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Make a smaller and bigger circle within each other. * Place 2 players as passers in the inner circle and rest of players evaders in between inner and outside circle. * Passers cannot leave inner circle unless to fetch a ball. * Evaders must stay in between the circles but can move around. * Passers must hit the evaders below the waist using a Hand Pass. * If you are hit you swap places with passers.',
  game_variations       = '**Variations:** * Place more passers in the inner circle * Play ‘Build Up’. So if an evader is hit they join and become a passer. Last evader left is the winner. * Split into 2 teams and keep time. If an evader is hit they are out. Team who stays as evaders the longest is the winner.',
  game_teaching_points  = '**Teaching Points:** * Encourage passers to use accurate Hand Passing with good technique. * Evaders to keep their head up and move side to side. * Encourage all players to keep moving.',
  game_image            = 'https://drive.google.com/file/d/1UJPn7A7iOqyCjtqtvO-78x6FpV3oRSXR/view?usp=sharing',
  game_video            = 'https://youtu.be/RlbmBFhka_A',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Space Dodgeball'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Nominate one traffic warden at a cone and rest of players at a line of cones 30m away. * Every player has a ball. * Players solo and bounce out towards the traffic wardens cone. * First player to touch the cone wins. * When the traffic warden shouts ‘red light’ players must freeze perfectly still. If traffic warden shouts ‘green light’ players are allowed to move. * If the traffic warden catches a player moving after ‘red light’ is called that player must take 3 steps backwards.',
  game_variations       = '**Variations:** * Warden stands with their back to players. * Put players in pairs to work together to introduce a Hand Pass or kick pass. * If a player is caught moving increase the number of steps backwards.',
  game_teaching_points  = '**Teaching Points:** * This Games is about reactions so encourage players to listen and maintain good control of the ball. * Good chance for coaches to get players to use both sides of the body as Games is linear.',
  game_image            = 'https://drive.google.com/file/d/1gQLlm48kqD0CTg6eQJqB-j3srljEWU6j/view?usp=sharing',
  game_video            = 'https://youtu.be/v0_vqA2BnTA',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Traffic Warden'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Mark out a channel with cones. Channel is 20m wide. * Split players into 2 teams. * Place team 1 either side along the channel spread out with a ball each like picture. Place team 2 at the start of the channel with a ball each. * Team one begin passing the ball along the ground to each each other. Team 2 on coaches call run through the channel one at a time bouncing and soloing the ball trying not to get hit and make it to the other end. * If a player on Team 2 gets hit that team loses 10 points. * Switch roles after a set time. whichever team has the most points at the end is the winner',
  game_variations       = '**Variations:** * Instead of kicking get players to hand pass or roll the ball. * Increase or decrease the size of the grid. * Place more footballs in the Games. * Get players running through the grid to dribble the ball on the ground with their feet.',
  game_teaching_points  = '**Teaching Points:** * Head up looking either side. * Accurate kicking. * Good control of the ball when in possession.',
  game_image            = 'https://drive.google.com/file/d/15hcB3cbrBpdcj3BIQ-NLXMVmun5OFvX6/view?usp=sharing',
  game_video            = 'https://youtu.be/LxmGwyUcaF8',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Croke Parks Extreme Tunnel'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Mark out a grid 25m x 25m. * Split players into 3 even teams. * Team in the middle of the grid are alligators. * Teams on the outside of the grid strike the balls back and forth attempting to get them to the other teams side. * Team in the middle tries to stop the balls from crossing the swamp (grid). If team in the middle stops a ball successfully they dribble the ball to the den and place there. * Games stops after a set time. Every team has a go in the middle. * Team who collected the most balls while being alligators are the winners.',
  game_variations       = '**Variations:** * Use bigger or smaller balls. * Award points to the striking teams for every successful strike that makes it across. * Use opposite side. * Instead of dribbling into a den alligators strike balls into a goal.',
  game_teaching_points  = '**Teaching Points:** * Accurate kicking and striking. * Players in the middle make themselves big and move side to side.',
  game_image            = 'https://drive.google.com/file/d/1tZJisTAZRW_rRG6s9MspVarD0b2TicBD/view?usp=sharing',
  game_video            = 'https://youtu.be/mWFmnF8G4Rc',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Alligators In The Swamp'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set up a grid in front of a goal. * Split players into 3 teams. * Coaches stand at different points on the outside of the grid with balls and act as feeders of the ball. * A coach delivers a ball randomly into the grid. Whichever team secure possession are the attacking team. The other 2 teams are defending. The attacking team try to score a goal. * Play the first team to score 3 goals then switch teams.',
  game_variations       = '**Variations:** * Place a goalkeeper in the goal.  * Shoot for points.   * Make the area bigger or smaller.   * Instead of first to 3 introduce a set time.',
  game_teaching_points  = '**Teaching Points:** * Encourage first time play.   * Support play.  * Quick reactions.',
  game_image            = 'https://drive.google.com/file/d/1u0f7H-8NEZcALsWRWFnzLHECQLsJ_dcr/view?usp=sharing',
  game_video            = 'https://youtu.be/snQAdbkcE_Q',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Triple Threat'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Mark out 2 circles. One big circle and one small circle inside. Big circle is 20m wide. Small circle is 2m wide. * Place a third of the players with footballs inside the small circle and the rest of the players outside the big circle. * On coaches call players in the middle solo out to the players on the outside hand pass the ball, get it back and solo back into the small circle (and they get a point). * Players have 2 mins to get as many points as they can. * Introduce a new group after the time is up.',
  game_variations       = '**Variations:** * Pair players up so they must look for their partner.   * Add in more skills like spinning, jumping etc.  * Increase or decrease the size of the circles.  * Introduce a ball to every player.',
  game_teaching_points  = '**Teaching Points:** * Head Up. * Quick turns and evade other players. * Speed.',
  game_image            = 'https://drive.google.com/file/d/18rNnzFzKB_qLmFh2rbqwRX1B7HDjj8Vx/view?usp=sharing',
  game_video            = 'https://youtu.be/qJlysCYJVxA',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Through The Circle'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Split the group into pairs. * Every pair has a ball. * Players strike the ball from their hands and attempt to hit the cone in the middle. * Players alternate turns. * Player who hits the cone the most times is the winner. * 4 Change pairs around so players play against a different player.',
  game_variations       = '**Variations:** * Give every player a ball so there is no waiting. * Increase the distance between the cones. * Get players to strike the ball moving. * Award extra points for using opposite side.',
  game_teaching_points  = '**Teaching Points:** * Accurate striking. * First touch. * Head down and head up.',
  game_image            = 'https://drive.google.com/file/d/1yitXppH5MCnKLGsn6PeVa3rcpnqGIoea/view?usp=sharing',
  game_video            = 'https://youtu.be/SgBPoy60K6k',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Bullseye'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Mark out a grid 30m x 30m and using cones place lots of goals spread out throughout the grid. * Players work in pairs. * One ball per pair. * Players move around the grid with the ball. * On the coaches call players have 1 min to score through as many goals as they can. They hand pass the ball through the goal to their partner on the other side. * The pair who passed the ball through the most goals is the winner.',
  game_variations       = '**Variations:** * Strike the ball instead of hand pass. * Kick the ball instead of hand pass. * Increase or decrease the size of the goals. * Nominate a couple of players to act as defenders to spoil passes.',
  game_teaching_points  = '**Teaching Points:** * Team work. * Head up. * Awareness. * Accuracy',
  game_image            = 'https://drive.google.com/file/d/1VRLND-Hy7vWfj50xLPWZKqkTHfrSR3KK/view?usp=sharing',
  game_video            = 'https://youtu.be/3oCQ48X2HyY',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Goals, Goals, Goals'));

UPDATE public.games SET
  game_setup            = '**Setup as Follows:** * Set out a pitch 25m x 25m in a diamond shape  * 9 Players plus to keepers (Keepers can be coaches) * 2 Teams play at a time',
  game_how_to_play      = '**How to Play:** * Split players into 3 teams of max 3 players.  * The goalkeeper or coach passes to the first attacking team who gets the ball and tries to get a shot on the oppositions goal as quickly as possible. * After a shot or goal the keeper passes the ball to the oppoistion team. * Games last 2 minutes and then rotate the teams.',
  game_variations       = '1. Restrict the amount of touches a player can have. 2. Everyone on your team must get a touch. 3. Increase the size of the pitch. 4. Remove the goalkeeepers and shoot for points.',
  game_teaching_points  = '1. Creating space. 2. First time. 3. First Touch. 4. Communication.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Six Shooter'));

UPDATE public.games SET
  game_setup            = '**Setup as Follows:** * Set out a grid 25m x 25m and Split players into 2 teams   * Place a line of cones across the centre of the grid and put 1 team either side * Place lots of footballs on each side of the grid',
  game_how_to_play      = '1. The Games begins on the coaches call. 2. Players strike or kick the ball across from one grid to the other. 3. When the time is up the team with the least amount of balls in their grid (garden) is the winner.',
  game_variations       = '1. Increse or decrease the size of the grid. 2. Put opposition players on each side of the grid to spoil shots from the other team. 3. Use opposite side to strike or kick. 4. Add or take out balls.',
  game_teaching_points  = '1. Striking. 2. Accuracy. 3. Head up 4. Awareness',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Clear The Garden'));

UPDATE public.games SET
  game_setup            = '**Setup as Follows:** * Set out a grid 25m x 25m and place lots of balls at the start of the grid   * Place Hoops, cones, big balls etc as obstacles throughout the grid',
  game_how_to_play      = '1. Players start one one side of the grid with all the balls. 2. Players retrive a ball and dribble it through the minefield to the otherside. 3. If a ball touches an obstacle players go back to the start. 4. If a player makes it to the otherside they run back to start and retrive another ball',
  game_variations       = '1. Get players to dribble ball moving backwards. 2. Encourage players to go faster. 3. Add or remove obstacles',
  game_teaching_points  = '1. Ball control. 2. Head Up. 3. Awareness',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Minefield'));

UPDATE public.games SET
  game_setup            = '**Setup as Follows:** * Set out a grid 5m x 5m   * Place 4 players at each corner of the grid a 1 in the middle',
  game_how_to_play      = '1. Players on the outside of the grid pass the ball to eachother laterally. 2. Players not allowed play the ball diagonally. 3. Player in the middle has 30 secs to get as many interceptions as they can. 4. After a set time change the player in the middle.',
  game_variations       = '1. Increase the number of players in the middle and/or on the outside of the grid. 2. Place more balls in the Games. 3. Allow players on the outside to move up and down the lines of the grid.',
  game_teaching_points  = '1. Quickness. 2. First Touch. 3. Head Up',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Rondo'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 25m x 25m * Place a cone at each corner of the grid * Place a circle of cones in the centre of the grid and fill the circle with lots of balls * Split players into 4 teams and place at each corner of the grid * The Games begins on the coaches call * 1 Player from each team runs into the middle and retrieves a ball from the circle * Player returns to team and next player goes * Games is played until all the balls have been removed from the middle circle * The team with the most balls wins',
  game_variations       = '**Variations:** * After all the balls are gone from the middle players can go steal from other teams. * Get players to do animal movements. * Let players take more than one ball at a time. * Players run into the middle in pairs.',
  game_teaching_points  = '**Teaching Points:** * Head Up When Running. * Be As Quick As Possible.',
  game_image            = 'https://drive.google.com/file/d/1wZ34yphHXUe3kyrsazVxOrW030HLGkZs/view?usp=sharing',
  game_video            = 'https://youtu.be/8ixKydAsOiI',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Rob The Nest'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out 2 circles one inside the other. Outside circle 20m in size, inside circle 10m in size * Place all the bean bags in the inner circle * Coaches stand inside the inner circle * Players stand in the outer circle * The Games begins on the coaches call * Coaches throw the bean bags under arm and attempt to hit the players on the leg * If a player is hit they lose a life * Games is played for a set time * Player with least amout of lives lost is the winner',
  game_variations       = '**Variations:** * Allow players to earn lives back by placing bean bags back into the inner circle. * Make the outer circle smaller or bigger. * Put players as taggers instead of coaches. * If a player is hit they must freeze and another player must attempt to free them by crawling under their legs.',
  game_teaching_points  = '**Teaching Points:** * Head Up When Running. * Be As Quick As Possible. * Dodging.',
  game_image            = 'https://drive.google.com/file/d/1T08wBeZ-IKTezZrG2IWFEAGdzuqIyEw-/view?usp=sharing',
  game_video            = 'https://youtu.be/rHcReIiTyqM',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Bean Bag Tag'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out 2 grids 20m apart. Each grid is 5m wide and 10m long * Place lots of balls inside both grids * Split players into 2 teams * Place each team inside a grid * The Games begins on the coaches call * Players run to the opposite teams grid, retrieve a ball and bring it back to their own grid * Players keep running back and forth retrieving balls until the time is up * The team with the most balls in their grid is the winner',
  game_variations       = '**Variations:** * Increase or decrease the size of the area. * Add in different skills for players to perform. Solo, Dribble, Bounce, Jab Lift, etc. * Place defenders in the Games to try and get the balls of players as they are running back.',
  game_teaching_points  = '**Teaching Points:** * Head Up When Running. * Be As Quick As Possible. * Side step, Balance, Agility.',
  game_image            = 'https://drive.google.com/file/d/1b59gYQ3sC-qpbhTtwquG8Rr-g9bZHZk8/view?usp=sharing',
  game_video            = 'https://youtu.be/ib1qO1SA_Jc',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Grid Swap'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 25m x 25m. Place a line of lots of cones through the centre of the grid * Split players into 2 teams * Place each team at the back of the grid behind a line of cones  * Every player has a ball to start and the Games begins on the coaches call * Players kick or strike the ball and attempt to hit one of the cones in the centre * Players must kick/strike the ball from their line of cones. If a player hits a cone they get to retrieve that cone and bring it back to their team * When all the cones are gone from the centre the team who hit and collected the most is the winner',
  game_variations       = '**Variations:** * Instead of collecting cones award players points for hitting them. * Make the grid smaller or bigger. Make the cones in the middle smaller or bigger * Put a couple of players on oppoistion side to block shots.',
  game_teaching_points  = '**Teaching Points:** * Accurate kicking and striking. * Team work. * Kicking and striking under pressure so move your feet.',
  game_image            = 'https://drive.google.com/file/d/1QDfc1oepSw4LNSyNjwej2lj03dbCsZiE/view?usp=sharing',
  game_video            = 'https://youtu.be/jd6jfTgZD1I',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('King Cone (Hit The Cone)'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 25m x 25m * Place 2 to 3 players as taggers and give them a ball each * Give every other player a bib and a ball each. Players tuck their bib into the back of their shorts which becomes the tail   * On the coaches call the Games begins and all players move in the grid. The 2/3 taggers attempt to run around and grab the foxes tails * If a players tail is taken they are out of the Games * The player who is last and did not get their tail taken is the winner * Encourage players to perfrom skills while moving in the grid',
  game_variations       = '**Variations:** * Split players into 2 teams instead of having taggers. * Take out the balls and put in a different type of equipment like tennis balls, bouncy balls, etc. * Increase or decrease the amount of taggers.',
  game_teaching_points  = '**Teaching Points:** * Quick feet and evasion. * Performing skills under pressure. * Awarness and head up.',
  game_image            = 'https://drive.google.com/file/d/1TJyAP7bmHLlcR8UoBD-WWKkzv7Ws-ud1/view?usp=sharing',
  game_video            = 'https://youtu.be/f5PLt6j5b_8',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Foxes Tails with the ball'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out 2 grids 25 to 30 metres apart. Each grid (Prison) is 5m wide and 10m long. Place a line of coes halfway between each grid * Split players into 2 teams. Place 2 to 3 players in each opponents grid. These are the prisoners * The rest of the team stay on their own side of the grid to start and have a ball each * The Games begins on the coaches call * Players attempt to run to the opponents prison and rescue their team mates * If a player is tagged on their way to rescue a team mate they must return to their side of the grid * The team who rescued the most prisoners in the set time is the winner',
  game_variations       = '**Variations:** * If a player is tagged they become a prisoner. * Take out the footballs and just get players to run. * Give players bibs to tuck into shorts so its harder to be tagged.',
  game_teaching_points  = '**Teaching Points:** * Quick feet and evasion. * Performing skills under pressure. * Awarness and head up.',
  game_image            = 'https://drive.google.com/file/d/1zA4sqAtrdse46XHMVdjoCj1NPpoQLrVC/view?usp=sharing',
  game_video            = 'https://youtu.be/9Z_19BEqP5g',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Prisoners'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 25m x 25m * Place lots of disc markers (Lily pads) throughout the grid * Give each player a ball * On the coaches call the Games begins * The players run throughout the grid. Everytime they approach a disc marker (Lily pad) they bounce the ball on the pad * Players continue and attempt to bounce the ball on as many pads as possible before the time is up',
  game_variations       = '**Variations:** * Players bounce the ball with one hand. * Set a time limit to get as many bounces as possible. * Players bounce twice on a pad. Right hand and Left hand. * Introduce different movements like animal movements.',
  game_teaching_points  = '**Teaching Points:** * Head up and evasion. * Perform skill quickly. * Push ball into ground hard to bounce.',
  game_image            = 'https://drive.google.com/file/d/1AhHfWyZNZOMnor3PSv_uEER9QPwq2Eip/view?usp=sharing',
  game_video            = 'https://youtu.be/7zFpzlTMFUo',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Lilipad Bounce'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out 4 small grids. 2 grids opposite each other like image above. Each grid is a house and the balls ar the furniture * Place lots of balls inside the first grid like image * Split players into 2 teams and place them at a cone 10m away from the first grid * One player at a time runs to the first grid, retrives a ball and moves it to the second grid. They then run back to their team and tag the next person * The team that has moved all their furniture first is the winner',
  game_variations       = '**Variations:** * Introduce different skills to do with the ball. * Increase the distance between the grids. * Place lots of balls and get players to take 2 at a time.',
  game_teaching_points  = '**Teaching Points:** * Team work. * Perform skill quickly. * Running and Agility.',
  game_image            = 'https://drive.google.com/file/d/1Pne0ZbPOqb-e2J_0YbAbl5wXvQWj1O3M/view?usp=sharing',
  game_video            = 'https://youtu.be/iA3mgv8wZ6U',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Moving House'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out 2 grids 25 to 30 metres apart. Place a line of cones halfway bewtween each grid. Each grid is 5m wide and 10m long. Place one flag or large cone inside each grid * Split players into 2 teams * Players have a ball each * The Games begins on the coaches call * Players attempt to run over to the opponents grid, steal the flag and bring it back to their grid without getting tagged. If a player is tagged they must return to their own side before trying to steal again * Play for a set time or the team that steals the flag and bring it back to their side successfully is the winner * Players must perform skills while moving throughout the grid',
  game_variations       = '**Variations:** * Increase or decrease the size of the area. * Place more flags in the Games. * Add or takeout skills to perform.',
  game_teaching_points  = '**Teaching Points:** * Head up and evasion. * Perform skill quickly. * Perform skill under pressure.',
  game_image            = 'https://drive.google.com/file/d/1Oi_oFngDjH87qfFs4ryawbiPWvP7dYDv/view?usp=sharing',
  game_video            = 'https://youtu.be/oe0Zd27kQfQ',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Capture The Flag'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 25m x 25m. Place 8 cones spread out evenly around the edge of the grid * Split players into 2 teams * The Games begins with the coach throwing the ball in. Games lasts 3 minutes * Players are only allowed to hand pass the ball to team mates when in possession * Every time a player hand passes a ball they must run quickly out around the nearest cone to them and get back into the Games * A score is awarded when a team gets 3 consecutive passes in a row * The team with the highest score wins',
  game_variations       = '**Variations:** * Reduce the amount of cones on the perimeter of the grid. * Increase or decrease the amount of consecutive passes for a score. * Award scores for other skills like tackling, intercepting, etc.',
  game_teaching_points  = '**Teaching Points:** * Head up and evasion. * Team work. * Good hands.',
  game_image            = 'https://drive.google.com/file/d/12aLOMG79q_fWIDjQL1UFS1SHy-xtPyDx/view?usp=sharing',
  game_video            = 'https://youtu.be/p_gXN6grnCQ',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Out around a cone'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 25m x 25m. Place about 5 to 6 poles spread throughout the grid * Split players into 2 teams. One team attacking and the other defending * The Games begins with the attacking team in possession. Games lasts 3 minutes * Attacking players hand pass the ball to each other and try to hit one of the poles * Attacking team can hand pass the ball off the pole or touch the ball off the pole * The defending team attempts to stop the attacking team from getting scores * After a set time reverse roles. The team who scored the most when they were attacking is the winner',
  game_variations       = '**Variations:** * Add or take away poles. * Make the Games non contact so defending team have to intercept passes. * If players struggle to hand pass let them throw the ball.',
  game_teaching_points  = '**Teaching Points:** * Head up and evasion. * Team work. * Accurate scoring and passing.',
  game_image            = 'https://drive.google.com/file/d/1nFjldPji7awifUAOIbZvE6YuGU9egJ6Q/view?usp=sharing',
  game_video            = 'https://youtu.be/WhWZVGqbnKM',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Guard The North Pole'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out set out 6 cones 2m apart in a straight line. Opposite each cone place another cone 10 to 12 metres away * Split players into pairs and place a pair at each cone like the picture above. No more than 2 players at a cone * The Games begins on the coaches call * The first player from ech pair runs as quickly as possible balancing the ball on their Hurley out to the cone oppoiste them * Player runs around the cone and returns to partner who then runs out around the cone * Players are always balancing the ball on their Hurely while running * The team who completes 3 turns each first is the winner',
  game_variations       = '**Variations:** * Instead of balls use bean bags to balance. * Increase or decrease the length of the run. * Change the layout of the run to zig zag or whatever you can think of.',
  game_teaching_points  = '**Teaching Points:** * Control of the bean bag or ball on the Hurley. * Correct grip for balancing. * Head up and moving quickly.',
  game_image            = 'https://drive.google.com/file/d/1ZbF9-iB5hdHGlvmdD1BwpigjgJ0sjttX/view?usp=sharing',
  game_video            = 'https://youtu.be/tQArDpMTgyI',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Formula 1'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a channel using cones from end line out towrds 45 metre line * Split players into attacking and defending * Place the attackers at the cone nearest to the goal like the picture above * Place the defenders at the cone farthest away from the goal * Place the ball in the middle of the grid or the coach can roll the ball in * On the coaches call the attacker moves towards the ball, jab lifts it and attempts to score * The defending player runs in and attempts to hook attacking player. After a set time change the 2 groups',
  game_variations       = '**Variations:** * Move the attackers further or closer to the goal. * Instead of jab lifiting the ball get attacker to start with the ball in their hand and the defender 2m behind them. * Have a competetion by splitting players into 2 teams. Team with most hooks wins.',
  game_teaching_points  = '**Teaching Points:** * Good Hooking technique. * Making up the ground. * Attacker trying to accelerate and score.',
  game_image            = 'https://drive.google.com/file/d/1Fh9EESBGDeUxnEvji_w8XPkP--L_bbpW/view?usp=sharing',
  game_video            = 'https://youtu.be/XPKb0r3feu4',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Captain Hook'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Place a cone either side of the goal and another 2 cones on the 45m line opposite the end line cones * Split players into 2 teams and then half the players in each team * Place half the players on the end line cone and the other half at the 45m line cone * All the balls are with the end line groups * On the coaches call each time the ball is played by the end line player to the 45m line player * The recieving players run onto the ball and attempt to score * The player that scores first wins a point for thier team. The team with the most points is the winner',
  game_variations       = '**Variations:** * Deliver the ball high, low, to the side. * Place a defender in the Games. * Go for goals or points only.',
  game_teaching_points  = '**Teaching Points:** * Good delivery of pass. * Moving into the ball at speed. * Kicking or Striking the ball off both side.',
  game_image            = 'https://drive.google.com/file/d/1Z8MgLGY7sSPHgIQor23gjIlejRvkcKqU/view?usp=sharing',
  game_video            = 'https://youtu.be/L-zMPwTX_jY',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Race To Score'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 25m x 25m * Place players in pairs and give every player a ball * One player acts as the leader and the other player acts as the follower   * The leader moves around the grid performing skills and the follower must react and copy the leader * After a set time switch roles',
  game_variations       = '**Variations:** * Put players in 3 or 4''s with a leader  * Place specific skills in the Games. * Add fundamental skills like jumping, turning, landing.',
  game_teaching_points  = '**Teaching Points:** * Reactions. * Agility. * Thinking on your feet.',
  game_image            = 'https://drive.google.com/file/d/1j2sRfIemOuGuZ4pRuQgve0iXg4wIXOhe/view?usp=sharing',
  game_video            = 'https://youtu.be/shRWs_DYhcM',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Mirror Mirror'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 25m x 25m. Place 4 goals using cones or polls on the edge of the grid like the image above * Split players into 2 teams * Games begins with coach throwing the ball in * Players hand pass the ball to each other and attempt to score in one of the 4 goals by hand passing through the goal * If a team scores in a goal they must score in a different goal next time * Games ends after a set time. Team with the most goals wins',
  game_variations       = '**Variations:** * Instead of hand passing through a goal players must carry the ball through the goal.  * Players could palm the ball into a goal insttead of hand passing. * Use opposite side for hand pass or introduce over head throwing.',
  game_teaching_points  = '**Teaching Points:** * Team Play. * Moving into space. * Accurate passing.',
  game_image            = 'https://drive.google.com/file/d/1Qk-QLPR_nwQ5N90Iz2b2RcvXC-ujcUvS/view?usp=sharing',
  game_video            = 'https://youtu.be/Vliyn10j8fY',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('4 Goal Games'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out 2 grids that are 15m x 15m and place them 10m away from each other like image above * Split players into 2 teams * Games begins with coach throwing the ball in * Players hand pass the ball to each other to keep possesion * When coach shouts ''Switch On'' team in possession must make it to the other grid while maintaining possession * Games ends after a set time. Team who successfully made it across the most times is the winner',
  game_variations       = '**Variations:** * Make the grids bigger.  * Increase the distance between the 2 grids. * Introduce a kick or strike.',
  game_teaching_points  = '**Teaching Points:** * Team Play and Maintaining possession. * Moving into space. * Accurate passing.',
  game_image            = 'https://drive.google.com/file/d/1ejRJeKprq_BmOlUfyQ6gNgaQbeypa6XF/view?usp=sharing',
  game_video            = 'https://youtu.be/4R1Ck_YUUf4',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Switch On'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 25m x 25m * Pick 2 to 3 players to be the chasers * Give all remaining players a ball each  * On the coaches call the Games begins * The players run throughout the grid bouncing the ball every 4 steps. Chaser try and knock the ball out of the players hands * If a players ball is tackled and knocked to ground they are out. Last player left is the winner',
  game_variations       = '**Variations:** * Instead of Tackling get chasers to tag players. * If some players a weak add lives into the Games so they are not eliminated straight away. * Increase or decrease the amount of taggers.',
  game_teaching_points  = '**Teaching Points:** * Bouncing. * Evasion. * Head up.',
  game_image            = 'https://drive.google.com/file/d/1gLT6Bticr_z41tWtTsZ6TnDQobHgEkQF/view?usp=sharing',
  game_video            = 'https://youtu.be/hPcdC3lwriw',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Bounce King/Queen'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a large grid 30m x 30m. Inside the grid place 4 small boxes 5m x 5m * Place 1 player in each of the small boxes. * Rest of the players are playing inside the large grid with a ball each * Pick 2 players to be chasers * Players with the ball must move throughout the area bouncing, soloing, dribbling the ball * The chasers are trying to knock as many balls as possible out of the grid. Each ball they knock out is worth a point * If a player with a ball wants a rest they can tag team a player in a small box and swap roles. The Games ends when all the balls have been knocked out of the grid',
  game_variations       = '**Variations:** * Increase or decrease the amount of small boxes. * On the coaches call players must tag team a player in a box. * Increase or decrease the amount of chasers.',
  game_teaching_points  = '**Teaching Points:** * Team work. * Evasion. * Head up.',
  game_image            = 'https://drive.google.com/file/d/1GkakYAfLsA5dAkUXxqxcXE1hutRy4g-a/view?usp=sharing',
  game_video            = 'https://youtu.be/DPvqKeYQPLs',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Tag Team'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a large grid 30m x 30m. Inside the grid set out a smaller grid (Fort Knox) 10m x 10m like image above and place a flag pole in the centre * At each corner of the small grid make small goals/gates using cones * Place 3 players inside Fort Knox * Rest of the players, with a ball each split into 3 teams and place them inside the large grid * Outside players attempt to carry the ball through one of the gates/goals and touch the flag pole in the centre of fort knox. If successful they get a point * The team inside Fort Knox tag any player that enters. If a player is tagged they leave Fort Knox and try again. Every team gets a go defending Fort Knox. Team with least amount of points lost is the winner',
  game_variations       = '**Variations:** * Increase or decrease the size of fort knox. * Place more that one flag pole in the centre. * Introduce different skills.',
  game_teaching_points  = '**Teaching Points:** * Quick feet and evasion. * Performing skills under pressure. * Awarness and head up.',
  game_image            = 'https://drive.google.com/file/d/1gyoWISkrGAEmBzTtB1TpM73sbmyOG3RP/view?usp=sharing',
  game_video            = 'https://youtu.be/OMrBa3jCJic',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Fort Knox'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a large grid 30m x 30m. Inside the grid place 5 small circles 3m x 3m * Split players into 2 teams and give every player a ball * Pick one player from each team to start as a defender against the opposite team like image above * Players attempt to carry a ball by bouncing, soloing, dribbling to one of the circles and place the ball down in the circle. As soon as they place the ball they must react and defend the next player coming from the opposition team like video above * Players when defending are not allowed go through the circles and must try tag the attacking place. If successful the attacking player does not win a point for their team * The middle pot is worth triple points * The team with the most points at the end of the Games is the winner',
  game_variations       = '**Variations:** * Add or take away circles. * Players can only go on coaches call. * Introduce different skills.',
  game_teaching_points  = '**Teaching Points:** * Quick feet and evasion. * Performing skills under pressure. * Awarness and head up.',
  game_image            = 'https://drive.google.com/file/d/1EGbTx9YFqnmuFPJUeehsWvYcAif59r54/view?usp=sharing',
  game_video            = 'https://youtu.be/opaX04lrGv0',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Power Rangers'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a pitch 25m x 25m with a goal at both ends  * Split players into 2 teams * One team starts with the ball. Teams must pick one player that will be their secret weapon. This player is the only person that can score * The opposition team do not know who the scret weapon is and must defend every player * The attacking keep possession by hand passing. They must try get it to the secret weapon to score  * If the secret weapon scores the team gets 10 points  * The team with the most points after the set time is up is the winner',
  game_variations       = '**Variations:** * Increase the size of the pitch so players can kick or strike the ball. * Let teams have more than one secret weapon. * Place goalkeepers in the Games.',
  game_teaching_points  = '**Teaching Points:** * Team play. * Performing skills under pressure. * Awarness and head up.',
  game_image            = 'https://drive.google.com/file/d/1K5x6mx7wLVUYPgG9IjLH6fmqrHERoqWQ/view?usp=sharing',
  game_video            = 'https://youtu.be/QwvgEoglVmg',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Secret Weapon'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out 4 semi circles using cones. Place 2 semi circles facing each other 30m apart like image above  * Place a line of cones half way between the semi circles * Place lots of balls in 2 semi circles like image and split players into teams with max 3 players on a team. Balls are nuts and players are squirrels * Place one player from each team on the middle line and place the rest of the players behind one of the semi circles like image * The Games begins on the coaches call. The 2 middle players run and retreive a ball. They bring it back to the centre line and kick or strike the ball. They try to get it to stop in the other semi circle  * If a ball stays inside the semi circle award 10 points  * The team with the most points after all the balls are gone is the winner',
  game_variations       = '**Variations:** * Increase the size of the semi circle. * Instead of a semi circle of cones use goals or poles. * Introduce skills players have to perform while moving with the ball.',
  game_teaching_points  = '**Teaching Points:** * Accurate striking and kicking. * Speed. * Awarness and head up.',
  game_image            = 'https://drive.google.com/file/d/1ZFfBYgJlw9N7yaTQeAUH8Yqkfd5_6MHs/view?usp=sharing',
  game_video            = 'https://youtu.be/_sP7L1ndlOo',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Nuts and Squirrels'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a channel from the goal out to about 35m. The line of cones is placed 15m along the end line either side of the goal  * Place a number of players on the end line either side of the goal, these players will defend. Place the other players, attackers, 35m away from the goal like image above * The coach also stands 35m away with attacking players * The Games begins on the coaches call. The coach calls a number, for example 3. 3 defenders come out from the end line and 3 attackers from the 35m line carry the ball and attempt to score * If the attackers score award 1 point. If the defenders successfully turn the ball over award them a point.  * After a set number of turns switch the defending and attacking teams',
  game_variations       = '**Variations:** * Increase or decrease the distance the attacking players have to carry the ball. * Place a defender and an attacker already inside the channel. Ball is delivered and coach calls the amount of players that have to support the play. * Have attackers go for points or goals only. Call out the numbers uneven. For example 2 attackers against 3 defenders.',
  game_teaching_points  = '**Teaching Points:** * Thinking on your feet. * Tackling. * Working a score.',
  game_image            = 'https://drive.google.com/file/d/1gvOHnrxdD57OPeh7DthjpZP7Cyddofxe/view?usp=sharing',
  game_video            = 'https://youtu.be/d4Eq8gP0ITg',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Numbers'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a 25m x 25m grid. Inside the grid mark out 2 to 3 small squares 5m x 5m  * Divide the players into 2 teams. Every player has a ball * One team carrys the ball around the playing area bouncing and soloing while the other team attempt to tag them by throwing the ball and hitting them on the legs * The tagged player becomes a patient and calls for an operation while holding the ball up over their head * The patients have 2 or 3 doctors based in the 2 small squares which are hospitals. They can save any of their patients by leaving the hospital and touching them but if either doctor is hit below the knee by a ball, the Games is over and the attacking team wins.  * Play for 1 to 2 minutes. If the doctors aren’t hit by a ball, the team with the least number of patients when time is up is the winner',
  game_variations       = '**Variations:** * Introduce bean bags for taggers to throw as well as carrying their ball. * Increase or decrease the amount of doctors. Introduce a hand pass instead or throwing for taggers * If you want the Games to go on for longer give each doctor 2 lives so the Games doesnt finish straight away.',
  game_teaching_points  = '**Teaching Points:** * Quick feet and moving into space. * Team work. * Performing skills under pressure.',
  game_image            = 'https://drive.google.com/file/d/1ZB_jTQcyQMRD9U6g8pt4y-IL_Vn8CUSm/view?usp=sharing',
  game_video            = 'https://youtu.be/AwzQgPExB2k',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Operation'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a large circle about like image above. Place goals either end of the circle with 2, 3 cones inside the goal * Split players into 2 teams of 3 * The Games begins with the coach throwing the ball in. Teams score by kicking/striking the ball, scoring a goal for 1 point or hitting a cone a cone for 3 points * Everytime there is a score the coach throws in another ball * Play the Games for a set time or when a team has hit all their cones',
  game_variations       = '**Variations:** * Add more cones along the goal line. Also place them in the corners of the goal for corner shots * Increase or decrease the size of the circle. * Always play 3 v 3 never anymore than that.',
  game_teaching_points  = '**Teaching Points:** * Accurate striking and kicking. * Team play. * Performing skills under pressure.',
  game_image            = 'https://drive.google.com/file/d/1tRu3AcVFCttgsZN9N0ShTjwuLgqq1YUr/view?usp=sharing',
  game_video            = 'https://youtu.be/T_QfB8fnImk',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('What A Strike'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a 25m x 25m grid. Along the edge of the grid place 6 goals 2m wide like a pool table. See image above  * Divide the players into 2 teams * The Games begins with the coach throwing the ball in * Teams try and score in any of the 6 goals. Once a team pots a ball in a goal they cannot go to that goal again * Once a goal is socred another ball is thrown in by the coach  * Play for a set time or until a team has scored in every goal. They team that has the most points or socres in all the goals first is the winner',
  game_variations       = '**Variations:** * Don''t remove a goal after a team scores. Let players score in whatever goal they want. * Introduce handpassing through a goal instead of kicking or striking. * Get players to carry the ball through the goal for a score.',
  game_teaching_points  = '**Teaching Points:** * Accurate striking and kicking. * Quick play. * Performing skills under pressure.',
  game_image            = 'https://drive.google.com/file/d/1ZlcObuiDyIgFWVcBPRVJELLVyql1HYS6/view?usp=sharing',
  game_video            = 'https://youtu.be/kspLZteuckw',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Pot The Ball'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out 2 grids 15m apart. Each grid is 10m wide and 15m long * Split players into 2 teams. Each team is placed in a grid. Players handpass the ball to each other * Each player is given a number. On the coaches call ''No. 3 Infiltrate'' this player from each team runs across to the other teams grid * The infiltrator attempts to win possession from the team. They have 20 secs to do so * If the infiltrator wins possession their team is awarded 1 point. After the 20 secs they return to their own team and the coach calls another player  * The team with the most points after a set time is the winner',
  game_variations       = '**Variations:** * Coach calls out more than 1 number for players to infiltrate. * Increase the size of the grid. * Increase the size of the grid so players can strike or kick the ball to each other.',
  game_teaching_points  = '**Teaching Points:** * Accurate hand passing, striking and kicking. * Team play and tackling. * Performing skills under pressure.',
  game_image            = 'https://drive.google.com/file/d/1EHYivtfuCCgVbjD0fJO9_6ufrFC25cZk/view?usp=sharing',
  game_video            = 'https://youtu.be/kbgG5sKKwr0',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Infiltrate'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a triangular grid with 3 equal sized zones. Place a goalkeeper and two defenders in each zone. Place 3 to 4 balls beside each goal. Look at image above * Players must stay in their area and protect their goalkeeper, who in turn protects the goal. * Each team has one assassin who attempts to score points by beating the goalkeeper to score a goal. * The assassin must be inside the opponent’s area to score in their goal. Creating 2v1 or 1v1 situations. 2 assassins can go for the same area * Each assassin has 3 to 4 shots and must return to their own goal to reload and collect a new ball after each shot * Team with the most points after every player has had a turn as an assassain is the winner',
  game_variations       = '**Variations:** * Open up the Games to free play where no one is restricted to an area. * Increase the size of the grid. * Place more than one assassain on.',
  game_teaching_points  = '**Teaching Points:** * Quick shooting. * Tackling and awarness. * Performing skills under pressure.',
  game_image            = 'https://drive.google.com/file/d/1YgoWeEC0Vekqgb-c_aykpVSLr1671LaQ/view?usp=sharing',
  game_video            = 'https://youtu.be/BxCpFezAcE4',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Assassin''s Creed'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 30m x 30m * Divide the players into 2 teams. Pair up players on each team. Players must link arms or tir their legs together with a piece of cloth * Players must stay linked throughout the Games. Players attempt to hit the cones in the goal like the image above. Players must switch sides on the coaches call * The team who has scored the most goals after a set time is the winner',
  game_variations       = '**Variations:** * Remove the cones in the goal. * When coach shouts ''Break'' players split and play on their own. * Make the area bigger or smaller.',
  game_teaching_points  = '**Teaching Points:** * Working together. * Performing skills with both sides of the body. * Accurate kicking.',
  game_image            = 'https://drive.google.com/file/d/18U0FZqdFcz15TM2JRv0hftx7CjP4EfM7/view?usp=sharing',
  game_video            = 'https://youtu.be/GgJIWISAqhQ',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Stuck With You'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 25m x 25m and place a goal at each end of the grid. Place a semi circle of cones in front of each goal * Split players into 2 teams * The Games begins with the coach throwing the ball in. The team that wins possession must try and get the ball to one of the players in the semi circle   * If a team is successful getting the ball to the semi circle player they are awarded one point. * The Games restarts witht the coach throwing another ball in. The team with the most points at the end of the set time is the winner',
  game_variations       = '**Variations:** * Place the goalkeepers with a team. If a team makes a successful pass to the keeper they become a keeper also. The team to get all players inside the semi circle first is the winner. * Let the ball start with the keepers. * Introduce skills like kick/strike only, hand pass only, etc.',
  game_teaching_points  = '**Teaching Points:** * Team Work. * Tackling. * Accurate passing.',
  game_image            = 'https://drive.google.com/file/d/1GZD9z1Elq0k1ndK8rUGH-W8FIlOXbkih/view?usp=sharing',
  game_video            = 'https://youtu.be/BQAftoONN38',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Captain Ball 2'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 30m x 30m. Set out a 5m triangle in each corner * Nominate one player to be the bear. The rest of the players are explorers * The bear collects a ball from the side of the grid and attempts to hit the explorers by hand passing or throwing the ball at the legs in order to bite them * If a player is bitten they to go collect a ball from the side and become a bear. Bears have one attempt at hitting an explorer. If they miss they must retreive a new ball * The explorers cannot be attacked once they are in one of the triangles (Cave). The explorers can only stay in a cave for 10 seconds and cannot return to same triangle without going to another one first * The last explorer left when all the balls have been used is the winner',
  game_variations       = '**Variations:** * Reduce the amount of time players have in a cave. * Limit the number of players allowed in a cave. * Use other equipment like bean bags. Give every player a ball so they have to carry and perform skills.',
  game_teaching_points  = '**Teaching Points:** * Speed and Agility. * Timing and Decision Making. * Accurate passing.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Bears and Caves'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a two 30m x 10m channels. Place a start cone and an end cone at each end of the channel like image * Split players into 2 teams * All players begin at their start cone * On the coaches call the first player from each team runs with the ball out around the end cone and back to the start cone * The first player then links arms with the second player and they both run around end cone and back. This repeats until all players are on the chain * The team who successfully runs out to end cone together and back is the winner',
  game_variations       = '**Variations:** * Give every player a ball. * Increase or decrease the distance of the run.',
  game_teaching_points  = '**Teaching Points:** * Team work. * Ball Control. * Balance.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Chain Race'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a 30m x 30m grid. Inside the grid set out different shapes using cones like image above. Semi circles, triangles, circles, diamonds, etc * Split players into groups of 3 and place each group in a shape to start * Players pass the ball to each other using one touch (No bounce, solo, etc,). Handpassing or kicking/striking * Players stay in a shape for 1 minute and move around inside the shape * On the coaches call the groups of 3 move to another shape * Count how many successful passes each team gets in each shape. Once all the shapes are completed take a break.=',
  game_variations       = '**Variations:** * Increase or decrease the size of the shapes. * Only allow one play to leave a shape each time to link up with 2 new players. * Introduce striking/kicking in the shape.',
  game_teaching_points  = '**Teaching Points:** * First Touch. * Understanding different spaces. * Accurate passing.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('What Shape'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 40m x 20m. Place a goal at each side of the grid * Split players into 2 teams of 4. One team can score at the goals either end and the other can score in goals either side * The team playing length ways can use an extra player. You can play with keepers if you wish * Normal rules apply * The team that socres the most goals after a set time is the winner * Give teams a chance to play both directions',
  game_variations       = '**Variations:** * Play one touch or two touch. * Increase the distance for striking or kicking. * Decrease the distance to encourage more tackling and working in tight areas.',
  game_teaching_points  = '**Teaching Points:** * Decision making. * Awareness. * Team Play.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Long and Short'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 40m x 20m split into 4 zones * Split players into groups of 3 and place each group in one of the four zones * Play 2 v 1 in each zone with a goal at each end like image above. Players are restricted to their zone * At least one attacker must touch the ball in each zone without a defender’s touch before they can score. Players can score at either end. If a defender wins the ball they become attackers and can attack either goal * Attackers must complete four passes before trying to score. If the defenders score you switch them with four attackers immediately. The team with most goals wins.',
  game_variations       = '**Variations:** * Allow ball to be played backwards. * Allow defenders to leave zones to double up on attackers. * Increase or decrease the size of the grid.',
  game_teaching_points  = '**Teaching Points:** * When to play forward. * First Touch. * Movement and Communication.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Connect Four'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out 4 grids 10m x 10m for Football, 20m x 20m for Hurling * Split players into groups of 4 and place inside each grid. Players are paired up * The player with the ball jogs to the oppositions corner, turns, and serves the ball to their team mate at around head height * The team mate dives towards the ball and tries to palm it past the 2 opposition players to score. Batting the ball for Hurling. Opposition players try to stop the ball * After each attempt the opponent gets a turn so all players are constantly rotating position * Encourage quick attacks * Team with the most goals wins',
  game_variations       = '**Variations:** * Increase the distance. * Increase or decrease the size of the goals. * Encourage players to throw the ball at different heights/angles for team mate.',
  game_teaching_points  = '**Teaching Points:** * Batting a ball and palming a ball. * Hand Eye Co Ordination. * Timing.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Cannon Ball'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 40m × 30m including two 5m end zones and a half-way line which must be clearly marked * Split players into 2 teams. Teams play outnumbered. Example 4 v 2, 3 v 1 in each half * The team in possession needs to create space to play an accurate long pass to the recievers in the end zone. The team not in possession should defend the end zones * Points only count when balls a struck from behind the half way line directly to reciever * After a set time rotate the attackers, defenders and goalkeepers.',
  game_variations       = '**Variations:** * Increase the distance. * Double points for using opposite side. * Increase or decrease the number of recievers.',
  game_teaching_points  = '**Teaching Points:** * Long passing. * Team play. * Catching and Handling.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Incoming'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 45m × 30m. In the 4 corners and the edges of the grid place 5m x 5m boxes * Split players into 9 attackers and 3 defenders * Attackers are restricted to 2 touches. Place plenty of extra balls outside the grid. If the defenders win the ball they can score in any box they wish. Scores are got when the ball is successfully placed down inside a box * Attackes must attempt to complete a set number of passes (E.g. 10) before they can score * Count the number goals scored. Switch the defensive team after 2 minutes',
  game_variations       = '**Variations:** * Attackers to recieve the ball in a box. * Place more defenders in the game. * Increase or decrease the area for strike/kick only or hand pass only.',
  game_teaching_points  = '**Teaching Points:** * Using space. * Defenders pressuirng the ball. * Timing and decision making.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Put Down'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 40m × 40m. Place a goal on the 4 sides like the image above * Split players into 2 teams of 4 plus 4 neutral goalkeepers * Play the game for 3 mins and then rotate the goalkeepers. The team in possession can score in any goal * On scoring a goal or making a save, the goalkeeper then delivers the ball to the opposite team who cannot shoot back at the same goal.',
  game_variations       = '**Variations:** * Increase or decrease the size of the grid. * Add in more than one ball. * Increase or decrease the amount of players playing in the grid.',
  game_teaching_points  = '**Teaching Points:** * Quick shots. * Using space. * Decision making.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Jeepers Keepers'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a large grid 20m wide with a 8m square inside * Place 6 attackers inside the small sqaure in the middle of the grid with a ball each * The defenders stand just outside the small square * On the coaches call defenders run out around a cone nearest to them and then re enter the grid. Attackers score by breaking out of the grid without being two-hand tagged by a defender * When all attackers have scored or been touched they turn and face the 8m square from outside the 20m square. Defenders now go into the 8m square. On the coaches second call, defenders break from the small square while attackers look to get back into it without being touched  * Play for two minutes and switch defenders and attackers',
  game_variations       = '**Variations:** * Increase or decrease the size of the grid. * Place more or less defenders on. * Introduce skills like soloing, bouncing while players move with the ball.',
  game_teaching_points  = '**Teaching Points:** * Agility and reactions. * Using space. * Decision making.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Escape With The Egg'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 25m long and 10m wide * Split the players into teams of 3 attackers and 3 defenders. Spread the defenders equally along the channel. They can only move side ways * The three attackers have a ball. They use passing (Sideways only) and running skills to score * If the player with the ball is tackled, they call out “Support Support” and pass the ball away within 3 seconds. * Give the attackers three attempts to score. Each attempt ends if the ball carrier doesn’t call “Support Support”, or pass the ball away within 3 seconds of the tackle, or a pass goes forward, or a ball carrier steps out of play * Switch attackers and defenders after 3 attempts',
  game_variations       = '**Variations:** * Increase or decrease the size of the grid. * Allow one pass to go forward to encourage play in behind. * Give defenders tennis balls to hold to stop grabbing.',
  game_teaching_points  = '**Teaching Points:** * Agility and reactions. * Hand passing. * Decision making.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Support Support'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 15m x 15m. * Place all the players with a bean bag each at one end of the grid * Place targets spread out at different distances inside the grid. Example: Hoola Hoops, Small Cones, Big Cones, Balls on top of cones, etc * Players throw their bean bags and try hit different targets. Once a player throws their bean bag they retrieve it and return to start  * Get players to count how many targets they hit',
  game_variations       = '**Variations:** * Increase or decrease the size of the grid. * Get players to throw different ways (Under arm, Over arm). * Use opposite side.',
  game_teaching_points  = '**Teaching Points:** * Throwing. * Accuracy. * Decision making.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Fire The Cannons'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 20m x 20m grid. Place 2 lines of cones 1m apart across the middle of the grid. At both ends of the grid place 10 cones with a tennis ball on each cone * Split players into 2 teams and give every player a ball * Team 1 stands on one of the lines in the middle of the grid. Team 2 stands on the other middle line * Players throw or roll the ball along the ground attempting to hit the tennis balls off the cones * Players retrieve their ball and retiurn to middle line to have another go * Team to knock all their tennis balls off first is the winner',
  game_variations       = '**Variations:** * Increase or decrease the size of the grid. * Use smaller or larger cones. * Use opposite side.',
  game_teaching_points  = '**Teaching Points:** * Throwing. * Accuracy. * Decision making.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Rolling Rocks'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 20m x 20m grid. Scatter lots of hoops throughout the grid. Also scatter lots of different colour bean bags throughout the grid * Split players into 2 teams. Team 1 are Goodies and Team 2 are Bandits * On the coaches call goodies enter the grid and have 30 secs to place bean bags inside matching colour hoops. After 30 seconds bandits enter and attempt to remove bean bags from hoops and place them in the wrong colours * Goodies fix any wrong colour bean bags in hoops * All players keep playing until the set time is up * If the goodies have more bean bags in the correct colour they win. Swap team roles and play again',
  game_variations       = '**Variations:** * Give every player a football or small ball to carry around while playing. * Increase or decrease the amount of hoops in the grid. * Get players to balance bean bags on their head while moving through the grid.',
  game_teaching_points  = '**Teaching Points:** * Pick up. * Balance. * Agility.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Bandits and Goodies'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 40m x 20m grid. Divide the grid into 3 zones but leave a 5m gap either side like image above * Split players into 2 teams and and place both teams at the start of the grid in zone 1 * The team in possession must play a set number of passes (E.g. 5) then attempt to break into the next zone through one of the time portals by passing or running through. * The defending players are not allowed stand in front of the gate to block it * Once the ball has been played through a gate the player who played it has followed it through, all of the players can move through into the next zone and the process begins again. * If possession is lost the other team faces the same challenge. Team who got through the most zones after the time is finished is the winner',
  game_variations       = '**Variations:** * Make the grid bigger to introduce kicking and striking. * Play an uneven number like 5 v 4, 4 v 2.',
  game_teaching_points  = '**Teaching Points:** * Decision Making. * Team Play. * Passing.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Time Portal'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 40m x 20m grid with 5m end zones at either end * Split players into 2 teams. One team starts in the middle and one team goes to an end zone  * The team in the middle are the zombies and in order to bite a player they have to keep their ball close and within touching distance they tag a runner with their hand. * The players without a ball have to go from end zone to end zone without being bitten by the zombies. * Once a runner is bitten they turn into a zombie and get a ball from the side of the area. See who can be the last runner to get bitten.',
  game_variations       = '**Variations:** * Fewer zombies than runners. * Introduce skills like dribbling, solo, bounce. * Increase or decrease the size of the grid.',
  game_teaching_points  = '**Teaching Points:** * Ball control. * Evasion. * Agility.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Zombie Attack'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 15m circle using cones with a diamond in the middle like image above * All players start in the diamond with a ball each * Nominate a player to audition their funny turn. This can be any way they know of turning with the ball, however unorthodox. The player called carries the ball to one of the outside cones and shows a turn that all the others must watch.  * After the rehearsal the players have to work their way around the clock performing their turn and returning through the diamond at each cone * The coach is the judge and selects the best turn after a set time. The player selected becomes the judge for the next round',
  game_variations       = '**Variations:** * Jump and turn. * Use different equipment for players to carry. * Encourage players to use the ball for their turn.',
  game_teaching_points  = '**Teaching Points:** * Ball control. * Balance. * Turning.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Acrobats'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out 40m x 20m grid. Split into two halves. Set out 10m x 10m grids in each half. Place 2 to 3 balls in each half * This game must be played by teams of 4 or 5 as you need at least one spare grid in each half of the area * Players attempt to throw the ball above head height into the spare grid in the opponent’s half. It must hit the ground to score a point. Opposition move to try and stop this but only one player can enter a zone at a time * The opposition must prevent this by catching the ball. They can then try to throw into their opponent’s spare grid * Play to 10 points, switching sides halfway through.',
  game_variations       = '**Variations:** * Use footballs, bean bags. * Use opposite hand to throw. * Players throw underarm and over arm head height.',
  game_teaching_points  = '**Teaching Points:** * Catching. * Throwing. * Decision making.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Airball'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a 10m circle * Split players into 2 teams, cats and mice, with the players on each team numbered 1-6 each starting at a cone. Place 12 balls (Cheese) in the middle * The coach calls out a number and the appropriate mouse runs to the centre and steals the cheese, one piece at a time, taking it back to their starting place on the circle. At the same time, the appropriate cat takes a piece of cheese, dribbles back to their starting cone and then all the way around the outside of the circle before returning the cheese to the middle  * When the cat gets back the turn is over. The mouse counts their cheese and returns it to the middle before the coach calls the next number to repeat the game * After all 6 pairs have gone, count the total number of pieces of cheese stolen and switch the roles of cat and mouse',
  game_variations       = '**Variations:** * Let cats run around the circle without a ball. * Call more than one number at a time. Place bean bags instead of balls. * Use skills like bouncing, dribbling.',
  game_teaching_points  = '**Teaching Points:** * Agility. * Ball control. * Speed.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Cat and Mouse'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a 30m x 30m grid with triangular “pizza slices” at each end and a 10m x 10m pizza shop on one of the long sides * A group of attackers (chefs) start inside the hut. They need to add toppings to the pizza slices by carrying balls and palcing them on top of the pizza slices * There are 2 to 3 customers that don’t like the toppings and will try to stop it going on the pizza. They do this by knocking the topping out of the kitchen. Once a topping is placed on the pizza slice customers are not allowed to touch that topping * The chefs go in pairs until all balls have been played. How many toppings can they get on the pizza slices',
  game_variations       = '**Variations:** * Let more than 2 players run with the ball. * Get players to dribble the ball back to the shop to see how many pizzas they can deliver. * Introduce different skills while moving with the ball.',
  game_teaching_points  = '**Teaching Points:** * Agility. * Ball control. * Speed.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Apache Pizza'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a 30m x 15m channel with 4m x 4m box at the end of channel like image above * Split players into equal teams, each team has a channel to work in. No more than 3 players on a team * One player from each team stands at the far end of the channel where the box is placed. The first player in line runs down the channel to the box at the end and plays 10 quick passes with their team mate. They then replace their team mate who sprints back to the team and tags the next player who repeats the run * The relay ends when all players have completed the skill and returned to their team * Award each team points based on their position (3 points for 1st, 2 for 2nd, 1 for 3rd, for example)',
  game_variations       = '**Variations:** * Use different skills to pass the ball like kicking, striking, throwing etc. * Instead of 10 passes place a tall cone where players put one hand on, spin around ten times and run back to their group. * Animal movements.',
  game_teaching_points  = '**Teaching Points:** * Agility. * Ball control. * Speed.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Skill Relay'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a 40m x 30m pitch with goals. Two 5m x 5m boxes on each side, 10m from the goal line like image above * Split players into 2 teams. Place 2 players from each team in the boxes nearest to the goal they are scoring in. The remaining players play in the area * To score, a team must pass to one of the boxed players, who catch the ball or pick it up and quickly look to pass it back to one of their team mates who then attempts to score a goal * Rotate the players in the boxes at regular intervals * Team with the most points at the end wins',
  game_variations       = '**Variations:** * Award points for getting ball to a boxed player * Increase the size of the area. * Play no goalkeepers.',
  game_teaching_points  = '**Teaching Points:** * Passing. * Team play. * Decision making.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Throw In Frenzy'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a 40m x 30m grid with 5m end zones at either end filled with poles. Goals are a further 5m outside the area * Split players into 2 teams. Inside the main area the teams try to maintain possession until they see the opportunity to run through the swamp at either end * If they get through the swamp without hitting a pole they can score in the goal by passing the ball in with accuracy, not power * If they hit a pole the attack stops and possession is given to the other team. If they score, they keep possession and must attack the opposite end * Team with the most scores at the end wins',
  game_variations       = '**Variations:** * Allow a defender to follow an attacker into the swamp. * Instead of running throw the swamp get players to shoot through the swamp avoiding the poles. * Remove a pole everytime a goal is scored to make it easier.',
  game_teaching_points  = '**Teaching Points:** * Accurate shooting. * Team play. * Decision making.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('The Swamp'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a 20m x 30m grids with a marked halfway line * Split players into teams of 3. Place 2 teams against each other. One team of three starts in each half of the grid. The object of the game is to palm the ball out of the grid over the end line of opposite team * The team moves the ball using the hand pass until an opportunity arises they then throw the ball for a team mate to palm the ball over the end line  * The opposite team can stop the ball any way they want including with their hands * Teams score a point for each palm that clears the end line. Play first to 5 or 10 and, if using more than one grid, play a round robin to see who the champions are',
  game_variations       = '**Variations:** * Use one hand to palm the ball instead of 2. * Use other equipent like tennis balls, soft balls, etc. * Make every player on the team get a touch before a ball can be palmed.',
  game_teaching_points  = '**Teaching Points:** * Hand eye co ordination. * Team play. * Accuracy.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Head Up'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a 30m x 30m grid with cones and zones like image above * Split players into 2 teams. The attacking team pass the ball across their zone until one decides to take on a defender 1v1 * The defenders are each restricted to one 8m yard x 8m box and can tackle the player with the ball or force them backwards or sideways into another defender’s box * Once through the defensive line the attackers try to score against the goalkeeper unopposed. If the attacker is tackled they go back and start again * Only the player with the ball moves beyond the defensive line. Change roles after a set time. Team who scored most goals is the winner',
  game_variations       = '**Variations:** * Allow one defender to chase down the attacker. * Add more balls into the game.',
  game_teaching_points  = '**Teaching Points:** * Decision making. * Team play. * Speed.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Escape'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a 20m x 20m grid  * Place all players in the grid with a ball each. Every player is against each other * Players can hold the ball in their hand but the ball is not allowed touch any other body part for the entire game. Players use their other hand to knock other players balls out of their hand * All players have 3 lives to start. If a player loses all their lives they are eliminated from the game. Last player left is the winner',
  game_variations       = '**Variations:** * Instead of players holding ball in front get them to hold above head. * Increase or decrease the amount of lives. * End the game after a set time as players are not sitting out for too long.',
  game_teaching_points  = '**Teaching Points:** * Awareness and ball control. * Agility. * Balance.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Swiper'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 25m x 25m and Split players into 2 teams. Place a line of cones across the centre of the grid and put 1 team either side * Players must stay on their side for the entire game * Place lots of balls and bean bags on each side of the * Teams strike/kick the ball on the ground onto the other teams side. Players throw the bean bags with their catching hand across to the other side * The game goes back and forth * The game finishes after a set time * The team with the least amount of balls and bean bags on their side is the winner',
  game_variations       = '**Variations:** * Award extra points if a player catches a bean bag. * Increase or decrease the size of the grid. * Players kick/strike out of their hands.',
  game_teaching_points  = '**Teaching Points:** * Striking and Kicking. * Accuracy. * Co-Ordination.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Clear The Garden 2 (Bean Bag)'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 20m circle and a 5m smaller circle inside like image above * Players move around in the area between the 2 circles * Coaches or nominated players stand inside the inner circle with lots of bean bags * Coaches/players inside inner circle throw bean bags and attempt to hit players on the legs * All other players have 10 lives. If players get hit they lose a life * The game finishes after a set time and the player with the most lives left is the winner * Players can earn lives back by placing the bean bags back into the inner circle',
  game_variations       = '**Variations:** * Get players to use their hurley to protect themsleves. * Give players footballs to carry while running. * Make the outside circle smaller.',
  game_teaching_points  = '**Teaching Points:** * Balance. * Jumping, Agility. * Co-Ordination.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Bean Bag Tag 2'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 15m x 15m * Split players into 2 teams * One team begins with the ball and they are taggers. The other team need to stay away from the ball * The taggers pass the ball by throwing it to each other. Taggers are not allowed move when in possession * If the taggers tag an opposition player the team is awarded one point. Opposition need to avoid been tagged * Play for 3 minutes and switch roles * The team with the most tags is the winner',
  game_variations       = '**Variations:** * Get players to hand pass instead of throw. * Allow taggers to take one step. * Make the grid smaller.',
  game_teaching_points  = '**Teaching Points:** * Team play. * Passing. * Agility and evasion.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Tag Ball'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 30m x 30m * Pick 2 to 3 taggers to start * Place the rest of the players on one end of the grid * The taggers call a players name to run. This player can run on their own or call bulldog charge and all players then run * Players attempt to get from one side of the grid to the other without getting tagged * If a player is tagged they also become a tagger * Last player left is the winner',
  game_variations       = '**Variations:** * Introduce a ball. * Make the area bigger or smaller. * Give players lives so they have more chance of not being a tagger.',
  game_teaching_points  = '**Teaching Points:** * Agility. * Running. * Evasion.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Bulldog'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 25m x 25m * Pick 2 to 3 taggers to start * Place all players inside the grid * Players run throughout the grid attempting not to get tagged * If a player is tagged they lie on their backs with their knees tucked into their chest like an upside down turtle * Players get free when another player pushes the turtle back onto their feet * Play for a set time then change taggers',
  game_variations       = '**Variations:** * Introduce a ball. * Make the area bigger or smaller. * Give players lives so they have more chance of not being a tagger.',
  game_teaching_points  = '**Teaching Points:** * Agility. * Running. * Evasion.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Turtle Flip'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 25m x 25m * Pick 2 to 3 taggers to start * Place all players inside the grid * Players run throughout the grid attempting not to get tagged * If a player is tagged they go down on their hands and feet like a press up * Players get free when another player crawls underneath their bridge * Play for a set time then change taggers',
  game_variations       = '**Variations:** * Introduce a ball. * Make the area bigger or smaller. * Give players lives so they have more chance of not being a tagger.',
  game_teaching_points  = '**Teaching Points:** * Agility. * Running. * Evasion.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Bridges and Rivers'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 25m x 25m * Pick 2 to 3 taggers to start * Place all players inside the grid * Players run throughout the grid attempting not to get tagged * If a player is tagged they lie down on their stomach * Players get free when another player run and jumps over the tagged player * Play for a set time then change taggers',
  game_variations       = '**Variations:** * Introduce a ball. * Make the area bigger or smaller. * Give players lives so they have more chance of not being a tagger.',
  game_teaching_points  = '**Teaching Points:** * Agility. * Running. * Jumping.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Log Jump'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 25m x 25m * Pick 2 to 3 taggers to start * Place all players inside the grid * Players run throughout the grid attempting not to get tagged * If a player is tagged they stand with their legs wide apart * Players get free when another player crawls under a tagged players legs * Play for a set time then change taggers',
  game_variations       = '**Variations:** * Introduce a ball. * Make the area bigger or smaller. * Give players lives so they have more chance of not being a tagger.',
  game_teaching_points  = '**Teaching Points:** * Agility. * Running. * Evasion.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Stuck In The Mud'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 25m x 25m * Pick 2 to 3 taggers to start * Place all players inside the grid * Players run throughout the grid attempting not to get tagged * If a player is tagged they stand with one armed raised out to the side * Players get free when another player pushes a tagged player arms down * Play for a set time then change taggers',
  game_variations       = '**Variations:** * Introduce a ball. * Make the area bigger or smaller. * Give players lives so they have more chance of not being a tagger.',
  game_teaching_points  = '**Teaching Points:** * Agility. * Running. * Evasion.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Flush The Toilet'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 30m x 30m * Pick 1 to 2 taggers to start as Zombie Chief (s). They stand in the middle of the playing area * Divide the rest of the players into four groups, with one group spread along each side of the playing area * On the coaches signal, the players run through the playing area and get to the opposite side without being caught by the Zombie Chief * If a player is tagged, that player becomes a “zombie slave”. They can “capture” other players (who similarly become zombie slaves), but they cannot move from the spot where they were caught. Only the Zombie Chief can move. * Last player left is the winner',
  game_variations       = '**Variations:** * Introduce a ball. * Make the area bigger or smaller. * Give players lives so they have more chance of not being a tagger.',
  game_teaching_points  = '**Teaching Points:** * Agility. * Running. * Evasion.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Zombie Chief'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Circle Tag'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Spiders and Flies'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('What Time Is It Mr. Wolf'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Set out a grid 25m x 25m * Pick 2 taggers to start. These 2 players link arms * Place all players inside the grid * If a player is tagged they join the ''Blob'' * Players in the blob link arms at all times * Last player left who wasn''t caught by the blob is the winner',
  game_variations       = '**Variations:** * Link hands instead of elbows. * Split the blob into 2. * Have paired blobs.',
  game_teaching_points  = '**Teaching Points:** * Agility. * Team work. * Evasion.',
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Blob Tag'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Sharks In The Water'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Hot Dog Tag'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Everyone''s On'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Octopus Tag'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Soccer Ball Tag'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Snakes In The Grass'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Animal Tag'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Divide the players into groups of 4 * Mark out a distance of 40m using 2 cones * Place one player at each cone with a ball and the other 2 players in the middle * In turn the outer players strike the ball for the nearest middle player to control and strike back. The second middle player provides token opposition * Reverse the role of the middle players when the second ball is played * Change the feeders and recievers after a set time',
  game_variations       = '**Variations:** * Increase or decrease the distance. * Strike to hand. * Use opposite side.',
  game_teaching_points  = '**Teaching Points:** * Cushion the ball on the Hurley and into the hand. * Run into the ball and attempt not to stop. * After recieving the ball keep moving when striking.',
  game_image            = NULL,
  game_video            = 'https://youtu.be/IZ-ZggDVnIg',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Controlling A Moving Ball Pressure'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Place 2 cones 5m away from each other and another cone 1m away from the first cone in a straight line * Divide the players into pairs * One player stands at the far cone with the ball. Other player runs from first cone to second cone as ball is thrown in the air for them to over head catch * Players have 5 turns and then switch * Encourage players catching the ball to move into it',
  game_variations       = '**Variations:** * Increase or decrease the distance. * Instead of throw strike the ball in the air. * Introduce a jump to catch.',
  game_teaching_points  = '**Teaching Points:** * Use fingers to catch the ball. * Run into the ball and attempt not to stop. * Keep your eye on the ball.',
  game_image            = NULL,
  game_video            = 'https://youtu.be/3Hj2QGIFafo',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Over Head Catch Move To Catch'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Place 2 cones 5m away from each other and another cone 1m away from the first cone in a straight line * Divide the players into groups of 4 * Two players stand at the far cone with the ball. Other 2 players run from first cone to second cone as ball is thrown in the air for them to compete for over head catch * Players have 5 turns and then switch * Encourage players catching the ball to move into it',
  game_variations       = '**Variations:** * Increase or decrease the distance. * Instead of throw strike the ball in the air. * Introduce a jump to catch.',
  game_teaching_points  = '**Teaching Points:** * Use fingers to catch the ball. * Run into the ball and attempt not to stop. * Keep your eye on the ball and use your body.',
  game_image            = NULL,
  game_video            = 'https://youtu.be/-ndJt7SxLnc',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Opposed Over Head Catch'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Place 3 cones 5m away from each other in a triangle like image * Divide the players into pairs * Player A stands at the top of the triangle with the ball * Player B stands at one of the corner cones. Player A throws the ball out in front and Player B moves across to catch the ball over head * Encourage players catching the ball to move into it',
  game_variations       = '**Variations:** * Increase or decrease the distance. * Instead of throw strike the ball in the air. * Introduce a jump to catch.',
  game_teaching_points  = '**Teaching Points:** * Use fingers to catch the ball. * Run into the ball and attempt not to stop. * Keep your eye on the ball and use your body.',
  game_image            = NULL,
  game_video            = 'https://youtu.be/yhKJVQEiOvs',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Over Head Catch Move To Catch 2'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Place 2 cones 5m away from each other and another cone 1m away from the first cone in a straight line * Divide the players into pairs * One player stands at the far cone with the ball. Other player runs from first cone to second cone as ball is struck for them to control into hand * Players have 5 turns and then switch * Encourage players one touch from Hurley into hand',
  game_variations       = '**Variations:** * Increase or decrease the distance. * Strike the ball chest height. * Encourage players to keep moving into the ball.',
  game_teaching_points  = '**Teaching Points:** * Use fingers to catch the ball. * Run into the ball and attempt not to stop. * Keep your eye on the ball and cushion the ball using the Hurley.',
  game_image            = NULL,
  game_video            = 'https://youtu.be/T4xdHj9tLY0',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Controlling A Moving Ball 1'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Place 2 cones 20m away from each other and another 2 cones 5m at an angle like image above * Divide the players into pairs * One player stands at the far cone with the ball. Other player runs from first cone to one of the angled cones as ball is struck for them to control into hand * Players have 5 turns and then switch * Encourage players one touch from Hurley into hand',
  game_variations       = '**Variations:** * Increase or decrease the distance. * Strike the ball chest height. * Encourage players to keep moving into the ball.',
  game_teaching_points  = '**Teaching Points:** * Use fingers to catch the ball. * Run into the ball and attempt not to stop. * Keep your eye on the ball and cushion the ball using the Hurley.',
  game_image            = NULL,
  game_video            = 'https://youtu.be/PcRxuq_IXwM',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Controlling A Moving Ball 2'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Place 2 cones 5m away from each other and another cone 1m away from the first cone in a straight line * Divide the players into pairs * One player stands at the far cone with the ball. Other player stands with their back to their partner. They run to the far cone, turn and control the ball into the hand * Players have 5 turns and then switch * Encourage players one touch from Hurley into hand',
  game_variations       = '**Variations:** * Increase or decrease the distance. * Strike the ball chest height. * Encourage players to keep moving into the ball.',
  game_teaching_points  = '**Teaching Points:** * Use fingers to catch the ball. * Run into the ball and attempt not to stop. * Keep your eye on the ball and cushion the ball using the Hurley.',
  game_image            = NULL,
  game_video            = 'https://youtu.be/snBbRJIFQ74',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Controlling A Moving Ball Turn and Control'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Divide the players into groups of 4 * Place the players in a straight line 10/15m apart * Ball starts at one end. The ball is struck from player to player as quickly as possible * The team that finishes first is the winner * Encourage players to move to the the ball',
  game_variations       = '**Variations:** * Increase or decrease the distance. * Strike the ball chest height. * Encourage players to keep moving into the ball.',
  game_teaching_points  = '**Teaching Points:** * Use fingers to catch the ball. * Run into the ball and attempt not to stop. * Keep your eye on the ball and cushion the ball using the Hurley.',
  game_image            = NULL,
  game_video            = 'https://youtu.be/ZZtZpYwrypg',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Controlling A Moving Ball Relay'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = '**How to Play:** * Divide the players into groups of 6. No More than 6 per group * Mark out a triangle with cones 10m apart. 2 players at each cone * Ball starts at one cone. Players solo the ball in a clockwise direction and hand pass the ball to the player at the next cone',
  game_variations       = '**Variations:** * Increase or decrease the distance. * Go opposite direction. * Encourage players to keep moving into the ball.',
  game_teaching_points  = '**Teaching Points:** * Use fingers to catch the ball. * Use fingers and top of palm to hand pass. * Keep your eye on the ball and claw catch.',
  game_image            = NULL,
  game_video            = 'https://youtu.be/WLbNMjwvfdM',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Solo Run With Pass'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = 'https://youtu.be/IOiRhqLKBKI',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Solo Run Zig Zag With Shot'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Solo Run Touchdown'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Solo Run Tag'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Solo Run Fill The Hoop'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Turn And Control'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = 'https://youtu.be/OpmY3iryF5c',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Chase And Hook'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = 'https://youtu.be/y8Ey8VezIQY',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Chase And Hook 2'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Zig Zag Roll Lift'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Roll Lift Musical Chairs'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Roll Lift 2'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('X Roll Lift'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Pressure Hand Pass'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Strike But Keep It Wide'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Shoulder Clash Jog and Clash'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Roll and Shoulder Clash'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Dribble Signal and Turn'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Through The Goals'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Knock The Cap'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Swap Shop'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Imagnary Strike'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Stopping a Ground Ball Roll'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Tightrope Strike'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Bean Bag Pancake'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Fill The Bucket'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Touch The Dome'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Run and Hug The Ball'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Kick Off The Cone'));

UPDATE public.games SET
  game_setup            = NULL,
  game_how_to_play      = NULL,
  game_variations       = NULL,
  game_teaching_points  = NULL,
  game_image            = NULL,
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Reaction Game'));

UPDATE public.games SET
  game_setup            = '**Setup as Follows:**  * Poles to be used to create "fences" to jump over and "tunnels" to crawl through * Slalom through poles to improve agility and speed * Hurdles set out 1m apart with rapid feet through that section * Hula Hoops staggered out diagonally 1m apart * Sprint to finish',
  game_how_to_play      = '**How to Play:** * 2 Teams of 6 players each * Top 2 players in each group go at a time * Leave 5 seconds between pairs * Players will race against their opposite player to see who can complete the course first and return to the finish line',
  game_variations       = '**Variations:** * If its a hurling session tell the kids to bring the hurley with them as they complete the course',
  game_teaching_points  = '**Teaching Points:** * Focus on completing the course without knocking the obstacles  * Take points/seconds away for each obstacle that gets knocked',
  game_image            = 'https://drive.google.com/file/d/1kQK8o3D1C5ykcqsHqMt3224Yfo8nKm5d/view?usp=sharing',
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Obstacle Course'));

UPDATE public.games SET
  game_setup            = '**Setup as Follows:**  * Make a circle of cones - 1 player at each cone',
  game_how_to_play      = '**How to Play:**  * Coach stands in the centre of the circle and shouts commands * "Jog on the spot", "Jump with High Knees 5 times", "Heels to Bums 10 times" etc',
  game_variations       = '**Variations:** * Progress to "Middle" which will be the trigger for the players to race into the centre of the circle and reverse back out to their cone * Change the activity from racing into the centre to "Bear Crawls" or "Bunny Hops" etc into the middle and then reversing back out.',
  game_teaching_points  = '**Teaching Points:** * This is great for warming up and working on fundamental movements. Jumping, hoping, skipping & transferring weight through the body.',
  game_image            = 'https://drive.google.com/file/d/19wdKmobXxn9XD4IBTcYLKcTnMAMuqUwC/view?usp=sharing',
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Circle Game'));

UPDATE public.games SET
  game_setup            = '**Setup as Follows:**  * Players line up behind the starting cone',
  game_how_to_play      = '**How to Play:** * First begin without a sliotar * The coach should stand 2m in front of the players and swing the hurley pretending to hit an imaginary ball * The players should step forward in turn and attempt to block the coach',
  game_variations       = NULL,
  game_teaching_points  = '**Teaching Points:** * Players should step forward with eyes on the ball and fully commit to the block * Once they are comfortable, introduce a large sliotar and begin blocking for real * Finally, introduce a standard sized sliotar and again practice with this',
  game_image            = NULL,
  game_video            = 'https://youtu.be/5nU3z3zdcUo',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Frontal Block Drill'));

UPDATE public.games SET
  game_setup            = '**Setup as Follows:** * Players are split into 2 teams with each player getting a number from 1 to X',
  game_how_to_play      = '**How to Play:** * When the coach calls a number, players with that number from both teams race out and around the cones * As the players turn at the cone the coach throws the ball/Sliotar in between them to compete for possession',
  game_variations       = '**Variations:** * Once a player wins possession they can attempt to carry the ball/sliotar through a gate as the defender tries to stop them * Introduce a goal to shoot into once a player has won possession',
  game_teaching_points  = '**Teaching Points:** * We want the kids to get used to competing for posession of the ball. Keep eyes on the ball at all times & try to get the timing right so they are competing at the earliest point possible to win posession * If the ball breaks to the ground, encourage the kids to continue to scrap for possession * Be harsh on tackling & rough play. They can compete hard for the ball but they cant foul. Important they understand where that line is!',
  game_image            = 'https://drive.google.com/file/d/1QJpqmStyBlu-39dEGGQP9YsSkPSeQjf1/view?usp=sharing',
  game_video            = 'https://youtu.be/LMajLt7BfsQ',
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Numbers Game'));

UPDATE public.games SET
  game_setup            = '**Setup as Follows:** * 2 Players at each red cone in the circle * Players are given a number – 1 or 2',
  game_how_to_play      = '**How to Play:** * Player 1 at each cone raises their hand to indicate they know their number and that they are ready to go * On the coaches call, all the player 1s will sprint around the outside of the circle and back to where they started * They will then crawl through their partners legs (the number 2s) and the first player to touch the cone in the middle wins * Swap player 1s and 2s',
  game_variations       = '**Variations:** * Instead of touching the cone in the middle, take a ball/sliotar from the centre of the circle * Players must then carry the ball/sliotar towards the goals and shoot for a point * The first player to score a point wins!',
  game_teaching_points  = '**Teaching Points:** * No cheating - Players must run around the full perimeter of the circle * Max 4 steps then solo prior to shooting * Encourage shooting on the run where possible',
  game_image            = 'https://drive.google.com/file/d/134ZnNw2n-3X401uVk_yOSPqn2l4rM2Lc/view?usp=sharing',
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Race & Shoot'));

UPDATE public.games SET
  game_setup            = '**Setup as Follows:** * Small Sided Game – Hand Pass Only * 1 Pitch 4 v 4 (or 5 v 5)',
  game_how_to_play      = '**How to Play:** * Players are split into 2 teams of 4 players * Each team nominates a “Catcher”.  * Teams score by hand passing the ball to their “Catcher” in the designated box * Only the “Catcher” is allowed in the box and they can move anywhere in the box but not leave it',
  game_variations       = NULL,
  game_teaching_points  = '**Teaching Points:** * Encourage all 4 steps prior to playing the ball  * Only 1 opponent can tackle the player with the ball * Encourage the players to find open space and make themselves a passing option for their team mate (reduce bunching) * Lets not run directly towards the player in possession looking for a pass. Looking for open space.',
  game_image            = 'https://drive.google.com/file/d/1VBtdCL3zgHsD2YPfnv1uHWaFC2Qi7Nx1/view?usp=sharing',
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Hand Pass Game'));

UPDATE public.games SET
  game_setup            = '**Setup as Follows:** * Players are split into 2 Teams of 4',
  game_how_to_play      = '**How to Play:** * Players from each team line up on either side of the goalposts * On the coaches call the next player on either side will weave out through the cones and turn to face the goals * The coach will roll out a ball/sliotar as the player turns the last cone * Players will then pickup and shoot for a point while on the run',
  game_variations       = NULL,
  game_teaching_points  = '**Teaching Points:** * Encourage the players to try and shoot while they are running. Its ok to stop and kick/strike but where possible lets practice striking on the run * When they pickup the ball/sliotar take the full 4 steps before shooting * Coach number 3 is behind the goal making sure coach 1 & 2 have enough balls to keep the station moving',
  game_image            = 'https://drive.google.com/file/d/1o2nhn987x9-IIVQ_xXnyM6ace_Y7lkpd/view?usp=sharing',
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Shooting Game'));

UPDATE public.games SET
  game_setup            = '**Setup as Follows:** * Split the players into 2 teams * Ensure there is 1 ball in the goals per player',
  game_how_to_play      = '**How to Play:** * On the coaches call, player 1 from each team sprints into the goals and picks up 1 ball * That player will solo the ball back out and hand pass it to player 2 * Player 2 will shoot once they receive the ball * That player then continues in and picks up a ball in the goals and solos it back out before hand passing to player 3 * Player 3 then shoots and repeats until all players have had a shot at goals',
  game_variations       = NULL,
  game_teaching_points  = '**Teaching Points:** * Proper execution of pickup and hand pass by all players * Team that scores the most wins * If it’s a tie then the team that finishes first wins * Encourage the kids to shoot with both feet * Introduce 2 points for a score off the players “other” foot',
  game_image            = 'https://drive.google.com/file/d/1iySlMs_GhB_RrM8E3LSN_9O0J1t2IivA/view?usp=share_link',
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Shooting Relay'));

UPDATE public.games SET
  game_setup            = '**Setup as Follows:** * Players each have a ball/sliotar',
  game_how_to_play      = '**How to Play:** * Start by standing 1m from the wall and practice handpassing * Then throw/pass the ball against the wall and catch over the head * Move back 5m and practice the Punt Kick or Ground Strike. Be sure to use both sides for kicking/striking. * With backs to the wall solo out 30m, turn and then strike the ball/sliothar against the wall while moving. Players should attemp to strike while running (but can stop prior to the strike if required) and then try to catch the ball/sliotar on its return from the wall before it hits the ground',
  game_variations       = NULL,
  game_teaching_points  = '**Teaching Points:** * This is not a race. Try to ensure all skills are executed to the best of the players ability.  * Its an opportunity to work with players that need additional hlep with their technique. Try to identify players that need help and break down the skills into steps so they can practice more easily on their own. * Striking on the run is very important in both codes. And driving forward to catch the ball so that the players never wait for the ball to arrive is crucial. Please encourage both of these attributes.',
  game_image            = 'https://drive.google.com/file/d/11B3uDHUakCIdWFgKeStrI3bnwfiIgwvF/view?usp=sharing',
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Skills Box'));

UPDATE public.games SET
  game_setup            = '**Setup as Follows:** * Players are split into 2 Teams of 4',
  game_how_to_play      = '**How to Play:** * Players from each team line up on either side of the goalposts * On the coaches call the next player on either side will solo/bounce the ball out around the cones * When they come around to the end of the cones they will shoot for a point using a hook kick',
  game_variations       = '**Variations:** * Coach stands at the last cone and instead of soloing the ball out around the cones, the player should hand pass to the coach, run around the cones and then receive a handpass back from the coach before shooting',
  game_teaching_points  = '**Teaching Points:** * The kick needs to be a hook kick (not a punt kick) so please watch out for players straightening up their body before shooting. The kick should be over their shoulder * Use both feet. If they are coming in from the left side of the goal then the kick should be off the right foot. Coming in from the right hand side then they should use the left foot * Ensure players stay outside the cones. They are set out to create the correct shooting angle for the hook kick',
  game_image            = 'https://drive.google.com/file/d/14NhlOIwJrlwMsFz9g0ETWNk9lZsQw7JG/view?usp=sharing',
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Hook Shot Drill'));

UPDATE public.games SET
  game_setup            = '**Setup as Follows:** * Players are split into 2 Teams of 4',
  game_how_to_play      = '**How to Play:** * Players from each team line up at their cone to start the game * Player 1 from each team goes on the whistle and solo/bounce the ball to the cones approx 15m from the wall *Before the line they’ll kick the ball against the wall and catch it again *Now it’s a race (soloing) to the back of the line where they roll the ball between the legs of their 3 team mates to player at the front of the line * Once the next player has the ball they go and repeat * First team to complete for all 4 players and roll the ball back to the first player again wins!',
  game_variations       = NULL,
  game_teaching_points  = '**Teaching Points:** * Its a fun drill but the focus needs to be on executing the skill while under pressure * Encourage the players to chase in after their ball after they kick it so that they are catching it at the earliest possible opportunity. We never wait for the ball to come to us. We always run in to meet the ball as early as possible',
  game_image            = 'https://drive.google.com/file/d/1tJp0qDy7xVFiRDi8Wssq0GYLD1TxZ-V4/view?usp=sharing',
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Relay Tunnel'));

UPDATE public.games SET
  game_setup            = '**Setup as Follows:** * Players are split into 2 Teams of 4 * No Goalkeepers',
  game_how_to_play      = '**How to Play:** * Players are split into 2 teams of 4 players * It’s a handpassing game only so to score the team must handpass through the goals * When a team scores, the player that scored must run to the sideline, take one of his teams beanbags and start a game of Xs & Os * Each time a player scores they get a turn on the sideline and must then race back onto the pitch. First team to 3 in a row wins!',
  game_variations       = NULL,
  game_teaching_points  = '**Teaching Points:** * The game on the sideline is obviously a bit of fun. But its also an opportunity to take some of the stronger players out of the game temporarily and give others an opportunity to score. * The kids will want to score but obviously it temporarily weakens their team too!',
  game_image            = 'https://drive.google.com/file/d/1RfTuPSwKS6aqZw5AMvkw1I76HM40TQxJ/view?usp=sharing',
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Xs & Os'));

UPDATE public.games SET
  game_setup            = '**Setup as Follows:**  * Players line up behind the starting cone',
  game_how_to_play      = '**How to Play:** * Player at the top of the line runs out and bounces the ball before bursting through the tackle bags (held by the coaches) * They will then run on and solo around the end cone * Now it’s a race back to the start soloing as they run',
  game_variations       = NULL,
  game_teaching_points  = '**Teaching Points:** * Lets continue to use the key word “Burst” so the kids understand that they need to push through the obstruction * Hold the ball really tight into the chest while hitting the bags. This is great practice for a match situation while being tackled * Next player goes as soon as the player ahead is through the tackle bags. Keep the line moving!',
  game_image            = 'https://drive.google.com/file/d/1Jtscin0pfV0aCvCPHsDF5aXgWIlrgfq_/view?usp=sharing',
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Tackle Bags'));

UPDATE public.games SET
  game_setup            = '**Setup as Follows:** * Players are split into 2 Teams of 4 * Players on each team are assigned a number from 1 to 4 * Team 1 are attackers & Team 2 are defenders',
  game_how_to_play      = '**How to Play** * Coach calls a number (or multiple Numbers) and the kids with those numbers race out and around their cone * Attacking players must pass the ball between them before shooting * Defending players must attempt to stop the attackers',
  game_variations       = NULL,
  game_teaching_points  = '**Teaching Points** * Encourage the defenders to push right up on the attackers and not wait for them * Defenders should pick an attacker each and not all run to the player in possession of the ball * Attacker without the ball should spread out and make themselves a passing options * Player in possession should be encouraged to pass and go again to receive a return pass',
  game_image            = 'https://drive.google.com/file/d/1UgG4IqWIxeAWIL0tyY_2hw-Nn3DPfBf5/view?usp=sharing',
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Backs and Forwards'));

UPDATE public.games SET
  game_setup            = '**Setup as Follows:** * 1 Pitch with 4 Goals * 1 Goal in each corner of the pitch',
  game_how_to_play      = '**How to Play** * No goalkeepers  * The ball is kicked out by the defender if a goal is scored or the ball is kicked wide * Attacking team can score in either opposition goal',
  game_variations       = NULL,
  game_teaching_points  = '**Teaching Points** * Give each player a position – Defender or Attacker before the game starts * Encourage the kids to stay in their positions and not subconsciously follow the ball * Providing 2 goals to score into will give the game width by not allowing the kids to defend a single goal * Encourage attackers that are not in possession to be a passing option away from the ball (rather than automatically running towards the player in possession) “Spread out”',
  game_image            = 'https://drive.google.com/file/d/1xzN7rKpRKHqaBLIOxmlB0it8XAyHO1pd/view?usp=sharing',
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('4 Goal Game'));

UPDATE public.games SET
  game_setup            = '**Setup as Follows:** * Players are split into 4 sets of Pairs',
  game_how_to_play      = '**How to Play:** * 2 Pairs go at a time (the other 2 pairs wait their turn behind) * 1 Pair will be the attackers and the other pair will be the defenders  * The attacking pair need to work together to carry the ball over the opposing line without kicking the ball (handpass only) * If the attackers are successful they get a point. If the defenders dispossess them they get a point Swap attackers and defenders * Now swap in the next group of 4 players',
  game_variations       = NULL,
  game_teaching_points  = '**Teaching Points:** * Attackers should spread out and try to make themselves a passing option for the player in possession * Defenders to stick with the player they are marking and not get drawn towards the ball',
  game_image            = 'https://drive.google.com/file/d/1PYD68NnCwmn2lpQlbVcdFWg4ZT1bv9f5/view?usp=sharing',
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Tackle Drill'));

UPDATE public.games SET
  game_setup            = '**Setup as Follows:** * Small Sided Game – Hand Pass Only * No Goalkeepers',
  game_how_to_play      = '**How to Play:** * Players are split into 4 teams of 2 players * It’s a handpassing game only so to score the team must handpass through the goals * First team to 3 (or whatever score makes sense) wins * If you win on Pitch 1, then you play the winners on Pitch 2',
  game_variations       = NULL,
  game_teaching_points  = '**Teaching Points:** * Balance the teams equally by ability where possible * Focus needs to be on: * Good tackle technique * Not running towards the player in possession to receive a pass. Run into space and trust the pass will come to you * Pass and go – We need to try to encourage the girls to pass the ball and then run again to receive a return pass. Combinations of skills',
  game_image            = 'https://drive.google.com/file/d/1HU9OJdcZ_N3EdT_VNGD9dNYQc_LTxwEe/view?usp=sharing',
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Hand Pass Team Game'));

UPDATE public.games SET
  game_setup            = '**Setup as Follows:** * 3 Players start at Cone A & 3 at Cone C * We also need 1 player at each of cone B & D',
  game_how_to_play      = '**How to Play:** * Player 1 at cone A starts by hand passing to Player 4 at cone B * Player 4 stays static at this cone and hand passes back to Player 1 as they run past * Player 1 now hand passes to player 5 at cone C and joins the back of that line * Player 5 repeats and hand passes to player 8 at cone D * When player 5 receives the ball back they shoot at goal',
  game_variations       = NULL,
  game_teaching_points  = '**Teaching Points:** * Be sure to rotate players 4 and 8 away from the static cones regularly * Target to have 2 balls in play at a time * The next level for the kids is to improve their continuity play - “Give and Go” * We need them to improve their ability to have multiple involvements in a single play',
  game_image            = 'https://drive.google.com/file/d/1BW9wxJc9oFwY4B1mNxkSHB4EQItuaXL-/view?usp=sharing',
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Pass & Shoot'));

UPDATE public.games SET
  game_setup            = '**Setup as Follows:** * Mark out a Pitch with 2 Goals * Now mark out a smaller square within that',
  game_how_to_play      = '**How to Play:** * Split the group into 2 teams * Initially all players will play a handpassing game in the smaller square * After 1 minute, the coach will blow the whistle and the team that’s currently in possession must break out of the small square and attempt to score on the larger pitch * The team without the ball must defend their goal',
  game_variations       = NULL,
  game_teaching_points  = '**Teaching Points:** * This game is about reacting quickly to an offensive or defensive shape once the coach blows the whistle * Defenders need to pickup an attacker quickly with 1 defender to each attacker * The game is not about scoring. Its about making good decisions in unstructured play',
  game_image            = 'https://drive.google.com/file/d/1sxakzbZzOEiPY4vS0dvJbu3dKd3dp01p/view?usp=sharing',
  game_video            = NULL,
  game_pdf              = NULL
WHERE lower(trim(game_name)) = lower(trim('Dynamite'));

-- Total statements: 154
