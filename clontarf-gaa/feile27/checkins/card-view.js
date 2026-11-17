// Draws a girl's card, the way her family sees it. Used by the coach form's
// preview (checkins/) and by the family page (card/).
window.CardView = (function () {
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
  const para = s => esc(s).replace(/\n/g, '<br>');
  const day = d => new Date(d + 'T12:00:00').toLocaleDateString('en-IE', { day: 'numeric', month: 'short' });
  const ICON = {
    bolt: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round" aria-hidden="true"><path d="M13 2L4 14h7l-1 8 9-12h-7z"/></svg>',
    target: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1"/></svg>',
    check: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 11l3 3L22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/></svg>',
    play: '<svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M8 5v14l11-7z"/></svg>'
  };

  // c: { first_name, code, superpower, development, how, video_url, checkins: [{date, progress, note}] }
  function render(c, checkDates) {
    const done = new Map((c.checkins || []).map(k => [k.date, k]));
    const code = c.code === 'camogie' ? 'Camogie' : 'Football';
    return `<div class="card"><div class="card-in">
      <div style="display:flex;align-items:center;gap:10px"><img src="/clontarf-gaa/images/clontarf-crest.png" alt="" style="width:30px;height:30px;object-fit:contain"><span class="eyebrow">Road to Féile · ${code}</span></div>
      <div class="display" style="font-size:28px;line-height:1">${esc(c.first_name || '')}</div>
      <div class="card-row"><div class="ic red">${ICON.bolt}</div><div><div class="k red">Superpower</div><div class="big">${para(c.superpower) || '<span class="muted">Not filled in yet</span>'}</div></div></div>
      <div class="card-row"><div class="ic">${ICON.target}</div><div><div class="k">Working on next</div><div class="big">${para(c.development) || '<span class="muted">Not filled in yet</span>'}</div></div></div>
      <div class="card-row"><div class="ic">${ICON.check}</div><div><div class="k">How</div><div style="color:var(--ink-2)">${para(c.how) || '<span class="muted">Not filled in yet</span>'}</div></div></div>
      ${c.video_url ? `<a class="vid" href="${esc(c.video_url)}" target="_blank" rel="noopener"><span class="th">${ICON.play}</span><span><b>Watch the help video</b><br><span class="muted small">Opens in a new tab</span></span></a>` : ''}
      ${(checkDates || []).length ? `<div style="border-top:1px solid #ECEEF4;padding-top:12px">
        <div class="k" style="color:var(--muted);margin-bottom:10px">Check-ins with your coach</div>
        <div class="tl">${checkDates.map(d => {
          const k = done.get(d);
          return `<div class="tl-i ${k ? 'done' : ''}"><span class="b"></span><div><b class="small">${day(d)}</b>${k
            ? `<div style="color:var(--ink-2);font-size:14px">${[k.progress, k.note].filter(Boolean).map(esc).join('. ')}</div>`
            : ''}</div></div>`;
        }).join('')}</div></div>` : ''}
    </div></div>`;
  }
  return { render, day, esc };
})();
