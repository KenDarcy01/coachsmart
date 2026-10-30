// Clontarf Senior Football · off-season diary: the plan itself.
// Block 1 (weeks 1-4, 12 Oct to 8 Nov 2026) from David Hare's player pack.
// Each dose is written once per week: [week 1, week 2, week 3, week 4].
window.PLAN = (function () {
  const FORM = 'https://forms.gle/V6LoEFhFLUcxjSGK7';
  const WARMUP_VIDEO = 'https://www.youtube.com/watch?v=og2z7tlNuCk';
  const yt = id => 'https://www.youtube.com/watch?v=' + id;
  const sets = (s, r) => s.map((n, i) => `${n} sets x ${r[i]}`);

  const BLOCKS = [
    { n: 1, name: 'Block 1', from: '2026-10-12', to: '2026-11-08',
      aim: 'Build the lifts, keep the running consistent and send one check-in each Sunday. Week 4 is lighter on purpose.' }
  ];
  const VIEW_START = BLOCKS[0].from;
  const VIEW_END = BLOCKS[BLOCKS.length - 1].to;

  const WEIGHTS = 'Leave about two good reps in the tank. Week 2: add the smallest increase only if every Week 1 set was clean. Week 3: pick a load for the lower reps that still leaves two in the tank. Week 4: about 10% less than your last good load, rounded down.';

  // Move + Activate before every gym session.
  const MOVE = [
    { n: 'Adductor rock-back', d: '6 each side', v: yt('1pqZI2t8XHo') },
    { n: 'Upper-back rotation', d: '6 each side', v: yt('58thdmAV_A0') }
  ];
  const ACT = {
    bridge: { n: 'Glute bridge', d: '8 reps', v: yt('uZyLZDxcD38') },
    row: { n: 'Band row', d: '10 reps', v: yt('ADeGAWCDjhQ') },
    scap: { n: 'Scapular press-up', d: '8 reps', v: 'https://www.catalystathletics.com/exercise/919/Scap-Push-Up/' },
    bug: { n: 'Dead bug', d: '5 each side', v: yt('GbSC02oU3To') }
  };

  const STD = { s: [3, 3, 4, 2], r8: ['8 reps', '8 reps', '6 reps', '8 reps'] };
  const ACC = [3, 3, 3, 2];

  const GYM = {
    1: { name: 'Gym 1 · Lower body + bench', track: { id: 'bench', n: 'Bench' }, first: 'Pitch warm-up and Monday speed first, then gym.',
      activate: [ACT.bridge, ACT.row, ACT.scap],
      power: { n: 'Countermovement jump', d: 'Maximum height; reset every jump.', dose: sets(ACC, Array(4).fill('3 jumps')), v: yt('MshBlueDsDk') },
      build: 'Split squat: bodyweight x 5 each leg, then light DBs x 5. Bench: empty bar x 8, then light x 5.',
      b: [{ n: 'Rear-foot-elevated split squat', d: 'Each leg; rear foot on bench.', dose: sets(STD.s, STD.r8), v: yt('VgPpv4Eq9tE') },
        { n: 'Barbell bench press', d: 'Stable shoulders; controlled lower.', dose: sets(STD.s, STD.r8), v: yt('GlPKtOUvZqw') }],
      c: [{ n: 'DB Romanian deadlift', d: 'Hips back; weights close.', dose: sets(ACC, Array(4).fill('8 reps')), v: yt('hQgFixeXdZo') },
        { n: 'Single-arm DB row', d: 'Each arm; stay square.', dose: sets(ACC, Array(4).fill('8 reps')), v: yt('IOy2k0Cb6Vo') }],
      d: { n: 'Slider hamstring curl', d: 'Two legs; hips up; control the slide.', dose: Array(4).fill('2 sets x 8 reps'), v: yt('XnO0QljCS_w') } },
    2: { name: 'Gym 2 · Hinge + pull', track: { id: 'trapbar', n: 'Trap bar' }, first: 'Move and Activate, then power, lighter sets, work sets.',
      activate: [ACT.bridge, ACT.row, ACT.bug],
      power: { n: 'Rotational med-ball scoop throw', d: 'Each side; fast throws into a safe wall.', dose: sets(ACC, Array(4).fill('4 throws')), v: yt('CXu7YeWTptE') },
      build: 'Trap bar: light x 5, then moderate x 3. Chin-up: 3 easy reps, extra band if needed.',
      b: [{ n: 'Trap-bar deadlift', d: 'Brace; push the floor away.', dose: sets(STD.s, ['6 reps', '6 reps', '5 reps', '6 reps']), v: yt('Vu4oXIRzx7w') },
        { n: 'Chin-up / band-assisted chin-up', d: 'No swing; note the band used.', dose: sets(STD.s, Array(4).fill('5 reps')), v: yt('3d9Lml4UBgg') }],
      c: [{ n: 'DB reverse lunge', d: 'Each leg; step back softly.', dose: sets(ACC, Array(4).fill('8 reps')), v: yt('Ix9QZ3Pnneo') },
        { n: 'Half-kneeling DB press', d: 'Each arm; no leaning.', dose: sets(ACC, Array(4).fill('8 reps')), v: yt('d3CRIDSCOhw') }],
      d: { n: 'Band Pallof press', d: 'Each side; resist rotation.', dose: Array(4).fill('2 sets x 8 reps'), v: yt('biS_F5SE73E') } },
    3: { name: 'Gym 3 · Squat + whole body', track: { id: 'frontsquat', n: 'Front squat' }, first: 'Week 1: gym only. Weeks 2 to 4: pitch warm-up and speed first.',
      activate: [ACT.bridge, ACT.row, ACT.bug],
      power: { n: 'Hurdle hops, 4 low hurdles', d: 'Quick, controlled rebounds.', dose: sets(ACC, Array(4).fill('4 hops')), v: yt('LYyCVstEHKE') },
      build: 'Front squat: empty bar x 5, then light x 5. Incline DB bench: light x 8, then moderate x 5.',
      b: [{ n: 'Front squat', d: 'Brace; whole foot planted.', dose: sets(STD.s, STD.r8), v: yt('lNJ3DyibYZQ') },
        { n: 'Incline DB bench press', d: 'Control the lower; press firmly.', dose: sets(STD.s, STD.r8), v: yt('IP4oeKh1Sd4') }],
      c: [{ n: 'Supported single-leg DB RDL', d: 'Each leg; hips level.', dose: sets(ACC, Array(4).fill('8 reps')), v: 'https://vimeo.com/703009907' },
        { n: 'Chest-supported DB row', d: 'Chest on pad; no swinging.', dose: sets(ACC, Array(4).fill('10 reps')), v: yt('5YZQTN80NT8') }],
      d: { n: 'Side plank', d: 'Each side; breathe normally.', dose: Array(4).fill('2 sets x 25 sec'), v: yt('nLtAqX7wW5Q') } }
  };

  // A gym session for one week, in the same shape the diary draws.
  function gym(n, wk) {
    const g = GYM[n], w = wk - 1;
    const ex = x => ({ n: x.n, d: `${x.dose[w]} · ${x.d}`, v: x.v });
    return {
      name: g.name, sub: g.first, mins: 60, track: g.track,
      blocks: [
        { title: 'Prepare', note: 'Move and Activate once.', items: [...MOVE, ...g.activate] },
        { title: 'A · Power', note: 'Complete all sets before B. Rest 2 min between sets.', items: [ex(g.power)] },
        { title: 'B · Pair 1', note: `Build up first (not work sets). ${g.build} Then B1, rest 90 sec, B2, rest 90 sec.`, items: g.b.map(ex) },
        { title: 'C · Pair 2', note: 'C1, rest 75 sec, C2, rest 75 sec. Both sides before resting.', items: g.c.map(ex) },
        { title: 'D · Finish', note: 'Rest 60 sec between sets.', items: [ex(g.d)] }
      ]
    };
  }

  const ACCEL = ['4 x 10 m + 2 x 20 m', '4 x 10 m + 3 x 20 m', '4 x 10 m + 3 x 20 m', '3 x 10 m + 2 x 20 m'];
  const FAST = [null, '3 runs: 20 m build-up + 10 m fast', '3 runs: 20 m build-up + 15 m fast', '2 runs: 20 m build-up + 10 m fast'];
  function speed(day, wk) {
    const mon = day === 'mon';
    const dose = mon ? ACCEL[wk - 1] : FAST[wk - 1];
    if (!dose) return null;
    return {
      name: mon ? 'Acceleration' : 'Build-up + fast zone', sub: dose, mins: 20,
      blocks: [
        { title: 'Warm up', note: 'Clontarf pitch warm-up: movement, mobility and skipping, then three progressive 20 m runs.', items: [{ n: 'Pitch warm-up', d: 'Flat, safe straight with room to slow down.', v: WARMUP_VIDEO }] },
        { title: mon ? 'Acceleration' : 'Build-up + fast zone',
          note: mon ? 'Rest 90 sec after every 10 m, 2 min after every 20 m. Walk back. Accelerate sharply without straining.'
            : 'Build speed gradually, fast and relaxed through the zone, ease down over 20 m. Rest 3 min. Stop if your stride changes.',
          items: [{ n: dose, d: 'Fast, controlled efforts with full recovery. Not conditioning.', v: mon && wk === 1 ? 'https://youtu.be/vY00Bj7NqQ8' : null }] }
      ]
    };
  }

  const EASY = [20, 25, 30, 20];
  const INTERVALS = [5, 6, 8, 5];
  function run(day, wk) {
    if (day === 'tue') {
      const m = EASY[wk - 1];
      return { name: 'Easy run', sub: `${m} minutes at chat pace`, mins: m,
        blocks: [{ title: 'Easy run', note: 'Flat, safe route. Start gently and keep the whole run comfortable.', items: [{ n: `${m} minutes`, d: 'A pace where you can speak in full sentences.', v: 'https://youtu.be/r2PBxwhg9nE' }] }] };
    }
    const n = INTERVALS[wk - 1];
    return { name: '30-second intervals', sub: `2 sets of ${n} efforts`, mins: 25 + n * 2,
      blocks: [
        { title: 'Warm up', items: [{ n: 'Easy jog, 8 minutes', d: 'Then three progressive 20 m runs.' }] },
        { title: 'Intervals', note: 'Each effort: 30 sec strong (7 to 8 out of 10, not a sprint) + 30 sec easy jog. End the set if your stride changes or pace falls away.',
          items: [{ n: `Set 1: ${n} efforts`, d: '30 sec strong + 30 sec easy', v: 'https://youtu.be/TacBZZqDpDY' }, { n: 'Walk 3 minutes', d: 'Full recovery' }, { n: `Set 2: ${n} efforts`, d: '30 sec strong + 30 sec easy' }] },
        { title: 'Finish', items: [{ n: '5 minutes easy', d: 'Wattbike or Airdyne instead only if agreed with David.' }] }
      ] };
  }

  // The week: 1 = Monday ... 7 = Sunday.
  function day(dow, wk) {
    switch (dow) {
      case 1: return [{ t: 'First', kind: 'speed', s: speed('mon', wk) }, { t: 'Then', kind: 'gym', s: gym(1, wk) }];
      case 2: return [{ t: 'Any time', kind: 'run', s: run('tue', wk) }];
      case 3: return [{ t: 'Any time', kind: 'gym', s: gym(2, wk) }];
      case 4: return [{ t: 'Any time', kind: 'rest', title: 'Off', detail: 'Walk or move if you like.' }];
      case 5: return [{ t: 'First', kind: 'speed', s: speed('fri', wk) }, { t: 'Then', kind: 'gym', s: gym(3, wk) }].filter(x => x.s).map((x, i, a) => a.length === 1 ? { ...x, t: 'Any time' } : x);
      case 6: return [{ t: 'Any time', kind: 'run', s: run('sat', wk) }];
      default: return [{ t: 'Any time', kind: 'rest', title: 'Off', detail: 'Rest. Send your weekly check-in.' }];
    }
  }

  return { FORM, BLOCKS, VIEW_START, VIEW_END, WEIGHTS, day };
})();
