// Senior team diary: sign-in with the CoachSmart login, the player's details,
// and ticks saved to their account (so they follow them to any phone).
// diary.js waits on ACCOUNT.ready before drawing.
window.ACCOUNT = (function () {
  const SUPABASE_URL = 'https://gyfporsbdftvtakdvukt.supabase.co';
  const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4';
  const SDK = 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.43.4/dist/umd/supabase.min.js';
  const FIELDS = [
    { k: 'first_name', l: 'First name', req: true, ac: 'given-name' },
    { k: 'last_name', l: 'Last name', req: true, ac: 'family-name' },
    { k: 'phone', l: 'Phone', type: 'tel', ac: 'tel' },
    { k: 'date_of_birth', l: 'Date of birth', type: 'date', ac: 'bday' },
    { k: 'emergency_name', l: 'Emergency contact name' },
    { k: 'emergency_phone', l: 'Emergency contact phone', type: 'tel' },
    { k: 'medical_notes', l: 'Injuries or medical notes', area: true }
  ];

  let sb = null, user = null, profile = null, store = {}, done;
  const ready = new Promise(r => { done = r; });
  const $ = s => document.querySelector(s);
  const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
  const cacheKey = () => 'senior-diary:' + user.id;

  // ---- the sign-in / details screen, drawn over the page ----
  function gate(html) {
    let g = $('#gate');
    if (!g) { g = document.createElement('div'); g.id = 'gate'; document.body.appendChild(g); }
    g.innerHTML = `<div class="gate-in">${html}</div>`;
    g.hidden = false;
    document.body.classList.add('gated');
  }
  function ungate() {
    const g = $('#gate'); if (g) g.hidden = true;
    document.body.classList.remove('gated');
  }

  function showSignIn(msg = '') {
    gate(`<img src="../images/clontarf-crest.png" alt="">
      <h2>Sign in</h2>
      <p class="gm">Use your CoachSmart email and password.</p>
      ${msg ? `<p class="gerr">${esc(msg)}</p>` : ''}
      <form id="signin">
        <label>Email<input name="email" type="email" autocomplete="email" required></label>
        <label>Password<input name="password" type="password" autocomplete="current-password" required></label>
        <button class="gbtn" type="submit">Sign in</button>
      </form>
      <button class="glink" id="forgot" type="button">Forgot your password?</button>`);
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
      const { error } = await sb.auth.resetPasswordForEmail(email, { redirectTo: location.origin + location.pathname });
      showSignIn(error ? error.message : 'Check your email for a link to set a new password.');
    };
  }

  function showProfile(first) {
    const p = profile || {};
    gate(`<h2>${first ? 'Your details' : 'Your account'}</h2>
      <p class="gm">${first ? 'Just once, so the coaches have what they need.' : esc(user.email)}</p>
      <form id="profile">
        ${FIELDS.map(f => `<label>${f.l}${f.req ? '' : ' <small>(optional)</small>'}${f.area
          ? `<textarea name="${f.k}" rows="3">${esc(p[f.k])}</textarea>`
          : `<input name="${f.k}" type="${f.type || 'text'}" value="${esc(p[f.k])}" ${f.ac ? `autocomplete="${f.ac}"` : ''} ${f.req ? 'required' : ''}>`}</label>`).join('')}
        <button class="gbtn" type="submit">Save</button>
      </form>
      ${first ? '' : '<button class="glink" id="close" type="button">Back to the diary</button><button class="glink" id="signout" type="button">Sign out</button>'}`);
    $('#profile').onsubmit = async e => {
      e.preventDefault();
      const f = e.target, b = f.querySelector('button[type=submit]');
      const row = { user_id: user.id, updated_at: new Date().toISOString() };
      FIELDS.forEach(x => { row[x.k] = f[x.k].value.trim() || null; });
      b.disabled = true; b.textContent = 'Saving…';
      const { error } = await sb.from('diary_profiles').upsert(row);
      if (error) { b.disabled = false; b.textContent = 'Save'; alert('Could not save: ' + error.message); return; }
      profile = row; who(); ungate(); done();
    };
    if (!first) {
      $('#close').onclick = ungate;
      $('#signout').onclick = async () => { await sb.auth.signOut(); location.reload(); };
    }
  }

  function who() {
    const el = $('#who'); if (!el || !profile) return;
    el.textContent = profile.first_name || 'Account';
    el.hidden = false;
  }

  // ---- after sign-in: details and ticks ----
  async function signedIn(u) {
    if (user && user.id === u.id) return;
    user = u;
    try { store = JSON.parse(localStorage.getItem(cacheKey())) || {}; } catch (e) {}
    gate('<p class="gm">Loading your diary…</p>');
    const [{ data: p }, { data: rows, error }] = await Promise.all([
      sb.from('diary_profiles').select('*').eq('user_id', user.id).maybeSingle(),
      sb.from('diary_ticks').select('day, ticks').eq('user_id', user.id)
    ]);
    if (!error) { store = {}; (rows || []).forEach(r => { store[r.day] = r.ticks; }); keep(); }
    profile = p;
    if (!profile) {
      // First visit: start from the name and phone CoachSmart already has.
      const { data: cs } = await sb.from('users').select('first_name, last_name, phone_number').eq('user_id', user.id).maybeSingle();
      profile = cs ? { first_name: cs.first_name, last_name: cs.last_name, phone: cs.phone_number } : null;
      showProfile(true);
      profile = null;
      return;
    }
    who(); ungate(); done();
  }

  // ---- ticks: kept on the phone for speed, saved to the account a moment later ----
  const keep = () => { try { localStorage.setItem(cacheKey(), JSON.stringify(store)); } catch (e) {} };
  const pending = new Map();
  function push(d) {
    clearTimeout(pending.get(d));
    pending.set(d, setTimeout(async () => {
      pending.delete(d);
      const { error } = await sb.from('diary_ticks').upsert({ user_id: user.id, day: d, ticks: store[d] || {}, updated_at: new Date().toISOString() });
      if (error) console.warn('Tick not saved to account', error);
    }, 600));
  }
  const ticked = (d, id) => !!(store[d] && store[d][id]);
  function toggle(d, id) {
    store[d] = store[d] || {};
    if (store[d][id]) delete store[d][id]; else store[d][id] = 1;
    keep(); push(d);
  }
  // Numbers the player types in (bodyweight, best sets), kept with the day's ticks.
  const value = (d, id) => (store[d] && typeof store[d][id] === 'string') ? store[d][id] : '';
  function setValue(d, id, v) {
    store[d] = store[d] || {};
    if (v) store[d][id] = v; else delete store[d][id];
    keep(); push(d);
  }

  async function boot() {
    if (!window.supabase) {
      await new Promise(r => { const s = document.createElement('script'); s.src = SDK; s.onload = s.onerror = r; document.head.appendChild(s); });
    }
    if (!window.supabase) { gate('<p class="gerr">Could not load the sign-in. Please refresh.</p>'); return; }
    sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    sb.auth.onAuthStateChange((ev, session) => {
      if (ev === 'PASSWORD_RECOVERY') { setNewPassword(); return; }
      if (session && session.user) signedIn(session.user);
    });
    const { data: { session } } = await sb.auth.getSession();
    if (!session) showSignIn();
  }

  function setNewPassword() {
    gate(`<h2>New password</h2><form id="newpw">
      <label>New password<input name="pw" type="password" autocomplete="new-password" minlength="6" required></label>
      <button class="gbtn" type="submit">Save password</button></form>`);
    $('#newpw').onsubmit = async e => {
      e.preventDefault();
      const { error } = await sb.auth.updateUser({ password: e.target.pw.value });
      if (error) { alert(error.message); return; }
      location.replace(location.pathname);
    };
  }

  document.addEventListener('click', e => { if (e.target.closest('#who')) showProfile(false); });
  boot();
  return { ready, ticked, toggle, value, setValue };
})();
