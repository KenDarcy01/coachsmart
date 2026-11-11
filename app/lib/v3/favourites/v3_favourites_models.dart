// Favourites and AI session plans: the pure data and rules behind the
// native copy of webviews/favourites.html (main). No Flutter, no network,
// so every rule here is unit tested.
import 'dart:convert';

/// Exports and plan builds take at most this many games (keeps the PDF
/// inside the server's time limit). Only the first 10 start picked.
const int kMaxGames = 10;

int _i(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0);
int? _iN(dynamic v) => v == null ? null : int.tryParse('$v');

List<String> _strings(dynamic v) => v is List
    ? [
        for (final e in v)
          if (e != null && '$e'.trim().isNotEmpty) '$e'.trim()
      ]
    : const [];

/// One favourite from generate-session-plan `get` (user_game_link + games).
class FavGame {
  const FavGame({
    required this.gameId,
    required this.name,
    this.image = '',
    this.codes = const [],
    this.types = const [],
    this.ages = const [],
    this.hasVideo = false,
  });

  factory FavGame.fromJson(Map j) => FavGame(
        gameId: _i(j['game_id']),
        name: '${j['game_name'] ?? ''}',
        image: '${j['game_image'] ?? ''}'.trim(),
        codes: _strings(j['game_code']),
        types: _strings(j['game_type']),
        ages: _strings(j['game_age']),
        hasVideo: j['has_video'] == true,
      );

  final int gameId;
  final String name, image;
  final List<String> codes, types, ages;
  final bool hasVideo;
}

/// The `favourites` list of a `get` response.
List<FavGame> parseFavourites(dynamic data) {
  final list = data is Map ? data['favourites'] : data;
  if (list is! List) return const [];
  return [
    for (final f in list)
      if (f is Map) FavGame.fromJson(f)
  ];
}

const List<String> kTypeOrder = ['warmup', 'drill', 'skills', 'skill', 'game'];
const Map<String, String> kTypeLabel = {
  'warmup': 'Warm-up',
  'drill': 'Drill',
  'skills': 'Skills',
  'skill': 'Skills',
  'game': 'Game',
};
const Map<String, String> kTypeChip = {
  'warmup': 'Warm-ups',
  'drill': 'Drills',
  'skills': 'Skills',
  'skill': 'Skills',
  'game': 'Games',
};

/// The known types of a game, lower case, in its own order.
List<String> favTypes(List<String> types) => [
      for (final t in types)
        if (kTypeLabel.containsKey(t.toLowerCase())) t.toLowerCase()
    ];

/// "U8–U12" from ['u8','u10','u12']; '' when the list has no ages.
String ageText(List<String> ages) {
  final n = <int>[
    for (final a in ages)
      if (int.tryParse(a.replaceAll(RegExp(r'\D'), '')) != null)
        int.parse(a.replaceAll(RegExp(r'\D'), ''))
  ];
  if (n.isEmpty) return '';
  n.sort();
  return n.first == n.last ? 'U${n.first}' : 'U${n.first}–U${n.last}';
}

/// A small tag under a game name; [type] tags are green.
typedef FavTag = ({String text, bool type});

/// Type, ages, code ('Both codes' for more than one) and video, as the page
/// tags each card.
List<FavTag> favTags(
    {required List<String> types,
    required List<String> ages,
    required List<String> codes,
    bool hasVideo = false}) {
  final out = <FavTag>[];
  final t = favTypes(types);
  if (t.isNotEmpty) out.add((text: kTypeLabel[t.first]!, type: true));
  final age = ageText(ages);
  if (age.isNotEmpty) out.add((text: age, type: false));
  if (codes.isNotEmpty) {
    out.add((text: codes.length > 1 ? 'Both codes' : codes.first, type: false));
  }
  if (hasVideo) out.add((text: '▶ Video', type: false));
  return out;
}

List<FavTag> tagsOf(FavGame f) =>
    favTags(types: f.types, ages: f.ages, codes: f.codes, hasVideo: f.hasVideo);

/// Filter keys: 'all', 'type:<chip>' or 'code:<code>'.
bool favMatches(FavGame f, String filter) {
  if (filter == 'all') return true;
  final i = filter.indexOf(':');
  final k = filter.substring(0, i), v = filter.substring(i + 1);
  if (k == 'type') return favTypes(f.types).any((t) => kTypeChip[t] == v);
  return f.codes.contains(v);
}

typedef FavChip = ({String key, String label});

/// The filter chips, 'All' first. Empty when they would not split the list
/// (fewer than 5 favourites, or one type and one code).
List<FavChip> favChips(List<FavGame> favs) {
  final types = <String>{}, codes = <String>{};
  for (final f in favs) {
    for (final t in favTypes(f.types)) {
      types.add(kTypeChip[t]!);
    }
    codes.addAll(f.codes);
  }
  final typeChips = <String>[];
  for (final t in kTypeOrder) {
    final c = kTypeChip[t]!;
    if (types.contains(c) && !typeChips.contains(c)) typeChips.add(c);
  }
  final chips = <FavChip>[];
  if (typeChips.length > 1) {
    for (final c in typeChips) {
      chips.add((key: 'type:$c', label: c));
    }
  }
  if (codes.length > 1) {
    for (final c in (codes.toList()..sort())) {
      chips.add((key: 'code:$c', label: c));
    }
  }
  if (favs.length < 5 || chips.isEmpty) return const [];
  return [(key: 'all', label: 'All'), ...chips];
}

/// The games picked when the list loads: the first [kMaxGames].
List<int> initialPicks(List<FavGame> favs) =>
    [for (final f in favs.take(kMaxGames)) f.gameId];

/// The count line over the meter: [bold] then [rest].
({String bold, String rest}) pickCountText(int n, int total) {
  if (n >= kMaxGames) return (bold: '$n picked', rest: " · that's the limit");
  if (total > kMaxGames)
    return (bold: '$n picked', rest: ' · up to $kMaxGames');
  return (bold: '$n of $total', rest: ' picked');
}

/// How full the meter is, 0 to 1.
double pickMeter(int n, int total) {
  final cap = total < 1 ? 1 : (total > kMaxGames ? kMaxGames : total);
  final v = n / cap;
  return v > 1 ? 1 : v;
}

String _games(int n) => '$n game${n == 1 ? '' : 's'}';

String buildPlanLabel(int n) =>
    n > 0 ? 'Build plan with ${_games(n)}' : 'Pick games to build a plan';

/// 'PDF' beside the Build button when AI is on; otherwise the full label.
String exportLabel(int n, bool ai) =>
    ai ? 'PDF' : (n > 0 ? 'Export ${_games(n)}' : 'Export Games');

/// The picked order after the coach drags [from] to [to] in [shown] (the
/// picked games the filter shows). Picked games the filter hides keep their
/// slots.
List<int> reorderPicked(List<int> picked, List<int> shown, int from, int to) {
  final s = [...shown];
  final moved = s.removeAt(from);
  s.insert(to.clamp(0, s.length), moved);
  final set = s.toSet();
  var k = 0;
  return [for (final id in picked) set.contains(id) ? s[k++] : id];
}

// ------------------------------------------------------------- session plans

const Map<String, String> kPhaseLabels = {
  'pre_session': 'Pre-session',
  'warm_up': 'Warm up',
  'cool_down': 'Cool down',
  'post_session': 'Post-session',
};

/// A deep copy of a plan (plain JSON maps and lists).
Map<String, dynamic> copyPlan(Map plan) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(plan)) as Map);

/// A section's text for comparing, without its picture and video.
String sectionText(dynamic p) {
  if (p == null) return '';
  if (p is! Map) return '$p';
  final rest = Map.of(p)
    ..remove('game_image')
    ..remove('game_video');
  return jsonEncode(rest);
}

/// What a revision changed: [changed] maps a section path to its old
/// duration (null when the duration did not change); [list] names each.
class PlanChanges {
  const PlanChanges(this.changed, this.list);
  final Map<String, int?> changed;
  final List<String> list;
  bool has(String path) => changed.containsKey(path);
}

PlanChanges diffPlans(Map before, Map after) {
  final map = <String, int?>{};
  final list = <String>[];
  void add(String key, String label, dynamic b, dynamic a) {
    if (sectionText(b) == sectionText(a)) return;
    int? was;
    if (b is Map &&
        a is Map &&
        '${b['duration_mins']}' != '${a['duration_mins']}') {
      was = _iN(b['duration_mins']);
    }
    map[key] = was;
    list.add(label);
  }

  add('session_objective', 'Focus', before['session_objective'],
      after['session_objective']);
  add('station_setup', 'Station setup', before['station_setup'],
      after['station_setup']);
  for (final k in ['pre_session', 'warm_up']) {
    add(k, kPhaseLabels[k]!, before[k], after[k]);
  }
  final bd = before['drills'] is List ? before['drills'] as List : const [];
  final ad = after['drills'] is List ? after['drills'] as List : const [];
  for (var i = 0; i < ad.length; i++) {
    final d = ad[i];
    final name = d is Map ? '${d['game_name'] ?? ''}' : '';
    dynamic old = i < bd.length ? bd[i] : null;
    for (final o in bd) {
      if (o is Map && name.isNotEmpty && '${o['game_name']}' == name) {
        old = o;
        break;
      }
    }
    add('drills.$i', name.isNotEmpty ? name : 'Drill ${i + 1}', old, d);
  }
  for (final k in ['cool_down', 'post_session']) {
    add(k, kPhaseLabels[k]!, before[k], after[k]);
  }
  return PlanChanges(map, list);
}

/// Writes [value] at a dotted path ('drills.0.coaching_points.2'). Does
/// nothing when a step on the way is missing, as the page does.
void setPlanPath(Map plan, String path, String value) {
  final keys = path.split('.');
  dynamic obj = plan;
  for (var i = 0; i < keys.length - 1; i++) {
    final idx = int.tryParse(keys[i]);
    if (idx != null) {
      if (obj is! List || idx >= obj.length) return;
      obj = obj[idx];
    } else {
      if (obj is! Map || obj[keys[i]] == null) return;
      obj = obj[keys[i]];
    }
  }
  final last = keys.last, idx = int.tryParse(last);
  if (idx != null) {
    if (obj is List && idx < obj.length) obj[idx] = value;
  } else if (obj is Map) {
    obj[last] = value;
  }
}

/// The name a Change panel uses for a section.
String sectionName(Map plan, String path) {
  if (path.startsWith('drills.')) {
    final i = int.parse(path.split('.')[1]);
    final d = plan['drills'] is List && i < (plan['drills'] as List).length
        ? plan['drills'][i]
        : null;
    final n = d is Map ? '${d['game_name'] ?? ''}' : '';
    return n.isNotEmpty ? n : 'Drill ${i + 1}';
  }
  final p = plan[path];
  final n = p is Map ? '${p['game_name'] ?? ''}' : '';
  return n.isNotEmpty ? n : (kPhaseLabels[path] ?? path);
}

/// Which plan buttons show and what the save pill says.
class PlanBar {
  const PlanBar(
      {required this.save,
      required this.share,
      required this.remove,
      this.pill});
  final bool save, share, remove;

  /// 'Saved', 'Unsaved changes', 'Not saved', or null for no pill.
  final String? pill;
}

/// A new plan is "Not saved" until saved; a saved plan shows "Saved", or
/// "Unsaved changes" once it is edited or revised.
PlanBar planBar(
    {required int? planId,
    required bool isDraft,
    required bool isOwn,
    required bool isShared,
    required bool isDirty}) {
  final isSaved = planId != null && !isDraft;
  final settled = isOwn && isSaved && !isDirty;
  return PlanBar(
    save: isOwn ? (!isSaved || isDirty) : isDirty,
    share: settled && !isShared,
    remove: settled && isShared,
    pill: !isOwn && !isDirty
        ? null
        : (isSaved && !isDirty
            ? 'Saved'
            : (isSaved ? 'Unsaved changes' : 'Not saved')),
  );
}

/// Optional player count: null is "—"; + starts at 15; under 4 clears it;
/// at most 60.
int? adjustPlayers(int? players, int d) {
  if (players == null) return d > 0 ? 15 : null;
  final n = players + d;
  if (n < 4) return null;
  return n > 60 ? 60 : n;
}

/// Session length in 5 minute steps, 15 to 180.
int adjustDuration(int dur, int d) => (dur + d).clamp(15, 180);

/// One plan in My Plans or Club Plans.
class SavedPlan {
  const SavedPlan({
    required this.planId,
    required this.title,
    this.createdAt,
    this.clubId,
    this.isOwn = true,
    this.createdBy = '',
  });

  factory SavedPlan.fromJson(Map j) => SavedPlan(
        planId: _i(j['plan_id']),
        title: '${j['session_title'] ?? ''}',
        createdAt: DateTime.tryParse('${j['created_at'] ?? ''}')?.toLocal(),
        clubId: _iN(j['club_id']),
        isOwn: j['is_own'] != false,
        createdBy: '${j['created_by'] ?? ''}',
      );

  final int planId;
  final String title;
  final DateTime? createdAt;
  final int? clubId;
  final bool isOwn;
  final String createdBy;

  SavedPlan unshared() => SavedPlan(
      planId: planId,
      title: title,
      createdAt: createdAt,
      isOwn: isOwn,
      createdBy: createdBy);
}

List<SavedPlan> parsePlans(dynamic data) {
  final list = data is Map ? data['plans'] : null;
  if (list is! List) return const [];
  return [
    for (final p in list)
      if (p is Map) SavedPlan.fromJson(p)
  ];
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "11 Nov 2026", as en-IE writes a short date.
String planDate(DateTime? d) =>
    d == null ? '' : '${d.day} ${_months[d.month - 1]} ${d.year}';

/// The text of a list of coaching points.
List<String> pointsOf(dynamic p) => p is List
    ? [
        for (final e in p)
          if (e != null) '$e'
      ]
    : const [];

/// A non-blank string field of a plan section, or ''.
String textOf(dynamic section, String key) {
  if (section is! Map) return '';
  final v = section[key];
  return v == null ? '' : '$v'.trim();
}

/// Duration in minutes, or null.
int? minsOf(dynamic section) =>
    section is Map ? _iN(section['duration_mins']) : null;
