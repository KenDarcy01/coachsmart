// Session plan: the data model and pure helpers behind V3SessionPlanPage,
// the native copy of webviews/session-plan.html. No Flutter, no network, so
// it can be unit tested.
//
// The plan is kept as the raw plan_json map (session_plans.plan_json) so
// every field the edge function writes (weather, session_image, counts,
// club_id, date_time ...) survives an edit and a save untouched.

/// The generate-session-plan edge function (every action but the PDF).
const String kSpFn = 'generate-session-plan';

/// The PDF edge function.
const String kSpPdfFn = 'generate-session-plan-pdf';

/// The four optional single-card sections, in plan order around the drills.
const List<String> kSpPhases = [
  'pre_session',
  'warm_up',
  'cool_down',
  'post_session'
];

int? _iN(dynamic v) =>
    v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
String _s(dynamic v) => v == null ? '' : '$v';
List<String> _list(dynamic v) => [
      if (v is List)
        for (final e in v)
          if (e != null && '$e'.trim().isNotEmpty) '$e'.trim()
    ];

/// One of my favourite games, as the `get` action lists them.
class SpFavourite {
  SpFavourite({
    required this.gameId,
    required this.name,
    this.image = '',
    this.codes = const [],
    this.types = const [],
    this.checked = true,
  });

  factory SpFavourite.fromJson(Map j) => SpFavourite(
        gameId: _iN(j['game_id']) ?? 0,
        name: _s(j['game_name']),
        image: _s(j['game_image']),
        codes: _list(j['game_code']),
        types: _list(j['game_type']),
      );

  final int gameId;
  final String name, image;
  final List<String> codes, types;

  /// In the plan (the web checkbox); unchecked games are skipped.
  bool checked;
}

List<SpFavourite> parseFavourites(dynamic rows) => [
      if (rows is List)
        for (final r in rows)
          if (r is Map && _iN(r['game_id']) != null) SpFavourite.fromJson(r)
    ];

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'\s'), '');

/// Keeps favourites that suit the event's code (web boot()): a game with no
/// code always suits; when nothing matches, every favourite is kept.
List<SpFavourite> filterByEventCode(List<SpFavourite> favs, String eventCode) {
  final code = _norm(eventCode);
  if (code.isEmpty) return favs;
  final out = favs.where((f) {
    final codes = f.codes.map(_norm).toList();
    return codes.isEmpty ||
        codes.any((c) => code.contains(c) || c.contains(code));
  }).toList();
  return out.isEmpty ? favs : out;
}

/// The event, as the edge function describes it (null in library mode).
class SpEvent {
  const SpEvent(
      {this.title = '',
      this.dateTime,
      this.locationName = '',
      this.teamName = '',
      this.eventCode = ''});

  factory SpEvent.fromJson(Map j) => SpEvent(
        title: _s(j['title']),
        dateTime: DateTime.tryParse(_s(j['date_time']))?.toLocal(),
        locationName: _s(j['location_name']),
        teamName: _s(j['team_name']),
        eventCode: _s(j['event_code']),
      );

  final String title, locationName, teamName, eventCode;
  final DateTime? dateTime;
}

/// What the `get` action returns.
class SpLoad {
  SpLoad({
    this.planId,
    this.plan,
    this.clubId,
    this.event,
    this.squadName = '',
    this.favourites = const [],
    this.allowed,
  });

  factory SpLoad.fromJson(Map j) {
    final ev = j['event'];
    final br = j['branding'];
    final plan = j['plan'];
    return SpLoad(
      planId: j['plan_id'] == null ? null : '${j['plan_id']}',
      plan: plan is Map ? deepCopy(plan) : null,
      clubId: br is Map ? _iN(br['club_id']) : null,
      event: ev is Map ? SpEvent.fromJson(ev) : null,
      squadName: _s(j['squad_name']),
      favourites: parseFavourites(j['favourites']),
      allowed: j['session_plan_allowed'] is bool
          ? j['session_plan_allowed'] as bool
          : null,
    );
  }

  final String? planId;
  final Map<String, dynamic>? plan;
  final int? clubId;
  final SpEvent? event;
  final String squadName;
  final List<SpFavourite> favourites;

  /// teams.session_plan or users.ai_features; null when unknown (allowed).
  final bool? allowed;
}

/// The page's gate (web boot()): for an event whose team does not have
/// session plans switched on, only an existing plan may still be opened.
bool spIsOff({required int? eventId, required SpLoad load}) =>
    eventId != null && load.allowed == false && load.plan == null;

/// A saved plan in the picker (get_user_plans / get_club_plans).
class SpPlanSummary {
  const SpPlanSummary(
      {required this.planId,
      required this.title,
      this.createdAt,
      this.createdBy = '',
      this.isOwn = false});

  factory SpPlanSummary.fromJson(Map j) => SpPlanSummary(
        planId: '${j['plan_id']}',
        title: _s(j['session_title']).isEmpty
            ? 'Untitled Plan'
            : _s(j['session_title']),
        createdAt: DateTime.tryParse(_s(j['created_at']))?.toLocal(),
        createdBy: _s(j['created_by']),
        isOwn: j['is_own'] == true,
      );

  final String planId, title, createdBy;
  final DateTime? createdAt;
  final bool isOwn;
}

List<SpPlanSummary> parsePlanList(dynamic data) {
  final rows = data is Map ? data['plans'] : data;
  return [
    if (rows is List)
      for (final r in rows)
        if (r is Map && r['plan_id'] != null) SpPlanSummary.fromJson(r)
  ];
}

const _months = [
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

/// "3 Nov 2026" (en-IE short date, as the web picker shows it).
String spDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// "19:05".
String spClock(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// The grey line under a saved plan: the date, and for club plans who made
/// it ("You · 3 Nov 2026").
String spPlanMeta(SpPlanSummary p, {required bool club}) {
  final date = p.createdAt == null ? '' : spDate(p.createdAt!);
  if (!club) return date;
  final who = p.isOwn ? 'You' : p.createdBy;
  return who.isEmpty ? date : (date.isEmpty ? who : '$who · $date');
}

// ------------------------------------------------------------ plan helpers

/// A JSON-safe deep copy of a plan map.
Map<String, dynamic> deepCopy(Map m) =>
    {for (final e in m.entries) '${e.key}': _copy(e.value)};

dynamic _copy(dynamic v) {
  if (v is Map) return deepCopy(v);
  if (v is List) return [for (final x in v) _copy(x)];
  return v;
}

/// The value at a dotted path ("drills.2.setup"), or null.
dynamic getPath(Map plan, String path) {
  dynamic cur = plan;
  for (final k in path.split('.')) {
    final i = int.tryParse(k);
    if (cur is List && i != null) {
      cur = i >= 0 && i < cur.length ? cur[i] : null;
    } else if (cur is Map) {
      cur = cur[k];
    } else {
      return null;
    }
  }
  return cur;
}

/// Sets the value at a dotted path. Missing parents are left alone (as the
/// web collectEdits()).
void setPath(Map plan, String path, dynamic value) {
  final keys = path.split('.');
  dynamic cur = plan;
  for (var n = 0; n < keys.length - 1; n++) {
    final k = keys[n];
    final i = int.tryParse(k);
    if (cur is List && i != null && i >= 0 && i < cur.length) {
      cur = cur[i];
    } else if (cur is Map && cur[k] != null) {
      cur = cur[k];
    } else {
      return;
    }
  }
  final last = keys.last;
  final i = int.tryParse(last);
  if (cur is List && i != null && i >= 0 && i < cur.length) {
    cur[i] = value;
  } else if (cur is Map) {
    cur[last] = value;
  }
}

/// One card of the plan, in running order.
class SpSection {
  const SpSection(this.path, this.label, this.tone, {this.drill});

  /// The plan key ("warm_up") or "drills.<i>".
  final String path;

  /// "WARM UP", "DRILL 2" ...
  final String label;

  /// 'warm', 'drill' or 'cool': the dot colour.
  final String tone;

  /// 0-based drill index for drills.
  final int? drill;
}

List<Map<String, dynamic>> spDrills(Map plan) => [
      if (plan['drills'] is List)
        for (final d in plan['drills'] as List)
          if (d is Map) d.cast<String, dynamic>()
    ];

/// The plan's cards in running order (web renderPlan()).
List<SpSection> planSections(Map plan) {
  final out = <SpSection>[];
  if (plan['pre_session'] is Map) {
    out.add(const SpSection('pre_session', 'PRE-SESSION', 'warm'));
  }
  if (plan['warm_up'] is Map) {
    out.add(const SpSection('warm_up', 'WARM UP', 'warm'));
  }
  final drills = spDrills(plan);
  for (var i = 0; i < drills.length; i++) {
    out.add(SpSection('drills.$i', 'DRILL ${i + 1}', 'drill', drill: i));
  }
  if (plan['cool_down'] is Map) {
    out.add(const SpSection('cool_down', 'COOL DOWN', 'cool'));
  }
  if (plan['post_session'] is Map) {
    out.add(const SpSection('post_session', 'POST-SESSION', 'cool'));
  }
  return out;
}

/// duration_mins of a section, 0 when missing.
int durationOf(Map plan, String path) =>
    _iN(getPath(plan, '$path.duration_mins')) ?? 0;

/// Sum of every section's minutes (the edge function's own rule).
int sumDurations(Map plan) =>
    planSections(plan).fold(0, (t, s) => t + durationOf(plan, s.path));

/// Changes one section's minutes and makes the total add up again.
void setDuration(Map plan, String path, int mins) {
  setPath(plan, '$path.duration_mins', mins < 0 ? 0 : mins);
  final total = sumDurations(plan);
  if (total > 0) plan['total_duration_mins'] = total;
}

/// When each section starts, from the event start (sections run one after
/// another; their minutes add up to the session length).
Map<String, DateTime> sectionStarts(Map plan, DateTime? start) {
  if (start == null) return const {};
  final out = <String, DateTime>{};
  var t = start;
  for (final s in planSections(plan)) {
    out[s.path] = t;
    t = t.add(Duration(minutes: durationOf(plan, s.path)));
  }
  return out;
}

/// Moves a drill (the order of play).
void moveDrill(Map plan, int from, int to) {
  final list = plan['drills'];
  if (list is! List || from < 0 || from >= list.length) return;
  if (to < 0 || to >= list.length || to == from) return;
  final d = list.removeAt(from);
  list.insert(to, d);
}

/// Takes a drill out and makes the total add up again.
void removeDrill(Map plan, int i) {
  final list = plan['drills'];
  if (list is! List || i < 0 || i >= list.length) return;
  list.removeAt(i);
  final total = sumDurations(plan);
  if (total > 0) plan['total_duration_mins'] = total;
}

/// The weather icon the web page picks.
String weatherIcon(Map w) {
  final p = (w['precip_pct'] is num) ? (w['precip_pct'] as num) : 0;
  final t = (w['temp_c'] is num) ? (w['temp_c'] as num) : 15;
  if (p >= 60) return '🌧';
  if (t < 5) return '🥶';
  if (t < 12) return '🌤';
  return '☀️';
}

/// Coaching points of a section as text.
List<String> coachingPoints(Map plan, String path) => [
      for (final p in (getPath(plan, '$path.coaching_points') as List? ?? []))
        '$p'
    ];

// ------------------------------------------------------------ request bodies

Map<String, dynamic> getBody(int? eventId) =>
    {'action': 'get', if (eventId != null) 'event_id': eventId};

Map<String, dynamic> generateBody({
  required int? eventId,
  required String? planId,
  required int minutes,
  required List<int> gameIds,
  required bool rotate,
}) =>
    {
      'action': 'generate',
      'event_id': eventId,
      'plan_id': planId,
      'duration_mins': minutes,
      'game_ids': gameIds,
      'rotate_stations': rotate,
    };

Map<String, dynamic> reviseBody({
  required int? eventId,
  required String? planId,
  required String feedback,
  required Map plan,
}) =>
    {
      'action': 'revise_plan',
      'event_id': eventId,
      'plan_id': planId,
      'feedback': feedback,
      'existing_plan': plan,
    };

Map<String, dynamic> updateBody(
        {required int? eventId, required String planId, required Map plan}) =>
    {
      'action': 'update_plan',
      'event_id': eventId,
      'plan_id': planId,
      'plan_json': plan,
    };

/// Minutes stepper bounds on the setup screen (web adjustDur()).
int clampSessionMinutes(int m) => m < 15 ? 15 : (m > 180 ? 180 : m);

/// The message to show for a failed call: the server's own words when it
/// gave any (web: data.message || data.error).
String spErrorText(dynamic data, String fallback) {
  if (data is Map) {
    final m = data['message'] ?? data['error'];
    if (m != null && '$m'.trim().isNotEmpty && '$m' != 'no_favourites') {
      return '$m';
    }
  }
  return fallback;
}
