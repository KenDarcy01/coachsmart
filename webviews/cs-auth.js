/* CoachSmart webview sign-in, shared by pages the app opens with ?token=<jwt>.
 *
 * The token in the URL lasts an hour from when the app made it, and a coach
 * can easily keep a page open longer than that. When the current token has
 * under two minutes left, this asks the app for a fresh one (FlutterBridge
 * "getToken"; the NativeWebView widget answers with
 * window.csSetToken(token, expiresAt)). If a call still comes back 401, it
 * asks once more and retries.
 *
 * Load it before the page's own scripts. It wraps window.fetch: any call to
 * Supabase that carries a token this page has held (the URL one or an older
 * fresh one) is sent with the current token instead. So pages that build
 * their own Authorization header, or use supabase-js with the URL token as a
 * global header, need no other change.
 *
 * Inside an iframe of a page that also loads this file, it borrows the parent
 * page's token, since only the top page can talk to the app.
 *
 * In a plain browser (no FlutterBridge) the URL token is used as it is.
 *
 *   CSAuth.fetch(url, opts)  adds apikey + Authorization with a fresh token
 *   CSAuth.token()           current token ('' if none)
 */
(function () {
  'use strict';
  if (window.CSAuth) return;

  const ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4';
  const SUPABASE_HOST = 'gyfporsbdftvtakdvukt.supabase.co';
  const params = new URLSearchParams(location.search);
  const claims = t => {
    try { return JSON.parse(atob(t.split('.')[1].replace(/-/g, '+').replace(/_/g, '/'))); } catch (_) { return {}; }
  };
  const bridge = () => window.FlutterBridge || null;
  const rawFetch = window.fetch.bind(window);

  let parentAuth = null;
  try { if (window.parent !== window && window.parent.CSAuth) parentAuth = window.parent.CSAuth; } catch (_) {}

  let token = params.get('token') || params.get('currentAuthToken') || params.get('access_token') || '';
  let exp = (claims(token).exp || 0) * 1000;
  const known = new Set(token ? [token] : []);   // every token this page has held
  let waiters = [];
  let pending = null;
  let appAnswers = null; // null = not known yet; false = older app build that never replies

  function setToken(t, expMs) {
    token = t;
    known.add(t);
    exp = expMs || (claims(t).exp || 0) * 1000;
  }

  if (!parentAuth) {
    window.csSetToken = function (t, expiresAt) {
      if (t && typeof t === 'string') {
        const e = Number(expiresAt) || 0;
        setToken(t, e ? (e > 1e12 ? e : e * 1000) : 0);
        appAnswers = true;
      }
      waiters.splice(0).forEach(f => f());
    };
  }

  function askApp() {
    if (!bridge() || appAnswers === false) return Promise.resolve();
    if (pending) return pending;
    const before = token;
    pending = new Promise(resolve => {
      waiters.push(resolve);
      setTimeout(resolve, appAnswers ? 6000 : 3000);
      try { bridge().postMessage('getToken'); } catch (_) { resolve(); }
    }).then(() => {
      if (token === before && appAnswers === null) appAnswers = false;
      pending = null;
    });
    return pending;
  }

  async function fresh(force) {
    if (!token) return token;
    if (parentAuth) {
      const t = await parentAuth.fresh(force);
      if (t && t !== token) setToken(t);
      return token;
    }
    if (force || exp - Date.now() < 120000) await askApp();
    return token;
  }

  const isSupabase = url => {
    try { return new URL(url, location.href).host === SUPABASE_HOST; } catch (_) { return false; }
  };

  // Reads/writes the Authorization header whether headers is a plain object or Headers.
  function getAuth(h) {
    if (!h) return null;
    if (typeof Headers !== 'undefined' && h instanceof Headers) return h.get('Authorization');
    for (const k in h) if (k.toLowerCase() === 'authorization') return h[k];
    return null;
  }
  function withAuth(h, value) {
    if (typeof Headers !== 'undefined' && h instanceof Headers) {
      const n = new Headers(h); n.set('Authorization', value); return n;
    }
    const n = {};
    for (const k in h) if (k.toLowerCase() !== 'authorization') n[k] = h[k];
    n.Authorization = value;
    return n;
  }

  async function sendWithRetry(url, opts) {
    const go = t => rawFetch(url, Object.assign({}, opts, { headers: withAuth(opts.headers || {}, 'Bearer ' + (t || ANON)) }));
    let res = await go(await fresh(false));
    if (res.status === 401 && token && (bridge() || parentAuth)) {
      const before = token;
      await fresh(true);
      if (token !== before) res = await go(token);
    }
    return res;
  }

  // Our own calls.
  function authFetch(url, opts) {
    opts = opts || {};
    const h = Object.assign({}, opts.headers || {}, { apikey: ANON });
    return sendWithRetry(url, Object.assign({}, opts, { headers: h }));
  }

  // Every other Supabase call on the page that carries one of our tokens.
  window.fetch = function (input, init) {
    if (typeof input === 'string' || input instanceof URL) {
      const auth = init && getAuth(init.headers);
      const m = auth && /^Bearer\s+(.+)$/i.exec(auth);
      if (m && known.has(m[1]) && isSupabase(String(input))) return sendWithRetry(input, init);
    }
    return rawFetch(input, init);
  };

  // Keep it topped up while the page sits open, so a tap never waits on it.
  if (!parentAuth) setInterval(() => { if (token && exp - Date.now() < 10 * 60000) fresh(true); }, 60000);

  window.CSAuth = { fetch: authFetch, token: () => token, fresh };
})();
