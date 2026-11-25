// Club newsletter page renderer (2026-11-25, thread "Build The Tarbh Times
// club newsletter"). Shared by the admin (club/newsletter.html) and the
// public share page (club/news.html). renderPaper(d) returns a whole HTML
// document for an iframe: phone width, one column, newspaper look in the
// club's colours with its crest. d = { club, settings, issue, stories }.
(function () {
  const F = '/club/newsletter/fonts/';
  const esc = s => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  const FONTS = `@font-face{font-family:Mast;font-weight:700;src:url(${F}grenze-gotisch-latin-700-normal.woff2) format('woff2')}
@font-face{font-family:PF;font-weight:700;src:url(${F}playfair-display-latin-700-normal.woff2) format('woff2')}
@font-face{font-family:PF;font-weight:900;src:url(${F}playfair-display-latin-900-normal.woff2) format('woff2')}
@font-face{font-family:PF;font-weight:700;font-style:italic;src:url(${F}playfair-display-latin-700-italic.woff2) format('woff2')}
@font-face{font-family:SS;font-weight:400;src:url(${F}source-serif-4-latin-400-normal.woff2) format('woff2')}
@font-face{font-family:SS;font-weight:400;font-style:italic;src:url(${F}source-serif-4-latin-400-italic.woff2) format('woff2')}
@font-face{font-family:SS;font-weight:700;src:url(${F}source-serif-4-latin-700-normal.woff2) format('woff2')}
@font-face{font-family:OS;font-weight:400;src:url(${F}oswald-latin-400-normal.woff2) format('woff2')}
@font-face{font-family:OS;font-weight:700;src:url(${F}oswald-latin-700-normal.woff2) format('woff2')}`;
  const MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const dm = s => { const [y, m, d] = s.split('-').map(Number); return { y, m, d }; };
  function weekLabel(a, b) {
    const x = dm(a), z = dm(b);
    return x.m === z.m ? `${x.d} to ${z.d} ${MON[z.m - 1]} ${z.y}` : `${x.d} ${MON[x.m - 1]} to ${z.d} ${MON[z.m - 1]} ${z.y}`;
  }
  function lum(hex) {
    const m = /^#?([0-9a-f]{6})$/i.exec(hex || ''); if (!m) return null;
    const n = parseInt(m[1], 16), c = [n >> 16, (n >> 8) & 255, n & 255].map(v => { v /= 255; return v <= .03928 ? v / 12.92 : Math.pow((v + .055) / 1.055, 2.4); });
    return .2126 * c[0] + .7152 * c[1] + .0722 * c[2];
  }
  function colours(c) {
    const dark = h => { const l = lum(h); return l != null && l < .45; };
    const list = [c.primary_colour, c.third_colour, c.secondary_colour].filter(dark);
    return { a: list[0] || '#1b1b1b', b: list[1] || list[0] || '#1b1b1b' };
  }
  const paras = t => String(t || '').split(/\n\s*\n/).map(p => p.trim()).filter(Boolean);
  function bodyHtml(t, drop) {
    return paras(t).map((p, i) => {
      if (drop && i === 0) return `<p><span class="dc">${esc(p[0])}</span>${esc(p.slice(1))}</p>`;
      return `<p>${esc(p)}</p>`;
    }).join('');
  }
  function scoreBox(d) {
    if (!d || !d.show_score || !d.home_score) return '';
    const hu = d.us === 'home';
    return `<div class="score"><div class="t${hu ? ' us' : ''}">${esc(d.home)}</div><div class="n${hu ? ' us' : ''}">${esc(d.home_score)}</div><div class="n">·</div><div class="n${hu ? '' : ' us'}">${esc(d.away_score)}</div><div class="t${hu ? '' : ' us'}">${esc(d.away)}</div></div>`;
  }
  const photo = s => (s.photo_url && !(s.data && s.data.hide_photo)) ? `<figure><img src="${esc(s.photo_url)}" crossorigin="anonymous" alt=""></figure>` : '';
  const byline = d => d && d.day ? `<div class="byline">${esc(d.dow)} ${Number(d.day.slice(8))} ${MON[Number(d.day.slice(5, 7)) - 1]}${d.venue ? ' · ' + esc(d.venue) : ''}</div>` : '';
  function badge(s) {
    const d = s.data || {};
    if (s.kind !== 'final' || d.show_score) return '';
    return `<span class="pill">${d.round === 'Semi-Final' ? 'Semi-finalists' : 'Runners-up'}</span>`;
  }

  function lead(s) {
    return `<article class="lead">
      ${s.kicker ? `<div class="kicker">${esc(s.kicker)}</div>` : ''}
      <h2>${esc(s.headline)}</h2>
      ${s.deck ? `<p class="deck">${esc(s.deck)}</p>` : ''}
      ${photo(s)}${scoreBox(s.data)}${byline(s.data)}
      ${bodyHtml(s.body, true)}${badge(s)}
    </article><hr class="d">`;
  }
  function story(s) {
    return `<article class="story">
      ${s.kicker ? `<div class="kicker">${esc(s.kicker)}</div>` : ''}
      ${s.headline ? `<h3>${esc(s.headline)}</h3>` : ''}
      ${scoreBox(s.data)}${photo(s)}${bodyHtml(s.body)}${badge(s)}
    </article>`;
  }
  function short(s) {
    return `<div class="go">
      ${s.kicker ? `<div class="kicker">${esc(s.kicker)}</div>` : ''}
      ${s.headline ? `<h3>${esc(s.headline)}</h3>` : ''}
      ${photo(s)}${bodyHtml(s.body)}
    </div>`;
  }
  function winsBox(s) {
    const rows = (s.data && s.data.rows) || [];
    return `<section class="board"><h3>${esc(s.headline || 'Big Wins This Week')}</h3>${rows.map(r =>
      `<div class="row"><div><div class="c">${esc(r.label)}</div><div class="m">${esc(r.home)} v ${esc(r.away)}</div></div><div class="r">${esc(r.home_score)} · ${esc(r.away_score)}</div></div>`).join('')}</section>`;
  }
  function fixtures(s) {
    const rows = (s.data && s.data.rows) || [];
    return `<section class="fxs"><div class="kicker red">Coming up · get down and support</div><h3>${esc(s.headline || 'Coming Up This Week')}</h3>${rows.map(r => {
      const opp = r.us === 'home' ? r.away : r.home;
      const tag = r.final ? '<span class="tag">Final</span>' : r.semi ? '<span class="tag">Semi-final</span>' : '';
      return `<div class="fx"><div class="d"><b>${Number(r.day.slice(8))}</b><span>${esc(r.dow)}</span></div><div><div class="w">${esc(r.label)} v ${esc(opp)} ${tag}</div><div class="v">${esc(r.competition)}${r.round ? ' · ' + esc(r.round) : ''} · ${esc(r.venue)} · ${esc(r.time)}</div></div></div>`;
    }).join('')}${s.body ? bodyHtml(s.body) : ''}</section>`;
  }

  window.renderPaper = function (d, opts) {
    const o = opts || {};
    const { club, settings, issue } = d;
    const c = colours(club);
    const items = (d.stories || []).filter(s => s.included !== false);
    const parts = items.map(s => {
      if (s.kind === 'wins_box') return winsBox(s);
      if (s.kind === 'fixtures') return fixtures(s);
      if (s.placement === 'lead') return lead(s);
      if (s.placement === 'short' || s.kind === 'go_games') return short(s);
      return story(s);
    }).join('');
    const title = settings.title || 'Club newsletter';
    return `<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(title)} · ${esc(weekLabel(issue.week_start, issue.week_end))}</title>
<style>
${FONTS}
:root{--club:${c.a};--club2:${c.b};--paper:#f6f1e6;--ink:#1b1b1b;--muted:#5d574d;--rule:#2a2a2a}
*{box-sizing:border-box}
html,body{margin:0;background:${o.page || '#d9d3c5'}}
body{font-family:SS,Georgia,serif;color:var(--ink);-webkit-font-smoothing:antialiased;font-variant-numeric:lining-nums}
.sheet{max-width:${o.width || 640}px;margin:0 auto;background:var(--paper);padding:18px 18px 26px}
.kicker{font-family:OS,sans-serif;text-transform:uppercase;letter-spacing:.06em;font-size:11.5px;color:var(--club2);margin-bottom:2px}
.kicker.red,.lead .kicker{color:var(--club)}
.topline{display:flex;justify-content:space-between;font-size:11px;color:var(--muted);border-bottom:1px solid var(--rule);padding-bottom:5px}
.mast{display:flex;align-items:center;justify-content:center;gap:12px;padding:12px 0 6px}
.mast img{width:52px;height:52px;object-fit:contain}
.mast h1{margin:0;font-family:Mast,serif;font-weight:700;font-size:${Math.max(26, Math.min(44, Math.floor(620 / Math.max(title.length, 1))))}px;line-height:1;white-space:nowrap}
.strap{text-align:center;font-family:PF;font-style:italic;font-weight:700;font-size:14px;color:var(--club2);margin-bottom:8px}
.bar{border-top:3px solid var(--club);border-bottom:1px solid var(--club);height:7px}
.dateline{display:flex;justify-content:space-between;gap:8px;font-size:11px;padding:5px 1px;border-bottom:2px solid var(--rule);margin-bottom:14px}
.dateline b{color:var(--club)}
.lead h2{font-family:PF;font-weight:900;font-size:40px;line-height:1;margin:4px 0 8px}
.deck{font-family:PF;font-style:italic;font-weight:700;font-size:17px;line-height:1.3;color:#333;margin:0 0 10px}
figure{margin:0 0 10px}
figure img{width:100%;max-height:320px;object-fit:cover;display:block;border:1px solid #bbb}
.byline{font-family:OS;font-size:11px;letter-spacing:.06em;text-transform:uppercase;color:var(--muted);margin-bottom:6px}
p{font-size:15.5px;line-height:1.5;margin:0 0 9px}
.dc{font-family:PF;font-weight:900;float:left;font-size:54px;line-height:.85;padding:4px 6px 0 0;color:var(--club)}
.score{display:flex;align-items:center;justify-content:center;gap:10px;border:2px solid var(--ink);margin:10px 0 12px;padding:8px;background:#fffdf8}
.score .t{font-family:OS;font-weight:700;font-size:13px;text-transform:uppercase;text-align:center;flex:1;line-height:1.1}
.score .n{font-family:OS;font-weight:700;font-size:30px;white-space:nowrap}
.score .us{color:var(--club)}
hr.d{border:0;border-top:1px solid var(--rule);border-bottom:1px solid var(--rule);height:3px;margin:16px 0}
.story{padding-bottom:12px;border-bottom:1px solid #c9c1b0;margin-bottom:12px}
.story h3{font-family:PF;font-weight:900;font-size:25px;line-height:1.08;margin:2px 0 6px}
.pill{display:inline-block;font-family:OS;font-size:11px;text-transform:uppercase;letter-spacing:.05em;background:var(--club2);color:#fff;padding:3px 8px}
.board{margin:0 0 16px}
.board h3{font-family:OS;font-weight:700;font-size:17px;text-transform:uppercase;letter-spacing:.06em;background:var(--ink);color:var(--paper);padding:7px 10px;margin:0}
.row{display:flex;justify-content:space-between;gap:8px;padding:8px 10px;border-bottom:1px solid #c9c1b0;background:#fffdf8}
.row .c{font-family:OS;font-size:11px;text-transform:uppercase;color:var(--muted);letter-spacing:.04em}
.row .m{font-weight:700;font-size:15px}
.row .r{font-family:OS;font-weight:700;font-size:18px;color:var(--club);white-space:nowrap}
.go{background:var(--club2);color:#fff;padding:12px 14px;margin:6px 0 16px}
.go .kicker{color:#ffffffcc}
.go h3{font-family:PF;font-weight:900;font-size:23px;margin:2px 0 6px;color:#fff}
.go p{font-size:14.5px}
.go figure img{border:0}
.fxs h3{font-family:PF;font-weight:900;font-size:25px;margin:2px 0 4px}
.fx{display:flex;gap:10px;padding:9px 0;border-bottom:1px dotted #999}
.fx .d{flex:none;width:54px;font-family:OS;text-align:center;border:2px solid var(--club);color:var(--club);line-height:1.05;padding:3px 0;align-self:flex-start}
.fx .d b{display:block;font-size:21px}
.fx .d span{font-size:10px;text-transform:uppercase;letter-spacing:.06em}
.fx .w{font-weight:700;font-size:15px}
.fx .v{font-size:13px;color:var(--muted)}
.fx .tag{font-family:OS;font-size:10px;letter-spacing:.06em;text-transform:uppercase;background:var(--club);color:#fff;padding:1px 6px;margin-left:3px}
.foot{text-align:center;font-size:11px;color:var(--muted);border-top:2px solid var(--rule);padding-top:8px;margin-top:16px}
.foot .fr{font-family:Mast;font-weight:700;font-size:24px;color:var(--ink)}
.empty{padding:40px 10px;text-align:center;color:var(--muted);font-style:italic}
</style></head><body><div class="sheet" id="sheet">
<div class="topline"><span>No. ${esc(issue.issue_no)}</span><span>Free to all members</span></div>
<div class="mast">${club.crest ? `<img src="${esc(club.crest)}" crossorigin="anonymous" alt="">` : ''}<h1>${esc(title)}</h1></div>
${settings.strap ? `<div class="strap">${esc(settings.strap)}</div>` : ''}
<div class="bar"></div>
<div class="dateline"><span>Week of <b>${esc(weekLabel(issue.week_start, issue.week_end))}</b></span><span>${esc(club.club_name)}</span></div>
${parts || '<div class="empty">Tick some stories to see them here.</div>'}
<div class="foot"><div class="fr">${esc(title)}</div>${esc(club.club_name)}${club.club_name_translated ? ' · ' + esc(club.club_name_translated) : ''}${o.pdfUrl ? `<br><a href="${esc(o.pdfUrl)}" style="color:var(--club);font-weight:700">Download the PDF</a>` : ''}</div>
</div></body></html>`;
  };
  window.paperWeekLabel = weekLabel;
  // html2canvas draws on a canvas in the page that calls it, so the paper's
  // fonts must be loaded there too before a PDF is built.
  window.paperLoadFonts = async function () {
    if (!document.getElementById('paperFonts')) {
      const st = document.createElement('style'); st.id = 'paperFonts'; st.textContent = FONTS; document.head.appendChild(st);
    }
    await Promise.all(['700 20px Mast', '700 20px PF', '900 20px PF', 'italic 700 20px PF', '400 20px SS', 'italic 400 20px SS', '700 20px SS', '400 20px OS', '700 20px OS']
      .map(f => document.fonts.load(f).catch(() => null)));
  };
})();
