// v3 Match Stats: the data side of webviews/match-stats-chart.html and the
// shared webviews/cs-match-charts.js, as pure functions so tests can run
// without a network. The page reads two RPCs:
//   list_match_stats_for_event(p_event_id)    -> the score keeping sessions
//   get_match_stats_session(p_match_stats_id) -> one session with its scores
// Only scores are shown: wides, frees, turnovers etc. stay in the score
// keeper's own list (cs-match-charts.js scoresOnly, Ken 2026-11-07).
import 'dart:math' as math;

// ------------------------------------------------------------------ parsing

int _int(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String)
    return int.tryParse(v) ?? num.tryParse(v)?.toInt() ?? fallback;
  return fallback;
}

double _double(dynamic v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

String _str(dynamic v) => v == null ? '' : v.toString();

DateTime? _date(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

/// One row of list_match_stats_for_event: a score keeper's session.
class MsSessionItem {
  MsSessionItem({
    required this.id,
    required this.userName,
    required this.squadName,
    required this.squadColour,
    required this.opposition,
    required this.finalised,
    required this.status,
    required this.scoreCount,
    required this.isMine,
  });

  final int id;
  final String userName;
  final String squadName;
  final String squadColour;
  final String opposition;
  final bool finalised;
  final String status;
  final int scoreCount;
  final bool isMine;

  bool get live => status == 'active' && !finalised;

  /// "Ken Darcy · Blue", or "Unknown" when the user has no name.
  String get title {
    final n = userName.trim().isEmpty ? 'Unknown' : userName.trim();
    return squadName.isEmpty ? n : '$n · $squadName';
  }

  String get meta =>
      'vs ${opposition.isEmpty ? 'Opposition' : opposition} · $scoreCount score${scoreCount != 1 ? 's' : ''}';

  factory MsSessionItem.fromJson(Map j) => MsSessionItem(
        id: _int(j['id']),
        userName: _str(j['user_name']),
        squadName: _str(j['squad_name']),
        squadColour: _str(j['squad_colour']),
        opposition: _str(j['opposition']),
        finalised: j['finalised_at'] != null,
        status: _str(j['status']),
        scoreCount: _int(j['score_count']),
        isMine: j['is_mine'] == true,
      );
}

List<MsSessionItem> parseSessionList(dynamic r) => r is List
    ? [
        for (final x in r)
          if (x is Map) MsSessionItem.fromJson(x)
      ]
    : <MsSessionItem>[];

/// "2 sessions · 1 live — tap to view"
String pickerSubtitle(List<MsSessionItem> s) {
  final live = s.where((x) => x.live).length;
  final count = s.length == 1 ? '1 session' : '${s.length} sessions';
  return '$count${live > 0 ? ' · $live live' : ''} — tap to view';
}

/// Squad colour as stored ("#1E88E5"), grey when missing or bad.
int squadColourValue(String hex) {
  var h = hex.trim().replaceFirst('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  final v = int.tryParse(h, radix: 16);
  if (v == null || (h.length != 6 && h.length != 8)) return 0xFF64748B;
  return h.length == 6 ? 0xFF000000 | v : v;
}

/// The match_timer row inside get_match_stats_session.
class MsTimer {
  MsTimer({
    this.elapsed = 0,
    this.startedAt,
    this.status = 'paused',
    this.duration = 1800,
    this.currentHalf = 1,
    this.localRef = false,
  });

  final double elapsed;
  final DateTime? startedAt;
  final String status;
  final int duration;
  final int currentHalf;

  /// True when started_at was re-anchored to this device's clock from a
  /// broadcast, so a later refresh keeps it (no cross-device clock skew).
  final bool localRef;

  bool get running => status == 'running';

  factory MsTimer.fromJson(Map j) => MsTimer(
        elapsed: _double(j['elapsed_seconds']),
        startedAt: _date(j['started_at']),
        status: _str(j['status']).isEmpty ? 'paused' : _str(j['status']),
        duration: _int(j['duration_seconds']) > 0
            ? _int(j['duration_seconds'])
            : 1800,
        currentHalf: _int(j['current_half']) > 0 ? _int(j['current_half']) : 1,
      );

  MsTimer copyWith(
          {double? elapsed,
          DateTime? startedAt,
          String? status,
          bool? localRef}) =>
      MsTimer(
          elapsed: elapsed ?? this.elapsed,
          startedAt: startedAt ?? this.startedAt,
          status: status ?? this.status,
          duration: duration,
          currentHalf: currentHalf,
          localRef: localRef ?? this.localRef);

  /// Seconds played in the current half, ticking while running.
  double elapsedAt(DateTime now) {
    var e = elapsed;
    if (running && startedAt != null) {
      e += now.difference(startedAt!).inMilliseconds / 1000;
    }
    return e;
  }
}

/// A broadcast timer_state from the score keeper, merged over the current
/// timer. A running clock is re-anchored to this device's own clock.
MsTimer mergeBroadcast(MsTimer? prev, Map raw, DateTime now) {
  final p = raw['payload'] is Map ? raw['payload'] as Map : raw;
  final base = prev ?? MsTimer();
  final running = _str(p['status']) == 'running';
  return MsTimer(
    elapsed: p.containsKey('elapsed_seconds')
        ? _double(p['elapsed_seconds'])
        : base.elapsed,
    startedAt: running ? now : (_date(p['started_at']) ?? base.startedAt),
    status: p.containsKey('status') ? _str(p['status']) : base.status,
    duration:
        p.containsKey('duration_seconds') && _int(p['duration_seconds']) > 0
            ? _int(p['duration_seconds'])
            : base.duration,
    currentHalf: p.containsKey('current_half') && _int(p['current_half']) > 0
        ? _int(p['current_half'])
        : base.currentHalf,
    localRef: running,
  );
}

/// After a refresh: keep a broadcast-anchored running clock, and keep the
/// smaller elapsed when the database stored a ceiling for injury time.
MsTimer mergeRefresh(MsTimer? prev, MsTimer next) {
  if (prev == null) return next;
  if (prev.localRef && next.running && prev.running) {
    return next.copyWith(
        elapsed: prev.elapsed, startedAt: prev.startedAt, localRef: true);
  }
  if (prev.elapsed > 0 &&
      next.status == 'paused' &&
      prev.elapsed < next.elapsed) {
    return next.copyWith(elapsed: prev.elapsed);
  }
  return next;
}

/// One stat row from the session, as cs-match-charts.js models it.
class MsEvent {
  MsEvent({
    required this.half,
    required this.second,
    required this.side,
    required this.value,
    required this.name,
    required this.kind,
    required this.count,
    required this.member,
    required this.order,
  });

  final int half;
  final int second;
  final String side; // 'us' | 'opp'
  final int? value; // points; null for wides etc
  final String name;
  final String kind; // 'score' | 'correction'
  final int count;
  final String member;
  final int order;

  bool get isCorrection => kind == 'correction';
  bool get isUs => side == 'us';

  /// How many of this stat the row adds (corrections carry +/-n).
  int get n => isCorrection ? count : 1;
}

class MsSub {
  MsSub(this.half, this.second, this.on, this.off);
  final int half;
  final int second;
  final String on;
  final String off;
}

/// get_match_stats_session.
class MsSession {
  MsSession({
    required this.id,
    required this.eventId,
    required this.teamName,
    required this.opposition,
    required this.eventTitle,
    required this.finalisedAt,
    required this.timer,
    required this.events,
    required this.subs,
  });

  final int id;
  final int eventId;
  final String teamName;
  final String opposition;
  final String eventTitle;
  final DateTime? finalisedAt;
  MsTimer timer;
  final List<MsEvent> events;
  final List<MsSub> subs;

  bool get finished => finalisedAt != null;
  String get usName => teamName.isEmpty ? 'Us' : teamName;
  String get oppName => opposition.isEmpty ? 'Opp' : opposition;
  String get title => eventTitle.isEmpty ? 'Match' : eventTitle;

  /// Null when the RPC returned {} (not found, reset or no access).
  static MsSession? fromJson(dynamic r) {
    if (r is! Map || r['match_stats_id'] == null) return null;
    final raw = r['events'] is List ? r['events'] as List : const [];
    // The RPC already orders by half, second, created_at; keep that order.
    final evs = <MsEvent>[];
    for (var i = 0; i < raw.length; i++) {
      final e = raw[i];
      if (e is! Map) continue;
      final v = _int(e['score_value']);
      final name = _str(e['score_type_name']).isNotEmpty
          ? _str(e['score_type_name'])
          : _str(e['abbreviated_name']).isNotEmpty
              ? _str(e['abbreviated_name'])
              : 'Score';
      evs.add(MsEvent(
        half: _int(e['half'], 1) == 0 ? 1 : _int(e['half'], 1),
        second: _int(e['second']),
        side: _str(e['side']),
        value: v == 0 ? null : v,
        name: name,
        kind: _str(e['kind']).isEmpty ? 'score' : _str(e['kind']),
        count: e['count'] == null ? 1 : _int(e['count'], 1),
        member: _str(e['member_name']),
        order: i,
      ));
    }
    final subs = <MsSub>[
      for (final s in (r['subs'] is List ? r['subs'] as List : const []))
        if (s is Map)
          MsSub(_int(s['half'], 1) == 0 ? 1 : _int(s['half'], 1),
              _int(s['second']), _str(s['on_name']), _str(s['off_name'])),
    ];
    return MsSession(
      id: _int(r['match_stats_id']),
      eventId: _int(r['event_id']),
      teamName: _str(r['team_name']),
      opposition: _str(r['opposition']),
      eventTitle: _str(r['event_title']),
      finalisedAt: _date(r['finalised_at']),
      timer: r['timer'] is Map ? MsTimer.fromJson(r['timer']) : MsTimer(),
      events: evs,
      subs: subs,
    );
  }
}

// ------------------------------------------------------------- chart model

/// The model cs-match-charts.js draws from (chartModel() in the page).
class MatchModel {
  MatchModel({
    required this.usName,
    required this.oppName,
    required this.duration,
    required this.hasH2,
    required this.nowAbs,
    required this.finished,
    required this.events,
    required this.subs,
  });

  final String usName;
  final String oppName;
  final int duration;
  final bool hasH2;
  final double? nowAbs;
  final bool finished;
  final List<MsEvent> events;
  final List<MsSub> subs;

  /// Only scores (value > 0), corrections to scores included.
  MatchModel scoresOnly() => MatchModel(
      usName: usName,
      oppName: oppName,
      duration: duration,
      hasH2: hasH2,
      nowAbs: nowAbs,
      finished: finished,
      events: [
        for (final e in events)
          if ((e.value ?? 0) > 0) e
      ],
      subs: subs);
}

MatchModel chartModel(MsSession s, DateTime now) {
  final t = s.timer;
  final dur = t.duration;
  double? nowAbs;
  if (!s.finished) {
    final el = t.elapsedAt(now);
    nowAbs = (t.currentHalf == 2 ? dur : 0) +
        math.min(math.max(el, 0), dur * 1.5).toDouble();
  }
  return MatchModel(
    usName: s.usName,
    oppName: s.oppName,
    duration: dur,
    hasH2: s.events.any((e) => e.half == 2) || t.currentHalf == 2,
    nowAbs: nowAbs,
    finished: s.finished,
    events: s.events,
    subs: s.subs,
  );
}

String pad2(int n) => n.toString().padLeft(2, '0');
String gaa(int g, int p) => '$g-${pad2(p)}';
String poss(String n) =>
    RegExp(r's$', caseSensitive: false).hasMatch(n) ? "$n'" : "$n's";

/// Absolute match second, injury time squeezed onto the end of its half.
double absSec(MatchModel m, int half, int sec) {
  final d = m.duration;
  final s = math.min(sec.toDouble(), d * 1.5);
  return half == 2 ? d + s : s;
}

/// 12', 30+2', 47' ...
String minuteLabel(MatchModel m, int half, int sec) {
  final min = sec ~/ 60 + 1;
  final halfLen = (m.duration / 60).round();
  final base = half == 2 ? halfLen : 0;
  if (min > halfLen) return "${base + halfLen}+${min - halfLen}'";
  return "${base + min}'";
}

class _Tally {
  int g = 0;
  int p = 0;
  int get total => g * 3 + p;
  void add(MsEvent e) {
    if (e.value == null) return;
    if (e.value == 3) {
      g += e.n;
    } else {
      p += e.n * e.value!;
    }
  }
}

/// One step of the running score.
class WalkRow {
  WalkRow(this.e, this.abs, this.us, this.opp, this.usT, this.oppT);
  final MsEvent e;
  final double abs;
  final String us;
  final String opp;
  final int usT;
  final int oppT;
  bool get scoring => e.value != null;
  int get diff => usT - oppT;
}

class Walk {
  Walk(this.rows, this.usG, this.usP, this.oppG, this.oppP);
  final List<WalkRow> rows;
  final int usG, usP, oppG, oppP;
  String get us => gaa(usG, usP);
  String get opp => gaa(oppG, oppP);
  int get usT => usG * 3 + usP;
  int get oppT => oppG * 3 + oppP;
}

int _cmpEv(MsEvent a, MsEvent b) {
  if (a.half != b.half) return a.half - b.half;
  if (a.second != b.second) return a.second - b.second;
  return a.order - b.order;
}

/// Walk the scores in order, keeping the running score.
Walk walk(MatchModel m) {
  final evs = [...m.scoresOnly().events]..sort(_cmpEv);
  final us = _Tally(), opp = _Tally();
  final rows = <WalkRow>[];
  for (final e in evs) {
    (e.isUs ? us : opp).add(e);
    rows.add(WalkRow(e, absSec(m, e.half, e.second), gaa(us.g, us.p),
        gaa(opp.g, opp.p), us.total, opp.total));
  }
  return Walk(rows, us.g, us.p, opp.g, opp.p);
}

class MatchAxis {
  MatchAxis(this.end, this.ticks, this.halfMin);
  final double end;
  final List<int> ticks; // minutes
  final int halfMin;
}

MatchAxis axis(MatchModel m) {
  final end = (m.hasH2 ? 2 * m.duration : m.duration).toDouble();
  final halfMin = (m.duration / 60).round();
  final step = halfMin <= 20 ? 5 : 10;
  final ticks = <int>[];
  for (var x = 0; x <= halfMin * (m.hasH2 ? 2 : 1); x += step) {
    if (m.hasH2 && x == halfMin) continue; // HT label goes here
    ticks.add(x);
  }
  return MatchAxis(end, ticks, halfMin);
}

double _endX(MatchModel m, MatchAxis ax) => m.nowAbs != null
    ? math.min(math.max(m.nowAbs!, 0), ax.end).toDouble()
    : ax.end;

/// "Who was ahead": the lead (us minus them) as a step line.
class LeadSeries {
  LeadSeries(this.points, this.maxD, this.goals, this.axis);
  final List<(double, int)> points; // (match second, lead)
  final int maxD;
  final List<(double, int, bool)> goals; // (second, lead, ours)
  final MatchAxis axis;
}

LeadSeries leadSeries(MatchModel m) {
  final w = walk(m);
  final ax = axis(m);
  var maxD = 3;
  for (final r in w.rows) {
    maxD = math.max(maxD, r.diff.abs());
  }
  maxD = (maxD / 3).ceil() * 3;
  final endX = _endX(m, ax);
  var d = 0;
  final pts = <(double, int)>[(0, 0)];
  for (final r in w.rows.where((r) => r.scoring)) {
    pts.add((r.abs, d));
    d = r.diff;
    pts.add((r.abs, d));
  }
  pts.add((math.max(endX, pts.last.$1), d));
  final goals = [
    for (final r in w.rows)
      if (r.scoring && r.e.value == 3 && !r.e.isCorrection)
        (r.abs, r.diff, r.e.isUs)
  ];
  return LeadSeries(pts, maxD, goals, ax);
}

/// "Scores over the match": each side's running total as a step line.
class RaceSeries {
  RaceSeries(this.us, this.opp, this.maxY, this.endX, this.axis, this.usLabel,
      this.oppLabel);
  final List<(double, int)> us;
  final List<(double, int)> opp;
  final int maxY;
  final double endX;
  final MatchAxis axis;
  final String usLabel;
  final String oppLabel;
  int get usEnd => us.last.$2;
  int get oppEnd => opp.last.$2;
}

RaceSeries raceSeries(MatchModel m) {
  final w = walk(m);
  final ax = axis(m);
  var maxY = 5;
  for (final r in w.rows) {
    maxY = math.max(maxY, math.max(r.usT, r.oppT));
  }
  maxY = (maxY / 5).ceil() * 5;
  final endX = _endX(m, ax);
  List<(double, int)> path(bool us) {
    var v = 0;
    final p = <(double, int)>[(0, 0)];
    for (final r in w.rows.where((r) => r.scoring)) {
      p.add((r.abs, v));
      v = us ? r.usT : r.oppT;
      p.add((r.abs, v));
    }
    p.add((endX, v));
    return p;
  }

  return RaceSeries(path(true), path(false), maxY, endX, ax, w.us, w.opp);
}

class BiggestLead {
  BiggestLead(this.d, this.at);
  final int d;
  final String at;
  String get label => d > 0 ? '+$d at $at' : '—';
}

(BiggestLead, BiggestLead) biggestLeads(MatchModel m) {
  final w = walk(m);
  var us = BiggestLead(0, ''), opp = BiggestLead(0, '');
  for (final r in w.rows.where((r) => r.scoring)) {
    final d = r.diff;
    if (d > us.d) us = BiggestLead(d, minuteLabel(m, r.e.half, r.e.second));
    if (-d > opp.d) opp = BiggestLead(-d, minuteLabel(m, r.e.half, r.e.second));
  }
  return (us, opp);
}

/// Score per half: {1: (us, opp), 2: (us, opp)}.
Map<int, (String, String)> halfScores(MatchModel m) {
  final s = m.scoresOnly();
  return {
    for (final h in [1, 2])
      h: () {
        final us = _Tally(), opp = _Tally();
        for (final e in s.events.where((e) => e.half == h)) {
          (e.isUs ? us : opp).add(e);
        }
        return (gaa(us.g, us.p), gaa(opp.g, opp.p));
      }()
  };
}

class StatCount {
  StatCount(this.name, this.value);
  final String name;
  final int? value;
  int us = 0;
  int opp = 0;
}

/// Counts per stat name. The page lists the ones with no score value; with
/// scoresOnly in force that list is empty, as on the web page.
List<StatCount> otherStats(MatchModel m) {
  final c = <String, StatCount>{};
  for (final e in m.scoresOnly().events) {
    final k = e.name.isEmpty ? 'Other' : e.name;
    final s = c.putIfAbsent(k, () => StatCount(k, e.value));
    if (e.isUs) {
      s.us += e.n;
    } else {
      s.opp += e.n;
    }
  }
  return [
    for (final s in c.values)
      if (s.value == null) s
  ];
}

class Scorer {
  Scorer(this.name, this.score, this.total, this.other);
  final String name; // '' = no player named
  final String score;
  final int total;
  final Map<String, int> other;

  /// "2 wides, 1 free"
  String get otherText => other.entries
      .map((x) =>
          '${x.value} ${x.key.toLowerCase()}${x.value != 1 && !RegExp(r's$', caseSensitive: false).hasMatch(x.key) ? 's' : ''}')
      .join(', ');
}

/// Our scorers, named players first, most points first.
List<Scorer> scorers(MatchModel m) {
  final by = <String, (_Tally, Map<String, int>)>{};
  for (final e in m.scoresOnly().events.where((e) => e.isUs)) {
    final b = by.putIfAbsent(e.member, () => (_Tally(), <String, int>{}));
    if (e.value == null) {
      b.$2[e.name] = (b.$2[e.name] ?? 0) + e.n;
    } else {
      b.$1.add(e);
    }
  }
  final list = <(int, Scorer)>[];
  var i = 0;
  by.forEach((k, v) {
    final s = Scorer(k, gaa(v.$1.g, v.$1.p), v.$1.total, v.$2);
    if (s.total > 0 || s.other.isNotEmpty) list.add((i, s));
    i++;
  });
  list.sort((a, b) {
    final ea = a.$2.name.isEmpty ? 1 : 0, eb = b.$2.name.isEmpty ? 1 : 0;
    if (ea != eb) return ea - eb;
    if (a.$2.total != b.$2.total) return b.$2.total - a.$2.total;
    return a.$1 - b.$1;
  });
  return [for (final x in list) x.$2];
}

// ---------------------------------------------------------------- timeline

enum TlKind { band, event, sub, run, empty }

enum TlTag { none, goalUs, goalOpp, plus2, check }

class TlItem {
  TlItem.band(this.label, this.score, {this.fullTime = false})
      : kind = TlKind.band,
        minute = '',
        who = '',
        tag = TlTag.none,
        ours = true,
        goal = false;
  TlItem.event(
      {required this.minute,
      required this.label,
      required this.who,
      required this.score,
      required this.tag,
      required this.ours,
      required this.goal})
      : kind = TlKind.event,
        fullTime = false;
  TlItem.sub(this.minute, this.label, this.who)
      : kind = TlKind.sub,
        score = '',
        tag = TlTag.none,
        ours = true,
        goal = false,
        fullTime = false;
  TlItem.run(this.label, this.ours)
      : kind = TlKind.run,
        minute = '',
        who = '',
        score = '',
        tag = TlTag.none,
        goal = false,
        fullTime = false;
  TlItem.empty(this.label)
      : kind = TlKind.empty,
        minute = '',
        who = '',
        score = '',
        tag = TlTag.none,
        ours = true,
        goal = false,
        fullTime = false;

  final TlKind kind;
  final String minute;
  final String label; // band label, event name, "Sub", run text
  final String who; // second line
  final String score; // "1-04 v 0-03"
  final TlTag tag;
  final bool ours;
  final bool goal;
  final bool fullTime;
}

/// The timeline, newest first: full time (or now) at the top, throw-in at
/// the bottom, half time between, subs and "scored 3 in a row" notes.
List<TlItem> timeline(MatchModel full) {
  final m = full.scoresOnly();
  final w = walk(m);
  final throwIn = TlItem.band('Throw-in', '0-00 v 0-00');
  final items = <(int, int, int, WalkRow?, MsSub?)>[];
  var i = 0;
  for (final r in w.rows) {
    items.add((r.e.half, r.e.second, i++, r, null));
  }
  for (final s in m.subs) {
    items.add((s.half, s.second, i++, null, s));
  }
  items.sort((a, b) => a.$1 != b.$1
      ? a.$1 - b.$1
      : a.$2 != b.$2
          ? a.$2 - b.$2
          : a.$3 - b.$3);

  final rows = <TlItem>[];
  String? lastSide;
  var run = 0;
  var htShown = false;
  var last = ('0-00', '0-00');
  for (var k = 0; k < items.length; k++) {
    final it = items[k];
    if (it.$1 == 2 && !htShown) {
      rows.add(TlItem.band('Half time', '${last.$1} v ${last.$2}'));
      htShown = true;
    }
    final s = it.$5;
    if (s != null) {
      rows.add(TlItem.sub(minuteLabel(m, s.half, s.second), 'Sub',
          '${s.on.isEmpty ? 'On' : s.on} on for ${s.off.isEmpty ? 'off' : s.off}'));
      continue;
    }
    final r = it.$4!;
    final e = r.e;
    last = (r.us, r.opp);
    final name = e.isCorrection
        ? 'Score check: ${e.count > 0 ? '+' : ''}${e.count} ${e.name.toLowerCase()}${e.count.abs() != 1 ? 's' : ''}'
        : (e.name.isEmpty ? 'Score' : e.name);
    final tag = e.isCorrection
        ? TlTag.check
        : e.value == 3
            ? (e.isUs ? TlTag.goalUs : TlTag.goalOpp)
            : e.value == 2
                ? TlTag.plus2
                : TlTag.none;
    final who = (e.isUs ? m.usName : m.oppName) +
        (e.member.isNotEmpty ? ' · ${e.member}' : '');
    rows.add(TlItem.event(
        minute: minuteLabel(m, e.half, e.second),
        label: name,
        who: who,
        score: r.scoring ? '${r.us} v ${r.opp}' : '',
        tag: tag,
        ours: e.isUs,
        goal: e.value == 3 && !e.isCorrection));
    if (r.scoring && !e.isCorrection) {
      run = e.side == lastSide ? run + 1 : 1;
      lastSide = e.side;
      WalkRow? next;
      for (final x in items.skip(k + 1)) {
        if (x.$4 != null && x.$4!.scoring) {
          next = x.$4;
          break;
        }
      }
      if (run >= 3 && !(next != null && next.e.side == e.side)) {
        rows.add(TlItem.run(
            '${e.isUs ? m.usName : m.oppName} scored $run in a row', e.isUs));
      }
    }
  }
  if (rows.isEmpty) return [throwIn, TlItem.empty('No scores yet')];
  final end = m.finished
      ? TlItem.band('Full time', '${w.us} v ${w.opp}', fullTime: true)
      : TlItem.band('Now', '${w.us} v ${w.opp}');
  return [throwIn, ...rows, end].reversed.toList();
}

// ----------------------------------------------------------------- header

enum LeadTone { none, leading, trailing, level }

/// The chip under the score board: Won by 3 / Raheny 2 up / Level / Draw.
(String, LeadTone) leadChip(MatchModel m) {
  final w = walk(m);
  final diff = w.usT - w.oppT;
  if (m.finished) {
    if (diff > 0) return ('Won by $diff', LeadTone.leading);
    if (diff < 0) return ('Lost by ${diff.abs()}', LeadTone.trailing);
    return ('Draw', LeadTone.level);
  }
  if (diff > 0) return ('${m.usName} $diff up', LeadTone.leading);
  if (diff < 0) return ('${m.oppName} ${diff.abs()} up', LeadTone.trailing);
  if (w.usT == 0) return ('', LeadTone.none);
  return ('Level', LeadTone.level);
}

String fmtMmSs(double s) {
  final v = math.max(0, s.floor());
  return '${pad2(v ~/ 60)}:${pad2(v % 60)}';
}

class LiveClock {
  LiveClock(this.half, this.time, this.sub, this.running);
  final String half;
  final String time;
  final String sub;
  final bool running;
}

/// The live timer card; null once the session is finalised.
LiveClock? liveClock(MsSession s, DateTime now) {
  if (s.finished) return null;
  final t = s.timer;
  final dur = t.duration;
  final halfName = t.currentHalf == 1 ? 'First Half' : 'Second Half';
  final elapsed = math.max(0.0, t.elapsedAt(now));
  final remaining = math.max(0.0, dur - elapsed);
  final inInjury = elapsed > dur;
  final injury = math.max(0.0, elapsed - dur);
  final running = t.running;
  if (t.currentHalf == 1 && elapsed >= dur && !running) {
    return LiveClock(
        'Half Time', fmtMmSs(dur.toDouble()), '2nd half starting', running);
  }
  if (inInjury) {
    return LiveClock(halfName, '+${fmtMmSs(injury)}',
        running ? 'injury time' : 'injury time — paused', running);
  }
  if (elapsed < 1 && !running) {
    return LiveClock(
        halfName, fmtMmSs(dur.toDouble()), 'ready to start', running);
  }
  return LiveClock(halfName, fmtMmSs(remaining),
      running ? 'remaining' : 'remaining — paused', running);
}

/// Event_vs_Opp_1-04_0-03_2026-11-11.pdf, as the web export names it.
String pdfFileName(
    String event, String opp, String us, String them, DateTime d) {
  final date = '${d.year}-${pad2(d.month)}-${pad2(d.day)}';
  return '${[
    event,
    'vs',
    opp,
    us,
    them,
    date
  ].join('_').replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_')}.pdf';
}

/// Grid label for the lead chart: 3, +1.5, -6.
String leadLabel(num v) {
  final s = v == v.roundToDouble() ? v.round().toString() : v.toString();
  return v > 0 ? '+$s' : s;
}
