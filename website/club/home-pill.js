// Shared "‹ Club home" pill (Ken 2026-11-25): every club page carries the
// crest and one button back to the club home, so officers always navigate
// through the hub and never rely on the browser's back. Same tab.
(function () {
  const st = document.createElement('style');
  st.textContent = `.hub{display:inline-flex;align-items:center;gap:8px;flex:none;border-radius:999px;padding:5px 14px 5px 5px;
background:color-mix(in srgb,var(--onband,#fff) 16%,transparent);color:var(--onband,#fff);font-size:13.5px;font-weight:600;
text-decoration:none!important;opacity:1!important;white-space:nowrap;cursor:pointer}
.hub:hover{background:color-mix(in srgb,var(--onband,#fff) 24%,transparent)}
.hub img{width:34px;height:34px;background:#fff;border-radius:50%;padding:2px;object-fit:contain;flex:none}
.hub i{font-style:normal;font-size:17px;line-height:1;margin:0 1px 1px 4px}
@media print{.hub{display:none}}`;
  document.head.appendChild(st);
  const q = s => String(s ?? '').replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;');
  window.clubHomePill = (clubId, crest) =>
    `<a class="hub" href="/club/?club=${encodeURIComponent(clubId || '')}">${crest ? `<img src="${q(crest)}" alt="">` : '<i>‹</i>'}${crest ? '<i>‹</i>' : ''}Club home</a>`;
})();
