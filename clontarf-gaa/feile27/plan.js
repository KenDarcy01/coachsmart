// Clontarf Girls 2012 · Féile 2027 diary: the plan itself.
// Team sessions and matches live in TEAM below for now. Later they come from
// CoachSmart events (see loadTeamEvents in diary.js) and everything else on a
// day is filled in around them.
window.FEILE = (function () {
  const TEAM = {
    // Weekly pattern: 1 = Monday ... 7 = Sunday.
    weekly: [
      { dow: 1, start: '18:30', end: '19:45', kind: 'team', title: 'Team training: football', detail: 'Formal training with the coaches' },
      { dow: 2, start: '18:00', end: '19:00', kind: 'snc', title: 'Group S&C', detail: 'Strength and conditioning with the group' },
      { dow: 3, start: '18:30', end: '19:45', kind: 'team', title: 'Team training: camogie', detail: 'Formal training with the coaches' }
    ],
    // No team sessions on these dates (Christmas break).
    off: [['2026-12-21', '2027-01-03']],
    // Sunday fixtures (times to confirm) and other one-off team days.
    matches: [
      { date: '2026-11-29', start: '11:00', title: 'Match' },
      { date: '2026-12-20', start: '11:00', title: 'Match' },
      { date: '2027-02-07', start: '11:00', title: 'Match' },
      { date: '2027-02-21', start: '11:00', title: 'Match' },
      { date: '2027-02-28', start: '11:00', title: 'Match' },
      { date: '2027-03-07', start: '11:00', title: 'Match' },
      { date: '2027-03-14', start: '10:00', title: 'Féile-style home blitz', detail: 'Several short games, like Féile day' },
      { date: '2027-03-21', start: '11:00', title: 'Match' },
      { date: '2027-04-04', start: '11:00', title: 'Match' },
      { date: '2027-04-11', start: '11:00', title: 'Match' }
    ],
    camps: [
      { from: '2027-03-30', to: '2027-04-01', start: '10:00', end: '13:00', title: 'Easter camp', detail: 'Mornings with the coaches' }
    ]
  };

  const FEILE_START = '2027-04-24';
  const FEILE_END = '2027-04-25';
  const PLAN_START = '2026-11-02';
  const VIEW_START = '2026-10-26';

  const PHASES = [
    { key: 'foundation', name: 'Foundation', from: '2026-10-26', to: '2026-12-13', aim: 'Learn every exercise properly and make wall ball a habit.' },
    { key: 'christmas', name: 'Christmas block', from: '2026-12-14', to: '2027-01-10', aim: 'Keep it ticking over: short sessions, family time, 24 to 27 Dec fully off.' },
    { key: 'build', name: 'Build', from: '2027-01-11', to: '2027-02-28', aim: 'More rounds, harder intervals, skills from longer range.' },
    { key: 'sharp', name: 'Competition prep', from: '2027-03-01', to: '2027-04-04', aim: 'Match-shaped running and skills when tired.' },
    { key: 'taper', name: 'Peak and taper', from: '2027-04-05', to: '2027-04-23', aim: 'Less work, same speed. Arrive fresh.' },
    { key: 'feile', name: 'Féile', from: FEILE_START, to: FEILE_END, aim: 'Enjoy it. Everything is done.' }
  ];

  const HOLIDAYS = [
    { from: '2026-10-26', to: '2026-10-30', name: 'Halloween midterm' },
    { from: '2026-12-21', to: '2027-01-05', name: 'Christmas holidays' },
    { from: '2027-02-15', to: '2027-02-19', name: 'February midterm' },
    { from: '2027-03-22', to: '2027-04-02', name: 'Easter holidays' }
  ];

  const BENCHMARKS = ['2026-11-07', '2027-01-02', '2027-02-26', '2027-04-02'];

  // While team sessions are off over Christmas, a fixed day-by-day plan
  // replaces the weekly pattern.
  const CHRISTMAS = {
    '2026-12-21': 'B', '2026-12-22': 'M', '2026-12-23': 'A',
    '2026-12-24': 'off', '2026-12-25': 'off', '2026-12-26': 'off', '2026-12-27': 'off',
    '2026-12-28': 'C', '2026-12-29': 'M', '2026-12-30': 'A',
    '2026-12-31': 'B', '2027-01-01': 'rest', '2027-01-02': 'test', '2027-01-03': 'C'
  };

  const TOUCHES_12 = {
    start: '2026-12-23',
    days: [
      '50 hand passes off the wall, 25 each fist',
      '30 ground strikes off the wall in a row',
      '20 high catches, landing on two feet',
      '100 sliotar taps on the hurl, both faces of the bas',
      '10 solo runs of 10 m, 5 each foot',
      '50 pull and catch off the wall',
      '10 toe pick-ups on the run each foot',
      '20 first-time overhead pulls',
      '10 kicks at the chalk square from 12 m, each foot',
      '10 jab lifts and 10 roll lifts on the move',
      '10 points from the hand at the chalk target',
      'Wall 21 against a family member'
    ]
  };

  const WARMUP = {
    title: 'Warm-up', mins: 7, items: [
      { n: 'Skip or jog on the spot', d: '2 minutes' },
      { n: 'Leg swings', d: '10 each way, each leg' },
      { n: 'Walking lunge with a twist', d: '8 each leg' },
      { n: 'Inchworms', d: '5' },
      { n: 'Glute bridges and clams', d: '10 bridges, 10 clams each side' },
      { n: 'Pogo hops then 3 quick 5 m sprints', d: '20 hops, sprint and turn' }
    ]
  };

  const COOLDOWN = {
    title: 'Cool-down', mins: 5, items: [
      { n: 'Hip flexor stretch, half kneeling', d: '45 s each side' },
      { n: 'Hamstring stretch', d: '45 s each side' },
      { n: 'Calf stretch on a step', d: '45 s each side' }
    ]
  };

  const MOBILITY = {
    title: 'Mobility', mins: 10, items: [
      { n: "World's greatest stretch", d: '5 each side' },
      { n: 'Hip flexor stretch, half kneeling', d: '45 s each side' },
      { n: 'Hamstring stretch', d: '45 s each side' },
      { n: 'Thoracic rotations on all fours', d: '8 each side, helps striking' },
      { n: 'Calf stretch on a step', d: '45 s each side' },
      { n: 'Wrist and forearm circles', d: '30 s, helps hurl grip' }
    ]
  };

  function strength(p) {
    const build = p === 'build', sharp = p === 'sharp' || p === 'taper';
    return {
      title: 'Strength circuit', mins: 14,
      note: build || sharp ? '4 rounds, 40 s work and 20 s rest' : '3 rounds, 40 s work and 20 s rest',
      items: [
        { n: 'Squat', d: sharp ? 'Jump squats, soft landings' : build ? 'Slow: 3 seconds down' : 'Bodyweight squat to a chair' },
        { n: 'Split squat', d: build || sharp ? 'Rear foot on the bottom stair' : 'Hands on hips' },
        { n: 'Push-up', d: build || sharp ? 'Floor push-ups' : 'Hands on a step or table' },
        { n: 'Glute bridge', d: build || sharp ? 'One leg, 2 s hold at the top' : 'Both legs' },
        { n: 'Plank', d: build || sharp ? 'With shoulder taps' : 'Forearm plank, 30 s' },
        { n: 'Side plank', d: build || sharp ? 'Full side plank, add a leg lift' : 'Knees down, 20 s each side' },
        { n: 'Hamstrings', d: build || sharp ? 'Assisted Nordic, someone holds your ankles, 4 to 6' : 'Bridge walk-outs, 6' },
        { n: 'Single-leg balance', d: sharp ? 'Catch a ball while balancing' : build ? '30 s eyes closed, each leg' : '30 s each leg' }
      ]
    };
  }

  function speed(p) {
    if (p === 'taper') return { title: 'Speed, short and sharp', mins: 8, note: 'Full rest between reps. Quality only.', items: [
      { n: '10 m sprints', d: '4 reps, walk back' },
      { n: 'Reactive sprint', d: '3 reps, someone points left or right' }
    ] };
    return { title: 'Speed and agility', mins: 12, note: 'Walk back between reps. Speed only counts when fresh.', items: [
      { n: '10 m sprints, different starts', d: '6 reps: standing, lying, side-on' },
      { n: '5-10-5 shuttle', d: '4 reps, cones 5 m apart' },
      { n: 'Footwork on a ladder or chalk line', d: '6 patterns x 2' },
      { n: 'Reactive sprint', d: '3 reps, someone points left or right' },
      { n: 'Jump and stick landing', d: '3 x 5, knees over toes, soft and quiet' }
    ] };
  }

  // Aerobic base: two runs a week of their own, built up a little each week.
  // Thursday is the shorter run, Saturday the longer one. Easy means chat
  // pace: high-level dual players get their hard running at team sessions,
  // so the base comes from easy minutes, not from more sprints.
  const EASY = 'Chat pace: you can talk in full sentences. Effort 5 out of 10. Walk breaks are fine';
  function run(day, p, week) {
    const w = Math.max(0, week);
    const pick = list => list.at(Math.min(w, list.length - 1));
    const plan = {
      thu: {
        foundation: () => ({ mins: pick([15, 15, 18, 18, 20, 20, 20]), main: { n: 'Easy run', d: EASY } }),
        christmas: () => ({ mins: 20, main: { n: 'Easy run', d: EASY } }),
        build: () => ({ mins: 22, main: { n: 'Fartlek run', d: '8 min easy, then 6 x 1 min steady (effort 7) with 1 min easy, then 2 min easy' } }),
        sharp: () => ({ mins: 24, main: { n: 'Match-shaped running', d: '8 min easy, then 2 x 8 min of 15 s sprint, 15 s jog, 30 s walk. 3 min easy between' } }),
        taper: () => ({ mins: 15, main: { n: 'Easy run', d: 'Relaxed and smooth. Finish feeling fresh' } })
      },
      sat: {
        foundation: () => ({ mins: pick([20, 22, 24, 26, 28, 30, 30]), main: { n: 'Long easy run', d: EASY } }),
        christmas: () => ({ mins: 30, main: { n: 'Long easy run', d: 'Chat pace. A park loop, a parkrun or a run with family' } }),
        build: () => ({ mins: pick([30, 32, 35, 35, 38, 40, 30]), main: { n: 'Long easy run', d: EASY } }),
        sharp: () => ({ mins: 30, main: { n: 'Progression run', d: '20 min easy, then 10 min steady (effort 7). Still in control at the end' } }),
        taper: () => ({ mins: pick([20, 15]), main: { n: 'Easy run', d: 'Relaxed. Shorter than usual on purpose' } })
      }
    }[day];
    const r = (plan[p] || plan.foundation)();
    const items = [
      { n: 'Brisk walk and leg swings', d: '3 minutes to loosen up' },
      { n: `${r.main.n}, ${r.mins} minutes`, d: r.main.d },
      { n: '4 strides of 60 m', d: 'Build to about 80% speed, walk back' },
      { n: 'Calf and hamstring stretch', d: '45 s each side' }
    ];
    const note = week >= 0 && p === 'foundation' && day === 'sat' && w > 0 && w < 6 ? `Week ${w + 1}: 2 minutes longer than last week.` : 'Grass or a park path where you can, in proper runners. Sore shins, knees or heels: stop and tell a coach.';
    return { code: 'R', name: r.main.n, sub: `${r.mins} min${r.main.n.startsWith('Long') || r.main.n === 'Easy run' ? ' at chat pace' : ''}`, mins: r.mins + 6,
      blocks: [{ title: 'Run', mins: r.mins + 6, note, items }] };
  }

  function football(p) {
    const far = p === 'build' || p === 'sharp';
    return { title: 'Football wall ball', mins: 13, note: 'Weak side gets double reps. Log your best score.', items: [
      { n: 'Hand-pass wall', d: '3 m out, alternate fists. Target 50 in a row each hand' },
      { n: 'High catch', d: 'Kick high off the wall, jump, catch above the head. 20 clean' },
      { n: 'Kick and catch', d: far ? 'From 15 m, 10 each foot' : 'From 8 to 10 m, 10 each foot' },
      { n: 'Solo run', d: 'Slalom 4 cones and back. 5 runs each foot' },
      { n: 'Toe pick-up on the run', d: '10 each foot' },
      { n: 'Shoot at the chalk square', d: far ? 'From 15 m: hits out of 10 each foot' : 'From 12 m: hits out of 10 each foot' }
    ] };
  }

  function camogie(p) {
    const far = p === 'build' || p === 'sharp';
    return { title: 'Camogie wall ball', mins: 13, note: 'Helmet on. Left and right grip every drill.', items: [
      { n: 'Ground strike to wall', d: 'First time back. Target 30 in a row, both sides' },
      { n: 'Pull and catch', d: 'Strike from the hand, catch. Target 50 in a row' },
      { n: 'First-time overhead pull', d: '20 in a row' },
      { n: 'Jab lift and roll lift', d: '10 each side on the move' },
      { n: 'Solo, sliotar on the hurl', d: 'Carry 20 m, bounce to hand after 4 steps. 5 runs' },
      { n: 'Point shooting', d: far ? 'From 20 m: hits out of 10, both sides' : 'From 15 m: hits out of 10, both sides' }
    ] };
  }

  const WALL21 = { title: 'Wall 21', mins: 10, note: 'Alone or with a sibling.', items: [
    { n: 'Alternate a football kick and a camogie strike at the chalk target', d: 'A hit scores 1, a clean catch after scores 1 more. First to 21' }
  ] };

  const TEST = { title: 'Benchmark test', mins: 25, note: 'Write your scores on the card on the fridge. Only beat your own last score.', items: [
    { n: 'Plank hold', d: 'Max time, cap 2 minutes' },
    { n: 'Standing broad jump', d: 'Best of 3, in cm' },
    { n: '5-10-5 shuttle', d: 'Best of 2, in seconds' },
    { n: 'Football wall ball', d: 'Hand passes in a row in 60 s' },
    { n: 'Camogie wall ball', d: 'Pull and catch in a row in 60 s' }
  ] };

  const MATCHPREP = { title: 'Match prep touches', mins: 15, note: 'Light. Leave the legs fresh for tomorrow.', items: [
    { n: 'Hand passes and high catches off the wall', d: '5 minutes' },
    { n: 'Ground strikes and pull and catch', d: '5 minutes' },
    { n: 'Free-kick and point routine', d: '5 each, full routine every time' }
  ] };

  function session(code, p) {
    const s = {
      A: { name: 'Home session A', sub: 'Strength + football', blocks: [WARMUP, strength(p), football(p), COOLDOWN] },
      B: { name: 'Home session B', sub: 'Speed + camogie', blocks: [WARMUP, speed(p), camogie(p), COOLDOWN] },
      C: { name: 'Home session C', sub: 'Dual skills after the run', blocks: [WALL21, COOLDOWN] },
      M: { name: 'Mobility', sub: '10 minutes, easy', blocks: [MOBILITY] },
      T: { name: 'Taper sharpener', sub: 'Short, fast, fresh', blocks: [WARMUP, speed('taper'), MATCHPREP] },
      P: { name: 'Match prep', sub: 'Light touches', blocks: [MATCHPREP] },
      test: { name: 'Benchmark test', sub: 'See how far you have come', blocks: [WARMUP, TEST] }
    }[code];
    if (!s) return null;
    s.code = code;
    s.mins = s.blocks.reduce((t, b) => t + b.mins, 0);
    return s;
  }

  const HABITS = [
    { id: 'touch', n: '100 touches', d: 'Sliotar taps, bounces and roll-lifts, both hands' },
    { id: 'water', n: 'Water bottle, 1.5 to 2 L', d: 'Bring it to school and refill' },
    { id: 'stretch', n: '5-minute stretch before bed', d: 'Hips, hamstrings, calves' },
    { id: 'sleep', n: 'Lights out by 22:00', d: '9 hours sleep helps you grow and recover' }
  ];

  // Eating well: principles, not menus. No dieting language.
  const EATING = [
    { t: 'Eat regularly', d: 'Three meals and a couple of snacks. Breakfast matters most on school days.' },
    { t: 'Fuel before you play', d: 'Have a meal or a snack in the few hours before training or a match.' },
    { t: 'Refuel after', d: 'Eat something within about an hour of finishing. A normal dinner counts.' },
    { t: 'Build a mixed plate', d: 'Some carbs for energy, some protein to repair, and plenty of colour from fruit and veg.' },
    { t: 'Drink water', d: 'Through the day, and bring a bottle to every session. Energy drinks are not for under-16s.' },
    { t: 'Iron and calcium', d: 'Girls your age need lots of both: meat, eggs, beans and greens for iron; milk, yogurt and cheese for calcium.' },
    { t: 'More, not less', d: 'Growing athletes need more food, not less. No diets or cutting out foods. Worried about food or your body? Talk to a parent or coach.' }
  ];

  const FOOD_TIPS = [
    'Big training week? Your body needs more fuel, so listen to your hunger.',
    'Have a water bottle with you all day today.',
    'Try to get a colourful plate at dinner.',
    'A snack after school makes evening training feel easier.',
    'Some protein at breakfast keeps you going until lunch.',
    'Eat something within an hour of finishing training.',
    'Sleep and food are when you get fitter. Training is just the start.',
    'Fruit is the easiest snack there is. Grab one on the way out.'
  ];

  return { TEAM, FEILE_START, FEILE_END, PLAN_START, VIEW_START, PHASES, HOLIDAYS, BENCHMARKS, CHRISTMAS, TOUCHES_12, HABITS, EATING, FOOD_TIPS, session, run };
})();
