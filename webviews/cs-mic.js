/* CoachSmart voice input, shared by game-upload, session-plan and favourites.
 *
 * In the app, speech goes through the native NativeWebView widget via
 * FlutterBridge (startSpeech:<field> / stopSpeech), and the widget calls back
 * onSpeechReady, onVoiceInterim, receiveSpeechResult, onSpeechDone and
 * onSpeechError. In a plain browser it falls back to the Web Speech API.
 *
 * In the app (iOS and Android): press and hold. In a browser: tap to start,
 * tap to stop.
 * After stopping we wait for the engine to hand over its last words before
 * passing the full text to the page's onResult.
 *
 * Also copes with older app builds, which deliver text in chunks while
 * recording and can end a recording on their own at a pause.
 */
(function () {
  'use strict';

  const ua = navigator.userAgent || '';
  // iPadOS reports itself as a Mac; touch points give it away.
  const isIOS = /iPhone|iPad|iPod/i.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1);
  const bridge = () => window.FlutterBridge || null;
  const holdMode = () => !!bridge();

  const DONE_TIMEOUT = 3500;
  const FILLERS = /\b(um+h?|uh+|erm+|eh+|ahh?|mm+|hmm+|err+|y'know)\b[\s,]*/gi;
  const clean = t => (t || '').replace(FILLERS, ' ').replace(/\s{2,}/g, ' ').trim();

  const store = {
    get(k) { try { return localStorage.getItem(k); } catch { return null; } },
    set(k) { try { localStorage.setItem(k, '1'); } catch {} },
  };

  const mics = {};
  let active = null; // the mic currently preparing, recording or finishing

  const TEXT = {
    hold:      { preparing: 'Starting… keep holding',      recording: 'Listening… release when done' },
    tap:       { preparing: 'Starting…',                    recording: 'Listening… tap the mic again when done' },
    finishing: 'Finishing…',
  };

  function toast(m, msg) {
    if (m && m.opts.onError) m.opts.onError(msg);
    else if (typeof window.showToast === 'function') window.showToast(msg, 'error');
  }

  function setUi(m, state) {
    const { button, wave, instruction } = m.opts;
    if (button) {
      button.classList.toggle('preparing', state === 'preparing');
      button.classList.toggle('recording', state === 'recording');
    }
    if (wave) wave.classList.toggle('active', state === 'recording');
    if (instruction) {
      const mode = holdMode() ? 'hold' : 'tap';
      instruction.textContent =
        state === 'idle'      ? (m.opts.idleText ? m.opts.idleText[mode] : instruction.textContent) :
        state === 'finishing' ? TEXT.finishing :
                                TEXT[mode][state];
    }
  }

  function showTranscript(m, text) {
    const el = m.opts.transcript;
    if (!el) return;
    el.textContent = text;
    if (m.opts.autoHideTranscript) el.style.display = text ? '' : 'none';
  }

  function start(m) {
    if (m.state !== 'idle' || (active && active !== m)) return;
    active = m;
    m.state = 'preparing';
    m.text = ''; m.interim = '';
    m.startedAt = Date.now();
    showTranscript(m, '');
    if (m.opts.onStart) m.opts.onStart();
    setUi(m, 'preparing');
    if (bridge()) {
      bridge().postMessage('startSpeech:' + m.fieldId);
      // Newer app builds say when the mic is live (onSpeechReady). For older
      // builds, fall back to a fixed delay as before.
      const delay = store.get('cs_mic_ready_signal') ? 5000
        : (!isIOS || store.get('cs_mic_warmed')) ? 700 : 2000;
      m.readyTimer = setTimeout(() => ready(m), delay);
    } else {
      startWeb(m);
    }
  }

  function ready(m) {
    clearTimeout(m.readyTimer);
    if (m.state !== 'preparing') return;
    m.state = 'recording';
    setUi(m, 'recording');
  }

  function stop(m) {
    if (m.state !== 'preparing' && m.state !== 'recording') return;
    clearTimeout(m.readyTimer);
    m.state = 'finishing';
    setUi(m, 'finishing');
    if (bridge()) {
      bridge().postMessage('stopSpeech');
      m.doneTimer = setTimeout(() => finish(m), DONE_TIMEOUT);
    } else {
      stopWeb(m);
    }
  }

  function finish(m) {
    if (m.state === 'idle') return;
    clearTimeout(m.doneTimer); clearTimeout(m.readyTimer);
    if (m.webRec) { const r = m.webRec; m.webRec = null; try { r.abort(); } catch {} }
    const text = clean(m.text);
    m.state = 'idle';
    if (active === m) active = null;
    setUi(m, 'idle');
    showTranscript(m, text);
    m.opts.onResult(text);
  }

  // Abandon a recording without passing anything to the page.
  function reset(m) {
    clearTimeout(m.doneTimer); clearTimeout(m.readyTimer);
    if (m.webRec) { const r = m.webRec; m.webRec = null; try { r.abort(); } catch {} }
    m.state = 'idle';
    if (active === m) active = null;
    setUi(m, 'idle');
  }

  // ── Browser fallback (PWA / desktop) ────────────────────────────────────────
  function startWeb(m) {
    const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SR) { reset(m); toast(m, "Voice input isn't supported in this browser. Try typing instead."); return; }
    const rec = new SR();
    rec.lang = 'en-IE';
    rec.continuous = true;
    rec.interimResults = true;
    m.webRec = rec;
    rec.onstart = () => ready(m);
    rec.onresult = (e) => {
      let interim = '';
      for (let i = e.resultIndex; i < e.results.length; i++) {
        if (e.results[i].isFinal) m.text = (m.text + ' ' + e.results[i][0].transcript).trim();
        else interim += e.results[i][0].transcript;
      }
      m.interim = interim;
      showTranscript(m, (m.text + ' ' + interim).trim());
    };
    rec.onerror = (e) => {
      if (e.error === 'not-allowed' || e.error === 'service-not-allowed') {
        m.webRec = null;
        reset(m);
        toast(m, 'Microphone permission is off. Allow it for this site to use voice input.');
      }
    };
    rec.onend = () => {
      if (m.webRec !== rec) return;
      // Browsers stop by themselves after a silence; keep going while recording.
      if (m.state === 'preparing' || m.state === 'recording') {
        try { rec.start(); return; } catch {}
      }
      m.webRec = null;
      if (m.interim) { m.text = (m.text + ' ' + m.interim).trim(); m.interim = ''; }
      finish(m);
    };
    try { rec.start(); } catch { m.webRec = null; reset(m); toast(m, 'Could not start the microphone'); }
  }

  function stopWeb(m) {
    const rec = m.webRec;
    if (!rec) { finish(m); return; }
    m.doneTimer = setTimeout(() => {
      if (m.interim) { m.text = (m.text + ' ' + m.interim).trim(); m.interim = ''; }
      finish(m);
    }, DONE_TIMEOUT);
    try { rec.stop(); } catch { m.webRec = null; finish(m); }
  }

  // ── Callbacks from the native widget ────────────────────────────────────────
  window.onSpeechReady = function (fieldId) {
    store.set('cs_mic_ready_signal');
    const m = mics[fieldId];
    if (m) ready(m);
  };

  // New builds: (fieldId, full text so far). Old builds: (text) for the game
  // description only, covering just the current chunk.
  window.onVoiceInterim = function (a, b) {
    const fieldId = b === undefined ? 'voice_input' : a;
    const text = b === undefined ? a : b;
    const m = mics[fieldId];
    if (!m || m.state === 'idle') return;
    m.interim = text || '';
    showTranscript(m, (m.text + ' ' + m.interim).trim());
  };

  window.receiveSpeechResult = function (fieldId, text) {
    const m = mics[fieldId];
    if (!m || m.state === 'idle' || !text) return;
    m.text = (m.text + ' ' + text).trim();
    m.interim = '';
    showTranscript(m, m.text);
  };

  window.onSpeechDone = function () {
    store.set('cs_mic_warmed');
    const m = active;
    if (!m) return;
    if (m.state === 'finishing') { finish(m); return; }
    // The engine stopped on its own while still recording (older builds do
    // this at a pause). Ignore a stray signal right after starting, which can
    // be left over from the warm-up.
    if (Date.now() - m.startedAt > 1000) finish(m);
  };

  window.onSpeechError = function (msg) {
    const m = active;
    // Keep anything already heard rather than throwing it away.
    if (m && m.text) { finish(m); return; }
    if (m) reset(m);
    msg = msg || '';
    if (/permission/i.test(msg)) msg = 'Microphone permission is off. Turn it on in Settings to use voice input.';
    else if (/network/i.test(msg)) msg = 'No connection for voice input. Check your signal and try again.';
    else if (/^error_/.test(msg) || !msg) msg = "Didn't catch that. Please try again.";
    toast(m, msg);
  };

  // ── Gestures ────────────────────────────────────────────────────────────────
  // In hold mode, lifting the last finger anywhere ends the recording.
  document.addEventListener('touchend', (e) => {
    if (active && holdMode() && e.touches.length === 0) stop(active);
  }, { passive: true });
  document.addEventListener('touchcancel', () => {
    if (active && holdMode()) stop(active);
  }, { passive: true });
  document.addEventListener('visibilitychange', () => {
    if (document.hidden && active) stop(active);
  });

  function bindButton(m, button) {
    if (!button || button._csMic) return;
    button._csMic = true;
    button.addEventListener('contextmenu', e => e.preventDefault());
    button.addEventListener('pointerdown', (e) => {
      e.preventDefault();
      const cur = mics[m.fieldId];
      if (holdMode()) { start(cur); return; }
      if (cur.state === 'idle') start(cur); else stop(cur);
    }, { passive: false });
    button.addEventListener('pointerup', () => { if (holdMode()) stop(mics[m.fieldId]); });
    button.addEventListener('pointercancel', () => { if (holdMode()) stop(mics[m.fieldId]); });
  }

  let warmupFired = false;

  window.CSMic = {
    isIOS,
    holdMode,

    /* attach(fieldId, opts) — call again if the button is re-rendered.
     * opts: button, wave, transcript, autoHideTranscript, instruction,
     *       idleText {hold, tap}, onStart(), onResult(text), onError(msg) */
    attach(fieldId, opts) {
      let m = mics[fieldId];
      if (!m) { m = mics[fieldId] = { fieldId, state: 'idle', text: '', interim: '' }; }
      m.opts = opts;
      bindButton(m, opts.button);
      if (m.state === 'idle') setUi(m, 'idle');
      return m;
    },

    isRecording(fieldId) {
      const m = fieldId ? mics[fieldId] : active;
      return !!m && m.state !== 'idle';
    },

    // iOS app: start and stop the engine once so the first real press is
    // quick. Only after the mic has been used once (permission granted).
    warmup() {
      if (warmupFired || !isIOS || !bridge() || !store.get('cs_mic_warmed')) return;
      warmupFired = true;
      setTimeout(() => {
        if (active) return;
        bridge().postMessage('startSpeech:warmup_init');
        setTimeout(() => { if (!active) bridge().postMessage('stopSpeech'); }, 400);
      }, 600);
    },
  };
})();
