// Data for the v3 member stats page: the result of get_member_analytics_v3
// (member, active teams, every event the member was invited to with their
// reply or none, and the
// latest match squad pick per event) plus the pure rules the web page
// webviews/member-analytics.html applies: period ranges, the code / event
// type / team filters, attendance counts, monthly bars, squad selections,
// the tap-to-focus that narrows the Matches and History lists, and the row
// wording. Kept in one place so the page and the tests share them.

import '../v3_squads.dart';

const List<String> kMon = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const List<String> kDow = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Rows shown before "See all".
const int kMatchLimit = 3;
const int kHistoryLimit = 5;

/// Filter value for events with no code ("-" or blank).
const String kNoCode = '__none';

int? _iN(dynamic v) => v == null
    ? null
    : (v is int ? v : (v is num ? v.toInt() : int.tryParse('$v')));
String? _sN(dynamic v) => v == null ? null : '$v';

enum Reply { yes, no, none }

enum Period { month, threeMonths, season, all }

const Map<Period, String> kPeriodLabels = {
  Period.month: 'Month',
  Period.threeMonths: '3 months',
  Period.season: 'Season',
  Period.all: 'All',
};

final _matchRe = RegExp(r'match|game|fixture|league|cup|championship|challenge',
    caseSensitive: false);
final _trainRe = RegExp(r'train|session|practi', caseSensitive: false);
final _blankCode = RegExp(r'^[\s\-–—]*$');
final _notSelected = RegExp(r'not\s*selected', caseSensitive: false);

/// One event row from `events` or `matchSelections`. Selection rows carry
/// squad and role; event rows carry the member's reply.
class MsEvent {
  MsEvent.fromJson(Map j)
      : eventId = _iN(j['event_id']) ?? 0,
        title = _sN(j['event_title']),
        date = DateTime.tryParse('${j['event_date_time']}')?.toLocal(),
        type = _sN(j['event_type']),
        code = _cleanCode(_sN(j['event_code'])),
        teamId = _iN(j['team_id']),
        teamName = _sN(j['team_name']),
        opposition = _sN(j['opposition']),
        homeAway = _sN(j['home_away']),
        responseId = _iN(j['response_id']),
        squadId = _iN(j['squad_id']),
        squadName = _sN(j['squad_name']),
        squadColour = _sN(j['squad_colour']),
        roleName = _sN(j['role_name']);

  final int eventId;
  final String? title, type, code, teamName, opposition, homeAway;
  final String? squadName, squadColour, roleName;
  final int? teamId, responseId, squadId;
  final DateTime? date;

  /// A "-" or blank code means the event isn't tied to a code.
  static String? _cleanCode(String? c) =>
      c == null || _blankCode.hasMatch(c) ? null : c;

  Reply get reply => responseId == 3
      ? Reply.yes
      : responseId == 4
          ? Reply.no
          : Reply.none;

  bool get isMatch => _matchRe.hasMatch(type ?? '');
  bool get isTraining => _trainRe.hasMatch(type ?? '');
  bool get hasOpposition => (opposition ?? '').isNotEmpty;
}

/// A past match in range with the member's squad pick, if any.
class MsMatch {
  MsMatch(this.e, this.selection);
  final MsEvent e;
  final MsEvent? selection;
  String? get squad => selection == null
      ? null
      : (_nz(v3SquadName(selection!.squadName)) ?? 'Selected');
}

String? _nz(String? s) => s == null || s.isEmpty ? null : s;

class MsTeam {
  MsTeam(this.teamId, this.teamName, this.female);
  final int teamId;
  final String? teamName;
  final bool female;
}

class MemberStats {
  MemberStats._(this.firstName, this.lastName, this.teams, this.events,
      this.selections, this.isFemale);

  factory MemberStats.fromJson(Map j) {
    List<MsEvent> dedupe(dynamic list) {
      final seen = <int>{};
      final out = <MsEvent>[];
      for (final r in (list is List ? list : const [])) {
        if (r is! Map) continue;
        final e = MsEvent.fromJson(r);
        if (e.date == null || !seen.add(e.eventId)) continue;
        out.add(e);
      }
      return out;
    }

    final m = j['member'] is Map ? j['member'] as Map : const {};
    final teams = [
      for (final t in (j['teams'] is List ? j['teams'] as List : const []))
        if (t is Map)
          MsTeam(_iN(t['team_id']) ?? 0, _sN(t['team_name']),
              t['team_female'] == true)
    ];
    return MemberStats._(
        _sN(m['first_name']),
        _sN(m['last_name']),
        teams,
        dedupe(j['events']),
        dedupe(j['matchSelections']),
        teams.any((t) => t.female));
  }

  final String? firstName, lastName;
  final List<MsTeam> teams;
  final List<MsEvent> events;
  final List<MsEvent> selections;
  final bool isFemale;

  String get name =>
      [firstName, lastName].where((s) => (s ?? '').isNotEmpty).join(' ');

  /// Hurling is Camogie on a girls' or ladies' team.
  String? codeLabel(String? code) =>
      code == null ? null : (isFemale && code == 'Hurling' ? 'Camogie' : code);

  String codeKey(MsEvent e) => e.code != null ? codeLabel(e.code)! : kNoCode;
  String codeOf(MsEvent e) => e.code != null ? codeLabel(e.code)! : 'No code';

  /// More than one code in the member's events: tag every row with its code.
  bool get multiCode =>
      events.map((e) => codeLabel(e.code)).whereType<String>().toSet().length >
      1;

  /// Filter options per group as (value, label), and what's on at the start.
  late final FilterOptions options = _buildOptions();

  FilterOptions _buildOptions() {
    final codes = events
        .map((e) => codeLabel(e.code))
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    final types = events.map((e) => e.type).whereType<String>().toSet().toList()
      ..sort();
    // Teams from current links plus any team in the member's history.
    final teamNames = <String, String?>{};
    for (final t in teams) {
      teamNames['${t.teamId}'] = t.teamName;
    }
    for (final e in events) {
      if (e.teamId != null && !teamNames.containsKey('${e.teamId}')) {
        teamNames['${e.teamId}'] = e.teamName;
      }
    }
    return FilterOptions(
      code: [
        for (final c in codes) (c, c),
        if (events.any((e) => e.code == null)) (kNoCode, '- (no code)'),
      ],
      type: [for (final t in types) (t, t)],
      team: [
        for (final e in teamNames.entries) (e.key, e.value ?? 'Team'),
      ],
      defaults: {
        'code': codes.toSet(),
        'type': types.toSet(),
        'team': teamNames.keys.toSet(),
      },
    );
  }
}

class FilterOptions {
  FilterOptions(
      {required this.code,
      required this.type,
      required this.team,
      required this.defaults});
  final List<(String, String)> code, type, team;

  /// "-" (no code) events start off; everything else starts on.
  final Map<String, Set<String>> defaults;

  List<(String, String)> of(String key) =>
      key == 'code' ? code : (key == 'type' ? type : team);

  /// The filter button is only worth showing when a group has a choice.
  bool get any => [code, type, team].any((l) => l.length > 1);
}

/// Groups in the sheet, in order, with their headings.
const List<(String, String)> kFilterGroups = [
  ('code', 'Code'),
  ('type', 'Event type'),
  ('team', 'Team'),
];

class Filters {
  Filters(this.period, this.on);
  Filters.initial(FilterOptions o)
      : period = Period.season,
        on = {
          for (final k in o.defaults.keys) k: {...o.defaults[k]!}
        };
  Period period;
  final Map<String, Set<String>> on;

  bool passes(MemberStats d, MsEvent e) =>
      on['code']!.contains(d.codeKey(e)) &&
      (e.type == null || on['type']!.contains(e.type)) &&
      (e.teamId == null || on['team']!.contains('${e.teamId}'));

  bool isDefault(FilterOptions o, String key) {
    final d = o.defaults[key]!;
    return on[key]!.length == d.length && d.every(on[key]!.contains);
  }

  void reset(FilterOptions o, String key) => on[key] = {...o.defaults[key]!};

  /// Short description of a changed group, e.g. "Football, - (no code)".
  String label(FilterOptions o, String key) {
    if (on[key]!.isEmpty) return 'No ${key == 'type' ? 'event type' : key}';
    return o
        .of(key)
        .where((p) => on[key]!.contains(p.$1))
        .map((p) => p.$2)
        .join(', ');
  }

  List<String> changed(FilterOptions o) => [
        for (final g in kFilterGroups)
          if (!isDefault(o, g.$1)) g.$1
      ];
}

class PeriodRange {
  PeriodRange(
      this.from, this.prevFrom, this.prevTo, this.prevLabel, this.label);
  final DateTime? from, prevFrom, prevTo;
  final String? prevLabel;
  final String label;
}

PeriodRange periodRange(Period p, DateTime now) {
  final y = now.year, m = now.month;
  switch (p) {
    case Period.month:
      return PeriodRange(DateTime(y, m, 1), DateTime(y, m - 1, 1),
          DateTime(y, m, 1), 'last month', '${kMon[m - 1]} $y');
    case Period.threeMonths:
      final from = DateTime(y, m - 2, 1);
      return PeriodRange(from, DateTime(y, m - 5, 1), from, 'previous 3 months',
          '${kMon[from.month - 1]} – ${kMon[m - 1]} $y');
    case Period.season:
      return PeriodRange(
          DateTime(y, 1, 1),
          DateTime(y - 1, 1, 1),
          DateTime(y - 1, m, now.day, 23, 59),
          'this time last year',
          '$y season');
    case Period.all:
      return PeriodRange(null, null, null, null, 'All time');
  }
}

bool _inRange(MsEvent e, DateTime? from, DateTime? to) {
  final d = e.date!;
  return (from == null || !d.isBefore(from)) && (to == null || !d.isAfter(to));
}

int _desc(MsEvent a, MsEvent b) => b.date!.compareTo(a.date!);

int pct(int n, int d) => d == 0 ? 0 : (n * 100 / d).round();
int countReply(Iterable<MsEvent> l, Reply r) =>
    l.where((e) => e.reply == r).length;

/// Everything the page shows for one period and filter set.
class StatsView {
  StatsView(this.range, this.past, this.prevPast, this.upcoming, this.matches,
      this.trainings);
  final PeriodRange range;

  /// Past events in the period, newest first.
  final List<MsEvent> past;
  final List<MsEvent> prevPast;

  /// The next three events.
  final List<MsEvent> upcoming;

  /// Past matches in range joined with the member's pick, newest first.
  final List<MsMatch> matches;
  final List<MsEvent> trainings;

  List<MsEvent> get pastMatches => past.where((e) => e.isMatch).toList();
}

StatsView computeView(MemberStats d, Filters f, DateTime now) {
  final r = periodRange(f.period, now);
  final evs = d.events.where((e) => f.passes(d, e)).toList();
  final sel = d.selections.where((e) => f.passes(d, e)).toList();

  final past = evs.where((e) => _inRange(e, r.from, now)).toList()..sort(_desc);
  final prevPast = r.prevFrom == null
      ? <MsEvent>[]
      : evs.where((e) => _inRange(e, r.prevFrom, r.prevTo)).toList();
  final upcoming = (evs.where((e) => e.date!.isAfter(now)).toList()
        ..sort((a, b) => a.date!.compareTo(b.date!)))
      .take(3)
      .toList();

  // A squad called "Not selected" isn't a real selection.
  final selById = <int, MsEvent>{
    for (final s in sel)
      if (_inRange(s, r.from, now) && !_notSelected.hasMatch(s.squadName ?? ''))
        s.eventId: s
  };
  final byId = <int, MsMatch>{};
  for (final e in past.where((e) => e.isMatch)) {
    byId[e.eventId] = MsMatch(e, selById[e.eventId]);
  }
  selById.forEach((id, s) => byId.putIfAbsent(id, () => MsMatch(s, s)));
  final matches = byId.values.toList()..sort((a, b) => _desc(a.e, b.e));

  return StatsView(r, past, prevPast, upcoming, matches,
      past.where((e) => e.isTraining).toList());
}

// ------------------------------------------------------------------- hero

class HeroStats {
  HeroStats(this.went, this.replied, this.total, this.rate, this.trend,
      this.trendDir, this.last);
  final int went, replied, total, rate;

  /// "▲ 12% on last month", "Same as last month" or null.
  final String? trend;

  /// 1 up, -1 down, 0 flat.
  final int trendDir;

  /// The last ten events, oldest first, for the dots.
  final List<Reply> last;
}

HeroStats? heroStats(StatsView v) {
  final past = v.past;
  if (past.isEmpty) return null;
  final went = countReply(past, Reply.yes);
  final replied = past.length - countReply(past, Reply.none);
  final rate = pct(went, past.length);
  String? trend;
  var dir = 0;
  if (v.prevPast.length >= 3) {
    final diff =
        rate - pct(countReply(v.prevPast, Reply.yes), v.prevPast.length);
    dir = diff.sign;
    trend = diff == 0
        ? 'Same as ${v.range.prevLabel}'
        : '${diff > 0 ? '▲' : '▼'} ${diff.abs()}% on ${v.range.prevLabel}';
  }
  return HeroStats(went, replied, past.length, rate, trend, dir,
      past.take(10).toList().reversed.map((e) => e.reply).toList());
}

// ------------------------------------------------------------- code cards

class CodeCard {
  CodeCard(
      this.code, this.went, this.no, this.total, this.picked, this.matches);
  final String code;
  final int went, no, total, picked, matches;
}

/// One card per code when the events on screen span more than one code.
List<CodeCard> codeCards(MemberStats d, StatsView v) {
  final codes = {
    ...v.past.map((e) => d.codeLabel(e.code)),
    ...v.matches.map((m) => d.codeLabel(m.e.code)),
  }.whereType<String>().toList()
    ..sort();
  if (codes.length < 2) return [];
  return [
    for (final c in codes)
      () {
        final evs = v.past.where((e) => d.codeLabel(e.code) == c);
        final ms = v.matches.where((m) => d.codeLabel(m.e.code) == c);
        return CodeCard(
            c,
            countReply(evs, Reply.yes),
            countReply(evs, Reply.no),
            evs.length,
            ms.where((m) => m.selection != null).length,
            ms.length);
      }()
  ];
}

// ----------------------------------------------------------------- months

class MonthBar {
  MonthBar(this.year, this.month, this.label, this.pct, this.low);
  final int year, month; // month 1-12
  final String label;

  /// Null when the member had no events that month.
  final int? pct;

  /// Well under the period average (15 points or more).
  final bool low;
  String get key => 'month:$year-$month';
}

/// Months from the start of the period (or the first event) up to now, the
/// latest 12. Empty when there's under two months or no events.
List<MonthBar> monthBars(StatsView v, DateTime now) {
  final past = v.past;
  final first = v.range.from ?? (past.isNotEmpty ? past.last.date! : now);
  final months = <DateTime>[];
  for (var d = DateTime(first.year, first.month, 1);
      !d.isAfter(now);
      d = DateTime(d.year, d.month + 1, 1)) {
    months.add(d);
  }
  final shown =
      months.length > 12 ? months.sublist(months.length - 12) : months;
  if (shown.length < 2 || past.isEmpty) return [];
  final avg = pct(countReply(past, Reply.yes), past.length);
  return [
    for (final m in shown)
      () {
        final inMonth = past
            .where((e) => e.date!.year == m.year && e.date!.month == m.month)
            .toList();
        final name = kMon[m.month - 1];
        final label = shown.length > 6 ? name[0] : name;
        if (inMonth.isEmpty)
          return MonthBar(m.year, m.month, label, null, false);
        final p = pct(countReply(inMonth, Reply.yes), inMonth.length);
        return MonthBar(m.year, m.month, label, p, p < avg - 15);
      }()
  ];
}

// ----------------------------------------------------------------- squads

class SquadCard {
  SquadCard(this.code, this.rows, this.total);
  final String code;

  /// (squad, times picked, squad colour as stored e.g. "#d32f2f"), most first.
  final List<(String, int, String?)> rows;
  final int total;
}

/// How often the member was picked for each squad, one card per code.
/// Each row carries the squad's own colour (squads.squad_colour).
List<SquadCard> squadCards(MemberStats d, StatsView v) {
  final byCode = <String, Map<String, int>>{};
  final colourOf = <String, String?>{};
  for (final m in v.matches) {
    if (m.selection == null) continue;
    final counts = byCode.putIfAbsent(d.codeOf(m.e), () => {});
    counts[m.squad!] = (counts[m.squad!] ?? 0) + 1;
    colourOf[m.squad!] ??= m.selection!.squadColour;
  }
  final codes = byCode.keys.toList()..sort();
  return [
    for (final c in codes)
      () {
        final ranked = _rankDesc(byCode[c]!);
        return SquadCard(
            c,
            [for (final r in ranked) (r.$1, r.$2, colourOf[r.$1])],
            ranked.fold(0, (n, r) => n + r.$2));
      }()
  ];
}

/// Entries by count, most first; ties keep their first-seen order.
List<(String, int)> _rankDesc(Map<String, int> counts) {
  final l = [for (final (i, e) in counts.entries.indexed) (e.key, e.value, i)]
    ..sort((a, b) => a.$2 != b.$2 ? b.$2 - a.$2 : a.$3 - b.$3);
  return [for (final r in l) (r.$1, r.$2)];
}

/// The squad picked most often in the list gets the green pill.
String? topSquad(List<MsMatch> matches) {
  final counts = <String, int>{};
  for (final m in matches) {
    if (m.squad != null) counts[m.squad!] = (counts[m.squad!] ?? 0) + 1;
  }
  final r = _rankDesc(counts);
  return r.isEmpty ? null : r.first.$1;
}

// ------------------------------------------------------------------ focus

enum FocusKind { type, month, squad }

/// Tapping a squad row, month bar or the trainings / matches card narrows
/// the Matches and History lists only. One at a time.
class StatsFocus {
  StatsFocus.type(bool match)
      : kind = FocusKind.type,
        key = match ? 'type:match' : 'type:training',
        match = match,
        label = match ? 'Matches' : 'Trainings',
        year = 0,
        month = 0,
        code = null,
        squad = null;
  StatsFocus.month(MonthBar b)
      : kind = FocusKind.month,
        key = b.key,
        match = false,
        year = b.year,
        month = b.month,
        label = '${kMon[b.month - 1]} ${b.year}',
        code = null,
        squad = null;
  StatsFocus.squad(this.code, this.squad, {required bool showCode})
      : kind = FocusKind.squad,
        key = 'squad:$code|$squad',
        match = false,
        year = 0,
        month = 0,
        label = showCode ? '$squad · $code' : squad!;

  final FocusKind kind;
  final String key, label;
  final bool match;
  final int year, month;
  final String? code, squad;

  bool _inMonth(MsEvent e) => e.date!.year == year && e.date!.month == month;

  List<MsMatch> matches(MemberStats d, List<MsMatch> list) {
    switch (kind) {
      case FocusKind.squad:
        return list
            .where((m) => m.squad == squad && d.codeOf(m.e) == code)
            .toList();
      case FocusKind.month:
        return list.where((m) => _inMonth(m.e)).toList();
      case FocusKind.type:
        return match ? list : [];
    }
  }

  List<MsEvent> events(MemberStats d, StatsView v, List<MsEvent> list) {
    switch (kind) {
      case FocusKind.squad:
        final ids = matches(d, v.matches).map((m) => m.e.eventId).toSet();
        return list.where((e) => ids.contains(e.eventId)).toList();
      case FocusKind.month:
        return list.where(_inMonth).toList();
      case FocusKind.type:
        return list.where((e) => match ? e.isMatch : e.isTraining).toList();
    }
  }
}

// ------------------------------------------------------------------- rows

String eventTitle(MsEvent e) {
  if (e.isMatch && e.hasOpposition) return 'vs ${e.opposition}';
  return _nz(e.title) ?? _nz(e.type) ?? 'Event';
}

/// "vs Raheny" already says it's a match, so leave the type out.
String? typeLabel(MsEvent e) => e.isMatch && e.hasOpposition ? null : e.type;

String _two(int n) => n.toString().padLeft(2, '0');

String dayTime(DateTime d) =>
    '${kDow[d.weekday - 1]} ${_two(d.hour)}:${_two(d.minute)}';

/// "12" over "MAR", with "’24" added for another year.
(String, String) dateBlock(DateTime d, DateTime now) => (
      '${d.day}',
      '${kMon[d.month - 1].toUpperCase()}'
          '${d.year != now.year ? ' ’${'${d.year}'.substring(2)}' : ''}'
    );

String meta(List<String?> parts, String title) =>
    parts.where((p) => (p ?? '').isNotEmpty && p != title).join(' · ');

String matchTitle(MsMatch m) =>
    m.e.hasOpposition ? 'vs ${m.e.opposition}' : (_nz(m.e.title) ?? 'Match');

List<String?> matchMeta(MsMatch m) {
  final e = m.e;
  final sub = e.hasOpposition && _nz(e.title) != null && e.title != e.opposition
      ? e.title
      : e.type;
  final role = m.selection?.roleName;
  return [
    sub,
    e.homeAway,
    role != null &&
            role.isNotEmpty &&
            !RegExp(r'^player$', caseSensitive: false).hasMatch(role)
        ? role
        : null
  ];
}

// -------------------------------------------------------------------- pdf

const Map<String, String> _plain = {
  'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', //
  'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U',
  'à': 'a', 'è': 'e', 'ì': 'i', 'ò': 'o', 'ù': 'u',
  'ä': 'a', 'ë': 'e', 'ï': 'i', 'ö': 'o', 'ü': 'u',
  'ç': 'c', 'ñ': 'n',
};

/// "Aoife Ní Bhriain" → "Aoife-Ni-Bhriain-stats.pdf".
String pdfFileName(String name) {
  final plain = (name.isEmpty ? 'player' : name)
      .split('')
      .map((c) => _plain[c] ?? c)
      .join()
      .replaceAll(RegExp(r'[^\w]+'), '-');
  return '$plain-stats.pdf';
}

/// The line under the name in the PDF: period, changed filters, teams.
String pdfSubtitle(MemberStats d, Filters f, PeriodRange r) {
  final o = d.options;
  final teamLine = f.isDefault(o, 'team')
      ? d.teams.map((t) => t.teamName).whereType<String>().toSet().join(', ')
      : '';
  return [r.label, ...f.changed(o).map((k) => f.label(o, k)), teamLine]
      .where((s) => s.isNotEmpty)
      .join(' · ');
}
