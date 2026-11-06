/* Gym activity dashboard (read-only). Data comes from the gym-dashboard edge function, which
 * decides what this person may see: team admins only (role_grade 100); S&C admins and
 * SuperUsers see the whole club, other admins their own team's players.
 *
 * In the CoachSmart app the page is opened with ?token=<jwt> (cs-auth.js keeps it fresh).
 * In a browser it signs in with the CoachSmart email and password.
 *
 * Views (location.hash): #overview, #sessions, #session-<event_id>, #people.
 * Words used: Came = accepted and checked in; Walk-in = checked in without accepting;
 * No-show = accepted and never checked in (only once the session has started).
 */
(function () {
  'use strict';

  const SUPABASE_URL = 'https://gyfporsbdftvtakdvukt.supabase.co';
  const ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4';
  const FN_URL = SUPABASE_URL + '/functions/v1/gym-dashboard';
  const TZ = 'Europe/Dublin';
  const params = new URLSearchParams(location.search);
  const URL_TOKEN = params.get('token') || params.get('currentAuthToken') || '';
  const STANDALONE = !URL_TOKEN && !window.FlutterBridge;
  const TEAM_COLOURS = ['#0357a3', '#e61e28', '#1e9a4a', '#8e44ad', '#d97706', '#0e7490', '#be185d', '#4d7c0f'];

  const $app = document.getElementById('app');
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  let sb = null;      // supabase-js client (browser only)
  let D = null;       // payload from the edge function
  const UI = { range: 'week', team: 'all', peopleSort: 'name', peopleQ: '', clubId: 0 };
  try { Object.assign(UI, JSON.parse(localStorage.getItem('gymDash') || '{}')); } catch (_) {}
  const saveUI = () => { try { localStorage.setItem('gymDash', JSON.stringify({ range: UI.range, team: UI.team, peopleSort: UI.peopleSort, clubId: UI.clubId })); } catch (_) {} };

  // ── Dates (all as Dublin YYYY-MM-DD strings) ───────────────────────────────
  const dDate = d => new Intl.DateTimeFormat('en-CA', { timeZone: TZ, year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date(d));
  const addDays = (s, n) => { const d = new Date(s + 'T12:00:00Z'); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10); };
  const monday = s => addDays(s, -((new Date(s + 'T12:00:00Z').getUTCDay() + 6) % 7));
  const daysBetween = (a, b) => Math.round((new Date(b + 'T12:00:00Z') - new Date(a + 'T12:00:00Z')) / 864e5);
  const fmtDay = s => new Date(s + 'T12:00:00Z').toLocaleDateString('en-IE', { weekday: 'short', day: 'numeric', month: 'short', timeZone: 'UTC' });
  const fmtLong = s => new Date(s + 'T12:00:00Z').toLocaleDateString('en-IE', { weekday: 'long', day: 'numeric', month: 'long', timeZone: 'UTC' });
  const fmtShort = s => new Date(s + 'T12:00:00Z').toLocaleDateString('en-IE', { day: 'numeric', month: 'short', timeZone: 'UTC' });
  const fmtTime = iso => new Date(iso).toLocaleTimeString('en-IE', { hour: '2-digit', minute: '2-digit', timeZone: TZ });
  const today = () => dDate(Date.now());

  const RANGES = {
    week: { label: 'This week', span: () => { const m = monday(today()); return [m, addDays(m, 6)]; } },
    last: { label: 'Last week', span: () => { const m = addDays(monday(today()), -7); return [m, addDays(m, 6)]; } },
    '4w': { label: 'Last 4 weeks', span: () => { const m = monday(today()); return [addDays(m, -21), addDays(m, 6)]; } },
    '12w': { label: 'Last 12 weeks', span: () => { const m = monday(today()); return [addDays(m, -77), addDays(m, 6)]; } },
  };
  if (!RANGES[UI.range]) UI.range = 'week';
  const rangeLabel = () => { const [a, b] = RANGES[UI.range].span(); return `${RANGES[UI.range].label} · ${fmtShort(a)} – ${fmtShort(b)}`; };

  // ── Indexes built once per load ────────────────────────────────────────────
  let memberById, teamById, eventById, ckByEvent, ckByMember, teamColour;
  function index() {
    memberById = new Map(D.members.map(m => [m.id, m]));
    teamById = new Map(D.teams.map(t => [t.team_id, t]));
    eventById = new Map(D.events.map(e => [e.event_id, e]));
    teamColour = new Map(D.teams.map((t, i) => [t.team_id, TEAM_COLOURS[i % TEAM_COLOURS.length]]));
    ckByEvent = new Map(); ckByMember = new Map();
    for (const c of D.checkins) {
      if (c.event_id) { if (!ckByEvent.has(c.event_id)) ckByEvent.set(c.event_id, []); ckByEvent.get(c.event_id).push(c); }
      if (!ckByMember.has(c.member_id)) ckByMember.set(c.member_id, []);
      ckByMember.get(c.member_id).push(c);
    }
    if (UI.team !== 'all' && !teamById.has(Number(UI.team))) UI.team = 'all';
  }
  const teamName = id => teamById.get(id)?.name || '';
  const dot = id => id ? `<span class="teamdot" style="background:${teamColour.get(id) || '#999'}"></span>` : '';
  const teamCell = id => id ? `${dot(id)}${esc(teamName(id))}` : '<span class="muted">Any team</span>';
  const name = id => memberById.get(id)?.name || 'Member';

  // The team filter: a member counts when they're on the team, or the session is the team's own.
  const teamF = () => UI.team === 'all' ? 0 : Number(UI.team);
  const memberIn = (id, ev) => { const t = teamF(); if (!t) return true; if (ev && ev.team_id === t) return true; return !!memberById.get(id)?.teams.includes(t); };
  const started = e => new Date(e.time).getTime() <= Date.now();

  /** Who came, walked in, didn't show, for one session (team filter applied). */
  function sessionStats(e) {
    const cks = (ckByEvent.get(e.event_id) || []).filter(c => memberIn(c.member_id, e));
    const checked = new Map(cks.map(c => [c.member_id, c]));
    const acc = e.accepted.filter(id => memberIn(id, e));
    const accSet = new Set(acc);
    const came = acc.filter(id => checked.has(id));
    const walk = [...checked.keys()].filter(id => !accSet.has(id));
    const noShow = started(e) ? acc.filter(id => !checked.has(id)) : [];
    const declined = e.declined.filter(id => memberIn(id, e) && !checked.has(id));
    return { e, cks, checked, acc, came, walk, noShow, declined, started: started(e) };
  }
  const eventVisible = e => { const t = teamF(); if (!t) return true; if (e.team_id === t) return true; const s = sessionStats(e); return s.cks.length || s.acc.length; };
  const eventsIn = (a, b) => D.events.filter(e => e.date >= a && e.date <= b && eventVisible(e));
  const checkinsIn = (a, b) => D.checkins.filter(c => c.date >= a && c.date <= b && memberIn(c.member_id, c.event_id ? eventById.get(c.event_id) : null));

  function periodStats(a, b) {
    const cks = checkinsIn(a, b);
    const evs = eventsIn(a, b).map(sessionStats).filter(s => s.started);
    const accepted = evs.reduce((n, s) => n + s.acc.length, 0);
    const came = evs.reduce((n, s) => n + s.came.length, 0);
    return {
      checkins: cks.length,
      people: new Set(cks.map(c => c.member_id)).size,
      turnup: accepted ? Math.round(came / accepted * 100) : null,
      walk: evs.reduce((n, s) => n + s.walk.length, 0),
      open: cks.filter(c => !c.event_id).length,
      sessions: evs.length,
    };
  }
  const pct = (n, d) => d ? Math.round(n / d * 100) : null;
  const meter = v => v === null ? '<span class="muted">–</span>' : `<span class="meter"><i class="${v < 50 ? 'low' : ''}" style="width:${v}%"></i></span>${v}%`;

  /** Last check-in date of a member (within the 12 weeks loaded), or null. */
  const lastSeen = id => { const l = ckByMember.get(id); return l && l.length ? l[l.length - 1].date : null; };
  const seenText = d => { if (!d) return 'Not in 12 weeks'; const n = daysBetween(d, today()); return n === 0 ? 'Today' : n === 1 ? 'Yesterday' : `${n} days ago`; };
  const players = () => D.members.filter(m => (m.player || ckByMember.has(m.id)) && memberIn(m.id, null));

  // ── API ───────────────────────────────────────────────────────────────────
  async function token() {
    if (!STANDALONE) return (window.CSAuth && await window.CSAuth.fresh(false)) || URL_TOKEN || ANON;
    const { data: { session } } = await sb.auth.getSession();
    return session ? session.access_token : '';
  }
  async function callFn(payload) {
    const t = await token();
    if (STANDALONE && !t) throw Object.assign(new Error('Please sign in'), { signIn: true });
    const res = await fetch(FN_URL, { method: 'POST', headers: { 'Content-Type': 'application/json', apikey: ANON, Authorization: 'Bearer ' + t }, body: JSON.stringify(payload) });
    let j = {}; try { j = await res.json(); } catch (_) {}
    if (res.status === 401) throw Object.assign(new Error(j.error || 'Please sign in'), { signIn: STANDALONE });
    if (!res.ok || j.error) throw new Error(j.error || 'Something went wrong');
    return j;
  }

  // ── Shell ────────────────────────────────────────────────────────────────
  function applyClub() {
    const c = (D && D.club.colours) || [];
    const ok = v => typeof v === 'string' && /^#[0-9a-f]{6}$/i.test(v);
    const lum = h => { const n = parseInt(h.slice(1), 16); const f = x => { x /= 255; return x <= .03928 ? x / 12.92 : Math.pow((x + .055) / 1.055, 2.4); }; return .2126 * f(n >> 16 & 255) + .7152 * f(n >> 8 & 255) + .0722 * f(n & 255); };
    const p = ok(c[0]) ? c[0] : '#3b6fd8';
    const r = document.documentElement.style;
    r.setProperty('--club', p);
    r.setProperty('--club-2', ok(c[1]) ? c[1] : '#ffffff');
    r.setProperty('--club-3', ok(c[2]) ? c[2] : p);
    r.setProperty('--on-club', lum(p) > .45 ? '#111111' : '#ffffff');
    // Accent for links and bars: the third colour if it reads on white, else the primary.
    const acc = [c[2], c[0], c[1]].find(x => ok(x) && lum(x) < .35) || '#0357a3';
    r.setProperty('--accent', acc);
    document.querySelector('meta[name=theme-color]')?.setAttribute('content', p);
  }
  const initials = s => (String(s).replace(/\b(GAA|CLG|LGFA)\b/gi, '').match(/\b[A-Za-z]/g) || []).slice(0, 2).join('').toUpperCase();

  function shell(view, inner) {
    const nav = [['overview', 'Overview'], ['sessions', 'Sessions'], ['people', 'People']];
    const crest = D.club.crest ? `<img class="crest" src="${esc(D.club.crest)}" alt="" onerror="this.outerHTML='<div class=crest-blank>${esc(initials(D.club.name))}</div>'">` : `<div class="crest-blank">${esc(initials(D.club.name))}</div>`;
    const who = `${esc(D.me.name || 'Signed in')}<span class="long"> · ${esc(D.scope.club_wide ? 'Whole club' : 'Team admin')}</span>`;
    $app.innerHTML = `
      <header class="bar">${crest}
        <div class="t"><h1>${esc(D.club.name)} · Gym activity</h1><div class="sub">${esc(D.scope.label || '')}</div></div>
        ${D.clubs.length > 1 ? `<select class="sel" id="clubSel" style="color:var(--text)">${D.clubs.map(c => `<option value="${c.club_id}" ${c.club_id === D.club.club_id ? 'selected' : ''}>${esc(c.name)}</option>`).join('')}</select>` : ''}
        ${STANDALONE ? `<button class="user" id="signOut" title="Sign out">${who} · Sign out</button>` : `<div class="user">${who}</div>`}
      </header>
      <div class="wrap"><nav>${nav.map(([k, l]) => `<a href="#${k}" class="${k === view ? 'on' : ''}">${l}</a>`).join('')}</nav>
      <main id="main">${teamStrip()}${inner}</main></div>`;
    const so = document.getElementById('signOut');
    if (so) so.onclick = async () => { await sb.auth.signOut(); D = null; showSignIn(); };
    const cs = document.getElementById('clubSel');
    if (cs) cs.onchange = () => { UI.clubId = Number(cs.value); UI.team = 'all'; saveUI(); load(); };
    bindFilters();
  }

  /** Teams to offer in the team filter: any team with people or sessions in the data. */
  function filterTeams() {
    return D.teams.filter(t => D.scope.teams.includes(t.team_id) || D.members.some(m => m.teams.includes(t.team_id)) || D.events.some(e => e.team_id === t.team_id));
  }
  function teamStrip() {
    const teams = filterTeams();
    if (teams.length < 2) return '';
    const cur = teamF() ? teamName(teamF()) : '';
    return `<div class="strip"><label for="teamSel">Team</label>
      <select class="sel" id="teamSel"><option value="all">All teams</option>${teams.map(t => `<option value="${t.team_id}" ${String(t.team_id) === String(UI.team) ? 'selected' : ''}>${esc(t.name)}${t.snc ? ' (S&amp;C)' : ''}</option>`).join('')}</select>
      ${cur ? `<span class="muted">Showing ${esc(cur)} players only</span> <button class="linkbtn" id="teamClear">Show all teams</button>` : ''}</div>`;
  }
  function filters({ range = true, extra = '' } = {}) {
    return `${extra}
      ${range ? `<select class="sel" id="rangeSel">${Object.keys(RANGES).map(k => `<option value="${k}" ${k === UI.range ? 'selected' : ''}>${k === UI.range ? esc(rangeLabel()) : RANGES[k].label}</option>`).join('')}</select>` : ''}
      <button class="btn" id="csvBtn">Export CSV</button>`;
  }
  function bindFilters() {
    const t = document.getElementById('teamSel'); if (t) t.onchange = () => { UI.team = t.value; saveUI(); route(); };
    const tc = document.getElementById('teamClear'); if (tc) tc.onclick = () => { UI.team = 'all'; saveUI(); route(); };
    const r = document.getElementById('rangeSel'); if (r) r.onchange = () => { UI.range = r.value; saveUI(); route(); };
    const c = document.getElementById('csvBtn'); if (c) c.onclick = () => { if (CSV) downloadCsv(CSV.name, CSV.rows); };
  }

  // CSV of whatever the current view shows.
  let CSV = null;
  function downloadCsv(file, rows) {
    const q = v => { const s = String(v ?? ''); return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s; };
    const blob = new Blob(['﻿' + rows.map(r => r.map(q).join(',')).join('\r\n')], { type: 'text/csv' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob); a.download = file; document.body.appendChild(a); a.click();
    setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 1000);
  }
  const fileStem = () => `${D.club.name}-gym`.replace(/[^A-Za-z0-9]+/g, '-').toLowerCase();

  // ── Overview ──────────────────────────────────────────────────────────────
  function viewOverview() {
    const [a, b] = RANGES[UI.range].span();
    const t = today();
    const effB = b < t ? b : t;
    const len = daysBetween(a, b) + 1;
    const cur = periodStats(a, b);
    const prev = periodStats(addDays(a, -len), addDays(effB, -len));
    const delta = (x, y, unit = '') => {
      if (x === null || y === null) return '<div class="d muted">&nbsp;</div>';
      const d = x - y;
      return d === 0 ? `<div class="d muted">Same as the period before</div>` : `<div class="d ${d > 0 ? 'up' : 'down'}">${d > 0 ? '▲' : '▼'} ${Math.abs(d)}${unit} on the period before</div>`;
    };
    const tile = (n, l, d) => `<div class="tile"><div class="n">${n}</div><div class="l">${l}</div>${d}</div>`;

    // Today
    const todays = D.events.filter(e => e.date === t && eventVisible(e)).map(sessionStats);
    const openToday = checkinsIn(t, t).filter(c => !c.event_id).length;
    const now = Date.now();
    const todayRows = todays.map(s => {
      const st = new Date(s.e.time).getTime();
      const badge = !s.started ? '<span class="pill soon">Later</span>' : now - st < 2 * 36e5 ? '<span class="pill live">Now</span>' : '';
      return `<tr class="link" data-ev="${s.e.event_id}"><td><b>${esc(s.e.title)}</b> ${badge}</td><td>${teamCell(s.e.team_id)}</td><td>${fmtTime(s.e.time)}</td>
        <td class="num">${s.acc.length}</td><td class="num">${s.checked.size}</td><td class="num">${s.walk.length}</td>
        <td>${s.started ? meter(pct(s.came.length, s.acc.length)) : `<span class="muted">starts ${fmtTime(s.e.time)}</span>`}</td></tr>`;
    }).join('') + `<tr><td><b>Open gym</b></td><td><span class="muted">Any team</span></td><td>All day</td><td class="num muted">–</td><td class="num">${openToday}</td><td class="num muted">–</td><td class="muted">–</td></tr>`;

    // By team
    const teamIds = teamF() ? [teamF()] : D.teams.map(x => x.team_id);
    const byTeam = teamIds.map(id => {
      const evs = D.events.filter(e => e.team_id === id && e.date >= a && e.date <= b).map(sessionStats).filter(s => s.started);
      const acc = evs.reduce((n, s) => n + s.acc.length, 0), came = evs.reduce((n, s) => n + s.came.length, 0);
      const cks = D.checkins.filter(c => c.date >= a && c.date <= b && (memberById.get(c.member_id)?.teams.includes(id) || (c.event_id && eventById.get(c.event_id)?.team_id === id)));
      return { id, sessions: evs.length, cks: cks.length, people: new Set(cks.map(c => c.member_id)).size, turnup: pct(came, acc) };
    }).filter(r => r.sessions || r.cks);

    // Not seen in 14 days
    const cutoff = addDays(t, -14);
    const notSeen = players().filter(m => m.player).map(m => ({ m, last: lastSeen(m.id) })).filter(x => !x.last || x.last < cutoff)
      .sort((x, y) => (x.last || '') < (y.last || '') ? -1 : (x.last || '') > (y.last || '') ? 1 : x.m.name.localeCompare(y.m.name));

    CSV = { name: `${fileStem()}-overview-${a}.csv`, rows: [['Team', 'Sessions', 'Check-ins', 'People', 'Turn-up %'], ...byTeam.map(r => [teamName(r.id), r.sessions, r.cks, r.people, r.turnup ?? ''])] };

    shell('overview', `
      <div class="head"><h2>Overview</h2>${filters()}</div>
      <div class="tiles">
        ${tile(cur.checkins, 'Check-ins', delta(cur.checkins, prev.checkins))}
        ${tile(cur.people, 'Different people', delta(cur.people, prev.people))}
        ${tile(cur.turnup === null ? '–' : cur.turnup + '%', 'Turn-up (came ÷ accepted)', delta(cur.turnup, prev.turnup, ' pts'))}
        ${tile(cur.walk, 'Walk-ins', '<div class="d muted">came without accepting</div>')}
        ${tile(cur.open, 'Open gym visits', '<div class="d muted">no session booked</div>')}
      </div>
      <div class="card"><h3>Today · ${esc(fmtLong(t))} <span>live from the kiosk</span></h3><div class="scroll"><table>
        <tr><th>Session</th><th>Team</th><th>Time</th><th class="num">Accepted</th><th class="num">Checked in</th><th class="num">Walk-ins</th><th>Turn-up</th></tr>
        ${todayRows}</table></div></div>
      <div class="grid2">
        <div class="card"><h3>By team <span>${esc(RANGES[UI.range].label)}</span></h3>${byTeam.length ? `<div class="scroll"><table>
          <tr><th>Team</th><th class="num">Sessions</th><th class="num">Check-ins</th><th class="num">People</th><th>Turn-up</th></tr>
          ${byTeam.map(r => `<tr><td>${teamCell(r.id)}</td><td class="num">${r.sessions}</td><td class="num">${r.cks}</td><td class="num">${r.people}</td><td>${meter(r.turnup)}</td></tr>`).join('')}
          </table></div>` : '<div class="empty">No gym activity in this period.</div>'}</div>
        <div class="card"><h3>Not seen in 14 days <span>${notSeen.length} player${notSeen.length === 1 ? '' : 's'}${notSeen.length > 8 ? ' · <a href="#people" id="seeAll">see all</a>' : ''}</span></h3>${notSeen.length ? `<div class="scroll"><table>
          <tr><th>Player</th><th>Team</th><th>Last seen</th></tr>
          ${notSeen.slice(0, 8).map(x => `<tr><td>${esc(x.m.name)}</td><td>${teamCell(x.m.teams[0])}</td><td class="${!x.last || daysBetween(x.last, t) >= 21 ? 'down' : ''}">${seenText(x.last)}</td></tr>`).join('')}
          </table></div>` : '<div class="empty">Everyone has been in during the last 14 days.</div>'}</div>
      </div>`);
    const sa = document.getElementById('seeAll'); if (sa) sa.onclick = () => { UI.peopleSort = 'seen'; };
    bindRows();
  }

  // ── Sessions ──────────────────────────────────────────────────────────────
  function viewSessions() {
    const [a, b] = RANGES[UI.range].span();
    const list = eventsIn(a, b).map(sessionStats).sort((x, y) => y.e.time.localeCompare(x.e.time));
    CSV = { name: `${fileStem()}-sessions-${a}.csv`, rows: [['Date', 'Time', 'Session', 'Team', 'Accepted', 'Came', 'Walk-ins', 'No-shows', 'Turn-up %'],
      ...list.map(s => [s.e.date, fmtTime(s.e.time), s.e.title, teamName(s.e.team_id), s.acc.length, s.came.length, s.walk.length, s.started ? s.noShow.length : '', s.started ? pct(s.came.length, s.acc.length) ?? '' : ''])] };
    shell('sessions', `
      <div class="head"><h2>Sessions</h2>${filters()}</div>
      <div class="card"><h3>${esc(rangeLabel())} <span>${list.length} session${list.length === 1 ? '' : 's'}</span></h3>${list.length ? `<div class="scroll"><table>
        <tr><th>Date</th><th>Session</th><th>Team</th><th class="num">Accepted</th><th class="num">Came</th><th class="num">Walk-ins</th><th class="num">No-shows</th><th>Turn-up</th></tr>
        ${list.map(s => `<tr class="link" data-ev="${s.e.event_id}"><td>${esc(fmtDay(s.e.date))} ${fmtTime(s.e.time)}</td><td><b>${esc(s.e.title)}</b>${s.e.snc ? '' : ' <span class="muted">(not S&amp;C)</span>'}</td><td>${teamCell(s.e.team_id)}</td>
          <td class="num">${s.acc.length}</td><td class="num">${s.came.length}</td><td class="num">${s.walk.length}</td>
          <td class="num ${s.noShow.length > 5 ? 'down' : ''}">${s.started ? s.noShow.length : '<span class="muted">–</span>'}</td>
          <td>${s.started ? meter(pct(s.came.length, s.acc.length)) : '<span class="pill soon">Upcoming</span>'}</td></tr>`).join('')}
        </table></div>` : '<div class="empty">No sessions in this period.</div>'}</div>`);
    bindRows();
  }

  // ── One session ───────────────────────────────────────────────────────────
  const FILTER_NAMES = { acc: 'accepted', came: 'who came', walk: 'walk-ins', no: 'no-shows' };
  const tileBtn = (key, cur, n, label, style = '') =>
    `<button class="tile tbtn${cur === key ? ' on' : ''}" data-sf="${key}" aria-pressed="${cur === key}"><div class="n" style="${style}">${n}</div><div class="l">${label}</div><div class="d muted">${cur === key ? 'Showing these · tap to clear' : 'Tap to show'}</div></button>`;

  function viewSession(id) {
    const e = eventById.get(id);
    if (!e) { location.hash = '#sessions'; return; }
    const s = sessionStats(e);
    const t = today(), from4 = addDays(t, -27);
    const recent = mid => (ckByMember.get(mid) || []).filter(c => c.date >= from4).length;
    const how = { tap: 'Tap', qr: 'QR', coach: 'Coach' };
    const rows = [
      ...s.came.map(id => ({ id, st: 'came', c: s.checked.get(id) })),
      ...s.walk.map(id => ({ id, st: 'walk', c: s.checked.get(id) })),
      ...s.noShow.map(id => ({ id, st: 'no' })),
      ...(s.started ? [] : s.acc.filter(id => !s.checked.has(id)).map(id => ({ id, st: 'acc' }))),
      ...s.declined.map(id => ({ id, st: 'dec' })),
    ];
    const order = { came: 0, walk: 1, acc: 2, no: 3, dec: 4 };
    rows.sort((x, y) => order[x.st] - order[y.st] || (x.c && y.c ? x.c.at.localeCompare(y.c.at) : name(x.id).localeCompare(name(y.id))));
    // The tiles filter the list (click again, or "Show everyone", to clear).
    if (UI.sessFor !== id) { UI.sessFor = id; UI.sessFilter = 'all'; }
    const F = UI.sessFilter || 'all';
    const keep = { all: () => true, acc: r => ['came', 'no', 'acc'].includes(r.st), came: r => r.st === 'came', walk: r => r.st === 'walk', no: r => r.st === 'no' };
    const shown = rows.filter(keep[F] || keep.all);
    const lab = { came: ['came', 'Came'], walk: ['walk', 'Walk-in'], no: ['no', 'No-show'], acc: ['soon', 'Accepted'], dec: ['dec', 'Declined'] };
    CSV = { name: `${fileStem()}-session-${e.date}-${e.event_id}.csv`, rows: [['Player', 'Status', 'Checked in', 'How', 'Check-ins last 4 weeks'],
      ...shown.map(r => [name(r.id), lab[r.st][1], r.c ? fmtTime(r.c.at) : '', r.c ? how[r.c.method] || r.c.method : '', recent(r.id)])] };
    const partial = !e.own ? `<div class="card"><div class="empty">This is another team's session. You see your own players only.</div></div>` : '';
    shell('sessions', `
      <a class="back" href="#sessions">‹ Back to sessions</a>
      <div class="head" style="margin-top:8px"><h2>${esc(e.title)} · ${esc(fmtLong(e.date))}, ${fmtTime(e.time)}</h2><button class="btn" id="csvBtn">Export CSV</button></div>
      <div class="tiles four">
        ${tileBtn('acc', F, s.acc.length, 'Accepted')}
        ${tileBtn('came', F, s.came.length, 'Came (accepted and checked in)')}
        ${tileBtn('walk', F, s.walk.length, 'Walk-ins')}
        ${tileBtn('no', F, s.started ? s.noShow.length : '–', s.started ? 'No-shows' : 'No-shows (not started yet)', s.noShow.length ? 'color:var(--bad)' : '')}
      </div>${partial}
      <div class="card"><h3><span style="color:var(--text);font-weight:700;font-size:16px">${teamCell(e.team_id)}</span><span>${F === 'all' ? `${rows.length} player${rows.length === 1 ? '' : 's'}` : `Showing ${shown.length} ${FILTER_NAMES[F]} of ${rows.length} · <button class="linkbtn" id="sessAll">Show everyone</button>`}${e.location ? ' · ' + esc(e.location) : ''}</span></h3>${shown.length ? `<div class="scroll"><table>
        <tr><th>Player</th><th>Status</th><th>Checked in</th><th>How</th><th class="num">Check-ins, last 4 weeks</th></tr>
        ${shown.map(r => `<tr><td>${esc(name(r.id))}</td><td><span class="pill ${lab[r.st][0]}">${lab[r.st][1]}</span></td>
          <td>${r.c ? fmtTime(r.c.at) : '<span class="muted">–</span>'}</td><td>${r.c ? esc(how[r.c.method] || r.c.method) : '<span class="muted">–</span>'}</td>
          <td class="num">${recent(r.id)}</td></tr>`).join('')}
        </table></div>` : `<div class="empty">${rows.length ? 'Nobody in this group.' : 'Nobody has replied or checked in yet.'}</div>`}</div>`);
    document.querySelectorAll('[data-sf]').forEach(b => b.onclick = () => { UI.sessFilter = UI.sessFilter === b.dataset.sf ? 'all' : b.dataset.sf; viewSession(id); });
    const sa = document.getElementById('sessAll'); if (sa) sa.onclick = () => { UI.sessFilter = 'all'; viewSession(id); };
  }

  // ── People ────────────────────────────────────────────────────────────────
  function viewPeople() {
    const t = today(), from4 = addDays(t, -27), from8 = addDays(t, -55);
    const past8 = D.events.filter(e => e.date >= from8 && e.date <= t && started(e));
    const rows = players().map(m => {
      const cks = ckByMember.get(m.id) || [];
      const acc = past8.filter(e => e.accepted.includes(m.id));
      const came = acc.filter(e => (ckByEvent.get(e.event_id) || []).some(c => c.member_id === m.id));
      return {
        m, w4: cks.filter(c => c.date >= from4).length, w8: cks.filter(c => c.date >= from8).length,
        open: cks.filter(c => c.date >= from8 && !c.event_id).length, acc: acc.length, turnup: pct(came.length, acc.length), last: lastSeen(m.id),
      };
    });
    const q = UI.peopleQ.trim().toLowerCase();
    const shown = rows.filter(r => !q || r.m.name.toLowerCase().includes(q));
    const sorts = {
      name: (x, y) => x.m.name.localeCompare(y.m.name),
      most: (x, y) => y.w8 - x.w8 || y.w4 - x.w4 || x.m.name.localeCompare(y.m.name),
      least: (x, y) => x.w8 - y.w8 || x.w4 - y.w4 || x.m.name.localeCompare(y.m.name),
      seen: (x, y) => (x.last || '') < (y.last || '') ? -1 : (x.last || '') > (y.last || '') ? 1 : x.m.name.localeCompare(y.m.name),
      turnup: (x, y) => (x.turnup ?? 999) - (y.turnup ?? 999) || x.m.name.localeCompare(y.m.name),
    };
    if (!sorts[UI.peopleSort]) UI.peopleSort = 'name';
    shown.sort(sorts[UI.peopleSort]);
    const notSeen = rows.filter(r => r.m.player && (!r.last || r.last < addDays(t, -14))).length;
    CSV = { name: `${fileStem()}-people-${t}.csv`, rows: [['Player', 'Teams', 'Check-ins last 4 weeks', 'Check-ins last 8 weeks', 'Open gym last 8 weeks', 'Sessions accepted last 8 weeks', 'Turn-up %', 'Last seen'],
      ...shown.map(r => [r.m.name, r.m.teams.map(teamName).join('; '), r.w4, r.w8, r.open, r.acc, r.turnup ?? '', r.last || ''])] };
    const sortSel = `<select class="sel" id="sortSel">${[['name', 'Sort: name'], ['most', 'Sort: most check-ins'], ['least', 'Sort: fewest check-ins'], ['seen', 'Sort: longest since seen'], ['turnup', 'Sort: lowest turn-up']]
      .map(([k, l]) => `<option value="${k}" ${k === UI.peopleSort ? 'selected' : ''}>${l}</option>`).join('')}</select>`;
    shell('people', `
      <div class="head"><h2>People</h2>${filters({ range: false, extra: `<input class="search" id="q" type="search" placeholder="Search names" value="${esc(UI.peopleQ)}">${sortSel}` })}</div>
      <div class="card"><h3>Last 8 weeks <span>${rows.length} player${rows.length === 1 ? '' : 's'} · ${notSeen} not seen in 14 days</span></h3>${shown.length ? `<div class="scroll"><table>
        <tr><th>Player</th><th>Team</th><th class="num">Last 4 wks</th><th class="num">Last 8 wks</th><th class="num">Open gym</th><th>Turn-up</th><th>Last seen</th></tr>
        ${shown.map(r => `<tr><td><b style="color:var(--text)">${esc(r.m.name)}</b>${r.m.player ? '' : ' <span class="muted">(admin)</span>'}</td>
          <td>${r.m.teams.length ? r.m.teams.map(teamCell).join('<br>') : '<span class="muted">–</span>'}</td>
          <td class="num">${r.w4}</td><td class="num">${r.w8}</td><td class="num">${r.open}</td>
          <td>${r.acc ? meter(r.turnup) : '<span class="muted">no sessions accepted</span>'}</td>
          <td class="${!r.last || daysBetween(r.last, t) >= 14 ? 'down' : ''}">${seenText(r.last)}</td></tr>`).join('')}
        </table></div>` : `<div class="empty">${q ? 'Nobody matches that search.' : 'No players to show.'}</div>`}</div>`);
    const qi = document.getElementById('q');
    qi.oninput = () => { UI.peopleQ = qi.value; const pos = qi.selectionStart; viewPeople(); const n = document.getElementById('q'); n.focus(); n.setSelectionRange(pos, pos); };
    document.getElementById('sortSel').onchange = e => { UI.peopleSort = e.target.value; saveUI(); viewPeople(); };
  }

  function bindRows() {
    document.querySelectorAll('tr[data-ev]').forEach(tr => tr.onclick = () => { location.hash = '#session-' + tr.dataset.ev; });
  }

  // ── Routing, loading, sign-in ─────────────────────────────────────────────
  function route() {
    if (!D) return;
    const h = (location.hash || '#overview').slice(1);
    const m = /^session-(\d+)$/.exec(h);
    if (m) viewSession(Number(m[1]));
    else if (h === 'sessions') viewSessions();
    else if (h === 'people') viewPeople();
    else viewOverview();
    window.scrollTo(0, 0);
  }
  window.addEventListener('hashchange', route);

  const centre = html => { $app.innerHTML = `<div class="center">${html}</div>`; };
  const showLoading = () => centre('<div class="spinner" aria-label="Loading"></div>');
  function showError(msg) {
    centre(`<div class="signin"><h2>Gym activity</h2><p>${esc(msg)}</p>
      <button class="btn primary" id="retry">Try again</button>${STANDALONE ? '<button class="btn" id="out" style="margin-top:8px;width:100%">Sign in as someone else</button>' : ''}</div>`);
    document.getElementById('retry').onclick = load;
    const o = document.getElementById('out'); if (o) o.onclick = async () => { await sb.auth.signOut(); showSignIn(); };
  }

  async function load() {
    showLoading();
    try {
      D = await callFn({ action: 'load', club_id: UI.clubId || undefined });
      UI.clubId = D.club.club_id; saveUI();
      index(); applyClub(); route();
      // Refresh the live numbers every 2 minutes while the page is open.
      clearInterval(load.timer);
      load.timer = setInterval(async () => {
        if (document.hidden) return;
        try { D = await callFn({ action: 'load', club_id: UI.clubId }); index(); if (!document.activeElement || document.activeElement.id !== 'q') route(); } catch (_) {}
      }, 120000);
    } catch (e) {
      D = null;
      if (e.signIn) showSignIn(e.message === 'Please sign in' ? '' : e.message);
      else showError(e.message);
    }
  }

  function showSignIn(msg = '') {
    centre(`<form class="signin" id="f"><h2>Gym activity</h2><p>Sign in with your CoachSmart login. This is for team admins.</p>
      <input id="email" type="email" placeholder="Email" autocomplete="username" required>
      <input id="pw" type="password" placeholder="Password" autocomplete="current-password" required>
      <div class="err" id="err">${esc(msg)}</div><button class="btn primary" id="go">Sign in</button></form>`);
    document.getElementById('f').onsubmit = async ev => {
      ev.preventDefault();
      const b = document.getElementById('go'); b.disabled = true; b.textContent = 'Signing in…';
      const { error } = await sb.auth.signInWithPassword({ email: document.getElementById('email').value.trim(), password: document.getElementById('pw').value });
      if (error) { b.disabled = false; b.textContent = 'Sign in'; document.getElementById('err').textContent = "That email and password didn't work."; return; }
      load();
    };
  }

  async function start() {
    if (!STANDALONE) { load(); return; }
    showLoading();
    await new Promise((ok, bad) => {
      const s = document.createElement('script');
      s.src = 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.43.4/dist/umd/supabase.min.js';
      s.onload = ok; s.onerror = bad; document.head.appendChild(s);
    }).catch(() => {});
    if (!window.supabase) { showError('Could not load the sign-in. Please refresh.'); return; }
    sb = window.supabase.createClient(SUPABASE_URL, ANON, { auth: { storageKey: 'cs-gym-dashboard' } });
    const { data: { session } } = await sb.auth.getSession();
    session ? load() : showSignIn();
  }
  start();
})();
