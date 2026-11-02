/* CoachSmart webview sign-in, shared by pages the app opens with ?token=<jwt>.
 *
 * The token in the URL lasts an hour, and a coach can easily keep a page open
 * longer than that. Before each call this asks the app for a fresh token
 * when the current one has under two minutes left (FlutterBridge "getToken";
 * the NativeWebView widget answers with window.csSetToken(token, expiresAt)).
 * If a call still comes back 401, it asks once more and retries.
 *
 * In a plain browser (no FlutterBridge) it just uses the URL token.
 *
 *   CSAuth.fetch(url, { method, headers, body })  adds apikey + Authorization
 *   CSAuth.token()                                 current token ('' if none)
 */
(function () {
  'use strict';

  const ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4';
  const params = new URLSearchParams(location.search);
  const claims = t => {
    try { return JSON.parse(atob(t.split('.')[1].replace(/-/g, '+').replace(/_/g, '/'))); } catch (_) { return {}; }
  };
  const bridge = () => window.FlutterBridge || null;

  let token = params.get('token') || params.get('currentAuthToken') || '';
  let exp = (claims(token).exp || 0) * 1000;
  let waiters = [];
  let pending = null;
  let appAnswers = null; // null = not known yet; false = older app build that never replies

  window.csSetToken = function (t, expiresAt) {
    if (t && typeof t === 'string') {
      token = t;
      const e = Number(expiresAt) || 0;
      exp = e ? (e > 1e12 ? e : e * 1000) : (claims(t).exp || 0) * 1000;
      appAnswers = true;
    }
    waiters.splice(0).forEach(f => f());
  };

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
    if (token && (force || exp - Date.now() < 120000)) await askApp();
    return token;
  }

  async function authFetch(url, opts) {
    opts = opts || {};
    const go = t => fetch(url, Object.assign({}, opts, {
      headers: Object.assign({}, opts.headers || {}, { apikey: ANON, Authorization: 'Bearer ' + (t || ANON) }),
    }));
    let res = await go(await fresh(false));
    if (res.status === 401 && token && bridge()) {
      const before = token;
      await fresh(true);
      if (token !== before) res = await go(token);
    }
    return res;
  }

  // Keep it topped up while the page sits open, so a tap never waits on it.
  setInterval(() => { if (token && exp - Date.now() < 10 * 60000) fresh(true); }, 60000);

  window.CSAuth = { fetch: authFetch, token: () => token, fresh };
})();
