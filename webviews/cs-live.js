/* CoachSmart live matches: shared by match-live.html and matches.html.
 *
 * - sign-in: token from the URL, topped up by the app (FlutterBridge getToken)
 *   or a refresh token; share links (?share=) run signed out
 * - rpc(): Supabase RPC calls
 * - listen(): Realtime on live_pulse (a counter per match that the database
 *   bumps on every change), with polling as a backup
 * - the alert-choice sheet used by both pages
 */
(function () {
  'use strict';
  const SUPABASE_URL = 'https://gyfporsbdftvtakdvukt.supabase.co';
  const SUPABASE_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4';
  const P = new URLSearchParams(location.search);
  let token = P.get('token') || P.get('currentAuthToken') || P.get('access_token') || '';
  let refreshTok = P.get('refreshToken') || P.get('refresh_token') || '';
  const jwtClaims = t => { try { return JSON.parse(atob(t.split('.')[1].replace(/-/g, '+').replace(/_/g, '/'))); } catch (_) { return {}; } };
  let tokenExp = token ? (jwtClaims(token).exp || 0) * 1000 : 0;

  const bridge = () => window.FlutterBridge && typeof window.FlutterBridge.postMessage === 'function';
  const post = m => { try { if (bridge()) window.FlutterBridge.postMessage(m); } catch (_) {} };

  let waiters = [], bridgeAnswers = null;
  const tokenListeners = [];
  window.csSetToken = function (t, exp) {
    if (t && typeof t === 'string') {
      token = t;
      const e = Number(exp) || 0;
      tokenExp = e ? (e > 1e12 ? e : e * 1000) : (jwtClaims(t).exp || 0) * 1000;
      bridgeAnswers = true;
      tokenListeners.forEach(f => f(token));
    }
    waiters.splice(0).forEach(f => f());
  };
  async function freshToken(force) {
    if (!token && !refreshTok) return '';
    if (!force && tokenExp - Date.now() > 120000) return token;
    const before = token;
    if (bridge() && bridgeAnswers !== false) {
      post('getToken');
      await new Promise(r => { waiters.push(r); setTimeout(r, bridgeAnswers ? 6000 : 3000); });
      if (token !== before) return token;
      if (bridgeAnswers === null) bridgeAnswers = false;
    }
    if (refreshTok) {
      try {
        const r = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=refresh_token`, {
          method: 'POST', headers: { apikey: SUPABASE_ANON, 'Content-Type': 'application/json' },
          body: JSON.stringify({ refresh_token: refreshTok }),
        });
        if (r.ok) {
          const j = await r.json();
          token = j.access_token; refreshTok = j.refresh_token || refreshTok;
          tokenExp = j.expires_at ? j.expires_at * 1000 : Date.now() + (j.expires_in || 3600) * 1000;
          tokenListeners.forEach(f => f(token));
        }
      } catch (_) {}
    }
    return token;
  }
  setInterval(() => { if (token && tokenExp - Date.now() < 10 * 60000) freshToken(true); }, 60000);

  async function rpc(fn, args) {
    const call = t => fetch(`${SUPABASE_URL}/rest/v1/rpc/${fn}`, {
      method: 'POST',
      headers: { apikey: SUPABASE_ANON, Authorization: 'Bearer ' + (t || SUPABASE_ANON), 'Content-Type': 'application/json' },
      body: JSON.stringify(args || {}),
    });
    const t = await freshToken(false);
    let r = await call(t);
    if (r.status === 401 && t) { const t2 = await freshToken(true); r = await call(t2); }
    if (!r.ok) { let j = null; try { j = await r.json(); } catch (_) {} const e = new Error((j && j.message) || 'HTTP ' + r.status); e.status = r.status; throw e; }
    const txt = await r.text();
    return txt ? JSON.parse(txt) : null;
  }

  // Realtime on live_pulse, plus polling. onChange is called (debounced) when
  // something may have changed; it should re-read and return.
  let sb = null;
  function client() {
    if (sb || !window.supabase) return sb;
    sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: token ? { headers: { Authorization: 'Bearer ' + token } } : {},
    });
    if (token) sb.realtime.setAuth(token);
    tokenListeners.push(t => { try { sb.realtime.setAuth(t); } catch (_) {} });
    return sb;
  }
  function listen(eventIds, onChange, opts) {
    opts = opts || {};
    let ch = null, live = false, timer = null, busy = false, again = false, last = 0;
    const kick = () => {
      if (busy) { again = true; return; }
      busy = true; last = Date.now();
      Promise.resolve(onChange()).catch(() => {}).finally(() => { busy = false; if (again) { again = false; setTimeout(kick, 300); } });
    };
    const poll = () => {
      clearInterval(timer);
      timer = setInterval(() => { if (!document.hidden && Date.now() - last > (live ? 3000 : 0)) kick(); }, live ? (opts.slow || 20000) : (opts.fast || 6000));
    };
    function sub(ids) {
      const c = client();
      if (ch && c) { try { c.removeChannel(ch); } catch (_) {} ch = null; }
      live = false; poll();
      if (!c || !ids.length) return;
      ch = c.channel('pulse-' + ids.join('-').slice(0, 80))
        .on('postgres_changes', { event: '*', schema: 'public', table: 'live_pulse', filter: ids.length === 1 ? `event_id=eq.${ids[0]}` : `event_id=in.(${ids.slice(0, 100).join(',')})` }, () => kick())
        .subscribe(st => { const was = live; live = st === 'SUBSCRIBED'; if (live !== was) poll(); });
    }
    sub(eventIds);
    document.addEventListener('visibilitychange', () => { if (!document.hidden) kick(); });
    return { resubscribe: sub, refresh: kick };
  }

  // ── Bits of text ────────────────────────────────────────────────────────────
  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const pad2 = n => String(n).padStart(2, '0');
  const gaa = s => s ? `${s.g}-${pad2(s.p)}` : '–';
  const cleanClub = n => String(n || '').replace(/\b(GAA|GFC|CLG|HC|LGFA|Camogie Club)\b/gi, '').replace(/\s{2,}/g, ' ').trim();
  const fmt = sec => { sec = Math.max(0, Math.floor(sec)); return `${pad2(Math.floor(sec / 60))}:${pad2(sec % 60)}`; };

  // Seconds into the current half, from the score keeper's clock
  function halfSeconds(timer, skew) {
    if (!timer) return 0;
    let s = timer.elapsed_seconds || 0;
    if (timer.status === 'running' && timer.started_at) s += Math.max(0, (Date.now() - skew - Date.parse(timer.started_at)) / 1000);
    return s;
  }

  // ── Alert choices sheet ─────────────────────────────────────────────────────
  const LEVELS = [
    ['all', 'Every score', 'Goals, points and 2 pointers, both teams, plus half time and full time'],
    ['goals', 'Goals only', 'Plus half time and full time'],
    ['result', 'Half time and full time only', 'No alerts for scores'],
    ['off', 'Stop following', 'No alerts for this match'],
  ];
  const levelLabel = l => ({ all: 'Every score', goals: 'Goals, half time and full time', result: 'Half time and full time', off: 'No alerts' }[l] || '');
  const CSS = `
  .lv-dim{position:fixed;inset:0;background:rgba(0,0,0,.55);z-index:50;opacity:0;transition:opacity .2s}
  .lv-dim.on{opacity:1}
  .lv-sheet{position:fixed;left:0;right:0;bottom:0;z-index:51;background:var(--card,#1e222b);border-radius:22px 22px 0 0;padding:10px 18px calc(24px + env(safe-area-inset-bottom,0px));max-width:520px;margin:0 auto;transform:translateY(100%);transition:transform .25s;max-height:88vh;overflow:auto}
  .lv-sheet.on{transform:none}
  .lv-grab{width:40px;height:5px;border-radius:3px;background:#3a404c;margin:0 auto 14px}
  .lv-h{font-size:20px;font-weight:700}.lv-sub{font-size:13px;color:var(--muted,#a1a1a2);margin-top:2px}
  .lv-row{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:13px 0;border-bottom:1px solid rgba(255,255,255,.07);font-size:15px;width:100%;text-align:left}
  .lv-row:last-child{border:0}.lv-row small{display:block;color:var(--muted,#a1a1a2);font-size:12.5px;margin-top:2px}
  .lv-rad{width:22px;height:22px;border-radius:50%;border:2px solid #4a515e;flex-shrink:0}.lv-rad.on{border:7px solid var(--green,#87c232)}
  .lv-tog{width:46px;height:28px;border-radius:99px;background:#3a404c;position:relative;flex-shrink:0;transition:background .15s}
  .lv-tog:after{content:'';position:absolute;left:3px;top:3px;width:22px;height:22px;border-radius:50%;background:#fff;transition:left .15s}
  .lv-tog.on{background:var(--green,#87c232)}.lv-tog.on:after{left:21px}
  .lv-cap{font-size:11px;letter-spacing:1.5px;text-transform:uppercase;color:var(--green,#87c232);font-weight:700;margin:14px 0 2px}
  .lv-btn{margin-top:14px;width:100%;height:50px;border-radius:14px;background:var(--green,#87c232);color:#14181b;font-weight:700;font-size:16px}
  .lv-note{font-size:12.5px;color:var(--muted,#a1a1a2);margin-top:10px;line-height:1.4}`;
  function injectCss() {
    if (document.getElementById('lv-css')) return;
    const st = document.createElement('style'); st.id = 'lv-css'; st.textContent = CSS; document.head.appendChild(st);
  }

  // opts: { title, sub, follow:{level,kickoff,names,own_team,source}, allowDefault, onSave(choice) }
  // choice: { level, kickoff, names, forAll }
  function alertSheet(opts) {
    injectCss();
    const f = Object.assign({ level: 'result', kickoff: true, names: true }, opts.follow || {});
    let ch = { level: f.level, kickoff: f.kickoff !== false, names: f.names !== false, forAll: false };
    const dim = document.createElement('div'); dim.className = 'lv-dim';
    const sh = document.createElement('div'); sh.className = 'lv-sheet';
    const draw = () => {
      sh.innerHTML = `<div class="lv-grab"></div><div class="lv-h">${esc(opts.title || 'Alerts for this match')}</div>
        <div class="lv-sub">${esc(opts.sub || 'Sent to your phone as they happen')}</div>
        ${LEVELS.map(([k, t, s]) => `<button class="lv-row" data-l="${k}"><div>${t}<small>${s}</small></div><div class="lv-rad ${ch.level === k ? 'on' : ''}"></div></button>`).join('')}
        <div class="lv-cap">Also</div>
        <button class="lv-row" data-t="kickoff"><div>Throw-in alerts<small>Start of each half</small></div><div class="lv-tog ${ch.kickoff ? 'on' : ''}"></div></button>
        <button class="lv-row" data-t="names"><div>Name the scorer<small>When the coach names a player</small></div><div class="lv-tog ${ch.names ? 'on' : ''}"></div></button>
        ${opts.allowDefault ? `<button class="lv-row" data-t="forAll"><div>Use this for all my teams' matches</div><div class="lv-tog ${ch.forAll ? 'on' : ''}"></div></button>` : ''}
        <button class="lv-btn" data-save>Save</button>
        ${opts.note ? `<div class="lv-note">${esc(opts.note)}</div>` : ''}`;
    };
    draw();
    sh.addEventListener('click', e => {
      const l = e.target.closest('[data-l]'), t = e.target.closest('[data-t]');
      if (l) { ch.level = l.dataset.l; draw(); }
      else if (t) { ch[t.dataset.t] = !ch[t.dataset.t]; draw(); }
      else if (e.target.closest('[data-save]')) { close(); opts.onSave && opts.onSave(ch); }
    });
    const close = () => { dim.classList.remove('on'); sh.classList.remove('on'); setTimeout(() => { dim.remove(); sh.remove(); }, 260); };
    dim.addEventListener('click', close);
    document.body.append(dim, sh);
    requestAnimationFrame(() => { dim.classList.add('on'); sh.classList.add('on'); });
    return close;
  }

  // forAll also sets the default for the caller's own teams; an own-team match
  // then just follows that default.
  async function saveFollow(eventId, ch, ownTeam) {
    if (ch.forAll) await rpc('set_live_follow', { p_event_id: null, p_level: ch.level, p_kickoff: ch.kickoff, p_names: ch.names });
    return rpc('set_live_follow', { p_event_id: eventId, p_level: ch.forAll && ownTeam ? null : ch.level, p_kickoff: ch.kickoff, p_names: ch.names });
  }

  // Following a match starts on every score (plus throw-in, half time and
  // full time); once following, the bell opens the choices for that match.
  function setFollow(eventId, on) {
    return rpc('set_live_follow', { p_event_id: eventId, p_level: on ? 'all' : null, p_kickoff: true, p_names: true });
  }

  // Bell on a match: follow straight away, or change / stop if already following
  // opts: { eventId, title, sub, follow, onChange(follow, message) }
  async function bell(opts) {
    const f = opts.follow || {};
    if (!f.level || f.level === 'off') {
      opts.onChange(await setFollow(opts.eventId, true), "Following: you'll get every score. Tap the bell to change.");
      return;
    }
    alertSheet({
      title: opts.title || 'Alerts for this match', sub: opts.sub, follow: f,
      onSave: async ch => {
        try {
          const nf = ch.level === 'off'
            ? await setFollow(opts.eventId, false)
            : await rpc('set_live_follow', { p_event_id: opts.eventId, p_level: ch.level, p_kickoff: ch.kickoff, p_names: ch.names });
          opts.onChange(nf, ch.level === 'off' ? 'Stopped following this match' : "Saved. You'll get " + levelLabel(ch.level).toLowerCase() + '.');
        } catch (_) { opts.onError && opts.onError(); }
      },
    });
  }

  function close() {
    if (bridge()) post('close');
    else if (history.length > 1) history.back();
  }

  window.CSLive = {
    P, rpc, listen, post, bridge, signedIn: () => !!token, freshToken,
    esc, gaa, fmt, pad2, cleanClub, halfSeconds, alertSheet, saveFollow, setFollow, bell, levelLabel, close,
    url: SUPABASE_URL, anon: SUPABASE_ANON,
  };
})();
