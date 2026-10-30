// Clontarf Senior Football · off-season diary: works out each day from the
// block plan (plan.js), then draws it. Ticks and numbers are saved to the
// player's account (account.js). Layout follows the Féile 2027 kids diary.
(function () {
  const P = window.PLAN;
  const { ticked, toggle, value, setValue } = window.ACCOUNT;
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
  const clamp = d => d < P.VIEW_START ? P.VIEW_START : d > P.VIEW_END ? P.VIEW_END : d;
  const monday = d => add(d, 1 - dow(d));
  const longDate = d => `${DOW[dow(d) - 1]} ${+d.slice(8)} ${MON[+d.slice(5, 7) - 1]}`;
  const short = d => `${+d.slice(8)} ${MON[+d.slice(5, 7) - 1].slice(0, 3)}`;

  const blockOf = d => P.BLOCKS.find(b => within(d, b.from, b.to));
  const weekOf = (d, b) => Math.floor((parse(d) - parse(b.from)) / DAY / 7) + 1;
  const weeksIn = b => Math.round((parse(b.to) - parse(b.from)) / DAY / 7 + 1 / 7);

  // gym and run sessions count towards the week's five; speed counts with its gym.
  const CSS = { gym: 'snc', speed: 'match', run: 'run', rest: 'rest' };
  const ICON = { gym: '◆', speed: '⚡', run: '➜', rest: '☾' };

  function planDay(d) {
    const b = blockOf(d);
    if (!b) return { d, items: [] };
    const wk = weekOf(d, b);
    const items = P.day(dow(d), wk).map((x, i) => ({ ...x, id: 'i:' + i, title: x.s ? x.s.name : x.title, detail: x.s ? x.s.sub : x.detail }));
    return { d, b, wk, items };
  }
  const tickables = plan => plan.items.filter(i => i.s);
  const dayTicks = plan => {
    const ids = tickables(plan).map(i => i.id);
    return { total: ids.length, done: ids.filter(id => ticked(plan.d, id)).length };
  };

  // ---- drawing ----
  const $ = s => document.querySelector(s);
  const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
  let current = clamp(new URLSearchParams(location.search).get('d') || todayIso());
  const openSessions = new Set();

  function hero() {
    const today = todayIso(), b = blockOf(today);
    if (b) {
      $('#count').textContent = weekOf(today, b);
      $('#count-label').textContent = `week of ${weeksIn(b)}`;
      $('#phase').textContent = b.name;
    } else {
      $('#count').textContent = '–';
      $('#count-label').textContent = today > P.VIEW_END ? 'next block soon' : 'starts ' + short(P.VIEW_START);
      $('#phase').textContent = '';
    }
  }

  function strip() {
    const mon = monday(current), today = todayIso();
    let html = '';
    for (let i = 0; i < 7; i++) {
      const d = add(mon, i);
      const inRange = within(d, P.VIEW_START, P.VIEW_END);
      const plan = inRange ? planDay(d) : null;
      const dots = plan ? [...new Set(plan.items.map(x => CSS[x.kind]))].slice(0, 3).map(k => `<i class="dot k-${k}"></i>`).join('') : '';
      const t = plan ? dayTicks(plan) : null;
      const done = t && t.total && t.done === t.total;
      html += `<button class="day${d === current ? ' on' : ''}${d === today ? ' today' : ''}${done ? ' done' : ''}" data-d="${d}" ${inRange ? '' : 'disabled'} aria-label="${longDate(d)}">
        <span class="dw">${DOW[i].slice(0, 3)}</span><span class="dn">${+d.slice(8)}</span><span class="dots">${dots}</span></button>`;
    }
    $('#days').innerHTML = html;
    $('#week-label').textContent = `${short(mon)} to ${short(add(mon, 6))}`;
    $('#prev').disabled = add(mon, -1) < P.VIEW_START;
    $('#next').disabled = add(mon, 7) > P.VIEW_END;
  }

  const watchLink = url => url ? `<a class="watch" href="${esc(url)}" target="_blank" rel="noopener">▶ Watch</a>` : '';

  function sessionHtml(d, sess, idx) {
    return sess.blocks.map((b, bi) => `<div class="block"><div class="bh"><b>${esc(b.title)}</b></div>
      ${b.note ? `<p class="bn">${esc(b.note)}</p>` : ''}
      <ul>${b.items.map((x, xi) => { const id = `x:${idx}:${bi}:${xi}`; return `<li><label><input type="checkbox" data-tick="${id}" ${ticked(d, id) ? 'checked' : ''}><span><b>${esc(x.n)}</b><small>${esc(x.d)}</small></span></label>${watchLink(x.v)}</li>`; }).join('')}</ul></div>`).join('');
  }

  const numField = (d, id, label, hint) => `<label class="num"><span><b>${esc(label)}</b><small>${esc(hint)}</small></span>
    <input type="text" inputmode="decimal" data-val="${id}" value="${esc(value(d, id))}" placeholder="—"></label>`;

  // Sunday: the week's numbers in one place, ready for David's form.
  function checkIn(plan) {
    const mon = monday(plan.d);
    let done = 0, total = 0;
    const best = {};
    for (let i = 0; i < 7; i++) {
      const d = add(mon, i), p = planDay(d);
      p.items.filter(x => x.kind === 'gym' || x.kind === 'run').forEach(x => { total++; if (ticked(d, x.id)) done++; });
      ['bench', 'trapbar', 'frontsquat'].forEach(k => { if (value(d, 'lift:' + k)) best[k] = value(d, 'lift:' + k); });
    }
    const bw = value(mon, 'bodyweight');
    const row = (l, v) => `<li><span>${l}</span><b>${v ? esc(v) : '<i>not logged</i>'}</b></li>`;
    return `<section class="card ci"><h2>Sunday check-in · Week ${plan.wk}</h2>
      <p>Count only sessions you fully completed. If one was partly done, tell David what changed.</p>
      <ul class="sum">${row('Sessions done', `${done} of ${total}`)}${row('Monday bodyweight', bw && bw + ' kg')}${row('Bench', best.bench)}${row('Trap bar', best.trapbar)}${row('Front squat', best.frontsquat)}</ul>
      <a class="gbtn" href="${P.FORM}" target="_blank" rel="noopener">Log your week</a></section>`;
  }

  function dayView() {
    const plan = planDay(current), d = current;
    let tracked = '';
    const rows = plan.items.map(it => {
      const okey = d + ':' + it.id;
      const open = it.s && openSessions.has(okey);
      if (it.s && it.s.track) tracked = numField(d, 'lift:' + it.s.track.id, `Best ${it.s.track.n} set`, 'Best clean work set, total kg x reps incl. the bar, e.g. 80x8');
      return `<li class="row k-${CSS[it.kind]}">
        <div class="tm">${esc(it.t)}${it.s ? `<small>${it.s.mins} min</small>` : ''}</div>
        <div class="ev"><div class="ic">${ICON[it.kind]}</div><div class="tx">
          <div class="tt">${esc(it.title)}</div>
          ${it.detail ? `<div class="td">${esc(it.detail)}</div>` : ''}
          ${it.s ? `<button class="more" data-open="${okey}">${open ? 'Hide' : 'Show what to do'}</button>` : ''}
        </div>
        ${it.s ? `<label class="chk" title="Done"><input type="checkbox" data-tick="${it.id}" ${ticked(d, it.id) ? 'checked' : ''}><span></span></label>` : ''}</div>
        ${open ? `<div class="sess">${sessionHtml(d, it.s, it.id)}</div>` : ''}
      </li>`;
    }).join('');

    const t = dayTicks(plan);
    const log = [dow(d) === 1 ? numField(d, 'bodyweight', 'Morning bodyweight (kg)', 'After the toilet, before breakfast, same scales') : '', tracked].join('');
    $('#day').innerHTML = `
      <div class="page">
        <div class="ph">
          <div><div class="pd">${esc(longDate(d))}</div>
          <div class="pm">${plan.b ? `${esc(plan.b.name)} · Week ${plan.wk} of ${weeksIn(plan.b)}` : ''}</div></div>
          ${t.total ? `<div class="score" aria-label="${t.done} of ${t.total} done"><b>${t.done}</b>/${t.total}</div>` : ''}
        </div>
        <div class="tags">${plan.items.map(x => `<span class="tag k-${CSS[x.kind]}">${esc(x.title)}</span>`).join('')}</div>
        ${plan.b && dow(d) === 1 ? `<p class="aim">${esc(plan.b.aim)}</p>` : ''}
        <ol class="timeline">${rows}</ol>
      </div>
      ${log ? `<section class="card"><h2>Log it</h2>${log}</section>` : ''}
      ${plan.items.some(x => x.kind === 'gym') ? `<section class="card"><h2>Weights</h2><p class="bn">${esc(P.WEIGHTS)}</p></section>` : ''}
      ${dow(d) === 7 && plan.b ? checkIn(plan) : ''}`;
  }

  function weekView() {
    const mon = monday(current);
    let html = '';
    for (let i = 0; i < 7; i++) {
      const d = add(mon, i);
      if (!within(d, P.VIEW_START, P.VIEW_END)) continue;
      const p = planDay(d);
      html += `<button class="wk${d === current ? ' on' : ''}" data-d="${d}"><span class="wd">${DOW[i].slice(0, 3)} ${+d.slice(8)}</span><span class="wl">${p.items.map(x => `<span class="k-${CSS[x.kind]}">${ICON[x.kind]} ${esc(x.title)}</span>`).join('')}</span></button>`;
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
    const v = e.target.dataset && e.target.dataset.val;
    if (v) { setValue(current, v, e.target.value.trim()); return; }
    const id = e.target.dataset && e.target.dataset.tick;
    if (!id) return;
    toggle(current, id);
    const t = dayTicks(planDay(current));
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

  window.ACCOUNT.ready.then(render);
})();
