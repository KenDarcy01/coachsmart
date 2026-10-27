// Clontarf Girls 2012 · Féile 2027 diary: works out each day from the team
// week and the plan, then draws it.
(function () {
  const F = window.FEILE;
  const DAY = 864e5;
  const DOW = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  const MON = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  // ---- dates (all ISO yyyy-mm-dd, handled in UTC so days never drift) ----
  const parse = iso => Date.UTC(+iso.slice(0, 4), +iso.slice(5, 7) - 1, +iso.slice(8, 10));
  const iso = t => new Date(t).toISOString().slice(0, 10);
  const add = (d, n) => iso(parse(d) + n * DAY);
  const dow = d => (new Date(parse(d)).getUTCDay() + 6) % 7 + 1; // 1 = Mon
  const within = (d, from, to) => d >= from && d <= to;
  const todayIso = () => { const n = new Date(); return iso(Date.UTC(n.getFullYear(), n.getMonth(), n.getDate())); };
  const clamp = d => d < F.VIEW_START ? F.VIEW_START : d > F.FEILE_END ? F.FEILE_END : d;
  const mins = t => +t.slice(0, 2) * 60 + +t.slice(3, 5);
  const hhmm = m => String(Math.floor(m / 60)).padStart(2, '0') + ':' + String(m % 60).padStart(2, '0');
  const longDate = d => `${DOW[dow(d) - 1]} ${+d.slice(8)} ${MON[+d.slice(5, 7) - 1]}`;

  // ---- team events: from the plan for now, from CoachSmart later ----
  // Later this reads the team's events from CoachSmart (training, S&C,
  // matches) and returns the same shape: [{ date, start, end, kind, title, detail }].
  function loadTeamEvents(d) {
    const t = F.TEAM, out = [];
    const off = t.off.some(([a, b]) => within(d, a, b));
    if (!off) t.weekly.filter(w => w.dow === dow(d)).forEach(w => out.push({ date: d, ...w }));
    t.matches.filter(m => m.date === d).forEach(m => out.push({ date: d, kind: 'match', end: hhmm(mins(m.start) + 60), detail: 'Check CoachSmart for the venue and squad', ...m }));
    (t.camps || []).filter(c => within(d, c.from, c.to)).forEach(c => out.push({ date: d, kind: 'team', ...c }));
    return out.sort((a, b) => mins(a.start) - mins(b.start));
  }

  const phaseOf = d => F.PHASES.find(p => within(d, p.from, p.to)) || F.PHASES[0];
  const holidayOf = d => F.HOLIDAYS.find(h => within(d, h.from, h.to));

  // ---- what to do at home on a day ----
  function homeFor(d, team) {
    const p = phaseOf(d).key;
    const toFeile = (parse(F.FEILE_START) - parse(d)) / DAY;
    if (p === 'feile') return 'feile';
    if (toFeile <= 2) return 'rest';
    if (F.CHRISTMAS[d]) return F.CHRISTMAS[d];
    if (F.BENCHMARKS.includes(d)) return 'test';
    if (team.length) return null;
    const matchTomorrow = loadTeamEvents(add(d, 1)).some(e => e.kind === 'match');
    switch (dow(d)) {
      case 4: return 'F';
      case 5: return p === 'taper' ? 'T' : 'B';
      case 6: return matchTomorrow ? 'P' : p === 'taper' ? 'T' : 'C';
      default: return 'rest';
    }
  }

  function sessionFor(code, p) {
    if (code === 'F') {
      const a = F.session('A', p);
      return { code: 'F', name: 'Skills night', sub: 'Football wall ball + mobility', blocks: [a.blocks[2], F.session('M', p).blocks[0]], mins: 23 };
    }
    return F.session(code, p);
  }

  // ---- the day's timeline ----
  function planDay(d) {
    const phase = phaseOf(d), hol = holidayOf(d), team = loadTeamEvents(d);
    const code = homeFor(d, team);
    const weekend = dow(d) >= 6 || !!hol;
    const sess = code && code !== 'rest' && code !== 'off' ? sessionFor(code, phase.key) : null;
    const items = [];
    const food = (t, title, detail) => items.push({ t, kind: 'food', title, detail });

    if (code === 'feile') {
      food('07:30', 'Breakfast, 3 hours before the first game', 'Porridge or cereal with milk, toast, a banana, water');
      items.push({ t: '09:30', kind: 'match', title: 'Féile games', detail: 'Warm up with the team. Be proud of all the work you did.' });
      food('Between games', 'Small and often', 'Water every break. Banana, rice cakes, jam sandwich, jelly sweets if games are close together');
      food('After the last game', 'Recover', 'Milk or yogurt drink and a proper meal within the hour');
      return { d, phase, hol, team, code, items, tags: [{ k: 'match', t: 'Féile' }] };
    }

    const match = team.find(e => e.kind === 'match');
    const evening = team.find(e => e.kind !== 'match' && mins(e.start) >= 16 * 60);
    const morning = team.find(e => e.kind !== 'match' && mins(e.start) < 13 * 60);

    if (match) {
      const s = mins(match.start);
      food(hhmm(s - 180), 'Breakfast, 3 hours before', 'Porridge, cereal or toast with eggs. Water or milk');
      food(hhmm(s - 75), 'Small snack', 'Banana or a slice of toast with honey. Sip water');
      items.push({ t: match.start, end: match.end, kind: 'match', title: match.title, detail: match.detail });
      food(hhmm(s + 90), 'Recovery', 'Milk or yogurt drink plus a sandwich within an hour, then a good lunch');
    } else if (morning) {
      food('08:00', 'Breakfast', 'Porridge or cereal with milk and fruit');
      items.push({ t: morning.start, end: morning.end, kind: morning.kind, title: morning.title, detail: morning.detail });
      food(hhmm(mins(morning.end) + 30), 'Lunch', 'Carbs plus protein: pasta, a wrap or a toastie with milk');
    } else {
      food(weekend ? '09:00' : '07:30', 'Breakfast', weekend ? 'Eggs on toast, porridge or pancakes with fruit' : 'Porridge or cereal with milk. Never skip it');
      if (!weekend) food('10:45', 'Break-time snack', 'Fruit, yogurt or a cereal bar');
      if (!(weekend && sess && !evening)) food('13:00', 'Lunch', 'Sandwich or wrap with chicken, tuna, egg or cheese, plus fruit');
    }

    if (evening) {
      const s = mins(evening.start), e = mins(evening.end);
      food(hhmm(s - 180), 'Main fuel, 3 hours before', 'A proper meal or big snack: pasta, a wrap, beans on toast');
      food(hhmm(s - 60), 'Top-up snack', 'Banana, toast with honey or a scone. Fill your water bottle');
      items.push({ t: evening.start, end: evening.end, kind: evening.kind, title: evening.title, detail: evening.detail });
      food(hhmm(e + 30), 'Recovery dinner', 'Within an hour: protein plus carbs, e.g. chicken, rice and veg, then milk or yogurt');
    } else if (sess) {
      const at = match ? mins(match.start) + 240 : weekend ? 11 * 60 : 17 * 60;
      if (!weekend && !match) food('16:00', 'After-school snack', 'Toast, yogurt and fruit, about an hour before the session');
      if (weekend && !match) food('10:15', 'Small snack', 'Fruit or a yogurt');
      items.push({ t: hhmm(at), end: hhmm(at + sess.mins), kind: 'home', title: sess.name, detail: sess.sub, session: sess });
      if (weekend && !match) food('13:00', 'Lunch', 'Carbs plus protein: pasta, a wrap or a toastie');
      food('18:30', 'Dinner', 'Protein, carbs and veg. A glass of milk');
    } else {
      if (!weekend && !match) food('16:00', 'After-school snack', 'Fruit and a yogurt or toast');
      food('18:30', 'Dinner', 'Protein, carbs and two colours of veg');
    }

    if (code === 'rest' || code === 'off') {
      items.push({ t: 'Any time', kind: 'rest', title: code === 'off' ? 'Day off' : 'Rest day', detail: code === 'off' ? 'No training at all. Enjoy Christmas with your family.' : 'Recovery is training too. A walk or a cycle is fine.' });
    }

    items.push({ t: '21:30', kind: 'habit', title: '5-minute stretch', detail: 'Hips, hamstrings, calves' });
    items.push({ t: '22:00', kind: 'habit', title: 'Lights out', detail: 'Aim for 9 hours sleep' });

    const order = t => /^\d\d:\d\d$/.test(t) ? mins(t) : t === 'Any time' ? -1 : 9999;
    items.sort((a, b) => order(a.t) - order(b.t));

    const tags = [];
    team.forEach(e => tags.push({ k: e.kind, t: e.title }));
    if (sess) tags.push({ k: 'home', t: sess.name });
    if (code === 'rest') tags.push({ k: 'rest', t: 'Rest' });
    if (code === 'off') tags.push({ k: 'rest', t: 'Day off' });
    return { d, phase, hol, team, code, items, tags };
  }

  // ---- ticks, saved on this phone only ----
  const KEY = 'feile27';
  const store = (() => { try { return JSON.parse(localStorage.getItem(KEY)) || {}; } catch (e) { return {}; } })();
  const save = () => { try { localStorage.setItem(KEY, JSON.stringify(store)); } catch (e) {} };
  const ticked = (d, id) => !!(store[d] && store[d][id]);
  function toggle(d, id) {
    store[d] = store[d] || {};
    if (store[d][id]) delete store[d][id]; else store[d][id] = 1;
    save();
  }
  const dayTicks = plan => {
    const ids = F.HABITS.map(h => 'h:' + h.id);
    plan.items.filter(i => i.session || i.kind === 'team' || i.kind === 'snc' || i.kind === 'match').forEach((i, n) => ids.push('i:' + n));
    return { total: ids.length, done: ids.filter(id => ticked(plan.d, id)).length };
  };

  // ---- drawing ----
  const $ = s => document.querySelector(s);
  const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
  const ICON = { team: '⚑', snc: '◆', match: '★', home: '⌂', food: '●', rest: '☾', habit: '✓' };
  let current = clamp(new URLSearchParams(location.search).get('d') || todayIso());
  const openSessions = new Set();

  function hero() {
    const today = todayIso();
    const left = Math.max(0, Math.round((parse(F.FEILE_START) - parse(today)) / DAY));
    const p = phaseOf(clamp(today));
    const started = today >= F.PLAN_START;
    $('#count').textContent = left;
    $('#count-label').textContent = left === 1 ? 'day to Féile' : 'days to Féile';
    $('#phase').textContent = started ? p.name : 'Starts Mon 2 Nov';
  }

  function strip() {
    const mon = add(current, 1 - dow(current));
    const today = todayIso();
    let html = '';
    for (let i = 0; i < 7; i++) {
      const d = add(mon, i);
      const inRange = within(d, F.VIEW_START, F.FEILE_END);
      const plan = inRange ? planDay(d) : null;
      const dots = plan ? [...new Set(plan.tags.map(t => t.k))].slice(0, 3).map(k => `<i class="dot k-${k}"></i>`).join('') : '';
      const t = plan ? dayTicks(plan) : null;
      const done = t && t.total && t.done === t.total;
      html += `<button class="day${d === current ? ' on' : ''}${d === today ? ' today' : ''}${done ? ' done' : ''}" data-d="${d}" ${inRange ? '' : 'disabled'} aria-label="${longDate(d)}">
        <span class="dw">${DOW[i].slice(0, 3)}</span><span class="dn">${+d.slice(8)}</span><span class="dots">${dots}</span></button>`;
    }
    $('#days').innerHTML = html;
    const sun = add(mon, 6);
    $('#week-label').textContent = `${+mon.slice(8)} ${MON[+mon.slice(5, 7) - 1].slice(0, 3)} to ${+sun.slice(8)} ${MON[+sun.slice(5, 7) - 1].slice(0, 3)}`;
    $('#prev').disabled = add(mon, -1) < F.VIEW_START;
    $('#next').disabled = add(mon, 7) > F.FEILE_END;
  }

  function sessionHtml(d, sess, idx) {
    return sess.blocks.map((b, bi) => `<div class="block"><div class="bh"><b>${esc(b.title)}</b><span>${b.mins} min</span></div>
      ${b.note ? `<p class="bn">${esc(b.note)}</p>` : ''}
      <ul>${b.items.map((x, xi) => { const id = `x:${idx}:${bi}:${xi}`; return `<li><label><input type="checkbox" data-tick="${id}" ${ticked(d, id) ? 'checked' : ''}><span><b>${esc(x.n)}</b><small>${esc(x.d)}</small></span></label></li>`; }).join('')}</ul></div>`).join('');
  }

  function dayView() {
    const plan = planDay(current);
    const d = current;
    const tip = F.FOOD_TIPS[Math.round(parse(d) / DAY) % F.FOOD_TIPS.length];
    const toFeile = Math.round((parse(F.FEILE_START) - parse(d)) / DAY);
    const chIdx = Math.round((parse(d) - parse(F.TOUCHES_12.start)) / DAY);
    const challenge = chIdx >= 0 && chIdx < 12 ? F.TOUCHES_12.days[chIdx] : null;
    let tickIdx = 0;

    const rows = plan.items.map(it => {
      const tickable = it.session || it.kind === 'team' || it.kind === 'snc' || it.kind === 'match';
      const id = tickable ? 'i:' + (tickIdx++) : null;
      const open = it.session && openSessions.has(d);
      return `<li class="row k-${it.kind}">
        <div class="tm">${esc(it.t)}${it.end ? `<small>${esc(it.end)}</small>` : ''}</div>
        <div class="ev"><div class="ic">${ICON[it.kind] || '•'}</div><div class="tx">
          <div class="tt">${esc(it.title)}${it.session ? ` <span class="mins">${it.session.mins} min</span>` : ''}</div>
          ${it.detail ? `<div class="td">${esc(it.detail)}</div>` : ''}
          ${it.session ? `<button class="more" data-open="${d}">${open ? 'Hide the session' : 'Show the session'}</button>${open ? `<div class="sess">${sessionHtml(d, it.session, id)}</div>` : ''}` : ''}
        </div>
        ${id ? `<label class="chk" title="Done"><input type="checkbox" data-tick="${id}" ${ticked(d, id) ? 'checked' : ''}><span></span></label>` : ''}</div>
      </li>`;
    }).join('');

    const t = dayTicks(plan);
    $('#day').innerHTML = `
      <div class="page">
        <div class="ph">
          <div><div class="pd">${esc(longDate(d))}</div>
          <div class="pm">${esc(plan.phase.name)}${plan.hol ? ' · ' + esc(plan.hol.name) : ''}${toFeile > 0 ? ` · ${toFeile} days to go` : ''}</div></div>
          <div class="score" aria-label="${t.done} of ${t.total} done"><b>${t.done}</b>/${t.total}</div>
        </div>
        <div class="tags">${plan.tags.map(x => `<span class="tag k-${x.k}">${esc(x.t)}</span>`).join('')}</div>
        ${d < F.PLAN_START ? `<p class="note">The plan starts on Monday 2 November. Use this week to find your wall, pump the ball and check your helmet.</p>` : ''}
        ${plan.d === F.FEILE_START || plan.d === F.FEILE_END ? '' : `<p class="aim">${esc(plan.phase.aim)}</p>`}
        <ol class="timeline">${rows}</ol>
      </div>
      ${challenge ? `<section class="card ch"><h2>12 Days of Touches · Day ${chIdx + 1}</h2><p>${esc(challenge)}</p><label class="hab"><input type="checkbox" data-tick="ch" ${ticked(d, 'ch') ? 'checked' : ''}><span>Done it</span></label></section>` : ''}
      <section class="card"><h2>Every day</h2>
        ${F.HABITS.map(h => `<label class="hab"><input type="checkbox" data-tick="h:${h.id}" ${ticked(d, 'h:' + h.id) ? 'checked' : ''}><span><b>${esc(h.n)}</b><small>${esc(h.d)}</small></span></label>`).join('')}
      </section>
      <section class="card food"><h2>Food focus: ${esc(tip.t)}</h2><p>${esc(tip.d)}</p></section>`;
  }

  function weekView() {
    const mon = add(current, 1 - dow(current));
    let html = '';
    for (let i = 0; i < 7; i++) {
      const d = add(mon, i);
      if (!within(d, F.VIEW_START, F.FEILE_END)) continue;
      const p = planDay(d);
      const main = p.items.filter(x => ['team', 'snc', 'match', 'home', 'rest'].includes(x.kind));
      html += `<button class="wk${d === current ? ' on' : ''}" data-d="${d}"><span class="wd">${DOW[i].slice(0, 3)} ${+d.slice(8)}</span><span class="wl">${main.map(x => `<span class="k-${x.kind}">${ICON[x.kind]} ${esc(x.title)}${/^\d/.test(x.t) ? ' · ' + x.t : ''}</span>`).join('') || '<span class="k-rest">Rest</span>'}</span></button>`;
    }
    $('#week').innerHTML = html;
  }

  function render() {
    hero(); strip(); dayView(); weekView();
    const u = new URL(location.href); u.searchParams.set('d', current); history.replaceState(null, '', u);
  }

  document.addEventListener('click', e => {
    const day = e.target.closest('[data-d]');
    if (day && !day.disabled) { current = day.dataset.d; render(); return; }
    const more = e.target.closest('[data-open]');
    if (more) { const k = more.dataset.open; openSessions.has(k) ? openSessions.delete(k) : openSessions.add(k); dayView(); return; }
    if (e.target.closest('#prev')) { current = clamp(add(current, -7)); render(); }
    if (e.target.closest('#next')) { current = clamp(add(current, 7)); render(); }
    if (e.target.closest('#today')) { current = clamp(todayIso()); render(); }
  });
  document.addEventListener('change', e => {
    const id = e.target.dataset && e.target.dataset.tick;
    if (!id) return;
    toggle(current, id);
    const plan = planDay(current), t = dayTicks(plan);
    const s = document.querySelector('.score'); if (s) s.innerHTML = `<b>${t.done}</b>/${t.total}`;
    strip();
  });
  let x0 = null;
  document.addEventListener('touchstart', e => { if (e.target.closest('.page')) x0 = e.touches[0].clientX; }, { passive: true });
  document.addEventListener('touchend', e => {
    if (x0 === null) return;
    const dx = e.changedTouches[0].clientX - x0; x0 = null;
    if (Math.abs(dx) > 70) { current = clamp(add(current, dx < 0 ? 1 : -1)); render(); }
  }, { passive: true });

  render();
  window.FEILE_DIARY = { planDay, loadTeamEvents };
})();
