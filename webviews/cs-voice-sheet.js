/* CoachSmart voice panel, shared by favourites, session-plan, game-upload and
 * match-report. Needs cs-mic.js loaded first.
 *
 * A panel slides up from the bottom with a large text box, a big mic and a
 * submit button. Spoken words land in the box so the coach can read and fix
 * them before sending. Typing in the box works too.
 *
 *   CSVoice.open({
 *     fieldId,        // CSMic field id, e.g. 'sp_feedback'
 *     title,          // e.g. 'Change: 3 v 2 Overlap'
 *     subtitle,       // one short line under the title
 *     placeholder,
 *     text,           // starting text
 *     submitLabel,    // e.g. 'Update'
 *     busyLabel,      // shown while onSubmit runs, e.g. 'Updating…'
 *     onSubmit(text), // may be async; return false to keep the panel open
 *   });
 *
 * CSVoice.restHtml({ id, label, placeholder, onclick }) gives the resting
 * box the pages show in place of the old mic buttons.
 */
(function () {
  'use strict';

  const MIC = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="2" width="6" height="12" rx="3"/><path d="M5 10a7 7 0 0 0 14 0M12 19v3M8 22h8"/></svg>';

  const CSS = `
  .csv-ov { position: fixed; inset: 0; z-index: 900; background: rgba(0,0,0,0); transition: background .25s; display: none; }
  .csv-ov.show { display: block; }
  .csv-ov.on { background: rgba(0,0,0,.55); }
  .csv-sheet {
    position: fixed; left: 0; right: 0; bottom: 0; z-index: 901; display: none;
    background: #1e222b; color: #f1f4f8; border-top: 2px solid #87c232; border-radius: 20px 20px 0 0;
    padding: 10px 16px max(18px, env(safe-area-inset-bottom));
    box-shadow: 0 -12px 30px rgba(0,0,0,.45);
    transform: translateY(100%); transition: transform .3s cubic-bezier(.2,.8,.2,1);
    font-family: inherit; max-height: 92vh; overflow-y: auto;
  }
  .csv-sheet.show { display: block; }
  .csv-sheet.on { transform: translateY(0); }
  .csv-grab { width: 40px; height: 4px; border-radius: 2px; background: rgba(255,255,255,.18); margin: 0 auto 12px; }
  .csv-top { display: flex; align-items: center; gap: 8px; margin-bottom: 4px; }
  .csv-title { flex: 1; font-size: 17px; font-weight: 700; line-height: 1.3; }
  .csv-x { width: 36px; height: 36px; display: flex; align-items: center; justify-content: center;
    color: #a1a1a2; font-size: 20px; background: none; border: none; cursor: pointer; flex-shrink: 0; }
  .csv-sub { font-size: 13px; color: #a1a1a2; margin-bottom: 12px; line-height: 1.4; }
  .csv-text, .csv-live {
    display: block; width: 100%; box-sizing: border-box; min-height: 140px; max-height: 38vh; overflow-y: auto;
    background: #262b36; color: #f1f4f8; border: 1.5px solid rgba(255,255,255,.08); border-radius: 14px;
    padding: 12px 14px; font-family: inherit; font-size: 17px; line-height: 1.5; resize: none; outline: none;
    word-break: break-word; -webkit-user-select: text; user-select: text;
  }
  .csv-text::placeholder { color: #a1a1a2; }
  .csv-text:focus { border-color: rgba(135,194,50,.55); }
  .csv-live { border-color: #dc3232; white-space: pre-wrap; }
  .csv-live:empty::before { content: "Listening…"; color: #a1a1a2; }
  .csv-row { display: flex; align-items: center; justify-content: space-between; gap: 10px; margin-top: 16px; }
  .csv-side { width: 104px; font-size: 13px; color: #a1a1a2; line-height: 1.3; }
  .csv-mic {
    width: 76px; height: 76px; border-radius: 50%; flex-shrink: 0; cursor: pointer;
    display: flex; align-items: center; justify-content: center;
    border: 2px solid #87c232; color: #87c232; background: rgba(135,194,50,.12);
    -webkit-user-select: none; user-select: none; touch-action: none; -webkit-tap-highlight-color: transparent;
    transition: background .15s, border-color .15s, color .15s;
  }
  .csv-mic svg { width: 34px; height: 34px; pointer-events: none; }
  .csv-mic.preparing { border-color: #f5a000; color: #f5a000; background: rgba(245,160,0,.12); animation: csvPrep 1s ease-in-out infinite; }
  .csv-mic.recording { border-color: #dc3232; color: #fff; background: #dc3232; animation: csvRing 1.2s ease-out infinite; }
  @keyframes csvPrep { 0%,100% { opacity: .6; } 50% { opacity: 1; } }
  @keyframes csvRing { 0% { box-shadow: 0 0 0 0 rgba(220,50,50,.45); } 70% { box-shadow: 0 0 0 16px rgba(220,50,50,0); } 100% { box-shadow: 0 0 0 0 rgba(220,50,50,0); } }
  .csv-send {
    width: 104px; height: 46px; border-radius: 12px; border: none; cursor: pointer;
    background: #87c232; color: rgba(0,0,0,.72); font-family: inherit; font-size: 15px; font-weight: 700;
  }
  .csv-send:disabled { opacity: .35; }
  .csv-hint { text-align: center; font-size: 13px; color: #a1a1a2; margin-top: 10px; min-height: 18px; }
  .csv-hint.rec { color: #ff6b6b; font-weight: 600; }
  /* Keep page toasts above the panel while it is open */
  body.csv-open .toast, body.csv-open #toast { z-index: 1000 !important; }

  /* Resting box shown on the page */
  .csv-rest {
    display: flex; align-items: center; gap: 12px; width: 100%; box-sizing: border-box; text-align: left;
    background: #262b36; border: 1.5px solid rgba(135,194,50,.55); border-radius: 16px;
    padding: 10px 10px 10px 14px; cursor: pointer; font-family: inherit; color: #f1f4f8;
    -webkit-tap-highlight-color: transparent;
  }
  .csv-rest:active { background: rgba(135,194,50,.12); }
  .csv-rest-body { flex: 1; min-width: 0; }
  .csv-rest-label { display: block; font-size: 11px; font-weight: 700; letter-spacing: .07em; text-transform: uppercase; color: #87c232; margin-bottom: 3px; }
  .csv-rest-ph { display: block; font-size: 15px; color: #a1a1a2; line-height: 1.4; }
  .csv-rest-mic {
    width: 46px; height: 46px; border-radius: 50%; flex-shrink: 0;
    display: flex; align-items: center; justify-content: center; background: #87c232; color: rgba(0,0,0,.72);
  }
  .csv-rest-mic svg { width: 22px; height: 22px; }
  /* Small mic that sits in the corner of a typing box (form fields) */
  .csv-field-mic {
    position: absolute; right: 8px; bottom: 8px; width: 40px; height: 40px; border-radius: 50%;
    display: flex; align-items: center; justify-content: center; border: none; cursor: pointer;
    background: #87c232; color: rgba(0,0,0,.72); box-shadow: 0 2px 8px rgba(0,0,0,.35);
  }
  .csv-field-mic svg { width: 20px; height: 20px; }
  `;

  let built = false, els = {}, cur = null, busy = false, micSeq = 0;

  // Styles go in straight away so resting boxes look right before first open.
  const st = document.createElement('style');
  st.textContent = CSS;
  (document.head || document.documentElement).appendChild(st);

  function build() {
    if (built) return;
    built = true;

    const ov = document.createElement('div');
    ov.className = 'csv-ov';
    ov.addEventListener('click', () => { if (!busy && !recording()) close(); });

    const sh = document.createElement('div');
    sh.className = 'csv-sheet';
    sh.setAttribute('role', 'dialog');
    sh.innerHTML = `
      <div class="csv-grab"></div>
      <div class="csv-top"><div class="csv-title"></div><button class="csv-x" aria-label="Close">✕</button></div>
      <div class="csv-sub"></div>
      <textarea class="csv-text" rows="5"></textarea>
      <div class="csv-live" style="display:none"></div>
      <div class="csv-row">
        <div class="csv-side">Tap the text to edit</div>
        <span class="csv-mic-slot"></span>
        <button class="csv-send"></button>
      </div>
      <div class="csv-hint"></div>`;
    document.body.appendChild(ov);
    document.body.appendChild(sh);

    els = {
      ov, sh,
      title: sh.querySelector('.csv-title'),
      sub:   sh.querySelector('.csv-sub'),
      text:  sh.querySelector('.csv-text'),
      live:  sh.querySelector('.csv-live'),
      slot:  sh.querySelector('.csv-mic-slot'),
      send:  sh.querySelector('.csv-send'),
      side:  sh.querySelector('.csv-side'),
      hint:  sh.querySelector('.csv-hint'),
    };
    sh.querySelector('.csv-x').addEventListener('click', () => { if (!busy && !recording()) close(); });
    els.text.addEventListener('input', updateSend);
    els.send.addEventListener('click', submit);
  }

  function recording() { return !!cur && window.CSMic && CSMic.isRecording(cur.fieldId); }

  function updateSend() {
    els.send.disabled = busy || recording() || !els.text.value.trim();
  }

  function showLive(on) {
    els.text.style.display = on ? 'none' : '';
    els.live.style.display = on ? '' : 'none';
    els.side.style.visibility = on ? 'hidden' : '';
    els.hint.classList.toggle('rec', on);
    if (!on) els.live.textContent = '';
  }

  // A fresh mic button per open, so each page's field id gets its own binding.
  function makeMic(fieldId) {
    els.slot.innerHTML = '';
    const btn = document.createElement('button');
    btn.className = 'csv-mic';
    btn.id = 'csvMic' + (++micSeq);
    btn.setAttribute('aria-label', 'Hold to speak');
    btn.innerHTML = MIC;
    els.slot.appendChild(btn);
    CSMic.attach(fieldId, {
      button:      btn,
      transcript:  els.live,
      instruction: els.hint,
      idleText:    { hold: 'Hold the mic to speak', tap: 'Tap the mic to speak, then tap again when done' },
      onStart()      { showLive(true); updateSend(); },
      onResult(text) {
        showLive(false);
        if (text) els.text.value = (els.text.value.trim() + ' ' + text).trim();
        els.text.scrollTop = els.text.scrollHeight;
        updateSend();
      },
      onError(msg) {
        showLive(false); updateSend();
        if (typeof window.showToast === 'function') window.showToast(msg, 'error');
      },
    });
  }

  function open(opts) {
    if (!window.CSMic) return;
    build();
    if (recording()) return;
    cur = opts;
    busy = false;
    els.title.textContent = opts.title || '';
    els.sub.textContent   = opts.subtitle || '';
    els.sub.style.display = opts.subtitle ? '' : 'none';
    els.text.placeholder  = opts.placeholder || 'Type here, or hold the mic to speak';
    els.text.value        = opts.text || '';
    els.send.textContent  = opts.submitLabel || 'Done';
    showLive(false);
    makeMic(opts.fieldId);
    updateSend();
    els.ov.classList.add('show');
    els.sh.classList.add('show');
    document.body.classList.add('csv-open');
    // Next frame so the slide-up transition runs.
    requestAnimationFrame(() => requestAnimationFrame(() => {
      els.ov.classList.add('on');
      els.sh.classList.add('on');
    }));
    CSMic.warmup();
  }

  function close() {
    if (!built || !els.sh.classList.contains('show')) return;
    els.ov.classList.remove('on');
    els.sh.classList.remove('on');
    if (document.activeElement === els.text) els.text.blur();
    setTimeout(() => {
      if (els.sh.classList.contains('on')) return; // reopened meanwhile
      els.ov.classList.remove('show');
      els.sh.classList.remove('show');
      document.body.classList.remove('csv-open');
    }, 300);
    cur = null;
  }

  async function submit() {
    if (!cur || busy || recording()) return;
    const text = els.text.value.trim();
    if (!text) return;
    busy = true;
    const label = els.send.textContent;
    els.send.textContent = cur.busyLabel || label;
    updateSend();
    let keepOpen = false;
    try { keepOpen = (await cur.onSubmit(text)) === false; }
    catch (_) { keepOpen = true; }
    busy = false;
    if (!cur) return;
    els.send.textContent = label;
    updateSend();
    if (!keepOpen) close();
  }

  function restHtml({ id, label, placeholder, onclick }) {
    return `<button type="button" class="csv-rest"${id ? ` id="${id}"` : ''} onclick="${onclick}">
      <span class="csv-rest-body"><span class="csv-rest-label">${label}</span><span class="csv-rest-ph">${placeholder}</span></span>
      <span class="csv-rest-mic">${MIC}</span></button>`;
  }

  window.CSVoice = {
    open, close, restHtml, micSvg: MIC,
    isOpen() { return built && els.sh.classList.contains('show'); },
  };
})();
