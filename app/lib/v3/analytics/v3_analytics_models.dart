// v3 Club Analytics: pure data and rules behind the native copy of
// webviews/dashboard-app.html. Everything here is a plain function of the
// get_club_comparison_dashboard result so it can be unit tested.
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' show Color;

const kNoCode = '__none';
final kAllFrom = DateTime(2020, 1, 1);
const kMon = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];
const kDow = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/// List limits before "See all".
const kLimitTeamEvents = 5;
const kLimitPlayers = 25;
const kLimitTeamPlayers = 5;
const kLimitPicked = 5;
const kLimitUnpicked = 5;

// Colours the web page uses on top of the v3 palette.
const kYes = Color(0xFF22C55E);
const kNo = Color(0xFFEF4444);
const kNoText = Color(0xFFF87171);
const kWarn = Color(0xFFF59E0B);
const kNone = Color(0xFF4B5563);
const kAccent = Color(0xFF87C232);
const kSlate = Color(0xFF64748B);
const kPurple = Color(0xFFA855F7);
const kText2 = Color(0xFFB0B8C8);

// ------------------------------------------------------------------ helpers

int pctOf(num n, num d) => d == 0 ? 0 : (n / d * 100).round();

/// 70%+ green, 50-69% amber, under 50% red.
Color bandColor(int p) => p >= 70
    ? kAccent
    : p >= 50
        ? kWarn
        : kNo;

/// Text colour for a percentage (the red is lighter for text).
Color bandText(int p) => p >= 70
    ? kAccent
    : p >= 50
        ? kWarn
        : kNoText;

final _matchRe = RegExp(r'match|game|fixture|league|cup|championship|challenge',
    caseSensitive: false);
final _trainRe = RegExp(r'train|session|practi', caseSensitive: false);
bool isMatchType(String type) => _matchRe.hasMatch(type);
bool isTrainingType(String type) => _trainRe.hasMatch(type);

String initials(String? n) {
  final words = (n ?? '?').split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final s = words.take(2).map((w) => w[0]).join().toUpperCase();
  return s.isEmpty ? '?' : s;
}

/// 1234 -> "1,234" like toLocaleString('en-IE').
String fmtN(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

String plural(int n, String w, [String? pl]) =>
    '${fmtN(n)} ${n == 1 ? w : (pl ?? '${w}s')}';

String fmtDay(DateTime d) => '${d.day} ${kMon[d.month - 1]} ${d.year}';

int _cmpText(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

/// A stable sort (JS Array.sort is stable; Dart's List.sort is not).
List<T> stableSort<T>(List<T> list, int Function(T a, T b) cmp) {
  final idx = List.generate(list.length, (i) => i);
  idx.sort((x, y) {
    final c = cmp(list[x], list[y]);
    return c != 0 ? c : x - y;
  });
  final out = [for (final i in idx) list[i]];
  list
    ..clear()
    ..addAll(out);
  return list;
}

int? _int(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}'));
String _str(dynamic v) => v == null ? '' : '$v';

// ------------------------------------------------------------------- models

class AnMember {
  const AnMember(
      {required this.id,
      required this.name,
      required this.role,
      required this.response,
      this.squadId});
  final int id;
  final String name;
  final String role;

  /// accepted, declined or no_response.
  final String response;
  final int? squadId;
}

class AnEvent {
  AnEvent({
    required this.id,
    required this.teamId,
    required this.teamName,
    required this.date,
    required this.title,
    required this.rawCode,
    required this.code,
    required this.type,
    required this.opposition,
    required this.homeAway,
    required this.members,
  }) {
    for (final m in members) {
      if (m.response == 'accepted') {
        acc++;
      } else if (m.response == 'declined') {
        dec++;
      }
    }
  }

  final int id;
  final int teamId;
  final String teamName;
  final DateTime date;
  final String title;
  final String rawCode;

  /// Display code (null for none; Camogie for a female hurling team).
  final String? code;
  final String type;
  final String opposition;
  final String homeAway;
  final List<AnMember> members;
  int acc = 0;
  int dec = 0;
  int get total => members.length;
  int get nr => total - acc - dec;

  bool get isMatch => isMatchType(type);
  bool get isTraining => isTrainingType(type);
  String get codeKey => code ?? kNoCode;
  String get typeKey => type.isEmpty ? 'Other' : type;

  AnEvent withMembers(List<AnMember> ms) => AnEvent(
      id: id,
      teamId: teamId,
      teamName: teamName,
      date: date,
      title: title,
      rawCode: rawCode,
      code: code,
      type: type,
      opposition: opposition,
      homeAway: homeAway,
      members: ms);
}

class AnRosterMember {
  const AnRosterMember(this.id, this.name);
  final int id;
  final String name;
}

class AnRoleGroup {
  const AnRoleGroup(this.role, this.count, this.members);
  final String role;
  final int count;
  final List<AnRosterMember> members;
}

class AnTeam {
  const AnTeam(this.id, this.name, this.female, this.roles);
  final int id;
  final String name;
  final bool female;
  final List<AnRoleGroup> roles;
}

class AnSquad {
  AnSquad(this.id, this.name, this.teamId, this.seq, this.colour);
  final int id;
  final String name;
  final int? teamId;
  final int? seq;
  final String colour;
  Color hex = kSlate;
}

class AnData {
  const AnData(
      {required this.clubId,
      required this.from,
      required this.clubName,
      required this.teams,
      required this.squads,
      required this.events});
  final int clubId;

  /// Earliest date the loaded data covers.
  final DateTime from;
  final String clubName;
  final List<AnTeam> teams;
  final Map<int, AnSquad> squads;

  /// Newest first.
  final List<AnEvent> events;

  AnTeam? team(int id) {
    for (final t in teams) {
      if (t.id == id) return t;
    }
    return null;
  }

  String nameOf(int memberId) {
    for (final e in events) {
      for (final m in e.members) {
        if (m.id == memberId) return m.name;
      }
    }
    return 'Player';
  }
}

/// A team the user holds a grade 100 (admin) role on.
class AdminTeam {
  const AdminTeam(this.teamId, this.teamName, this.clubId, this.clubName);
  final int teamId;
  final String teamName;
  final int clubId;
  final String clubName;

  factory AdminTeam.fromJson(Map m) => AdminTeam(_int(m['team_id']) ?? 0,
      _str(m['team_name']), _int(m['club_id']) ?? 0, _str(m['club_name']));
}

class AnClub {
  const AnClub(this.id, this.name);
  final int id;
  final String name;
}

/// The user's clubs (from their admin teams), A to Z.
List<AnClub> clubsOf(List<AdminTeam> teams) {
  final map = <int, AnClub>{};
  for (final t in teams) {
    map.putIfAbsent(t.clubId,
        () => AnClub(t.clubId, t.clubName.isEmpty ? 'Club' : t.clubName));
  }
  final list = map.values.toList();
  return stableSort(list, (a, b) => _cmpText(a.name, b.name));
}

/// users.default_club when the user admins a team there, else the first club.
int defaultClubFor(List<AnClub> clubs, dynamic defaultClub) {
  final id = _int(defaultClub);
  if (id != null && id != 0 && clubs.any((c) => c.id == id)) return id;
  return clubs.first.id;
}

String? codeLabel(String? code, bool female) {
  if (code == null || RegExp(r'^[\s\-–—]*$').hasMatch(code)) return null;
  return female && code == 'Hurling' ? 'Camogie' : code;
}

// Squad colours: the squad's own colour where it shows on a dark card,
// otherwise a bright palette colour. Two squads on one team never share one.
const kSquadPalette = [
  Color(0xFF87C232),
  Color(0xFF3B82F6),
  Color(0xFFF59E0B),
  Color(0xFFA855F7),
  Color(0xFFEC4899),
  Color(0xFF14B8A6),
  Color(0xFFF97316),
  Color(0xFF06B6D4),
  Color(0xFFEF4444),
  Color(0xFFEAB308),
];

Color? hexOf(String? c) {
  var h = (c ?? '').trim();
  h = h.replaceFirst(RegExp(r'^0x', caseSensitive: false), '');
  h = h.replaceFirst('#', '');
  if (RegExp(r'^[0-9a-f]{3}$', caseSensitive: false).hasMatch(h)) {
    h = h.split('').map((x) => '$x$x').join();
  }
  if (RegExp(r'^[0-9a-f]{8}$', caseSensitive: false).hasMatch(h)) {
    h = h.substring(2); // Flutter ARGB
  }
  if (!RegExp(r'^[0-9a-f]{6}$', caseSensitive: false).hasMatch(h)) {
    return null;
  }
  final v = [0, 2, 4]
      .map((i) => int.parse(h.substring(i, i + 2), radix: 16) / 255)
      .toList();
  final lum = 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2];
  if (lum < 0.18) return null; // too dark to see
  if (lum > 0.85) return const Color(0xFFE2E6EE); // whites read as light grey
  return Color(0xFF000000 | int.parse(h, radix: 16));
}

void squadColours(Map<int, AnSquad> squads) {
  final list = squads.values.toList();
  stableSort(
      list,
      (a, b) => (a.seq ?? 999) - (b.seq ?? 999) != 0
          ? (a.seq ?? 999) - (b.seq ?? 999)
          : _cmpText(a.name, b.name));
  final byTeam = <int?, List<Color>>{};
  for (final s in list) {
    final used = byTeam.putIfAbsent(s.teamId, () => []);
    var c = hexOf(s.colour);
    if (c == null || used.contains(c)) {
      c = kSquadPalette.firstWhere((x) => !used.contains(x),
          orElse: () => kSquadPalette[used.length % kSquadPalette.length]);
    }
    used.add(c);
    s.hex = c;
  }
}

final _notSelected = RegExp(r'not\s*selected', caseSensitive: false);

/// Turns the RPC result into events, keeping only the user's admin teams.
AnData normalise(Map json, Set<int> adminTeamIds, int clubId, DateTime from) {
  final squads = <int, AnSquad>{};
  for (final s in (json['squads'] as List? ?? const [])) {
    if (s is! Map) continue;
    final id = _int(s['squad_id']);
    if (id == null) continue;
    squads[id] = AnSquad(id, _str(s['squad_name']), _int(s['team_id']),
        _int(s['seq']), _str(s['colour']));
  }
  // A squad called "Not selected" isn't a real selection.
  int? realSquad(int? id) =>
      id != null && !_notSelected.hasMatch(squads[id]?.name ?? '') ? id : null;

  final teams = <AnTeam>[];
  final events = <AnEvent>[];
  for (final t in (json['teams'] as List? ?? const [])) {
    if (t is! Map) continue;
    final id = _int(t['team_id']);
    if (id == null || !adminTeamIds.contains(id)) continue;
    final female = t['team_female'] == true;
    final roles = <AnRoleGroup>[];
    for (final r in (t['member_roles'] as List? ?? const [])) {
      if (r is! Map) continue;
      roles.add(AnRoleGroup(_str(r['role']), _int(r['count']) ?? 0, [
        for (final m in (r['members'] as List? ?? const []))
          if (m is Map)
            AnRosterMember(_int(m['member_id']) ?? 0, _str(m['name']))
      ]));
    }
    final team = AnTeam(id, _str(t['team_name']), female, roles);
    teams.add(team);
    for (final e in (t['events'] as List? ?? const [])) {
      if (e is! Map) continue;
      final date = DateTime.tryParse(_str(e['date']))?.toLocal();
      if (date == null) continue;
      final raw = _str(e['code']);
      events.add(AnEvent(
        id: _int(e['event_id']) ?? 0,
        teamId: id,
        teamName: team.name,
        date: date,
        title: _str(e['title']),
        rawCode: raw,
        code: codeLabel(raw, female),
        type: _str(e['type']),
        opposition: _str(e['opposition']),
        homeAway: _str(e['home_away']),
        members: [
          for (final m in (e['members'] as List? ?? const []))
            if (m is Map)
              AnMember(
                id: _int(m['member_id']) ?? 0,
                name: _str(m['name']),
                role: _str(m['role']).isEmpty ? 'Player' : _str(m['role']),
                response: _str(m['response']).isEmpty
                    ? 'no_response'
                    : _str(m['response']),
                squadId: realSquad(_int(m['squad_id'])),
              )
        ],
      ));
    }
  }
  stableSort(events, (a, b) => b.date.compareTo(a.date));
  squadColours(squads);
  return AnData(
      clubId: clubId,
      from: from,
      clubName: _str(json['club_name']),
      teams: teams,
      squads: squads,
      events: events);
}

// ------------------------------------------------------------------- period

enum AnPeriod { month, threeMonths, season, all }

const kPeriodLabels = {
  AnPeriod.month: 'Month',
  AnPeriod.threeMonths: '3 months',
  AnPeriod.season: 'Season',
  AnPeriod.all: 'All',
};

class AnRange {
  const AnRange(
      {this.from,
      required this.to,
      this.prevFrom,
      this.prevTo,
      this.prevLabel,
      required this.label});
  final DateTime? from;
  final DateTime to;
  final DateTime? prevFrom;
  final DateTime? prevTo;
  final String? prevLabel;
  final String label;
}

class AnCustom {
  const AnCustom(this.from, this.to);
  final DateTime from;
  final DateTime to;
}

/// Same day n months back, clamped to the month's last day (31 Mar -> 28 Feb).
DateTime monthsAgo(DateTime d, int n) {
  final last = DateTime(d.year, d.month - n + 1, 0).day;
  return DateTime(d.year, d.month - n, math.min(d.day, last), 23, 59);
}

AnRange periodRange(AnPeriod period, AnCustom? custom, DateTime now) {
  final y = now.year, m = now.month;
  if (custom != null) {
    final from = custom.from;
    final to = custom.to.isBefore(now) ? custom.to : now;
    final len = to.difference(from);
    return AnRange(
        from: from,
        to: to,
        prevFrom: from.subtract(len),
        prevTo: from,
        prevLabel: 'the period before',
        label: '${fmtDay(from)} – ${fmtDay(custom.to)}');
  }
  switch (period) {
    case AnPeriod.month:
      return AnRange(
          from: DateTime(y, m, 1),
          to: now,
          prevFrom: DateTime(y, m - 1, 1),
          prevTo: monthsAgo(now, 1),
          prevLabel: 'this time last month',
          label: '${kMon[m - 1]} $y');
    case AnPeriod.threeMonths:
      final from = DateTime(y, m - 2, 1);
      return AnRange(
          from: from,
          to: now,
          prevFrom: DateTime(y, m - 5, 1),
          prevTo: monthsAgo(now, 3),
          prevLabel: 'the 3 months before',
          label: '${kMon[from.month - 1]} – ${kMon[m - 1]} $y');
    case AnPeriod.season:
      return AnRange(
          from: DateTime(y, 1, 1),
          to: now,
          prevFrom: DateTime(y - 1, 1, 1),
          prevTo: monthsAgo(now, 12),
          prevLabel: 'this time last year',
          label: '$y season');
    case AnPeriod.all:
      return AnRange(to: now, label: 'All time');
  }
}

/// The earliest date the RPC must cover for a range (incl. the comparison).
DateTime needFrom(AnRange r) => r.prevFrom ?? r.from ?? kAllFrom;

// ------------------------------------------------------------------ filters

const kGroups = [
  ('team', 'Teams'),
  ('code', 'Code'),
  ('type', 'Event type'),
  ('role', 'Role'),
];

class AnFilters {
  final Map<String, List<(String, String)>> options = {
    for (final g in kGroups) g.$1: []
  };
  final Map<String, List<String>> defaults = {
    for (final g in kGroups) g.$1: []
  };
  final Map<String, Set<String>> on = {for (final g in kGroups) g.$1: {}};

  /// Forget everything (a new club).
  void clear() {
    for (final g in kGroups) {
      options[g.$1] = [];
      defaults[g.$1] = [];
      on[g.$1] = {};
    }
  }

  /// New options from fresh data. A group still on its default follows the
  /// new default; a changed group keeps its picks and new values join on.
  void rebuild(AnData d) {
    final evs = d.events;
    final codes = {
      for (final e in evs)
        if (e.code != null) e.code!
    }.toList()
      ..sort();
    final types = {for (final e in evs) e.typeKey}.toList()..sort();
    final roles = <String>{};
    for (final t in d.teams) {
      for (final r in t.roles) {
        roles.add(r.role);
      }
    }
    for (final e in evs) {
      for (final m in e.members) {
        roles.add(m.role);
      }
    }
    final next = <String, List<(String, String)>>{
      'team': [for (final t in d.teams) ('${t.id}', t.name)],
      'code': [
        for (final c in codes) (c, c),
        if (evs.any((e) => e.code == null)) (kNoCode, '- (no code)'),
      ],
      'type': [for (final t in types) (t, t)],
      'role': [for (final r in (roles.toList()..sort())) (r, r)],
    };
    final nextDefault = <String, List<String>>{
      'team': [for (final o in next['team']!) o.$1],
      'code': codes, // "- (no code)" is selectable but off on load
      'type': [for (final o in next['type']!) o.$1],
      'role': [for (final o in next['role']!) o.$1],
    };
    for (final g in kGroups) {
      final k = g.$1;
      final wasDefault = options[k]!.isEmpty || isDefault(k);
      final known = {for (final o in options[k]!) o.$1};
      options[k] = next[k]!;
      defaults[k] = nextDefault[k]!;
      if (wasDefault) {
        on[k] = {...defaults[k]!};
      } else {
        for (final v in nextDefault[k]!) {
          if (!known.contains(v)) on[k]!.add(v);
        }
      }
    }
  }

  bool isDefault(String k) {
    final d = defaults[k]!;
    return on[k]!.length == d.length && d.every(on[k]!.contains);
  }

  void reset(String k) => on[k] = {...defaults[k]!};
  void resetAll() {
    for (final g in kGroups) {
      reset(g.$1);
    }
  }

  void all(String k) => on[k] = {for (final o in options[k]!) o.$1};
  void none(String k) => on[k] = {};
  void toggle(String k, String v) =>
      on[k]!.contains(v) ? on[k]!.remove(v) : on[k]!.add(v);
  void only(String k, String v) => on[k] = {v};

  String label(String k) {
    final sel = on[k]!;
    if (sel.isEmpty) return 'None';
    if (sel.length == options[k]!.length) {
      return k == 'code' && options['code']!.any((o) => o.$1 == kNoCode)
          ? 'All, incl. no code'
          : 'All';
    }
    final onL = [
      for (final o in options[k]!)
        if (sel.contains(o.$1)) o.$2
    ];
    final offL = [
      for (final o in options[k]!)
        if (!sel.contains(o.$1)) o.$2
    ];
    return onL.length > 2 && offL.length < onL.length
        ? 'All except ${offL.join(', ')}'
        : onL.join(', ');
  }

  /// Groups shown in the filter sheet (more than one choice).
  List<(String, String)> get visibleGroups => [
        for (final g in kGroups)
          if (options[g.$1]!.length > 1) g
      ];

  /// Groups changed from their default, as chips.
  List<(String, String)> get changed => [
        for (final g in visibleGroups)
          if (!isDefault(g.$1)) g
      ];

  List<String> changedLabels() =>
      [for (final g in changed) '${g.$2}: ${label(g.$1)}'];
}

// ------------------------------------------------------------ derived data

/// Events in [from, to] that pass the filters, with members cut to the
/// chosen roles and counted.
List<AnEvent> scope(AnData d, AnFilters f, DateTime? from, DateTime? to,
    {int? teamId}) {
  final out = <AnEvent>[];
  for (final e in d.events) {
    if (from != null && e.date.isBefore(from)) continue;
    if (to != null && e.date.isAfter(to)) continue;
    if (teamId != null
        ? e.teamId != teamId
        : !f.on['team']!.contains('${e.teamId}')) {
      continue;
    }
    if (!f.on['code']!.contains(e.codeKey) ||
        !f.on['type']!.contains(e.typeKey)) {
      continue;
    }
    final ms = e.members.where((m) => f.on['role']!.contains(m.role)).toList();
    if (ms.isEmpty) continue;
    out.add(e.withMembers(ms));
  }
  return out;
}

/// One event with members cut to the chosen roles (for the event sheet).
AnEvent? scopeEvent(AnData d, AnFilters f, int id) {
  for (final e in d.events) {
    if (e.id == id) {
      return e.withMembers(
          e.members.where((m) => f.on['role']!.contains(m.role)).toList());
    }
  }
  return null;
}

class AnTotals {
  const AnTotals(this.acc, this.dec, this.total, this.events);
  final int acc;
  final int dec;
  final int total;
  final int events;
  int get nr => total - acc - dec;
  int get pct => pctOf(acc, total);
  int get replied => pctOf(acc + dec, total);
}

AnTotals totals(Iterable<AnEvent> evs) {
  var acc = 0, dec = 0, total = 0, n = 0;
  for (final e in evs) {
    acc += e.acc;
    dec += e.dec;
    total += e.total;
    n++;
  }
  return AnTotals(acc, dec, total, n);
}

class AnCtx {
  const AnCtx(this.r, this.evs, this.prev, this.teamId);
  final AnRange r;
  final List<AnEvent> evs;
  final List<AnEvent> prev;
  final int? teamId;
  AnCtx withEvs(List<AnEvent> e) => AnCtx(r, e, prev, teamId);
}

AnCtx contextFor(AnData d, AnFilters f, AnRange r, {int? teamId}) => AnCtx(
    r,
    scope(d, f, r.from, r.to, teamId: teamId),
    r.prevFrom != null
        ? scope(d, f, r.prevFrom, r.prevTo, teamId: teamId)
        : const [],
    teamId);

class PlayerStat {
  PlayerStat(this.id, this.name);
  final int id;
  final String name;
  final Set<String> teams = LinkedHashSet();
  int events = 0, acc = 0, dec = 0, nr = 0;

  /// yes, no or none per event, newest first.
  final List<String> recent = [];
  final List<DateTime> dates = [];
  int rate = 0;

  /// Second half of the period minus the first half.
  int? delta;
}

/// Per-player numbers across a set of events (newest first).
Map<int, PlayerStat> playerStats(List<AnEvent> evs) {
  final map = <int, PlayerStat>{};
  for (final e in evs) {
    for (final m in e.members) {
      final p = map.putIfAbsent(
          m.id, () => PlayerStat(m.id, m.name.isEmpty ? 'Player' : m.name));
      p.teams.add(e.teamName);
      p.events++;
      final c = m.response == 'accepted'
          ? 'yes'
          : m.response == 'declined'
              ? 'no'
              : 'none';
      if (c == 'yes') {
        p.acc++;
      } else if (c == 'no') {
        p.dec++;
      } else {
        p.nr++;
      }
      p.recent.add(c);
      p.dates.add(e.date);
    }
  }
  for (final p in map.values) {
    p.rate = pctOf(p.acc, p.events);
  }
  return map;
}

/// Compares each player's first half of the period with the second half.
void movers(AnCtx ctx, Map<int, PlayerStat> stats) {
  final evs = ctx.evs;
  if (evs.length < 4) return;
  final start = ctx.r.from ?? evs.last.date;
  final mid = DateTime.fromMillisecondsSinceEpoch(
      (start.millisecondsSinceEpoch + ctx.r.to.millisecondsSinceEpoch) ~/ 2);
  for (final p in stats.values) {
    var a1 = 0, n1 = 0, a2 = 0, n2 = 0;
    for (var i = 0; i < p.dates.length; i++) {
      final yes = p.recent[i] == 'yes';
      if (p.dates[i].isBefore(mid)) {
        n1++;
        if (yes) a1++;
      } else {
        n2++;
        if (yes) a2++;
      }
    }
    if (n1 >= 2 && n2 >= 2) p.delta = pctOf(a2, n2) - pctOf(a1, n1);
  }
}

class AnMonth {
  const AnMonth(this.d, this.evs, this.pct);
  final DateTime d;
  final List<AnEvent> evs;

  /// Null for a month with no events.
  final int? pct;
}

/// Up to the last 12 months of the period.
List<AnMonth> months(AnCtx ctx) {
  final now = ctx.r.to;
  final first = ctx.r.from ?? (ctx.evs.isNotEmpty ? ctx.evs.last.date : now);
  final list = <DateTime>[];
  for (var d = DateTime(first.year, first.month, 1);
      !d.isAfter(now);
      d = DateTime(d.year, d.month + 1, 1)) {
    list.add(d);
  }
  final last = list.length > 12 ? list.sublist(list.length - 12) : list;
  return [
    for (final d in last)
      () {
        final evs = ctx.evs
            .where((e) => e.date.year == d.year && e.date.month == d.month)
            .toList();
        return AnMonth(d, evs, evs.isEmpty ? null : totals(evs).pct);
      }()
  ];
}

/// "J" for long runs, "Jan" otherwise.
String monthLabel(DateTime d, int count) =>
    count > 6 ? kMon[d.month - 1][0] : kMon[d.month - 1];

class AnTrend {
  const AnTrend(this.diff, this.text);
  final int diff;
  final String text;
}

AnTrend? trendText(int? diff, String? prevLabel) {
  if (diff == null || prevLabel == null) return null;
  if (diff == 0) return AnTrend(0, 'Same as $prevLabel');
  return AnTrend(diff, '${diff > 0 ? '▲' : '▼'} ${diff.abs()}% on $prevLabel');
}

AnTrend? trendLine(AnCtx ctx, int cur) {
  if (ctx.prev.length < 3 || ctx.r.prevLabel == null) return null;
  return trendText(cur - totals(ctx.prev).pct, ctx.r.prevLabel);
}

// Event rows: "vs Raheny" for matches, the type otherwise (or a custom title).
String eventTitle(AnEvent e) {
  if (e.isMatch && e.opposition.isNotEmpty) return 'vs ${e.opposition}';
  final auto = '${e.rawCode} ${e.type}'.trim();
  if (e.title.isNotEmpty &&
      !e.title.startsWith(auto) &&
      !e.title.startsWith('Camogie ${e.type}')) {
    return e.title;
  }
  if (e.type.isNotEmpty) return e.type;
  return e.title.isNotEmpty ? e.title : 'Event';
}

/// Second line of an event row: team, type and home or away.
String eventMeta(AnEvent e, bool showTeam) {
  final title = eventTitle(e);
  return [
    if (showTeam) e.teamName,
    if (title != e.type && !(e.isMatch && e.opposition.isNotEmpty)) e.type,
    e.homeAway,
  ].where((s) => s.isNotEmpty).join(' · ');
}

/// "St Annes U12 · Football training · Sat 4 Oct 2026 · Home".
String eventSub(AnEvent e) {
  final d = e.date;
  final kind =
      [e.code ?? '', e.type].where((s) => s.isNotEmpty).join(' ').toLowerCase();
  return [
    e.teamName,
    kind.isEmpty ? '' : kind[0].toUpperCase() + kind.substring(1),
    '${kDow[d.weekday % 7]} ${d.day} ${kMon[d.month - 1]} ${d.year}',
    e.homeAway,
  ].where((s) => s.isNotEmpty).join(' · ');
}

bool multiCodeIn(List<AnEvent> evs) =>
    {for (final e in evs) e.codeKey}.length > 1;

class TeamRank {
  TeamRank(this.id, this.name, this.evs, this.t, this.tr, this.ma, this.players,
      this.trend);
  final int id;
  final String name;
  final List<AnEvent> evs;
  final AnTotals t;
  final AnTotals tr;
  final AnTotals ma;
  final int players;
  final int? trend;
}

const kTeamSorts = [
  ('att', 'Attendance'),
  ('reply', 'Replies'),
  ('trend', 'Trend'),
  ('az', 'A–Z'),
];

List<TeamRank> teamRanking(AnCtx ctx, String sort) {
  final by = <int, List<AnEvent>>{};
  for (final e in ctx.evs) {
    by.putIfAbsent(e.teamId, () => []).add(e);
  }
  final prevBy = <int, List<AnEvent>>{};
  for (final e in ctx.prev) {
    prevBy.putIfAbsent(e.teamId, () => []).add(e);
  }
  final list = [
    for (final en in by.entries)
      () {
        final evs = en.value, t = totals(evs), prev = prevBy[en.key] ?? [];
        return TeamRank(
            en.key,
            evs.first.teamName,
            evs,
            t,
            totals(evs.where((e) => e.isTraining)),
            totals(evs.where((e) => e.isMatch)),
            {
              for (final e in evs)
                for (final m in e.members) m.id
            }.length,
            prev.length >= 3 ? t.pct - totals(prev).pct : null);
      }()
  ];
  final sorters = <String, int Function(TeamRank, TeamRank)>{
    'att': (a, b) => b.t.pct - a.t.pct,
    'reply': (a, b) => b.t.replied - a.t.replied,
    'trend': (a, b) => (b.trend ?? -999) - (a.trend ?? -999),
    'az': (a, b) => _cmpText(a.name, b.name),
  };
  return stableSort(list, sorters[sort] ?? sorters['att']!);
}

// ------------------------------------------------------------------ players

const kPlayerSorts = [
  ('low', 'Lowest'),
  ('high', 'Highest'),
  ('dropping', 'Dropping'),
  ('rising', 'Rising'),
  ('noreply', 'No reply'),
];
const kTeamPlayerSorts = [
  ('low', 'Lowest first'),
  ('high', 'Highest first'),
  ('noreply', 'No reply'),
];

List<PlayerStat> sortPlayers(List<PlayerStat> list, String sort) {
  int cmpD(double a, double b) => a.compareTo(b);
  final by = <String, int Function(PlayerStat, PlayerStat)>{
    'low': (a, b) =>
        a.rate - b.rate != 0 ? a.rate - b.rate : b.events - a.events,
    'high': (a, b) =>
        b.rate - a.rate != 0 ? b.rate - a.rate : b.events - a.events,
    'dropping': (a, b) {
      final c = (a.delta ?? 999) - (b.delta ?? 999);
      return c != 0 ? c : a.rate - b.rate;
    },
    'rising': (a, b) {
      final c = (b.delta ?? -999) - (a.delta ?? -999);
      return c != 0 ? c : b.rate - a.rate;
    },
    'noreply': (a, b) {
      final c = cmpD(b.nr / b.events, a.nr / a.events);
      return c != 0 ? c : b.nr - a.nr;
    },
  };
  return stableSort(list, by[sort] ?? by['low']!);
}

/// The Players tab list: search, the sort's own cut, then the sort.
List<PlayerStat> playerList(Iterable<PlayerStat> all, String q, String sort) {
  final query = q.trim().toLowerCase();
  var list = query.isEmpty
      ? all.toList()
      : all.where((p) => p.name.toLowerCase().contains(query)).toList();
  if (sort == 'dropping') {
    list = list.where((p) => p.delta != null && p.delta! < 0).toList();
  }
  if (sort == 'rising') {
    list = list.where((p) => p.delta != null && p.delta! > 0).toList();
  }
  if (sort == 'noreply') list = list.where((p) => p.nr > 0).toList();
  return sortPlayers(list, sort);
}

enum BadgeKind { plain, warn, up, down }

class Badge {
  const Badge(this.text, this.kind);
  final String text;
  final BadgeKind kind;
}

List<Badge> playerBadges(PlayerStat p, String sort, bool showTeam) {
  final out = <Badge>[];
  if (showTeam) out.add(Badge(p.teams.join(', '), BadgeKind.plain));
  if (sort == 'noreply' || (p.events >= 3 && p.nr / p.events >= 0.5)) {
    out.add(Badge('No reply ${p.nr}', BadgeKind.warn));
  }
  final d = p.delta;
  if (d != null &&
      (d.abs() >= 15 || sort == 'dropping' || sort == 'rising') &&
      d != 0) {
    out.add(Badge('${d > 0 ? '▲' : '▼'} ${d.abs()}%',
        d > 0 ? BadgeKind.up : BadgeKind.down));
  }
  return out;
}

/// Under 50%, 50-69% and 70%+ player counts.
(int, int, int) spread(Iterable<PlayerStat> all) {
  var lo = 0, mid = 0, hi = 0;
  for (final p in all) {
    if (p.rate < 50) {
      lo++;
    } else if (p.rate < 70) {
      mid++;
    } else {
      hi++;
    }
  }
  return (lo, mid, hi);
}

// ------------------------------------------------------------------- squads

class SquadRow {
  SquadRow(this.id);
  final int id;
  final Set<int> events = {};
  final Map<int, int> members = {};
  int get places => members.values.fold(0, (a, b) => a + b);
}

class PickRow {
  const PickRow(this.id, this.name, this.total, this.m, this.of);
  final int id;
  final String name;
  final int total;
  final Map<int, int> m;
  final int of;
}

class DonutSeg {
  const DonutSeg(this.v, this.color, this.label, this.team);
  final int v;
  final Color color;
  final String label;
  final String team;
}

class SquadMonth {
  const SquadMonth(this.label, this.counts, this.total);
  final String label;

  /// squad id -> places.
  final Map<int, int> counts;
  final int total;
}

const kPickBuckets = [
  ('Never picked', Color(0xFFEF4444)),
  ('Under a third', Color(0xFFF97316)),
  ('A third to half', Color(0xFFF59E0B)),
  ('Over half', Color(0xFFA3D65C)),
  ('Every match', Color(0xFF87C232)),
];

class SquadModel {
  SquadModel(this.d, AnCtx ctx) {
    withPicks =
        ctx.evs.where((e) => e.members.any((m) => m.squadId != null)).toList();
    final teamIds = {for (final e in withPicks) e.teamId};
    pool =
        playerStats(ctx.evs.where((e) => teamIds.contains(e.teamId)).toList());
    for (final e in withPicks) {
      for (final m in e.members) {
        chances[m.id] = (chances[m.id] ?? 0) + 1;
        final s = m.squadId;
        if (s == null) continue;
        final pm = picks.putIfAbsent(m.id, () => {});
        pm[s] = (pm[s] ?? 0) + 1;
        final sq = squads.putIfAbsent(s, () => SquadRow(s));
        sq.events.add(e.id);
        sq.members[m.id] = (sq.members[m.id] ?? 0) + 1;
      }
    }
    for (final e in withPicks) {
      teamOf.putIfAbsent(e.teamId, () => e.teamName);
    }
  }

  final AnData d;
  late final List<AnEvent> withPicks;
  late final Map<int, PlayerStat> pool;

  /// member -> squad -> picks.
  final Map<int, Map<int, int>> picks = {};
  final Map<int, SquadRow> squads = {};

  /// How many picked matches each player was in the running for.
  final Map<int, int> chances = {};
  final Map<int, String> teamOf = {};

  String sqName(int id) => d.squads[id]?.name ?? 'Squad';
  int sqSeq(int id) => d.squads[id]?.seq ?? 999;
  Color sqHex(int id) => d.squads[id]?.hex ?? kSlate;

  // Name squads with their team when the view spans more than one team.
  String sqTeam(int id) =>
      teamOf.length > 1 ? teamOf[d.squads[id]?.teamId] ?? '' : '';
  String sqLabel(int id) => '${sqTeam(id)} ${sqName(id)}'.trim();
  String nameOf(int id) => pool[id]?.name ?? d.nameOf(id);

  int get picked => picks.length;
  int get poolN => pool.length;
  int get multi => picks.values.where((m) => m.length >= 2).length;

  List<PickRow> get most {
    final list = [
      for (final en in picks.entries)
        PickRow(
            en.key,
            nameOf(en.key),
            en.value.values.fold(0, (a, b) => a + b),
            en.value,
            chances[en.key] ?? 0)
    ];
    return stableSort(
        list,
        (a, b) =>
            b.total != a.total ? b.total - a.total : _cmpText(a.name, b.name));
  }

  List<PlayerStat> get unpicked => stableSort(
      pool.values.where((p) => !picks.containsKey(p.id)).toList(),
      (a, b) => b.rate - a.rate);

  List<SquadRow> get squadList => stableSort(squads.values.toList(), (a, b) {
        final t = _cmpText(sqTeam(a.id), sqTeam(b.id));
        if (t != 0) return t;
        final s = sqSeq(a.id) - sqSeq(b.id);
        if (s != 0) return s;
        return _cmpText(sqName(a.id), sqName(b.id));
      });

  /// Squad split donut: the biggest 7, the rest as Other.
  List<DonutSeg> donut(List<SquadRow> rows) {
    final bySize = stableSort([...rows], (a, b) => b.places - a.places);
    final segs = [
      for (final s in bySize.take(7))
        DonutSeg(s.places, sqHex(s.id), sqName(s.id), sqTeam(s.id))
    ];
    if (bySize.length > 7) {
      segs.add(DonutSeg(bySize.skip(7).fold(0, (t, s) => t + s.places), kSlate,
          '${bySize.length - 7} other squads', ''));
    }
    return segs;
  }

  /// Squad places by month, stacked by squad (empty under 2 months).
  List<SquadMonth> byMonth(AnCtx ctx) {
    final ms = months(ctx.withEvs(withPicks));
    if (ms.length < 2) return const [];
    return [
      for (final m in ms)
        () {
          final c = <int, int>{};
          for (final e in m.evs) {
            for (final x in e.members) {
              if (x.squadId != null) c[x.squadId!] = (c[x.squadId!] ?? 0) + 1;
            }
          }
          return SquadMonth(
              monthLabel(m.d, ms.length), c, c.values.fold(0, (a, b) => a + b));
        }()
    ];
  }

  /// Share of their team's picked matches each player was picked for.
  List<int> buckets() {
    final b = List.filled(kPickBuckets.length, 0);
    for (final pl in pool.values) {
      final of = chances[pl.id] ?? 0;
      if (of == 0) continue;
      final n = picks[pl.id]?.values.fold(0, (a, c) => a + c) ?? 0;
      final r = n / of;
      b[n == 0
          ? 0
          : r >= 1
              ? 4
              : r > 0.5
                  ? 3
                  : r >= 1 / 3
                      ? 2
                      : 1]++;
    }
    return b;
  }

  /// Squad entries in seq order, for a stacked bar.
  List<MapEntry<int, int>> ordered(Map<int, int> m, {bool desc = false}) =>
      stableSort(
          m.entries.toList(),
          (a, b) =>
              desc ? sqSeq(b.key) - sqSeq(a.key) : sqSeq(a.key) - sqSeq(b.key));
}

/// A PDF file name: accents dropped, everything else not a word char to -.
String pdfFileBase(String s) {
  const from = 'áàâäãÁÀÂÄÃéèêëÉÈÊËíìîïÍÌÎÏóòôöõÓÒÔÖÕúùûüÚÙÛÜñÑçÇ';
  const to = 'aaaaaAAAAAeeeeEEEEiiiiIIIIoooooOOOOOuuuuUUUUnNcC';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b
      .toString()
      .replaceAll(RegExp(r'[^\w]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}
