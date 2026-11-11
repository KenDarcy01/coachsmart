// Native copy of the shared slide-up voice panel (webviews/cs-voice-sheet.js
// with cs-mic.js): a large text box, a big hold-to-talk mic and a submit
// button. Spoken words land in the box so the coach can read and fix them
// before sending; typing works too. Dictation uses speech_to_text directly
// rather than the web page's mic bridge.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../v3_theme.dart';
import 'v3_match_report_models.dart' show appendSpoken, cleanSpeech;

const _red = Color(0xFFDC3232);

/// Opens the panel. [onSubmit] gets the text; return false to keep the
/// panel open (for example when the AI step failed).
Future<void> showV3VoiceSheet(
  BuildContext context, {
  required String title,
  String subtitle = '',
  String placeholder = 'Type here, or hold the mic to speak',
  String text = '',
  String submitLabel = 'Done',
  String? busyLabel,
  required Future<bool> Function(String text) onSubmit,
  void Function(String message)? onError,
  ValueNotifier<V3SheetNote?>? note,
  V3Dictation? dictation,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => V3VoiceSheet(
      title: title,
      subtitle: subtitle,
      placeholder: placeholder,
      text: text,
      submitLabel: submitLabel,
      busyLabel: busyLabel,
      onSubmit: onSubmit,
      onError: onError,
      note: note,
      dictation: dictation,
    ),
  );
}

class V3VoiceSheet extends StatefulWidget {
  const V3VoiceSheet(
      {super.key,
      required this.title,
      this.subtitle = '',
      this.placeholder = 'Type here, or hold the mic to speak',
      this.text = '',
      this.submitLabel = 'Done',
      this.busyLabel,
      required this.onSubmit,
      this.onError,
      this.note,
      this.dictation});

  final String title, subtitle, placeholder, text, submitLabel;
  final String? busyLabel;
  final Future<bool> Function(String text) onSubmit;
  final void Function(String message)? onError;

  /// Messages the page wants seen while the panel covers its snack bar
  /// (the web page keeps its toasts above the panel).
  final ValueNotifier<V3SheetNote?>? note;

  /// Tests pass a fake; the app uses the real recogniser.
  final V3Dictation? dictation;

  @override
  State<V3VoiceSheet> createState() => _V3VoiceSheetState();
}

/// A line shown in the panel in place of the hint.
class V3SheetNote {
  const V3SheetNote(this.text, {this.error = false});
  final String text;
  final bool error;
}

enum _Mic { idle, preparing, recording, finishing }

class _V3VoiceSheetState extends State<V3VoiceSheet> {
  late final TextEditingController _text =
      TextEditingController(text: widget.text);
  late final V3Dictation _dict = widget.dictation ?? V3Dictation();
  _Mic _mic = _Mic.idle;
  String _live = '';
  bool _busy = false;
  bool _wantStop = false;

  bool get _recording => _mic != _Mic.idle;
  bool get _canSend => !_busy && !_recording && _text.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    _dict.onInterim = (t) {
      if (mounted && _recording) setState(() => _live = t);
    };
    _dict.onError = (msg) {
      if (!mounted) return;
      setState(() {
        _mic = _Mic.idle;
        _live = '';
      });
      _error(msg);
    };
  }

  @override
  void dispose() {
    _dict.dispose();
    if (widget.note == null) _note.dispose();
    _text.dispose();
    super.dispose();
  }

  late final ValueNotifier<V3SheetNote?> _note =
      widget.note ?? ValueNotifier<V3SheetNote?>(null);

  void _error(String msg) {
    if (widget.onError != null) {
      widget.onError!(msg);
    } else {
      _note.value = V3SheetNote(msg, error: true);
    }
  }

  Future<void> _press() async {
    if (_busy || _recording) return;
    FocusScope.of(context).unfocus();
    _wantStop = false;
    _note.value = null;
    setState(() {
      _mic = _Mic.preparing;
      _live = '';
    });
    final ok = await _dict.start();
    if (!mounted) return;
    if (!ok) {
      setState(() => _mic = _Mic.idle);
      return;
    }
    setState(() => _mic = _Mic.recording);
    if (_wantStop) await _release();
  }

  Future<void> _release() async {
    if (_mic == _Mic.preparing) {
      // Still starting: stop as soon as the mic is live.
      _wantStop = true;
      return;
    }
    if (_mic != _Mic.recording) return;
    setState(() => _mic = _Mic.finishing);
    final words = await _dict.stop();
    if (!mounted) return;
    setState(() {
      _mic = _Mic.idle;
      _live = '';
      if (words.isNotEmpty) _text.text = appendSpoken(_text.text, words);
    });
  }

  Future<void> _submit() async {
    if (!_canSend) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    var keepOpen = true;
    try {
      keepOpen = !(await widget.onSubmit(_text.text.trim()));
    } catch (_) {
      keepOpen = true;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (!keepOpen) Navigator.of(context).pop();
  }

  String get _hint => switch (_mic) {
        _Mic.idle => 'Hold the mic to speak',
        _Mic.preparing => 'Starting… keep holding',
        _Mic.recording => 'Listening… release when done',
        _Mic.finishing => 'Finishing…',
      };

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final maxBox = MediaQuery.of(context).size.height * 0.38;
    return PopScope(
      canPop: !_busy && !_recording,
      child: Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: Container(
          decoration: const BoxDecoration(
            color: V3.card,
            border: Border(top: BorderSide(color: V3.green, width: 2)),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(
              16, 10, 16, 18 + MediaQuery.of(context).padding.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2))),
                ),
                Row(children: [
                  Expanded(
                      child: Text(widget.title,
                          style: V3.tight(18, weight: FontWeight.w700))),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close, color: V3.muted, size: 24),
                      onPressed: _busy || _recording
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ),
                ]),
                if (widget.subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(widget.subtitle,
                        style: V3.inter(15, color: V3.muted, height: 1.4)),
                  ),
                ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: 140, maxHeight: maxBox),
                  child: _recording ? _liveBox() : _editBox(),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Visibility(
                        visible: !_recording,
                        child: Text('Tap the text to edit',
                            style: V3.inter(14, color: V3.muted, height: 1.3)),
                      ),
                    ),
                    _micButton(),
                    SizedBox(
                      width: 110,
                      height: 52,
                      child: FilledButton(
                        key: const ValueKey('voice-submit'),
                        style: FilledButton.styleFrom(
                          backgroundColor: V3.green,
                          disabledBackgroundColor:
                              V3.green.withValues(alpha: 0.35),
                          foregroundColor: Colors.black87,
                          disabledForegroundColor: Colors.black54,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _canSend ? _submit : null,
                        child: Text(
                            _busy
                                ? (widget.busyLabel ?? widget.submitLabel)
                                : widget.submitLabel,
                            textAlign: TextAlign.center,
                            style: V3.inter(16,
                                weight: FontWeight.w700,
                                color: Colors.black87)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<V3SheetNote?>(
                  valueListenable: _note,
                  builder: (_, note, __) {
                    final showNote = note != null && !_recording;
                    return Text(showNote ? note.text : _hint,
                        key: const ValueKey('voice-hint'),
                        textAlign: TextAlign.center,
                        style: _recording || (showNote && note.error)
                            ? V3.inter(15,
                                weight: FontWeight.w600,
                                color: const Color(0xFFFF6B6B))
                            : V3.inter(15,
                                color: showNote ? V3.green : V3.muted));
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _editBox() => TextField(
        key: const ValueKey('voice-text'),
        controller: _text,
        enabled: !_busy,
        minLines: 5,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        style: V3.inter(17, height: 1.5),
        cursorColor: V3.green,
        decoration: InputDecoration(
          hintText: widget.placeholder,
          hintStyle: V3.inter(17, color: V3.muted, height: 1.5),
          filled: true,
          fillColor: V3.card2,
          contentPadding: const EdgeInsets.all(14),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: V3.line, width: 1.5)),
          disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: V3.line, width: 1.5)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: V3.green.withValues(alpha: 0.55), width: 1.5)),
        ),
      );

  Widget _liveBox() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: V3.card2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _red, width: 1.5),
        ),
        child: SingleChildScrollView(
          reverse: true,
          child: Text(_live.isEmpty ? 'Listening…' : _live,
              style: V3.inter(17,
                  height: 1.5, color: _live.isEmpty ? V3.muted : V3.text)),
        ),
      );

  Widget _micButton() {
    final (Color border, Color fg, Color bg) = switch (_mic) {
      _Mic.preparing => (V3.amber, V3.amber, V3.amber.withValues(alpha: 0.12)),
      _Mic.recording || _Mic.finishing => (_red, Colors.white, _red),
      _Mic.idle => (V3.green, V3.green, V3.green.withValues(alpha: 0.12)),
    };
    return Semantics(
      button: true,
      label: 'Hold to speak',
      child: Listener(
        key: const ValueKey('voice-mic'),
        onPointerDown: (_) => _press(),
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg,
            border: Border.all(color: border, width: 2),
            boxShadow: _mic == _Mic.recording
                ? [
                    BoxShadow(
                        color: _red.withValues(alpha: 0.35),
                        blurRadius: 16,
                        spreadRadius: 4)
                  ]
                : null,
          ),
          child: Icon(Icons.mic_none_rounded, color: fg, size: 38),
        ),
      ),
    );
  }
}

/// Hold-to-talk dictation on speech_to_text, following the app's
/// NativeWebView mic: Irish English if the phone has it, a session restarted
/// whenever the recogniser stops on its own while the button is held, and
/// on release a short wait for the last words.
class V3Dictation {
  V3Dictation({SpeechToText? engine}) : _engineOverride = engine;

  final SpeechToText? _engineOverride;
  SpeechToText get _stt => _engineOverride ?? SpeechToText();

  void Function(String text)? onInterim;
  void Function(String message)? onError;

  static const _maxRecording = Duration(minutes: 10);
  static String? _localeId;
  static bool _localeChecked = false;

  bool _recording = false;
  bool _listenInFlight = false;
  bool _restartPending = false;
  String _committed = '';
  String _current = '';
  int _gen = 0;
  DateTime? _startedAt;
  Completer<void>? _finalWaiter;

  // speech_to_text is a single shared engine; the web view sets its own
  // listeners on it. Borrow them while this panel records and hand them back.
  SpeechErrorListener? _prevError;
  SpeechStatusListener? _prevStatus;
  bool _borrowed = false;

  String get _full => '$_committed $_current'.trim();

  Future<bool> _init() async {
    var ok = false;
    try {
      ok = await _stt.initialize();
    } catch (_) {
      ok = false;
    }
    if (!ok) return false;
    if (!_localeChecked) {
      _localeChecked = true;
      try {
        final locales = await _stt.locales();
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
    return true;
  }

  void _borrow() {
    if (_borrowed) return;
    _borrowed = true;
    _prevError = _stt.errorListener;
    _prevStatus = _stt.statusListener;
    _stt.errorListener = _onError;
    _stt.statusListener = _onStatus;
  }

  void _giveBack() {
    if (!_borrowed) return;
    _borrowed = false;
    _stt.errorListener = _prevError;
    _stt.statusListener = _prevStatus;
  }

  /// Starts listening. False (after [onError]) if the mic can't be used.
  Future<bool> start() async {
    if (!await _init()) {
      onError?.call(
          "Voice input isn't available. Check that microphone and speech recognition are allowed for CoachSmart in Settings.");
      return false;
    }
    _borrow();
    if (_stt.isListening) {
      try {
        await _stt.cancel();
      } catch (_) {}
    }
    _committed = '';
    _current = '';
    _recording = true;
    _startedAt = DateTime.now();
    if (!await _listen()) {
      _recording = false;
      _giveBack();
      onError?.call('Could not start the microphone. Please try again.');
      return false;
    }
    return true;
  }

  /// Stops and returns everything heard, fillers removed.
  Future<String> stop() async {
    if (!_recording) return '';
    _recording = false;
    final stopGen = _gen;
    final waiter = Completer<void>();
    _finalWaiter = waiter;
    final wasLive = _stt.isListening || _listenInFlight || _current.isNotEmpty;
    try {
      await _stt.stop();
    } catch (_) {}
    if (wasLive) {
      try {
        await waiter.future.timeout(const Duration(milliseconds: 1500));
      } catch (_) {}
    }
    if (_finalWaiter == waiter) _finalWaiter = null;
    if (_gen != stopGen) return '';
    _commit();
    final words = cleanSpeech(_committed);
    _committed = '';
    _gen++;
    _giveBack();
    return words;
  }

  void dispose() {
    if (_recording) {
      _recording = false;
      try {
        _stt.cancel();
      } catch (_) {}
    }
    _gen++;
    _giveBack();
    onInterim = null;
    onError = null;
  }

  Future<bool> _listen() async {
    final gen = ++_gen;
    _current = '';
    _listenInFlight = true;
    try {
      await _stt.listen(
        onResult: (r) => _onResult(gen, r),
        listenOptions: SpeechListenOptions(
          localeId: _localeId,
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
          pauseFor: const Duration(seconds: 30),
          listenFor: _maxRecording,
        ),
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      _listenInFlight = false;
    }
  }

  void _commit() {
    if (_current.isNotEmpty) {
      _committed = '$_committed $_current'.trim();
      _current = '';
    }
  }

  void _completeWaiter() {
    final w = _finalWaiter;
    if (w != null && !w.isCompleted) w.complete();
  }

  void _onResult(int gen, SpeechRecognitionResult r) {
    if (gen != _gen) return;
    final words = r.recognizedWords.trim();
    // A late final result from a session already kept.
    if (_current.isEmpty && words.isNotEmpty && _committed.endsWith(words)) {
      if (r.finalResult) _completeWaiter();
      return;
    }
    if (words.isNotEmpty) {
      // iOS can start its text over after a pause without marking the
      // earlier text final: keep the earlier segment.
      if (_current.length >= 12 && words.length < _current.length ~/ 2) {
        _commit();
      }
      _current = words;
    }
    if (r.finalResult) {
      _commit();
      _completeWaiter();
    }
    if (_recording) onInterim?.call(_full);
  }

  void _onStatus(String status) {
    if (status != 'done') return;
    _completeWaiter();
    if (_recording) _restart();
  }

  void _onError(SpeechRecognitionError e) {
    // Most errors (no match, silence) just end the session; the status
    // handler restarts it. Permission errors end the recording.
    if (!e.errorMsg.contains('permission') || !_recording) return;
    _recording = false;
    _gen++;
    _completeWaiter();
    _giveBack();
    onError?.call(
        'Microphone permission is off. Turn it on in Settings to use voice input.');
  }

  void _restart() {
    if (_restartPending) return;
    _restartPending = true;
    Future.delayed(const Duration(milliseconds: 150), () async {
      _restartPending = false;
      if (!_recording) return;
      final started = _startedAt;
      if (started != null &&
          DateTime.now().difference(started) > _maxRecording) {
        return;
      }
      for (var attempt = 0; attempt < 4; attempt++) {
        if (!_recording) return;
        if (_listenInFlight || _stt.isListening) return;
        _commit();
        await _listen();
        await Future.delayed(const Duration(milliseconds: 300));
      }
    });
  }
}
