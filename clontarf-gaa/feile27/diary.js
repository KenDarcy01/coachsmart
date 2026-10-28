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

  // ---- team events: CoachSmart first, the planned week where none are set up ----
  // CoachSmart events come from the team-diary edge function. Any week (Mon to
  // Sun) with at least one CoachSmart event uses only those events; a week
  // with none falls back to the planned pattern in plan.js, flagged "planned".
  const FEED = `https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/team-diary?code=${F.TEAM_CODE}&from=${F.VIEW_START}&to=${F.FEILE_END}`;
  const CACHE = 'feile27:cs';
  let cs = null; // { at, byDate: { date: [event] }, weeks: Set of Mondays }
  const monday = d => add(d, 1 - dow(d));

  function useFeed(body, at) {
    const byDate = {}, weeks = new Set();
    (body.events || []).forEach(e => {
      weeks.add(monday(e.date));
      if (!e.cancelled) (byDate[e.date] = byDate[e.date] || []).push(e);
    });
    cs = { at, byDate, weeks };
  }
  try { const c = JSON.parse(localStorage.getItem(CACHE)); if (c) useFeed(c.body, c.at); } catch (e) {}

  function fromCs(e) {
    ['opposition', 'location'].forEach(k => { if (/^tbc$/i.test(e[k] || '')) e[k] = null; });
    const type = (e.type || '').toLowerCase(), code = e.code === 'Hurling' ? 'Camogie' : e.code;
    const snc = /s\s*&\s*c/i.test(`${e.title} ${e.code}`);
    const kind = type === 'match' ? 'match' : snc ? 'snc' : 'team';
    const fallback = kind === 'match' ? (e.opposition ? `Match v ${e.opposition}` : 'Match') : kind === 'snc' ? 'Group S&C' : `${code && code !== '-' ? code + ' training' : 'Team session'}`;
    const title = e.title || fallback;
    const detail = [e.squad, kind === 'match' && e.opposition && !title.toLowerCase().includes(e.opposition.toLowerCase().slice(0, 5)) ? 'v ' + e.opposition : null,
      e.meet ? 'Meet ' + e.meet : null, e.location].filter(Boolean).join(' · ');
    return { date: e.date, start: e.start, end: hhmm(mins(e.start) + 60), kind, title, detail, squad: e.squad, cs: true };
  }

  function plannedEvents(d) {
    const t = F.TEAM, out = [];
    const off = t.off.some(([a, b]) => within(d, a, b));
    if (!off) t.weekly.filter(w => w.dow === dow(d)).forEach(w => out.push({ date: d, ...w }));
    t.matches.filter(m => m.date === d).forEach(m => out.push({ date: d, kind: 'match', end: hhmm(mins(m.start) + 60), detail: 'Planned fixture', ...m }));
    (t.camps || []).filter(c => within(d, c.from, c.to)).forEach(c => out.push({ date: d, kind: 'team', ...c }));
    return out.map(e => ({ ...e, planned: true }));
  }

  function loadTeamEvents(d) {
    const out = cs && cs.weeks.has(monday(d)) ? (cs.byDate[d] || []).map(fromCs) : plannedEvents(d);
    return out.sort((a, b) => mins(a.start) - mins(b.start));
  }

  async function refreshFeed() {
    try {
      const r = await fetch(FEED, { cache: 'no-store' });
      if (!r.ok) throw new Error(r.status);
      const body = await r.json(), at = new Date().toISOString();
      useFeed(body, at);
      try { localStorage.setItem(CACHE, JSON.stringify({ body, at })); } catch (e) {}
    } catch (e) { console.warn('CoachSmart feed unavailable, using the planned week', e); }
    render();
  }

  const phaseOf = d => F.PHASES.find(p => within(d, p.from, p.to)) || F.PHASES[0];
  const holidayOf = d => F.HOLIDAYS.find(h => within(d, h.from, h.to));

  // ---- what to do at home on a day ----
  // Worked out from the team sessions around the day: light the day before a
  // match, recovery the day after, the long run on the last free day before
  // the weekend, and nothing extra on a day with a team session.
  function homeFor(d, team) {
    const p = phaseOf(d).key;
    const toFeile = (parse(F.FEILE_START) - parse(d)) / DAY;
    if (p === 'feile') return 'feile';
    if (toFeile <= 2) return 'rest';
    if (F.CHRISTMAS[d] && !team.length) return F.CHRISTMAS[d];
    if (team.length) return null;
    const ev = n => loadTeamEvents(add(d, n));
    const matchIn = n => ev(n).some(e => e.kind === 'match');
    if (matchIn(1)) return 'P';
    if (matchIn(-1)) return 'M';
    if (F.BENCHMARKS.includes(d)) return 'test';
    switch (dow(d)) {
      case 1: return 'B';
      case 2: return 'A';
      case 3: return 'M';
      case 4: return 'F';
      // A match or team session at the weekend: the long run moves to Friday.
      case 5: return p === 'taper' ? 'T' : matchIn(2) || ev(1).length ? 'C' : 'B';
      case 6: return p === 'taper' ? 'T' : 'C';
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

  // ---- the run for a day, if there is one ----
  function runFor(d, code, team, phase) {
    if (team.length || !code) return null;
    let day = null;
    if (F.CHRISTMAS[d] && !team.length) day = code === 'C' ? 'sat' : code === 'M' ? 'thu' : null;
    else if (code === 'F') day = 'thu';
    else if (code === 'C') day = 'sat';
    else if (code === 'T' && dow(d) === 6) day = 'sat';
    if (!day) return null;
    const from = monday(phase.from > F.PLAN_START ? phase.from : F.PLAN_START);
    const week = Math.floor((parse(d) - parse(from)) / DAY / 7);
    return F.run(day, phase.key, week);
  }

  // ---- the day's timeline ----
  function planDay(d) {
    const phase = phaseOf(d), hol = holidayOf(d), team = loadTeamEvents(d);
    const code = homeFor(d, team);
    const sess = code && code !== 'rest' && code !== 'off' ? sessionFor(code, phase.key) : null;
    const items = [];

    if (code === 'feile') {
      items.push({ t: '09:30', kind: 'match', title: 'Féile games', detail: 'Warm up with the team. Be proud of all the work you did.' });
      return { d, phase, hol, team, code, items, tags: [{ k: 'match', t: 'Féile' }] };
    }

    team.forEach(e => items.push({ t: e.start, end: e.end, kind: e.kind, title: e.title, detail: e.detail, planned: e.planned }));
    const run = runFor(d, code, team, phase);
    // School days: everything happens in the evening. Weekends: mid-morning.
    let at = dow(d) >= 6 ? 10 * 60 + 30 : 18 * 60 + 30;
    if (run) {
      items.push({ t: hhmm(at), end: hhmm(at + run.mins), kind: 'run', title: run.name, detail: run.sub, session: run });
      at += run.mins + 10;
    }
    if (sess) items.push({ t: hhmm(at), end: hhmm(at + sess.mins), kind: 'home', title: sess.name, detail: sess.sub, session: sess });
    if (code === 'rest' || code === 'off') {
      items.push({ t: 'Any time', kind: 'rest', title: code === 'off' ? 'Day off' : 'Rest day', detail: code === 'off' ? 'No training at all. Enjoy Christmas with your family.' : 'Recovery is training too. A walk or a cycle is fine.' });
    }

    const order = t => /^\d\d:\d\d$/.test(t) ? mins(t) : t === 'Any time' ? -1 : 9999;
    items.sort((a, b) => order(a.t) - order(b.t));

    const tags = [];
    team.forEach(e => tags.push({ k: e.kind, t: e.title }));
    if (run) tags.push({ k: 'run', t: run.name });
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
  const ICON = { team: '⚑', snc: '◆', match: '★', run: '➜', home: '⌂', rest: '☾' };
  let current = clamp(new URLSearchParams(location.search).get('d') || todayIso());
  const openSessions = new Set();

  function hero() {
    const today = todayIso();
    const left = Math.max(0, Math.round((parse(F.FEILE_START) - parse(today)) / DAY));
    const p = phaseOf(clamp(today));
    $('#count').textContent = left;
    $('#count-label').textContent = left === 1 ? 'day to Féile' : 'days to Féile';
    $('#phase').textContent = p.name;
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

  function watchLink(name) {
    const w = F.watch(name);
    return w ? `<a class="watch" href="${esc(w.url)}" target="_blank" rel="noopener" title="${w.by === 'YouTube' ? 'YouTube videos' : 'GAA Activate videos'}">▶ Watch</a>` : '';
  }

  function sessionHtml(d, sess, idx) {
    return sess.blocks.map((b, bi) => `<div class="block"><div class="bh"><b>${esc(b.title)}</b><span>${b.mins} min</span></div>
      ${b.note ? `<p class="bn">${esc(b.note)}</p>` : ''}
      <ul>${b.items.map((x, xi) => { const id = `x:${idx}:${bi}:${xi}`; return `<li><label><input type="checkbox" data-tick="${id}" ${ticked(d, id) ? 'checked' : ''}><span><b>${esc(x.n)}</b><small>${esc(x.d)}</small></span></label>${watchLink(x.n)}</li>`; }).join('')}</ul></div>`).join('');
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
      const okey = d + ':' + id;
      const open = it.session && openSessions.has(okey);
      return `<li class="row k-${it.kind}">
        <div class="tm">${esc(it.t)}${it.end ? `<small>${esc(it.end)}</small>` : ''}</div>
        <div class="ev"><div class="ic">${ICON[it.kind] || '•'}</div><div class="tx">
          <div class="tt">${esc(it.title)}${it.planned ? ' <span class="pl">Planned</span>' : ''}${it.session ? ` <span class="mins">${it.session.mins} min</span>` : ''}</div>
          ${it.detail ? `<div class="td">${esc(it.detail)}</div>` : ''}
          ${it.session ? `<button class="more" data-open="${okey}">${open ? 'Hide' : 'Show what to do'}</button>` : ''}
        </div>
        ${id ? `<label class="chk" title="Done"><input type="checkbox" data-tick="${id}" ${ticked(d, id) ? 'checked' : ''}><span></span></label>` : ''}</div>
        ${open ? `<div class="sess">${sessionHtml(d, it.session, id)}</div>` : ''}
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
        ${plan.d === F.FEILE_START || plan.d === F.FEILE_END ? '' : `<p class="aim">${esc(plan.phase.aim)}</p>`}
        <ol class="timeline">${rows}</ol>
      </div>
      ${challenge ? `<section class="card ch"><h2>12 Days of Touches · Day ${chIdx + 1}</h2><p>${esc(challenge)}</p><label class="hab"><input type="checkbox" data-tick="ch" ${ticked(d, 'ch') ? 'checked' : ''}><span>Done it</span></label></section>` : ''}
      <section class="card"><h2>Every day</h2>
        ${F.HABITS.map(h => `<label class="hab"><input type="checkbox" data-tick="h:${h.id}" ${ticked(d, 'h:' + h.id) ? 'checked' : ''}><span><b>${esc(h.n)}</b><small>${esc(h.d)}</small></span></label>`).join('')}
      </section>
      <section class="card food"><h2>Eating well</h2><p class="tip">${esc(tip)}</p>
        <details><summary>What good eating looks like</summary><ul>${F.EATING.map(x => `<li><b>${esc(x.t)}.</b> ${esc(x.d)}</li>`).join('')}</ul></details>
      </section>`;
  }

  function weekView() {
    const mon = add(current, 1 - dow(current));
    let html = '';
    for (let i = 0; i < 7; i++) {
      const d = add(mon, i);
      if (!within(d, F.VIEW_START, F.FEILE_END)) continue;
      const p = planDay(d);
      const main = p.items.filter(x => ['team', 'snc', 'match', 'run', 'home', 'rest'].includes(x.kind));
      html += `<button class="wk${d === current ? ' on' : ''}" data-d="${d}"><span class="wd">${DOW[i].slice(0, 3)} ${+d.slice(8)}</span><span class="wl">${main.map(x => `<span class="k-${x.kind}">${ICON[x.kind]} ${esc(x.title)}${/^\d/.test(x.t) ? ' · ' + x.t : ''}</span>`).join('') || '<span class="k-rest">Rest</span>'}</span></button>`;
    }
    $('#week').innerHTML = html;
  }

  function feedNote() {
    const el = $('#feed'); if (!el) return;
    if (!cs) { el.textContent = 'Team sessions shown are the planned week until CoachSmart loads.'; return; }
    const t = new Date(cs.at);
    el.textContent = `Team sessions from CoachSmart, updated ${t.toLocaleDateString('en-IE', { day: 'numeric', month: 'short' })} at ${t.toLocaleTimeString('en-IE', { hour: '2-digit', minute: '2-digit' })}. Weeks with nothing set up yet show the planned week.`;
  }

  function render() {
    hero(); strip(); dayView(); weekView(); feedNote();
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
  refreshFeed();
  window.FEILE_DIARY = { planDay, loadTeamEvents };
})();
