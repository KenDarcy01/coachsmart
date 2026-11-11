// v3 Score keeper: the match logic of webviews/score-keeper.html — loading,
// the clock and halves, every action, the outbox upload, and voice — with
// no widgets, so the page only draws it.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../match_stats/v3_match_stats_models.dart';
import 'sk_models.dart';
import 'sk_services.dart';
import 'sk_voice_parser.dart';

class SkToast {
  SkToast(this.msg, {this.action, this.onAction});
  final String msg;
  final String? action;
  final VoidCallback? onAction;
}

/// A result card under the mic.
class SkVCard {
  SkVCard(this.kind,
      {this.id,
      String? key,
      this.guess = false,
      required this.at,
      this.ms,
      this.onId,
      this.offId,
      this.onHeard = '',
      this.offHeard = '',
      this.subAt,
      this.text = ''})
      : key = key ?? skId();

  final String kind; // act | sub | subask | miss
  final String? id;
  final String key;
  final bool guess;
  final int at;
  final int? ms; // shown for this long; null = until dealt with
  final int? onId;
  final int? offId;
  final String onHeard;
  final String offHeard;
  final SkAt? subAt;
  final String text;
}

/// The setup form while it's being filled in.
class SkDraft {
  SkDraft(
      {required this.opp,
      this.squadId,
      this.dur = 1800,
      this.inj = 300,
      this.throwH,
      this.throwM,
      this.venue = '',
      this.otherDur = false});
  String opp;
  int? squadId;
  int dur;
  int inj;
  int? throwH;
  int? throwM;
  String venue;
  bool otherDur;
}

class _ServerError implements Exception {}

class SkController extends ChangeNotifier {
  SkController({
    required this.eventId,
    required this.backend,
    required this.store,
    this.device = const SkDevice(),
    SkMic? mic,
    this.now,
  }) : mic = mic ?? SkMic();

  final int eventId;
  final SkBackend backend;
  final SkStore store;
  final SkDevice device;
  final SkMic mic;

  /// Tests set the clock.
  final int Function()? now;
  int get nowMs => now?.call() ?? DateTime.now().millisecondsSinceEpoch;

  SkState? s;
  SkInfo? c;
  bool loading = true;

  /// (title, text) when the match can't be opened.
  (String, String)? fatal;
  bool fatalRetry = false;

  String view = 'score'; // score | stats
  String mode = 'tap'; // tap | voice
  bool voiceAllowed = false;
  String netState = 'ok'; // ok | offline | auth | error
  bool syncing = false;
  bool awakeWanted = true;
  bool foreground = true;

  void Function(SkToast t)? onToast;

  /// Ticks four times a second for the clock.
  final ValueNotifier<int> tick = ValueNotifier(0);

  /// The Start button pulses when someone taps before kick-off.
  final ValueNotifier<bool> pulseStart = ValueNotifier(false);

  /// Bumped when the page should scroll back to the top.
  final ValueNotifier<int> scrollTop = ValueNotifier(0);

  final Set<String> inFlight = {};
  Timer? _syncTimer;
  Timer? _tickTimer;
  Timer? _cardTimer;
  Timer? _pulseTimer;
  bool _syncAgain = false;
  int _backoff = 0;
  bool _single = false; // after a rejected batch, one at a time
  bool _shown = false;
  bool _disposed = false;

  String get _key => 'sk2:$eventId:${backend.uid}';
  String get _ckey => 'sk2c:$eventId:${backend.uid}';

  void _save() {
    if (s != null) store.set(_key, s!.toJson());
  }

  void _changed() {
    if (_disposed) return;
    _syncAudio();
    notifyListeners();
  }

  void toast(String msg, {String? action, VoidCallback? onAction}) =>
      onToast?.call(SkToast(msg, action: action, onAction: onAction));

  void _buzz(List<int> p) => device.buzz(p);

  // ------------------------------------------------------------- loading

  Future<void> boot() async {
    await store.init();
    keepAwake(true);
    s = SkState.fromJson(store.get(_key));
    final craw = store.get(_ckey);
    c = craw is Map ? SkInfo(craw) : null;
    if (s != null && c != null) _show(); // from the phone, even with no signal

    Map<String, dynamic>? srv;
    try {
      srv = await backend.state(eventId);
    } catch (e) {
      netState = _failName(classifyFail(e));
    }
    if (_disposed) return;
    if (srv != null && srv['error'] != null) {
      if (s == null) {
        fatal = (
          "Can't open this match",
          srv['error'] == 'event_not_found'
              ? 'The event was not found.'
              : 'Please close and open it again.'
        );
        loading = false;
        _changed();
        return;
      }
      srv = null;
    }
    if (srv != null) {
      _takeInfo(srv);
      final ses = srv['session'] is Map ? srv['session'] as Map : null;
      final sesId = ses == null ? null : int.tryParse('${ses['id']}');
      final cur = s;
      if (cur == null) {
        s = stateFromServer(srv);
      } else if (cur.sessionId != null && sesId == cur.sessionId) {
        final m = mergeWithOutbox(mapServerActs(srv['actions']),
            mapServerSubs(srv['subs']), cur.out, nowMs);
        cur.acts = m.$1;
        cur.subs = m.$2;
        if (ses!['status'] == 'finalised' && !cur.isFinal) {
          cur.isFinal = true;
          cur.finalisePending = false;
          cur.phase = 'done';
        }
      } else if (cur.sessionId != null &&
          sesId != cur.sessionId &&
          cur.out.isEmpty) {
        // Reset or restarted somewhere else: go with the server
        s = stateFromServer(srv);
      }
      // else: this phone has a match the server hasn't seen yet; keep it
    } else if (s == null || c == null) {
      fatal = (
        'No signal',
        'The score keeper needs signal the first time it opens a match. Once open, it keeps working without signal.'
      );
      fatalRetry = true;
      loading = false;
      _changed();
      return;
    }
    _save();
    _show();
    kickSync(0);
  }

  Future<void> retry() async {
    fatal = null;
    fatalRetry = false;
    loading = true;
    _changed();
    await boot();
  }

  void _takeInfo(Map srv) {
    final raw = SkInfo.pick(srv);
    c = SkInfo(raw);
    store.set(_ckey, raw);
  }

  Future<void> _refreshInfo() async {
    try {
      final srv = await backend.state(eventId);
      if (srv != null && srv['error'] == null && !_disposed) {
        _takeInfo(srv);
        _changed();
      }
    } catch (_) {}
  }

  void _show() {
    loading = false;
    if (!_shown) {
      _shown = true;
      _tickTimer =
          Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
      _cardTimer = Timer.periodic(
          const Duration(milliseconds: 500), (_) => _pruneCards());
      voiceAllowed = store.get('sk2aiflag') == true;
      if (voiceAllowed && store.get('sk2mode') == 'voice') mode = 'voice';
      // Voice is parked for now (Ken, 2026-10-16): only AI-feature accounts
      // see it, to test.
      backend.aiFeatures().then((v) {
        voiceAllowed = v;
        store.set('sk2aiflag', v);
        if (!v && mode == 'voice') mode = 'tap';
        _changed();
      }).catchError((_) {});
    }
    _changed();
  }

  // --------------------------------------------------------------- names

  String get us => c == null ? 'Us' : usName(c!);
  String get opp => c == null ? 'Opposition' : oppName(s, c!);
  int get halfLen => s?.halfLen ?? 1800;
  String minute(int half, int sec) => minuteFor(halfLen, half, sec);
  int get sec => s == null ? 0 : secInHalf(s!, nowMs);
  bool get isStarted => s != null && started(s!, nowMs);
  MatchModel model() => skMatchModel(s!, c!, nowMs);
  Walk totals() => walk(model());
  Map<int, SkPlayer> get players => roster(s, c!);
  String nameOf(int? id) => memberName(s, c!, id);

  // ---------------------------------------------------------------- clock

  void _timerChanged() {
    s!.timerVer++;
    _save();
    kickSync(400);
    _changed();
  }

  void startClock() {
    final st = s!;
    if (st.clock.run) return;
    st.clock.run = true;
    st.clock.startedAt = nowMs;
    _timerChanged();
  }

  void pauseClock() {
    final st = s!;
    if (!st.clock.run) return;
    st.clock.banked = (st.clock.banked + (nowMs - st.clock.startedAt!) / 1000)
        .roundToDouble();
    st.clock.run = false;
    st.clock.startedAt = null;
    _timerChanged();
  }

  /// cap: when injury time ran out, the half ends at half length + injury.
  void endHalf([int? cap]) {
    final st = s!;
    final now = secInHalf(st, nowMs);
    final sec = cap != null && cap < now ? cap : now;
    if (st.clock.run) {
      st.clock.banked = sec.toDouble();
      st.clock.run = false;
      st.clock.startedAt = null;
    }
    st.clock.ended[st.clock.half] = sec;
    st.phase = st.clock.half == 1 ? 'ht' : 'ft';
    _timerChanged();
    device.sound(st.phase == 'ht' ? SkSound.halfTime : SkSound.fullTime,
        micOpen: mic.live);
    _buzz([200, 100, 200]);
    view = 'score';
    scrollTop.value++;
    _changed();
  }

  void backToClock() {
    final st = s!;
    st.clock.ended.remove(st.clock.half);
    st.phase = 'play';
    _timerChanged();
  }

  void startSecondHalf() {
    final st = s!;
    st.clock.half = 2;
    st.clock.banked = 0;
    st.clock.run = true;
    st.clock.startedAt = nowMs;
    st.phase = 'play';
    _timerChanged();
    scrollTop.value++;
  }

  void finishMatch() {
    s!.phase = 'done';
    s!.finalisePending = true;
    _save();
    _changed();
    kickSync(0);
  }

  void _tick() {
    final st = s;
    if (st != null && st.phase == 'play') {
      final sec = secInHalf(st, nowMs), dur = st.halfLen, inj = st.injLen;
      final h = st.clock.half;
      final al = st.clock.alarmed;
      if (st.clock.run &&
          inj > 0 &&
          sec >= dur &&
          sec < dur + inj &&
          !al.contains('${h}a')) {
        al.add('${h}a');
        _save();
        device.sound(SkSound.injury, micOpen: mic.live);
        _buzz([300, 120, 300]);
        toast('${(dur / 60).round()} minutes up. Injury time now.');
      }
      // Injury time is the most per half: when it's up the half ends by
      // itself (also when the phone was closed and opened long after)
      if (st.clock.run && dur > 0 && sec >= dur + inj) {
        al.add('${h}b');
        endHalf(dur + inj);
        toast(h == 1
            ? "Injury time's up. Half time."
            : "Injury time's up. Full time.");
        return;
      }
    }
    tick.value++;
  }

  void notStarted() {
    _buzz([40, 60, 40]);
    toast('Start the ${s!.clock.half == 1 ? '1st' : '2nd'} half first');
    pulseStart.value = true;
    _pulseTimer?.cancel();
    _pulseTimer = Timer(
        const Duration(milliseconds: 1600), () => pulseStart.value = false);
  }

  // -------------------------------------------------------------- actions

  void _commit() {
    _save();
    kickSync(300);
    _changed();
  }

  SkAt stamp() => nowStamp(s!, nowMs);

  void tapScore(int st, String side) {
    if (!isStarted) return notStarted();
    final a = addScore(s!, st, side, stamp(), nowMs);
    _buzz([15]);
    _commit();
    final t = c!.typeById(st);
    toast(
        '${t.name} for ${side == 'us' ? us : opp} at ${minute(a.half, a.sec)}',
        action: 'Undo', onAction: () {
      removeAct(s!, a.id, inFlight);
      _commit();
    });
  }

  /// Press and hold: take the last one off.
  void takeOneOff(int st, String side) {
    if (!isStarted) return notStarted();
    final list = s!.acts
        .where((a) => a.st == st && a.side == side && a.k == 'score')
        .toList()
      ..sort((a, b) => b.ts - a.ts);
    final t = c!.typeById(st);
    if (list.isEmpty) {
      toast('No ${t.name.toLowerCase()} to take off');
      return;
    }
    final last = list.first;
    removeAct(s!, last.id, inFlight);
    _buzz([40, 60, 40]);
    _commit();
    toast('Took off a ${t.name.toLowerCase()} for ${side == 'us' ? us : opp}',
        action: 'Undo', onAction: () {
      restoreAct(s!, last, nowMs);
      _commit();
    });
  }

  SkAct? get lastScore {
    final l = s!.acts.where((a) => a.k == 'score').toList()
      ..sort((a, b) => b.ts - a.ts);
    return l.firstOrNull;
  }

  void undoLast() {
    final last = lastScore;
    if (last == null) return;
    removeAct(s!, last.id, inFlight);
    _commit();
    toast('Removed: ${actLabel(s!, c!, last).$1}', action: 'Undo',
        onAction: () {
      restoreAct(s!, last, nowMs);
      _commit();
    });
  }

  void editActs(List<String> ids, Map<String, Object?> ch) {
    for (final id in ids) {
      editAct(s!, c!, id, ch, inFlight);
    }
    _commit();
  }

  SkAct copyAct(SkAct a) {
    final b = restoreAct(s!, a, nowMs);
    _buzz([15]);
    _commit();
    return b;
  }

  void dropAct(String id, {bool buzz = true}) {
    removeAct(s!, id, inFlight);
    if (buzz) _buzz([15]);
    _commit();
  }

  void deleteAct(String id) {
    final gone = removeAct(s!, id, inFlight);
    _commit();
    if (gone == null) return;
    toast('Removed: ${actLabel(s!, c!, gone).$1}', action: 'Undo',
        onAction: () {
      restoreAct(s!, gone, nowMs);
      _commit();
    });
  }

  SkSub makeSub(int off, int on, SkAt at) {
    final x = addSub(s!, off, on, at, nowMs);
    _commit();
    final r = players;
    toast('Sub: ${r[on]?.short ?? '?'} on for ${r[off]?.short ?? '?'}',
        action: 'Undo', onAction: () {
      removeSub(s!, x.id, inFlight);
      _commit();
    });
    return x;
  }

  void deleteSub(String id, {bool quiet = false}) {
    removeSub(s!, id, inFlight);
    _commit();
    if (!quiet) toast('Sub removed');
  }

  void markChecked() {
    s!.checked[s!.phase == 'ht' ? 1 : 2] = true;
    _save();
    _changed();
  }

  /// Sets the score to the ref's: score checks for the difference.
  void saveCorrection(Walk rec, int usG, int usP, int oppG, int oppP) {
    final st = s!, g = c!.goalType!, p = c!.pointType!;
    var changed = 0;
    final at = stamp();
    void add(SkType t, String side, int d) {
      if (d == 0) return;
      addCorrection(st, t.id, side, d, at, nowMs);
      changed++;
    }

    add(g, 'us', usG - rec.usG);
    add(p, 'us', usP - rec.usP);
    add(g, 'opp', oppG - rec.oppG);
    add(p, 'opp', oppP - rec.oppP);
    if (st.phase == 'ht') st.checked[1] = true;
    if (st.phase == 'ft') st.checked[2] = true;
    _commit();
    toast(changed > 0 ? "Score set to the ref's" : 'No change');
  }

  // ---------------------------------------------------------------- setup

  SkDraft draft() {
    final st = s?.setup;
    final t = hhmm(st?.throwAt);
    return SkDraft(
      opp: st != null ? st.opp : c!.eventOpposition,
      squadId: st?.squadId,
      dur: st?.dur ?? 1800,
      inj: st?.inj ?? 300,
      throwH: t?.$1,
      throwM: t?.$2,
      venue: st?.venue ?? '',
    );
  }

  /// False when the opposition is missing.
  bool applySetup(SkDraft d) {
    final o = d.opp.trim();
    if (o.isEmpty) {
      toast('Add the opposition first');
      return false;
    }
    final st = s!;
    final wasFinal = st.phase == 'done';
    final throwAt = throwIso(c!.eventDateTime, d.throwH, d.throwM);
    final venue = d.venue.trim();
    st.setup = SkSetup(
        opp: o,
        squadId: d.squadId,
        dur: d.dur,
        inj: d.inj,
        throwAt: throwAt,
        venue: venue,
        extra:
            throwAt != null || venue.isNotEmpty || (st.setup?.extra ?? false));
    if (st.phase == 'setup') st.phase = 'play';
    if (!wasFinal) st.needSetup = true;
    _timerChanged();
    scrollTop.value++;
    return true;
  }

  Future<void> resetMatch(bool again) async {
    final st = s!;
    if (st.sessionId != null) {
      toast('Resetting…');
      while (syncing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      try {
        final r = again
            ? await backend.upsertMatchStats(
                eventId,
                (st.setup?.opp ?? '').isEmpty ? null : st.setup!.opp,
                st.setup?.squadId)
            : await backend.reset(st.sessionId!);
        final id = r == null ? null : int.tryParse('${r['id']}');
        if (id == null) throw _ServerError();
        s = SkState(setup: st.setup)
          ..sessionId = id
          ..timerVer = 1;
      } catch (e) {
        toast(classifyFail(e) == SkFail.offline && e is! _ServerError
            ? 'Reset needs signal. Try again when you have it.'
            : "Couldn't reset. Please try again.");
        return;
      }
    } else {
      s = SkState(setup: st.setup)..needSetup = st.needSetup;
    }
    keepAwake(true);
    _save();
    _changed();
    kickSync(0);
    toast(again ? 'New record started' : 'Match reset');
  }

  // ---------------------------------------------------------------- views

  void setView(String v) {
    view = v;
    scrollTop.value++;
    _changed();
  }

  void setMode(String m) {
    mode = m;
    store.set('sk2mode', m);
    _changed();
  }

  void keepAwake(bool on) {
    awakeWanted = on;
    device.keepAwake(on);
    if (_shown) _changed();
  }

  void toggleAwake() {
    keepAwake(!awakeWanted);
    toast(awakeWanted ? 'Screen stays on' : 'Screen can sleep now');
  }

  void setForeground(bool fg) {
    foreground = fg;
    if (!fg) {
      _save();
      _syncAudio();
      return;
    }
    if (awakeWanted) device.keepAwake(true);
    kickSync(0);
    _changed();
  }

  /// Back: save, give the outbox a moment to upload, let the screen sleep.
  Future<void> leave() async {
    _save();
    if ((s?.pending ?? 0) > 0) {
      kickSync(0);
      await Future.delayed(const Duration(milliseconds: 1500));
    }
    await device.keepAwake(false);
  }

  // --------------------------------------------------------------- upload

  void kickSync([int delay = 0]) {
    _syncTimer?.cancel();
    if (_disposed) return;
    _syncTimer = Timer(Duration(milliseconds: delay), sync);
  }

  void syncNow() {
    netState = 'ok';
    _backoff = 0;
    kickSync(0);
  }

  static String _failName(SkFail f) => switch (f) {
        SkFail.offline => 'offline',
        SkFail.auth => 'auth',
        _ => 'error',
      };

  Future<void> _serverSetup() async {
    final st = s!, su = st.setup!;
    await backend.upsertTimer({
      'event_id': eventId,
      'user_id': backend.uid,
      'opposition': su.opp.isEmpty ? null : su.opp,
      'squad_id': su.squadId,
      'duration_seconds': su.dur,
      'injury_seconds': su.inj,
      'current_half': st.clock.half,
      // A squad's own throw-in time and venue (shown on the live link);
      // only sent once set
      if (su.throwAt != null || su.venue.isNotEmpty || su.extra) ...{
        'throw_in_at': su.throwAt,
        'venue': su.venue.isEmpty ? null : su.venue,
      },
    });
    final r = await backend.upsertMatchStats(
        eventId, su.opp.isEmpty ? null : su.opp, su.squadId);
    final id = r == null ? null : int.tryParse('${r['id']}');
    if (id == null) throw _ServerError();
    st.sessionId = id;
    st.needSetup = false;
    st.timerVer++;
    _save();
    _refreshInfo(); // line-up may depend on the squad picked
  }

  Future<void> sync() async {
    if (s == null || _disposed) return;
    if (syncing) {
      _syncAgain = true;
      return;
    }
    syncing = true;
    _changed();
    try {
      if (s!.needSetup && s!.setup != null) await _serverSetup();
      while (s!.sessionId != null &&
          (s!.out.isNotEmpty || s!.timerVer != s!.timerSent)) {
        final st = s!;
        final batch = st.out.take(_single ? 1 : 40).toList();
        final ver = st.timerVer;
        for (final o in batch) {
          inFlight.add('${o['id']}');
        }
        Map<String, dynamic>? res;
        try {
          res = await backend.sync(st.sessionId!, batch,
              ver != st.timerSent ? timerPayload(st, DateTime.now()) : null);
        } catch (e) {
          // A batch the server can't read: find the bad entry, set it aside
          if (classifyFail(e) == SkFail.bad) {
            if (!_single && batch.length > 1) {
              _single = true;
              continue;
            }
            if (batch.length == 1) {
              st.out.removeWhere((o) => o['id'] == batch[0]['id']);
              st.rejected = [...st.rejected, batch[0]];
              if (st.rejected.length > 20) {
                st.rejected = st.rejected.sublist(st.rejected.length - 20);
              }
              _save();
              continue;
            }
          }
          rethrow;
        } finally {
          for (final o in batch) {
            inFlight.remove('${o['id']}');
          }
        }
        final done = <String>{
          if (res?['done'] is List)
            for (final d in res!['done'] as List) '$d'
        };
        st.out.removeWhere((o) => done.contains('${o['id']}'));
        st.timerSent = ver;
        if (_single && st.out.isEmpty) _single = false;
        _save();
      }
      final st = s!;
      if (st.finalisePending &&
          st.sessionId != null &&
          st.out.isEmpty &&
          st.timerVer == st.timerSent) {
        await backend.finalise(st.sessionId!);
        st.finalisePending = false;
        st.isFinal = true;
        _save();
        keepAwake(false);
      }
      netState = 'ok';
      _backoff = 0;
    } catch (e) {
      netState = e is _ServerError ? 'error' : _failName(classifyFail(e));
      _backoff = _backoff == 0 ? 3000 : (_backoff * 2).clamp(0, 30000);
      kickSync(_backoff);
    } finally {
      syncing = false;
      _changed();
      if (_syncAgain) {
        _syncAgain = false;
        kickSync(0);
      }
    }
  }

  // ----------------------------------------------------------------- voice

  List<SkVCard> vcards = [];
  String vheard = '';
  String lastBy = '';
  bool aiVoice = true; // false once the server says no AI on this account
  late bool aiWanted = store.get('sk2ai') != 'off'; // test switch (Ken)

  /// off | arming | on | none (the mic can't stay open)
  String audioState = 'off';
  SkAt? _audioPress;

  /// idle | recording | working
  String micUi = 'idle';

  String get _aliasKey => 'sk2a:${c?.teamId ?? 0}';

  Map<String, int> get _aliases {
    final al = store.get(_aliasKey);
    return {
      if (al is Map)
        for (final e in al.entries)
          if (int.tryParse('${e.value}') != null)
            '${e.key}': int.parse('${e.value}')
    };
  }

  /// Spoken name -> player, saved per team on this phone.
  void rememberName(String? heard, int? mem) {
    if (heard == null || heard.isEmpty || heard.startsWith('#')) return;
    final al = _aliases;
    final k = voiceNorm(heard);
    if (mem != null) {
      al[k] = mem;
    } else {
      al.remove(k);
    }
    store.set(_aliasKey, al);
  }

  List<VoicePlayer> _voicePlayers() {
    final r = players;
    // Line-up and squad first, then the rest of the team, so a name said is
    // always matched
    return [
      for (final p in r.values)
        VoicePlayer(
            memberId: p.id,
            firstName: p.first,
            lastName: p.last,
            number: p.number),
      for (final p in c!.players)
        if (!r.containsKey(p.memberId))
          VoicePlayer(
              memberId: p.memberId, firstName: p.first, lastName: p.last),
    ];
  }

  VoiceCtx voiceCtx() => VoiceCtx(
        types: [
          for (final t in c!.types)
            VoiceType(
                id: t.id,
                name: t.name,
                abbr: t.abbr,
                value: t.value,
                source: t.source)
        ],
        usName: '$us ${c!.clubName} ${c!.teamName}',
        oppName: opp,
        players: _voicePlayers(),
        aliases: _aliases,
      );

  void toggleAi() {
    aiWanted = !aiWanted;
    store.set('sk2ai', aiWanted ? 'on' : 'off');
    _changed();
    toast(aiWanted
        ? 'AI reading on: Gemini works out what you meant'
        : 'AI reading off: the phone reads your words on its own');
  }

  bool get _wantAudio =>
      voiceAllowed &&
      aiWanted &&
      aiVoice &&
      mode == 'voice' &&
      s?.phase == 'play' &&
      view == 'score' &&
      foreground &&
      !_disposed;

  void _syncAudio() {
    if (audioState == 'none') return;
    final want = _wantAudio;
    if (want && audioState == 'off') {
      audioState = 'arming';
      mic.arm().then((ok) {
        if (audioState != 'arming') {
          if (ok && audioState == 'off') mic.disarm();
          return;
        }
        audioState = ok ? 'on' : 'none';
        if (!ok) {
          toast(
              "Couldn't keep the mic open, so it starts on each press instead");
        }
        _changed();
      });
    } else if (!want && (audioState == 'on' || audioState == 'arming')) {
      audioState = 'off';
      mic.disarm();
    }
  }

  /// The always-on mic takes the press. False = use dictation instead.
  bool audioDown() {
    if (audioState != 'on') return false;
    if (_audioPress != null) return true;
    if (!isStarted) {
      notStarted();
      return true;
    }
    _audioPress = stamp();
    mic.start();
    micUi = 'recording';
    vheard = '';
    _buzz([10]);
    _changed();
    return true;
  }

  Future<void> audioUp() async {
    final p = _audioPress;
    if (p == null) return;
    _audioPress = null;
    micUi = 'working';
    _changed();
    Uint8List? wav;
    try {
      wav = await mic.stop();
    } catch (_) {}
    if (wav == null) {
      micUi = 'idle';
      _changed();
      toast('Too short. Hold the mic while you talk.');
      return;
    }
    Map<String, dynamic>? d;
    try {
      d = await _voiceRequest({'audio': base64Encode(wav)})
          .timeout(const Duration(seconds: 9));
    } catch (_) {}
    micUi = 'idle';
    if (d == null) {
      _changed();
      toast(netState == 'offline'
          ? 'No signal for voice. Use Tap for now.'
          : "Couldn't make that out. Try again.");
      return;
    }
    final res = _mapAi(d);
    lastBy = 'AI (listening)';
    applyVoice(res, res.transcript.isEmpty ? '…' : res.transcript, p);
  }

  /// Dictated words (the phone's own speech engine).
  Future<void> handleVoiceText(String text, SkAt? at) async {
    at ??= stamp();
    text = text.trim();
    if (text.isEmpty) {
      micUi = 'idle';
      _changed();
      toast("Didn't hear anything. Hold the mic while you talk.");
      return;
    }
    if (!isStarted) {
      micUi = 'idle';
      _changed();
      return notStarted();
    }
    micUi = 'working';
    vheard = '"$text" · working it out…';
    _changed();
    final ai = await _aiParse(text);
    lastBy = ai != null ? 'AI' : 'phone';
    micUi = 'idle';
    applyVoice(ai ?? parseVoice(text, voiceCtx()), text, at);
  }

  Future<VoiceResult?> _aiParse(String text) async {
    if (!aiWanted || !aiVoice || netState == 'offline') return null;
    try {
      final d = await _voiceRequest({'text': text})
          .timeout(const Duration(seconds: 4));
      return d == null ? null : _mapAi(d);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _voiceRequest(
      Map<String, dynamic> extra) async {
    final ctx = voiceCtx();
    try {
      return await backend.voice({
        'event_id': eventId,
        'us': us,
        'opp': opp,
        'aliases': ctx.aliases,
        'types': [
          for (final t in c!.types)
            {'id': t.id, 'name': t.name, 'value': t.value, 'source': t.source}
        ],
        'players': [
          for (final p in ctx.players)
            {
              'id': p.memberId,
              'name': '${p.firstName} ${p.lastName}'.trim(),
              'number': p.number
            }
        ],
        ...extra,
      });
    } on SkNoAi {
      // No AI on this account: on-phone only
      aiVoice = false;
      _changed();
      return null;
    }
  }

  VoiceResult _mapAi(Map d) {
    int? id(dynamic v) => v == null ? null : int.tryParse('$v');
    return VoiceResult([
      for (final it in (d['items'] is List ? d['items'] as List : []))
        if (it is Map)
          it['kind'] == 'sub'
              ? VoiceItem.sub(
                  onId: id(it['on_id']),
                  offId: id(it['off_id']),
                  onHeard: nameOf(id(it['on_id'])),
                  offHeard: nameOf(id(it['off_id'])))
              : VoiceItem.score(
                  typeId: id(it['type_id']) ?? 0,
                  typeName: c!.typeById(id(it['type_id']) ?? 0).name,
                  count: id(it['count']) ?? 1,
                  side: it['side'] == 'us' || it['side'] == 'opp'
                      ? it['side'] as String
                      : null,
                  memberId: it['unsure'] == true ? null : id(it['member_id']),
                  heard: '${it['heard'] ?? ''}',
                  ask: it['unsure'] == true
                      ? [if (id(it['member_id']) != null) id(it['member_id'])!]
                      : null,
                  fromId: id(it['from_id'])),
    ], [
      for (final u in (d['unknown'] is List ? d['unknown'] as List : [])) '$u'
    ], transcript: '${d['transcript'] ?? ''}');
  }

  void applyVoice(VoiceResult res, String text, SkAt at) {
    vheard = text;
    final now = nowMs;
    final cards = <SkVCard>[];
    for (final it in res.items) {
      if (it.kind == 'sub') {
        if (it.onId != null && it.offId != null) {
          final x = addSub(s!, it.offId!, it.onId!, at, now);
          cards.add(SkVCard('sub', id: x.id, at: now, ms: 9000));
        } else {
          cards.add(SkVCard('subask',
              onId: it.onId,
              offId: it.offId,
              onHeard: it.onHeard,
              offHeard: it.offHeard,
              at: now,
              subAt: at));
        }
        continue;
      }
      // No questions while the coach is watching: no team named means us,
      // an unsure name goes to the best guess (remembered for next time)
      // with a "?" on the card.
      final side = it.side ?? 'us';
      final scoring = c!.typeById(it.typeId).scoring;
      // Our player on their side only for a non-score he gave away
      final named = side == 'us' || !scoring;
      var mem = named ? it.memberId : null;
      var guess = false;
      if (named && mem == null && (it.ask?.isNotEmpty ?? false)) {
        mem = it.ask!.first;
        guess = true;
        rememberName(it.heard, mem);
      }
      for (var i = 0; i < it.count; i++) {
        final a = addScore(s!, it.typeId, side, at, now,
            mem: mem, fr: scoring ? it.fromId : null);
        if (named && it.heard.isNotEmpty) a.heard = it.heard;
        cards.add(SkVCard('act',
            id: a.id, guess: guess, at: now, ms: guess ? 7000 : 6000));
      }
    }
    for (final u in res.unknown) {
      cards.add(SkVCard('miss', text: u, at: now, ms: 9000));
    }
    if (res.items.isEmpty && res.unknown.isEmpty) {
      cards.add(SkVCard('miss', text: text, at: now, ms: 9000));
    }
    vcards =
        [...cards, ...vcards.where((x) => x.kind == 'subask')].take(4).toList();
    _buzz([20]);
    _commit();
  }

  void dropCard(SkVCard card) {
    vcards = vcards.where((x) => x != card).toList();
    if (vcards.isEmpty) vheard = '';
    _changed();
  }

  void _pruneCards() {
    if (vcards.isEmpty) return;
    final now = nowMs;
    final keep =
        vcards.where((x) => x.ms == null || now - x.at < x.ms!).toList();
    if (keep.length != vcards.length) {
      vcards = keep;
      if (vcards.isEmpty) vheard = '';
      _changed();
    }
  }

  void setMicUi(String v) {
    micUi = v;
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    _save();
    _syncTimer?.cancel();
    _tickTimer?.cancel();
    _cardTimer?.cancel();
    _pulseTimer?.cancel();
    mic.dispose();
    device.keepAwake(false);
    tick.dispose();
    pulseStart.dispose();
    scrollTop.dispose();
    super.dispose();
  }
}
