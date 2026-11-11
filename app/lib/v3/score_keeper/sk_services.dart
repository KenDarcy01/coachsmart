// v3 Score keeper: what the page needs from outside — Supabase, the phone's
// storage, the screen, buzz and sound, and the mic. Each is a small class so
// widget tests swap in fakes and run with no network or plugins.
//
// The web page reaches these through the app's NativeWebView (keepAwake,
// getToken, audioArm/audioStart/audioStop/audioDisarm). Here they are plain
// Dart: the Supabase client keeps its own sign-in fresh, wakelock_plus keeps
// the screen on, and the always-on mic records 16 kHz PCM with `record`.
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import 'sk_models.dart';
import '/v3/tracking/v3_track.dart';

// ---------------------------------------------------------------- backend

/// The account has no AI features (score-voice answered 403).
class SkNoAi implements Exception {}

/// The calls the web page makes, one method each.
abstract class SkBackend {
  String get uid;

  /// get_score_keeper_state(p_event_id)
  Future<Map<String, dynamic>?> state(int eventId);

  /// get_my_ai_features()
  Future<bool> aiFeatures();

  /// match_timer upsert on (event_id, user_id)
  Future<void> upsertTimer(Map<String, dynamic> row);

  /// upsert_match_stats(p_event_id, p_opposition, p_squad_id) -> {id}
  Future<Map<String, dynamic>?> upsertMatchStats(
      int eventId, String? opposition, int? squadId);

  /// sync_match_actions(p_match_stats_id, p_actions, p_timer) -> {done}
  Future<Map<String, dynamic>?> sync(int matchStatsId,
      List<Map<String, dynamic>> actions, Map<String, dynamic>? timer);

  /// finalise_match_stats(p_match_stats_id)
  Future<void> finalise(int matchStatsId);

  /// reset_match_stats_session(p_match_stats_id) -> {id}
  Future<Map<String, dynamic>?> reset(int matchStatsId);

  /// score-voice edge function. Null when it couldn't answer; throws
  /// [SkNoAi] when the account has no AI.
  Future<Map<String, dynamic>?> voice(Map<String, dynamic> body);
}

Map<String, dynamic>? _map(dynamic r) {
  if (r is Map) return Map<String, dynamic>.from(r);
  if (r is String && r.isNotEmpty) {
    try {
      final j = jsonDecode(r);
      if (j is Map) return Map<String, dynamic>.from(j);
    } catch (_) {}
  }
  return null;
}

class SupabaseSkBackend implements SkBackend {
  const SupabaseSkBackend();

  @override
  String get uid => currentUserUid;

  Future<dynamic> _rpc(String fn, Map<String, dynamic> params) =>
      SupaFlow.client.rpc(fn, params: params);

  @override
  Future<Map<String, dynamic>?> state(int eventId) async =>
      _map(await _rpc('get_score_keeper_state', {'p_event_id': eventId}));

  @override
  Future<bool> aiFeatures() async =>
      (await SupaFlow.client.rpc('get_my_ai_features')) == true;

  @override
  Future<void> upsertTimer(Map<String, dynamic> row) => SupaFlow.client
      .from('match_timer')
      .upsert(row, onConflict: 'event_id,user_id');

  @override
  Future<Map<String, dynamic>?> upsertMatchStats(
          int eventId, String? opposition, int? squadId) async =>
      _map(await _rpc('upsert_match_stats', {
        'p_event_id': eventId,
        'p_opposition': opposition,
        'p_squad_id': squadId,
      }));

  @override
  Future<Map<String, dynamic>?> sync(int id, List<Map<String, dynamic>> actions,
          Map<String, dynamic>? timer) async =>
      _map(await _rpc('sync_match_actions', {
        'p_match_stats_id': id,
        'p_actions': actions,
        'p_timer': timer,
      }));

  @override
  Future<void> finalise(int id) =>
      _rpc('finalise_match_stats', {'p_match_stats_id': id})
          .whenComplete(() => V3Track.event('score_keeper_finished'));

  @override
  Future<Map<String, dynamic>?> reset(int id) async =>
      _map(await _rpc('reset_match_stats_session', {'p_match_stats_id': id}));

  @override
  Future<Map<String, dynamic>?> voice(Map<String, dynamic> body) async {
    try {
      final r =
          await SupaFlow.client.functions.invoke('score-voice', body: body);
      if (r.status == 403) throw SkNoAi();
      if (r.status < 200 || r.status >= 300) return null;
      return _map(r.data);
    } on FunctionException catch (e) {
      if (e.status == 403) throw SkNoAi();
      return null;
    }
  }
}

/// How an upload failed, as the web page sorts HTTP answers.
SkFail classifyFail(Object e) {
  if (e is AuthException) return SkFail.auth;
  if (e is PostgrestException) {
    final code = e.code ?? '';
    final msg = e.message.toLowerCase();
    if (code == '401' ||
        code == '403' ||
        code == 'PGRST301' ||
        code == 'PGRST302' ||
        code == '42501' ||
        msg.contains('jwt')) {
      return SkFail.auth;
    }
    // Timeouts, rate limits and server trouble: try again later
    if (code == '408' ||
        code == '429' ||
        RegExp(r'^5\d\d$').hasMatch(code) ||
        RegExp(r'^(08|53|54|55|57|58|XX)').hasMatch(code)) {
      return SkFail.error;
    }
    return SkFail.bad;
  }
  if (e is SkBadRequest) return SkFail.bad;
  return SkFail.offline;
}

/// Thrown by test backends for an entry the server turns down.
class SkBadRequest implements Exception {}

// ---------------------------------------------------------------- storage

/// The phone's own copy of the match (the page's localStorage).
abstract class SkStore {
  Future<void> init();
  dynamic get(String key);
  void set(String key, dynamic value);
}

class PrefsSkStore implements SkStore {
  SharedPreferences? _p;

  @override
  Future<void> init() async {
    try {
      _p ??= await SharedPreferences.getInstance();
    } catch (_) {}
  }

  @override
  dynamic get(String key) {
    final s = _p?.getString(key);
    if (s == null) return null;
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  @override
  void set(String key, dynamic value) {
    try {
      _p?.setString(key, jsonEncode(value));
    } catch (_) {}
  }
}

class MemorySkStore implements SkStore {
  final Map<String, String> data = {};

  @override
  Future<void> init() async {}

  @override
  dynamic get(String key) => data[key] == null ? null : jsonDecode(data[key]!);

  @override
  void set(String key, dynamic value) => data[key] = jsonEncode(value);
}

// ----------------------------------------------------------------- device

enum SkSound { injury, halfTime, fullTime }

/// Screen, buzz and the whistle.
class SkDevice {
  const SkDevice({this.quiet = false});

  /// Tests: no plugins at all.
  final bool quiet;

  Future<void> keepAwake(bool on) async {
    if (quiet) return;
    try {
      if (on) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {}
  }

  /// A buzz pattern in ms: on, off, on, ... (the page's navigator.vibrate).
  Future<void> buzz(List<int> pattern) async {
    if (quiet) return;
    for (var i = 0; i < pattern.length; i++) {
      if (i.isEven) {
        try {
          await (pattern[i] >= 100
              ? HapticFeedback.heavyImpact()
              : pattern[i] >= 30
                  ? HapticFeedback.mediumImpact()
                  : HapticFeedback.lightImpact());
        } catch (_) {}
      }
      if (i < pattern.length - 1) {
        await Future.delayed(Duration(milliseconds: pattern[i]));
      }
    }
  }

  static final Map<SkSound, String> _files = {};
  static VideoPlayerController? _player;

  /// The page's whistle and injury-time beeps, made here as a WAV and
  /// played once. Skipped while the always-on mic is open, so the sound
  /// never takes the phone's audio away from the recording.
  Future<void> sound(SkSound s, {bool micOpen = false}) async {
    if (micOpen || quiet) return;
    try {
      var path = _files[s];
      if (path == null) {
        final bytes = switch (s) {
          SkSound.injury => toneWav([0, 0.45, 0.9], 880, 0.35, 0.6),
          SkSound.halfTime => toneWav([0, 0.4], 740, 0.25, 0.7),
          SkSound.fullTime =>
            toneWav([0, 0.28, 0.56, 0.84, 1.12], 660, 0.25, 0.7),
        };
        final dir = await getTemporaryDirectory();
        final f = File('${dir.path}/sk_${s.name}.wav');
        await f.writeAsBytes(bytes, flush: true);
        path = _files[s] = f.path;
      }
      final old = _player;
      _player = null;
      await old?.dispose();
      final p = VideoPlayerController.file(File(path),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
      _player = p;
      await p.initialize();
      await p.play();
    } catch (_) {}
  }
}

/// 16-bit mono PCM -> WAV.
Uint8List pcmToWav(List<int> pcm, {int rate = 16000}) {
  final h = ByteData(44);
  void str(int o, String v) {
    for (var i = 0; i < 4; i++) {
      h.setUint8(o + i, v.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  h.setUint32(4, 36 + pcm.length, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  h.setUint32(16, 16, Endian.little);
  h.setUint16(20, 1, Endian.little);
  h.setUint16(22, 1, Endian.little);
  h.setUint32(24, rate, Endian.little);
  h.setUint32(28, rate * 2, Endian.little);
  h.setUint16(32, 2, Endian.little);
  h.setUint16(34, 16, Endian.little);
  str(36, 'data');
  h.setUint32(40, pcm.length, Endian.little);
  final out = Uint8List(44 + pcm.length);
  out.setRange(0, 44, h.buffer.asUint8List());
  out.setRange(44, out.length, pcm);
  return out;
}

/// Sine beeps at the given start times (s), each fading out over [len] s,
/// as the page's Web Audio beep() plays them.
Uint8List toneWav(List<double> times, double freq, double len, double vol,
    {int rate = 22050}) {
  final total = ((times.reduce(math.max) + len + 0.05) * rate).ceil();
  final samples = Float64List(total);
  for (final t0 in times) {
    final start = (t0 * rate).round();
    final n = (len * rate).round();
    for (var i = 0; i < n && start + i < total; i++) {
      final t = i / rate;
      // exponential ramp from vol to 0.001 over len
      final g = vol * math.pow(0.001 / vol, t / len);
      samples[start + i] += g * math.sin(2 * math.pi * freq * t);
    }
  }
  final pcm = ByteData(total * 2);
  for (var i = 0; i < total; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    pcm.setInt16(i * 2, v, Endian.little);
  }
  return pcmToWav(pcm.buffer.asUint8List(), rate: rate);
}

// -------------------------------------------------------------------- mic

/// The always-on mic: open once and keep listening, holding the last few
/// seconds in memory, so a press is instant. start() marks the spot minus a
/// 0.7 s lead-in so the first word is never clipped; stop() waits a 0.7 s
/// tail and hands back the clip as a WAV. Nothing is kept or sent otherwise.
class SkMic {
  SkMic({this.enabled = true});

  /// Tests: never opens the mic.
  final bool enabled;
  AudioRecorder? _rec;
  StreamSubscription<Uint8List>? _sub;
  bool _live = false;
  bool _arming = false;
  bool _wanted = false;
  final Queue<Uint8List> _chunks = Queue();
  int _total = 0; // bytes in _chunks
  int _dropped = 0; // bytes trimmed off the front
  int? _mark;

  static const rate = 16000; // 16 kHz mono 16-bit = 32,000 bytes a second
  static const bytesPerSec = rate * 2;
  static const leadIn = bytesPerSec * 7 ~/ 10; // 0.7 s before the press
  static const _keep = bytesPerSec * 30; // hold at most 30 s

  bool get live => _live;

  /// Opens the mic. False when it can't (no permission or no mic).
  Future<bool> arm() async {
    if (!enabled) return false;
    _wanted = true;
    if (_live) return true;
    if (_arming) return false;
    _arming = true;
    try {
      _rec ??= AudioRecorder();
      if (!await _rec!.hasPermission()) return false;
      final stream = await _rec!.startStream(const RecordConfig(
          encoder: AudioEncoder.pcm16bits, sampleRate: rate, numChannels: 1));
      _chunks.clear();
      _total = 0;
      _dropped = 0;
      _mark = null;
      _sub = stream.listen(_add);
      _live = true;
      if (!_wanted) {
        await disarm();
        return false;
      }
      return true;
    } catch (_) {
      _live = false;
      return false;
    } finally {
      _arming = false;
    }
  }

  void _add(Uint8List data) {
    _chunks.add(data);
    _total += data.length;
    // Don't trim past a press in progress
    while (_mark == null &&
        _chunks.isNotEmpty &&
        _total - _chunks.first.length > _keep) {
      final f = _chunks.removeFirst();
      _total -= f.length;
      _dropped += f.length;
    }
  }

  Future<void> disarm() async {
    _wanted = false;
    if (!enabled) return;
    _mark = null;
    final sub = _sub;
    _sub = null;
    _live = false;
    try {
      await sub?.cancel();
    } catch (_) {}
    try {
      await _rec?.stop();
    } catch (_) {}
    _chunks.clear();
    _total = 0;
  }

  void start() {
    if (!_live) return;
    final at = _dropped + _total - leadIn;
    _mark = at < _dropped ? _dropped : at;
  }

  /// The clip since start() as a WAV, or null when too short.
  Future<Uint8List?> stop() async {
    final mark = _mark;
    if (mark == null || !_live) return null;
    // A tail so the last word isn't cut (people let go as they finish)
    await Future.delayed(const Duration(milliseconds: 700));
    _mark = null;
    final from = (mark - _dropped).clamp(0, _total);
    final b = BytesBuilder(copy: false);
    var pos = 0;
    for (final c in _chunks) {
      final end = pos + c.length;
      if (end > from) b.add(pos >= from ? c : c.sublist(from - pos));
      pos = end;
    }
    var pcm = b.takeBytes();
    if (pcm.length.isOdd) pcm = pcm.sublist(0, pcm.length - 1);
    if (pcm.length < bytesPerSec ~/ 4) return null;
    return pcmToWav(pcm);
  }

  Future<void> dispose() async {
    if (!enabled) return;
    await disarm();
    try {
      await _rec?.dispose();
    } catch (_) {}
    _rec = null;
  }
}

// ------------------------------------------------------------- test data

/// A backend with no network: opens [stateData] and accepts every upload.
/// The page uses it when given testData; tests read [calls].
class SkMemoryBackend implements SkBackend {
  SkMemoryBackend(this.stateData, {this.ai = false, this.voiceAnswer});

  final Map<String, dynamic> stateData;
  final bool ai;
  final Map<String, dynamic>? voiceAnswer;
  final List<(String, dynamic)> calls = [];
  int _id = 900;

  @override
  String get uid => 'test-user';

  @override
  Future<Map<String, dynamic>?> state(int eventId) async {
    calls.add(('state', eventId));
    return stateData;
  }

  @override
  Future<bool> aiFeatures() async => ai;

  @override
  Future<void> upsertTimer(Map<String, dynamic> row) async =>
      calls.add(('timer', row));

  @override
  Future<Map<String, dynamic>?> upsertMatchStats(
      int eventId, String? opposition, int? squadId) async {
    calls.add(('upsert', opposition));
    return {'id': ++_id};
  }

  @override
  Future<Map<String, dynamic>?> sync(int id, List<Map<String, dynamic>> actions,
      Map<String, dynamic>? timer) async {
    calls.add(('sync', {'actions': actions, 'timer': timer}));
    return {
      'done': [for (final a in actions) a['id']]
    };
  }

  @override
  Future<void> finalise(int id) async => calls.add(('finalise', id));

  @override
  Future<Map<String, dynamic>?> reset(int id) async {
    calls.add(('reset', id));
    return {'id': ++_id};
  }

  @override
  Future<Map<String, dynamic>?> voice(Map<String, dynamic> body) async {
    calls.add(('voice', body));
    return voiceAnswer;
  }
}
