// Clontarf Senior Football · off-season diary: works out each day from the
// plan the coaches published from their Google Sheet (or plan.js until the
// first publish), then draws it. Ticks and numbers are saved to the
// player's account (account.js). Layout follows the Féile 2027 kids diary.
(function () {
  let P = window.PLAN;
  const { ticked, toggle, value, setValue, saved } = window.ACCOUNT;

  // The published sheet plan, in the shape the rest of this file uses.
  // A player's own rows for a day replace the team's slots for that day.
  function fromSheet(pub) {
    const blocks = pub.blocks.slice().sort((a, b) => a.from.localeCompare(b.from));
    const own = pub.own || {};
    // The diary runs from the first block to the last block, or further if an
    // event, activity or note falls outside them (e.g. over Christmas).
    const dated = [...Object.keys(pub.extras || {}), ...Object.keys(pub.notes || {}),
      ...Object.keys(own).filter(d => (own[d].extras || []).length || (own[d].notes || []).length)].sort();
    const first = [blocks[0].from, dated[0]].filter(Boolean).sort()[0];
    const last = [blocks[blocks.length - 1].to, dated[dated.length - 1]].filter(Boolean).sort().pop();
    const slot = x => {
      if (x.kind === 'rest' || !x.code) return { t: x.t, kind: 'rest', title: x.title || 'Off', detail: x.detail || '' };
      const s = pub.sessions[x.code];
      return s ? { t: x.t, kind: s.kind, s } : null;
    };
    return {
      FORM: pub.form || window.PLAN.FORM,
      WEIGHTS: pub.weights || '',
      BLOCKS: blocks,
      VIEW_START: first,
      VIEW_END: last,
      slots: d => ((own[d] && own[d].slots) || pub.days[d] || []).map(slot).filter(Boolean),
      // Events and activities from the sheet: the squad's, then this player's own.
      extras: d => [...((pub.extras || {})[d] || []), ...((own[d] && own[d].extras) || [])],
      notes: d => [...((pub.notes || {})[d] || []), ...((own[d] && own[d].notes) || [])]
    };
  }
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
  // event = something to know about (no tick); extra = an activity from the sheet.
  const CSS = { gym: 'snc', speed: 'match', run: 'run', rest: 'rest', event: 'event', extra: 'home' };
  const ICON = { gym: '◆', speed: '⚡', run: '➜', rest: '☾', event: '●', extra: '✚' };

  function planDay(d) {
    const b = blockOf(d);
    const wk = b ? weekOf(d, b) : null;
    const plan = b ? (P.slots ? P.slots(d) : P.day(dow(d), wk)) : [];
    const items = [
      ...plan.map((x, i) => ({ ...x, id: 'i:' + i, title: x.s ? x.s.name : x.title, detail: x.s ? x.s.sub : x.detail })),
      ...(P.extras ? P.extras(d) : []).map(x => ({ ...x, id: x.id || 'e:' + x.title }))
    ];
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
  // Always open on today. (An old ?d= in a saved link or home-screen icon is ignored.)
  let current = clamp(todayIso());
  const openSessions = new Set();

  function hero() {
    const today = todayIso(), b = blockOf(today);
    if (b) {
      $('#count').textContent = weekOf(today, b);
      $('#count-label').textContent = `week of ${weeksIn(b)}`;
      $('#phase').textContent = b.name;
    } else {
      $('#count').textContent = '–';
      const firstBlock = P.BLOCKS[0].from, ahead = P.BLOCKS.find(x => x.from > today);
      $('#count-label').textContent = ahead ? 'starts ' + short(ahead.from) : today > firstBlock ? 'next block soon' : 'starts ' + short(firstBlock);
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
      const dots = plan ? [...new Set(plan.items.map(x => CSS[x.kind]))].slice(0, 3).map(k => `<i class="dot k-${k || 'home'}"></i>`).join('') : '';
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
    <input type="text" inputmode="decimal" enterkeyhint="done" data-val="${id}" value="${esc(value(d, id))}" placeholder="—">
    <i class="sv${value(d, id) && saved(d) ? ' ok' : ''}" data-sv="${id}" aria-live="polite">${value(d, id) && saved(d) ? '✓ Saved' : ''}</i></label>`;

  // Under a number: "Saving…", then "✓ Saved" only once the account has it, or an error.
  function showSave(id, state) {
    const el = document.querySelector(`[data-sv="${id.replace(/"/g, '\\"')}"]`); if (!el) return;
    el.className = 'sv' + (state ? ' ' + state : '');
    el.textContent = { busy: 'Saving…', ok: '✓ Saved', err: 'Not saved. Check your signal, then tap the box to try again' }[state] || '';
  }

  // Sunday: the week's numbers in one place, ready for David's form.
  function checkIn(plan) {
    const mon = monday(plan.d);
    let done = 0, total = 0;
    const best = {}, lifts = [];
    for (let i = 0; i < 7; i++) {
      const d = add(mon, i), p = planDay(d);
      p.items.filter(x => x.kind === 'gym' || x.kind === 'run').forEach(x => { total++; if (ticked(d, x.id)) done++; });
      p.items.forEach(x => { if (x.s && x.s.track && !lifts.some(l => l.id === x.s.track.id)) lifts.push(x.s.track); });
      lifts.forEach(l => { if (value(d, 'lift:' + l.id)) best[l.id] = value(d, 'lift:' + l.id); });
    }
    const bw = value(mon, 'bodyweight');
    const row = (l, v) => `<li><span>${l}</span><b>${v ? esc(v) : '<i>not logged</i>'}</b></li>`;
    return `<section class="card ci"><h2>Sunday check-in · Week ${plan.wk}</h2>
      <p>Count only sessions you fully completed. If one was partly done, tell David what changed.</p>
      <ul class="sum">${row('Sessions done', `${done} of ${total}`)}${row('Monday bodyweight', bw && bw + ' kg')}${lifts.map(l => row(esc(l.n), best[l.id])).join('')}</ul>
      ${P.FORM ? `<a class="gbtn" href="${esc(P.FORM)}" target="_blank" rel="noopener">Log your week</a>` : ''}</section>`;
  }

  function dayView() {
    const plan = planDay(current), d = current;
    const notes = P.notes ? P.notes(d) : [];
    let tracked = '';
    const rows = plan.items.map(it => {
      const okey = d + ':' + it.id;
      const open = it.s && openSessions.has(okey);
      if (it.s && it.s.track) tracked = numField(d, 'lift:' + it.s.track.id, `Best ${it.s.track.n} set`, 'Best clean work set, total kg x reps incl. the bar, e.g. 80x8');
      const more = it.s && it.s.blocks && it.s.blocks.length;
      const sub = it.kind === 'event' ? (it.end ? `to ${it.end}` : '') : it.s && it.s.mins ? `${it.s.mins} min` : '';
      const detail = it.kind === 'event' ? [it.where, it.detail].filter(Boolean).join(' · ') : it.detail;
      return `<li class="row k-${CSS[it.kind] || 'home'}">
        <div class="tm">${esc(it.t)}${sub ? `<small>${esc(sub)}</small>` : ''}</div>
        <div class="ev"><div class="ic">${ICON[it.kind] || '✚'}</div><div class="tx">
          <div class="tt">${esc(it.title)}</div>
          ${detail ? `<div class="td">${esc(detail)}</div>` : ''}
          ${it.link ? `<a class="watch" href="${esc(it.link)}" target="_blank" rel="noopener">Open link</a>` : ''}
          ${more ? `<button class="more" data-open="${okey}">${open ? 'Hide' : 'Show what to do'}</button>` : ''}
        </div>
        ${it.s ? `<label class="chk" title="Done"><input type="checkbox" data-tick="${it.id}" ${ticked(d, it.id) ? 'checked' : ''}><span></span></label>` : ''}</div>
        ${open && more ? `<div class="sess">${sessionHtml(d, it.s, it.id)}</div>` : ''}
      </li>`;
    }).join('');

    const t = dayTicks(plan);
    const log = [plan.b && dow(d) === 1 ? numField(d, 'bodyweight', 'Morning bodyweight (kg)', 'After the toilet, before breakfast, same scales') : '', tracked].join('');
    $('#day').innerHTML = `
      <div class="page">
        <div class="ph">
          <div><div class="pd">${esc(longDate(d))}</div>
          <div class="pm">${plan.b ? `${esc(plan.b.name)} · Week ${plan.wk} of ${weeksIn(plan.b)}` : ''}</div></div>
          ${t.total ? `<div class="score" aria-label="${t.done} of ${t.total} done"><b>${t.done}</b>/${t.total}</div>` : ''}
        </div>
        <div class="tags">${plan.items.map(x => `<span class="tag k-${CSS[x.kind] || 'home'}">${esc(x.title)}</span>`).join('')}</div>
        ${plan.b && dow(d) === 1 ? `<p class="aim">${esc(plan.b.aim)}</p>` : ''}
        <ol class="timeline">${rows}</ol>
      </div>
      ${notes.length ? `<section class="card note"><h2>From your coach</h2>${notes.map(n => `<p class="bn">${esc(n)}</p>`).join('')}</section>` : ''}
      ${log ? `<section class="card"><h2>Log it</h2>${log}</section>` : ''}
      ${P.WEIGHTS && plan.items.some(x => x.kind === 'gym') ? `<section class="card"><h2>Weights</h2><p class="bn">${esc(P.WEIGHTS)}</p></section>` : ''}
      ${dow(d) === 7 && plan.b ? checkIn(plan) : ''}`;
  }

  function weekView() {
    const mon = monday(current);
    let html = '';
    for (let i = 0; i < 7; i++) {
      const d = add(mon, i);
      if (!within(d, P.VIEW_START, P.VIEW_END)) continue;
      const p = planDay(d);
      html += `<button class="wk${d === current ? ' on' : ''}" data-d="${d}"><span class="wd">${DOW[i].slice(0, 3)} ${+d.slice(8)}</span><span class="wl">${p.items.map(x => `<span class="k-${CSS[x.kind] || 'home'}">${ICON[x.kind] || '✚'} ${esc(x.title)}</span>`).join('')}</span></button>`;
    }
    $('#week').innerHTML = html;
  }

  function render() {
    hero(); strip(); dayView(); weekView();
  }
  if (new URLSearchParams(location.search).has('d')) history.replaceState(null, '', location.pathname);

  // Coming back to the page (app brought forward, or restored from the back/forward
  // cache): jump to today if the date has changed or it was away for 10+ minutes.
  let hiddenAt = Date.now(), shownDay = todayIso();
  const backToToday = () => {
    if (todayIso() !== shownDay || Date.now() - hiddenAt > 10 * 60e3) { current = clamp(todayIso()); openSessions.clear(); }
    shownDay = todayIso(); render();
  };
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) hiddenAt = Date.now(); else window.ACCOUNT.ready.then(backToToday);
  });
  window.addEventListener('pagehide', () => { hiddenAt = Date.now(); });
  window.addEventListener('pageshow', e => { if (e.persisted) window.ACCOUNT.ready.then(backToToday); });

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
    if (v) {
      const d = current, val = e.target.value.trim(), input = e.target;
      showSave(v, val ? 'busy' : '');
      setValue(d, v, val).then(ok => {
        if (d !== current || input.value.trim() !== val) return;
        showSave(v, ok ? (val ? 'ok' : '') : 'err');
      });
      return;
    }
    const id = e.target.dataset && e.target.dataset.tick;
    if (!id) return;
    toggle(current, id);
    const t = dayTicks(planDay(current));
    const s = document.querySelector('.score'); if (s) s.innerHTML = `<b>${t.done}</b>/${t.total}`;
    strip();
  });
  // After a failed save, tapping the box and leaving it again retries, even unchanged.
  document.addEventListener('focusout', e => {
    const v = e.target.dataset && e.target.dataset.val;
    const sv = v && document.querySelector(`[data-sv="${v.replace(/"/g, '\\"')}"]`);
    if (sv && sv.classList.contains('err')) setTimeout(() => { if (sv.classList.contains('err')) e.target.dispatchEvent(new Event('change', { bubbles: true })); }, 0);
  });
  document.addEventListener('keydown', e => { if (e.key === 'Enter' && e.target.dataset && e.target.dataset.val) e.target.blur(); });
  let x0 = null;
  document.addEventListener('touchstart', e => { if (e.target.closest('.page')) x0 = e.touches[0].clientX; }, { passive: true });
  document.addEventListener('touchend', e => {
    if (x0 === null) return;
    const dx = e.changedTouches[0].clientX - x0; x0 = null;
    if (Math.abs(dx) > 70) { current = clamp(add(current, dx < 0 ? 1 : -1)); render(); }
  }, { passive: true });

  window.ACCOUNT.ready.then(() => {
    const pub = window.ACCOUNT.published();
    if (pub) { try { P = fromSheet(pub); } catch (e) { console.warn('Published plan unreadable, using plan.js', e); } }
    current = clamp(todayIso());
    render();
  });
})();
