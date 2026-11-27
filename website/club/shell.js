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
    // Club crest as the tab icon from the first moment, so it never flips
    // back to the CoachSmart icon while the page loads (Ken 2026-11-27).
    if (H.club.crest) ['icon', 'apple-touch-icon'].forEach(rel => {
      let l = document.querySelector(`link[rel="${rel}"]`);
      if (!l) { l = document.createElement('link'); l.rel = rel; document.head.appendChild(l); }
      if (l.getAttribute('href') !== H.club.crest) l.href = H.club.crest;
    });
  }
  paintColours();

  // ── Styles ────────────────────────────────────────────────────────
  const st = document.createElement('style');
  st.textContent = `
:root{--csh:#1a1d23}
.csh{background:#fff;border-bottom:5px solid var(--csh);font-family:DM,system-ui,sans-serif;color:#16191f;padding-top:env(safe-area-inset-top)}
.csh-in{max-width:none;margin:0 auto;padding:22px 48px 0}
.csh-top{display:flex;align-items:center;gap:16px}
.csh-top img{width:56px;height:56px;object-fit:contain;flex:none}
.csh-top b{display:block;font-size:26px;font-weight:700;line-height:1.15}
.csh-top span{display:block;font-size:16px;color:#5d6573;margin-top:2px}
.csh-out{margin-left:auto;font:600 16px DM,system-ui,sans-serif;color:#5d6573;background:none;border:0;cursor:pointer}
.csh-out:hover{color:#16191f}
.csh-nav{display:flex;gap:0;margin:14px -10px 0;padding-bottom:10px;position:relative;overflow-x:auto;scrollbar-width:none;-webkit-overflow-scrolling:touch}
.csh-nav::-webkit-scrollbar{display:none}
.csh-nav a{flex:none;display:flex;align-items:center;gap:7px;font:600 15.5px DM,system-ui,sans-serif;color:#5d6573;text-decoration:none;padding:8px 10px;border-radius:10px;white-space:nowrap}
.csh-nav a svg{width:19px;height:19px;stroke:currentColor;fill:none;stroke-width:1.9;stroke-linecap:round;stroke-linejoin:round;flex:none}
.csh-nav a:hover{color:#16191f;background:#f2f3f6}
.csh-nav a.on{color:var(--csh);background:color-mix(in srgb,var(--csh) 9%,#fff)}
.csh-nav a em{font-style:normal;display:inline-block;margin-left:-2px!important;min-width:20px;height:20px;line-height:20px;text-align:center;border-radius:10px;background:var(--csh);color:#fff;font-size:12px;margin-left:6px;padding:0 6px;vertical-align:1px}
.csh.nonav .csh-in{padding-bottom:22px}
@media (max-width:760px){
 .csh-in{padding:16px 16px 0}.csh.nonav .csh-in{padding-bottom:16px}
 .csh-top{gap:12px}.csh-top img{width:46px;height:46px}.csh-top b{font-size:21px}.csh-top span{font-size:14.5px}.csh-out{font-size:15px}
 .csh-nav{margin:10px -16px 0;padding:0 10px 10px}.csh-nav a{font-size:15px;padding:8px 10px;gap:7px}.csh-nav a svg{width:19px;height:19px}
}
@media print{.csh{display:none}}
/* Smooth switching between club tools: the header stays put, only the page below changes. */
@view-transition{navigation:auto}
.csh{view-transition-name:csh}
::view-transition-old(root),::view-transition-new(root){animation-duration:.18s}
@media (max-width:760px){body.cs-shell:not(.cs-own) .wrap{padding-left:14px!important;padding-right:14px!important}body.cs-shell:not(.cs-own) .band{padding:18px 14px 8px!important}body.cs-shell:not(.cs-own) .band h1{font-size:22px!important}body.cs-shell:not(.cs-own) .band .sub{font-size:15px!important}}
/* The page's own header becomes a plain title under the shell. */
body.cs-shell:not(.cs-own) .band{background:transparent!important;color:var(--text,#16191f)!important;--onband:var(--text,#16191f);box-shadow:none!important;position:static!important;border:0!important}
body.cs-shell:not(.cs-own) .band .hub,body.cs-shell:not(.cs-own) .band .crest{display:none!important}
body.cs-shell:not(.cs-own) .band h1{font-size:26px!important;line-height:1.2!important}
body.cs-shell:not(.cs-own) .band .sub{font-size:16px!important;color:var(--muted,#5d6573)!important;opacity:1!important}
body.cs-shell:not(.cs-own) .band .back{color:var(--club,var(--csh))!important;opacity:1!important}
body.cs-shell:not(.cs-own) .band [onclick="signOut()"],body.cs-shell:not(.cs-own) .band [data-a="signout"]{display:none!important}
body.cs-shell:not(.cs-own) .band .links button,body.cs-shell:not(.cs-own) .band .links a{color:var(--club,var(--csh))!important;font-size:15px!important;font-weight:600;text-decoration:none!important;opacity:1!important;white-space:nowrap}
body.cs-shell:not(.cs-own) .band .links{flex-wrap:wrap;row-gap:6px}
body.cs-shell:not(.cs-own) .band .links span{font-size:14px;color:var(--muted,#5d6573)}
body.cs-shell:not(.cs-own) .band .chip{background:#fff!important;color:#3b4250!important;border:1.5px solid var(--line,#e4e6eb)!important;font-size:15px!important}
body.cs-shell:not(.cs-own) .band .chip.on{background:var(--club,var(--csh))!important;border-color:var(--club,var(--csh))!important;color:#fff!important}
/* One column for every tool (Ken 2026-11-27): the title row and the page line up with the header. */
body.cs-shell:not(.cs-own) .band{max-width:none!important;margin:0 auto!important;padding:30px 48px 14px!important;display:flex!important;align-items:flex-start!important;gap:16px!important;flex-wrap:wrap}
body.cs-shell:not(.cs-own) .band .top{display:flex;align-items:center;gap:12px;max-width:none!important;margin:0!important}
body.cs-shell:not(.cs-own) .band .sub:empty{display:none}
body.cs-shell:not(.cs-own) .band .right{margin-left:auto!important;align-items:flex-end!important;width:auto!important}
body.cs-shell:not(.cs-own) .band .links span{display:none}
body.cs-shell:not(.cs-own) .band .links button,body.cs-shell:not(.cs-own) .band .links a{background:#fff!important;border:1.5px solid var(--line,#e4e6eb)!important;border-radius:999px!important;padding:7px 14px!important;cursor:pointer}
body.cs-shell:not(.cs-own) .band .wk button{background:#fff!important;border:1.5px solid var(--line,#e4e6eb)!important;color:var(--text,#16191f)!important}
body.cs-shell:not(.cs-own) .band .wk span{color:var(--text,#16191f)!important;font-size:16px!important}
body.cs-shell:not(.cs-own) .wrap{max-width:none!important;margin-left:auto!important;margin-right:auto!important;padding-left:48px!important;padding-right:48px!important}
body.cs-shell .abar{margin:0!important;padding:30px 0 14px!important}
@media (max-width:760px){body.cs-shell:not(.cs-own) .wrap{padding-left:14px!important;padding-right:14px!important}body.cs-shell:not(.cs-own) .band{padding:20px 14px 8px!important}body.cs-shell:not(.cs-own) .band .right{margin-left:0!important;align-items:flex-start!important}body.cs-shell .abar{padding:20px 0 8px!important}}
`;
  document.head.appendChild(st);

  const ICON = {
    home: '<path d="M3 11l9-7 9 7v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/>',
    dashboard: '<path d="M3 3v18h18"/><path d="M7 15l4-4 3 3 6-7"/>',
    pitches: '<rect x="2" y="5" width="20" height="14" rx="1.5"/><path d="M12 5v14"/><circle cx="12" cy="12" r="2.5"/>',
    newsletter: '<path d="M4 4h13v16H6a2 2 0 0 1-2-2z"/><path d="M17 8h3v10a2 2 0 0 1-2 2"/><path d="M8 8h5M8 12h5M8 16h3"/>',
    messages: '<path d="M3 11l15-6v14L3 13z"/><path d="M7 13v5a2 2 0 0 0 4 0v-3.5"/>',
    sponsors: '<path d="M12 2l3 6.5 7 .8-5.2 4.8 1.4 7L12 17.6 5.8 21l1.4-7L2 9.3l7-.8z"/>',
    officers: '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0"/><circle cx="17.5" cy="9" r="2.5"/><path d="M17 14a5 5 0 0 1 5 5"/>',
    spend: '<path d="M5 2h14v20l-3-2-2 2-2-2-2 2-2-2-3 2z"/><path d="M9 7h6M9 11h6"/>',
    lotto: '<path d="M3 7h18v3a2 2 0 0 0 0 4v3H3v-3a2 2 0 0 0 0-4z"/>'
  };
  // ── Menu ──────────────────────────────────────────────────────────
  const esc = s => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  function items() {
    const t = (H && H.tiles) || {}, q = '?club=' + clubId, out = [['home', 'Home', '/club/' + q, 0]];
    if (t.dashboard) out.push(['dashboard', 'Dashboard', '/club/dashboard.html' + q + '&period=season', 0]);
    if (t.pitches) out.push(['pitches', 'Pitches', '/club/pitches.html' + q, t.pitches.unread || 0]);
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
    const sub = ['ClubSmart', me.first_name ? 'Hi ' + me.first_name : ''].filter(Boolean).join(' · ');
    const nav = H ? items() : [];
    el.className = 'csh' + (nav.length > 1 ? '' : ' nonav');
    el.innerHTML = `<div class="csh-in"><div class="csh-top">
      ${c.crest ? `<img src="${esc(c.crest)}" alt="">` : ''}
      <div><b>${esc(c.club_name || 'ClubSmart')}</b><span>${esc(c.club_name ? sub : '')}</span></div>
      ${H ? '<button class="csh-out" id="cshOut">Sign out</button>' : ''}</div>
      ${nav.length > 1 ? `<nav class="csh-nav">${nav.map(([k, l, h, n]) =>
        `<a href="${esc(h)}" data-k="${k}" class="${k === cur ? 'on' : ''}"><svg viewBox="0 0 24 24">${ICON[k] || ''}</svg>${esc(l)}${n && k !== cur ? `<em>${n > 99 ? '99+' : n}</em>` : ''}</a>`).join('')}</nav>` : ''}</div>`;
    const out = document.getElementById('cshOut');
    if (out) out.onclick = async () => {
      try { Object.keys(localStorage).filter(k => /^cs_(club_home|spend|sponsors|msgs|officers|news|dash)_/.test(k)).forEach(k => localStorage.removeItem(k)); } catch (e) {}
      try { if (client()) await client().auth.signOut(); } catch (e) {}
      location.reload();
    };
    const nv = el.querySelector('.csh-nav'), on = el.querySelector('.csh-nav a.on');
    if (nv && on && nv.scrollWidth > nv.clientWidth) nv.scrollLeft = on.offsetLeft - (nv.clientWidth - on.offsetWidth) / 2;
    preload();
  }
  // Pages open instantly (Ken 2026-11-27, "one ClubSmart app"): when the
  // pointer rests on a tab (or a finger goes down on it) the browser builds
  // that tool in the background, data and all, and swaps it in on click
  // while the header stays put. Chrome and Edge; other browsers just load it.
  function preload() {
    if (document.getElementById('csSpec') || !(HTMLScriptElement.supports && HTMLScriptElement.supports('speculationrules'))) return;
    const s = document.createElement('script');
    s.type = 'speculationrules'; s.id = 'csSpec';
    s.textContent = JSON.stringify({ prerender: [{ where: { and: [{ selector_matches: '.csh-nav a' }, { not: { selector_matches: '.csh-nav a.on, .csh-nav a[data-k="pitches"]' } }] }, eagerness: 'moderate' }] });
    document.head.appendChild(s);
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
    if (cached && cached.uid === session.user.id) { H = cached.h; if (!document.getElementById('csh')) paint(); return; }
    try {
      const { data } = await client().rpc('club_home', { p_club: clubId });
      if (data && !data.error) {
        H = data; paint();
        try { localStorage.setItem(KEY, JSON.stringify({ uid: session.user.id, h: data })); } catch (e) {}
      }
    } catch (e) {}
  }
  // Paint straight away from the cache when this browser is signed in as the
  // cached user, so the header is there on the first frame (no flash between tools).
  function early() {
    const c = read(KEY);
    let uid = null;
    try { uid = (read('sb-gyfporsbdftvtakdvukt-auth-token') || {}).user.id; } catch (e) {}
    if (!clubId || !c || !uid || c.uid !== uid) return;
    H = c.h;
    if (document.body) return paint();
    const mo = new MutationObserver(() => { if (document.body) { mo.disconnect(); paint(); } });
    mo.observe(document.documentElement, { childList: true });
  }
  early();
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start); else start();
})();
