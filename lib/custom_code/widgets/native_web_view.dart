// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:record/record.dart';
import 'package:universal_html/html.dart' as html;

class NativeWebView extends StatefulWidget {
  const NativeWebView({
    super.key,
    this.width,
    this.height,
    required this.url,
    this.onPageReady,
    this.onComplete,
    this.onLogout,
  });

  final double? width;
  final double? height;
  final String url;
  final Future Function()? onPageReady;
  final Future Function()? onComplete;
  final Future Function()? onLogout;

  @override
  State<NativeWebView> createState() => _NativeWebViewState();
}

class _NativeWebViewState extends State<NativeWebView>
    with WidgetsBindingObserver {
  WebViewController? _controller;

  // ── Voice input ────────────────────────────────────────────────────────────
  // One recording = from startSpeech:<field> until stopSpeech. Within one
  // recording the phone's recogniser may end its session several times
  // (Android at every pause, iOS after ~1 minute or a long silence). Each
  // time it does, we keep what was heard and start a new session, so
  // nothing said while the user is still recording is lost. The full text
  // is sent to the page once, after the user stops.
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  String? _localeId;
  // Field the user is recording into, or null when idle.
  String? _fieldId;
  // True from start until the user stops (button released / tapped again).
  bool _recording = false;
  DateTime? _recordingStartedAt;
  // Text from recogniser sessions (or iOS segments) already finished.
  String _committed = '';
  // Latest partial text of the current recogniser session.
  String _current = '';
  // Bumped on every new session; results from older sessions are ignored.
  int _gen = 0;
  bool _restartPending = false;
  bool _listenInFlight = false;
  int _notListeningTicks = 0;
  Timer? _watchdog;
  Completer<void>? _finalWaiter;

  static const _maxRecording = Duration(minutes: 5);
  static const _warmupField = 'warmup_init';

  // ── Web (PWA) only ─────────────────────────────────────────────────────────
  // On the web the page is shown in an iframe, and browsers block the
  // microphone inside an iframe unless the iframe allows it. This adds
  // allow="microphone" to every iframe the app creates. It runs once, and
  // never on iOS or Android (kIsWeb is false there).
  static bool _webMicAllowed = false;

  static void _allowMicInWebIframes() {
    if (!kIsWeb || _webMicAllowed) return;
    _webMicAllowed = true;
    try {
      final script = html.ScriptElement()
        ..text = r"""
(function () {
  var ALLOW = 'microphone; clipboard-write';
  function fix(f) {
    var a = f.getAttribute('allow') || '';
    if (/microphone/.test(a)) return false;
    f.setAttribute('allow', a ? a + '; ' + ALLOW : ALLOW);
    return true;
  }
  var orig = Document.prototype.createElement;
  Document.prototype.createElement = function (tag) {
    var el = orig.apply(this, arguments);
    if (String(tag).toLowerCase() === 'iframe') fix(el);
    return el;
  };
  function reload(f) { if (f.src && f.isConnected) { var s = f.src; f.src = 'about:blank'; f.src = s; } }
  document.querySelectorAll('iframe').forEach(function (f) { if (fix(f)) reload(f); });
})();
""";
      html.document.head?.append(script);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _allowMicInWebIframes();
    _initController();
    // Speech is initialized lazily on first use to avoid requesting
    // microphone permission on pages that don't need it.
  }

  // ── Always-on mic for the score keeper (audio sent to Gemini) ──────────────
  // audioArm: open the mic once and keep listening, holding the last few
  //   seconds in memory, so a press is instant. Replies onAudioArmed(true|false).
  // audioStart: the coach pressed the mic. Marks the spot, minus a short
  //   lead-in so the first word is never clipped.
  // audioStop: the coach let go. Sends the clip to the page as a WAV
  //   (base64) via onVoiceAudio. Nothing is kept or sent otherwise.
  // audioDisarm: close the mic (also when the app goes to the background).
  AudioRecorder? _rec;
  StreamSubscription<Uint8List>? _recSub;
  bool _audioWanted = false;
  bool _audioLive = false;
  bool _audioArming = false;
  final List<int> _audioBuf = [];
  int _audioDropped = 0; // bytes trimmed off the front of _audioBuf
  int? _audioMark;
  static const _rate = 16000; // 16 kHz mono 16-bit = 32,000 bytes a second
  static const _bytesPerSec = _rate * 2;
  static const _leadIn = _bytesPerSec * 7 ~/ 10; // 0.7 s before the press
  static const _keep = _bytesPerSec * 30; // hold at most 30 s

  Future<void> _audioArm() async {
    _audioWanted = true;
    if (_audioLive) {
      _js('window.onAudioArmed && window.onAudioArmed(true)');
      return;
    }
    if (_audioArming) return; // the call already under way will answer
    _audioArming = true;
    try {
      _rec ??= AudioRecorder();
      if (!await _rec!.hasPermission()) {
        _js('window.onAudioArmed && window.onAudioArmed(false, "permission")');
        return;
      }
      // speech_to_text can't share the mic
      if (_speech.isListening) {
        try { await _speech.cancel(); } catch (_) {}
      }
      final stream = await _rec!.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits, sampleRate: _rate, numChannels: 1));
      _audioBuf.clear();
      _audioDropped = 0;
      _audioMark = null;
      _recSub = stream.listen((data) {
        _audioBuf.addAll(data);
        final over = _audioBuf.length - _keep;
        // Don't trim past a press in progress
        if (over > _bytesPerSec && _audioMark == null) {
          _audioBuf.removeRange(0, over);
          _audioDropped += over;
        }
      });
      _audioLive = true;
      if (!_audioWanted) { await _audioDisarm(); return; }
      _js('window.onAudioArmed && window.onAudioArmed(true)');
    } catch (_) {
      _audioLive = false;
      _js('window.onAudioArmed && window.onAudioArmed(false)');
    } finally {
      _audioArming = false;
    }
  }

  Future<void> _audioDisarm({bool keepWanted = false}) async {
    if (!keepWanted) _audioWanted = false;
    _audioMark = null;
    final sub = _recSub;
    _recSub = null;
    _audioLive = false;
    try { await sub?.cancel(); } catch (_) {}
    try { await _rec?.stop(); } catch (_) {}
    _audioBuf.clear();
  }

  void _audioStart() {
    if (!_audioLive) return;
    final at = _audioDropped + _audioBuf.length - _leadIn;
    _audioMark = at < _audioDropped ? _audioDropped : at;
  }

  Future<void> _audioStop() async {
    final mark = _audioMark;
    if (mark == null || !_audioLive) {
      _js('window.onVoiceAudio && window.onVoiceAudio(null)');
      return;
    }
    // A tail so the last word isn't cut (people let go as they finish)
    await Future.delayed(const Duration(milliseconds: 700));
    _audioMark = null;
    final from = (mark - _audioDropped).clamp(0, _audioBuf.length).toInt();
    var pcm = _audioBuf.sublist(from);
    if (pcm.length.isOdd) pcm = pcm.sublist(0, pcm.length - 1);
    if (pcm.length < _bytesPerSec ~/ 4) {
      _js('window.onVoiceAudio && window.onVoiceAudio(null)');
      return;
    }
    _js('window.onVoiceAudio && window.onVoiceAudio(${jsonEncode(base64Encode(_wav(pcm)))})');
  }

  Uint8List _wav(List<int> pcm) {
    final h = ByteData(44);
    void str(int o, String v) { for (var i = 0; i < 4; i++) { h.setUint8(o + i, v.codeUnitAt(i)); } }
    str(0, 'RIFF');
    h.setUint32(4, 36 + pcm.length, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    h.setUint32(16, 16, Endian.little);
    h.setUint16(20, 1, Endian.little);
    h.setUint16(22, 1, Endian.little);
    h.setUint32(24, _rate, Endian.little);
    h.setUint32(28, _bytesPerSec, Endian.little);
    h.setUint16(32, 2, Endian.little);
    h.setUint16(34, 16, Endian.little);
    str(36, 'data');
    h.setUint32(40, pcm.length, Endian.little);
    final out = Uint8List(44 + pcm.length);
    out.setRange(0, 44, h.buffer.asUint8List());
    out.setRange(44, out.length, pcm);
    return out;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioDisarm();
    try { _rec?.dispose(); } catch (_) {}
    if (_keepAwake) {
      try { WakelockPlus.disable(); } catch (_) {}
    }
    _recording = false;
    _fieldId = null;
    try { _speech.cancel(); } catch (_) {}
    super.dispose();
  }

  // ── Screen on and sign-in (score keeper) ────────────────────────────────────
  // keepAwake:on / keepAwake:off keep the screen from sleeping while a page
  // needs it. It always turns off again when the page closes.
  bool _keepAwake = false;

  void _setKeepAwake(bool on) {
    _keepAwake = on;
    try {
      if (on) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }
    } catch (_) {}
  }

  // getToken: the page's sign-in is about to run out (it lasts an hour and a
  // match is longer). The app owns the sign-in, so it hands over its current
  // access token, refreshing it first if it has less than 5 minutes left.
  // Replies with window.csSetToken(token, expiresAtSeconds).
  Future<void> _sendToken() async {
    try {
      final auth = SupaFlow.client.auth;
      var session = auth.currentSession;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (session == null || (session.expiresAt ?? 0) - now < 300) {
        final res = await auth.refreshSession();
        session = res.session ?? auth.currentSession;
      }
      if (session == null) {
        _js('window.csSetToken && window.csSetToken(null, 0)');
        return;
      }
      _js('window.csSetToken && window.csSetToken(${jsonEncode(session.accessToken)}, ${session.expiresAt ?? 0})');
    } catch (_) {
      // No signal or sign-in failed: the page keeps everything and asks again
      _js('window.csSetToken && window.csSetToken(null, 0)');
    }
  }

  void _js(String code) {
    try { _controller?.runJavaScript(code); } catch (_) {}
  }

  String get _fullText => '$_committed $_current'.trim();

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onError: _onSpeechError,
        onStatus: _onSpeechStatus,
      );
    } catch (_) {
      _speechAvailable = false;
    }
    if (!_speechAvailable) return;
    // Prefer Irish English, then UK English, else the phone's default.
    try {
      final locales = await _speech.locales();
      String norm(String id) => id.replaceAll('-', '_').toLowerCase();
      for (final want in ['en_ie', 'en_gb']) {
        final match = locales.where((l) => norm(l.localeId) == want);
        if (match.isNotEmpty) {
          _localeId = match.first.localeId;
          break;
        }
      }
    } catch (_) {}
  }

  void _onSpeechError(dynamic error) {
    final String msg = error.errorMsg?.toString() ?? '';
    // Recoverable errors (no match, silence timeout, busy...) just end the
    // current session; the status handler restarts it while recording.
    final isPermission = msg.contains('permission');
    if (!isPermission || _fieldId == null) return;
    final fid = _fieldId;
    _resetRecording();
    if (fid != _warmupField) {
      _js('window.onSpeechError && window.onSpeechError(${jsonEncode("Microphone permission is off. Turn it on in Settings to use voice input.")})');
    }
  }

  // 'done' comes after the session's final result, so by then its words are
  // safely kept. (Restarting on 'notListening' would hand the old session's
  // late final result to the new session's listener.)
  void _onSpeechStatus(String status) {
    if (status != 'done' || _fieldId == null) return;
    _completeFinalWaiter();
    if (_recording) _scheduleRestart();
  }

  void _completeFinalWaiter() {
    final w = _finalWaiter;
    if (w != null && !w.isCompleted) w.complete();
  }

  void _commitCurrent() {
    if (_current.isNotEmpty) {
      _committed = '$_committed $_current'.trim();
      _current = '';
    }
  }

  void _onResult(int gen, dynamic result) {
    if (gen != _gen || _fieldId == null) return;
    final String words = (result.recognizedWords as String).trim();
    // A late final result from a session we already kept.
    if (_current.isEmpty && words.isNotEmpty && _committed.endsWith(words)) {
      if (result.finalResult == true) _completeFinalWaiter();
      return;
    }
    if (words.isNotEmpty) {
      // iOS sometimes starts its text over after a pause without marking
      // the earlier text final. A much shorter partial means a fresh
      // segment, so keep the previous one before replacing it.
      if (_current.length >= 12 && words.length < _current.length ~/ 2) {
        _commitCurrent();
      }
      _current = words;
    }
    if (result.finalResult == true) {
      _commitCurrent();
      _completeFinalWaiter();
    }
    if (_recording && _fieldId != _warmupField) {
      _js('window.onVoiceInterim && window.onVoiceInterim(${jsonEncode(_fieldId)}, ${jsonEncode(_fullText)})');
    }
  }

  Future<bool> _listenSession() async {
    final gen = ++_gen;
    _current = '';
    _listenInFlight = true;
    try {
      await _speech.listen(
        onResult: (result) => _onResult(gen, result),
        localeId: _localeId,
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        pauseFor: const Duration(seconds: 30),
        listenFor: _maxRecording,
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      _listenInFlight = false;
    }
  }

  // The recogniser ended its session while the user is still recording:
  // keep what it heard and start a new one.
  void _scheduleRestart() {
    if (_restartPending) return;
    _restartPending = true;
    Future.delayed(const Duration(milliseconds: 150), () async {
      _restartPending = false;
      if (!_recording || _fieldId == null) return;
      final started = _recordingStartedAt;
      if (started != null &&
          DateTime.now().difference(started) > _maxRecording) {
        // Safety cap so a forgotten tap-to-record doesn't run forever.
        _stopSpeech();
        return;
      }
      for (var attempt = 0; attempt < 4; attempt++) {
        if (!_recording || _fieldId == null) return;
        if (_listenInFlight || _speech.isListening) return;
        _commitCurrent();
        await _listenSession();
        await Future.delayed(const Duration(milliseconds: 300));
      }
    });
  }

  // Backstop for a session that ended without telling us (or a restart the
  // recogniser refused because it was still shutting down).
  void _startWatchdog() {
    _watchdog?.cancel();
    _notListeningTicks = 0;
    _watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_recording || _fieldId == null) {
        _watchdog?.cancel();
        return;
      }
      if (_listenInFlight || _restartPending || _speech.isListening) {
        _notListeningTicks = 0;
        return;
      }
      _notListeningTicks++;
      if (_notListeningTicks >= 2) {
        _notListeningTicks = 0;
        _scheduleRestart();
      }
    });
  }

  void _resetRecording() {
    _watchdog?.cancel();
    _watchdog = null;
    _recording = false;
    _fieldId = null;
    _committed = '';
    _current = '';
    _gen++;
    _completeFinalWaiter();
  }

  Future<void> _startSpeech(String fieldId) async {
    if (!_speechAvailable) {
      await _initSpeech();
    }
    if (!_speechAvailable) {
      if (fieldId != _warmupField) {
        _js('window.onSpeechError && window.onSpeechError(${jsonEncode("Voice input isn't available. Check that microphone and speech recognition are allowed for CoachSmart in Settings.")})');
      }
      return;
    }
    // The always-on mic and speech recognition can't share the microphone
    if (_audioLive) await _audioDisarm(keepWanted: true);
    // Abandon any earlier recording (e.g. the warm-up) without sending
    // anything for it.
    _resetRecording();
    if (_speech.isListening) {
      try { await _speech.cancel(); } catch (_) {}
    }
    _fieldId = fieldId;
    _recording = true;
    _recordingStartedAt = DateTime.now();
    final ok = await _listenSession();
    if (_fieldId != fieldId) return; // stopped or replaced meanwhile
    if (!ok) {
      _resetRecording();
      if (fieldId != _warmupField) {
        _js('window.onSpeechError && window.onSpeechError(${jsonEncode("Could not start the microphone. Please try again.")})');
      }
      return;
    }
    _startWatchdog();
    if (fieldId != _warmupField) {
      _js('window.onSpeechReady && window.onSpeechReady(${jsonEncode(fieldId)})');
    }
  }

  Future<void> _stopSpeech() async {
    final fid = _fieldId;
    if (fid == null || !_recording) return;
    _recording = false;
    _watchdog?.cancel();
    final stopGen = _gen;
    // Wait briefly for the recogniser's final result: it usually holds the
    // last words spoken before the button was released.
    final waiter = Completer<void>();
    _finalWaiter = waiter;
    final wasLive =
        _speech.isListening || _listenInFlight || _current.isNotEmpty;
    try { await _speech.stop(); } catch (_) {}
    if (wasLive) {
      try {
        await waiter.future.timeout(const Duration(milliseconds: 1500));
      } catch (_) {}
    }
    if (_finalWaiter == waiter) _finalWaiter = null;
    if (_gen != stopGen) return; // a new recording started meanwhile
    _commitCurrent();
    final words = _committed;
    _resetRecording();
    if (_audioWanted && !_audioLive) _audioArm();
    if (fid == _warmupField) return;
    if (words.isNotEmpty) {
      _js('window.receiveSpeechResult(${jsonEncode(fid)}, ${jsonEncode(words)})');
    }
    // Always signal done so the page resets and sends the text to the AI.
    _js('window.onSpeechDone && window.onSpeechDone()');
  }

  // When the app returns to the foreground, check whether the WebView's
  // content process is still alive. On iOS the OS can kill the WKWebView
  // renderer while the app is backgrounded; on Android the same can happen
  // to the WebView renderer. A dead process leaves a blank screen with no
  // way to recover from inside the page, so we detect it here and reload.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndReloadIfDead();
      if (_keepAwake) _setKeepAwake(true);
      if (_audioWanted && !_audioLive) _audioArm();
    } else if (state == AppLifecycleState.paused) {
      // Never listen in the background
      if (_audioLive) _audioDisarm(keepWanted: true);
    }
  }

  Future<void> _checkAndReloadIfDead() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    try {
      // A live process returns '1'; a dead process throws a PlatformException.
      await ctrl.runJavaScriptReturningResult('1');
    } catch (_) {
      try {
        ctrl.loadRequest(Uri.parse(widget.url));
      } catch (_) {}
    }
  }

  void _initController() {
    try {
      final ctrl = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent);

      // setOnShowFileSelector lives on AndroidWebViewController (the platform
      // layer), not on WebViewController itself. We call it via dynamic
      // dispatch on ctrl.platform so the FlutterFlow analyser (which runs
      // against an older SDK) does not reject it at edit time, while the
      // actual production build resolves it correctly on Android at runtime.
      // On iOS ctrl.platform is WebKitWebViewController which lacks the
      // method, so the call throws and is silently caught — iOS handles
      // file inputs natively without needing this hook.
      try {
        (ctrl.platform as dynamic).setOnShowFileSelector((dynamic params) async {
          try {
            final picker = ImagePicker();
            bool multiple = false;
            try {
              multiple = params.mode.toString().contains('openMultiple');
            } catch (_) {}
            if (multiple) {
              final images = await picker.pickMultiImage();
              return images.map((x) => Uri.file(x.path).toString()).toList();
            } else {
              final image = await picker.pickImage(source: ImageSource.gallery);
              if (image == null) return <String>[];
              return [Uri.file(image.path).toString()];
            }
          } catch (_) {
            return <String>[];
          }
        });
      } catch (_) {}

      ctrl
        ..addJavaScriptChannel(
          'FlutterBridge',
          onMessageReceived: (JavaScriptMessage msg) {
            final message = msg.message;
            if (message.startsWith('startSpeech:')) {
              _startSpeech(message.substring('startSpeech:'.length));
              return;
            }
            if (message == 'stopSpeech') {
              _stopSpeech();
              return;
            }
            if (message == 'keepAwake:on' || message == 'keepAwake:off') {
              _setKeepAwake(message == 'keepAwake:on');
              return;
            }
            if (message == 'audioArm') { _audioArm(); return; }
            if (message == 'audioDisarm') { _audioDisarm(); return; }
            if (message == 'audioStart') { _audioStart(); return; }
            if (message == 'audioStop') { _audioStop(); return; }
            if (message == 'getToken') {
              _sendToken();
              return;
            }
            if (message.startsWith('haptic:')) {
              // Small buzz for drag-and-drop: grab, tick (new slot), drop.
              switch (message.substring('haptic:'.length)) {
                case 'grab':
                  HapticFeedback.mediumImpact();
                  break;
                case 'drop':
                  HapticFeedback.lightImpact();
                  break;
                default:
                  HapticFeedback.selectionClick();
              }
              return;
            }
            if (message.startsWith('openUrl:')) {
              final url = message.substring('openUrl:'.length);
              try {
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              } catch (_) {}
              return;
            }
            if (message.startsWith('sharePdf:')) {
              // Format: sharePdf:filename.pdf:BASE64DATA
              final rest = message.substring('sharePdf:'.length);
              final sep = rest.indexOf(':');
              if (sep > 0) {
                final filename = rest.substring(0, sep);
                final b64 = rest.substring(sep + 1);
                try {
                  final bytes = base64Decode(b64);
                  Printing.sharePdf(bytes: bytes, filename: filename);
                } catch (_) {}
              }
              return;
            }
            switch (message) {
              case 'close':
                widget.onLogout?.call();
                break;
              case 'complete':
                widget.onComplete?.call();
                break;
            }
          },
        )
        ..setNavigationDelegate(NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.contains('/cs-close')) {
              widget.onLogout?.call();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ));
      _controller = ctrl;
      // Use async/await so loadRequest is guaranteed to run whether
      // clearCache succeeds or throws (e.g. on web platform).
      () async {
        try { await ctrl.clearCache(); } catch (_) {}
        if (mounted) ctrl.loadRequest(Uri.parse(widget.url));
      }();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    if (ctrl == null) {
      return Container(
        width: widget.width ?? double.infinity,
        height: widget.height ?? double.infinity,
        color: const Color(0xFF111418),
      );
    }
    return SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      // EagerGestureRecognizer wins the Flutter gesture arena immediately,
      // preventing parent widgets from stealing touch events mid-hold.
      // Without this, holds longer than ~500 ms lose their touchend/pointerup
      // to Flutter's scroll/pan recognizer, leaving JS stuck in recording state.
      child: WebViewWidget(
        controller: ctrl,
        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
          Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
        },
      ),
    );
  }
}
