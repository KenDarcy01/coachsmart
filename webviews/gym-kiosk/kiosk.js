/* Gym attendance kiosk.
 *
 * Runs full screen on a tablet in the gym (Android Chrome, installed to the home screen
 * and pinned). Members pick today's S&C session (or Open gym), tap their name or scan
 * their QR code, and are checked in. Talks only to the gym-kiosk edge function.
 *
 * Setup: a club admin signs in once, picks the club and sets a coach PIN. The tablet
 * then keeps a device token; the club can only be changed by an admin removing the
 * tablet (coach mode → Remove this tablet) and setting it up again.
 *
 * Offline: today's sessions and names are kept in localStorage and refreshed every
 * minute. Check-ins go into a local queue and are sent when online; each has its own
 * id (client_uuid) so sending one twice never stores it twice.
 *
 * Privacy: names are shown as "Ken D" (the server makes them); no photos, no member
 * codes, no dates of birth ever reach the tablet.
 */
(function () {
  'use strict';

  const API = 'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/gym-kiosk';
  const ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4';
  const TZ = 'Europe/Dublin';
  const IDLE_MS = 30000;          // back to the session list after this long untouched
  const DONE_MS = 3500;           // how long the "checked in" screen stays up
  const SYNC_MS = 15000;          // try to send queued check-ins this often
  const REFRESH_MS = 60000;       // refresh today's data this often

  const K = { token: 'gk.token', boot: 'gk.boot', queue: 'gk.queue', mine: 'gk.mine', problems: 'gk.problems' };
  const load = (k, d) => { try { const v = JSON.parse(localStorage.getItem(k)); return v == null ? d : v; } catch (_) { return d; } };
  const save = (k, v) => localStorage.setItem(k, JSON.stringify(v));

  const app = document.getElementById('app');
  const S = {
    token: localStorage.getItem(K.token) || '',
    boot: load(K.boot, null),
    queue: load(K.queue, []),        // check-ins not yet accepted by the server
    mine: load(K.mine, []),          // check-ins made on this tablet today: { client_uuid, event_id, member_id, at, synced }
    problems: load(K.problems, []),  // check-ins the server refused, shown in coach mode
    online: navigator.onLine,
    lastSync: 0,
    syncing: false,
    view: 'home',
    eventKey: null,                  // event_id or 'open'
    coachPin: '',
  };

  // ── Utilities ──────────────────────────────────────────────────────────
  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const h = (html) => { const t = document.createElement('template'); t.innerHTML = html.trim(); return t.content.firstElementChild; };
  const uuid = () => (crypto.randomUUID ? crypto.randomUUID() : 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
    const r = crypto.getRandomValues(new Uint8Array(1))[0] & 15; return (c === 'x' ? r : (r & 3) | 8).toString(16);
  }));
  const dublinDate = d => new Intl.DateTimeFormat('en-CA', { timeZone: TZ, year: 'numeric', month: '2-digit', day: '2-digit' }).format(d);
  const fmtTime = iso => new Intl.DateTimeFormat('en-IE', { timeZone: TZ, hour: '2-digit', minute: '2-digit', hour12: false }).format(new Date(iso));
  const fmtDay = d => new Intl.DateTimeFormat('en-IE', { timeZone: TZ, weekday: 'long', day: 'numeric', month: 'long' }).format(d);
  const initials = n => String(n || '?').split(' ').map(p => p[0] || '').join('').slice(0, 2).toUpperCase();
  const AV = ['#3b6fd8', '#8c4bd6', '#c2477d', '#d0602c', '#2b9a8d', '#5b8c2a', '#b5841c', '#4a5a7a'];
  const avColour = n => { let x = 0; for (const c of String(n)) x = (x * 31 + c.charCodeAt(0)) >>> 0; return AV[x % AV.length]; };
  const keyOf = (eventId, memberId) => `${eventId == null ? 'open' : eventId}:${memberId}`;
  const ICON = {
    back: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M15 18l-6-6 6-6"/></svg>',
    tick: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6L9 17l-5-5"/></svg>',
    bigTick: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10.5"/><path d="M7 12.5l3.2 3.2L17 9"/></svg>',
    info: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><circle cx="12" cy="12" r="10.5"/><path d="M12 11v6M12 7.5v.01"/></svg>',
    qr: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><path d="M14 14h3v3M21 14v.01M14 21h3M21 18v3M17 21v.01"/></svg>',
  };

  async function api(action, body = {}) {
    const res = await fetch(API, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: ANON, Authorization: `Bearer ${ANON}`, 'x-kiosk-token': S.token },
      body: JSON.stringify({ action, ...body }),
    });
    let data = {};
    try { data = await res.json(); } catch (_) {}
    if (!res.ok) {
      const e = new Error(data.error || `Error ${res.status}`);
      e.status = res.status; e.code = data.code; throw e;
    }
    return data;
  }

  // ── Data helpers ───────────────────────────────────────────────────────
  const today = () => dublinDate(new Date());
  const members = () => (S.boot && S.boot.members) || [];
  const memberById = id => members().find(m => m.id === id);
  const team = id => ((S.boot && S.boot.teams) || []).find(t => t.team_id === id);
  const squad = id => { for (const t of (S.boot && S.boot.teams) || []) { const s = t.squads.find(x => x.squad_id === id); if (s) return s; } return null; };
  const events = () => (S.boot && S.boot.today === today() ? S.boot.events : []) || [];
  const eventById = id => events().find(e => e.event_id === id);

  /** Everyone checked in today, from the server plus this tablet's queue. Map key → { client_uuid, mine, at } */
  function checkedIn() {
    const out = new Map();
    if (S.boot && S.boot.today === today()) {
      for (const c of S.boot.checkins || []) out.set(keyOf(c.event_id, c.member_id), { client_uuid: c.client_uuid, at: c.checked_in_at });
    }
    for (const q of S.queue) if (dublinDate(new Date(q.checked_in_at)) === today() && q.member_id) out.set(keyOf(q.event_id, q.member_id), { client_uuid: q.client_uuid, at: q.checked_in_at, pending: true });
    return out;
  }
  const countFor = eventKey => { let n = 0; for (const k of checkedIn().keys()) if (k.startsWith(`${eventKey}:`)) n++; return n; };

  function pruneOld() {
    const t = today();
    S.mine = S.mine.filter(m => dublinDate(new Date(m.at)) === t);
    S.problems = S.problems.filter(p => Date.now() - new Date(p.at).getTime() < 7 * 864e5);
    save(K.mine, S.mine); save(K.problems, S.problems);
  }

  // ── Sync ───────────────────────────────────────────────────────────────
  async function refresh() {
    if (!S.token) return;
    try {
      const b = await api('bootstrap');
      S.boot = b; save(K.boot, b);
      S.online = true; S.lastSync = Date.now();
      applyClubColours();
    } catch (e) {
      if (e.status === 401 && e.code === 'unpaired') return unpairedLocally();
      S.online = false;
    }
    if (S.view === 'home' && !document.querySelector('.overlay, .success, .scanner')) render(); else updateSyncPill();
  }

  async function flush() {
    if (!S.token || S.syncing || !S.queue.length) return;
    S.syncing = true;
    try {
      const batch = S.queue.slice(0, 100);
      const { results } = await api('checkin', { items: batch });
      const byId = new Map(results.map(r => [r.client_uuid, r]));
      for (const item of batch) {
        const r = byId.get(item.client_uuid);
        if (!r) continue;
        S.queue = S.queue.filter(q => q.client_uuid !== item.client_uuid);
        const mine = S.mine.find(m => m.client_uuid === item.client_uuid);
        if (r.ok) {
          if (mine) { mine.synced = true; mine.member_id = r.member_id; mine.event_id = r.event_id; mine.name = r.name; }
          if (S.boot && !(S.boot.checkins || []).some(c => c.client_uuid === (r.original_client_uuid || item.client_uuid))) {
            (S.boot.checkins ||= []).push({ client_uuid: r.original_client_uuid || item.client_uuid, event_id: r.event_id, member_id: r.member_id, checked_in_at: item.checked_in_at });
          }
        } else if (r.code !== 'error') {
          // Refused for good (unknown QR, not on an S&C team...). Keep a note for the coach.
          S.mine = S.mine.filter(m => m.client_uuid !== item.client_uuid);
          S.problems.unshift({ at: item.checked_in_at, what: r.error, method: item.method });
        } else {
          S.queue.push(item); // server hiccup: try again later
        }
      }
      save(K.queue, S.queue); save(K.mine, S.mine); save(K.problems, S.problems);
      if (S.boot) save(K.boot, S.boot);
      S.online = true; S.lastSync = Date.now();
    } catch (e) {
      if (e.status === 401 && e.code === 'unpaired') { S.syncing = false; return unpairedLocally(); }
      S.online = false;
    }
    S.syncing = false;
    updateSyncPill();
    if (S.queue.length && S.online) setTimeout(flush, 500);
  }

  function enqueue(item) {
    S.queue.push(item); save(K.queue, S.queue);
    S.mine.push({ client_uuid: item.client_uuid, event_id: item.event_id === 'auto' ? undefined : item.event_id, member_id: item.member_id, at: item.checked_in_at, synced: false });
    save(K.mine, S.mine);
  }

  function unpairedLocally() {
    localStorage.removeItem(K.token); S.token = '';
    go('setup');
  }

  // ── Club colours ───────────────────────────────────────────────────────
  function lum(hex) {
    const m = /^#?([0-9a-f]{6})$/i.exec(hex || ''); if (!m) return 0;
    const [r, g, b] = [0, 2, 4].map(i => parseInt(m[1].slice(i, i + 2), 16) / 255).map(c => (c <= .03928 ? c / 12.92 : ((c + .055) / 1.055) ** 2.4));
    return .2126 * r + .7152 * g + .0722 * b;
  }
  function applyClubColours() {
    const c = (S.boot && S.boot.club && S.boot.club.colours) || [];
    const valid = x => /^#[0-9a-f]{6}$/i.test(x || '');
    const root = document.documentElement.style;
    const primary = valid(c[0]) ? c[0] : '#3b6fd8';
    root.setProperty('--club', primary);
    root.setProperty('--club-2', valid(c[1]) ? c[1] : '#ffffff');
    root.setProperty('--club-3', valid(c[2]) ? c[2] : primary);
    root.setProperty('--on-club', lum(primary) > .45 ? '#111111' : '#ffffff');
    if (S.boot && S.boot.club) document.title = `${S.boot.club.name} gym check-in`;
  }

  // ── Idle timer ─────────────────────────────────────────────────────────
  let idleTimer = null;
  function poke() {
    clearTimeout(idleTimer);
    if (S.view !== 'home' && S.view !== 'setup' && S.view !== 'coach') idleTimer = setTimeout(() => { closeScanner(); closeOverlays(); go('home'); }, IDLE_MS);
  }
  ['pointerdown', 'keydown', 'input'].forEach(ev => document.addEventListener(ev, poke, { passive: true }));

  // ── Rendering ──────────────────────────────────────────────────────────
  function go(view, opts = {}) {
    closeOverlays();
    S.view = view;
    if ('eventKey' in opts) S.eventKey = opts.eventKey;
    render(); poke();
  }

  function render() {
    app.innerHTML = '';
    if (!S.token) return renderSetup();
    if (S.view === 'picker') return renderPicker();
    if (S.view === 'coach') return renderCoach();
    return renderHome();
  }

  function bar({ back, title, sub } = {}) {
    const club = (S.boot && S.boot.club) || {};
    const crest = club.crest ? `<img class="crest" src="${esc(club.crest)}" alt="" draggable="false">` : '<div class="crest-blank"></div>';
    const el = h(`<header class="bar">
      ${back ? `<button class="back" data-back>${ICON.back}<span>Sessions</span></button>` : ''}
      <div class="crest-hold">${crest}</div>
      <div class="title"><h1>${esc(title || club.name || 'Gym check-in')}</h1><div class="sub">${esc(sub || 'Gym check-in')}</div></div>
      <span class="sync"><i></i><span></span></span>
      <div class="clock"></div>
    </header>`);
    if (back) el.querySelector('[data-back]').onclick = () => go('home');
    // Coach mode: press and hold the crest for 2 seconds.
    const hold = el.querySelector('.crest-hold');
    let t = null;
    hold.addEventListener('pointerdown', () => { t = setTimeout(openCoachPin, 2000); });
    ['pointerup', 'pointerleave', 'pointercancel'].forEach(ev => hold.addEventListener(ev, () => clearTimeout(t)));
    hold.addEventListener('contextmenu', e => e.preventDefault());
    hold.addEventListener('touchstart', e => e.preventDefault(), { passive: false }); // no iOS image menu
    return el;
  }

  function updateSyncPill() {
    const pill = document.querySelector('.sync'); if (!pill) return;
    const n = S.queue.length;
    pill.classList.toggle('off', !S.online);
    pill.querySelector('span').textContent = !S.online
      ? (n ? `Offline · ${n} waiting to sync` : 'Offline')
      : (n ? `Syncing ${n}…` : 'Online');
  }
  function tickClock() {
    const c = document.querySelector('.clock');
    if (c) c.textContent = new Intl.DateTimeFormat('en-IE', { timeZone: TZ, hour: '2-digit', minute: '2-digit', hour12: false }).format(new Date());
  }

  // Home: today's sessions
  function renderHome() {
    S.eventKey = null;
    app.append(bar({ sub: fmtDay(new Date()) }));
    const main = h('<main></main>');
    const evs = events();
    const now = Date.now();
    // "Now" = any session that started up to 2 hours ago or starts within the hour (several teams can be in at once).
    const liveIds = new Set(evs.filter(e => { const t = new Date(e.time).getTime(); return t - now < 3600e3 && now - t < 2 * 3600e3; }).map(e => e.event_id));

    main.append(h(`<div class="h2"><h2>Tap your team's session</h2><span class="muted">${evs.length ? `${evs.length} today` : ''}</span></div>`));
    if (!S.boot) {
      main.append(h('<div class="empty">Loading today\'s sessions…</div>'));
    } else if (!evs.length) {
      main.append(h('<div class="empty">No S&amp;C sessions scheduled today. Use Open gym below.</div>'));
    }
    const tick = ICON.tick.replace('<svg', '<svg width="22" height="22"');
    const tiles = h(`<div class="tiles${evs.length > 4 ? ' many' : ''}"></div>`);
    for (const e of evs) {
      const t = team(e.team_id);
      const sq = e.squad_id ? squad(e.squad_id) : null;
      const n = countFor(e.event_id);
      const isLive = liveIds.has(e.event_id);
      const tile = h(`<button class="tile${isLive ? ' now' : ''}" style="--stripe:${esc((sq && sq.colour) || 'var(--club)')}">
        <span class="tile-top">
          <span class="team">${esc(t ? t.name : 'Team')}</span>
          ${isLive ? '<span class="badge">NOW</span>' : ''}
        </span>
        ${sq ? `<span class="squad"><i style="background:${esc(sq.colour || 'var(--club)')}"></i>${esc(sq.name)}</span>` : '<span class="squad">Whole team</span>'}
        <span class="tile-bottom">
          <span class="when"><b>${esc(fmtTime(e.time))}</b> ${esc(e.title)}${e.location ? ` · ${esc(e.location)}` : ''}</span>
          <span class="count">${n ? `${tick}${n} in` : ''}</span>
        </span>
      </button>`);
      tile.onclick = () => go('picker', { eventKey: e.event_id });
      tiles.append(tile);
    }
    main.append(tiles);
    app.append(main);

    // Always in the same place, however many sessions there are.
    const nOpen = countFor('open');
    const dock = h(`<footer class="dock">
      <button class="dock-btn open"><span class="dock-title">Open gym</span><span class="dock-sub">Not at a team session${nOpen ? ` · ${nOpen} in` : ''}</span></button>
      <button class="dock-btn qr">${ICON.qr}<span class="dock-title">Scan my QR code</span></button>
    </footer>`);
    dock.querySelector('.open').onclick = () => go('picker', { eventKey: 'open' });
    dock.querySelector('.qr').onclick = () => openScanner('auto');
    app.append(dock);
    updateSyncPill(); tickClock();
  }

  // Picker: names for a session
  function pickerPeople() {
    const all = members();
    if (S.eventKey === 'open') {
      // Grouped by team, everyone on the club's S&C teams.
      return ((S.boot && S.boot.teams) || []).map(t => ({
        title: t.name, colour: null,
        people: all.filter(m => m.teams.includes(t.team_id)),
      })).filter(g => g.people.length);
    }
    const e = eventById(S.eventKey); if (!e) return [];
    const t = team(e.team_id);
    const onTeam = all.filter(m => m.teams.includes(e.team_id));
    if (!e.squad_id) return [{ title: t ? t.name : 'Team', people: onTeam }];
    const sq = squad(e.squad_id);
    const inSquad = onTeam.filter(m => m.squads.includes(e.squad_id));
    const rest = onTeam.filter(m => !m.squads.includes(e.squad_id));
    return [
      { title: sq ? sq.name : 'Squad', colour: sq && sq.colour, people: inSquad },
      { title: `Rest of ${t ? t.name : 'the team'}`, colour: null, people: rest },
    ].filter(g => g.people.length);
  }

  function renderPicker() {
    const isOpen = S.eventKey === 'open';
    const e = isOpen ? null : eventById(S.eventKey);
    if (!isOpen && !e) return go('home');
    const t = e && team(e.team_id);
    app.append(bar({ back: true, title: isOpen ? 'Open gym' : `${fmtTime(e.time)} · ${e.title}`, sub: isOpen ? 'Find your name' : `${t ? t.name : ''} · Find your name` }));
    const wrap = h('<div class="picker"></div>');
    const main = h('<main></main>');
    const search = h(`<div class="search"><input type="search" placeholder="Search your name" autocomplete="off" autocorrect="off" spellcheck="false" enterkeyhint="search">
      <button class="qr-small">${ICON.qr}<span>Scan QR</span></button></div>`);
    search.querySelector('.qr-small').onclick = () => openScanner(isOpen ? null : e.event_id);
    const list = h('<div></div>');
    main.append(search, list);
    const az = h('<nav class="az" aria-label="Jump to letter"></nav>');
    wrap.append(main, az);
    app.append(wrap);

    const groups = pickerPeople();
    const draw = () => {
      const q = search.querySelector('input').value.trim().toLowerCase();
      const ins = checkedIn();
      list.innerHTML = '';
      const letters = new Set();
      let any = false;
      for (const g of groups) {
        const ppl = g.people.filter(m => !q || m.name.toLowerCase().split(' ').some(w => w.startsWith(q)) || m.name.toLowerCase().startsWith(q));
        if (!ppl.length) continue;
        any = true;
        const sec = h(`<section class="group"><h3>${g.colour ? `<span class="dot" style="background:${esc(g.colour)}"></span>` : ''}${esc(g.title)} <span class="muted">· ${ppl.length}</span></h3><div class="names"></div></section>`);
        const grid = sec.querySelector('.names');
        for (const m of ppl) {
          const k = keyOf(isOpen ? null : e.event_id, m.id);
          const isIn = ins.has(k);
          const L = m.name[0].toUpperCase();
          const btn = h(`<button class="person${isIn ? ' in' : ''}" data-letter="${esc(L)}">
            <span class="av" style="background:${avColour(m.name)}">${esc(initials(m.name))}</span>
            <span class="nm">${esc(m.name)}</span>${isIn ? `<span class="tick">${ICON.tick}</span>` : ''}</button>`);
          if (!letters.has(L)) { btn.id = `L-${L}`; letters.add(L); }
          btn.onclick = () => { if (btn.dataset.held) { delete btn.dataset.held; return; } isIn ? showAlready(m, ins.get(k)) : confirmTap(m, isOpen ? null : e.event_id); };
          if (isIn) onLongPress(btn, () => confirmUndo(m, ins.get(k)));
          grid.append(btn);
        }
        list.append(sec);
      }
      if (!any) list.append(h(`<div class="empty">${q ? 'No one matches that. Check the spelling, or ask a coach.' : 'No members to show for this session.'}</div>`));
      az.innerHTML = '';
      for (const L of 'ABCDEFGHIJKLMNOPQRSTUVWXYZ') {
        const b = h(`<button class="${letters.has(L) ? 'has' : ''}">${L}</button>`);
        b.onclick = () => { const el = document.getElementById(`L-${L}`); if (el) el.scrollIntoView({ block: 'start', behavior: 'smooth' }); };
        az.append(b);
      }
    };
    search.querySelector('input').addEventListener('input', draw);
    draw();
    updateSyncPill(); tickClock();
  }

  // ── Check-in flow ──────────────────────────────────────────────────────
  function overlay(inner) {
    closeOverlays();
    const o = h(`<div class="overlay" role="dialog" aria-modal="true">${inner}</div>`);
    o.addEventListener('click', ev => { if (ev.target === o) o.remove(); });
    document.body.append(o);
    return o;
  }
  function closeOverlays() { document.querySelectorAll('.overlay, .success').forEach(x => x.remove()); clearTimeout(doneTimer); }

  function confirmTap(m, eventId) {
    const e = eventId == null ? null : eventById(eventId);
    const o = overlay(`<div class="card">
      <div class="big-av" style="background:${avColour(m.name)}">${esc(initials(m.name))}</div>
      <p>Is this you?</p><h2>${esc(m.name)}</h2>
      <p>${e ? `${esc(fmtTime(e.time))} · ${esc(e.title)}` : 'Open gym'}</p>
      <div class="actions"><button class="btn ghost" data-no>No</button><button class="btn primary" data-yes>Yes, check me in</button></div></div>`);
    o.querySelector('[data-no]').onclick = () => o.remove();
    o.querySelector('[data-yes]').onclick = () => {
      const item = { client_uuid: uuid(), event_id: eventId, member_id: m.id, method: 'tap', checked_in_at: new Date().toISOString() };
      enqueue(item);
      showDone({ name: m.name, where: e ? `${fmtTime(e.time)} · ${e.title}` : 'Open gym', clientUuid: item.client_uuid });
      flush();
    };
  }

  let doneTimer = null;
  function showDone({ name, where, clientUuid, kind = 'ok', title, icon }) {
    closeOverlays();
    const el = h(`<div class="success ${kind === 'ok' ? '' : kind}">
      <div>${icon || ICON.bigTick}
      <h2>${esc(title || (name ? `Thanks, ${name.split(' ')[0]}!` : 'Thanks!'))}</h2>
      <p>${kind === 'ok' ? "You're checked in" : ''}</p>
      ${where ? `<p>${esc(where)}</p>` : ''}
      ${clientUuid ? '<button class="undo">Not me? Undo</button>' : ''}</div></div>`);
    if (clientUuid) el.querySelector('.undo').onclick = ev => { ev.stopPropagation(); undoMine(clientUuid); };
    el.onclick = () => { el.remove(); go('home'); };
    document.body.append(el);
    doneTimer = setTimeout(() => { el.remove(); go('home'); }, kind === 'ok' ? DONE_MS : DONE_MS + 1500);
  }

  function showAlready(m, rec) {
    showDone({ kind: 'info', icon: ICON.info, title: `${m.name}, you're already in`, where: `Checked in at ${fmtTime(rec.at)}`, clientUuid: rec && rec.client_uuid });
  }

  /** Press and hold (about 0.7s). Marks the element so the click that follows the hold is ignored. */
  function onLongPress(el, fn, ms = 700) {
    let t = null;
    const cancel = () => clearTimeout(t);
    el.addEventListener('pointerdown', () => { cancel(); t = setTimeout(() => { el.dataset.held = '1'; if (navigator.vibrate) navigator.vibrate(30); fn(); }, ms); });
    ['pointerup', 'pointerleave', 'pointercancel', 'pointermove'].forEach(ev => el.addEventListener(ev, e => { if (ev !== 'pointermove' || Math.abs(e.movementX) + Math.abs(e.movementY) > 6) cancel(); }));
    el.addEventListener('contextmenu', e => e.preventDefault());
  }

  function confirmUndo(m, rec) {
    if (!rec) return;
    const o = overlay(`<div class="card">
      <div class="big-av" style="background:${avColour(m.name)}">${esc(initials(m.name))}</div>
      <p>Undo this check-in?</p><h2>${esc(m.name)}</h2><p>Checked in at ${esc(fmtTime(rec.at))}</p>
      <div class="actions"><button class="btn ghost" data-no>Keep it</button><button class="btn danger" data-yes>Undo check-in</button></div></div>`);
    o.querySelector('[data-no]').onclick = () => o.remove();
    o.querySelector('[data-yes]').onclick = () => undoMine(rec.client_uuid);
  }

  async function undoMine(clientUuid) {
    const queued = S.queue.some(q => q.client_uuid === clientUuid);
    if (queued) {
      S.queue = S.queue.filter(q => q.client_uuid !== clientUuid); save(K.queue, S.queue);
    } else {
      try { await api('undo', { client_uuid: clientUuid }); }
      catch (e) { return showDone({ kind: 'err', icon: ICON.info, title: "Couldn't undo", where: e.status ? 'Ask a coach to undo it.' : 'No connection. Ask a coach to undo it.' }); }
      if (S.boot) S.boot.checkins = (S.boot.checkins || []).filter(c => c.client_uuid !== clientUuid);
      save(K.boot, S.boot);
    }
    S.mine = S.mine.filter(m => m.client_uuid !== clientUuid); save(K.mine, S.mine);
    showDone({ kind: 'info', icon: ICON.info, title: 'Undone', where: 'That check-in has been removed.' });
  }

  // ── QR scanner (Chrome on Android has BarcodeDetector built in) ───────
  let scan = null;
  async function openScanner(eventId) {
    if (!('BarcodeDetector' in window)) {
      return showDone({ kind: 'err', icon: ICON.info, title: 'QR scanning isn\'t available', where: 'Tap your session and find your name instead.' });
    }
    closeScanner();
    const el = h(`<div class="scanner"><video playsinline muted></video><div class="frame"></div>
      <div class="hint">Hold your CoachSmart QR code up to the camera</div>
      <div class="bottom"><button class="btn ghost">Cancel</button></div></div>`);
    document.body.append(el);
    el.querySelector('.btn').onclick = () => closeScanner();
    const video = el.querySelector('video');
    let stream;
    try {
      stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'user', width: { ideal: 1280 }, height: { ideal: 720 } }, audio: false });
    } catch (_) {
      closeScanner();
      return showDone({ kind: 'err', icon: ICON.info, title: 'Camera not available', where: 'Tap your session and find your name instead.' });
    }
    video.srcObject = stream; await video.play().catch(() => {});
    const detector = new window.BarcodeDetector({ formats: ['qr_code'] });
    scan = { el, stream, stop: false };
    const timeout = setTimeout(() => closeScanner(), 45000);
    const loop = async () => {
      if (!scan || scan.stop) return clearTimeout(timeout);
      try {
        const codes = await detector.detect(video);
        if (codes.length && codes[0].rawValue) { clearTimeout(timeout); closeScanner(); return onQr(codes[0].rawValue, eventId); }
      } catch (_) {}
      setTimeout(loop, 180);
    };
    loop();
  }
  function closeScanner() {
    if (!scan) return;
    scan.stop = true; scan.stream.getTracks().forEach(t => t.stop()); scan.el.remove(); scan = null;
  }

  async function onQr(raw, eventId) {
    const code = String(raw).trim();
    if (!/^(CS[-:]?)?[A-Za-z0-9]{4,12}$/.test(code)) {
      return showDone({ kind: 'err', icon: ICON.info, title: "That's not a member QR code", where: 'Open your CoachSmart app and show your gym QR.' });
    }
    const item = { client_uuid: uuid(), event_id: eventId === null ? null : (eventId || 'auto'), member_code: code, method: 'qr', checked_in_at: new Date().toISOString() };
    if (navigator.onLine) {
      try {
        const { results } = await api('checkin', { items: [item] });
        const r = results[0];
        if (r && r.ok) {
          const e = r.event_id ? eventById(r.event_id) : null;
          if (S.boot && !(S.boot.checkins || []).some(c => c.client_uuid === (r.original_client_uuid || item.client_uuid))) {
            (S.boot.checkins ||= []).push({ client_uuid: r.original_client_uuid || item.client_uuid, event_id: r.event_id, member_id: r.member_id, checked_in_at: item.checked_in_at });
            save(K.boot, S.boot);
          }
          if (r.already) return showDone({ kind: 'info', icon: ICON.info, title: `${r.name}, you're already in`, where: e ? `${fmtTime(e.time)} · ${e.title}` : 'Open gym' });
          S.mine.push({ client_uuid: item.client_uuid, event_id: r.event_id, member_id: r.member_id, at: item.checked_in_at, synced: true, name: r.name }); save(K.mine, S.mine);
          return showDone({ name: r.name, where: (e ? `${fmtTime(e.time)} · ${e.title}` : 'Open gym') + (r.converted ? ' (not your team\'s session)' : ''), clientUuid: item.client_uuid });
        }
        if (r && r.code !== 'error') return showDone({ kind: 'err', icon: ICON.info, title: 'Not checked in', where: r.error });
      } catch (e) {
        if (e.status === 401) return unpairedLocally();
        // Fall through to offline handling.
      }
    }
    enqueue(item);
    showDone({ title: 'Thanks!', where: 'Saved on this tablet. It will sync when the Wi-Fi is back.' });
  }

  // ── Coach mode ─────────────────────────────────────────────────────────
  function openCoachPin() {
    if (S.view === 'coach') return;
    let pin = '';
    const o = overlay(`<div class="card"><h2>Coach mode</h2><p>Enter the coach PIN</p>
      <div class="pindots"></div><div class="form"><div class="err"></div></div>
      <div class="pinpad">${[1, 2, 3, 4, 5, 6, 7, 8, 9].map(n => `<button data-n="${n}">${n}</button>`).join('')}<button data-x>✕</button><button data-n="0">0</button><button data-ok>OK</button></div></div>`);
    const dots = o.querySelector('.pindots'); const err = o.querySelector('.err');
    const draw = () => { dots.innerHTML = Array.from({ length: Math.max(4, pin.length) }, (_, i) => `<i class="${i < pin.length ? 'on' : ''}"></i>`).join(''); };
    draw();
    o.querySelectorAll('[data-n]').forEach(b => b.onclick = () => { if (pin.length < 6) { pin += b.dataset.n; draw(); } });
    o.querySelector('[data-x]').onclick = () => { if (pin) { pin = pin.slice(0, -1); draw(); } else o.remove(); };
    o.querySelector('[data-ok]').onclick = async () => {
      err.textContent = '';
      try { await api('coach', { pin }); S.coachPin = pin; o.remove(); go('coach'); }
      catch (e) { err.textContent = e.status ? e.message : 'Coach mode needs a connection.'; pin = ''; draw(); }
    };
  }

  function renderCoach() {
    app.append(bar({ back: true, title: 'Coach mode', sub: `${(S.boot && S.boot.device && S.boot.device.name) || 'This tablet'} · ${fmtDay(new Date())}` }));
    const main = h('<main><div class="coach-grid"><div class="list" data-sessions></div><div data-detail></div></div></main>');
    app.append(main);
    const sessions = main.querySelector('[data-sessions]');
    const detail = main.querySelector('[data-detail]');
    const keys = [...events().map(e => e.event_id), 'open'];
    let sel = S.eventKey && keys.includes(S.eventKey) ? S.eventKey : keys[0];

    const drawSessions = () => {
      sessions.innerHTML = '';
      for (const k of keys) {
        const e = k === 'open' ? null : eventById(k);
        const b = h(`<button class="row" style="${k === sel ? 'border-color:var(--club)' : ''}"><div class="grow"><div><b>${esc(e ? `${fmtTime(e.time)} · ${e.title}` : 'Open gym')}</b></div>
          <div class="small">${esc(e ? (team(e.team_id) || {}).name || '' : 'No session')}</div></div><span class="pill">${countFor(k)} in</span></button>`);
        b.onclick = () => { sel = k; drawSessions(); drawDetail(); };
        sessions.append(b);
      }
      const extra = h(`<div class="list" style="margin-top:1rem">
        <button class="btn ghost" data-refresh>Refresh now</button>
        <div class="small muted" style="text-align:center">${S.queue.length} waiting to sync · last sync ${S.lastSync ? fmtTime(new Date(S.lastSync).toISOString()) : 'not yet'}</div>
        ${S.problems.length ? `<div class="row"><div class="grow"><b>Not saved</b>${S.problems.slice(0, 5).map(p => `<div class="small">${esc(fmtTime(p.at))} · ${esc(p.what)}</div>`).join('')}</div></div>` : ''}
        <button class="btn danger" data-remove>Remove this tablet</button></div>`);
      extra.querySelector('[data-refresh]').onclick = async () => { await flush(); await refresh(); drawSessions(); drawDetail(); toast('Up to date'); };
      extra.querySelector('[data-remove]').onclick = openRemove;
      sessions.append(extra);
    };

    const drawDetail = () => {
      const ins = checkedIn();
      const rows = [];
      for (const [k, v] of ins) {
        const [ek, mid] = k.split(':');
        if (ek !== String(sel)) continue;
        const m = memberById(Number(mid));
        rows.push({ m, v });
      }
      rows.sort((a, b) => new Date(a.v.at) - new Date(b.v.at));
      detail.innerHTML = '';
      detail.append(h(`<div class="h2"><h2>Checked in</h2><span class="muted">${rows.length}</span></div>`));
      const list = h('<div class="list"></div>');
      if (!rows.length) list.append(h('<div class="empty">No one yet.</div>'));
      for (const { m, v } of rows) {
        const r = h(`<div class="row"><span class="person" style="border:0;background:none;padding:0;min-height:0"><span class="av" style="background:${avColour(m ? m.name : '?')}">${esc(initials(m ? m.name : '?'))}</span></span>
          <div class="grow"><b>${esc(m ? m.name : 'Member')}</b><div class="small">${esc(fmtTime(v.at))}${v.pending ? ' · waiting to sync' : ''}</div></div>
          <button class="btn ghost">Undo</button></div>`);
        r.querySelector('button').onclick = async () => {
          if (v.pending) { S.queue = S.queue.filter(q => q.client_uuid !== v.client_uuid); save(K.queue, S.queue); }
          else {
            try { await api('undo', { client_uuid: v.client_uuid, pin: S.coachPin }); }
            catch (e) { return toast(e.status ? e.message : 'Needs a connection'); }
            S.boot.checkins = (S.boot.checkins || []).filter(c => c.client_uuid !== v.client_uuid); save(K.boot, S.boot);
          }
          S.mine = S.mine.filter(x => x.client_uuid !== v.client_uuid); save(K.mine, S.mine);
          drawSessions(); drawDetail(); toast('Undone');
        };
        list.append(r);
      }
      detail.append(list);
    };
    drawSessions(); drawDetail();
    updateSyncPill(); tickClock();
  }

  function openRemove() {
    const o = overlay(`<div class="card"><h2>Remove this tablet</h2><p>A club admin must sign in. The tablet stops working until it is set up again.</p>
      <form class="form" style="margin-top:1rem;text-align:left">
        <label>Admin email<input name="email" type="email" autocomplete="off" required></label>
        <label>Password<input name="password" type="password" autocomplete="off" required></label>
        <div class="err"></div>
        <div class="actions" style="margin-top:0"><button type="button" class="btn ghost" data-cancel>Cancel</button><button class="btn danger">Remove</button></div>
      </form></div>`);
    const f = o.querySelector('form');
    o.querySelector('[data-cancel]').onclick = () => o.remove();
    f.onsubmit = async ev => {
      ev.preventDefault();
      const err = f.querySelector('.err'); err.textContent = '';
      try {
        await api('unpair', { email: f.email.value, password: f.password.value });
        [K.token, K.boot, K.queue, K.mine, K.problems].forEach(k => localStorage.removeItem(k));
        Object.assign(S, { token: '', boot: null, queue: [], mine: [], problems: [] });
        go('setup');
      } catch (e) { err.textContent = e.status ? e.message : 'Needs a connection.'; }
    };
  }

  function toast(msg) {
    const t = h(`<div class="toast">${esc(msg)}</div>`); document.body.append(t); setTimeout(() => t.remove(), 2200);
  }

  // ── Setup (first run) ──────────────────────────────────────────────────
  function renderSetup() {
    S.view = 'setup';
    document.documentElement.style.removeProperty('--club');
    app.append(h(`<header class="bar"><div class="crest-blank"></div><div class="title"><h1>Set up this tablet</h1><div class="sub">Gym check-in</div></div></header>`));
    const main = h(`<main><form class="form">
      <p class="muted">A club admin signs in once. The tablet then shows your club's S&amp;C sessions and its colours. Only a club admin can change or remove it later.</p>
      <label>Tablet name <span class="muted">e.g. Gym door</span><input name="device_name" value="Gym tablet" maxlength="60"></label>
      <label>Admin email<input name="email" type="email" autocomplete="off" required></label>
      <label>Password<input name="password" type="password" autocomplete="off" required></label>
      <label>Coach PIN <span class="muted">4 to 6 digits, for coaches to undo check-ins on this tablet</span><input name="pin" inputmode="numeric" pattern="[0-9]{4,6}" maxlength="6" autocomplete="off" required></label>
      <div class="err"></div>
      <div data-clubs class="list"></div>
      <button class="btn club">Set up tablet</button>
    </form></main>`);
    app.append(main);
    const f = main.querySelector('form');
    const send = async clubId => {
      const err = f.querySelector('.err'); err.textContent = '';
      if (!/^\d{4,6}$/.test(f.pin.value)) { err.textContent = 'The coach PIN must be 4 to 6 digits.'; return; }
      try {
        const r = await api('pair', { email: f.email.value, password: f.password.value, pin: f.pin.value, device_name: f.device_name.value, club_id: clubId });
        if (r.clubs) {
          const box = f.querySelector('[data-clubs]');
          box.innerHTML = '<h2>Which club is this tablet for?</h2>';
          for (const c of r.clubs) {
            const b = h(`<button type="button" class="choice">${c.crest ? `<img src="${esc(c.crest)}" alt="">` : ''}<span>${esc(c.name)}</span></button>`);
            b.onclick = () => send(c.club_id);
            box.append(b);
          }
          return;
        }
        S.token = r.token; localStorage.setItem(K.token, r.token);
        [K.boot, K.queue, K.mine, K.problems].forEach(k => localStorage.removeItem(k));
        Object.assign(S, { boot: null, queue: [], mine: [], problems: [] });
        go('home');
        refresh();
      } catch (e) { err.textContent = e.status ? e.message : 'No connection. Setup needs Wi-Fi.'; }
    };
    f.onsubmit = ev => { ev.preventDefault(); send(); };
  }

  // ── Start ──────────────────────────────────────────────────────────────
  window.addEventListener('online', () => { S.online = true; flush().then(refresh); });
  window.addEventListener('offline', () => { S.online = false; updateSyncPill(); });
  document.addEventListener('visibilitychange', () => { if (!document.hidden) { flush(); refresh(); } });
  setInterval(tickClock, 5000);
  setInterval(() => { flush(); }, SYNC_MS);
  setInterval(() => { if (S.view === 'home') refresh(); }, REFRESH_MS);
  // Keep the screen awake where the browser allows it.
  const wake = () => { if (navigator.wakeLock && !document.hidden) navigator.wakeLock.request('screen').catch(() => {}); };
  document.addEventListener('visibilitychange', wake); document.addEventListener('pointerdown', wake, { once: true });
  if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js').catch(() => {});
  // Day rollover: re-render at midnight so yesterday's sessions disappear.
  let day = today();
  setInterval(() => { if (today() !== day) { day = today(); pruneOld(); refresh(); } }, 60000);

  pruneOld();
  applyClubColours();
  render();
  if (S.token) { flush(); refresh(); }

  window.__kiosk = S; // for debugging from the browser console
})();
