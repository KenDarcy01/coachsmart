// Data for the v3 Matches list and live match pages: native copies of
// webviews/matches.html and webviews/match-live.html (with cs-live.js and
// cs-match-charts.js). Pure parsing and maths only, so it can be unit tested.
//
// RPCs (same as the web pages):
//   get_live_matches()                         the Matches list, a row per squad
//   get_live_match_v2(p_event_id, p_squad)     one squad's match + every squad
//   set_live_follow(p_event_id, p_level, ...)  follow / alert level
//   get_live_share_link(p_event_id)            share token for the web page
// Realtime: live_pulse (event_id), bumped by the database on every change.
import 'dart:ui' show Color;

import 'package:intl/intl.dart';

int _i(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
int? _iN(dynamic v) => v == null ? null : _i(v);
String _s(dynamic v) => v == null ? '' : '$v';
DateTime? _t(dynamic v) => v == null ? null : DateTime.tryParse('$v');
Map _m(dynamic v) => v is Map ? v : const {};
List _l(dynamic v) => v is List ? v : const [];

// ───────────────────────────────────────────────────────────── text bits

String pad2(int n) => n.toString().padLeft(2, '0');

/// "Clontarf GAA" → "Clontarf".
String cleanClub(String n) => n
    .replaceAll(
        RegExp(r'\b(GAA|GFC|CLG|HC|LGFA|Camogie Club)\b', caseSensitive: false),
        '')
    .replaceAll(RegExp(r'\s{2,}'), ' ')
    .trim();

/// mm:ss from seconds.
String fmtClock(num sec) {
  final s = sec < 0 ? 0 : sec.floor();
  return '${pad2(s ~/ 60)}:${pad2(s % 60)}';
}

/// "Blue Team" → "Blue" for tabs; "No team" → "Team"; others as they are.
String squadShort(String n) {
  if (RegExp(r'^\s*no team\s*$', caseSensitive: false).hasMatch(n)) {
    return 'Team';
  }
  final s = n.replaceAll(RegExp(r'\s+(team|squad)$', caseSensitive: false), '');
  return s.trim().isEmpty ? n : s.trim();
}

const _named = {
  'blue': 0xFF3B82F6,
  'navy': 0xFF1E3A8A,
  'red': 0xFFE05252,
  'maroon': 0xFF8B1E2D,
  'green': 0xFF22A559,
  'black': 0xFF0B0D0F,
  'white': 0xFFF1F4F8,
  'yellow': 0xFFF5C518,
  'gold': 0xFFD4A017,
  'orange': 0xFFF28C28,
  'purple': 0xFF8B5CF6,
  'grey': 0xFF9AA0A6,
  'gray': 0xFF9AA0A6,
  'pink': 0xFFEC4899,
  'sky': 0xFF38BDF8,
};
const _spare = [
  0xFF3B82F6,
  0xFFE05252,
  0xFFF28C28,
  0xFF8B5CF6,
  0xFF22A559,
  0xFFF5C518
];

Color? _hex(String c) {
  final h = c.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(h)) return null;
  if (h.length == 3) {
    return Color(
        int.parse('FF${h.split('').map((x) => '$x$x').join()}', radix: 16));
  }
  if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
  if (h.length == 8) {
    // CSS #rrggbbaa
    return Color(int.parse('${h.substring(6)}${h.substring(0, 6)}', radix: 16));
  }
  return null;
}

/// A squad's colour: its own colour, else a colour word in its name
/// ("Blue Team"), else one from a fixed set by position.
Color squadColour(String name, String colour, int index) {
  if (RegExp(r'^#[0-9a-fA-F]{3,8}$').hasMatch(colour.trim())) {
    final c = _hex(colour);
    if (c != null) return c;
  }
  for (final w in RegExp('[a-z]+').allMatches(name.toLowerCase())) {
    final c = _named[w.group(0)];
    if (c != null) return Color(c);
  }
  return Color(_spare[index % _spare.length]);
}

const alertLevels = [
  (
    'all',
    'Every score',
    'Goals, points and 2 pointers, both teams, plus half time and full time'
  ),
  ('goals', 'Goals only', 'Plus half time and full time'),
  ('result', 'Half time and full time only', 'No alerts for scores'),
  ('off', 'Stop following', 'No alerts for this match'),
];

String levelLabel(String l) =>
    const {
      'all': 'Every score',
      'goals': 'Goals, half time and full time',
      'result': 'Half time and full time',
      'off': 'No alerts',
    }[l] ??
    '';

// ───────────────────────────────────────────────────────────── Irish time

/// The wall-clock time in Ireland (GMT, or IST from the last Sunday of March
/// to the last Sunday of October, 01:00 UTC). The result's fields are the
/// Dublin wall time; only use it for showing.
DateTime dublin(DateTime t) {
  final u = t.toUtc();
  DateTime lastSunday(int month) {
    var d = DateTime.utc(u.year, month + 1, 0);
    while (d.weekday != DateTime.sunday) {
      d = d.subtract(const Duration(days: 1));
    }
    return d.add(const Duration(hours: 1));
  }

  final summer = !u.isBefore(lastSunday(3)) && u.isBefore(lastSunday(10));
  return u.add(Duration(hours: summer ? 1 : 0));
}

/// 14:05 in Dublin.
String clockTime(DateTime? t) =>
    t == null ? '' : DateFormat('HH:mm').format(dublin(t));

/// Wed 12 Nov
String dayLabel(DateTime t) => DateFormat('EEE d MMM').format(dublin(t));

/// Wed 12 Nov, 14:00
String whenLabel(DateTime t) =>
    DateFormat('EEE d MMM, HH:mm').format(dublin(t));

bool sameDublinDay(DateTime a, DateTime b) {
  final x = dublin(a), y = dublin(b);
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

/// Time to throw-in on the Matches list: Due, 45m, 2h 5m, or the day.
String untilLabel(DateTime t, DateTime now) {
  final ms = t.difference(now).inMilliseconds;
  if (ms <= 0) return 'Due';
  final min = (ms / 60000).round();
  if (min < 60) return '${min}m';
  final h = min ~/ 60;
  if (h < 24) return '${h}h ${min % 60}m';
  return dayLabel(t);
}

/// Big countdown on the live page before throw-in: 2 days or 01:02:03.
String countdown(Duration left) {
  final s = left.inSeconds, d = s ~/ 86400;
  if (d >= 1) return '$d day${d > 1 ? 's' : ''}';
  return '${pad2(s ~/ 3600)}:${pad2((s ~/ 60) % 60)}:${pad2(s % 60)}';
}

/// Countdown on a squad card: 1 DAY, 2H 5M, 45M.
String untilCaps(Duration left) {
  final m = (left.inMilliseconds / 60000).round().clamp(0, 1 << 30);
  if (m >= 1440) return '${m ~/ 1440} DAY${m >= 2880 ? 'S' : ''}';
  return m >= 60 ? '${m ~/ 60}H ${m % 60}M' : '${m}M';
}

// ───────────────────────────────────────────────────────────── shared parts

class ScoreLine {
  const ScoreLine(this.g, this.p, this.t);
  ScoreLine.fromJson(Map j)
      : g = _i(j['g']),
        p = _i(j['p']),
        t = j['t'] == null ? _i(j['g']) * 3 + _i(j['p']) : _i(j['t']);
  final int g, p, t;

  /// 1-05
  String get gaa => '$g-${pad2(p)}';
}

class LiveScore {
  const LiveScore(this.us, this.opp);
  LiveScore.fromJson(Map j)
      : us = ScoreLine.fromJson(_m(j['us'])),
        opp = ScoreLine.fromJson(_m(j['opp']));
  static const zero = LiveScore(ScoreLine(0, 0, 0), ScoreLine(0, 0, 0));
  final ScoreLine us, opp;
  int get diff => us.t - opp.t;
}

class LiveTimer {
  const LiveTimer(
      {this.status = '',
      this.startedAt,
      this.elapsedSeconds = 0,
      this.currentHalf = 1,
      this.durationSeconds = 1800});
  LiveTimer.fromJson(Map j)
      : status = _s(j['status']),
        startedAt = _t(j['started_at']),
        elapsedSeconds = (j['elapsed_seconds'] as num?)?.toDouble() ?? 0,
        currentHalf = j['current_half'] == null ? 1 : _i(j['current_half']),
        durationSeconds =
            j['duration_seconds'] == null || _i(j['duration_seconds']) == 0
                ? 1800
                : _i(j['duration_seconds']);
  final String status;
  final DateTime? startedAt;
  final double elapsedSeconds;
  final int currentHalf, durationSeconds;

  bool get running => status == 'running';

  /// Seconds into the current half, from the score keeper's clock. [now] is
  /// server time (phone time less the skew).
  double halfSeconds(DateTime now) {
    var s = elapsedSeconds;
    if (running && startedAt != null) {
      final d = now.difference(startedAt!).inMilliseconds / 1000;
      if (d > 0) s += d;
    }
    return s;
  }

  /// Minute of the match, e.g. 41' or 30+2'.
  String minuteOf(DateTime now) {
    final sec = halfSeconds(now);
    final min = (sec / 60).floor() + 1,
        halfMin = (durationSeconds / 60).round();
    final h = currentHalf;
    return min > halfMin
        ? "${(h - 1) * halfMin + halfMin}+${min - halfMin}'"
        : "${(h - 1) * halfMin + min}'";
  }
}

class LiveFollow {
  const LiveFollow(
      {this.level = 'off',
      this.kickoff = false,
      this.names = true,
      this.ownTeam = false});
  LiveFollow.fromJson(Map j)
      : level = j['level'] == null ? 'off' : _s(j['level']),
        kickoff = j['kickoff'] != false,
        names = j['names'] != false,
        ownTeam = j['own_team'] == true;
  final String level;
  final bool kickoff, names, ownTeam;
  bool get on => level.isNotEmpty && level != 'off';

  /// "Every score and throw-in"
  String get label => levelLabel(level) + (kickoff ? ' and throw-in' : '');
}

bool isLivePhase(String p) => p == 'play' || p == 'ht';
bool isDonePhase(String p) => p == 'ft' || p == 'done';

// ───────────────────────────────────────────────────────────── Matches list

class LiveMatchRow {
  LiveMatchRow.fromJson(Map j)
      : eventId = _i(j['event_id']),
        squadKey = _iN(j['squad_key']),
        squadName = _s(j['squad_name']),
        squadColourText = _s(j['squad_colour']),
        squadsInEvent = _i(j['squads_in_event']),
        eventDateTime = _t(j['event_date_time']),
        teamName = _s(j['team_name']),
        clubName = _s(j['club_name']),
        opposition = _s(j['opposition']),
        venue = _s(j['venue']),
        homeAway = _s(j['home_away']),
        phase = _s(j['phase']).isEmpty ? 'pre' : _s(j['phase']),
        timer = j['timer'] is Map ? LiveTimer.fromJson(j['timer']) : null,
        score = j['score'] is Map ? LiveScore.fromJson(j['score']) : null,
        follow = LiveFollow.fromJson(_m(j['follow']));

  final int eventId, squadsInEvent;
  final int? squadKey;
  final String squadName, squadColourText, teamName, clubName, opposition;
  final String venue, homeAway, phase;
  final DateTime? eventDateTime;
  final LiveTimer? timer;
  final LiveScore? score;
  LiveFollow follow;

  bool get live => isLivePhase(phase);
  bool get done => isDonePhase(phase);
  bool get started => live || done;
  bool get multi => squadName.isNotEmpty && squadsInEvent > 1;
  String get opp => opposition.isEmpty ? 'Opposition' : opposition;

  /// Home / Away
  String get ha => homeAway.isEmpty
      ? ''
      : homeAway[0].toUpperCase() + homeAway.substring(1).toLowerCase();

  /// "U12 Blue v Raheny"; the squad only when the event has more than one.
  String get title =>
      '$teamName${multi ? ' ${squadShort(squadName)}' : ''} v $opp';

  /// Squads can play at different grounds, so show the venue for them.
  String get place => squadsInEvent > 1 && venue.isNotEmpty ? venue : ha;

  Color get colour => squadColour(squadName, squadColourText, 0);
}

class LiveMatchesData {
  LiveMatchesData.fromJson(Map j, {DateTime? phoneNow})
      : error = _s(j['error']),
        serverNow = _t(j['server_now']),
        matches = [for (final m in _l(j['matches'])) LiveMatchRow.fromJson(m)]
          ..sort((a, b) => (a.eventDateTime?.millisecondsSinceEpoch ?? 0)
              .compareTo(b.eventDateTime?.millisecondsSinceEpoch ?? 0)) {
    skew = serverNow == null
        ? Duration.zero
        : (phoneNow ?? DateTime.now()).difference(serverNow!);
  }

  final String error;
  final DateTime? serverNow;
  final List<LiveMatchRow> matches;

  /// Phone clock minus server clock.
  late final Duration skew;
  bool get hasError => error.isNotEmpty;

  List<LiveMatchRow> get live => matches.where((m) => m.live).toList();

  List<LiveMatchRow> today(DateTime now) => matches
      .where((m) =>
          m.eventDateTime != null && sameDublinDay(m.eventDateTime!, now))
      .toList();

  List<LiveMatchRow> get following =>
      matches.where((m) => m.follow.on && !m.done).toList();

  /// Finished in the last 12 hours (the server keeps them that long),
  /// newest first.
  List<LiveMatchRow> get results => matches.where((m) => m.done).toList()
    ..sort((a, b) => (b.eventDateTime?.millisecondsSinceEpoch ?? 0)
        .compareTo(a.eventDateTime?.millisecondsSinceEpoch ?? 0));

  /// Distinct events, for the realtime subscription.
  List<int> get eventIds => {for (final m in matches) m.eventId}.toList();

  /// Following is per event: every squad row of the event changes together.
  void setFollow(int eventId, LiveFollow f) {
    for (final m in matches) {
      if (m.eventId == eventId) m.follow = f;
    }
  }
}

// ───────────────────────────────────────────────────────────── live match

class LiveEvent {
  LiveEvent.fromJson(Map j)
      : eventId = _i(j['event_id']),
        eventDateTime = _t(j['event_date_time']),
        eventStart = _t(j['event_start']),
        eventTitle = _s(j['event_title']),
        opposition = _s(j['opposition']),
        homeAway = _s(j['home_away']),
        locationName = _s(j['location_name']),
        teamName = _s(j['team_name']),
        clubName = _s(j['club_name']),
        eventCode = _s(j['event_code']);
  final int eventId;
  final DateTime? eventDateTime, eventStart;
  final String eventTitle, opposition, homeAway, locationName, teamName;
  final String clubName, eventCode;
}

class LiveLast {
  LiveLast.fromJson(Map j)
      : type = _s(j['type']),
        value = _i(j['value']),
        side = _s(j['side']),
        half = j['half'] == null ? 1 : _i(j['half']),
        second = _i(j['second']);
  final String type, side;
  final int value, half, second;
}

/// One squad's summary (the Both cards and the squad tabs).
class LiveSquad {
  LiveSquad.fromJson(Map j)
      : key = _i(j['key']),
        name = _s(j['name']),
        colourText = _s(j['colour']),
        phase = _s(j['phase']).isEmpty ? 'pre' : _s(j['phase']),
        score = j['score'] is Map ? LiveScore.fromJson(j['score']) : null,
        opposition = _s(j['opposition']),
        venue = _s(j['venue']),
        throwInAt = _t(j['throw_in_at']),
        kickedOffAt = _t(j['kicked_off_at']),
        timer = j['timer'] is Map ? LiveTimer.fromJson(j['timer']) : null,
        last = j['last'] is Map ? LiveLast.fromJson(j['last']) : null;
  final int key;
  final String name, colourText, phase, opposition, venue;
  final LiveScore? score;
  final DateTime? throwInAt, kickedOffAt;
  final LiveTimer? timer;
  final LiveLast? last;

  String get short => squadShort(name);
  String get opp => opposition.isEmpty ? 'Opposition' : opposition;
}

class ScoreType {
  ScoreType.fromJson(Map j)
      : id = _i(j['id']),
        name = _s(j['name']),
        value = _i(j['value']);
  final int id, value;
  final String name;
}

class LiveAction {
  LiveAction.fromJson(Map j)
      : id = _i(j['id']),
        type = _i(j['type']),
        side = _s(j['side']) == 'opp' ? 'opp' : 'us',
        kind = _s(j['kind']),
        count = j['count'] == null ? 1 : _i(j['count']),
        half = j['half'] == null ? 1 : _i(j['half']),
        second = _i(j['second']),
        member = _s(j['member']);
  final int id, type, count, half, second;
  final String side, kind, member;
}

class LiveSub {
  LiveSub.fromJson(Map j)
      : half = j['half'] == null ? 1 : _i(j['half']),
        second = _i(j['second']),
        on = _s(j['on']),
        off = _s(j['off']);
  final int half, second;
  final String on, off;
}

const kBoth = -1;

class LiveMatchData {
  LiveMatchData.fromJson(Map j, {DateTime? phoneNow})
      : error = _s(j['error']),
        serverNow = _t(j['server_now']),
        phase = _s(j['phase']).isEmpty ? 'pre' : _s(j['phase']),
        event = LiveEvent.fromJson(_m(j['event'])),
        timer = LiveTimer.fromJson(_m(j['timer'])),
        score = j['score'] is Map ? LiveScore.fromJson(j['score']) : null,
        scoreTypes = [
          for (final t in _l(j['score_types'])) ScoreType.fromJson(t)
        ],
        actions = [for (final a in _l(j['actions'])) LiveAction.fromJson(a)],
        subs = [for (final s in _l(j['subs'])) LiveSub.fromJson(s)],
        follow = LiveFollow.fromJson(_m(j['follow'])),
        squad = j['squad'] is Map ? LiveSquad.fromJson(j['squad']) : null,
        squads = [for (final s in _l(j['squads'])) LiveSquad.fromJson(s)] {
    skew = serverNow == null
        ? Duration.zero
        : (phoneNow ?? DateTime.now()).difference(serverNow!);
  }

  final String error, phase;
  final DateTime? serverNow;
  final LiveEvent event;
  final LiveTimer timer;
  final LiveScore? score;
  final List<ScoreType> scoreTypes;
  final List<LiveAction> actions;
  final List<LiveSub> subs;
  LiveFollow follow;
  final LiveSquad? squad;
  final List<LiveSquad> squads;
  late final Duration skew;

  bool get hasError => error.isNotEmpty;
  bool get done => isDonePhase(phase);
  bool get multi => !hasError && squads.length > 1;

  String get errorText =>
      const {
        'not_allowed': 'This match is only for members of the club.',
        'link_not_found':
            "This link isn't working any more. Ask for a new one.",
        'not_signed_in': 'Please sign in again.',
      }[error] ??
      "Couldn't load the match.";

  ScoreType? typeOf(int id) {
    for (final t in scoreTypes) {
      if (t.id == id) return t;
    }
    return null;
  }

  String get usName {
    final c = cleanClub(event.clubName);
    if (c.isNotEmpty) return c;
    return event.teamName.isNotEmpty ? event.teamName : 'Us';
  }

  String get oppName =>
      event.opposition.isEmpty ? 'Opposition' : event.opposition;

  bool scoring(LiveAction a) =>
      a.kind == 'score' && (typeOf(a.type)?.value ?? 0) > 0;
  List<LiveAction> get scoringActions => actions.where(scoring).toList();

  int squadIndex(int key) => squads.indexWhere((s) => s.key == key);
  Color colourOf(LiveSquad s) =>
      squadColour(s.name, s.colourText, squadIndex(s.key).clamp(0, 99));

  /// The view to show after a load: on the first load open on Both when
  /// more than one squad is playing (unless a squad was asked for); a squad
  /// that has gone falls back to the one the server sent.
  int? nextView(int? view) {
    if (view == null) {
      return squads.length > 1 ? kBoth : squad?.key;
    }
    if (view != kBoth &&
        squad != null &&
        squad!.key != view &&
        !squads.any((x) => x.key == view)) {
      return squad!.key;
    }
    return view;
  }

  /// Cards for Both: live first, then the next to start, then results
  /// (newest first).
  List<LiveSquad> get ordered {
    int rank(LiveSquad s) =>
        isLivePhase(s.phase) ? 0 : (s.phase == 'pre' ? 1 : 2);
    int at(LiveSquad s, int r) =>
        ((r == 1 ? s.throwInAt : s.kickedOffAt)?.millisecondsSinceEpoch ?? 0);
    return squads.toList()
      ..sort((a, b) {
        final ra = rank(a), rb = rank(b);
        if (ra != rb) return ra - rb;
        return ra == 2 ? at(b, ra) - at(a, ra) : at(a, ra) - at(b, ra);
      });
  }

  /// The chart model, as cs-match-charts.js builds it.
  MatchModel model(DateTime serverNowish) {
    final finished = done;
    final dur = timer.durationSeconds;
    final half = timer.currentHalf;
    final sec = timer.halfSeconds(serverNowish);
    return MatchModel(
      usName: usName,
      oppName: oppName,
      duration: dur,
      hasH2: half == 2 || finished,
      nowAbs: phase == 'play'
          ? (half == 2 ? dur : 0) + (sec < dur * 1.5 ? sec : dur * 1.5)
          : null,
      finished: finished,
      events: [
        for (final a in actions)
          MatchEv(
              half: a.half,
              second: a.second,
              side: a.side,
              value: typeOf(a.type)?.value ?? 0,
              name: typeOf(a.type)?.name ?? '',
              kind: a.kind,
              count: a.count,
              member: a.member),
      ],
      subs: subs,
    );
  }

  /// Share text, as the web page writes it.
  String shareText(int? view) {
    if (multi && view == kBoth) {
      return 'Follow ${event.teamName} live: ${squads.map((x) => '${x.short} v ${x.opp}').join(', ')}';
    }
    if (phase == 'pre') {
      return 'Follow ${event.teamName}${multi && squad != null ? ' ${squad!.short}' : ''} v $oppName live';
    }
    final s = score ?? LiveScore.zero;
    final what = done ? 'Full time' : (phase == 'ht' ? 'Half time' : 'Live');
    return '$what: $usName ${s.us.gaa} $oppName ${s.opp.gaa}';
  }

  /// The coachsmart.app link (the web page, so anyone can open it).
  static String shareUrl(String token, int? squadKey) =>
      'https://coachsmart.app/webviews/match-live.html?share=$token'
      '${squadKey != null && squadKey != kBoth ? '&squad=$squadKey' : ''}';
}

// ───────────────────────────────────────────────────────────── charts maths

class MatchEv {
  const MatchEv(
      {required this.half,
      required this.second,
      required this.side,
      required this.value,
      required this.name,
      this.kind = 'score',
      this.count = 1,
      this.member = ''});
  final int half, second, value, count;
  final String side, name, kind, member;
  bool get correction => kind == 'correction';
}

class MatchModel {
  const MatchModel(
      {required this.usName,
      required this.oppName,
      required this.duration,
      required this.hasH2,
      required this.nowAbs,
      required this.finished,
      required this.events,
      this.subs = const []});
  final String usName, oppName;
  final int duration;
  final bool hasH2, finished;
  final double? nowAbs;
  final List<MatchEv> events;
  final List<LiveSub> subs;

  /// Only scores are shown: Wide, Free, Turnover, 45 etc. stay in the score
  /// keeper's own list but not on the live screen (Ken, 2026-11-07).
  List<MatchEv> get scores => events.where((e) => e.value > 0).toList();

  /// Absolute match second, with injury time squeezed onto the end of its
  /// half so the axis never grows a phantom third period.
  double absSec(int half, int sec) {
    final d = duration.toDouble();
    final s = sec < d * 1.5 ? sec.toDouble() : d * 1.5;
    return half == 2 ? d + s : s;
  }

  String minuteLabel(int half, int sec) => minuteLabelFor(duration, half, sec);

  /// The x axis: end second and minute ticks (HT goes in its own place).
  (double end, List<int> ticks) get axis {
    final end = (hasH2 ? 2 * duration : duration).toDouble();
    final halfMin = (duration / 60).round();
    final step = halfMin <= 20 ? 5 : 10;
    final ticks = <int>[];
    for (var x = 0; x <= halfMin * (hasH2 ? 2 : 1); x += step) {
      if (hasH2 && x == halfMin) continue;
      ticks.add(x);
    }
    return (end, ticks);
  }

  /// Every score in order, with the running score.
  List<WalkRow> walk() {
    final evs = scores
      ..sort(
          (a, b) => a.half != b.half ? a.half - b.half : a.second - b.second);
    var ug = 0, up = 0, og = 0, op = 0;
    final rows = <WalkRow>[];
    for (final e in evs) {
      final n = e.correction ? e.count : 1;
      if (e.value == 3) {
        if (e.side == 'us') {
          ug += n;
        } else {
          og += n;
        }
      } else {
        if (e.side == 'us') {
          up += n * e.value;
        } else {
          op += n * e.value;
        }
      }
      rows.add(WalkRow(e, absSec(e.half, e.second),
          ScoreLine(ug, up, ug * 3 + up), ScoreLine(og, op, og * 3 + op)));
    }
    return rows;
  }

  LiveScore get totals {
    final w = walk();
    return w.isEmpty ? LiveScore.zero : LiveScore(w.last.us, w.last.opp);
  }

  /// Each side's biggest lead and when: (us lead, us at, opp lead, opp at).
  (int, String, int, String) get biggestLeads {
    var ud = 0, od = 0;
    var ua = '', oa = '';
    for (final r in walk()) {
      final d = r.us.t - r.opp.t;
      if (d > ud) {
        ud = d;
        ua = minuteLabel(r.e.half, r.e.second);
      }
      if (-d > od) {
        od = -d;
        oa = minuteLabel(r.e.half, r.e.second);
      }
    }
    return (ud, ua, od, oa);
  }

  /// Score in each half: {1: score, 2: score}.
  Map<int, LiveScore> get halfScores {
    final out = <int, LiveScore>{};
    for (final h in [1, 2]) {
      var ug = 0, up = 0, og = 0, op = 0;
      for (final e in scores.where((e) => e.half == h)) {
        final n = e.correction ? e.count : 1;
        final us = e.side == 'us';
        if (e.value == 3) {
          if (us) {
            ug += n;
          } else {
            og += n;
          }
        } else if (us) {
          up += n * e.value;
        } else {
          op += n * e.value;
        }
      }
      out[h] = LiveScore(
          ScoreLine(ug, up, ug * 3 + up), ScoreLine(og, op, og * 3 + op));
    }
    return out;
  }

  /// Our scorers, named first then by total; '' is "No player named".
  List<(String name, ScoreLine score)> get scorers {
    final by = <String, List<int>>{};
    for (final e in scores.where((e) => e.side == 'us')) {
      final v = by.putIfAbsent(e.member, () => [0, 0]);
      final n = e.correction ? e.count : 1;
      if (e.value == 3) {
        v[0] += n;
      } else {
        v[1] += n * e.value;
      }
    }
    final out = [
      for (final x in by.entries)
        if (x.value[0] * 3 + x.value[1] > 0)
          (
            x.key,
            ScoreLine(x.value[0], x.value[1], x.value[0] * 3 + x.value[1])
          )
    ];
    out.sort((a, b) {
      final an = a.$1.isEmpty ? 1 : 0, bn = b.$1.isEmpty ? 1 : 0;
      if (an != bn) return an - bn;
      return b.$2.t - a.$2.t;
    });
    return out;
  }

  /// The timeline, newest first: full time (or now) at the top, throw-in at
  /// the bottom, half-time band, subs, and "scored 3 in a row" notes.
  List<TimelineItem> timeline() {
    final w = walk();
    final items = <(int half, int second, WalkRow? r, LiveSub? s)>[
      for (final r in w) (r.e.half, r.e.second, r, null),
      for (final s in subs) (s.half, s.second, null, s),
    ];
    // Stable sort by half then second (scores before subs at the same time,
    // as in the web page's sort).
    final idx = [for (var i = 0; i < items.length; i++) i];
    idx.sort((a, b) {
      final x = items[a], y = items[b];
      if (x.$1 != y.$1) return x.$1 - y.$1;
      if (x.$2 != y.$2) return x.$2 - y.$2;
      return a - b;
    });
    final sorted = [for (final i in idx) items[i]];
    final out = <TimelineItem>[
      const TimelineItem.band('Throw-in', '0-00 v 0-00'),
    ];
    final rows = <TimelineItem>[];
    String? lastSide;
    var run = 0;
    var htShown = false;
    var lastUs = '0-00', lastOpp = '0-00';
    for (var i = 0; i < sorted.length; i++) {
      final it = sorted[i];
      if (it.$1 == 2 && !htShown) {
        rows.add(TimelineItem.band('Half time', '$lastUs v $lastOpp'));
        htShown = true;
      }
      if (it.$4 != null) {
        final s = it.$4!;
        rows.add(TimelineItem.sub(minuteLabel(s.half, s.second),
            '${s.on.isEmpty ? 'On' : s.on} on for ${s.off.isEmpty ? 'off' : s.off}'));
        continue;
      }
      final r = it.$3!;
      lastUs = r.us.gaa;
      lastOpp = r.opp.gaa;
      rows.add(TimelineItem.score(
          r,
          minuteLabel(r.e.half, r.e.second),
          (r.e.side == 'us' ? usName : oppName) +
              (r.e.member.isNotEmpty ? ' · ${r.e.member}' : '')));
      if (!r.e.correction) {
        if (r.e.side == lastSide) {
          run++;
        } else {
          run = 1;
        }
        lastSide = r.e.side;
        WalkRow? next;
        for (final x in sorted.skip(i + 1)) {
          if (x.$3 != null) {
            next = x.$3;
            break;
          }
        }
        if (run >= 3 && !(next != null && next.e.side == r.e.side)) {
          rows.add(TimelineItem.run(
              '${r.e.side == 'us' ? usName : oppName} scored $run in a row',
              r.e.side == 'opp'));
        }
      }
    }
    if (rows.isEmpty) return const [];
    final t = totals;
    out.addAll(rows);
    out.add(TimelineItem.band(
        finished ? 'Full time' : 'Now', '${t.us.gaa} v ${t.opp.gaa}',
        ft: finished));
    return out.reversed.toList();
  }
}

String minuteLabelFor(int duration, int half, int sec) {
  final min = (sec / 60).floor() + 1;
  final halfLen = (duration / 60).round();
  final base = half == 2 ? halfLen : 0;
  if (min > halfLen) return "${base + halfLen}+${min - halfLen}'";
  return "${base + min}'";
}

class WalkRow {
  const WalkRow(this.e, this.abs, this.us, this.opp);
  final MatchEv e;
  final double abs;
  final ScoreLine us, opp;
}

enum TimelineKind { band, score, sub, run }

class TimelineItem {
  const TimelineItem.band(this.title, this.right, {this.ft = false})
      : kind = TimelineKind.band,
        row = null,
        minute = '',
        opp = false;
  const TimelineItem.score(WalkRow this.row, this.minute, this.right)
      : kind = TimelineKind.score,
        title = '',
        ft = false,
        opp = false;
  const TimelineItem.sub(this.minute, this.right)
      : kind = TimelineKind.sub,
        title = 'Sub',
        row = null,
        ft = false,
        opp = false;
  const TimelineItem.run(this.title, this.opp)
      : kind = TimelineKind.run,
        row = null,
        minute = '',
        right = '',
        ft = false;
  final TimelineKind kind;
  final String title, minute, right;
  final WalkRow? row;
  final bool ft, opp;

  /// The score row's name: "Point", or "Score check: +1 point".
  String get scoreName {
    final e = row!.e;
    if (!e.correction) return e.name.isEmpty ? 'Score' : e.name;
    final c = e.count;
    return 'Score check: ${c > 0 ? '+' : ''}$c ${e.name.toLowerCase()}${c.abs() != 1 ? 's' : ''}';
  }
}
