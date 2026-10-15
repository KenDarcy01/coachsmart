/* CoachSmart match charts, shared by score-keeper.html and match-stats-chart.html.
 *
 * Everything here is pure rendering: pass in a match model, get HTML back.
 *
 * model = {
 *   usName, oppName,            team labels
 *   duration,                   seconds per half (e.g. 1800)
 *   hasH2,                      true once the second half has started
 *   nowAbs,                     current match second (for the live end of the line), or null
 *   events: [{                  every score row, corrections included
 *     half, second, side ('us'|'opp'), value (points, null for wides etc),
 *     name ('Point'), kind ('score'|'correction'), count (1, or +/-n for corrections),
 *     member ('Ciarán Byrne' or '')
 *   }],
 *   subs: [{ half, second, on, off }]
 * }
 */
(function () {
  'use strict';

  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const pad2 = n => String(n).padStart(2, '0');
  const gaa = (g, p) => `${g}-${pad2(p)}`;
  const poss = n => /s$/i.test(n || '') ? `${n}'` : `${n}'s`;

  // Absolute match second, with injury time squeezed onto the end of its half
  // so the axis never grows a phantom third period.
  function absSec(m, half, sec) {
    const d = m.duration;
    return half === 2 ? d + Math.min(sec, d * 1.5) : Math.min(sec, d * 1.5);
  }
  function minuteLabel(m, half, sec) {
    const min = Math.floor(sec / 60) + 1;
    const base = half === 2 ? Math.round(m.duration / 60) : 0;
    const halfLen = Math.round(m.duration / 60);
    if (min > halfLen) return `${base + halfLen}+${min - halfLen}'`;
    return `${base + min}'`;
  }

  // Walk the events in order, keeping the running score.
  function walk(m) {
    const evs = (m.events || []).slice().sort((a, b) =>
      (a.half - b.half) || (a.second - b.second) || ((a.order || 0) - (b.order || 0)));
    const t = { us: { g: 0, p: 0 }, opp: { g: 0, p: 0 } };
    const rows = [];
    evs.forEach(e => {
      const n = e.kind === 'correction' ? (e.count || 0) : 1;
      if (e.value) {
        if (e.value === 3) t[e.side].g += n; else t[e.side].p += n * e.value;
      }
      rows.push(Object.assign({}, e, {
        abs: absSec(m, e.half, e.second),
        scoring: !!e.value,
        us: gaa(t.us.g, t.us.p), opp: gaa(t.opp.g, t.opp.p),
        usT: t.us.g * 3 + t.us.p, oppT: t.opp.g * 3 + t.opp.p,
      }));
    });
    return { rows, us: t.us, opp: t.opp };
  }

  function totals(m) {
    const w = walk(m);
    return {
      us: gaa(w.us.g, w.us.p), opp: gaa(w.opp.g, w.opp.p),
      usT: w.us.g * 3 + w.us.p, oppT: w.opp.g * 3 + w.opp.p,
    };
  }

  function axis(m) {
    const end = m.hasH2 ? 2 * m.duration : m.duration;
    const halfMin = Math.round(m.duration / 60);
    const ticks = [];
    const step = halfMin <= 20 ? 5 : 10;
    for (let x = 0; x <= halfMin * (m.hasH2 ? 2 : 1); x += step) {
      if (m.hasH2 && x === halfMin) continue; // HT label goes here
      ticks.push(x);
    }
    return { end, ticks, halfMin };
  }

  // ── "Who was ahead" lead chart ────────────────────────────────────────────
  function leadChart(m) {
    const w = walk(m);
    const ax = axis(m);
    const W = 358, H = 220, L = 34, R = 10, T = 14, B = 30, cw = W - L - R, ch = H - T - B;
    let maxD = 3;
    w.rows.forEach(r => { maxD = Math.max(maxD, Math.abs(r.usT - r.oppT)); });
    maxD = Math.ceil(maxD / 3) * 3;
    const endX = m.nowAbs != null ? Math.min(Math.max(m.nowAbs, 0), ax.end) : ax.end;
    const x = s => L + (s / ax.end) * cw, y = d => T + ch / 2 - (d / maxD) * (ch / 2);
    let d = 0;
    const pts = [[0, 0]];
    w.rows.filter(r => r.scoring).forEach(r => { pts.push([r.abs, d]); d = r.usT - r.oppT; pts.push([r.abs, d]); });
    pts.push([Math.max(endX, pts[pts.length - 1][0]), d]);
    const line = pts.map((q, i) => (i ? 'L' : 'M') + x(q[0]).toFixed(1) + ' ' + y(q[1]).toFixed(1)).join(' ');
    const lastX = x(pts[pts.length - 1][0]);
    const area = `${line} L${lastX.toFixed(1)} ${y(0)} L${x(0)} ${y(0)} Z`;
    const uid = 'lc' + Math.random().toString(36).slice(2, 7);
    let s = `<svg viewBox="0 0 ${W} ${H}" width="100%" style="display:block" role="img" aria-label="Lead over time">
      <defs><clipPath id="${uid}u"><rect x="0" y="0" width="${W}" height="${y(0)}"/></clipPath>
      <clipPath id="${uid}d"><rect x="0" y="${y(0)}" width="${W}" height="${H}"/></clipPath></defs>`;
    [-maxD, -maxD / 2, 0, maxD / 2, maxD].forEach(v => {
      s += `<line x1="${L}" x2="${W - R}" y1="${y(v)}" y2="${y(v)}" stroke="${v ? 'rgba(255,255,255,.06)' : 'rgba(255,255,255,.28)'}" ${v ? '' : 'stroke-dasharray="4 4"'}/>`;
      s += `<text x="${L - 6}" y="${y(v) + 4}" fill="#a1a1a2" font-size="11" text-anchor="end">${v > 0 ? '+' + v : v}</text>`;
    });
    if (m.hasH2) {
      s += `<line x1="${x(m.duration)}" x2="${x(m.duration)}" y1="${T}" y2="${T + ch}" stroke="#f5a524" stroke-dasharray="3 4"/>`;
      s += `<text x="${x(m.duration)}" y="${T + ch + 22}" fill="#f5a524" font-size="11" font-weight="700" text-anchor="middle">HT</text>`;
    }
    ax.ticks.forEach(t => { s += `<text x="${x(t * 60)}" y="${T + ch + 22}" fill="#a1a1a2" font-size="11" text-anchor="middle">${t}'</text>`; });
    s += `<path d="${area}" fill="rgba(135,194,50,.22)" clip-path="url(#${uid}u)"/><path d="${area}" fill="rgba(224,82,82,.22)" clip-path="url(#${uid}d)"/>`;
    s += `<path d="${line}" fill="none" stroke="#87c232" stroke-width="2.5" clip-path="url(#${uid}u)"/>`;
    s += `<path d="${line}" fill="none" stroke="#e05252" stroke-width="2.5" clip-path="url(#${uid}d)"/>`;
    s += `<path d="${line}" fill="none" stroke="rgba(255,255,255,.35)" stroke-width="1" clip-path="url(#${uid}u)" style="display:none"/>`;
    w.rows.filter(r => r.scoring && r.value === 3 && r.kind !== 'correction').forEach(r => {
      const dd = r.usT - r.oppT;
      s += `<circle cx="${x(r.abs)}" cy="${y(dd)}" r="9" fill="${r.side === 'us' ? '#87c232' : '#e05252'}"/>`;
      s += `<text x="${x(r.abs)}" y="${y(dd) + 4}" font-size="11" font-weight="800" fill="#14181b" text-anchor="middle">G</text>`;
    });
    s += `<text x="${L + 4}" y="${T + 11}" fill="#87c232" font-size="11" font-weight="700">${esc(m.usName)} ahead</text>`;
    s += `<text x="${L + 4}" y="${T + ch - 4}" fill="#e05252" font-size="11" font-weight="700">${esc(m.oppName)} ahead</text>`;
    return s + '</svg>';
  }

  // ── Two-line score race ───────────────────────────────────────────────────
  function raceChart(m) {
    const w = walk(m);
    const ax = axis(m);
    const W = 358, H = 200, L = 30, R = 58, T = 12, B = 28, cw = W - L - R, ch = H - T - B;
    let maxY = 5;
    w.rows.forEach(r => { maxY = Math.max(maxY, r.usT, r.oppT); });
    maxY = Math.ceil(maxY / 5) * 5;
    const endX = m.nowAbs != null ? Math.min(Math.max(m.nowAbs, 0), ax.end) : ax.end;
    const x = s => L + (s / ax.end) * cw, y = v => T + ch - (v / maxY) * ch;
    const path = k => {
      let v = 0, d = `M${x(0)} ${y(0)}`;
      w.rows.filter(r => r.scoring).forEach(r => { d += ` L${x(r.abs).toFixed(1)} ${y(v).toFixed(1)}`; v = r[k + 'T']; d += ` L${x(r.abs).toFixed(1)} ${y(v).toFixed(1)}`; });
      return { d: d + ` L${x(endX).toFixed(1)} ${y(v).toFixed(1)}`, v };
    };
    const pu = path('us'), po = path('opp');
    let s = `<svg viewBox="0 0 ${W} ${H}" width="100%" style="display:block" role="img" aria-label="Scores over the match">`;
    const step = maxY <= 10 ? 5 : 10;
    for (let v = 0; v <= maxY; v += step) {
      s += `<line x1="${L}" x2="${W - R}" y1="${y(v)}" y2="${y(v)}" stroke="rgba(255,255,255,.06)"/><text x="${L - 6}" y="${y(v) + 4}" fill="#a1a1a2" font-size="11" text-anchor="end">${v}</text>`;
    }
    if (m.hasH2) {
      s += `<line x1="${x(m.duration)}" x2="${x(m.duration)}" y1="${T}" y2="${T + ch}" stroke="#f5a524" stroke-dasharray="3 4"/>`;
      s += `<text x="${x(m.duration)}" y="${T + ch + 22}" fill="#f5a524" font-size="11" font-weight="700" text-anchor="middle">HT</text>`;
    }
    ax.ticks.forEach(t => { s += `<text x="${x(t * 60)}" y="${T + ch + 22}" fill="#a1a1a2" font-size="11" text-anchor="middle">${t}'</text>`; });
    s += `<path d="${po.d}" fill="none" stroke="#e05252" stroke-width="2.5"/><path d="${pu.d}" fill="none" stroke="#87c232" stroke-width="2.5"/>`;
    const t = totals(m);
    let yu = y(pu.v) + 4, yo = y(po.v) + 4;
    if (Math.abs(yu - yo) < 14) { if (pu.v >= po.v) { yu -= 7; yo += 7; } else { yu += 7; yo -= 7; } }
    s += `<text x="${x(endX) + 6}" y="${yu}" fill="#87c232" font-size="12" font-weight="700">${t.us}</text>`;
    s += `<text x="${x(endX) + 6}" y="${yo}" fill="#e05252" font-size="12" font-weight="700">${t.opp}</text>`;
    return s + '</svg>';
  }

  function biggestLeads(m) {
    const w = walk(m);
    let us = { d: 0, at: '' }, opp = { d: 0, at: '' };
    w.rows.filter(r => r.scoring).forEach(r => {
      const d = r.usT - r.oppT;
      if (d > us.d) us = { d, at: minuteLabel(m, r.half, r.second) };
      if (-d > opp.d) opp = { d: -d, at: minuteLabel(m, r.half, r.second) };
    });
    return { us, opp };
  }

  function halfScores(m) {
    const out = {};
    [1, 2].forEach(h => {
      const t = { us: { g: 0, p: 0 }, opp: { g: 0, p: 0 } };
      (m.events || []).filter(e => e.half === h && e.value).forEach(e => {
        const n = e.kind === 'correction' ? (e.count || 0) : 1;
        if (e.value === 3) t[e.side].g += n; else t[e.side].p += n * e.value;
      });
      out[h] = { us: gaa(t.us.g, t.us.p), opp: gaa(t.opp.g, t.opp.p) };
    });
    return out;
  }

  // Count of non-scoring stats (wides etc) per side per name
  function statCounts(m) {
    const c = {};
    (m.events || []).forEach(e => {
      const n = e.kind === 'correction' ? (e.count || 0) : 1;
      const k = e.name || 'Other';
      c[k] = c[k] || { us: 0, opp: 0, value: e.value };
      c[k][e.side] += n;
    });
    return c;
  }

  function scorers(m) {
    const by = {};
    (m.events || []).filter(e => e.side === 'us').forEach(e => {
      const k = e.member || '';
      by[k] = by[k] || { g: 0, p: 0, other: {} };
      const n = e.kind === 'correction' ? (e.count || 0) : 1;
      if (e.value === 3) by[k].g += n;
      else if (e.value) by[k].p += n * e.value;
      else by[k].other[e.name] = (by[k].other[e.name] || 0) + n;
    });
    return Object.entries(by)
      .map(([name, v]) => ({ name, score: gaa(v.g, v.p), total: v.g * 3 + v.p, other: v.other }))
      .filter(r => r.total > 0 || Object.keys(r.other).length)
      .sort((a, b) => (a.name === '') - (b.name === '') || b.total - a.total);
  }

  // ── Page sections ─────────────────────────────────────────────────────────
  function chartSection(m) {
    const t = totals(m);
    const bl = biggestLeads(m);
    const hs = halfScores(m);
    const sc = scorers(m);
    const named = sc.some(r => r.name);
    let html = `<div class="mc-card"><div class="mc-h">Who was ahead</div>
      <div class="mc-sub">Above the line ${esc(m.usName)} led, below it ${esc(m.oppName)} led</div>${leadChart(m)}</div>
      <div class="mc-kpis">
        <div class="mc-kpi"><b class="us">${bl.us.d ? '+' + bl.us.d + ' at ' + bl.us.at : '—'}</b><span>${esc(poss(m.usName))} biggest lead</span></div>
        <div class="mc-kpi"><b class="opp">${bl.opp.d ? '+' + bl.opp.d + ' at ' + bl.opp.at : '—'}</b><span>${esc(poss(m.oppName))} biggest lead</span></div>
      </div>
      <div class="mc-card"><div class="mc-h">Scores over the match</div><div class="mc-sub">Total points for each team</div>${raceChart(m)}</div>
      <div class="mc-card mc-halves">
        <div class="mc-hrow mc-hd"><span></span><span>${esc(m.usName)}</span><span>${esc(m.oppName)}</span></div>
        <div class="mc-hrow"><span>1st half</span><span>${hs[1].us}</span><span>${hs[1].opp}</span></div>
        ${m.hasH2 ? `<div class="mc-hrow"><span>2nd half</span><span>${hs[2].us}</span><span>${hs[2].opp}</span></div>` : ''}
        <div class="mc-hrow"><span><b>${m.finished ? 'Final' : 'Now'}</b></span><span class="us">${t.us}</span><span>${t.opp}</span></div>
      </div>`;
    const stats = statCounts(m);
    const other = Object.entries(stats).filter(([, v]) => !v.value);
    if (other.length) {
      html += `<div class="mc-card mc-halves"><div class="mc-hrow mc-hd"><span>Stats</span><span>${esc(m.usName)}</span><span>${esc(m.oppName)}</span></div>
        ${other.map(([k, v]) => `<div class="mc-hrow"><span>${esc(k)}</span><span>${v.us}</span><span>${v.opp}</span></div>`).join('')}</div>`;
    }
    if (named) {
      html += `<div class="mc-card"><div class="mc-h" style="margin-bottom:4px">${esc(m.usName)} scorers</div>
        ${sc.map(r => `<div class="mc-sc"><span${r.name ? '' : ' class="mc-mute"'}>${esc(r.name || 'No player named')}</span><span>${r.score}</span><span>${esc(Object.entries(r.other).map(([k, v]) => `${v} ${k.toLowerCase()}${v !== 1 && !/s$/i.test(k) ? 's' : ''}`).join(', '))}</span></div>`).join('')}</div>`;
    }
    return html;
  }

  function timelineSection(m) {
    const w = walk(m);
    const NAME = e => e.kind === 'correction'
      ? `Score check: ${e.count > 0 ? '+' : ''}${e.count} ${esc((e.name || '').toLowerCase())}${Math.abs(e.count) !== 1 ? 's' : ''}`
      : esc(e.name || 'Score');
    let out = `<div class="mc-band"><span>Throw-in</span><b>0-00 v 0-00</b></div>`;
    const items = w.rows.map(r => ({ t: 'ev', half: r.half, second: r.second, r }))
      .concat((m.subs || []).map(s => ({ t: 'sub', half: s.half, second: s.second, s })))
      .sort((a, b) => (a.half - b.half) || (a.second - b.second));
    let lastSide = null, run = 0, htShown = false, lastScore = { us: '0-00', opp: '0-00' };
    const rows = [];
    items.forEach((it, i) => {
      if (it.half === 2 && !htShown) {
        rows.push(`<div class="mc-band"><span>Half time</span><b>${lastScore.us} v ${lastScore.opp}</b></div>`);
        htShown = true;
      }
      if (it.t === 'sub') {
        rows.push(`<div class="mc-ev mc-subev"><span class="mn">${minuteLabel(m, it.half, it.second)}</span>
          <span class="wh">Sub<small>${esc(it.s.on || 'On')} on for ${esc(it.s.off || 'off')}</small></span><span class="rs"></span></div>`);
        return;
      }
      const r = it.r;
      lastScore = { us: r.us, opp: r.opp };
      const tag = r.kind === 'correction' ? '<span class="mc-tag a">CHECK</span>'
        : r.value === 3 ? `<span class="mc-tag ${r.side === 'us' ? 'g' : 'r'}">GOAL</span>`
        : r.value === 2 ? '<span class="mc-tag a">+2</span>' : '';
      const who = (r.side === 'us' ? m.usName : m.oppName) + (r.member ? ' · ' + r.member : '');
      rows.push(`<div class="mc-ev ${r.side === 'opp' ? 'opp' : ''} ${r.value === 3 && r.kind !== 'correction' ? 'goal' : ''} ${r.scoring ? '' : 'stat'}">
        <span class="mn">${minuteLabel(m, r.half, r.second)}</span>
        <span class="wh">${NAME(r)}${tag}<small>${esc(who)}</small></span>
        <span class="rs">${r.scoring ? `${r.us}<i>v</i>${r.opp}` : ''}</span></div>`);
      if (r.scoring && r.kind !== 'correction') {
        if (r.side === lastSide) run++; else run = 1;
        lastSide = r.side;
        const next = items.slice(i + 1).find(x => x.t === 'ev' && x.r.scoring);
        if (run >= 3 && !(next && next.r.side === r.side)) {
          rows.push(`<div class="mc-run ${r.side === 'opp' ? 'opp' : ''}">${esc(r.side === 'us' ? m.usName : m.oppName)} scored ${run} in a row</div>`);
        }
      }
    });
    if (!rows.length) return out + '<div class="mc-empty">No scores yet</div>';
    out += rows.join('');
    const t = totals(m);
    out += m.finished
      ? `<div class="mc-band ft"><span>Full time</span><b>${t.us} v ${t.opp}</b></div>`
      : `<div class="mc-band"><span>Now</span><b>${t.us} v ${t.opp}</b></div>`;
    return out;
  }

  const CSS = `
  .mc-card{background:var(--card,#1e222b);border-radius:18px;padding:16px;margin:10px 16px 0}
  .mc-h{font-size:16px;font-weight:700}.mc-sub{font-size:13px;color:var(--muted,#a1a1a2);margin:2px 0 8px}
  .mc-kpis{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin:10px 16px 0}
  .mc-kpi{background:var(--card,#1e222b);border-radius:14px;padding:10px 12px}
  .mc-kpi b{display:block;font-family:'Bebas Neue',sans-serif;font-size:21px;letter-spacing:.5px;font-weight:400}
  .mc-kpi span{font-size:12px;color:var(--muted,#a1a1a2)}
  .mc-kpi b.us,.mc-hrow .us{color:#87c232}.mc-kpi b.opp{color:#e05252}
  .mc-halves{padding:6px 14px}
  .mc-hrow{display:grid;grid-template-columns:1fr 1fr 1fr;padding:9px 0;border-bottom:1px solid rgba(255,255,255,.07);font-size:15px;align-items:center}
  .mc-hrow:last-child{border:0}
  .mc-hrow span:nth-child(2),.mc-hrow span:nth-child(3){text-align:center;font-family:'Bebas Neue',sans-serif;font-size:22px}
  .mc-hrow.mc-hd span{font-family:inherit!important;font-size:12px!important;color:var(--muted,#a1a1a2);text-transform:uppercase;letter-spacing:1px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
  .mc-sc{display:grid;grid-template-columns:1fr 64px 1fr;gap:6px;padding:9px 0;border-bottom:1px solid rgba(255,255,255,.07);font-size:15px;align-items:center}
  .mc-sc:last-child{border:0}.mc-sc span:nth-child(2){font-family:'Bebas Neue',sans-serif;font-size:20px;text-align:right}
  .mc-sc span:nth-child(3){color:var(--muted,#a1a1a2);text-align:right;font-size:12px}.mc-mute{color:var(--muted,#a1a1a2)}
  .mc-tl{margin:10px 16px 0}
  .mc-band{display:flex;justify-content:space-between;align-items:center;background:#262b35;border-radius:12px;padding:9px 14px;margin:10px 0 6px;font-size:13px;color:var(--muted,#a1a1a2);font-weight:600;text-transform:uppercase;letter-spacing:1px}
  .mc-band b{color:var(--text,#f1f4f8);font-family:'Bebas Neue',sans-serif;font-size:20px;letter-spacing:1px;font-weight:400;text-transform:none}
  .mc-band.ft{background:rgba(135,194,50,.14)}.mc-band.ft span{color:#87c232}
  .mc-ev{display:grid;grid-template-columns:46px 1fr 96px;align-items:center;gap:8px;padding:9px 12px;background:var(--card,#1e222b);border-radius:12px;margin-bottom:6px;border-left:4px solid #87c232}
  .mc-ev.opp{border-left-color:#e05252}.mc-ev.stat{opacity:.75}.mc-ev.mc-subev{border-left-color:#5b8def}
  .mc-ev .mn{color:var(--muted,#a1a1a2);font-weight:700;font-size:13px}
  .mc-ev .wh{font-size:15px}.mc-ev .wh small{display:block;color:var(--muted,#a1a1a2);font-size:12px}
  .mc-ev .rs{text-align:right;font-family:'Bebas Neue',sans-serif;font-size:20px;letter-spacing:.5px}
  .mc-ev .rs i{font-style:normal;color:var(--muted,#a1a1a2);font-size:14px;margin:0 3px}
  .mc-ev.goal{background:linear-gradient(90deg,rgba(135,194,50,.16),var(--card,#1e222b) 60%)}
  .mc-ev.opp.goal{background:linear-gradient(90deg,rgba(224,82,82,.16),var(--card,#1e222b) 60%)}
  .mc-tag{display:inline-block;font-size:11px;font-weight:700;padding:2px 7px;border-radius:6px;margin-left:6px;vertical-align:1px}
  .mc-tag.g{background:#87c232;color:#14181b}.mc-tag.r{background:#e05252;color:#fff}.mc-tag.a{background:#f5a524;color:#14181b}
  .mc-run{font-size:12px;color:#87c232;font-weight:600;margin:2px 0 6px 4px}.mc-run.opp{color:#e05252}
  .mc-empty{text-align:center;color:var(--muted,#a1a1a2);padding:30px 0;font-size:14px}`;

  function injectCss() {
    if (document.getElementById('mc-css')) return;
    const st = document.createElement('style');
    st.id = 'mc-css';
    st.textContent = CSS;
    document.head.appendChild(st);
  }

  window.CSMatchCharts = { totals, chartSection, timelineSection, leadChart, raceChart, minuteLabel, injectCss, walk };
})();
