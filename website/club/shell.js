// Club tools shell (Ken 2026-11-27): every club tool page (club home, messages,
// newsletter, officers, spend & gear, partners, lotto admin) shares one white
// header with the club crest, club colour rule and a tool menu, so the tools
// feel like one app. The club dashboard and pitch planner keep their own look.
// The menu comes from the club home's cached club_home() result
// (localStorage cs_club_home_<club>); if it is missing it is fetched with the
// page's own Supabase client (global `sb`).
(function () {
  const P = new URLSearchParams(location.search);
  const onLotto = location.pathname.startsWith('/lotto/');
  const read = k => { try { return JSON.parse(localStorage.getItem(k) || 'null'); } catch (e) { return null; } };
  let clubId = Number(P.get('club')) || null;
  if (!clubId && onLotto) {
    const lid = Number(P.get('lotto'));
    for (let i = 0; i < localStorage.length; i++) {
      const k = localStorage.key(i) || '';
      if (!k.startsWith('cs_club_home_')) continue;
      const c = read(k), l = c && c.h && c.h.tiles && c.h.tiles.lotto;
      if (l && Number(l.lotto_id) === lid) { clubId = Number(k.slice(13)); break; }
    }
  }
  const KEY = 'cs_club_home_' + clubId;
  // The page's global `sb`, or our own client on the same login store.
  let own = null;
  const client = () => {
    try { return sb; } catch (e) {}
    if (!own && window.supabase) own = window.supabase.createClient('https://gyfporsbdftvtakdvukt.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4');
    return own;
  };
  let H = (read(KEY) || {}).h || null;

  // ── Colours (same rules as the club home) ─────────────────────────
  function lum(hex) {
    const m = /^#?([0-9a-f]{6})$/i.exec(hex || ''); if (!m) return null;
    const n = parseInt(m[1], 16), c = [n >> 16, (n >> 8) & 255, n & 255].map(v => { v /= 255; return v <= .03928 ? v / 12.92 : Math.pow((v + .055) / 1.055, 2.4); });
    return .2126 * c[0] + .7152 * c[1] + .0722 * c[2];
  }
  function accentOf(c) {
    const ok = h => { const l = lum(h); return l != null && l < .45; };
    return c && ok(c.primary_colour) ? c.primary_colour : c && ok(c.secondary_colour) ? c.secondary_colour : '#1a1d23';
  }
  function paintColours() {
    if (!H || !H.club) return;
    const a = accentOf(H.club), r = document.documentElement.style;
    window.csAccent = a;
    r.setProperty('--csh', a);
    if (onLotto) { r.setProperty('--g', a); r.setProperty('--acc', a); }
  }
  paintColours();

  // ── Styles ────────────────────────────────────────────────────────
  const st = document.createElement('style');
  st.textContent = `
:root{--csh:#1a1d23}
.csh{background:#fff;border-bottom:5px solid var(--csh);font-family:DM,system-ui,sans-serif;color:#16191f;padding-top:env(safe-area-inset-top)}
.csh-in{max-width:1180px;margin:0 auto;padding:22px 48px 0}
.csh-top{display:flex;align-items:center;gap:16px}
.csh-top img{width:56px;height:56px;object-fit:contain;flex:none}
.csh-top b{display:block;font-size:26px;font-weight:700;line-height:1.15}
.csh-top span{display:block;font-size:16px;color:#5d6573;margin-top:2px}
.csh-out{margin-left:auto;font:600 16px DM,system-ui,sans-serif;color:#5d6573;background:none;border:0;cursor:pointer}
.csh-out:hover{color:#16191f}
.csh-nav{display:flex;gap:2px;margin:16px -13px 0;position:relative;overflow-x:auto;scrollbar-width:none;-webkit-overflow-scrolling:touch}
.csh-nav::-webkit-scrollbar{display:none}
.csh-nav a{flex:none;font:600 16px DM,system-ui,sans-serif;color:#5d6573;text-decoration:none;padding:10px 13px 12px;border-bottom:3px solid transparent;white-space:nowrap}
.csh-nav a:hover{color:#16191f}
.csh-nav a.on{color:var(--csh);border-bottom-color:var(--csh)}
.csh-nav a em{font-style:normal;display:inline-block;min-width:20px;height:20px;line-height:20px;text-align:center;border-radius:10px;background:var(--csh);color:#fff;font-size:12px;margin-left:6px;padding:0 6px;vertical-align:1px}
.csh.nonav .csh-in{padding-bottom:22px}
@media (max-width:760px){
 .csh-in{padding:16px 16px 0}.csh.nonav .csh-in{padding-bottom:16px}
 .csh-top{gap:12px}.csh-top img{width:46px;height:46px}.csh-top b{font-size:21px}.csh-top span{font-size:14.5px}.csh-out{font-size:15px}
 .csh-nav{margin:10px -16px 0;padding:0 8px}.csh-nav a{font-size:15px;padding:9px 10px 11px}
}
@media print{.csh{display:none}}
@media (max-width:760px){body.cs-shell .wrap{padding-left:14px!important;padding-right:14px!important}body.cs-shell .band{padding:18px 14px 8px!important}body.cs-shell .band h1{font-size:22px!important}body.cs-shell .band .sub{font-size:15px!important}}
/* The page's own header becomes a plain title under the shell. */
body.cs-shell .band{background:transparent!important;color:var(--text,#16191f)!important;--onband:var(--text,#16191f);box-shadow:none!important;position:static!important;border:0!important}
body.cs-shell .band .hub,body.cs-shell .band .crest{display:none!important}
body.cs-shell .band h1{font-size:26px!important;line-height:1.2!important}
body.cs-shell .band .sub{font-size:16px!important;color:var(--muted,#5d6573)!important;opacity:1!important}
body.cs-shell .band .back{color:var(--club,var(--csh))!important;opacity:1!important}
body.cs-shell .band [onclick="signOut()"],body.cs-shell .band [data-a="signout"]{display:none!important}
body.cs-shell .band .links button,body.cs-shell .band .links a{color:var(--club,var(--csh))!important;font-size:15px!important;font-weight:600;text-decoration:none!important;opacity:1!important;white-space:nowrap}
body.cs-shell .band .links{flex-wrap:wrap;row-gap:6px}
body.cs-shell .band .links span{font-size:14px;color:var(--muted,#5d6573)}
body.cs-shell .band .chip{background:#fff!important;color:#3b4250!important;border:1.5px solid var(--line,#e4e6eb)!important;font-size:15px!important}
body.cs-shell .band .chip.on{background:var(--club,var(--csh))!important;border-color:var(--club,var(--csh))!important;color:#fff!important}
`;
  document.head.appendChild(st);

  // ── Menu ──────────────────────────────────────────────────────────
  const esc = s => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  function items() {
    const t = (H && H.tiles) || {}, q = '?club=' + clubId, out = [['home', 'Home', '/club/' + q, 0]];
    if (t.dashboard) out.push(['dashboard', 'Dashboard', '/club/dashboard.html' + q + '&period=season', 0]);
    if (t.pitches) out.push(['pitches', 'Pitches', '#cs-pitches', t.pitches.unread || 0]);
    if (t.newsletter) out.push(['newsletter', t.newsletter.title || 'Newsletter', '/club/newsletter.html' + q, t.newsletter.status === 'built' ? 1 : 0]);
    if (t.messages) out.push(['messages', 'Messages', '/club/messages.html' + q, 0]);
    if (t.sponsors) out.push(['sponsors', 'Partners', '/club/sponsors.html' + q, 0]);
    if (t.officers) out.push(['officers', 'Officers', '/club/officers.html' + q, 0]);
    if (t.spend) out.push(['spend', 'Spend & gear', '/club/spend.html' + q, (t.spend.claims || 0) + (t.spend.gear || 0)]);
    if (t.lotto) out.push(['lotto', 'Lotto', '/lotto/admin.html?lotto=' + t.lotto.lotto_id, 0]);
    return out;
  }
  function current() {
    const p = location.pathname;
    if (p.startsWith('/lotto/')) return 'lotto';
    const m = /\/club\/([a-z]+)\.html$/.exec(p);
    return m ? m[1] : 'home';
  }
  function paint() {
    let el = document.getElementById('csh');
    if (!el) { el = document.createElement('header'); el.id = 'csh'; document.body.prepend(el); }
    document.body.classList.add('cs-shell');
    paintColours();
    const c = (H && H.club) || {}, me = (H && H.me) || {}, cur = current();
    const sub = ['Club tools', me.first_name ? 'Hi ' + me.first_name : ''].filter(Boolean).join(' · ');
    const nav = H ? items() : [];
    el.className = 'csh' + (nav.length > 1 ? '' : ' nonav');
    el.innerHTML = `<div class="csh-in"><div class="csh-top">
      ${c.crest ? `<img src="${esc(c.crest)}" alt="">` : ''}
      <div><b>${esc(c.club_name || 'Club tools')}</b><span>${esc(c.club_name ? sub : '')}</span></div>
      ${H ? '<button class="csh-out" id="cshOut">Sign out</button>' : ''}</div>
      ${nav.length > 1 ? `<nav class="csh-nav">${nav.map(([k, l, h, n]) =>
        `<a href="${esc(h)}" data-k="${k}" class="${k === cur ? 'on' : ''}">${esc(l)}${n && k !== cur ? `<em>${n > 99 ? '99+' : n}</em>` : ''}</a>`).join('')}</nav>` : ''}</div>`;
    const out = document.getElementById('cshOut');
    if (out) out.onclick = async () => {
      try { localStorage.removeItem(KEY); } catch (e) {}
      try { if (client()) await client().auth.signOut(); } catch (e) {}
      location.reload();
    };
    const pt = el.querySelector('[data-k="pitches"]');
    if (pt) pt.onclick = openPlanner;
    const nv = el.querySelector('.csh-nav'), on = el.querySelector('.csh-nav a.on');
    if (nv && on && nv.scrollWidth > nv.clientWidth) nv.scrollLeft = on.offsetLeft - (nv.clientWidth - on.offsetWidth) / 2;
  }
  // The planner is another website with its own login store: hand this login
  // over in the link's #fragment (never sent to a server; the planner wipes it).
  async function openPlanner(e) {
    e.preventDefault();
    const url = `https://coachsmart-v3.web.app/pitches?club=${clubId}&look=club`;
    try {
      const { data: { session } } = await client().auth.getSession();
      location.href = session ? url + '#cs_rt=' + encodeURIComponent(session.refresh_token) : url;
    } catch (err) { location.href = url; }
  }
  // Called by the club home after it loads fresh data.
  window.csShellSet = h => { H = h; paint(); };

  async function start() {
    if (!clubId) return;
    if (window.csShellOwner) return; // the page paints the shell itself
    let session = null;
    try { session = client() ? (await client().auth.getSession()).data.session : null; } catch (e) {}
    const cached = read(KEY);
    if (!session) {
      // The page has its own sign-in form: paint the shell once it signs in.
      try { const { data } = client().auth.onAuthStateChange(ev => { if (ev === 'SIGNED_IN') { data.subscription.unsubscribe(); setTimeout(start, 0); } }); } catch (e) {}
      return;
    }
    if (cached && cached.uid === session.user.id) { H = cached.h; paint(); return; }
    try {
      const { data } = await client().rpc('club_home', { p_club: clubId });
      if (data && !data.error) {
        H = data; paint();
        try { localStorage.setItem(KEY, JSON.stringify({ uid: session.user.id, h: data })); } catch (e) {}
      }
    } catch (e) {}
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start); else start();
})();
