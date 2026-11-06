/* My gym QR.
 *
 * Sign in once with the CoachSmart email and password. The page asks the gym-kiosk edge
 * function (action my_qr) for the members this login is linked to (the member themselves,
 * or a parent's children) and shows each one's member code as a QR code for the gym kiosk.
 *
 * The codes are kept on the phone (localStorage), so after the first sign-in the page opens
 * straight to the QR with no signal. When online it quietly refreshes the list (e.g. a child
 * added later) using the stored refresh token.
 */
(function () {
  'use strict';

  const SB = 'https://gyfporsbdftvtakdvukt.supabase.co';
  const API = `${SB}/functions/v1/gym-kiosk`;
  const ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4';
  const K = { data: 'gq.data', rt: 'gq.rt', pick: 'gq.pick' };

  const app = document.getElementById('app');
  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const load = k => { try { return JSON.parse(localStorage.getItem(k)); } catch (_) { return null; } };
  let data = load(K.data);

  async function auth(grant, body) {
    const r = await fetch(`${SB}/auth/v1/token?grant_type=${grant}`, {
      method: 'POST', headers: { apikey: ANON, 'Content-Type': 'application/json' }, body: JSON.stringify(body),
    });
    const j = await r.json().catch(() => ({}));
    if (!r.ok || !j.access_token) { const e = new Error(j.error_description || j.msg || 'Sign-in failed'); e.status = r.status; throw e; }
    if (j.refresh_token) localStorage.setItem(K.rt, j.refresh_token);
    return j.access_token;
  }

  async function fetchCodes(accessToken) {
    const r = await fetch(API, {
      method: 'POST',
      headers: { apikey: ANON, Authorization: `Bearer ${ANON}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ action: 'my_qr', access_token: accessToken }),
    });
    const j = await r.json().catch(() => ({}));
    if (!r.ok) { const e = new Error(j.error || 'Something went wrong'); e.status = r.status; throw e; }
    data = j; localStorage.setItem(K.data, JSON.stringify(j));
    return j;
  }

  function brand() {
    const club = data && data.clubs && data.clubs[0];
    const valid = x => /^#[0-9a-f]{6}$/i.test(x || '');
    const root = document.documentElement.style;
    const crest = document.getElementById('crest');
    if (!club) { crest.hidden = true; return; }
    const [a, b, c] = club.colours || [];
    if (valid(a)) root.setProperty('--club', a);
    if (valid(b)) root.setProperty('--club-2', b);
    root.setProperty('--club-3', valid(c) ? c : (valid(a) ? a : '#0357a3'));
    if (club.crest) { crest.src = club.crest; crest.hidden = false; }
    document.getElementById('title').textContent = `${club.name} · Gym QR`;
  }

  function qrSvg(text) {
    const q = window.qrcode(0, 'M');
    q.addData(text); q.make();
    return q.createSvgTag({ cellSize: 8, margin: 4, scalable: true });
  }

  function renderQr() {
    brand();
    const members = (data && data.members) || [];
    if (!members.length) {
      app.innerHTML = `<p class="empty">This login isn't linked to a member yet. Ask your coach to add you, then sign in again.</p>
        <div class="foot"><button data-out>Sign out</button></div>`;
      app.querySelector('[data-out]').onclick = signOut;
      return;
    }
    let pick = Number(localStorage.getItem(K.pick)) || members[0].member_id;
    if (!members.some(m => m.member_id === pick)) pick = members[0].member_id;
    const m = members.find(x => x.member_id === pick);
    app.innerHTML = `
      ${members.length > 1 ? `<div class="tabs">${members.map(x => `<button data-id="${x.member_id}" class="${x.member_id === pick ? 'on' : ''}">${esc(x.name.split(' ')[0])}</button>`).join('')}</div>` : ''}
      <div class="qr" role="img" aria-label="QR code for ${esc(m.name)}">${qrSvg(m.code)}</div>
      <p class="name">${esc(m.name)}</p>
      ${m.teams.length ? `<div class="teams">${esc(m.teams.join(' · '))}</div>` : ''}
      <div class="code">${esc(m.code)}</div>
      <p class="tip">At the gym, tap <b>Scan my QR code</b> on the tablet and hold this up to its camera. Turn your screen brightness up if it doesn't read.</p>
      <div class="foot"><button data-out>Sign out</button></div>`;
    app.querySelectorAll('[data-id]').forEach(b => b.onclick = () => { localStorage.setItem(K.pick, b.dataset.id); renderQr(); });
    app.querySelector('[data-out]').onclick = signOut;
  }

  function renderSignIn(msg) {
    document.getElementById('title').textContent = 'My gym QR';
    app.innerHTML = `
      <p class="intro">Sign in with your CoachSmart email and password. Your QR code is then saved on this phone for checking in at the gym.</p>
      <form>
        <label>Email<input name="email" type="email" autocomplete="username" required></label>
        <label>Password<input name="password" type="password" autocomplete="current-password" required></label>
        <div class="err">${esc(msg || '')}</div>
        <button class="go">Show my QR code</button>
      </form>
      <div class="howto"><b>Make it an app:</b> after signing in, tap Share then <b>Add to Home Screen</b> (iPhone), or the menu then <b>Add to Home screen</b> (Android). It then opens straight to your code.</div>`;
    const f = app.querySelector('form');
    f.onsubmit = async ev => {
      ev.preventDefault();
      const btn = f.querySelector('.go'); btn.disabled = true;
      f.querySelector('.err').textContent = '';
      try {
        const token = await auth('password', { email: f.email.value.trim(), password: f.password.value });
        await fetchCodes(token);
        renderQr();
      } catch (e) {
        f.querySelector('.err').textContent = e.status === 400 ? "That email and password didn't work." : (e.status ? e.message : 'No connection. Try again with signal.');
        btn.disabled = false;
      }
    };
  }

  function signOut() {
    [K.data, K.rt, K.pick].forEach(k => localStorage.removeItem(k));
    data = null;
    renderSignIn();
  }

  // Quiet background refresh so a newly linked child appears without signing in again.
  async function refreshQuietly() {
    const rt = localStorage.getItem(K.rt);
    if (!rt || !navigator.onLine) return;
    try { await fetchCodes(await auth('refresh_token', { refresh_token: rt })); renderQr(); }
    catch (e) { if (e.status === 400 || e.status === 401) { /* session gone; keep showing the saved code */ } }
  }

  if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js').catch(() => {});
  if (data && data.members) { renderQr(); refreshQuietly(); } else renderSignIn();
})();
