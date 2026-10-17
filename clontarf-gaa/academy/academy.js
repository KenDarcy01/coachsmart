// Clontarf 2013 boys: Dublin GAA Talent Academy expression of interest.
// One form; parents pick hurling, football or both, confirm the blitz dates, then their details.
// Responses go to Ken's "Dublin Dev - Sign Up Sheet" (Hurling and Football tabs) via its Apps Script web app.
(function () {
  const SHEET_URL = window.ACADEMY_SHEET_URL || '';
  const BLITZ = {
    hurling: { label: 'Hurling', month: 'NOV', day: '8', date: 'Sunday 8 November'  },
    football: { label: 'Football', month: 'NOV', day: '15', date: 'Sunday 15 November' }
  };

  const dateBox = c => `
    <div class="date-box">
      <div class="cal"><div class="m">${BLITZ[c].month}</div><div class="d">${BLITZ[c].day}</div></div>
      <div><div class="t">${BLITZ[c].label} Academy Blitz</div><div class="s">${BLITZ[c].date}. 7-a-side club teams. Venue and times to follow.</div></div>
    </div>`;

  document.getElementById('app').innerHTML = `
  <header class="hero">
    <div class="hero-in">
      <img src="../images/clontarf-crest.png" alt="Clontarf GAA crest">
      <div>
        <div class="club">Clontarf GAA · 2013 Boys</div>
        <h1>Dublin Talent Academy</h1>
        <div class="sub">Expression of interest · Hurling and Football</div>
      </div>
    </div>
  </header>
  <main class="wrap">
    <section class="card" id="intro">
      <h2>Is your son interested?</h2>
      <p>Dublin GAA is starting its Talent Academy selection for boys born in 2013. Clontarf will put forward teams at the Academy blitz days below.</p>
      <p>If your son would like to be considered for hurling, football or both, please fill in this short form.</p>
      ${dateBox('hurling')}
      ${dateBox('football')}
    </section>

    <section class="card" id="about">
      <h2>About the Academy</h2>
      <details>
        <summary>How selection works</summary>
        <div class="body">
          <p class="muted">Recruiting runs from October 2026 to March 2027, with about 6 dates per code.</p>
          <ol>
            <li>A series of 7-a-side blitz days with club teams, starting in October.</li>
            <li>15-a-side trial games.</li>
            <li>The panel is finalised.</li>
            <li>Skills testing with the new panel.</li>
            <li>Coaching sessions, matches and off-pitch activities through 2027.</li>
            <li>Further trials and a regional tournament in Nov/Dec 2027 to bring in new players for U15 in 2028.</li>
          </ol>
        </div>
      </details>
      <details>
        <summary>What the selectors look for</summary>
        <div class="body">
          <ul>
            <li><b>Skill level</b>, the most important.</li>
            <li><b>Speed and intensity.</b></li>
            <li><b>Commitment</b>, including practising on his own.</li>
          </ul>
        </div>
      </details>
      <details>
        <summary>The pathway</summary>
        <div class="body">
          <div class="path">
            <div class="step"><span class="age">U14</span><span>Talent ID and showing potential (North and South squads of 35 to 40 players)</span></div>
            <div class="step"><span class="age">U15</span><span>Talent verification (55 to 65 players)</span></div>
            <div class="step"><span class="age">U16</span><span>45 to 55 players</span></div>
            <div class="step"><span class="age">Minor</span><span>36 players</span></div>
            <div class="step"><span class="age">U19/U20</span><span>Breakthrough and reward</span></div>
          </div>
          <p class="muted" style="margin-top:10px">Players can join and leave at different ages. Dual players are catered for in the Academy up to U15. Volunteer Academy coaches, backed by professional staff, support players at every stage.</p>
        </div>
      </details>
      <details>
        <summary>Feedback and communication</summary>
        <div class="body">
          <p>In the early stages, Dublin GAA communicates through club mentors and the Juvenile Chairperson. Because of the large number of players, individual feedback won't be possible early on.</p>
        </div>
      </details>
    </section>

    <form class="card" id="form" novalidate>
      <div class="step-k" id="stepK"></div>
      <div class="progress"><i></i><i></i><i></i><i></i></div>

      <div class="pane" data-step="1">
        <div class="field" data-f="codes">
          <label class="lbl">Which code would he like to be considered for? <span class="req">*</span></label>
          <div class="choices">
            <label class="choice big"><input type="radio" name="codes" value="hurling"><span><span class="ic">H</span><span>Hurling only</span></span></label>
            <label class="choice big"><input type="radio" name="codes" value="football"><span><span class="ic">F</span><span>Football only</span></span></label>
            <label class="choice big"><input type="radio" name="codes" value="both"><span><span class="ic">H+F</span><span>Both<small>Dual players are catered for up to U15</small></span></span></label>
          </div>
          <div class="err">Please pick one.</div>
        </div>
      </div>

      <div class="pane" data-step="2" hidden>
        <label class="lbl">Can he make the blitz?</label>
        <div class="hint">Clontarf's teams are picked from the boys who can be there.</div>
        ${['hurling', 'football'].map(c => `
        <div class="field" data-f="avail_${c}" data-code="${c}">
          ${dateBox(c)}
          <div class="choices three avail">
            <label class="choice"><input type="radio" name="avail_${c}" value="Yes"><span>Yes</span></label>
            <label class="choice"><input type="radio" name="avail_${c}" value="No"><span>No</span></label>
            <label class="choice"><input type="radio" name="avail_${c}" value="Not sure"><span>Not sure</span></label>
          </div>
          <div class="err">Please pick one.</div>
        </div>`).join('')}
      </div>

      <div class="pane" data-step="3" hidden>
        <div class="field" data-f="player">
          <label class="lbl">Player's name <span class="req">*</span></label>
          <div class="row2">
            <input type="text" name="player_first" placeholder="First name" autocomplete="off">
            <input type="text" name="player_last" placeholder="Surname" autocomplete="off">
          </div>
          <div class="err">Please enter his first name and surname.</div>
        </div>
        <div class="field" data-f="dob">
          <label class="lbl">Date of birth <span class="req">*</span></label>
          <input type="date" name="dob" min="2013-01-01" max="2013-12-31">
          <div class="err">Please enter a date in 2013.</div>
        </div>
        <div class="field">
          <label class="lbl">Anything we should know?</label>
          <div class="hint">Injuries, other commitments, or questions for the coaches. Optional.</div>
          <textarea name="notes"></textarea>
        </div>
      </div>

      <div class="pane" data-step="4" hidden>
        <div class="field" data-f="parent">
          <label class="lbl">Parent or guardian <span class="req">*</span></label>
          <input type="text" name="parent_name" placeholder="Full name" autocomplete="name">
          <div class="err">Please enter your name.</div>
        </div>
        <div class="field" data-f="phone">
          <label class="lbl">Mobile <span class="req">*</span></label>
          <input type="tel" name="parent_phone" placeholder="08x xxx xxxx" autocomplete="tel">
          <div class="err">Please enter a mobile number.</div>
        </div>
        <div class="field" data-f="email">
          <label class="lbl">Email</label>
          <input type="email" name="parent_email" placeholder="Optional" autocomplete="email">
          <div class="err">That email doesn't look right.</div>
        </div>
        <input class="hp" type="text" name="website" tabindex="-1" autocomplete="off" aria-hidden="true">
        <div class="summary" id="summary"></div>
        <div class="field" data-f="consent" style="margin-top:14px">
          <label class="consent"><input type="checkbox" name="consent"><span>I'm happy for Clontarf GAA to pass my son's name to Dublin GAA for Talent Academy selection, and to contact me about it.</span></label>
          <div class="err">Please tick to continue.</div>
        </div>
      </div>

      <div class="nav">
        <button class="back" type="button" id="back" hidden>Back</button>
        <button class="submit" type="submit" id="next">Next</button>
      </div>
      <div class="form-msg" id="formMsg"></div>
    </form>

    <section class="card done" id="done" hidden>
      <div class="tick">✓</div>
      <h2>Thanks, we've got it</h2>
      <p id="doneText"></p>
    </section>

    <div class="foot">Clontarf GAA · Juvenile Hurling and Football · 2013 Boys</div>
  </main>`;

  const form = document.getElementById('form');
  const panes = [...form.querySelectorAll('.pane')];
  const TITLES = ['Step 1 of 4 · Hurling, football or both', 'Step 2 of 4 · Blitz dates', 'Step 3 of 4 · Player', 'Step 4 of 4 · Your details'];
  let step = 1;
  const val = n => (form.elements[n].value || '').trim();
  const radio = n => (form.querySelector(`input[name="${n}"]:checked`) || {}).value || '';
  const codes = () => ({ hurling: ['hurling'], football: ['football'], both: ['hurling', 'football'] }[radio('codes')] || []);

  function show(n) {
    step = n;
    panes.forEach(p => p.hidden = +p.dataset.step !== n);
    form.querySelectorAll('.progress i').forEach((b, i) => b.classList.toggle('on', i < n));
    document.getElementById('stepK').textContent = TITLES[n - 1];
    document.getElementById('back').hidden = n === 1;
    document.getElementById('next').textContent = n === 4 ? 'Send' : 'Next';
    if (n === 2) form.querySelectorAll('[data-code]').forEach(f => f.hidden = !codes().includes(f.dataset.code));
    if (n === 4) document.getElementById('summary').innerHTML =
      `<div><span>Player</span><b>${esc(val('player_first'))} ${esc(val('player_last'))}</b></div>` +
      codes().map(c => `<div><span>${BLITZ[c].label} · ${BLITZ[c].date}</span><b>${radio('avail_' + c)}</b></div>`).join('');
  }
  const esc = s => s.replace(/[&<>"]/g, ch => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[ch]));

  form.addEventListener('change', e => { const f = e.target.closest('.field'); if (f) f.classList.remove('bad'); });
  form.addEventListener('input', e => { const f = e.target.closest('.field'); if (f) f.classList.remove('bad'); });
  document.getElementById('back').addEventListener('click', () => { show(step - 1); form.scrollIntoView(); });

  function check(n) {
    const bad = [];
    if (n === 1 && !radio('codes')) bad.push('codes');
    if (n === 2) codes().forEach(c => { if (!radio('avail_' + c)) bad.push('avail_' + c); });
    if (n === 3) {
      if (!val('player_first') || !val('player_last')) bad.push('player');
      if (!/^2013-\d\d-\d\d$/.test(val('dob'))) bad.push('dob');
    }
    if (n === 4) {
      if (!val('parent_name')) bad.push('parent');
      if (val('parent_phone').replace(/\D/g, '').length < 7) bad.push('phone');
      if (val('parent_email') && !/^\S+@\S+\.\S+$/.test(val('parent_email'))) bad.push('email');
      if (!form.elements.consent.checked) bad.push('consent');
    }
    panes[n - 1].querySelectorAll('.field').forEach(f => f.classList.toggle('bad', bad.includes(f.dataset.f)));
    return bad.length === 0;
  }

  function showDone(first, cs) {
    ['form', 'about', 'intro'].forEach(id => document.getElementById(id).hidden = true);
    document.getElementById('done').hidden = false;
    const names = cs.map(c => BLITZ[c].label.toLowerCase()).join(' and ');
    const dates = cs.map(c => BLITZ[c].date).join(' and ');
    document.getElementById('doneText').textContent =
      `We've noted ${first}'s interest in the ${names} Academy. His coaches will be in touch with venue and times for ${dates}.`;
    window.scrollTo(0, 0);
  }

  form.addEventListener('submit', async e => {
    e.preventDefault();
    const msg = document.getElementById('formMsg');
    msg.textContent = '';
    if (!check(step)) {
      const f = form.querySelector('.field.bad');
      if (f) f.scrollIntoView({ behavior: 'smooth', block: 'center' });
      return;
    }
    if (step < 4) { show(step + 1); form.scrollIntoView(); return; }
    if (val('website')) return; // bot
    const row = {
      codes: codes(),
      available: Object.fromEntries(codes().map(c => [c, radio('avail_' + c)])),
      player_first: val('player_first'),
      player_last: val('player_last'),
      dob: val('dob'),
      parent_name: val('parent_name'),
      parent_phone: val('parent_phone'),
      parent_email: val('parent_email'),
      notes: val('notes')
    };
    const btn = document.getElementById('next');
    btn.disabled = true; btn.textContent = 'Sending…';
    try {
      // text/plain keeps this a simple request, so Apps Script needs no CORS preflight.
      const r = await fetch(SHEET_URL, { method: 'POST', headers: { 'Content-Type': 'text/plain;charset=utf-8' }, body: JSON.stringify(row) });
      const j = await r.json();
      if (!j.ok) throw new Error(j.error || 'failed');
      showDone(row.player_first, row.codes);
    } catch (err) {
      msg.textContent = "Sorry, that didn't send. Please check your signal and try again.";
      btn.disabled = false; btn.textContent = 'Send';
    }
  });

  show(1);
  // Screenshot previews: ?preview=done
  if (new URLSearchParams(location.search).get('preview') === 'done') showDone('Oisín', ['hurling', 'football']);
  window.__academyShow = show;
})();
