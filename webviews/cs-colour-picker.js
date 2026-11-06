/* Shared squad colour picker (bottom sheet).
 * CSColourPicker.open({ title, colour, label, onPick(hex) })
 * Used by create_team.html and team-setup.html.
 */
(function () {
  const SWATCHES = [
    '#2F6FD6', '#D63B3B', '#2FA84F', '#F2C230', '#F07B22', '#8A4FD6',
    '#1A1A1A', '#F1F4F8', '#9AA0A6', '#7A1F2B', '#4CC3E6', '#E85D9C'
  ];
  const DEFAULTS = ['#2F6FD6', '#D63B3B', '#2FA84F', '#F2C230', '#F07B22', '#8A4FD6', '#1A1A1A', '#4CC3E6', '#7A1F2B', '#E85D9C'];

  const css = `
  .cp-dim{position:fixed;inset:0;background:rgba(0,0,0,.55);z-index:200;opacity:0;transition:opacity .2s;pointer-events:none}
  .cp-dim.on{opacity:1;pointer-events:auto}
  .cp-sheet{position:fixed;left:0;right:0;bottom:0;z-index:201;background:#1E222B;border-radius:22px 22px 0 0;
    padding:12px 22px calc(24px + env(safe-area-inset-bottom));max-width:520px;margin:0 auto;
    transform:translateY(105%);transition:transform .25s ease;visibility:hidden;font-family:'DM Sans',sans-serif;color:#E7EBEE}
  .cp-sheet.on{transform:none;visibility:visible}
  .cp-grab{width:40px;height:5px;border-radius:3px;background:rgba(255,255,255,.2);margin:0 auto 16px}
  .cp-t{font-size:19px;font-weight:600;margin-bottom:4px}
  .cp-s{font-size:13px;color:#8a909a}
  .cp-grid{display:grid;grid-template-columns:repeat(6,1fr);gap:12px;margin:18px 0}
  .cp-g{aspect-ratio:1;border-radius:50%;border:2px solid rgba(255,255,255,.12);cursor:pointer;padding:0}
  .cp-g.pk{outline:3px solid #E7EBEE;outline-offset:3px}
  .cp-lbl{font-size:12px;color:#8a909a;text-transform:uppercase;letter-spacing:.6px;font-weight:600;margin-bottom:8px}
  .cp-range{-webkit-appearance:none;appearance:none;width:100%;height:26px;border-radius:13px;margin:6px 0 10px;outline:none}
  .cp-range::-webkit-slider-thumb{-webkit-appearance:none;width:30px;height:30px;border-radius:50%;background:var(--cp-c,#fff);border:3px solid #fff;box-shadow:0 1px 4px rgba(0,0,0,.5)}
  .cp-range::-moz-range-thumb{width:26px;height:26px;border-radius:50%;background:var(--cp-c,#fff);border:3px solid #fff}
  .cp-hue{background:linear-gradient(90deg,#f00,#ff0,#0f0,#0ff,#00f,#f0f,#f00)}
  .cp-prev{display:flex;align-items:center;gap:12px;padding:12px 14px;background:#252A35;border-radius:12px;margin-top:6px}
  .cp-dot{width:28px;height:28px;border-radius:8px;border:1px solid rgba(255,255,255,.15)}
  .cp-chip{margin-left:auto;padding:5px 12px;border-radius:999px;font-size:13px;font-weight:700}
  .cp-hex{font-size:13px;color:#8a909a;min-width:62px;text-align:right}
  .cp-btn{width:100%;margin-top:16px;padding:16px;border-radius:12px;background:#87C232;color:#111418;border:none;font-weight:700;font-size:17px;font-family:inherit;cursor:pointer}`;

  let styled = false, els = null, cur = null, done = null, label = '';

  function hexToRgb(h) { const n = parseInt(h.slice(1), 16); return [n >> 16 & 255, n >> 8 & 255, n & 255]; }
  function rgbToHex(r, g, b) { return '#' + [r, g, b].map(v => Math.round(v).toString(16).padStart(2, '0')).join('').toUpperCase(); }
  function hexToHsl(h) {
    let [r, g, b] = hexToRgb(h).map(v => v / 255);
    const mx = Math.max(r, g, b), mn = Math.min(r, g, b); let hh = 0, s = 0; const l = (mx + mn) / 2;
    if (mx !== mn) {
      const d = mx - mn; s = l > .5 ? d / (2 - mx - mn) : d / (mx + mn);
      hh = mx === r ? (g - b) / d + (g < b ? 6 : 0) : mx === g ? (b - r) / d + 2 : (r - g) / d + 4; hh *= 60;
    }
    return [hh, s, l];
  }
  function hslToHex(h, s, l) {
    const k = n => (n + h / 30) % 12, a = s * Math.min(l, 1 - l);
    const f = n => l - a * Math.max(-1, Math.min(k(n) - 3, Math.min(9 - k(n), 1)));
    return rgbToHex(f(0) * 255, f(8) * 255, f(4) * 255);
  }
  function textOn(h) { const [r, g, b] = hexToRgb(h); return (r * 299 + g * 587 + b * 114) / 1000 > 150 ? '#111418' : '#ffffff'; }
  function esc(s) { return String(s || '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c])); }

  function build() {
    if (!styled) { const st = document.createElement('style'); st.textContent = css; document.head.appendChild(st); styled = true; }
    const dim = document.createElement('div'); dim.className = 'cp-dim'; dim.onclick = close;
    const sh = document.createElement('div'); sh.className = 'cp-sheet';
    sh.innerHTML = `<div class="cp-grab"></div><div class="cp-t" id="cpT"></div><div class="cp-s">Pick a team colour or make your own.</div>
      <div class="cp-grid" id="cpGrid">${SWATCHES.map(c => `<button class="cp-g" data-c="${c}" style="background:${c}" aria-label="${c}"></button>`).join('')}</div>
      <div class="cp-lbl">Custom colour</div>
      <input type="range" class="cp-range cp-hue" id="cpHue" min="0" max="359" step="1">
      <input type="range" class="cp-range" id="cpLight" min="12" max="88" step="1">
      <div class="cp-prev"><div class="cp-dot" id="cpDot"></div><div id="cpName" style="font-size:16px;font-weight:500"></div><div class="cp-chip" id="cpChip"></div><div class="cp-hex" id="cpHex"></div></div>
      <button class="cp-btn" id="cpUse">Use this colour</button>`;
    document.body.appendChild(dim); document.body.appendChild(sh);
    els = { dim, sh, t: sh.querySelector('#cpT'), grid: sh.querySelector('#cpGrid'), hue: sh.querySelector('#cpHue'), light: sh.querySelector('#cpLight'),
      dot: sh.querySelector('#cpDot'), name: sh.querySelector('#cpName'), chip: sh.querySelector('#cpChip'), hex: sh.querySelector('#cpHex') };
    els.grid.onclick = e => { const b = e.target.closest('.cp-g'); if (b) set(b.dataset.c, true); };
    els.hue.oninput = els.light.oninput = () => set(hslToHex(+els.hue.value, .7, els.light.value / 100), false);
    sh.querySelector('#cpUse').onclick = () => { const f = done; close(); if (f) f(cur); };
  }

  function set(hex, moveSliders) {
    cur = hex.toUpperCase();
    els.grid.querySelectorAll('.cp-g').forEach(b => b.classList.toggle('pk', b.dataset.c.toUpperCase() === cur));
    if (moveSliders) { const [h, , l] = hexToHsl(cur); els.hue.value = Math.round(h); els.light.value = Math.max(12, Math.min(88, Math.round(l * 100))); }
    const h = +els.hue.value;
    els.light.style.background = `linear-gradient(90deg,${hslToHex(h, .7, .12)},${hslToHex(h, .7, .5)},${hslToHex(h, .7, .88)})`;
    els.sh.style.setProperty('--cp-c', cur);
    els.dot.style.background = cur; els.hex.textContent = cur;
    els.name.textContent = label; els.chip.textContent = label || 'Squad';
    els.chip.style.background = cur; els.chip.style.color = textOn(cur);
  }

  function open(o) {
    if (!els) build();
    label = o.label || ''; done = o.onPick;
    els.t.textContent = o.title || 'Squad colour';
    set(/^#[0-9a-f]{6}$/i.test(o.colour || '') ? o.colour : SWATCHES[0], true);
    requestAnimationFrame(() => { els.dim.classList.add('on'); els.sh.classList.add('on'); });
  }
  function close() { if (!els) return; els.dim.classList.remove('on'); els.sh.classList.remove('on'); done = null; }

  window.CSColourPicker = { open, close, SWATCHES, DEFAULTS, textOn, esc };
})();
