// "Tell the team" confirm sheet for create, edit, cancel and delete
// (Ken, 2026-11-12). Doing the action and telling people are separate: the
// switch starts off every time and the button only names the action. With
// the switch on the sheet shows who would be told (counts by role), a
// preview of the message and, for cancel/edit, a note box. Who is told is
// whoever the event is for: the whole team, coaches only, or one squad.
// Counts come from get_event_notify_preview; the message is sent after the
// action succeeds by notify_event_change.
import 'package:flutter/material.dart';

import '/backend/supabase/supabase.dart';
import '../v3_theme.dart';

enum EventAction { create, edit, cancel, delete }

class NotifyPreview {
  NotifyPreview({
    this.people = 0,
    this.push = 0,
    this.email = 0,
    this.members = 0,
    this.players = 0,
    this.flos = 0,
    this.coaches = 0,
    this.admins = 0,
    this.going = 0,
    this.cantGo = 0,
    this.notReplied = 0,
    this.isPast = false,
  });

  final int people;
  final int push;
  final int email;
  final int members;
  final int players;
  final int flos;
  final int coaches;
  final int admins;
  final int going;
  final int cantGo;
  final int notReplied;
  final bool isPast;

  static int _i(dynamic v) =>
      v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

  factory NotifyPreview.fromJson(dynamic body) {
    dynamic j = body;
    if (j is List) j = j.isEmpty ? null : j.first;
    if (j is! Map) return NotifyPreview();
    return NotifyPreview(
      people: _i(j['people']),
      push: _i(j['push']),
      email: _i(j['email']),
      members: _i(j['members']),
      players: _i(j['players']),
      flos: _i(j['flos']),
      coaches: _i(j['coaches']),
      admins: _i(j['admins']),
      going: _i(j['going']),
      cantGo: _i(j['cant_go']),
      notReplied: _i(j['not_replied']),
      isPast: j['is_past'] == true,
    );
  }
}

/// What the admin picked. scope is 'one' or 'following'.
class EventActionChoice {
  const EventActionChoice(
      {this.scope = 'one', this.tell = false, this.note = ''});
  final String scope;
  final bool tell;
  final String note;
}

Future<NotifyPreview> fetchNotifyPreview(
    {int? eventId,
    int? teamId,
    int? audienceId,
    int? squadId,
    int? codeId}) async {
  final r = await SupaFlow.client.rpc('get_event_notify_preview', params: {
    'p_event_id': eventId,
    'p_team_id': teamId,
    'p_audience_id': audienceId,
    'p_squad_id': (squadId ?? 0) == 0 ? null : squadId,
    'p_code_id': codeId,
  });
  return NotifyPreview.fromJson(r);
}

/// Sends the message after the action worked. For cancel/delete it is
/// always called (tell false still clears open reply reminders).
Future<int> notifyEventChange(int eventId, EventAction a,
    {String note = '', int events = 1, bool tell = true}) async {
  final r = await SupaFlow.client.rpc('notify_event_change', params: {
    'p_event_id': eventId,
    'p_kind': switch (a) {
      EventAction.create => 'created',
      EventAction.edit => 'edited',
      EventAction.cancel => 'cancelled',
      EventAction.delete => 'deleted',
    },
    'p_note': note.trim().isEmpty ? null : note.trim(),
    'p_events': events,
    'p_tell': tell,
  });
  final n = r is Map ? r['notified'] : null;
  return n is num ? n.toInt() : 0;
}

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

/// "Thu 13 Nov, 18:30", the same as the message the server sends.
String notifyWhen(DateTime t) =>
    '${_days[t.weekday - 1]} ${t.day} ${_months[t.month - 1]}, '
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// The text people will see, mirroring notify_event_change.
String notifyMessage(EventAction a, String title, String when,
    {int events = 1, String note = ''}) {
  final n = note.trim();
  final String s;
  switch (a) {
    case EventAction.create:
      s = events > 1 ? '$title: $events events from $when.' : '$title, $when.';
    case EventAction.edit:
      s = 'Changed: $title, $when.';
    case EventAction.cancel:
      s = events > 1
          ? 'Cancelled: $title, $when and the ${events - 1} after it.'
          : 'Cancelled: $title, $when.';
    case EventAction.delete:
      s = events > 1
          ? 'Removed: $title, $when and the ${events - 1} after it.'
          : 'Removed: $title, $when.';
  }
  return n.isEmpty ? s : '$s $n';
}

/// Starting note for an edit: what people care about changing.
String editNote(Map<String, dynamic> changes, DateTime start, String venue) {
  final out = <String>[];
  if (changes.containsKey('event_date_time')) {
    out.add('New time: ${notifyWhen(start)}.');
  }
  if (changes.containsKey('location_name') && venue.isNotEmpty) {
    out.add('New venue: $venue.');
  }
  return out.join(' ');
}

String _people(int n) => n == 1 ? '1 person' : '$n people';

/// Line under "Tell the team".
String tellLine(NotifyPreview? p, bool on) {
  if (p == null) return on ? 'Working out who…' : 'Off. Nobody is told.';
  if (p.people == 0) return 'Nobody else to tell.';
  if (!on) return 'Off. Turn on to tell ${_people(p.people)}.';
  return p.members > p.people
      ? '${_people(p.people)}, covering ${p.members} team members'
      : _people(p.people);
}

/// Opens the confirm sheet. Returns null when the admin backs out.
///  - [later]: events from this one on in its series (cancel/delete);
///    above 1 shows the "Just this one / This and N later" choice.
///  - [events]: how many events a create makes (for the wording).
///  - [note]: starting text for the note box (edit: what changed).
Future<EventActionChoice?> showEventActionSheet(
  BuildContext context, {
  required EventAction action,
  required String title,
  required String when,
  String venue = '',
  int? eventId,
  int? teamId,
  int? audienceId,
  int? squadId,
  int? codeId,
  int later = 0,
  int events = 1,
  String seriesLine = '',
  String note = '',
  Future<NotifyPreview> Function()? load,
}) {
  return showModalBottomSheet<EventActionChoice>(
    context: context,
    backgroundColor: V3.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _ActionSheet(
      action: action,
      title: title,
      when: when,
      venue: venue,
      later: later,
      events: events,
      seriesLine: seriesLine,
      note: note,
      load: load ??
          () => fetchNotifyPreview(
              eventId: eventId,
              teamId: teamId,
              audienceId: audienceId,
              squadId: squadId,
              codeId: codeId),
    ),
  );
}

class _ActionSheet extends StatefulWidget {
  const _ActionSheet({
    required this.action,
    required this.title,
    required this.when,
    required this.venue,
    required this.later,
    required this.events,
    required this.seriesLine,
    required this.note,
    required this.load,
  });
  final EventAction action;
  final String title;
  final String when;
  final String venue;
  final int later;
  final int events;
  final String seriesLine;
  final String note;
  final Future<NotifyPreview> Function() load;

  @override
  State<_ActionSheet> createState() => _ActionSheetState();
}

class _ActionSheetState extends State<_ActionSheet> {
  NotifyPreview? _p;
  bool _tell = false; // Off by default (Ken, 2026-11-12).
  String _scope = 'one';
  late final TextEditingController _note =
      TextEditingController(text: widget.note);

  @override
  void initState() {
    super.initState();
    widget.load().then((p) {
      if (mounted) setState(() => _p = p);
    }).catchError((_) {
      if (mounted) setState(() => _p = NotifyPreview());
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _red =>
      widget.action == EventAction.cancel ||
      widget.action == EventAction.delete;

  int get _events => widget.action == EventAction.create
      ? widget.events
      : (_scope == 'following' ? widget.later : 1);

  String get _heading => switch (widget.action) {
        EventAction.create => widget.events > 1
            ? 'Create ${widget.events} events?'
            : 'Create this event?',
        EventAction.edit => 'Save changes?',
        EventAction.cancel => 'Cancel this event?',
        EventAction.delete => 'Delete this event?',
      };

  String get _sub => switch (widget.action) {
        EventAction.create => '',
        EventAction.edit => '',
        EventAction.cancel =>
          'It stays on the list marked cancelled. You can reinstate it later.',
        EventAction.delete =>
          "It disappears from everyone's list. This cannot be undone from the app.",
      };

  String get _button => switch (widget.action) {
        EventAction.create =>
          widget.events > 1 ? 'Create ${widget.events} events' : 'Create event',
        EventAction.edit => 'Save',
        EventAction.cancel =>
          _events > 1 ? 'Cancel $_events events' : 'Cancel event',
        EventAction.delete => _events > 1 ? 'Delete $_events events' : 'Delete',
      };

  bool get _hasNote => widget.action != EventAction.create;

  Widget _chip(int n, String one, String many) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
              color: V3.card2, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text('$n', style: V3.tight(18)),
            const SizedBox(height: 1),
            Text(n == 1 ? one : many,
                style: V3.inter(11, weight: FontWeight.w500, color: V3.muted)),
          ]),
        ),
      );

  Widget _seg() {
    Widget opt(String label, String v) => Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _scope = v),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
              decoration: BoxDecoration(
                color: _scope == v ? const Color(0xFF3A3F4A) : null,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: V3.inter(14,
                      weight: FontWeight.w500,
                      color: _scope == v ? V3.text : V3.muted)),
            ),
          ),
        );
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: V3.card2, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        opt('Just this one', 'one'),
        opt('This and ${widget.later - 1} later', 'following'),
      ]),
    );
  }

  Widget _eventCard() {
    final p = _p;
    final showReplies = p != null &&
        (widget.action == EventAction.cancel ||
            widget.action == EventAction.delete);
    final details = [
      widget.seriesLine.isNotEmpty ? widget.seriesLine : widget.when,
      if (widget.venue.isNotEmpty) widget.venue,
    ].join(' · ');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
          color: V3.card2, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.title, style: V3.inter(15, weight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(details, style: V3.inter(13, color: V3.muted)),
        if (showReplies) ...[
          const SizedBox(height: 8),
          if (p.isPast)
            Text(
                p.going == 0
                    ? 'This event is over.'
                    : 'This event is over. ${p.going} went.',
                style: V3.inter(13, color: V3.muted))
          else
            Text.rich(TextSpan(style: V3.inter(13, color: V3.muted), children: [
              TextSpan(
                  text: '${p.going} going',
                  style:
                      V3.inter(13, weight: FontWeight.w600, color: V3.green)),
              const TextSpan(text: ' · '),
              TextSpan(
                  text: "${p.cantGo} can't go",
                  style:
                      V3.inter(13, weight: FontWeight.w600, color: V3.redText)),
              TextSpan(text: ' · ${p.notReplied} not replied'),
            ])),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final canTell = p != null && p.people > 0;
    final on = _tell && canTell;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * .9),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                        color: const Color(0xFF444A56),
                        borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                Text(_heading, style: V3.tight(20)),
                if (_sub.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(_sub, style: V3.inter(14, color: V3.muted, height: 1.4)),
                ],
                if (widget.later > 1) _seg(),
                _eventCard(),
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.only(top: 12),
                  decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: V3.line))),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tell the team',
                              style: V3.inter(16, weight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(tellLine(p, on),
                              style: V3.inter(13, color: V3.muted)),
                        ],
                      ),
                    ),
                    Switch(
                      value: on,
                      activeThumbColor: Colors.white,
                      activeTrackColor: V3.green,
                      inactiveTrackColor: const Color(0xFF3A3F4A),
                      onChanged:
                          canTell ? (v) => setState(() => _tell = v) : null,
                    ),
                  ]),
                ),
                if (on) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    _chip(p.players, 'Player', 'Players'),
                    const SizedBox(width: 6),
                    _chip(p.flos, 'FLO', 'FLOs'),
                    const SizedBox(width: 6),
                    _chip(p.coaches, 'Coach', 'Coaches'),
                    const SizedBox(width: 6),
                    _chip(p.admins, 'Admin', 'Admins'),
                  ]),
                  if (_hasNote) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _note,
                      onChanged: (_) => setState(() {}),
                      maxLines: null,
                      style: V3.inter(14),
                      cursorColor: V3.green,
                      decoration: InputDecoration(
                        hintText: widget.action == EventAction.cancel
                            ? 'Add a note (optional), e.g. pitch waterlogged'
                            : 'Add a note (optional)',
                        hintStyle: V3.inter(14, color: const Color(0xFF6E727A)),
                        filled: true,
                        fillColor: V3.bg,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: V3.line)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: V3.line)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: V3.green)),
                      ),
                    ),
                  ],
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                        border: Border.all(color: V3.line),
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("THEY'LL SEE",
                            style: V3.inter(11,
                                weight: FontWeight.w500,
                                color: V3.muted,
                                letterSpacing: .5)),
                        const SizedBox(height: 4),
                        Text(
                            notifyMessage(
                                widget.action, widget.title, widget.when,
                                events: _events, note: _note.text),
                            style: V3.inter(14, height: 1.4)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          backgroundColor: V3.card2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(_red ? 'Keep event' : 'Back',
                            style: V3.inter(15, weight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: TextButton(
                        onPressed: () => Navigator.pop(
                            context,
                            EventActionChoice(
                                scope: _scope, tell: on, note: _note.text)),
                        style: TextButton.styleFrom(
                          backgroundColor: _red ? V3.red : V3.green,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(_button,
                            style: V3.inter(15,
                                weight: FontWeight.w600,
                                color: _red ? Colors.white : V3.bg)),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
