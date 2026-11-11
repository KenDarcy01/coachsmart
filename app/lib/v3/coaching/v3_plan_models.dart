// Rules for the plan builder, the Plans list and the event's "Session plan"
// entry of the v3 Coaching tab (proposal approved by Ken 2026-11-11).
// Pure Dart: no Flutter, no network, so every rule is unit tested.
//
// A plan is the same plan_json the generate-session-plan edge function
// writes (session_plans.plan_json), so a plan built here opens in the plan
// screen, the old app and the PDF function unchanged.
import '../games/v3_game_models.dart';
import 'v3_plan_draft.dart';

int? _iN(dynamic v) =>
    v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
String _s(dynamic v) => v == null ? '' : '$v';

// ------------------------------------------------------------------ steppers

/// Session length: 15 to 180 minutes in 5-minute steps.
int stepLength(int mins, int dir) {
  final n = dir > 0 ? (mins ~/ 5) * 5 + 5 : ((mins - 1) ~/ 5) * 5;
  return n < 15 ? 15 : (n > 180 ? 180 : n);
}

/// A game's minutes: 5 to 120 in 5-minute steps (an odd value snaps to the
/// next step in the direction tapped).
int stepGameMins(int mins, int dir) {
  final n = dir > 0 ? (mins ~/ 5) * 5 + 5 : ((mins - 1) ~/ 5) * 5;
  return n < 5 ? 5 : (n > 120 ? 120 : n);
}

/// Optional player count: null shows "—"; + starts at 15; under 4 clears
/// it; at most 60 (the rule the old setup screen had).
int? stepPlayers(int? players, int dir) {
  if (players == null) return dir > 0 ? 15 : null;
  final n = players + dir;
  if (n < 4) return null;
  return n > 60 ? 60 : n;
}

/// The line under "Games, in order": the games' minutes against the session
/// length. [over] is true when the games run longer than the session.
({String text, String hint, bool over}) minutesLine(int total, int length) {
  final text = '$total of $length min';
  if (total > length) {
    return (text: text, hint: '${total - length} min over', over: true);
  }
  if (total < length) {
    return (text: text, hint: '${length - total} min to spare', over: false);
  }
  return (text: text, hint: 'Fills the session', over: false);
}

/// "1 game", "5 games".
String gamesCount(int n) => '$n game${n == 1 ? '' : 's'}';

// -------------------------------------------------------------------- events

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "Tue 17 Nov".
String planDay(DateTime d) =>
    '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

/// "19:05".
String planClock(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// The event a plan is for (events row with its team).
class PlanEvent {
  const PlanEvent({
    required this.eventId,
    this.title = '',
    this.start,
    this.end,
    this.teamId,
    this.teamName = '',
  });

  /// From `events` with `teams(team_name)` embedded.
  factory PlanEvent.fromJson(Map j) {
    final t = j['teams'];
    return PlanEvent(
      eventId: _iN(j['event_id']) ?? 0,
      title: _s(j['event_title']).trim(),
      start: DateTime.tryParse(_s(j['event_date_time']))?.toLocal(),
      end: DateTime.tryParse(_s(j['event_date_time_2']))?.toLocal(),
      teamId: _iN(j['team_id']),
      teamName: t is Map ? _s(t['team_name']).trim() : '',
    );
  }

  final int eventId;
  final String title, teamName;
  final DateTime? start, end;
  final int? teamId;

  /// "Tue 17 Nov · 19:00 · U12 Boys".
  String get line => [
        if (start != null) planDay(start!),
        if (start != null) planClock(start!),
        if (teamName.isNotEmpty) teamName,
      ].join(' · ');

  /// The event's own length in minutes, rounded to 5 and kept inside the
  /// stepper's range; null when it has no end time.
  int? get lengthMins {
    if (start == null || end == null) return null;
    final m = end!.difference(start!).inMinutes;
    if (m <= 0) return null;
    final r = ((m + 2) ~/ 5) * 5;
    return r < 15 ? 15 : (r > 180 ? 180 : r);
  }
}

/// Players marked as attending, from get_event_attendance_v3 (the same
/// rule the edge function applies: a coach is not a player). Null when
/// nobody has replied yet.
int? attendingPlayers(dynamic rpc) {
  final members = rpc is Map ? rpc['members'] : null;
  if (members is! List) return null;
  final coach = <int>{}, going = <int>{};
  for (final m in members) {
    if (m is! Map) continue;
    final id = _iN(m['member_id']);
    if (id == null || _iN(m['response_id']) != 3) continue;
    going.add(id);
    if ((_iN(m['role_level']) ?? 0) >= 30) coach.add(id);
  }
  final n = going.difference(coach).length;
  return n > 0 ? n : null;
}

// --------------------------------------------------------------- simple plan

/// A game's teaching points as short lines (the edge function's own
/// parseCoachingPoints: split on new lines and bullets, drop scraps).
List<String> parseCoachingPoints(String text) => [
      for (final p in text.split(RegExp(r'\n|(?:^|\s)[•·–\-]\s')))
        if (p.replaceFirst(RegExp(r'^[•·–\-]\s*'), '').trim().length > 2)
          p.replaceFirst(RegExp(r'^[•·–\-]\s*'), '').trim()
    ];

String? _orNull(String s) => s.trim().isEmpty ? null : s.trim();

/// "Keep it simple": a plan made on the phone, with no AI, in the shape the
/// server's plans have. One drill per game, in order, with the game's own
/// words; no warm-up, cool-down or station text (those are AI-written).
/// The coach's note, when there is one, is the plan's focus.
///
/// [details] holds the games' text and pictures by id; a game missing from
/// it still gets its name and minutes.
Map<String, dynamic> buildSimplePlan({
  required String title,
  required List<PlanDraftGame> games,
  Map<int, V3Game> details = const {},
  int? players,
  String notes = '',
}) {
  final drills = <Map<String, dynamic>>[];
  for (final g in games) {
    final d = details[g.gameId];
    drills.add({
      'game_name': d != null && d.name.trim().isNotEmpty ? d.name : g.name,
      'duration_mins': g.mins,
      'setup': d == null ? null : _orNull(d.setup),
      'description': d?.howToPlay.trim() ?? '',
      'coaching_points':
          d == null ? <String>[] : parseCoachingPoints(d.teachingPoints),
      'variation': d == null ? null : _orNull(d.variations),
      'game_image': d == null ? null : _orNull(d.image),
      'game_video': d == null ? null : _orNull(d.video),
    });
  }
  return {
    'session_title': title.trim().isEmpty ? 'Training plan' : title.trim(),
    'session_objective': notes.trim(),
    'total_duration_mins': games.fold<int>(0, (t, g) => t + g.mins),
    if (players != null) 'player_count': players,
    'pre_session': null,
    'warm_up': null,
    'station_setup': null,
    'drills': drills,
    'cool_down': null,
    'post_session': null,
  };
}

// ---------------------------------------------------------------- plans list

/// One row of the Plans list.
class PlanItem {
  const PlanItem({
    required this.planId,
    required this.title,
    this.createdAt,
    this.minutes,
    this.games,
    this.shared = false,
    this.isOwn = true,
    this.createdBy = '',
    this.event,
  });

  final String planId, title, createdBy;
  final DateTime? createdAt;

  /// From the plan itself; null when not known.
  final int? minutes, games;

  /// Shared with the coach's club.
  final bool shared;
  final bool isOwn;

  /// The event the plan is on; null for a reusable plan.
  final PlanEvent? event;
}

/// "3 Nov 2026".
String planDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// The grey line under a plan's title: "Tue 17 Nov · U12 Boys · 60 min ·
/// 5 games" on an event, "60 min · 5 games · shared with club" for a
/// reusable plan (its date when the minutes are not known).
String planLine(PlanItem p) {
  final e = p.event;
  return [
    if (e?.start != null) planDay(e!.start!),
    if (e != null && e.teamName.isNotEmpty) e.teamName,
    if (p.minutes != null && p.minutes! > 0) '${p.minutes} min',
    if (p.games != null && p.games! > 0) gamesCount(p.games!),
    if (e == null && (p.minutes ?? 0) <= 0 && p.createdAt != null)
      planDate(p.createdAt!),
    if (e == null && p.shared) 'shared with club',
  ].join(' · ');
}

/// The line under a club plan: who shared it and when.
String clubPlanLine(PlanItem p) => [
      p.isOwn ? 'You' : (p.createdBy.isEmpty ? 'A coach' : p.createdBy),
      if (p.createdAt != null) planDate(p.createdAt!),
    ].join(' · ');

int? _planMinutes(dynamic plan) {
  if (plan is! Map) return null;
  final t = _iN(plan['total_duration_mins']);
  return t != null && t > 0 ? t : null;
}

/// Every game in the plan: the drills plus a warm-up or cool-down game.
int? _planGames(dynamic plan) {
  if (plan is! Map) return null;
  var n = plan['drills'] is List ? (plan['drills'] as List).length : 0;
  for (final k in ['warm_up', 'cool_down']) {
    final s = plan[k];
    if (s is Map && _s(s['game_name']).trim().isNotEmpty) n++;
  }
  return n;
}

/// "On events": my active plans that sit on an event, from session_plans
/// rows with `events` embedded. Newest event first (so what is coming up
/// leads); one row per event (the newest plan wins).
List<PlanItem> eventPlanItems(dynamic rows) {
  final out = <PlanItem>[];
  final seen = <int>{};
  if (rows is! List) return out;
  final sorted = [
    for (final r in rows)
      if (r is Map && r['plan_id'] != null && r['events'] is Map) r
  ]..sort((a, b) => _s(b['created_at']).compareTo(_s(a['created_at'])));
  for (final r in sorted) {
    final e = PlanEvent.fromJson(r['events'] as Map);
    if (!seen.add(e.eventId)) continue;
    final title = e.title.isNotEmpty ? e.title : _s(r['session_title']).trim();
    out.add(PlanItem(
      planId: '${r['plan_id']}',
      title: title.isEmpty ? 'Training plan' : title,
      createdAt: DateTime.tryParse(_s(r['created_at']))?.toLocal(),
      minutes: _planMinutes(r['plan_json']),
      games: _planGames(r['plan_json']),
      event: e,
    ));
  }
  final never = DateTime.fromMillisecondsSinceEpoch(0);
  out.sort(
      (a, b) => (b.event?.start ?? never).compareTo(a.event?.start ?? never));
  return out;
}

/// "Reusable": get_user_plans, in the server's order, with each plan's
/// minutes and games filled in from [rows] (my own session_plans rows) when
/// they could be read.
List<PlanItem> reusablePlanItems(dynamic userPlans, [dynamic rows]) {
  final list = userPlans is Map ? userPlans['plans'] : userPlans;
  final byId = <String, Map>{
    if (rows is List)
      for (final r in rows)
        if (r is Map && r['plan_id'] != null) '${r['plan_id']}': r
  };
  return [
    if (list is List)
      for (final p in list)
        if (p is Map && p['plan_id'] != null)
          PlanItem(
            planId: '${p['plan_id']}',
            title: _s(p['session_title']).trim().isEmpty
                ? 'Untitled plan'
                : _s(p['session_title']).trim(),
            createdAt: DateTime.tryParse(_s(p['created_at']))?.toLocal(),
            shared: p['club_id'] != null,
            minutes: _planMinutes(byId['${p['plan_id']}']?['plan_json']),
            games: _planGames(byId['${p['plan_id']}']?['plan_json']),
          )
  ];
}

/// The Club list: get_club_plans.
List<PlanItem> clubPlanItems(dynamic clubPlans) {
  final list = clubPlans is Map ? clubPlans['plans'] : clubPlans;
  return [
    if (list is List)
      for (final p in list)
        if (p is Map && p['plan_id'] != null)
          PlanItem(
            planId: '${p['plan_id']}',
            title: _s(p['session_title']).trim().isEmpty
                ? 'Untitled plan'
                : _s(p['session_title']).trim(),
            createdAt: DateTime.tryParse(_s(p['created_at']))?.toLocal(),
            shared: true,
            isOwn: p['is_own'] == true,
            createdBy: _s(p['created_by']).trim(),
          )
  ];
}

/// "Repeat last session's plan": my most recent plan on an earlier event of
/// the same team as [event]. Null when there is none.
PlanItem? lastSessionPlan(List<PlanItem> eventPlans, PlanEvent event) {
  final when = event.start;
  if (event.teamId == null || when == null) return null;
  for (final p in eventPlans) {
    final e = p.event;
    if (e == null || e.eventId == event.eventId) continue;
    if (e.teamId != event.teamId || e.start == null) continue;
    if (e.start!.isBefore(when)) return p; // newest first
  }
  return null;
}
