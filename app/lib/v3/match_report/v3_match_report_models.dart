// Data and rules for the v3 match report page, a native copy of
// webviews/match-report.html. Everything goes through the ai-match-report
// edge function (actions load, draft, revise, save); this file holds the
// parsing and the pure rules so they can be unit tested.
import 'package:intl/intl.dart';

int _i(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
String _s(dynamic v) => v == null ? '' : '$v';
DateTime? _d(dynamic v) =>
    v == null ? null : DateTime.tryParse('$v')?.toLocal();

class MrSquad {
  MrSquad.fromJson(Map j)
      : squadId = _i(j['squad_id']),
        squadName = _s(j['squad_name']);
  const MrSquad(this.squadId, this.squadName);
  final int squadId;
  final String squadName;

  /// The web page falls back to "Squad <id>" for a squad with no name.
  String get label => squadName.isNotEmpty ? squadName : 'Squad $squadId';
}

/// One earlier report for this match (role level 100+ only; the server
/// sends null for everyone else).
class MrReport {
  MrReport.fromJson(Map j)
      : id = _i(j['id']),
        createdAt = _d(j['created_at']),
        author = _s(j['author']),
        squadName = _s(j['squad_name']),
        opposition = _s(j['opposition']),
        report = _s(j['report']);
  final int id;
  final DateTime? createdAt;
  final String author, squadName, opposition, report;

  /// "Wed 12 Nov 2026, 19:30 · Blue · v Raheny", as in the web list.
  String get subtitle => [
        formatMrDate(createdAt),
        squadName,
        if (opposition.isNotEmpty) 'v $opposition',
      ].where((s) => s.isNotEmpty).join(' · ');

  /// The read-only detail's label / value rows, empty values left out.
  List<MapEntry<String, String>> get meta => [
        MapEntry('By', author),
        MapEntry('Submitted', formatMrDate(createdAt)),
        MapEntry('Squad', squadName),
        MapEntry('Opposition', opposition),
      ].where((e) => e.value.isNotEmpty).toList();
}

class MrLoad {
  MrLoad.fromJson(Map j)
      : eventTitle = _s((j['event'] as Map?)?['event_title']),
        eventDate = _d((j['event'] as Map?)?['event_date_time']),
        teamName = _s(j['team_name']),
        squads = [
          for (final s in (j['squads'] as List? ?? []))
            if (s is Map) MrSquad.fromJson(s)
        ],
        aiEnabled = j['ai_enabled'] == true,
        reports = j['reports'] is List
            ? [
                for (final r in j['reports'] as List)
                  if (r is Map) MrReport.fromJson(r)
              ]
            : null;

  final String eventTitle, teamName;
  final DateTime? eventDate;
  final List<MrSquad> squads;
  final bool aiEnabled;

  /// Null when the caller is below role level 100 (no list shown).
  final List<MrReport>? reports;

  String get title => eventTitle.isNotEmpty ? eventTitle : 'Match';
  String get subtitle => [teamName, formatMrDate(eventDate)]
      .where((s) => s.isNotEmpty)
      .join(' · ');

  /// More than one squad: the coach must pick one. One squad: it is used
  /// and the choice is hidden. None: no squad.
  bool get needsSquad => squads.length > 1;
  bool get showSquadPicker => squads.length > 1;
  int? get initialSquadId => squads.length == 1 ? squads.first.squadId : null;
  bool get showReports => reports != null;
}

/// Same shape as the web page's en-IE date: "Wed 12 Nov 2026, 19:30".
String formatMrDate(DateTime? d) =>
    d == null ? '' : DateFormat('EEE d MMM y, HH:mm', 'en_US').format(d);

/// What the save button checks before calling the server, in the same
/// order and wording as the web page. Null means good to save.
String? saveProblem(
    {required bool needsSquad,
    required int? squadId,
    required String opposition,
    required String report}) {
  if (needsSquad && squadId == null) return 'Please select a squad';
  if (opposition.trim().isEmpty) return 'Please enter the opposition';
  if (report.trim().isEmpty) return 'The match report is empty';
  return null;
}

/// squad_id and opposition, sent with draft, revise and save.
Map<String, dynamic> matchFields(int? squadId, String opposition) => {
      'squad_id': squadId,
      'opposition': opposition.trim().isEmpty ? null : opposition.trim(),
    };

/// The edge function answers {success: true, data} or {error}. Returns
/// data, or throws [MrError] with the server's message.
dynamic unwrapMr(dynamic json) {
  if (json is Map && json['success'] == true) return json['data'];
  final err = json is Map ? _s(json['error']) : '';
  throw MrError(err.isNotEmpty ? err : 'Something went wrong');
}

class MrError implements Exception {
  const MrError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The wording of the voice box and panel: the first recording drafts the
/// report, later ones add to or correct it.
class MrVoiceText {
  const MrVoiceText(
      {required this.label,
      required this.placeholder,
      required this.title,
      required this.subtitle,
      required this.submit,
      required this.busy});
  final String label, placeholder, title, subtitle, submit, busy;

  static const first = MrVoiceText(
      label: 'Talk through the match',
      placeholder: 'Hold the mic and tell me how it went…',
      title: 'Talk through the match',
      subtitle: 'AI will tidy it up in your own words.',
      submit: 'Write report',
      busy: 'Writing…');
  static const more = MrVoiceText(
      label: 'Add to or correct the report',
      placeholder: 'Say or type what to add or change…',
      title: 'Add to or correct the report',
      subtitle:
          'Say what to add or change. You can also type straight into the report.',
      submit: 'Update',
      busy: 'Updating…');

  static MrVoiceText forReport(String report) =>
      report.trim().isEmpty ? first : more;
}

/// The request body for the AI step: draft from nothing, else revise.
Map<String, dynamic> voiceBody(
        {required String current,
        required String transcript,
        required int? squadId,
        required String opposition}) =>
    current.trim().isEmpty
        ? {
            'action': 'draft',
            'transcript': transcript,
            ...matchFields(squadId, opposition)
          }
        : {
            'action': 'revise',
            'report': current.trim(),
            'changes': transcript,
            ...matchFields(squadId, opposition)
          };

final _fillers = RegExp(
    r"\b(um+h?|uh+|erm+|eh+|ahh?|mm+|hmm+|err+|y'know)\b[\s,]*",
    caseSensitive: false);

/// Drops spoken fillers the way cs-mic.js does before text reaches the box.
String cleanSpeech(String t) =>
    t.replaceAll(_fillers, ' ').replaceAll(RegExp(r'\s{2,}'), ' ').trim();

/// Adds newly spoken words to what is already in the panel's text box.
String appendSpoken(String existing, String spoken) =>
    spoken.isEmpty ? existing : '${existing.trim()} $spoken'.trim();
