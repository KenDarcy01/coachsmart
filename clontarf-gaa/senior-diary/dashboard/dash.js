// Senior diary · coach dashboard. Sign in with CoachSmart; the diary-dashboard edge
// function only answers diary admins. Works out each player's planned sessions the
// same way the diary does (published sheet plan, or plan.js before the first publish),
// then shows what they ticked and the numbers they logged.
(function () {
  const SUPABASE_URL = 'https://gyfporsbdftvtakdvukt.supabase.co';
  const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4';
  const SDK = 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.43.4/dist/umd/supabase.min.js';
  const FN = SUPABASE_URL + '/functions/v1/diary-dashboard';

  const $ = s => document.querySelector(s);
  const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);

  // ---- dates (ISO yyyy-mm-dd in UTC, as in the diary) ----
  const DAY = 864e5;
  const DOW = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const parse = d => Date.UTC(+d.slice(0, 4), +d.slice(5, 7) - 1, +d.slice(8, 10));
  const iso = t => new Date(t).toISOString().slice(0, 10);
  const add = (d, n) => iso(parse(d) + n * DAY);
  const dow = d => (new Date(parse(d)).getUTCDay() + 6) % 7 + 1;
  const monday = d => add(d, 1 - dow(d));
  const todayIso = () => { const n = new Date(); return iso(Date.UTC(n.getFullYear(), n.getMonth(), n.getDate())); };
  const short = d => `${+d.slice(8)} ${MON[+d.slice(5, 7) - 1]}`;
  const ago = ts => {
    if (!ts) return '';
    const m = (Date.now() - new Date(ts).getTime()) / 6e4;
    if (m < 60) return 'just now';
    if (m < 60 * 24) return Math.round(m / 60) + 'h ago';
    const days = Math.round(m / 60 / 24);
    return days === 1 ? 'yesterday' : days + ' days ago';
  };

  // ---- the plan: which sessions each player had on a day ----
  // Tick ids match diary.js: plan slots are i:<n>, sheet activities their own id.
  function planner(pub) {
    if (pub && pub.blocks && pub.blocks.length) {
      const blocks = pub.blocks.slice().sort((a, b) => a.from.localeCompare(b.from));
      const own = {};
      (D.player_days || []).forEach(r => { (own[r.email] = own[r.email] || {})[r.day] = r; });
      const lifts = {};
      Object.values(pub.sessions || {}).forEach(s => { if (s.track) lifts[s.track.id] = s.track.n; });
      const slot = x => {
        if (x.kind === 'rest' || !x.code) return { kind: 'rest' };
        const s = pub.sessions[x.code];
        return s ? { kind: s.kind, s } : null;
      };
      return {
        blocks, lifts,
        items(email, d) {
          const mine = (own[email] || {})[d];
          const inBlock = blocks.some(b => d >= b.from && d <= b.to);
          const slots = inBlock ? ((mine && mine.slots) || (pub.days || {})[d] || []).map(slot).filter(Boolean) : [];
          const extras = [...((pub.extras || {})[d] || []), ...((mine && mine.extras) || [])];
          return [
            ...slots.map((x, i) => ({ id: 'i:' + i, kind: x.kind, s: x.s, name: x.s && x.s.name })),
            ...extras.map(x => ({ id: x.id || 'e:' + x.title, kind: x.kind, s: x.s, name: x.title }))
          ].filter(x => x.s);
        }
      };
    }
    // Before the first publish: plan.js, the same for everyone.
    const P = window.PLAN, lifts = {};
    return {
      blocks: P.BLOCKS, lifts,
      items(email, d) {
        const b = P.BLOCKS.find(x => d >= x.from && d <= x.to);
        if (!b) return [];
        const wk = Math.floor((parse(d) - parse(b.from)) / DAY / 7) + 1;
        return P.day(dow(d), wk).map((x, i) => {
          if (x.s && x.s.track) lifts[x.s.track.id] = x.s.track.n;
          return { id: 'i:' + i, kind: x.kind, s: x.s, name: x.s && x.s.name };
        }).filter(x => x.s);
      }
    };
  }

  // ---- state ----
  let sb = null, D = null, P = null;
  let view = 'squad', week = monday(todayIso()), sortBy = 'name', player = null, msg = '';
  const tickOf = {};   // user_id -> day -> ticks
  const savedAt = {};  // user_id -> latest updated_at

  const name = p => [p.first_name, p.last_name].filter(Boolean).join(' ') || p.email;
  const ticks = (p, d) => (tickOf[p.user_id] || {})[d] || {};
  const liftName = id => P.lifts[id] || id.replace(/^./, c => c.toUpperCase());

  function dayStat(p, d) {
    const items = P.items(p.email, d), t = ticks(p, d);
    return { items, total: items.length, done: items.filter(x => t[x.id]).length };
  }
  function weekStat(p, mon) {
    let total = 0, done = 0;
    const days = [], lifts = {};
    for (let i = 0; i < 7; i++) {
      const d = add(mon, i), s = dayStat(p, d), t = ticks(p, d);
      total += s.total; done += s.done; days.push({ d, ...s });
      Object.keys(t).forEach(k => { if (k.startsWith('lift:') && typeof t[k] === 'string') lifts[k.slice(5)] = t[k]; });
    }
    const bw = ticks(p, mon).bodyweight;
    return { total, done, days, lifts, bw: typeof bw === 'string' ? bw : '' };
  }
  const pct = (a, b) => b ? Math.round(a / b * 100) : null;

  // Weeks the plan covers, Monday first.
  function weeks() {
    const out = [], first = monday(P.blocks[0].from), last = P.blocks[P.blocks.length - 1].to;
    for (let m = first; m <= last; m = add(m, 7)) out.push(m);
    return out;
  }
  function weekLabel(mon) {
    const b = P.blocks.find(x => add(mon, 6) >= x.from && mon <= x.to);
    if (!b) return 'Between blocks';
    const n = Math.floor((parse(mon) - parse(monday(b.from))) / DAY / 7) + 1;
    return `${b.name} · Week ${n}`;
  }

  // ---- calls ----
  async function call(body) {
    const { data: { session } } = await sb.auth.getSession();
    if (!session) throw new Error('Please sign in');
    const r = await fetch(FN, { method: 'POST', headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY, Authorization: 'Bearer ' + session.access_token }, body: JSON.stringify(body) });
    const j = await r.json().catch(() => ({}));
    if (!r.ok) { const e = new Error(j.error || 'Something went wrong'); e.status = r.status; throw e; }
    return j;
  }

  async function load() {
    centre('<p class="muted">Loading the squad…</p>');
    try { D = await call({ action: 'load' }); }
    catch (e) {
      if (e.status === 403) return centre(`<h2>Admins only</h2><p class="muted">${esc(e.message)}</p><button class="btn" id="out">Sign out</button>`);
      return centre(`<h2>Could not load</h2><p class="muted">${esc(e.message)}</p><button class="btn" id="retry">Try again</button>`);
    }
    Object.keys(tickOf).forEach(k => delete tickOf[k]);
    Object.keys(savedAt).forEach(k => delete savedAt[k]);
    D.ticks.forEach(r => {
      (tickOf[r.user_id] = tickOf[r.user_id] || {})[r.day] = r.ticks || {};
      if (!savedAt[r.user_id] || r.updated_at > savedAt[r.user_id]) savedAt[r.user_id] = r.updated_at;
    });
    P = planner(D.plan && D.plan.plan);
    const ws = weeks();
    if (!ws.includes(week)) week = monday(todayIso()) < ws[0] ? ws[0] : ws[ws.length - 1];
    render();
  }

  // ---- drawing ----
  function centre(html) { $('#app').innerHTML = `<div class="centre"><div class="box">${html}</div></div>`; }

  function shell(body) {
    const tab = (k, l) => `<button class="tab${view === k ? ' on' : ''}" data-view="${k}">${l}</button>`;
    $('#app').innerHTML = `
      <header class="top"><div class="top-in">
        <img src="../../images/clontarf-crest.png" alt="">
        <div class="tt"><div class="club">Clontarf GAA · Senior Football</div><h1>Diary dashboard</h1></div>
        <div class="me"><span>${esc(D.me)}</span><button class="link" id="out">Sign out</button></div>
      </div>
      <nav class="tabs">${tab('squad', 'Squad')}${player ? tab('player', esc(name(player))) : ''}${tab('admins', 'Admins')}<button class="tab" id="reload" title="Load the latest">↻ Refresh</button></nav></header>
      <main class="wrap">${msg ? `<p class="msg">${esc(msg)}</p>` : ''}${body}</main>
      <p class="foot">Plan ${D.plan ? `published from the coaches' sheet ${esc(short(D.plan.published_at.slice(0, 10)))}${D.plan.published_by ? ' by ' + esc(D.plan.published_by) : ''}` : 'from plan.js (not published from the sheet yet)'}. Session ticks only; exercise ticks inside a session are not counted.</p>`;
    msg = '';
  }

  function weekNav() {
    const ws = weeks(), i = ws.indexOf(week);
    return `<div class="weeknav">
      <button class="nav" data-week="${ws[i - 1] || ''}" ${i > 0 ? '' : 'disabled'} aria-label="Previous week">‹</button>
      <div><b>${esc(weekLabel(week))}</b><span>${short(week)} to ${short(add(week, 6))}</span></div>
      <button class="nav" data-week="${ws[i + 1] || ''}" ${i < ws.length - 1 ? '' : 'disabled'} aria-label="Next week">›</button>
      ${week !== monday(todayIso()) && ws.includes(monday(todayIso())) ? `<button class="small" data-week="${monday(todayIso())}">This week</button>` : ''}
    </div>`;
  }

  function cell(s, d, t) {
    if (!s.total) return '<td class="c none">–</td>';
    const today = todayIso();
    const cls = s.done === s.total ? 'full' : s.done ? 'part' : d < today ? 'miss' : 'due';
    const tip = s.items.map(x => `${t[x.id] ? '✓' : '·'} ${x.name}`).join('\n');
    return `<td class="c ${cls}" title="${esc(tip)}">${s.done}/${s.total}</td>`;
  }

  function squad() {
    const rows = D.players.map(p => ({ p, w: weekStat(p, week) }));
    const liftIds = [...new Set(rows.flatMap(r => Object.keys(r.w.lifts)))];
    // Lifts planned this week, so their columns show even before anyone logs.
    for (let i = 0; i < 7; i++) (D.players[0] ? P.items(D.players[0].email, add(week, i)) : []).forEach(x => { if (x.s.track && !liftIds.includes(x.s.track.id)) liftIds.push(x.s.track.id); });
    const sorters = {
      name: (a, b) => name(a.p).localeCompare(name(b.p)),
      done: (a, b) => (pct(b.w.done, b.w.total) ?? -1) - (pct(a.w.done, a.w.total) ?? -1) || sorters.name(a, b),
      least: (a, b) => (pct(a.w.done, a.w.total) ?? 101) - (pct(b.w.done, b.w.total) ?? 101) || sorters.name(a, b),
      recent: (a, b) => String(savedAt[b.p.user_id] || '').localeCompare(String(savedAt[a.p.user_id] || ''))
    };
    rows.sort(sorters[sortBy]);

    const planned = rows.reduce((a, r) => a + r.w.total, 0), done = rows.reduce((a, r) => a + r.w.done, 0);
    const active = rows.filter(r => r.w.done || r.w.bw || Object.keys(r.w.lifts).length).length;
    const bws = rows.filter(r => r.w.bw).length;
    const tile = (n, l) => `<div class="tile"><b>${n}</b><span>${l}</span></div>`;

    const head = `<tr><th class="nm">Player</th>${DOW.map((x, i) => `<th class="c${add(week, i) === todayIso() ? ' today' : ''}">${x}<small>${+add(week, i).slice(8)}</small></th>`).join('')}
      <th class="c">Week</th><th>Bodyweight</th>${liftIds.map(id => `<th>${esc(liftName(id))}</th>`).join('')}<th>Last saved</th></tr>`;
    const body = rows.map(({ p, w }) => {
      const pc = pct(w.done, w.total);
      return `<tr data-player="${esc(p.user_id)}">
        <td class="nm"><b>${esc(name(p))}</b>${p.medical_notes ? ' <span class="flag" title="Has injury or medical notes">✚</span>' : ''}</td>
        ${w.days.map(s => cell(s, s.d, ticks(p, s.d))).join('')}
        <td class="c wk"><b>${w.done}/${w.total}</b>${pc !== null ? `<div class="bar"><i style="width:${pc}%"></i></div>` : ''}</td>
        <td>${w.bw ? esc(w.bw) + ' kg' : '<span class="muted">–</span>'}</td>
        ${liftIds.map(id => `<td>${w.lifts[id] ? esc(w.lifts[id]) : '<span class="muted">–</span>'}</td>`).join('')}
        <td class="muted">${esc(ago(savedAt[p.user_id]))}</td></tr>`;
    }).join('');

    shell(`${weekNav()}
      <div class="tiles">${tile(D.players.length, 'players signed up')}${tile(active, 'logged something this week')}${tile(planned ? pct(done, planned) + '%' : '–', `sessions ticked (${done} of ${planned})`)}${tile(bws, 'Monday bodyweights')}</div>
      <section class="card">
        <div class="ch"><h2>Squad this week</h2>
          <label class="sort">Sort <select id="sort">
            ${[['name', 'Name'], ['done', 'Most done'], ['least', 'Least done'], ['recent', 'Last saved']].map(([k, l]) => `<option value="${k}"${sortBy === k ? ' selected' : ''}>${l}</option>`).join('')}
          </select></label></div>
        ${D.players.length ? `<div class="scroll"><table class="grid">${head}${body}</table></div>
        <p class="legend"><span class="c full">all done</span><span class="c part">some done</span><span class="c miss">none, day passed</span><span class="c due">to do</span> Tap a player for their history.</p>`
        : '<p class="muted">No players have signed in to the diary yet.</p>'}
      </section>`);
  }

  function playerView() {
    const p = player;
    const ws = weeks().filter(m => m <= monday(todayIso()));
    const stats = ws.map(m => ({ m, w: weekStat(p, m) }));
    const liftIds = [...new Set(stats.flatMap(s => Object.keys(s.w.lifts)))];
    const info = [['Email', p.email], ['Phone', p.phone], ['Date of birth', p.date_of_birth], ['Emergency contact', [p.emergency_name, p.emergency_phone].filter(Boolean).join(' · ')], ['Joined the diary', p.created_at && short(p.created_at.slice(0, 10))]]
      .filter(([, v]) => v).map(([k, v]) => `<div><span>${k}</span><b>${esc(v)}</b></div>`).join('');
    const w = weekStat(p, week);
    const days = w.days.filter(s => s.total).map(s => {
      const t = ticks(p, s.d);
      return `<li><span class="dd">${DOW[dow(s.d) - 1]} ${+s.d.slice(8)}</span><span>${s.items.map(x => `<span class="chip ${t[x.id] ? 'yes' : s.d < todayIso() ? 'no' : ''}">${t[x.id] ? '✓' : '○'} ${esc(x.name)}</span>`).join('')}</span></li>`;
    }).join('');

    shell(`<section class="card"><h2>${esc(name(p))}</h2><div class="info">${info}</div>
        ${p.medical_notes ? `<div class="med"><span>Injuries or medical notes</span><p>${esc(p.medical_notes)}</p></div>` : ''}</section>
      <section class="card"><h2>Week by week</h2>
        ${stats.length ? `<div class="scroll"><table class="grid hist"><tr><th class="nm">Week</th><th class="c">Sessions</th><th>Bodyweight</th>${liftIds.map(id => `<th>${esc(liftName(id))}</th>`).join('')}</tr>
        ${stats.slice().reverse().map(({ m, w }) => { const pc = pct(w.done, w.total); return `<tr data-week="${m}" class="${m === week ? 'on' : ''}"><td class="nm"><b>${esc(weekLabel(m))}</b><small>${short(m)}</small></td>
          <td class="c wk"><b>${w.done}/${w.total}</b>${pc !== null ? `<div class="bar"><i style="width:${pc}%"></i></div>` : ''}</td>
          <td>${w.bw ? esc(w.bw) + ' kg' : '<span class="muted">–</span>'}</td>
          ${liftIds.map(id => `<td>${w.lifts[id] ? esc(w.lifts[id]) : '<span class="muted">–</span>'}</td>`).join('')}</tr>`; }).join('')}</table></div>`
        : '<p class="muted">The plan has not started yet.</p>'}
      </section>
      <section class="card">${weekNav()}<ul class="daylist">${days || '<li class="muted">Nothing planned this week.</li>'}</ul></section>`);
  }

  function adminsView() {
    shell(`<section class="card"><h2>Diary admins</h2>
      <p class="muted">These people can sign in here and see every player's diary. They sign in with the CoachSmart login for the email below.</p>
      <ul class="admins">${D.admins.map(a => `<li><span><b>${esc(a.email)}</b><small>${a.added_by && a.added_by !== 'setup' ? 'added by ' + esc(a.added_by) : ''}</small></span>
        ${a.email === D.me ? '<span class="muted">you</span>' : `<button class="small danger" data-remove="${esc(a.email)}">Remove</button>`}</li>`).join('')}</ul>
      <form id="add" class="add"><input name="email" type="email" placeholder="coach@email.com" required><button class="btn" type="submit">Add admin</button></form>
    </section>`);
  }

  function render() {
    if (view === 'player' && player) playerView();
    else if (view === 'admins') adminsView();
    else { view = 'squad'; squad(); }
  }

  // ---- sign in ----
  function signIn(err = '') {
    centre(`<img src="../../images/clontarf-crest.png" alt="" class="crest">
      <h2>Diary dashboard</h2><p class="muted">For senior diary admins. Sign in with your CoachSmart email and password.</p>
      ${err ? `<p class="err">${esc(err)}</p>` : ''}
      <form id="signin"><label>Email<input name="email" type="email" autocomplete="email" required></label>
      <label>Password<input name="password" type="password" autocomplete="current-password" required></label>
      <button class="btn" type="submit">Sign in</button></form>`);
  }

  // ---- events ----
  document.addEventListener('submit', async e => {
    e.preventDefault();
    const f = e.target, b = f.querySelector('button[type=submit]');
    if (f.id === 'signin') {
      b.disabled = true; b.textContent = 'Signing in…';
      const { error } = await sb.auth.signInWithPassword({ email: f.email.value.trim(), password: f.password.value });
      if (error) signIn(/invalid/i.test(error.message) ? 'That email and password did not match a CoachSmart account.' : error.message);
    }
    if (f.id === 'add') {
      b.disabled = true;
      try { D.admins = (await call({ action: 'admin_add', email: f.email.value })).admins; msg = 'Added. They can sign in here now.'; }
      catch (err) { msg = err.message; }
      render();
    }
  });
  document.addEventListener('click', async e => {
    const t = e.target;
    if (t.closest('#out')) { await sb.auth.signOut(); location.reload(); return; }
    if (t.closest('#retry') || t.closest('#reload')) { load(); return; }
    const v = t.closest('[data-view]'); if (v) { view = v.dataset.view; render(); return; }
    const w = t.closest('[data-week]'); if (w && w.dataset.week) { week = w.dataset.week; render(); return; }
    const pr = t.closest('[data-player]');
    if (pr) { player = D.players.find(p => p.user_id === pr.dataset.player); view = 'player'; render(); window.scrollTo(0, 0); return; }
    const rm = t.closest('[data-remove]');
    if (rm && confirm(`Remove ${rm.dataset.remove} as a diary admin?`)) {
      try { D.admins = (await call({ action: 'admin_remove', email: rm.dataset.remove })).admins; } catch (err) { msg = err.message; }
      render();
    }
  });
  document.addEventListener('change', e => { if (e.target.id === 'sort') { sortBy = e.target.value; render(); } });

  async function boot() {
    if (!window.supabase) await new Promise(r => { const s = document.createElement('script'); s.src = SDK; s.onload = s.onerror = r; document.head.appendChild(s); });
    if (!window.supabase) return centre('<p class="err">Could not load the sign-in. Please refresh.</p>');
    sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    let started = false;
    sb.auth.onAuthStateChange((ev, session) => {
      if (session && session.user && !started) { started = true; load(); }
    });
    const { data: { session } } = await sb.auth.getSession();
    if (!session) signIn();
  }
  boot();
})();
