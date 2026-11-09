/* CoachSmart score keeper: turns what the coach said into score entries.
 *
 * Runs on the phone with no AI and no network, so it works with no signal.
 *
 *   CSScoreVoice.parse("Point Ciarán and a wide for Ballymun", ctx) → {
 *     items: [
 *       { kind:'score', typeId, side:'us', memberId, heard:'ciaran', count:1 },
 *       { kind:'score', typeId, side:'opp', memberId:null, heard:'', count:1 },
 *     ],
 *     unknown: []             // bits we couldn't make sense of
 *   }
 *
 * An item can also carry:
 *   side: null           nobody named ("Point"): the page asks who
 *   fromId               what a score came from ("point Murrough free": the Free type's id)
 *   For a stat that isn't a score, side is whose ball it is now, so "free against
 *   Luke" = side 'opp' with memberId Luke (he gave it away).
 *   ask: [candidates]    a name we weren't sure about: the page asks "Who was X?"
 *   kind:'sub', onId, offId, onHeard, offHeard
 *
 * ctx = {
 *   types:   [{ id, name, abbr, value, source }],   source: a score can come from it (Free, 45)
 *   usName:  'Clontarf', oppName: 'Ballymun',
 *   players: [{ member_id, first_name, last_name, number }],  number may be null
 *   aliases: { 'kieran': 123 }   heard name → member_id, saved per team
 * }
 */
(function (root) {
  'use strict';

  const deaccent = s => s.normalize('NFD').replace(/[̀-ͯ]/g, '');
  const norm = s => deaccent(String(s || '').toLowerCase())
    .replace(/[’']/g, '')
    .replace(/[^a-z0-9+ ]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

  const NUMS = {
    zero: 0, one: 1, two: 2, three: 3, four: 4, for: null, five: 5, six: 6, seven: 7, eight: 8, nine: 9, ten: 10,
    eleven: 11, twelve: 12, thirteen: 13, fourteen: 14, fifteen: 15, sixteen: 16, seventeen: 17,
    eighteen: 18, nineteen: 19, twenty: 20, thirty: 30, forty: 40, fourty: 40,
  };
  // Speech engines write numbers either way; settle on digits.
  function numberWords(s) {
    s = s.replace(/\b(twenty|thirty|forty|fourty) (one|two|three|four|five|six|seven|eight|nine)\b/g,
      (m, a, b) => String(NUMS[a] + NUMS[b]));
    return s.replace(/\b(zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fourty)\b/g,
      m => String(NUMS[m]));
  }

  // Irish names the speech engine tends to spell the English way, and the
  // like. Both sides are folded to the same key before comparing.
  const SOUNDS = [
    [/^(kieran|keiran|kieron|ciaran|kiran)$/, 'ciaran'],
    [/^(shawn|shaun|sean|shane)$/, 'sean'],
    [/^(owen|eoin|eoghan)$/, 'eoin'],
    [/^(osheen|oisin|ocean)$/, 'oisin'],
    [/^(neil|neal|niall|nile)$/, 'niall'],
    [/^(keen|kian|cian|keane)$/, 'cian'],
    [/^(dara|darragh|darra)$/, 'darragh'],
    [/^(cahal|cathal|kahal)$/, 'cathal'],
    [/^(fin|finn|fionn)$/, 'fionn'],
    [/^(tige|teig|tadhg|tague)$/, 'tadhg'],
    [/^(aidan|aodhan|aiden|aedan)$/, 'aidan'],
    [/^(padraig|pauric|porick|padraic)$/, 'padraig'],
    [/^(connor|conor|conner)$/, 'conor'],
    [/^(rory|ruairi|ruari|rorie)$/, 'rory'],
    [/^(cillian|killian|kilian|cilian)$/, 'cillian'],
    [/^(shay|se)$/, 'shay'],
    [/^(senan|shenan)$/, 'senan'],
    [/^(fiachra|feeakra)$/, 'fiachra'],
    [/^(caoimhe|keeva|keva)$/, 'caoimhe'],
    [/^(aoife|eefa|eva)$/, 'aoife'],
    [/^(niamh|neve|neeve)$/, 'niamh'],
    [/^(siobhan|shivaun|chevonne)$/, 'siobhan'],
    [/^(saoirse|seersha|sorcha)$/, 'saoirse'],
    [/^(roisin|rosheen)$/, 'roisin'],
    [/^(grainne|grania)$/, 'grainne'],
    [/^(sadhbh|sive|sieve)$/, 'sadhbh'],
    [/^(clodagh|cloda)$/, 'clodagh'],
    [/^(ailbhe|alva)$/, 'ailbhe'],
  ];
  function soundKey(w) {
    for (const [re, k] of SOUNDS) if (re.test(w)) return k;
    // Rough fold for everything else: soft letters and doubled letters
    return w.replace(/ph/g, 'f').replace(/k/g, 'c').replace(/(.)\1+/g, '$1').replace(/h/g, '');
  }

  function lev(a, b) {
    if (a === b) return 0;
    const m = a.length, n = b.length;
    if (!m || !n) return m || n;
    let prev = Array.from({ length: n + 1 }, (_, j) => j);
    for (let i = 1; i <= m; i++) {
      const cur = [i];
      for (let j = 1; j <= n; j++) {
        cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
      }
      prev = cur;
    }
    return prev[n];
  }
  const sim = (a, b) => {
    if (!a || !b) return 0;
    if (a === b) return 1;
    if (soundKey(a) === soundKey(b)) return 0.95;
    return 1 - lev(soundKey(a), soundKey(b)) / Math.max(a.length, b.length);
  };

  // Words for each kind of score. Built from the team's own score types.
  function typeWords(t) {
    const n = norm(t.name), a = norm(t.abbr);
    const out = new Set([n]);
    if (a && a.length > 1 && !/^(p|g|w)$/.test(a)) out.add(a);
    if (t.value === 3 || /goal/.test(n)) ['goal', 'goals', 'gold', 'goel'].forEach(w => out.add(w));
    if (t.value === 2 || /2 ?point|two ?point/.test(n)) ['2pointer', '2 pointer', '2 pointers', 'two pointer', 'to pointer', 'too pointer', 'double'].forEach(w => out.add(w));
    if (t.value === 1 || n === 'point') ['point', 'points', 'pointe', 'over the bar'].forEach(w => out.add(w));
    if (/wide/.test(n)) ['wide', 'wides', 'white', 'wired'].forEach(w => out.add(w));
    if (/short/.test(n)) ['short', 'dropped short', 'shorts'].forEach(w => out.add(w));
    if (/^free/.test(n)) ['free', 'frees', 'free kick'].forEach(w => out.add(w));
    if (/45|forty/.test(n)) ['45', '45s', 'forty five'].forEach(w => out.add(w));
    if (/65|sixty/.test(n)) ['65', '65s', 'sixty five'].forEach(w => out.add(w));
    if (/penal/.test(n)) ['penalty', 'penalties', 'pen'].forEach(w => out.add(w));
    if (/mark/.test(n)) ['mark', 'marks'].forEach(w => out.add(w));
    if (/turn/.test(n)) ['turnover', 'turnovers', 'turn over', 'lost it', 'lost the ball', 'lost possession'].forEach(w => out.add(w));
    if (/throw ?in/.test(n)) ['throw in', 'throwin', 'throw ins', 'throw ball in'].forEach(w => out.add(w));
    // The puck-out is hurling's kick-out: either word finds whichever the team has
    if (/kick ?out|puck ?out/.test(n)) ['kickout', 'kick out', 'kickouts', 'kick outs', 'puckout', 'puck out', 'puckouts', 'puck outs'].forEach(w => out.add(w));
    return Array.from(out).map(norm).filter(Boolean).sort((x, y) => y.length - x.length);
  }

  const FILLER = new Set(('a an the for to by from scored score scores got get gets was is it its that this ' +
    'and then by our number no num nr shirt jersey player who from with of on in at').split(' '));
  const US_WORDS = new Set(['us', 'we', 'ours', 'ourselves', 'home']);
  const OPP_WORDS = new Set(['them', 'they', 'theirs', 'opposition', 'opponents', 'opponent', 'away', 'other', 'oppo', 'opp']);
  // "free against Luke", "Luke conceded a free", "Luke gave away a free"
  const AGAINST = /\b(against|conceded|concedes|concede|gave away|gives away|give away|gave|given away)\b/;

  function teamWords(name) {
    const stop = new Set(['gaa', 'gfc', 'hc', 'club', 'cumann', 'camogie', 'lgfa', 'ladies', 'football', 'hurling', 'st', 'saint', 'naomh', 'clg', 'the', 'and']);
    return norm(name).split(' ').filter(w => w.length > 2 && !stop.has(w) && !/^u\d+$/.test(w) && !/^\d+$/.test(w));
  }

  function makeMatcher(ctx) {
    const players = (ctx.players || []).map(p => ({
      id: p.member_id,
      number: p.number == null ? null : Number(p.number),
      first: norm(p.first_name).split(' ')[0] || '',
      last: norm(p.last_name).replace(/^(o|mc|mac) /, '$1'),
      full: norm(`${p.first_name} ${p.last_name}`),
    }));
    const aliases = {};
    Object.entries(ctx.aliases || {}).forEach(([k, v]) => { aliases[norm(k)] = v; });

    // Returns {id} for a sure match, {ask:[ids]} when unsure, or null.
    function byName(words) {
      const heard = words.join(' ');
      if (!heard) return null;
      if (aliases[heard] != null && players.some(p => p.id === aliases[heard])) return { id: aliases[heard] };
      const scored = players.map(p => {
        let s;
        if (words.length >= 2) {
          s = Math.max(sim(words[0], p.first) * 0.5 + sim(words.slice(1).join(''), p.last.replace(/ /g, '')) * 0.5,
            sim(heard.replace(/ /g, ''), p.full.replace(/ /g, '')));
        } else {
          const w = words[0];
          s = Math.max(sim(w, p.first), sim(w, p.last.replace(/^(o|mc|mac)/, '')) * 0.92, sim(w, p.last.replace(/ /g, '')) * 0.92);
        }
        return { p, s };
      }).filter(x => x.s >= 0.55).sort((a, b) => b.s - a.s);
      if (!scored.length) return { ask: [] };
      const top = scored[0];
      const tied = scored.filter(x => x.s >= top.s - 0.001);
      const next = scored[1];
      const clear = !next || (top.s === 1 ? next.s < 1 : top.s - next.s >= 0.1);
      if (top.s >= 0.85 && tied.length === 1 && clear) return { id: top.p.id };
      return { ask: scored.slice(0, 3).map(x => x.p.id) };
    }
    function byNumber(n) {
      const p = players.find(x => x.number === n);
      return p ? { id: p.id } : { ask: [], number: n };
    }
    return { byName, byNumber, players };
  }

  // Who is a clause about? Returns {side, memberId, ask, heard}
  function who(words, ctx, m) {
    const usW = new Set(teamWords(ctx.usName)), oppW = new Set(teamWords(ctx.oppName));
    let side = null;
    const rest = [];
    words.forEach(w => {
      if (US_WORDS.has(w) || usW.has(w)) side = side || 'us';
      else if (OPP_WORDS.has(w) || oppW.has(w)) side = side || 'opp';
      else if (!FILLER.has(w)) rest.push(w);
    });
    if (side === 'opp') return { side, memberId: null, heard: '' };
    const num = rest.find(w => /^\d+$/.test(w));
    if (num) {
      const r = m.byNumber(Number(num));
      return { side: 'us', memberId: r.id || null, ask: r.id ? null : r.ask, heard: '#' + num };
    }
    if (!rest.length) return { side, memberId: null, heard: '' };
    const r = m.byName(rest);
    if (r && r.id) return { side: 'us', memberId: r.id, heard: rest.join(' ') };
    return { side: side || 'us', memberId: null, ask: r ? r.ask : [], heard: rest.join(' ') };
  }

  function parseSub(words, ctx, m) {
    // "sub 17 for 11", "17 on for 11", "11 off 17 on", "Cillian on for Ciarán"
    const txt = words.join(' ').replace(/\b(sub|subs|substitute|substitution|change|coming|goes|going|replaces|replacing|in)\b/g, ' ')
      .replace(/\s+/g, ' ').trim();
    let onPart, offPart;
    let mm;
    if ((mm = txt.match(/^(.+?) off (?:and )?(.+?) on$/))) { offPart = mm[1]; onPart = mm[2]; }
    else if ((mm = txt.match(/^(.+?) on (?:and )?(.+?) off$/))) { onPart = mm[1]; offPart = mm[2]; }
    else if ((mm = txt.match(/^(.+?) (?:on )?for (.+?)(?: off)?$/))) { onPart = mm[1].replace(/ on$/, ''); offPart = mm[2]; }
    else return null;
    const pick = part => {
      const ws = part.split(' ').filter(w => w && !FILLER.has(w));
      const num = ws.find(w => /^\d+$/.test(w));
      if (num) return Object.assign({ heard: '#' + num }, m.byNumber(Number(num)));
      return Object.assign({ heard: ws.join(' ') }, m.byName(ws) || { ask: [] });
    };
    const on = pick(onPart), off = pick(offPart);
    return {
      kind: 'sub',
      onId: on.id || null, onHeard: on.heard, onAsk: on.id ? null : on.ask,
      offId: off.id || null, offHeard: off.heard, offAsk: off.id ? null : off.ask,
    };
  }

  function parse(text, ctx) {
    const m = makeMatcher(ctx);
    let s = numberWords(norm(text));
    s = s.replace(/\b(2|two|to|too) ?-?pointers?\b/g, '2pointer')
      .replace(/\b(off|on) and\b/g, '$1');
    // Split into separate calls: "goal Ken and a wide for them, then point Seán"
    const clauses = s.split(/\b(?:and then|then|and also|also|plus|and|next)\b|,/).map(c => c.trim()).filter(Boolean);
    const types = (ctx.types || []).map(t => ({ t, words: typeWords(t) }));
    const items = [], unknown = [];
    clauses.forEach(c => {
      let words = c.split(' ');
      if (/\b(sub|subs|substitute|substitution)\b/.test(c) || /\bon for\b/.test(c) || /\boff\b.*\bon\b|\bon\b.*\boff\b/.test(c)) {
        const sub = parseSub(words, ctx, m);
        if (sub) { items.push(sub); return; }
      }
      // Find the stat (longest phrase wins). A score named with a source
      // ("point Murrough free") is one score from a free, not two stats.
      const hit = {};
      for (const { t, words: tw } of types) {
        for (const w of tw) {
          const re = new RegExp(`(^| )${w.replace(/[+]/g, '\\+')}( |$)`);
          if (re.test(c) && (!hit[t.id] || w.length > hit[t.id].w.length)) hit[t.id] = { t, w };
        }
      }
      const hits = Object.values(hit).sort((a, b) => b.w.length - a.w.length);
      const scoreHit = hits.find(h => h.t.value > 0);
      const srcHit = scoreHit && hits.find(h => h !== scoreHit && h.t.source);
      const found = scoreHit || hits[0];
      if (!found) { unknown.push(c); return; }
      let restTxt = c.replace(new RegExp(`(^| )${found.w.replace(/[+]/g, '\\+')}( |$)`), ' ').trim();
      if (srcHit) restTxt = restTxt.replace(new RegExp(`(^| )(off |from )?(a )?${srcHit.w.replace(/[+]/g, '\\+')}( |$)`), ' ').trim();
      // Who gave it away: "free against Luke", "Luke lost it"
      const scoring = found.t.value > 0;
      let against = false;
      if (!scoring && (AGAINST.test(restTxt) || /^lost /.test(found.w))) {
        against = true;
        restTxt = restTxt.replace(new RegExp(AGAINST.source, 'g'), ' ').replace(/\s+/g, ' ').trim();
      }
      words = restTxt ? restTxt.split(' ') : [];
      // "two wides for them": a small count in front of the type
      let count = 1;
      const idx = c.split(' ').indexOf(found.w.split(' ')[0]);
      const before = c.split(' ')[idx - 1];
      if (before && /^[2-5]$/.test(before) && /s$/.test(found.w)) {
        count = Number(before);
        words.splice(words.indexOf(before), 1);
      }
      const w = who(words, ctx, m);
      // Against us (a player or our team named) = their ball; against them = ours
      let side = w.side;
      if (against) side = w.side === 'opp' ? 'us' : 'opp';
      const ourPlayer = side === 'us' || (against && w.side !== 'opp');
      items.push({
        kind: 'score', typeId: found.t.id, typeName: found.t.name, count, against,
        side, memberId: ourPlayer ? w.memberId : null, heard: ourPlayer ? w.heard : '', ask: ourPlayer ? (w.ask || null) : null,
        fromId: srcHit ? srcHit.t.id : null,
      });
    });
    return { items, unknown };
  }

  const api = { parse, norm, soundKey, sim, teamWords };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.CSScoreVoice = api;
})(typeof window !== 'undefined' ? window : globalThis);
