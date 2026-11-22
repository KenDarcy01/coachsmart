// Draws a girl's card, the way her family sees it. Used by the coach form's
// preview (checkins/) and by the family page (card/).
window.CardView = (function () {
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
  const para = s => esc(s).replace(/\n/g, '<br>');
  // Several picks (one per line) show as a list; one shows as a sentence.
  const items = s => {
    const l = String(s ?? '').split('\n').map(x => x.trim()).filter(Boolean);
    return l.length > 1 ? `<ul class="picks">${l.map(x => `<li>${esc(x)}</li>`).join('')}</ul>` : esc(l[0] || '');
  };
  const vids = c => (c.videos && c.videos.length ? c.videos : String(c.video_url || '').split(/[\s,]+/)).filter(u => /^https:\/\//i.test(u));
  const groupsOf = c => (Array.isArray(c.dev_groups) ? c.dev_groups : String(c.dev_groups || '').split('\n')).map(x => String(x).trim()).filter(Boolean);
  const day = d => new Date(d + 'T12:00:00').toLocaleDateString('en-IE', { day: 'numeric', month: 'short' });
  const ICON = {
    bolt: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round" aria-hidden="true"><path d="M13 2L4 14h7l-1 8 9-12h-7z"/></svg>',
    target: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1"/></svg>',
    check: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 11l3 3L22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/></svg>',
    people: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c.6-3.6 3.2-5.5 6.5-5.5s5.9 1.9 6.5 5.5"/><circle cx="17" cy="9" r="2.5"/><path d="M16 14.6c2.8-.3 5 1.3 5.5 4.4"/></svg>',
    play: '<svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M8 5v14l11-7z"/></svg>'
  };

  // c: { first_name, code, superpower, development, how, dev_groups (list, or one per line), videos (or video_url, one link per line), checkins: [{date, progress, note}] }
  function render(c, checkDates) {
    const done = new Map((c.checkins || []).map(k => [k.date, k]));
    const code = c.code === 'camogie' ? 'Camogie' : 'Football';
    return `<div class="card"><div class="card-in">
      <div style="display:flex;align-items:center;gap:10px"><img src="/clontarf-gaa/images/clontarf-crest.png" alt="" style="width:44px;height:44px;object-fit:contain"><span class="eyebrow">Road to Féile · ${code}</span></div>
      <div class="display" style="font-size:28px;line-height:1">${esc(c.first_name || '')}</div>
      <div class="card-row"><div class="ic red">${ICON.bolt}</div><div><div class="k red">Superpower</div><div class="big">${items(c.superpower) || '<span class="muted">Not filled in yet</span>'}</div></div></div>
      <div class="card-row"><div class="ic">${ICON.target}</div><div><div class="k">Working on next</div><div class="big">${items(c.development) || '<span class="muted">Not filled in yet</span>'}</div></div></div>
      <div class="card-row"><div class="ic">${ICON.check}</div><div><div class="k">How</div><div style="color:var(--ink-2)">${items(c.how) || '<span class="muted">Not filled in yet</span>'}</div></div></div>
      ${groupsOf(c).length ? `<div class="card-row"><div class="ic red">${ICON.people}</div><div><div class="k red">My groups in the Féile diary</div>
        <div class="chips" style="margin:6px 0">${groupsOf(c).map(g => `<span class="chip on" style="background:var(--red);border-color:var(--red)">${esc(g)}</span>`).join('')}</div>
        <div style="color:var(--ink-2);font-size:14px">Open the <a href="/clontarf-gaa/feile27/">Féile diary</a>, scroll to My groups and tap these under ${code}. Your home exercises for them then show on your home nights.</div></div></div>` : ''}
      ${vids(c).map((u, i, all) => `<a class="vid" href="${esc(u)}" target="_blank" rel="noopener"><span class="th">${ICON.play}</span><span><b>Watch the help video${all.length > 1 ? ' ' + (i + 1) : ''}</b><br><span class="muted small">Opens in a new tab</span></span></a>`).join('')}
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
