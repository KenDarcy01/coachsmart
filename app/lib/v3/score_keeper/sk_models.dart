// v3 Score keeper: the data side of webviews/score-keeper.html, as pure
// functions so tests run without a network.
//
// Phone first: every tap is saved on the phone straight away and put in an
// outbox. The outbox uploads in batches (sync_match_actions) whenever there
// is signal. Each entry carries an id made here (client_id on the server),
// so an upload that is retried never makes a duplicate.
//
// SkState is the match as this phone knows it (the page's S); SkInfo is the
// read-only match info from get_score_keeper_state (the page's C).
import 'dart:math' as math;

import 'package:uuid/uuid.dart';

import '../match_stats/v3_match_stats_models.dart';

const _uuid = Uuid();
String skId() => _uuid.v4();

int _int(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) {
    return int.tryParse(v) ?? num.tryParse(v)?.toInt() ?? fallback;
  }
  return fallback;
}

int? _intOrNull(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? num.tryParse(v)?.toInt();
  return null;
}

double _double(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

String _str(dynamic v) => v == null ? '' : v.toString();

int? _epochMs(dynamic iso) {
  if (iso == null) return null;
  return DateTime.tryParse(iso.toString())?.millisecondsSinceEpoch;
}

// ------------------------------------------------------------------ info

class SkType {
  SkType(
      {required this.id,
      required this.name,
      this.abbr = '',
      this.value,
      this.source = false,
      this.button = true});

  final int id;
  final String name;
  final String abbr;
  final int? value;
  final bool source;

  /// False = voice only (not linked to the team's buttons).
  final bool button;

  bool get scoring => (value ?? 0) > 0;

  factory SkType.fromJson(Map j) => SkType(
        id: _int(j['id']),
        name: _str(j['score_type']).isEmpty ? 'Score' : _str(j['score_type']),
        abbr: _str(j['abbreviated_name']),
        value: _intOrNull(j['score_value']),
        source: j['source'] == true,
        button: j['button'] != false,
      );

  static SkType unknown(int id) => SkType(id: id, name: 'Score');
}

class SkSquad {
  SkSquad(this.id, this.name);
  final int id;
  final String name;
}

class SkLineupPlayer {
  SkLineupPlayer(this.memberId, this.number, this.isSub, this.first, this.last);
  final int memberId;
  final int? number;
  final bool isSub;
  final String first;
  final String last;
}

class SkTeamPlayer {
  SkTeamPlayer(this.memberId, this.first, this.last, this.squads);
  final int memberId;
  final String first;
  final String last;
  final List<int> squads;
}

/// The read-only match info (get_score_keeper_state minus the live parts).
class SkInfo {
  SkInfo(this.raw)
      : event = raw['event'] is Map ? raw['event'] as Map : const {},
        squads = [
          for (final s in (raw['squads'] is List ? raw['squads'] as List : []))
            if (s is Map) SkSquad(_int(s['squad_id']), _str(s['squad_name']))
        ],
        types = [
          for (final t
              in (raw['score_types'] is List ? raw['score_types'] as List : []))
            if (t is Map) SkType.fromJson(t)
        ],
        lineup = [
          if (raw['lineup'] is Map && raw['lineup']['players'] is List)
            for (final p in raw['lineup']['players'] as List)
              if (p is Map)
                SkLineupPlayer(
                    _int(p['member_id']),
                    _intOrNull(p['number']),
                    p['is_sub'] == true,
                    _str(p['first_name']),
                    _str(p['last_name']))
        ],
        players = [
          for (final p
              in (raw['players'] is List ? raw['players'] as List : []))
            if (p is Map)
              SkTeamPlayer(_int(p['member_id']), _str(p['first_name']),
                  _str(p['last_name']), [
                for (final s in (p['squads'] is List ? p['squads'] : []))
                  _int(s)
              ])
        ];

  /// What is stored on the phone, so it opens with no signal.
  final Map raw;
  final Map event;
  final List<SkSquad> squads;
  final List<SkType> types;
  final List<SkLineupPlayer> lineup;
  final List<SkTeamPlayer> players;

  static Map<String, dynamic> pick(Map srv) => {
        'event': srv['event'] ?? {},
        'is_member': srv['is_member'] == true,
        'squads': srv['squads'] ?? [],
        'score_types': srv['score_types'] ?? [],
        'lineup': srv['lineup'],
        'players': srv['players'] ?? [],
      };

  int get teamId => _int(event['team_id']);
  String get teamName => _str(event['team_name']);
  String get clubName => _str(event['club_name']);
  String get eventOpposition => _str(event['opposition']);
  String get eventDateTime => _str(event['event_date_time']);
  String get eventCode => _str(event['event_code']);
  String get eventType => _str(event['event_type']);

  SkType typeById(int id) =>
      types.where((t) => t.id == id).firstOrNull ?? SkType.unknown(id);

  /// Tap shows only the team's buttons; voice can record any stat.
  List<SkType> get btnTypes => types.where((t) => t.button).toList();
  List<SkType> get sourceTypes => types.where((t) => t.source).toList();
  SkType? get goalType => types.where((t) => t.value == 3).firstOrNull;
  SkType? get pointType => types.where((t) => t.value == 1).firstOrNull;

  /// Scores first (goal, point, then the rest by value), then the other
  /// stats in their own order.
  List<SkType> get padTypes {
    final big = btnTypes.where((t) => t.scoring).toList();
    int rank(SkType t) => t.value == 3
        ? 0
        : t.value == 1
            ? 1
            : 2;
    big.sort((a, b) {
      final r = rank(a) - rank(b);
      return r != 0 ? r : (b.value ?? 0) - (a.value ?? 0);
    });
    return [...big, ...btnTypes.where((t) => !t.scoring)];
  }
}

String cleanClub(String n) => n
    .replaceAll(
        RegExp(r'\b(GAA|GFC|CLG|HC|LGFA|Camogie Club)\b', caseSensitive: false),
        '')
    .replaceAll(RegExp(r'\s{2,}'), ' ')
    .trim();

// ----------------------------------------------------------------- state

class SkSetup {
  SkSetup(
      {required this.opp,
      this.squadId,
      this.dur = 1800,
      this.inj = 300,
      this.throwAt,
      this.venue = '',
      this.extra = false});

  final String opp;
  final int? squadId;
  final int dur;
  final int inj;
  final String? throwAt; // ISO
  final String venue;

  /// A throw-in time or venue was set at some point, so keep sending them.
  final bool extra;

  Map<String, dynamic> toJson() => {
        'opp': opp,
        'squadId': squadId,
        'dur': dur,
        'inj': inj,
        'throwAt': throwAt,
        'venue': venue,
        'extra': extra,
      };

  factory SkSetup.fromJson(Map j) => SkSetup(
        opp: _str(j['opp']),
        squadId: _intOrNull(j['squadId']),
        dur: _int(j['dur'], 1800) > 0 ? _int(j['dur'], 1800) : 1800,
        inj: j['inj'] == null ? 300 : _int(j['inj']),
        throwAt: j['throwAt'] == null ? null : _str(j['throwAt']),
        venue: _str(j['venue']),
        extra: j['extra'] == true,
      );
}

class SkClock {
  bool run = false;
  int? startedAt; // ms since epoch
  double banked = 0; // seconds banked in this half
  int half = 1;
  Map<int, int> ended = {};
  Set<String> alarmed = {};

  Map<String, dynamic> toJson() => {
        'run': run,
        'startedAt': startedAt,
        'banked': banked,
        'half': half,
        'ended': {for (final e in ended.entries) '${e.key}': e.value},
        'alarmed': alarmed.toList(),
      };

  static SkClock fromJson(Map j) => SkClock()
    ..run = j['run'] == true
    ..startedAt = _intOrNull(j['startedAt'])
    ..banked = _double(j['banked'])
    ..half = _int(j['half'], 1) == 2 ? 2 : 1
    ..ended = {
      if (j['ended'] is Map)
        for (final e in (j['ended'] as Map).entries) _int(e.key): _int(e.value)
    }
    ..alarmed = {
      if (j['alarmed'] is List)
        for (final a in j['alarmed'] as List) _str(a)
    };
}

/// One entry: a score or other stat ('score'), or a score check
/// ('correction', carrying +/- n).
class SkAct {
  SkAct(
      {required this.id,
      required this.k,
      required this.st,
      required this.side,
      required this.sec,
      required this.half,
      this.run = false,
      this.mem,
      this.fr,
      this.n = 1,
      required this.ts,
      this.heard});

  final String id;
  final String k;
  int st;
  String side;
  final int sec;
  final int half;
  final bool run;
  int? mem;
  int? fr;
  final int n;
  final int ts;

  /// The name voice heard, so a fix in the edit sheet is remembered.
  String? heard;

  bool get isCorrection => k == 'correction';

  SkAct copyAs(String newId, int newTs) => SkAct(
      id: newId,
      k: k,
      st: st,
      side: side,
      sec: sec,
      half: half,
      run: run,
      mem: mem,
      fr: fr,
      n: n,
      ts: newTs,
      heard: heard);

  Map<String, dynamic> toJson() => {
        'id': id,
        'k': k,
        'st': st,
        'side': side,
        'sec': sec,
        'half': half,
        'run': run,
        'mem': mem,
        'fr': fr,
        'n': n,
        'ts': ts,
        if (heard != null) 'heard': heard,
      };

  factory SkAct.fromJson(Map j) => SkAct(
        id: _str(j['id']),
        k: _str(j['k']) == 'correction' ? 'correction' : 'score',
        st: _int(j['st']),
        side: _str(j['side']) == 'opp' ? 'opp' : 'us',
        sec: _int(j['sec']),
        half: _int(j['half'], 1),
        run: j['run'] == true,
        mem: _intOrNull(j['mem']),
        fr: _intOrNull(j['fr']),
        n: j['n'] == null ? 1 : _int(j['n'], 1),
        ts: _int(j['ts']),
        heard: j['heard'] == null ? null : _str(j['heard']),
      );
}

class SkSub {
  SkSub(
      {required this.id,
      required this.half,
      required this.sec,
      this.off,
      this.on,
      this.ts = 0});
  final String id;
  final int half;
  final int sec;
  final int? off;
  final int? on;
  final int ts;

  Map<String, dynamic> toJson() =>
      {'id': id, 'half': half, 'sec': sec, 'off': off, 'on': on, 'ts': ts};

  factory SkSub.fromJson(Map j) => SkSub(
        id: _str(j['id']),
        half: _int(j['half'], 1),
        sec: _int(j['sec']),
        off: _intOrNull(j['off']),
        on: _intOrNull(j['on']),
        ts: _int(j['ts']),
      );
}

/// When something happened: the half, the second in it, and whether the
/// clock was running.
class SkAt {
  const SkAt(this.half, this.sec, this.run);
  final int half;
  final int sec;
  final bool run;
}

class SkState {
  SkState({this.setup}) : phase = setup != null ? 'play' : 'setup';

  int? sessionId;
  bool isFinal = false;
  bool finalisePending = false;
  bool needSetup = false;
  SkSetup? setup;

  /// setup | play | ht | ft | done
  String phase;
  SkClock clock = SkClock();
  List<SkAct> acts = [];
  List<SkSub> subs = [];

  /// The outbox: entries exactly as sync_match_actions takes them.
  List<Map<String, dynamic>> out = [];
  int timerVer = 0;
  int timerSent = 0;
  Map<int, bool> checked = {};
  List<Map<String, dynamic>> rejected = [];

  Map<String, dynamic> toJson() => {
        'v': 1,
        'sessionId': sessionId,
        'final': isFinal,
        'finalisePending': finalisePending,
        'needSetup': needSetup,
        'setup': setup?.toJson(),
        'phase': phase,
        'clock': clock.toJson(),
        'acts': [for (final a in acts) a.toJson()],
        'subs': [for (final s in subs) s.toJson()],
        'out': out,
        'timerVer': timerVer,
        'timerSent': timerSent,
        'checked': {for (final e in checked.entries) '${e.key}': e.value},
        'rejected': rejected,
      };

  static SkState? fromJson(dynamic j) {
    if (j is! Map) return null;
    final s =
        SkState(setup: j['setup'] is Map ? SkSetup.fromJson(j['setup']) : null)
          ..sessionId = _intOrNull(j['sessionId'])
          ..isFinal = j['final'] == true
          ..finalisePending = j['finalisePending'] == true
          ..needSetup = j['needSetup'] == true
          ..clock = j['clock'] is Map ? SkClock.fromJson(j['clock']) : SkClock()
          ..timerVer = _int(j['timerVer'])
          ..timerSent = _int(j['timerSent']);
    const phases = {'setup', 'play', 'ht', 'ft', 'done'};
    if (phases.contains(j['phase'])) s.phase = j['phase'] as String;
    s.acts = [
      for (final a in (j['acts'] is List ? j['acts'] as List : []))
        if (a is Map) SkAct.fromJson(a)
    ];
    s.subs = [
      for (final x in (j['subs'] is List ? j['subs'] as List : []))
        if (x is Map) SkSub.fromJson(x)
    ];
    s.out = [
      for (final o in (j['out'] is List ? j['out'] as List : []))
        if (o is Map) Map<String, dynamic>.from(o)
    ];
    s.checked = {
      if (j['checked'] is Map)
        for (final e in (j['checked'] as Map).entries)
          _int(e.key): e.value == true
    };
    s.rejected = [
      for (final o in (j['rejected'] is List ? j['rejected'] as List : []))
        if (o is Map) Map<String, dynamic>.from(o)
    ];
    return s;
  }

  int get halfLen => setup?.dur ?? 1800;
  int get injLen => setup?.inj ?? 300;

  /// Pending uploads: the outbox plus the match setup when it's waiting.
  int get pending => out.length + (needSetup ? 1 : 0);
}

// ------------------------------------------------------------------ clock

int secInHalf(SkState s, int nowMs) {
  final c = s.clock;
  final live = c.run && c.startedAt != null ? (nowMs - c.startedAt!) / 1000 : 0;
  return math.max(0, (c.banked + live).floor());
}

String fmtClock(int s) => '${pad2(s ~/ 60)}:${pad2(s % 60)}';

/// 12', 30+2', 47' for a half length.
String minuteFor(int duration, int half, int sec) =>
    minuteLabel(_labelModel(duration), half, sec);

MatchModel _labelModel(int d) => MatchModel(
    usName: '',
    oppName: '',
    duration: d,
    hasH2: false,
    nowAbs: null,
    finished: false,
    events: const [],
    subs: const []);

/// Nothing can be scored until the half has kicked off.
bool started(SkState s, int nowMs) =>
    s.phase != 'play' || s.clock.run || secInHalf(s, nowMs) > 0;

SkAt nowStamp(SkState s, int nowMs) => SkAt(
    s.clock.half,
    s.phase == 'play'
        ? secInHalf(s, nowMs)
        : (s.clock.ended[s.clock.half] ?? secInHalf(s, nowMs)),
    s.clock.run);

/// What followers see (sync_match_actions p_timer).
Map<String, dynamic> timerPayload(SkState s, DateTime now) {
  final c = s.clock;
  return {
    'status': c.run ? 'running' : 'paused',
    'started_at': c.run && c.startedAt != null
        ? DateTime.fromMillisecondsSinceEpoch(c.startedAt!, isUtc: true)
            .toIso8601String()
        : '',
    'elapsed_seconds': c.banked.floor(),
    'current_half': c.half,
    'duration_seconds': s.halfLen,
    'injury_seconds': s.injLen,
    // Lets followers see kick-off, half time and full time
    // ('setup' until the clock first runs)
    'phase': s.phase == 'play' && !c.run && c.half == 1 && c.banked == 0
        ? 'setup'
        : s.phase,
    // This phone's clock when sent, so the live screen can correct for a
    // phone clock that is off
    'client_now': now.toUtc().toIso8601String(),
  };
}

// ----------------------------------------------------------------- outbox

Map<String, dynamic> opFor(SkAct a) => a.isCorrection
    ? {
        'type': 'correction',
        'id': a.id,
        'score_type': a.st,
        'side': a.side,
        'count': a.n,
        'second': a.sec,
        'half': a.half,
      }
    : {
        'type': 'score',
        'id': a.id,
        'score_type': a.st,
        'side': a.side,
        'second': a.sec,
        'half': a.half,
        'timer_status': a.run ? 'running' : 'paused',
        'member_id': a.mem,
        'from_type': a.fr,
      };

SkAct addScore(SkState s, int st, String side, SkAt at, int nowMs,
    {int? mem, int? fr}) {
  final a = SkAct(
      id: skId(),
      k: 'score',
      st: st,
      side: side,
      sec: at.sec,
      half: at.half,
      run: at.run,
      mem: mem,
      fr: fr,
      ts: nowMs);
  s.acts.add(a);
  s.out.add(opFor(a));
  return a;
}

SkAct addCorrection(SkState s, int st, String side, int n, SkAt at, int nowMs) {
  final a = SkAct(
      id: skId(),
      k: 'correction',
      st: st,
      side: side,
      sec: at.sec,
      half: at.half,
      n: n,
      ts: nowMs);
  s.acts.add(a);
  s.out.add(opFor(a));
  return a;
}

/// Takes an entry off. Still in the outbox (and not uploading): it just
/// never goes; otherwise a remove is queued.
SkAct? removeAct(SkState s, String id, Set<String> inFlight) {
  final a = s.acts.where((x) => x.id == id).firstOrNull;
  if (a == null) return null;
  s.acts.removeWhere((x) => x.id == id);
  final queued = s.out.indexWhere((o) => o['id'] == id);
  if (queued >= 0 && !inFlight.contains(id)) {
    s.out.removeAt(queued);
    s.out.removeWhere((o) => o['target'] == id);
  } else {
    s.out.add({'type': 'remove', 'id': skId(), 'target': id});
  }
  return a;
}

/// Puts a removed entry back (Undo of a take-off), as a new entry.
SkAct restoreAct(SkState s, SkAct a, int nowMs) {
  final b = a.copyAs(skId(), nowMs);
  s.acts.add(b);
  s.out.add(opFor(b));
  return b;
}

/// ch keys: 'st', 'side', 'mem', 'fr' (present = changed).
void editAct(SkState s, SkInfo c, String id, Map<String, Object?> ch,
    Set<String> inFlight) {
  final a = s.acts.where((x) => x.id == id).firstOrNull;
  if (a == null) return;
  if (ch.containsKey('st')) a.st = ch['st'] as int;
  if (ch.containsKey('side')) a.side = ch['side'] as String;
  if (ch.containsKey('mem')) a.mem = ch['mem'] as int?;
  if (ch.containsKey('fr')) a.fr = ch['fr'] as int?;
  // A player on their side only for a non-score he gave away
  // ("free against Luke")
  final scoring = c.typeById(a.st).scoring;
  if (a.side == 'opp' && scoring) a.mem = null;
  if (!scoring) a.fr = null;
  final qi = s.out.indexWhere((o) =>
      o['id'] == id && (o['type'] == 'score' || o['type'] == 'correction'));
  if (qi >= 0 && !inFlight.contains(id)) {
    s.out[qi] = opFor(a);
  } else {
    final op = <String, dynamic>{'type': 'edit', 'id': skId(), 'target': id};
    if (ch.containsKey('st')) op['score_type'] = a.st;
    if (ch.containsKey('side')) op['side'] = a.side;
    if (ch.containsKey('mem') ||
        ch.containsKey('side') ||
        ch.containsKey('st')) {
      op['member_id'] = a.mem;
    }
    if (ch.containsKey('fr') || ch.containsKey('st')) op['from_type'] = a.fr;
    s.out.add(op);
  }
}

SkSub addSub(SkState s, int off, int on, SkAt at, int nowMs) {
  final x = SkSub(
      id: skId(), half: at.half, sec: at.sec, off: off, on: on, ts: nowMs);
  s.subs.add(x);
  s.out.add({
    'type': 'sub',
    'id': x.id,
    'second': x.sec,
    'half': x.half,
    'member_off': off,
    'member_on': on,
  });
  return x;
}

void removeSub(SkState s, String id, Set<String> inFlight) {
  s.subs.removeWhere((x) => x.id == id);
  final q = s.out.indexWhere((o) => o['id'] == id);
  if (q >= 0 && !inFlight.contains(id)) {
    s.out.removeAt(q);
  } else {
    s.out.add({'type': 'remove_sub', 'id': skId(), 'target': id});
  }
}

// ---------------------------------------------------------- from server

List<SkAct> mapServerActs(dynamic list) {
  final out = <SkAct>[];
  if (list is! List) return out;
  for (var i = 0; i < list.length; i++) {
    final d = list[i];
    if (d is! Map) continue;
    out.add(SkAct(
      id: _str(d['id']),
      k: d['kind'] == 'correction' ? 'correction' : 'score',
      st: _int(d['score_type']),
      side: _str(d['side']) == 'opp' ? 'opp' : 'us',
      sec: _int(d['second']),
      half: _int(d['half'], 1) == 0 ? 1 : _int(d['half'], 1),
      mem: _intOrNull(d['member_id']),
      fr: _intOrNull(d['from_type']),
      n: d['count'] == null ? 1 : _int(d['count'], 1),
      ts: _epochMs(d['created_at']) ?? i,
    ));
  }
  return out;
}

List<SkSub> mapServerSubs(dynamic list) => [
      if (list is List)
        for (final x in list)
          if (x is Map)
            SkSub(
                id: _str(x['id']),
                half: _int(x['half'], 1) == 0 ? 1 : _int(x['half'], 1),
                sec: _int(x['second']),
                off: _intOrNull(x['member_off']),
                on: _intOrNull(x['member_on']))
    ];

/// Server entries, with anything still waiting in this phone's outbox on
/// top.
(List<SkAct>, List<SkSub>) mergeWithOutbox(List<SkAct> acts, List<SkSub> subs,
    List<Map<String, dynamic>> out, int nowMs) {
  var a2 = [...acts];
  var s2 = [...subs];
  for (final o in out) {
    final t = o['type'];
    if ((t == 'score' || t == 'correction') &&
        !a2.any((a) => a.id == o['id'])) {
      a2.add(SkAct(
        id: _str(o['id']),
        k: t as String,
        st: _int(o['score_type']),
        side: _str(o['side']) == 'opp' ? 'opp' : 'us',
        sec: _int(o['second']),
        half: _int(o['half'], 1),
        run: o['timer_status'] == 'running',
        mem: _intOrNull(o['member_id']),
        fr: _intOrNull(o['from_type']),
        n: t == 'correction' ? _int(o['count'], 1) : 1,
        ts: nowMs,
      ));
    } else if (t == 'remove') {
      a2 = a2.where((a) => a.id != o['target']).toList();
    } else if (t == 'edit') {
      final a = a2.where((x) => x.id == o['target']).firstOrNull;
      if (a != null) {
        if (o.containsKey('score_type')) a.st = _int(o['score_type']);
        if (o.containsKey('side')) a.side = _str(o['side']);
        if (o.containsKey('member_id')) a.mem = _intOrNull(o['member_id']);
        if (o.containsKey('from_type')) a.fr = _intOrNull(o['from_type']);
      }
    } else if (t == 'sub' && !s2.any((x) => x.id == o['id'])) {
      s2.add(SkSub(
          id: _str(o['id']),
          half: _int(o['half'], 1),
          sec: _int(o['second']),
          off: _intOrNull(o['member_off']),
          on: _intOrNull(o['member_on']),
          ts: nowMs));
    } else if (t == 'remove_sub') {
      s2 = s2.where((x) => x.id != o['target']).toList();
    }
  }
  return (a2, s2);
}

SkState stateFromServer(Map srv) {
  final tm = srv['timer'] is Map ? srv['timer'] as Map : null;
  final ses = srv['session'] is Map ? srv['session'] as Map : null;
  if (ses == null && tm == null) return SkState();
  final ev = srv['event'] is Map ? srv['event'] as Map : const {};
  String firstOf(List<dynamic> v) =>
      v.map(_str).firstWhere((x) => x.isNotEmpty, orElse: () => '');
  final setup = SkSetup(
    opp: firstOf([ses?['opposition'], tm?['opposition'], ev['opposition']]),
    squadId: _intOrNull(ses?['squad_id']) ?? _intOrNull(tm?['squad_id']),
    dur: _int(tm?['duration_seconds']) > 0
        ? _int(tm?['duration_seconds'])
        : 1800,
    inj: tm?['injury_seconds'] != null ? _int(tm!['injury_seconds']) : 300,
    throwAt: tm?['throw_in_at'] == null ? null : _str(tm!['throw_in_at']),
    venue: _str(tm?['venue']),
    extra: tm != null && (tm['throw_in_at'] != null || _str(tm['venue']) != ''),
  );
  final s = SkState(setup: setup);
  if (tm != null) {
    s.clock.half = _int(tm['current_half'], 1) == 2 ? 2 : 1;
    s.clock.banked = _double(tm['elapsed_seconds']);
    final st = _epochMs(tm['started_at']);
    if (tm['status'] == 'running' && st != null) {
      s.clock.run = true;
      s.clock.startedAt = st;
    }
    if (tm['phase'] == 'ht' || tm['phase'] == 'ft') {
      s.clock.ended[s.clock.half] = s.clock.banked.floor();
      s.phase = tm['phase'] as String;
    } else if (tm['status'] != 'running' &&
        s.clock.banked >= setup.dur + setup.inj &&
        setup.dur > 0) {
      // The old score keeper parks the clock at half length + injury when
      // a half ends
      s.clock.ended[s.clock.half] = s.clock.banked.floor();
      s.phase = s.clock.half == 1 ? 'ht' : 'ft';
    }
  }
  if (ses != null) {
    s.sessionId = _intOrNull(ses['id']);
    if (ses['status'] == 'finalised') {
      s.isFinal = true;
      s.phase = 'done';
    } else if (tm == null) {
      s.needSetup = true; // recreate the clock row
    }
  } else {
    s.needSetup = true;
  }
  s.acts = mapServerActs(srv['actions']);
  s.subs = mapServerSubs(srv['subs']);
  s.timerVer = 0;
  s.timerSent = 0;
  return s;
}

// ---------------------------------------------------------------- players

class SkPlayer {
  SkPlayer(
      {required this.id,
      required this.first,
      required this.last,
      this.number,
      this.inLineup = false,
      this.isSub = false});
  final int id;
  final String first;
  final String last;
  final int? number;
  final bool inLineup;
  final bool isSub;

  String get full => '$first $last'.trim();

  /// "Ciarán B.", "Jack O'S."
  String get short {
    final l = last.trim();
    if (l.isEmpty) return first;
    final ini = RegExp(r"^(O'|O’|Ó )", caseSensitive: false).hasMatch(l)
        ? l.substring(0, 3).replaceAll(' ', '')
        : l[0];
    return '$first $ini.';
  }
}

/// The latest saved line-up (with shirt numbers) plus the rest of the team.
/// A squad picked in setup narrows the rest to that squad (unless nobody is
/// linked to it).
Map<int, SkPlayer> roster(SkState? s, SkInfo c) {
  final out = <int, SkPlayer>{};
  for (final p in c.lineup) {
    out[p.memberId] = SkPlayer(
        id: p.memberId,
        first: p.first,
        last: p.last,
        number: p.number,
        inLineup: true,
        isSub: p.isSub);
  }
  final sq = s?.setup?.squadId;
  var players = c.players;
  if (sq != null) {
    final inSq = players.where((p) => p.squads.contains(sq)).toList();
    if (inSq.isNotEmpty) players = inSq;
  }
  for (final p in players) {
    out.putIfAbsent(p.memberId,
        () => SkPlayer(id: p.memberId, first: p.first, last: p.last));
  }
  return out;
}

List<SkSub> subsSorted(SkState s) => [...s.subs]
  ..sort((a, b) => a.half != b.half ? a.half - b.half : a.sec - b.sec);

int _byNumber(SkPlayer a, SkPlayer b) => (a.number ?? 99) - (b.number ?? 99);

/// Who is on the pitch now: line-up starters, then each sub in turn. Null
/// when there's no line-up.
List<SkPlayer>? onPitch(SkState s, SkInfo c) {
  if (c.lineup.isEmpty) return null;
  final r = roster(s, c);
  final on = <int>{
    for (final p in c.lineup)
      if (!p.isSub) p.memberId
  };
  for (final x in subsSorted(s)) {
    if (x.off != null) on.remove(x.off);
    if (x.on != null) on.add(x.on!);
  }
  return [
    for (final id in on)
      if (r[id] != null) r[id]!
  ]..sort(_byNumber);
}

String memberName(SkState? s, SkInfo c, int? id) =>
    id == null ? '' : roster(s, c)[id]?.full ?? '';

// ---------------------------------------------------------------- labels

String usName(SkInfo c) {
  final club = cleanClub(c.clubName);
  if (club.isNotEmpty) return club;
  return c.teamName.isNotEmpty ? c.teamName : 'Us';
}

String oppName(SkState? s, SkInfo c) {
  final o = s?.setup?.opp ?? '';
  if (o.isNotEmpty) return o;
  return c.eventOpposition.isNotEmpty ? c.eventOpposition : 'Opposition';
}

/// "Point from a free", "Score check: +1 goal" and the line under it.
(String, String) actLabel(SkState s, SkInfo c, SkAct a) {
  final t = c.typeById(a.st);
  final us = usName(c), opp = oppName(s, c);
  if (a.isCorrection) {
    return (
      'Score check: ${a.n > 0 ? '+' : ''}${a.n} ${t.name.toLowerCase()}${a.n.abs() != 1 ? 's' : ''}',
      a.side == 'us' ? us : opp
    );
  }
  final fr = a.fr != null ? c.typeById(a.fr!) : null;
  final name = fr != null && fr.name != 'Score'
      ? '${t.name} from a ${RegExp(r'^\d').hasMatch(fr.name) ? fr.name : fr.name.toLowerCase()}'
      : t.name;
  if (a.side == 'opp') {
    return (
      name,
      a.mem != null
          ? '$opp · against ${memberName(s, c, a.mem).isEmpty ? '?' : memberName(s, c, a.mem)}'
          : opp
    );
  }
  final who = memberName(s, c, a.mem);
  return (name, a.mem != null && who.isNotEmpty ? who : us);
}

int countFor(SkState s, int st, String side) => s.acts.fold(
    0,
    (n, a) =>
        n + (a.st == st && a.side == side ? (a.isCorrection ? a.n : 1) : 0));

/// The chart model (the page's model()): only scores go on the Stats tab
/// (Ken, 2026-11-07).
MatchModel skMatchModel(SkState s, SkInfo c, int nowMs) {
  final r = roster(s, c);
  final finished = s.phase == 'ft' || s.phase == 'done';
  final order =
      ([...s.acts]..sort((a, b) => a.ts - b.ts)).map((a) => a.id).toList();
  final dur = s.halfLen;
  return MatchModel(
    usName: usName(c),
    oppName: oppName(s, c),
    duration: dur,
    hasH2: s.clock.half == 2 || finished,
    nowAbs: s.phase == 'play'
        ? (s.clock.half == 2 ? dur : 0) +
            math.min(secInHalf(s, nowMs), dur * 1.5).toDouble()
        : null,
    finished: finished,
    events: [
      for (final a in s.acts)
        if (c.typeById(a.st).scoring)
          MsEvent(
            half: a.half,
            second: a.sec,
            side: a.side,
            value: c.typeById(a.st).value,
            name: c.typeById(a.st).name,
            kind: a.k,
            count: a.n,
            member: a.mem != null ? r[a.mem]?.full ?? '' : '',
            order: order.indexOf(a.id),
          )
    ],
    subs: [
      for (final x in s.subs)
        MsSub(x.half, x.sec, x.on != null ? r[x.on]?.full ?? '' : '',
            x.off != null ? r[x.off]?.full ?? '' : '')
    ],
  );
}

/// Half (1 or 2) or whole match (0) by kind of score, for the HT/FT cards.
List<(String, int, int)> halfTable(SkState s, SkInfo c, int h) {
  final rows = <String, List<int>>{}; // name -> [us, opp, order]
  for (final a in s.acts) {
    if (!(a.half == h || h == 0)) continue;
    final t = c.typeById(a.st);
    if (!t.scoring) continue;
    final k = t.value == 3
        ? 'Goals'
        : t.value == 2
            ? '2 pointers'
            : t.value == 1
                ? 'Points'
                : t.name + (t.name.endsWith('s') ? '' : 's');
    final r = rows.putIfAbsent(
        k,
        () => [
              0,
              0,
              t.value == 3
                  ? 0
                  : t.value == 1
                      ? 1
                      : t.value == 2
                          ? 2
                          : 3
            ]);
    r[a.side == 'us' ? 0 : 1] += a.isCorrection ? a.n : 1;
  }
  final list = rows.entries.toList()..sort((a, b) => a.value[2] - b.value[2]);
  return [for (final e in list) (e.key, e.value[0], e.value[1])];
}

/// "Clontarf leading by 3", "Raheny won by 2", "Level".
String leadText(SkState s, SkInfo c, Walk w) {
  final d = w.usT - w.oppT;
  if (d == 0) return 'Level';
  final who = d > 0 ? usName(c) : oppName(s, c);
  final verb = s.phase == 'ht'
      ? 'leading'
      : (s.phase == 'done' || s.phase == 'ft')
          ? 'won'
          : 'ahead';
  return '$who $verb by ${d.abs()}';
}

/// The status pill: text and whether it's waiting (amber) or busy.
(String, String) pillText(SkState? s, String netState, bool syncing) {
  if (s == null) return ('All saved', '');
  final n = s.pending;
  final timerWait = s.timerVer != s.timerSent;
  if (n == 0 && !timerWait && !s.finalisePending) return ('All saved', '');
  switch (netState) {
    case 'offline':
      return (n > 0 ? '$n waiting · no signal' : 'Waiting for signal', 'wait');
    case 'auth':
      return ('Waiting to sign in', 'wait');
    case 'error':
      return (n > 0 ? '$n waiting · retrying' : 'Retrying', 'wait');
  }
  return ('Saving…', 'busy');
}

/// What the Saving sheet says.
String pillMessage(int n, String netState) {
  final e = n == 1 ? 'entry is' : 'entries are';
  if (n == 0 && netState == 'ok') return 'Everything is saved to CoachSmart.';
  if (netState == 'offline') {
    return '$n $e saved on this phone and will upload by themselves when signal comes back. Keep scoring as normal.';
  }
  if (netState == 'auth') {
    return '$n $e saved on this phone, waiting for the app to sign in again. Keep scoring. If this stays, close the score keeper and open it again: nothing is lost.';
  }
  return '$n $e saved on this phone and uploading.';
}

/// The squad's own throw-in: the event's date as stored, at this time on
/// the phone's clock.
String? throwIso(String eventDateTime, int? hour, int? minute) {
  if (hour == null || minute == null) return null;
  final day = eventDateTime.length >= 10 ? eventDateTime.substring(0, 10) : '';
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(day);
  if (m == null) return null;
  final d = DateTime(
      int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!), hour, minute);
  return d.toUtc().toIso8601String();
}

/// "HH:MM" on the phone's clock, or null.
(int, int)? hhmm(String? iso) {
  if (iso == null) return null;
  final d = DateTime.tryParse(iso)?.toLocal();
  return d == null ? null : (d.hour, d.minute);
}

/// Shared PDF file name: "Clontarf_v_Raheny_1-04_0-03.pdf".
String skPdfName(String us, String opp, String usScore, String oppScore) =>
    '${'$us v $opp $usScore $oppScore'.replaceAll(RegExp(r'[^A-Za-z0-9 \-]'), '').replaceAll(RegExp(r'\s+'), '_')}.pdf';

// ---------------------------------------------------------- errors / sync

/// How an upload failed: offline (no signal), auth (sign-in), error
/// (server trouble, retry) or bad (the server can't read this entry).
enum SkFail { offline, auth, error, bad }
