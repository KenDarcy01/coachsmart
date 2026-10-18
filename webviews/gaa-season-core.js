// Shared by gaa-season.html (all-clubs comparison) and gaa-club.html (one club over time).
// Reads the season store filled nightly by the gaa-sync edge function.
const SUPABASE_URL = 'https://gyfporsbdftvtakdvukt.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4';

const CODES = ['Football', 'Hurling', 'Camogie', 'Ladies Football'];
const GENDER = { all: CODES, boys: ['Football', 'Hurling'], girls: ['Camogie', 'Ladies Football'] };
const BANDS = { ccc1: 'CCC1 (U12 and under)', ccc2: 'CCC2 (U13 to U16)', adult: 'Adult and Minor' };
const BAND_SHORT = { ccc1: 'CCC1', ccc2: 'CCC2', adult: 'Adult' };
const MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const SERIES = ['#679C20', '#3F7FE6', '#D47A0C', '#B565D8', '#2BA89A'];
const CLONTARF = 'clontarf';

// ── Small helpers ──────────────────────────────────────────────────────────
const $ = id => document.getElementById(id);
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const sign = v => v > 0 ? `+${v}` : v < 0 ? `−${-v}` : '0';
const pct = (a, b) => b ? Math.round(a / b * 100) : 0;
const one = v => Math.round(v * 10) / 10;
const fmtN = n => n.toLocaleString('en-IE');
const iso = d => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const fromIso = s => { const [y, m, d] = s.split('-').map(Number); return new Date(y, m - 1, d); };
const addDays = (d, n) => { const x = new Date(d); x.setDate(x.getDate() + n); return x; };
const dayLabel = s => { const d = fromIso(s); return `${d.getDate()} ${MON[d.getMonth()]}`; };
const nameKey = s => String(s || '').toLowerCase().replace(/[^a-z0-9]/g, '');
function store(key, val) { try { localStorage.setItem(key, JSON.stringify(val)); } catch {} }
function stored(key, dflt) { try { const v = JSON.parse(localStorage.getItem(key)); return v ?? dflt; } catch { return dflt; } }

// U8..U16, then Minor and the adult grades
function ageOrder(a) {
  const m = /^U(\d+)/.exec(a); if (m) return +m[1];
  return { Minor: 17, Junior: 30, Intermediate: 31, Senior: 32, Adult: 33 }[a] ?? 40;
}

async function rpc(name, body = {}) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: 'POST',
    headers: { apikey: SUPABASE_ANON_KEY, Authorization: `Bearer ${SUPABASE_ANON_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!r.ok) throw new Error(`${name} failed (${r.status})`);
  return r.json();
}

// ── Division strength ──────────────────────────────────────────────────────
// A competition's tier from its grade: "League Div.3" / "Division 3" / "AFL 5" -> 3 / 5,
// "A Championship" / "Championship B" -> 1 / 2. Numbers and letters are ranked separately.
function tierOf(grade) {
  const g = grade || '';
  let m = /\bDiv(?:ision)?\.?\s*(\d+)/i.exec(g) || /\bA[FH]L\s*(\d+)/i.exec(g);
  if (m) return { fam: 'n', n: +m[1] };
  m = /\b([A-H])\s+(?:Championship|League|Shield|Cup)\b/.exec(g) || /\b(?:Championship|League|Shield|Cup)\s+([A-H])\b/.exec(g);
  if (m) return { fam: 'l', n: m[1].charCodeAt(0) - 64 };
  return null;
}
// Strength 0..1 within each code + age: top tier 1, bottom tier 0; no tier (or only one) 0.5
function addStrength(comps) {
  const max = {};
  for (const c of comps) {
    c.tier = tierOf(c.grade);
    if (c.tier) { const k = `${c.code}|${c.age}|${c.tier.fam}`; max[k] = Math.max(max[k] || 0, c.tier.n); }
  }
  for (const c of comps) {
    const mx = c.tier ? max[`${c.code}|${c.age}|${c.tier.fam}`] : 0;
    c.str = c.tier && mx > 1 ? (mx - c.tier.n) / (mx - 1) : 0.5;
  }
}

// ── Data ───────────────────────────────────────────────────────────────────
// DB = { clubs: Map id -> {id, name}, comps: [{code, age, level, grade, str}], games: [...] }
let DB = null, STATUS = null;
async function loadSeason(year) {
  const raw = await rpc('gaa_season_data', { p_from: `${year}-01-01`, p_to: `${year}-12-31` });
  const clubs = new Map(raw.clubs.map(([id, name]) => [id, { id, name }]));
  const comps = raw.comps.map(([id, code, age, level, grade]) => ({ id, code, age, level, grade }));
  addStrength(comps);
  const games = raw.games.map(([day, c, h, a, hp, ap, hs, as]) => ({ day, m: +day.slice(5, 7) - 1, comp: comps[c], h, a, hp, ap, hs, as }));
  DB = { year, clubs, comps, games, lastDay: games.length ? games[games.length - 1].day : null };
  return DB;
}
async function loadStatus() {
  try { STATUS = await rpc('gaa_status'); } catch { STATUS = null; }
  return STATUS;
}
function statusHtml() {
  const s = STATUS;
  if (!s) return 'Data from Dublin GAA, Camogie and LGFA fixtures.';
  const when = s.last_ok ? new Date(s.last_ok) : null;
  const today = new Date().toDateString() === when?.toDateString();
  const t = when ? `${today ? 'today' : `${when.getDate()} ${MON[when.getMonth()]}`} ${String(when.getHours()).padStart(2, '0')}:${String(when.getMinutes()).padStart(2, '0')}` : 'not yet';
  let h = `Data from Dublin GAA, Camogie and LGFA fixtures.<br>Updated <b>${t}</b> · ${fmtN(s.results || 0)} results stored`;
  if (s.first_day) h += ` from ${dayLabel(s.first_day)}`;
  // The backfill walks from 1 Jan to four weeks ahead, so it's done once fixtures past today are stored
  // The backfill walks a week at a time per code from 1 Jan to four weeks ahead
  const to = s.backfill_codes >= 4 ? s.backfill_to : null;
  if (!to || to < iso(new Date())) h += `<br>The season is still loading a week at a time${to ? `, done up to ${dayLabel(to)}` : ''}.`;
  if (s.failed_24h) h += `<br><span class="neg">${s.failed_24h} load${s.failed_24h > 1 ? 's' : ''} failed in the last day</span>`;
  return h;
}

// ── Filters (sidebar) ──────────────────────────────────────────────────────
const F = stored('gaaSeason.f', {});
F.preset ??= 'season'; F.show ??= 'all'; F.offCodes ??= []; F.band ??= 'all'; F.min ??= 30;
F.weighted ??= false; F.k ??= 40; F.from ??= ''; F.to ??= '';
const saveF = () => store('gaaSeason.f', F);

const PRESETS = [['season', 'Whole season'], ['spring', 'Spring (Jan to Jul)'], ['autumn', 'Autumn (Aug to Dec)'],
  ['m3', 'Last 3 months'], ['w6', 'Last 6 weeks'], ['month', 'This month'], ['custom', 'Custom']];
function range() {
  const y = DB?.year ?? new Date().getFullYear(), today = new Date();
  const end = iso(new Date(Math.min(today, new Date(y, 11, 31))));
  switch (F.preset) {
    case 'spring': return [`${y}-01-01`, `${y}-07-31`];
    case 'autumn': return [`${y}-08-01`, `${y}-12-31`];
    case 'm3': return [iso(addDays(fromIso(end), -91)), end];
    case 'w6': return [iso(addDays(fromIso(end), -42)), end];
    case 'month': { const e = fromIso(end); return [iso(new Date(e.getFullYear(), e.getMonth(), 1)), end]; }
    case 'custom': return [F.from || `${y}-01-01`, F.to || end];
    default: return [`${y}-01-01`, `${y}-12-31`];
  }
}
const codesOn = () => GENDER[F.show].filter(c => !F.offCodes.includes(c));
function filtered(opts = {}) {
  const [from, to] = range(), codes = new Set(codesOn());
  return DB.games.filter(g => g.day >= from && g.day <= to && codes.has(g.comp.code)
    && (opts.anyBand || F.band === 'all' || g.comp.level === F.band));
}
const K = () => F.weighted ? F.k / 100 : 0;

// Builds the sidebar into #filters. opts.min shows "clubs shown", opts.clubLabel names the club picker.
function renderFilters(opts) {
  const counts = {};
  if (DB) { const [from, to] = range(); for (const g of DB.games) if (g.day >= from && g.day <= to) counts[g.comp.code] = (counts[g.comp.code] || 0) + 1; }
  const y = DB?.year ?? new Date().getFullYear();
  $('filters').innerHTML = `
    <div class="s-section"><div class="s-label-row"><div class="s-label">${opts.clubLabel}</div></div>
      <select class="select" id="clubSel" onchange="onClubPick(this.value)">${clubOptions(opts.clubId)}</select></div>
    <div class="s-section"><div class="s-label-row"><div class="s-label">Dates · ${y}</div></div>
      <select class="select" onchange="setF('preset', this.value)">${PRESETS.map(([v, l]) => `<option value="${v}" ${F.preset === v ? 'selected' : ''}>${l}</option>`).join('')}</select>
      ${F.preset === 'custom' ? `<div class="date-row"><input type="date" class="select" value="${range()[0]}" onchange="setF('from', this.value)"><input type="date" class="select" value="${range()[1]}" onchange="setF('to', this.value)"></div>` : ''}</div>
    <div class="s-section"><div class="s-label-row"><div class="s-label">Show</div></div>
      <div class="seg">${[['all', 'All'], ['boys', 'Boys'], ['girls', 'Girls']].map(([v, l]) => `<button class="${F.show === v ? 'on' : ''}" onclick="setF('show', '${v}')">${l}</button>`).join('')}</div></div>
    <div class="s-section"><div class="s-label-row"><div class="s-label">Code</div>
      <div class="toggle-all"><button onclick="allCodes(true)">All</button><button onclick="allCodes(false)">None</button></div></div>
      <div class="chips">${GENDER[F.show].map(c => `<span class="chip ${F.offCodes.includes(c) ? '' : 'on'}" onclick="toggleCode('${c}')">${c}<span class="n">${fmtN(counts[c] || 0)}</span></span>`).join('')}</div></div>
    <div class="s-section"><div class="s-label-row"><div class="s-label">Age group</div></div>
      <div class="seg">${[['all', 'All'], ['ccc1', 'CCC1'], ['ccc2', 'CCC2'], ['adult', 'Adult']].map(([v, l]) => `<button class="${F.band === v ? 'on' : ''}" onclick="setF('band', '${v}')">${l}</button>`).join('')}</div>
      <div class="s-hint">CCC1 is U12 and under, CCC2 is U13 to U16, Adult is Minor and up.</div></div>
    ${opts.min ? `<div class="s-section"><div class="s-label-row"><div class="s-label">Clubs shown</div></div>
      <select class="select" onchange="setF('min', +this.value)">${[10, 30, 50, 100].map(n => `<option value="${n}" ${F.min === n ? 'selected' : ''}>At least ${n} games</option>`).join('')}</select></div>` : ''}
    <div class="s-section"><div class="s-label-row"><div class="s-label">Division weighting</div></div>
      <div class="switch ${F.weighted ? 'on' : ''}" onclick="setF('weighted', !F.weighted)"><i></i>Weight by division</div>
      ${F.weighted ? `<input class="slider" type="range" min="0" max="100" step="5" value="${F.k}" oninput="slideK(this.value)" onchange="setF('k', +this.value)">
      <div class="slider-row"><span>Results only</span><span id="kVal"><b>${F.k}%</b> division</span><span>Division only</span></div>` : ''}
      <div class="s-hint">${F.weighted
        ? 'Each game scores win 1, draw ½, loss 0, blended with how high the division is (top division 1, bottom 0, within each code and age). The weighted score is the average out of 100.'
        : 'Off: plain win %. On: a win in Division 1 counts for more than a win in Division 6.'}</div></div>
    <div class="s-section"><div class="s-hint" id="status">${statusHtml()}</div></div>`;
}
function setF(k, v) { F[k] = v; if (k === 'show') F.offCodes = []; saveF(); refresh(); }
function toggleCode(c) { F.offCodes = F.offCodes.includes(c) ? F.offCodes.filter(x => x !== c) : [...F.offCodes, c]; saveF(); refresh(); }
function allCodes(on) { F.offCodes = on ? [] : [...GENDER[F.show]]; saveF(); refresh(); }
let kTimer = null;
function slideK(v) { F.k = +v; const el = $('kVal'); if (el) el.innerHTML = `<b>${v}%</b> division`; clearTimeout(kTimer); kTimer = setTimeout(() => { saveF(); render(); }, 120); }

function clubOptions(sel) {
  if (!DB) return '';
  return [...DB.clubs.values()].sort((a, b) => a.name.localeCompare(b.name))
    .map(c => `<option value="${c.id}" ${c.id === sel ? 'selected' : ''}>${esc(c.name)}</option>`).join('');
}
const clubName = id => DB.clubs.get(id)?.name ?? '';
function defaultClub() {
  const saved = stored('gaaSeason.club', null);
  if (saved && DB.clubs.has(saved)) return saved;
  const c = [...DB.clubs.values()].find(c => nameKey(c.name) === CLONTARF);
  return c?.id ?? DB.clubs.keys().next().value;
}

// ── Aggregation ────────────────────────────────────────────────────────────
// One game from one side: result 1 / ½ / 0, plus its weighted score
const blank = () => ({ p: 0, w: 0, d: 0, l: 0, pf: 0, pa: 0, ws: 0 });
function addSide(s, f, a, str, k) {
  const r = f > a ? 1 : f < a ? 0 : 0.5;
  s.p++; s.pf += f; s.pa += a; s.ws += (1 - k) * r + k * str;
  if (r === 1) s.w++; else if (r === 0) s.l++; else s.d++;
}
// Per club: totals, home/away, by band, by code, teams (code|age|team name)
function aggregate(games, k = K()) {
  const out = new Map();
  const get = id => {
    let s = out.get(id);
    if (!s) { s = { id, name: clubName(id), ...blank(), home: blank(), away: blank(), band: {}, code: {}, teams: new Set(), comps: new Set() }; out.set(id, s); }
    return s;
  };
  for (const g of games) {
    const c = g.comp;
    for (const [id, f, a, suf, ha] of [[g.h, g.hp, g.ap, g.hs, 'home'], [g.a, g.ap, g.hp, g.as, 'away']]) {
      const s = get(id);
      addSide(s, f, a, c.str, k); addSide(s[ha], f, a, c.str, k);
      addSide(s.band[c.level] ??= blank(), f, a, c.str, k);
      addSide(s.code[c.code] ??= blank(), f, a, c.str, k);
      s.teams.add(`${c.code}|${c.age}|${suf}`);
      s.comps.add(c.id);
    }
  }
  return out;
}
const winPct = s => s && s.p ? pct(s.w, s.p) : 0;
const wScore = s => s && s.p ? Math.round(s.ws / s.p * 100) : 0;
const diffPg = s => s && s.p ? one((s.pf - s.pa) / s.p) : 0;
const metric = s => F.weighted ? wScore(s) : winPct(s);
const metricName = () => F.weighted ? 'Weighted score' : 'Win %';
const metricFmt = v => F.weighted ? `${v}` : `${v}%`;

// Months covered by the current range, capped at the last stored game
function monthsInRange() {
  const [from, to] = range(), end = DB.lastDay && DB.lastDay < to ? DB.lastDay : to;
  const out = [];
  for (let m = +from.slice(5, 7) - 1; m <= +end.slice(5, 7) - 1; m++) out.push(m);
  return out;
}

// ── Charts (inline SVG with explicit colours so the PDF snapshot keeps them) ─
// cfg: { labels, series: [{name, color, values}], fmt, ref, min, max, bars, endLabels, tip(i) }
const CHARTS = {};
function chartHtml(id, cfg) {
  CHARTS[id] = cfg;
  const W = innerWidth < 760 ? Math.max(320, innerWidth - 56) : (cfg.width || 900), H = cfg.height || 280, ml = 44, mr = cfg.endLabels && W >= 700 ? 150 : 16, mt = 14, mb = 28;
  const vals = cfg.series.flatMap(s => s.values).filter(v => v != null);
  let lo = cfg.min ?? Math.min(0, ...vals), hi = cfg.max ?? Math.max(1, ...vals);
  if (cfg.fit && vals.length) { lo = Math.max(lo, Math.min(...vals) - 5); hi = Math.min(hi, Math.max(...vals) + 5); }
  if (cfg.ref != null) { lo = Math.min(lo, cfg.ref); hi = Math.max(hi, cfg.ref); }
  const span = hi - lo || 1, step = [1, 2, 5, 10, 20, 25, 50, 100].find(s => span / s <= 5) || 100;
  lo = Math.floor(lo / step) * step; hi = Math.ceil(hi / step) * step;
  const n = cfg.labels.length, pw = W - ml - mr;
  const X = i => cfg.bars ? ml + (i + 0.5) * pw / n : ml + (n > 1 ? i * pw / (n - 1) : pw / 2);
  const Y = v => mt + (hi - v) / (hi - lo) * (H - mt - mb);
  Object.assign(cfg, { W, H, X, Y, mt, mb, ml, mr });
  let g = '';
  for (let v = lo; v <= hi + 1e-9; v += step)
    g += `<line x1="${ml}" x2="${W - mr}" y1="${Y(v)}" y2="${Y(v)}" stroke="rgba(255,255,255,0.06)"/><text x="${ml - 8}" y="${Y(v) + 4}" text-anchor="end" fill="#9CA3AF" font-size="11">${cfg.fmt(v)}</text>`;
  if (cfg.ref != null) g += `<line x1="${ml}" x2="${W - mr}" y1="${Y(cfg.ref)}" y2="${Y(cfg.ref)}" stroke="#9CA3AF" stroke-dasharray="4 4"/>`;
  const every = Math.ceil(n / 12);
  cfg.labels.forEach((l, i) => { if (i % every === 0) g += `<text x="${X(i)}" y="${H - 8}" text-anchor="middle" fill="#9CA3AF" font-size="11">${esc(l)}</text>`; });
  if (cfg.bars) {
    const bw = Math.min(46, pw / n * 0.62) / cfg.series.length;
    cfg.series.forEach((s, si) => s.values.forEach((v, i) => {
      if (v == null) return;
      const x = X(i) - bw * cfg.series.length / 2 + si * bw, y0 = Y(Math.max(lo, Math.min(0, hi))), y = Y(v);
      const col = typeof s.color === 'function' ? s.color(v) : s.color;
      g += `<rect x="${x + 1}" y="${Math.min(y, y0)}" width="${bw - 2}" height="${Math.max(1, Math.abs(y0 - y))}" rx="3" fill="${col}"/>`;
      if (s.labels) g += `<text x="${x + bw / 2}" y="${(v >= 0 ? Math.min(y, y0) - 5 : Math.max(y, y0) + 13)}" text-anchor="middle" fill="#E7EBEE" font-size="11" font-weight="600">${esc(s.labels[i])}</text>`;
    }));
  } else {
    const ends = [];
    cfg.series.forEach(s => {
      let path = '', last = null;
      s.values.forEach((v, i) => { if (v == null) return; path += `${path ? 'L' : 'M'}${X(i).toFixed(1)},${Y(v).toFixed(1)}`; last = [i, v]; });
      g += `<path d="${path}" fill="none" stroke="${s.color}" stroke-width="2.2" stroke-linejoin="round" stroke-linecap="round"/>`;
      s.values.forEach((v, i) => { if (v != null) g += `<circle cx="${X(i)}" cy="${Y(v)}" r="${n > 14 ? 2 : 3.2}" fill="${s.color}"/>`; });
      if (last && cfg.endLabels && W >= 700) ends.push({ s, x: X(last[0]), y: Y(last[1]), v: last[1] });
    });
    // End labels at least 16px apart so close finishes stay readable
    ends.sort((p, q) => p.y - q.y).forEach((e, i) => { e.ly = i && e.y - ends[i - 1].ly < 16 ? ends[i - 1].ly + 16 : e.y; });
    for (const e of ends) g += `<text x="${e.x + 10}" y="${e.ly + 4}" fill="#E7EBEE" font-size="12" font-weight="600">${esc(e.s.name)} ${cfg.fmt(e.v)}</text>`;
  }
  g += `<line class="hair" x1="0" x2="0" y1="${mt}" y2="${H - mb}" stroke="rgba(255,255,255,0.35)" visibility="hidden"/>`;
  const legend = cfg.legend === false ? '' : `<div class="legend">${cfg.series.map(s => `<span><b style="background:${typeof s.color === 'function' ? s.color(1) : s.color}"></b>${esc(s.name)}${s.drop ? `<span class="x" style="cursor:pointer" title="Remove" onclick="${s.drop}">✕</span>` : ''}</span>`).join('')}${cfg.legendExtra || ''}</div>`;
  return `${legend}<div class="chart" data-chart="${id}"><svg viewBox="0 0 ${W} ${H}" onmousemove="chartHover(event)" onmouseleave="chartOut(event)" onclick="chartHover(event)">${g}</svg><div class="tip"></div></div>`;
}
function chartHover(e) {
  const box = e.currentTarget.closest('.chart'), cfg = CHARTS[box.dataset.chart]; if (!cfg) return;
  const svg = box.querySelector('svg'), r = svg.getBoundingClientRect();
  const x = (e.clientX - r.left) / r.width * cfg.W;
  let best = 0;
  cfg.labels.forEach((_, i) => { if (Math.abs(cfg.X(i) - x) < Math.abs(cfg.X(best) - x)) best = i; });
  const hair = svg.querySelector('.hair');
  hair.setAttribute('x1', cfg.X(best)); hair.setAttribute('x2', cfg.X(best)); hair.setAttribute('visibility', 'visible');
  const tip = box.querySelector('.tip');
  tip.innerHTML = cfg.tip ? cfg.tip(best) : `<b>${esc(cfg.labels[best])}</b>${cfg.series.map(s => s.values[best] == null ? '' :
    `<div><i style="background:${typeof s.color === 'function' ? s.color(s.values[best]) : s.color}"></i>${esc(s.name)}<span>${cfg.fmt(s.values[best])}</span></div>`).join('')}`;
  tip.style.display = 'block';
  const px = cfg.X(best) / cfg.W * r.width, tw = tip.offsetWidth;
  tip.style.left = `${px + 14 + tw > r.width ? px - tw - 14 : px + 14}px`;
  tip.style.top = '30px';
}
function chartOut(e) {
  const box = e.currentTarget.closest('.chart');
  box.querySelector('.tip').style.display = 'none';
  box.querySelector('.hair').setAttribute('visibility', 'hidden');
}

const ring = (p, c, label = `${p}%`) => `<svg class="ring" viewBox="0 0 36 36"><circle cx="18" cy="18" r="15.5" fill="none" stroke="#252A35" stroke-width="4"/><circle cx="18" cy="18" r="15.5" fill="none" stroke="${c}" stroke-width="4" stroke-linecap="round" stroke-dasharray="${p} 100" pathLength="100" transform="rotate(-90 18 18)"/><text x="18" y="21" text-anchor="middle" font-size="8.5" font-weight="700" fill="#F1F4F8">${label}</text></svg>`;
const wdlBar = s => s.p ? `<div class="wdl"><i class="w" style="width:${s.w / s.p * 100}%"></i><i class="d" style="width:${s.d / s.p * 100}%"></i><i class="l" style="width:${s.l / s.p * 100}%"></i></div>` : '';
// Teams per code from a club's team set, in code order
const teamsByCode = teams => { const n = {}; for (const t of teams) { const c = t.split('|')[0]; n[c] = (n[c] || 0) + 1; } return CODES.filter(c => n[c]).map(c => [c, n[c]]); };
const rec = s => s ? `${s.w}–${s.d}–${s.l}` : '0–0–0';

// ── Exports ────────────────────────────────────────────────────────────────
// A tab describes itself as { title, sheets: [{ name, cols: [[header, key]], rows }] }
const fileSafe = s => s.normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^\w]+/g, '-').replace(/^-|-$/g, '');
function download(blob, name) {
  const url = URL.createObjectURL(blob), a = document.createElement('a');
  a.href = url; a.download = name; document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 60000);
}
function exportCsv() {
  const x = exportData(), q = v => /[",\n]/.test(String(v ?? '')) ? `"${String(v).replace(/"/g, '""')}"` : String(v ?? '');
  const parts = x.sheets.map(s => [x.sheets.length > 1 ? q(s.name) : null, s.cols.map(c => q(c[0])).join(','), ...s.rows.map(r => s.cols.map(c => q(r[c[1]])).join(','))].filter(l => l != null).join('\n'));
  download(new Blob(['﻿' + `${q(x.title)}\n\n` + parts.join('\n\n')], { type: 'text/csv' }), `${fileSafe(x.title)}.csv`);
}
const loadScript = src => new Promise((ok, bad) => { const el = document.createElement('script'); el.src = src; el.onload = ok; el.onerror = () => bad(new Error('load failed')); document.head.appendChild(el); });
let xlLib = null, pdfLib = null;
async function exportExcel() {
  const btn = $('xlsxBtn'); btn.disabled = true;
  try {
    await (xlLib ??= loadScript('https://cdn.jsdelivr.net/npm/exceljs@4.4.0/dist/exceljs.min.js'));
    const x = exportData(), wb = new ExcelJS.Workbook();
    const fill = c => ({ type: 'pattern', pattern: 'solid', fgColor: { argb: c } });
    for (const s of x.sheets) {
      const ws = wb.addWorksheet(s.name.slice(0, 31).replace(/[\\/?*[\]:]/g, ' '));
      ws.addRow([x.title]);
      ws.mergeCells(1, 1, 1, s.cols.length);
      Object.assign(ws.getRow(1).getCell(1), { font: { bold: true, size: 14, color: { argb: 'FF87C232' } }, fill: fill('FF14181B') });
      ws.getRow(1).height = 24;
      const hr = ws.addRow(s.cols.map(c => c[0]));
      hr.eachCell(c => { c.font = { bold: true, color: { argb: 'FF14181B' } }; c.fill = fill('FF87C232'); });
      for (const r of s.rows) {
        const row = ws.addRow(s.cols.map(c => r[c[1]]));
        if (r._me) row.eachCell(c => { c.font = { bold: true }; c.fill = fill('FFE6F2D4'); });
      }
      s.cols.forEach((c, i) => { ws.getColumn(i + 1).width = Math.min(40, Math.max(8, c[0].length + 2, ...s.rows.slice(0, 300).map(r => String(r[c[1]] ?? '').length + 2))); });
      ws.views = [{ state: 'frozen', ySplit: 2 }];
    }
    const buf = await wb.xlsx.writeBuffer();
    download(new Blob([buf], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }), `${fileSafe(x.title)}.xlsx`);
  } catch (e) { console.error(e); alert('Could not create the Excel file'); }
  finally { btn.disabled = false; }
}
// Snapshot of what's on screen, page-height slices so long lists don't blow the canvas limit
async function exportPdf() {
  const busy = $('busy'); busy.classList.add('on');
  const stage = $('pdfStage');
  try {
    await (pdfLib ??= Promise.all([loadScript('https://cdn.jsdelivr.net/npm/jspdf@2.5.1/dist/jspdf.umd.min.js'),
      loadScript('https://cdn.jsdelivr.net/npm/html2canvas@1.4.1/dist/html2canvas.min.js')]));
    const x = exportData();
    stage.innerHTML = `<div class="section-title" style="margin-top:0">${esc(x.title)}</div>` + $('list').innerHTML;
    stage.querySelectorAll('.more-btn, .tip, select.no-pdf').forEach(el => el.remove());
    stage.style.display = 'block';
    const { jsPDF } = window.jspdf, pad = 16, pageH = 1300, w = stage.offsetWidth, h = stage.scrollHeight;
    let pdf = null;
    for (let y = 0; y < h; y += pageH) {
      const sliceH = Math.min(pageH, h - y);
      const canvas = await html2canvas(stage, { backgroundColor: '#111418', scale: 2, y, height: sliceH, width: w, windowWidth: w, logging: false });
      const pw = w + pad * 2, ph = sliceH + pad * 2;
      // Orientation must follow each slice's shape, or jsPDF swaps width and height on short last pages
      const orient = pw > ph ? 'l' : 'p';
      if (!pdf) pdf = new jsPDF({ orientation: orient, unit: 'px', format: [pw, ph] }); else pdf.addPage([pw, ph], orient);
      pdf.setFillColor(17, 20, 24); pdf.rect(0, 0, pw, ph, 'F');
      pdf.addImage(canvas.toDataURL('image/jpeg', 0.9), 'JPEG', pad, pad, w, sliceH);
    }
    download(pdf.output('blob'), `${fileSafe(x.title)}.pdf`);
  } catch (e) { console.error(e); alert('Could not create the PDF'); }
  finally { stage.style.display = 'none'; stage.innerHTML = ''; busy.classList.remove('on'); }
}

// ── Page boot ──────────────────────────────────────────────────────────────
function showLoading(msg) { $('list').innerHTML = `<div class="empty"><div class="spinner"></div>${esc(msg)}</div>`; }
function showError(e) { $('list').innerHTML = `<div class="empty"><b>Couldn't load the season</b>${esc(e.message)}</div>`; }
async function boot() {
  showLoading('Loading every result this season…');
  try {
    await Promise.all([loadSeason(new Date().getFullYear()), loadStatus()]);
    pageInit();
    refresh();
  } catch (e) { console.error(e); showError(e); }
}
// Sidebar and view together; render() alone redraws only the view (slider drags)
function refresh() { if (!DB) return; renderFilters(filterOpts()); render(); }
