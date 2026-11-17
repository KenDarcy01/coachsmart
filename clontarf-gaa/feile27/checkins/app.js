// Player check-ins: the coaches' portal (Clontarf Girls 2012, Féile 2027).
// Pages (hash routes): #/ my players, #/p/<id> assess a girl, #/review (admins),
// #/checkins the check-in timeline, #/publish (admins).
// All data comes from the player-checkins edge function through PC.call.
(function () {
  const { call, esc } = PC;
  const $ = s => document.querySelector(s);
  const main = $('#main');
  const day = CardView.day;
  const today = new Date().toISOString().slice(0, 10);

  // ---- suggested phrases (soft, ability-focused: see the u15 language rule) ----
  const SUPER = {
    'Any code': ['Pace and power', 'Reading the game', 'Calm on the ball', 'Never stops working', 'Brave in the tackle',
      'A great first touch', 'Scoring from distance', 'A big voice on the pitch', 'A brilliant team-mate', 'Always in the right place',
      'Lifts everyone around her'],
    Football: ['Accurate kick-passing', 'Safe hands under a high ball', 'Strong in the solo run'],
    Camogie: ['Strong first-time striking', 'A clean lift and catch', 'Quick hands in the tackle']
  };
  const DEV = {
    'On the ball': ['Using the left foot with confidence', 'Using the right foot with confidence', 'Taking a shot when the chance is there',
      'Looking up before passing', 'Moving the ball on quickly', 'Catching the ball cleanly under pressure'],
    'In the game': ['Calling for the ball so team-mates can find her', 'Getting back to help the defence', 'Finding space away from the ball',
      'Lasting a full match with energy to spare', 'Talking to team-mates on the pitch', 'Tracking her player all the way'],
    Confidence: ['Going for it in one-on-ones', 'Backing herself to take on a bigger role', 'Shaking off a mistake and going again'],
    Camogie: ['Striking off both sides', 'Lifting the sliotar first time', 'Hooking and blocking with confidence']
  };
  const HOW = ['10 minutes of wall-ball, 3 times a week', 'The home skills sheet from the Féile plan', 'One extra drill at Monday training',
    'Practise it in the Tuesday S&C warm-up', 'Watch the help video, then try it at home', '10 minutes of kick-passing with someone at home',
    '10 shots at a target after every home session', 'Use her voice in every Wednesday small-sided game'];
  // Mirrors BANNED in supabase/functions/player-checkins/index.ts.
  const BANNED = ['weak', 'weakness', 'weaker', 'poor', 'poorly', 'bad', 'lazy', 'fat', 'weight', 'heavy', 'overweight', 'skinny', 'chubby',
    'unfit', 'useless', 'terrible', 'awful', 'lacks', 'lacking', 'struggles', 'worst', 'body', 'bmi'];
  const BANNED_RE = new RegExp(`\\b(${BANNED.join('|')})\\b`, 'gi');
  const flagged = (...t) => [...new Set(t.join(' ').match(BANNED_RE) || [])].map(w => w.toLowerCase());
  const PROGRESS = { starting: 'Just getting started', coming: 'Coming on well', nailed: 'Nailed it' };
  const STATUS = { todo: 'To do', draft: 'Draft', review: 'With reviewer', changes: 'Change asked', approved: 'Approved', shared: 'Shared with family' };

  let D = null;           // last list load
  let ME = null;
  let view = { code: 'football', filter: 'all', scope: 'mine', q: '' };
  try { Object.assign(view, JSON.parse(sessionStorage.getItem('pc-view')) || {}); } catch (e) {}
  const keepView = () => sessionStorage.setItem('pc-view', JSON.stringify(view));

  function toast(msg) {
    const t = $('#toast'); t.textContent = msg; t.classList.add('show');
    clearTimeout(toast.t); toast.t = setTimeout(() => t.classList.remove('show'), 2800);
  }
  const initials = n => String(n || '').split(/\s+/).filter(Boolean).slice(0, 2).map(s => s[0].toUpperCase()).join('');
  const statusOf = a => (a.status === 'approved' && a.published_at && !a.changed_since_publish) ? 'shared' : a.status;
  const pill = a => { const s = statusOf(a); return `<span class="pill st-${s}">${STATUS[s]}</span>`; };
  const when = iso => iso ? new Date(iso).toLocaleDateString('en-IE', { day: 'numeric', month: 'short' }) : '';
  const codeName = c => c === 'camogie' ? 'Camogie' : 'Football';
  // A dropdown with tick boxes: pick as many phrases as fit her.
  const picker = (id, groups, label) => `<details class="dd" id="${id}"><summary><span class="dd-t" data-label="${esc(label)}">${esc(label)}</span><span class="dd-n" hidden></span></summary>
    <div class="dd-menu" role="group" aria-label="${esc(label)}">${Object.entries(groups).filter(([, l]) => l && l.length).map(([g, l]) =>
      `<div class="g">${esc(g)}</div>${l.map(p => `<label class="dd-i"><input type="checkbox" value="${esc(p)}"><span>${esc(p)}</span></label>`).join('')}`).join('')}
      <div class="dd-foot"><button type="button" class="btn small red dd-done">Done</button></div></div></details>`;
  const options = (groups, label) => `<option value="">${label}</option>` + Object.entries(groups)
    .map(([g, l]) => `<optgroup label="${esc(g)}">${l.map(p => `<option>${esc(p)}</option>`).join('')}</optgroup>`).join('');

  async function load() {
    D = await call('list');
    const waiting = D.assessments.filter(a => a.status === 'review' && !a.mine).length;
    const b = $('#nReview'); b.textContent = waiting; b.hidden = !waiting;
    return D;
  }
  const mineOrAll = () => D.assessments.filter(a => view.scope === 'all' && ME.isAdmin ? true : a.mine);

  // ---------- router ----------
  async function route() {
    const h = location.hash.replace(/^#\/?/, '');
    const [r, id] = h.split('/');
    document.querySelectorAll('#nav a').forEach(a => a.classList.toggle('on', a.dataset.r === (r === 'p' ? 'list' : (r || 'list'))));
    try {
      if (!D) await load();
      if (r === 'p') return showAssess(Number(id));
      if (r === 'review' && ME.isAdmin) return showReview();
      if (r === 'checkins') return showCheckins();
      if (r === 'publish' && ME.isAdmin) return showPublish();
      return showList();
    } catch (e) {
      main.innerHTML = `<p class="err">${esc(e.message)}</p>`;
    }
  }

  // ---------- my players ----------
  function steps(on) {
    const s = [['Assess', 'Superpower, Development and How'], ['Review', 'Another admin approves or asks for a change'],
      ['Share', 'All cards go to families together'], ['Check-ins', (ME.checkDates || []).map(day).join(', ')]];
    return `<section class="box steps">${s.map(([t, d], i) => `<div class="step ${i === on ? 'on' : ''}"><i>${i + 1}</i><div><b>${t}</b><div class="muted small">${esc(d)}</div></div></div>`).join('')}</section>`;
  }
  function codeSeg() {
    return `<div class="seg" role="group" aria-label="Code">${['football', 'camogie'].map(c =>
      `<button data-code="${c}" class="${view.code === c ? 'on' : ''}">${codeName(c)}</button>`).join('')}</div>`;
  }
  function bindCodeSeg(again) {
    main.querySelectorAll('[data-code]').forEach(b => b.onclick = () => { view.code = b.dataset.code; keepView(); again(); });
  }
  function scopeSeg() {
    if (!ME.isAdmin) return '';
    return `<div class="seg" role="group" aria-label="Whose players">${[['mine', 'Mine'], ['all', 'Everyone']].map(([k, l]) =>
      `<button data-scope="${k}" class="${view.scope === k ? 'on' : ''}">${l}</button>`).join('')}</div>`;
  }
  function bindScopeSeg(again) {
    main.querySelectorAll('[data-scope]').forEach(b => b.onclick = () => { view.scope = b.dataset.scope; keepView(); again(); });
  }

  function showList() {
    const all = mineOrAll().filter(a => a.code === view.code);
    const groups = { todo: ['todo', 'draft'], review: ['review'], changes: ['changes'], done: ['approved'] };
    const n = k => all.filter(a => groups[k].includes(a.status)).length;
    const shown = all.filter(a => view.filter === 'all' || groups[view.filter].includes(a.status))
      .filter(a => !view.q || a.player_name.toLowerCase().includes(view.q.toLowerCase()));
    const order = { changes: 0, todo: 1, draft: 1, review: 2, approved: 3 };
    shown.sort((a, b) => order[a.status] - order[b.status] || a.player_name.localeCompare(b.player_name));
    const who = view.scope === 'all' && ME.isAdmin ? 'All girls' : 'My players to assess';
    main.innerHTML = `${steps(0)}
      <section class="toolbar">
        <div><h1 class="display" style="font-size:38px">${who}</h1>
          <p class="muted" style="margin:4px 0 0">${all.length} ${all.length === 1 ? 'girl' : 'girls'} in ${codeName(view.code).toLowerCase()}${D.lastRelease ? ` · cards last shared ${when(D.lastRelease.published_at)}` : ''}${D.inactive ? ` · ${D.inactive} inactive hidden (Player status in the team sheet)` : ''}</p></div>
        <div style="display:flex;gap:10px;flex-wrap:wrap">${scopeSeg()}${codeSeg()}</div>
      </section>
      <section class="stats">
        <div class="stat"><span class="muted">To do</span><b>${n('todo')}</b></div>
        <div class="stat"><span class="muted">With reviewer</span><b>${n('review')}</b></div>
        <div class="stat"><span class="muted">Change asked</span><b style="color:var(--red-dark)">${n('changes')}</b></div>
        <div class="stat"><span class="muted">Approved</span><b>${n('done')}</b></div>
      </section>
      <section class="list">
        <div class="list-head">
          <div class="chips">${[['all', `All ${all.length}`], ['todo', 'To do'], ['review', 'With reviewer'], ['changes', 'Change asked'], ['done', 'Approved']]
            .map(([k, l]) => `<button class="chip ${view.filter === k ? 'on' : ''}" data-f="${k}">${l}</button>`).join('')}</div>
          <label class="search"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/></svg>
            <input id="q" placeholder="Find a player" aria-label="Find a player" value="${esc(view.q)}"></label>
        </div>
        ${shown.length ? shown.map(a => `
          <a class="row ${a.status === 'changes' ? 'hot' : ''}" href="#/p/${a.id}">
            <div class="who"><div class="av">${initials(a.player_name)}</div><div style="min-width:0"><b>${esc(a.player_name)}</b>
              <span>${a.status === 'changes' && a.review_comment ? `${esc(a.reviewed_by)}: “${esc(a.review_comment)}”` : (view.scope === 'all' ? `Assessor: ${esc(a.assessor_name || 'not set')}` : (a.updated_by ? `Updated by ${esc(a.updated_by)}` : 'Not started'))}</span></div></div>
            <div class="sp">${esc((a.superpower || '').split('\n')[0]) || '<span class="muted">—</span>'}</div>
            <div>${pill(a)}${a.changed_since_publish ? '<div class="muted small">Changed since shared</div>' : ''}</div>
            <div class="act"><span class="btn small ${['todo', 'draft', 'changes'].includes(a.status) ? 'red' : ''}">${a.status === 'todo' ? 'Start' : ['draft', 'changes'].includes(a.status) ? 'Continue' : 'Open'}</span></div>
          </a>`).join('') : `<div class="empty">${all.length ? 'No girls match.' : (ME.isAdmin && view.scope === 'mine' ? 'No girls have you as their assessor. Switch to Everyone to see the whole panel, or set Assessor Email in the team sheet.' : 'No girls have you as their assessor yet. The team sheet sets who assesses whom.')}</div>`}
      </section>
      <p class="muted small">Only coaches see this page. Nothing reaches a girl or her family until another admin approves it and the cards are shared.</p>`;
    bindCodeSeg(showList); bindScopeSeg(showList);
    main.querySelectorAll('[data-f]').forEach(b => b.onclick = () => { view.filter = b.dataset.f; keepView(); showList(); });
    const q = $('#q'); q.oninput = () => { view.q = q.value; keepView(); const pos = q.selectionStart; showList(); const n2 = $('#q'); n2.focus(); n2.setSelectionRange(pos, pos); };
  }

  // ---------- assess one girl ----------
  function showAssess(id) {
    const a = D.assessments.find(x => x.id === id);
    if (!a) { main.innerHTML = '<p class="err">That girl is not on your list.</p><a class="btn" href="#/">Back</a>'; return; }
    const editable = (ME.isAdmin || a.mine) && a.status !== 'review';
    const ro = editable ? '' : 'readonly';
    const superGroups = { 'Any code': SUPER['Any code'], [codeName(a.code)]: SUPER[codeName(a.code)] };
    const devGroups = a.code === 'camogie' ? DEV : Object.fromEntries(Object.entries(DEV).filter(([k]) => k !== 'Camogie'));
    main.innerHTML = `
      <a href="#/" class="link" style="align-self:flex-start;padding:0">‹ ${view.scope === 'all' && ME.isAdmin ? 'All girls' : 'My players'}</a>
      <section class="player-head">
        <div class="av">${initials(a.player_name)}</div>
        <div style="flex:1 1 260px"><h1 class="display">${esc(a.player_name)}</h1>
          <div class="muted">${codeName(a.code)} · assessor ${esc(a.assessor_name || 'not set')} · ${pill(a)}</div></div>
        ${(() => { const o = D.assessments.find(x => x.player_name === a.player_name && x.code !== a.code); return o ? `<a class="btn small" href="#/p/${o.id}">Open ${codeName(o.code)}</a>` : ''; })()}
        ${ME.isAdmin && a.member_id && a.published_at ? `<a class="btn small" href="../card/?m=${a.member_id}" target="_blank" rel="noopener">Family card</a>` : ''}
      </section>
      ${a.status === 'changes' && a.review_comment ? `<div class="banner red"><div><b>${esc(a.reviewed_by)} asked for a change</b><div>“${esc(a.review_comment)}”</div></div></div>` : ''}
      ${a.status === 'review' ? `<div class="banner amber"><div><b>With the reviewer.</b> Any admin other than the assessor can approve it from the Review page.</div></div>` : ''}
      ${a.status === 'approved' ? `<div class="banner green"><div><b>Approved${a.reviewed_by ? ' by ' + esc(a.reviewed_by) : ''}.</b> ${a.published_at && !a.changed_since_publish ? 'This is what her family can see now.' : 'It goes to her family at the next Publish.'} Changing the card sends it back for review.</div></div>` : ''}
      <div class="layout">
        <div class="main">
          <section class="box stack">
            <label class="field-title" for="f-super"><span style="color:var(--red)">${ICON.bolt}</span>Superpower</label>
            <p class="hint" style="margin:0">What she brings to the team. Tick as many as fit her in the list, or write your own (one per line).</p>
            ${editable ? picker('p-super', superGroups, 'Choose superpowers') : ''}
            <textarea id="f-super" rows="3" ${ro}>${esc(a.superpower)}</textarea>
          </section>
          <section class="box stack">
            <label class="field-title" for="f-dev"><span style="color:var(--red)">${ICON.target}</span>Development: what she's working on next</label>
            <p class="hint" style="margin:0">Tick one or more, said as things she'll be able to do. Or write your own (one per line).</p>
            ${editable ? picker('p-dev', devGroups, 'Choose what she is working on') : ''}
            <textarea id="f-dev" rows="3" ${ro}>${esc(a.development)}</textarea>
            <div class="helper"><span style="color:var(--navy)">${ICON.bulb}</span><div><b>Wording.</b> These are u15 girls: keep it positive and about what she can do. Words like “weak”, “poor” or anything about body or weight can't be sent.</div></div>
          </section>
          <section class="box stack">
            <label class="field-title" for="f-how"><span style="color:var(--red)">${ICON.check}</span>How: what she'll do</label>
            ${editable ? `<select id="s-how" aria-label="Suggested ways">${options({ 'Féile plan and training': HOW }, 'Add a suggestion…')}</select>` : ''}
            <textarea id="f-how" rows="3" ${ro}>${esc(a.how)}</textarea>
            <div class="field-title" style="font-size:16px;margin-top:6px"><span style="color:var(--red)">${ICON.video}</span>Help videos <span class="muted small" style="font-family:Inter">(optional)</span></div>
            <div class="stack" id="vids" style="gap:8px"></div>
            ${editable ? `<button type="button" class="btn small" id="addVid" style="align-self:flex-start">+ Add another video</button>` : ''}
            <p class="hint" style="margin:0">YouTube, Vimeo, Google Drive or club clips. Each one shows on her card as a Watch button.</p>
          </section>
          <section class="box stack">
            <label class="field-title" for="f-note" style="font-size:16px"><span class="muted">${ICON.lock}</span>Coach-only note</label>
            <p class="hint" style="margin:0">Seen by coaches only. Never on her card.</p>
            <textarea id="f-note" rows="2" ${ro}>${esc(a.coach_note)}</textarea>
          </section>
          <div id="warn"></div>
          ${editable ? `<div class="actions"><button class="btn" id="save">Save draft</button><span class="grow"></span>
            <button class="btn red" id="send">Send for review ${ICON.arrow}</button></div>` : ''}
        </div>
        <aside>
          <span class="k" style="color:var(--muted)">What ${esc(a.player_name.split(' ')[0])} and her parents will see</span>
          <div id="preview"></div>
          <p class="muted small" style="margin:0">Updates as you type. Families only see it after it's approved and shared.</p>
        </aside>
      </div>`;

    const f = { super: $('#f-super'), dev: $('#f-dev'), how: $('#f-how'), note: $('#f-note') };
    const vidBox = $('#vids');
    const addVid = (u = '') => {
      const row = document.createElement('div'); row.className = 'vrow';
      row.innerHTML = `<input type="url" placeholder="https://youtu.be/…" aria-label="Help video link" value="${esc(u)}" ${ro}>${editable ? '<button type="button" class="btn small" aria-label="Remove this video">✕</button>' : ''}`;
      row.querySelector('input').addEventListener('input', draw);
      const x = row.querySelector('button');
      if (x) x.onclick = () => { row.remove(); if (!vidBox.children.length) addVid(); draw(); };
      vidBox.appendChild(row);
      return row;
    };
    const vidLinks = () => [...vidBox.querySelectorAll('input')].map(i => i.value.trim()).filter(Boolean);
    const values = () => ({ superpower: f.super.value, development: f.dev.value, how: f.how.value, video_url: vidLinks().join('\n'), coach_note: f.note.value });
    const draw = () => {
      const v = values();
      $('#preview').innerHTML = CardView.render({ first_name: a.player_name.split(' ')[0], code: a.code, ...v, checkins: [] }, []);
      const bad = flagged(v.superpower, v.development, v.how);
      $('#warn').innerHTML = bad.length ? `<div class="warn"><b>Please reword:</b> ${bad.map(w => `“${esc(w)}”`).join(', ')}. Try saying what she'll be able to do, for example “Using the left foot with confidence”.</div>` : '';
    };
    const links = String(a.video_url || '').split(/[\s,]+/).filter(Boolean);
    (links.length ? links : ['']).forEach(u => addVid(u));
    Object.values(f).forEach(el => el.addEventListener('input', draw));
    draw();
    if (!editable) return;
    $('#addVid').onclick = () => { addVid().querySelector('input').focus(); };
    // Tick-box dropdowns: each tick adds or removes that phrase as its own line.
    const lines = field => field.value.split('\n').map(x => x.trim()).filter(Boolean);
    const multi = (box, field) => {
      const boxes = [...box.querySelectorAll('input[type=checkbox]')];
      const sync = () => {
        const have = new Set(lines(field).map(x => x.toLowerCase()));
        boxes.forEach(c => { c.checked = have.has(c.value.toLowerCase()); });
        const n = boxes.filter(c => c.checked).length, badge = box.querySelector('.dd-n');
        badge.hidden = !n; badge.textContent = `${n} ticked`;
      };
      boxes.forEach(c => c.onchange = () => {
        const cur = lines(field), i = cur.findIndex(x => x.toLowerCase() === c.value.toLowerCase());
        if (c.checked && i < 0) cur.push(c.value); else if (!c.checked && i >= 0) cur.splice(i, 1);
        field.value = cur.join('\n'); sync(); draw();
      });
      box.querySelector('.dd-done').onclick = () => { box.open = false; };
      document.addEventListener('click', e => { if (box.open && !box.contains(e.target)) box.open = false; });
      field.addEventListener('input', sync); sync();
    };
    multi($('#p-super'), f.super); multi($('#p-dev'), f.dev);
    const pick = (sel, field) => { const s = $(sel); s.onchange = () => {
      const p = s.value; if (!p) return;
      const cur = field.value.trim();
      field.value = cur ? cur + '\n' + p : p;
      s.value = ''; draw(); field.focus();
    }; };
    pick('#s-how', f.how);
    const save = async (action) => {
      const btns = main.querySelectorAll('.actions button'); btns.forEach(b => b.disabled = true);
      try {
        const r = await call(action, { id: a.id, ...values() });
        Object.assign(a, r.assessment);
        await load();
        toast(action === 'submit' ? 'Sent for review' : 'Saved');
        if (action === 'submit') location.hash = '#/'; else showAssess(a.id);
      } catch (e) {
        btns.forEach(b => b.disabled = false);
        $('#warn').innerHTML = `<div class="err">${esc(e.message)}${e.flagged ? ': ' + e.flagged.map(w => `“${esc(w)}”`).join(', ') : ''}</div>`;
      }
    };
    $('#save').onclick = () => save('save');
    $('#send').onclick = () => save('submit');
  }

  // ---------- review (admins) ----------
  function showReview() {
    const q = D.assessments.filter(a => a.status === 'review');
    const mine = q.filter(a => a.mine), theirs = q.filter(a => !a.mine);
    main.innerHTML = `${steps(1)}
      <div><h1 class="display" style="font-size:38px">Review queue</h1>
        <p class="muted" style="margin:4px 0 0">${theirs.length} waiting for you${mine.length ? ` · ${mine.length} of your own are waiting for another admin` : ''}</p></div>
      ${theirs.length ? theirs.map(a => `
        <section class="box stack" id="r${a.id}">
          <div style="display:flex;gap:12px;align-items:center"><div class="av">${initials(a.player_name)}</div>
            <div><b style="font-size:18px">${esc(a.player_name)}</b><div class="muted small">${codeName(a.code)} · from ${esc(a.assessor_name || a.updated_by || '')} · ${when(a.updated_at)}</div></div></div>
          <div class="layout" style="gap:16px">
            <div class="main" style="flex-basis:380px">
              <div><div class="k red">Superpower</div><div>${esc(a.superpower).replace(/\n/g, '<br>')}</div></div>
              <div><div class="k">Development</div><div>${esc(a.development).replace(/\n/g, '<br>')}</div></div>
              <div><div class="k">How</div><div>${esc(a.how).replace(/\n/g, '<br>')}</div></div>
              ${a.video_url ? `<div><div class="k">Help video${a.video_url.trim().includes('\n') ? 's' : ''}</div>${a.video_url.split(/\s+/).filter(Boolean).map(u => `<div><a href="${esc(u)}" target="_blank" rel="noopener">${esc(u)}</a></div>`).join('')}</div>` : ''}
              ${a.coach_note ? `<div><div class="k" style="color:var(--muted)">Coach-only note</div><div class="muted">${esc(a.coach_note)}</div></div>` : ''}
              ${flagged(a.superpower, a.development, a.how).length ? `<div class="warn">Wording check: please ask for a change.</div>` : `<div class="banner green" style="padding:10px 14px">${ICON.tick}<span>Wording check passed</span></div>`}
              <label class="stack" style="gap:6px"><b>Comment for ${esc((a.assessor_name || 'the coach').split(' ')[0])}</b><textarea rows="2" data-c="${a.id}" placeholder="Only needed if you're asking for a change"></textarea></label>
              <div class="actions"><button class="btn" data-x="${a.id}">Ask for a change</button><span class="grow"></span><button class="btn red" data-ok="${a.id}">Approve</button></div>
            </div>
          </div>
        </section>`).join('') : '<section class="box empty">Nothing waiting for you. Nice.</section>'}`;
    const decide = async (id, decision) => {
      const comment = main.querySelector(`[data-c="${id}"]`).value;
      try { await call('review', { id, decision, comment }); await load(); toast(decision === 'approve' ? 'Approved' : 'Sent back to the coach'); showReview(); }
      catch (e) { toast(e.message); }
    };
    main.querySelectorAll('[data-ok]').forEach(b => b.onclick = () => decide(Number(b.dataset.ok), 'approve'));
    main.querySelectorAll('[data-x]').forEach(b => b.onclick = () => decide(Number(b.dataset.x), 'changes'));
  }

  // ---------- check-ins ----------
  function showCheckins() {
    const dates = ME.checkDates || [];
    const rows = mineOrAll().filter(a => a.code === view.code);
    const next = dates.find(d => d >= today) || dates[dates.length - 1];
    main.innerHTML = `${steps(3)}
      <section class="toolbar">
        <div><h1 class="display" style="font-size:38px">Check-ins</h1>
          <p class="muted" style="margin:4px 0 0">A short note on her focus every two weeks. Next one: <b style="color:var(--ink)">${next ? day(next) : '—'}</b>. Notes go to families at the next Publish.</p></div>
        <div style="display:flex;gap:10px;flex-wrap:wrap">${scopeSeg()}${codeSeg()}</div>
      </section>
      <div class="grid-wrap"><table class="grid">
        <thead><tr><th>Player</th><th>Working on</th>${dates.map(d => `<th style="text-align:center">${day(d)}</th>`).join('')}</tr></thead>
        <tbody>${rows.length ? rows.map(a => `<tr>
          <td><div class="who"><div class="av" style="width:32px;height:32px;font-size:12px">${initials(a.player_name)}</div><b>${esc(a.player_name)}</b></div></td>
          <td class="small" style="color:var(--ink-2)">${esc(a.development) || '<span class="muted">Not set yet</span>'}</td>
          ${dates.map(d => {
            const k = a.checkins.find(c => c.check_date === d);
            const cls = k ? 'done' : (d <= today ? 'due' : 'up');
            const label = k ? (PROGRESS[k.progress] || 'Note added') : (d <= today ? 'Due' : '—');
            return `<td><button class="cell ${cls}" data-a="${a.id}" data-d="${d}" aria-label="${esc(a.player_name)}, ${day(d)}: ${label}">${label}</button></td>`;
          }).join('')}</tr>`).join('') : `<tr><td colspan="${dates.length + 2}" class="empty">No girls here yet.</td></tr>`}</tbody>
      </table></div>`;
    bindCodeSeg(showCheckins); bindScopeSeg(showCheckins);
    main.querySelectorAll('.cell').forEach(b => b.onclick = () => openCheckin(Number(b.dataset.a), b.dataset.d));
  }

  function openCheckin(id, date) {
    const a = D.assessments.find(x => x.id === id);
    const k = a.checkins.find(c => c.check_date === date) || {};
    let progress = k.progress || '';
    const dlg = $('#dlg');
    const canEdit = ME.isAdmin || a.mine;
    dlg.innerHTML = `<div class="dlg">
      <div style="font:600 20px Oswald,sans-serif">Check-in · ${esc(a.player_name)} · ${day(date)}</div>
      <div class="muted">Working on: ${esc(a.development) || 'not set yet'}</div>
      <div class="opts" role="group" aria-label="How is it going">${Object.entries(PROGRESS).map(([v, l]) => `<button data-p="${v}" class="${progress === v ? 'on' : ''}" ${canEdit ? '' : 'disabled'}>${l}</button>`).join('')}</div>
      <label class="stack" style="gap:6px"><b>Note for ${esc(a.player_name.split(' ')[0])} and her family</b>
        <textarea id="ck-note" rows="3" ${canEdit ? '' : 'readonly'} placeholder="Something she did well, and what's next">${esc(k.note)}</textarea></label>
      <div id="ck-warn"></div>
      <div class="actions"><button class="btn" id="ck-close">Close</button><span class="grow"></span>${canEdit ? '<button class="btn red" id="ck-save">Save</button>' : ''}</div>
    </div>`;
    dlg.showModal();
    dlg.querySelectorAll('[data-p]').forEach(b => b.onclick = () => { progress = b.dataset.p; dlg.querySelectorAll('[data-p]').forEach(x => x.classList.toggle('on', x === b)); });
    $('#ck-close').onclick = () => dlg.close();
    const note = $('#ck-note');
    note.oninput = () => { const bad = flagged(note.value); $('#ck-warn').innerHTML = bad.length ? `<div class="warn">Please reword: ${bad.map(w => `“${esc(w)}”`).join(', ')}</div>` : ''; };
    if (canEdit) $('#ck-save').onclick = async () => {
      try { await call('checkin', { id, date, progress, note: note.value }); await load(); dlg.close(); toast('Check-in saved'); showCheckins(); }
      catch (e) { $('#ck-warn').innerHTML = `<div class="err">${esc(e.message)}</div>`; }
    };
  }

  // ---------- publish (admins) ----------
  function showPublish() {
    const all = D.assessments;
    const c = s => all.filter(a => a.status === s).length;
    const changed = all.filter(a => a.changed_since_publish).length;
    const ready = all.filter(a => a.status === 'approved' && a.member_id).length;
    const noLogin = [...new Set(all.filter(a => !a.member_id).map(a => a.player_name))];
    main.innerHTML = `${steps(2)}
      <div><h1 class="display" style="font-size:38px">Share cards with families</h1>
        <p class="muted" style="margin:4px 0 0">Every approved card goes out together. Press it again any time to send updates and new check-in notes.</p></div>
      <section class="stats">
        <div class="stat"><span class="muted">Approved, ready</span><b style="color:var(--green-ink)">${ready}</b></div>
        <div class="stat"><span class="muted">With reviewer</span><b>${c('review')}</b></div>
        <div class="stat"><span class="muted">Still with coaches</span><b>${c('todo') + c('draft') + c('changes')}</b></div>
        <div class="stat"><span class="muted">Changed since last share</span><b>${changed}</b></div>
      </section>
      <section class="box stack">
        <div>${D.lastRelease ? `Last shared <b>${new Date(D.lastRelease.published_at).toLocaleString('en-IE', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })}</b> by ${esc(D.lastRelease.published_by)} (${D.lastRelease.cards} cards).` : 'Nothing has been shared yet.'}</div>
        <div class="muted small">Cards that aren't approved stay as they were. A girl's family keeps seeing her last shared card until her new one is approved.</div>
        ${noLogin.length ? `<div class="warn">${noLogin.length} ${noLogin.length === 1 ? 'name' : 'names'} in the sheet didn't match a player on the CoachSmart team, so no family can open those cards yet: ${noLogin.map(esc).join(', ')}.</div>` : ''}
        <div class="actions"><span class="grow"></span><button class="btn red" id="pub" ${ready ? '' : 'disabled'}>Share ${ready} approved ${ready === 1 ? 'card' : 'cards'}</button></div>
      </section>
      <section class="box stack">
        <b>Where families see it</b>
        <div>Parents sign in with their CoachSmart login at <a href="../card/" target="_blank">coachsmart.app/clontarf-gaa/feile27/card</a>. Only that girl's parents and the team's admins can open her card. Anyone else gets a message that it isn't theirs.</div>
      </section>`;
    const b = $('#pub');
    if (b) b.onclick = async () => {
      if (!confirm(`Share ${ready} cards with families now?`)) return;
      b.disabled = true; b.textContent = 'Sharing…';
      try { const r = await call('publish'); await load(); toast(`${r.published} cards shared`); showPublish(); }
      catch (e) { toast(e.message); b.disabled = false; }
    };
  }

  const ICON = {
    bolt: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round" aria-hidden="true"><path d="M13 2L4 14h7l-1 8 9-12h-7z"/></svg>',
    target: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1"/></svg>',
    check: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 11l3 3L22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/></svg>',
    video: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round" aria-hidden="true"><rect x="2" y="5" width="15" height="14" rx="2"/><path d="M17 10l5-3v10l-5-3z"/></svg>',
    lock: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg>',
    bulb: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 18h6M10 22h4M12 2a7 7 0 0 0-4 12.7V17h8v-2.3A7 7 0 0 0 12 2z"/></svg>',
    arrow: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>',
    tick: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 6L9 17l-5-5"/></svg>'
  };

  // ---------- start ----------
  PC.ready.then(async () => {
    try { ME = await call('me'); }
    catch (e) { main.innerHTML = `<p class="err">${esc(e.message)}</p>`; return; }
    if (!ME.isCoach) {
      main.innerHTML = `<section class="box stack"><b>This page is for the team's coaches.</b>
        <div>${ME.children.length ? `Looking for your daughter's card? <a href="../card/${location.search}">Open her card</a>.` : 'Your CoachSmart login isn\'t a coach on Clontarf Girls 2012.'}</div>
        ${PC.inApp ? '' : '<button class="btn" id="so">Sign out</button>'}</section>`;
      const so = $('#so'); if (so) so.onclick = PC.signOut;
      return;
    }
    if (!ME.isAdmin) view.scope = 'mine';
    $('#nav').hidden = false;
    document.querySelectorAll('[data-admin]').forEach(a => a.hidden = !ME.isAdmin);
    $('#me').hidden = false; $('#meAv').textContent = initials(ME.name); $('#meName').textContent = ME.name;
    $('#meRole').textContent = ME.isAdmin ? 'Coach · Admin' : 'Coach';
    $('#me').onclick = () => { if (!PC.inApp && confirm('Sign out?')) PC.signOut(); };
    window.addEventListener('hashchange', route);
    route();
  });
})();
