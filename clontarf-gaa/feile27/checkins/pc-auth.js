// Player check-ins: CoachSmart sign-in and calls to the player-checkins function.
// Shared by checkins/ (coaches) and card/ (families).
// Opened from the v3 app as ...?token=<jwt>: no sign-in screen, the token is used as is.
// In a browser it signs in with the CoachSmart email and password.
window.PC = (function () {
  const SUPABASE_URL = 'https://gyfporsbdftvtakdvukt.supabase.co';
  const ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4';
  const FN = SUPABASE_URL + '/functions/v1/player-checkins';
  const SDK = 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.43.4/dist/umd/supabase.min.js';
  const params = new URLSearchParams(location.search);
  const WV_TOKEN = params.get('token') || '';
  let sb = null, done;
  const ready = new Promise(r => { done = r; });
  const $ = s => document.querySelector(s);
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

  function gate(html) {
    let g = $('#gate');
    if (!g) { g = document.createElement('div'); g.id = 'gate'; document.body.appendChild(g); }
    g.innerHTML = `<div class="gate-in">${html}</div>`;
    g.hidden = false;
  }
  function ungate() { const g = $('#gate'); if (g) g.hidden = true; }

  function showSignIn(msg = '') {
    gate(`<img src="/clontarf-gaa/images/clontarf-crest.png" alt="">
      <h2>Sign in</h2>
      <p class="muted">Use your CoachSmart email and password.</p>
      ${msg ? `<p class="err">${esc(msg)}</p>` : ''}
      <form id="signin">
        <label>Email<input name="email" type="email" autocomplete="email" required></label>
        <label>Password<input name="password" type="password" autocomplete="current-password" required></label>
        <button class="btn red wide" type="submit">Sign in</button>
      </form>
      <button class="link" id="forgot" type="button">Forgot your password?</button>`);
    $('#signin').onsubmit = async e => {
      e.preventDefault();
      const f = e.target, b = f.querySelector('button');
      b.disabled = true; b.textContent = 'Signing in…';
      const { error } = await sb.auth.signInWithPassword({ email: f.email.value.trim(), password: f.password.value });
      if (error) showSignIn(/invalid/i.test(error.message) ? 'That email and password did not match a CoachSmart account.' : error.message);
    };
    $('#forgot').onclick = async () => {
      const email = $('#signin').email.value.trim();
      if (!email) { showSignIn('Type your email first, then tap Forgot your password.'); return; }
      const { error } = await sb.auth.resetPasswordForEmail(email, { redirectTo: location.origin + location.pathname + location.search });
      showSignIn(error ? error.message : 'Check your email for a link to set a new password.');
    };
  }

  async function token() {
    if (WV_TOKEN) return WV_TOKEN;
    const { data: { session } } = await sb.auth.getSession();
    return session ? session.access_token : '';
  }

  async function call(action, payload = {}) {
    const res = await fetch(FN, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + ((await token()) || ANON), apikey: ANON },
      body: JSON.stringify({ action, ...payload })
    });
    let j = {};
    try { j = await res.json(); } catch (e) {}
    if (res.status === 401 && !WV_TOKEN) { showSignIn('Please sign in again.'); throw new Error('Please sign in'); }
    if (!res.ok || j.error) { const err = new Error(j.error || 'Something went wrong'); err.flagged = j.flagged; err.status = res.status; throw err; }
    return j;
  }

  async function signOut() { if (sb) await sb.auth.signOut(); location.reload(); }

  function start() {
    if (WV_TOKEN) { done(); return; }
    const s = document.createElement('script');
    s.src = SDK;
    s.onload = async () => {
      sb = window.supabase.createClient(SUPABASE_URL, ANON);
      let started = false;
      const go = () => { if (!started) { started = true; ungate(); done(); } };
      sb.auth.onAuthStateChange((ev, session) => {
        if (ev === 'PASSWORD_RECOVERY') {
          gate(`<h2>New password</h2><form id="np"><label>New password<input name="pw" type="password" minlength="6" autocomplete="new-password" required></label><button class="btn red wide">Save</button></form>`);
          $('#np').onsubmit = async e => { e.preventDefault(); const { error } = await sb.auth.updateUser({ password: e.target.pw.value }); if (error) alert(error.message); else go(); };
          return;
        }
        if (session) go();
      });
      const { data: { session } } = await sb.auth.getSession();
      if (session) go(); else showSignIn();
    };
    s.onerror = () => gate('<p class="err">Could not load the sign-in. Check your connection and reload.</p>');
    document.head.appendChild(s);
  }

  start();
  return { ready, call, esc, signOut, inApp: !!WV_TOKEN };
})();
