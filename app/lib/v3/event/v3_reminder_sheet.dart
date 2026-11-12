// "Send reminder" confirm step (Ken, 2026-11-12). Before the reminder goes
// out the admin sees how many people will get it, who hasn't replied by role
// (players, FLOs, coaches) and when a reminder was last sent. Counts come
// from get_event_reminder_preview, which uses the same filters as
// populate_event_notifications (the send itself is unchanged).
import 'package:flutter/material.dart';

import '/backend/supabase/supabase.dart';
import '../v3_theme.dart';

class ReminderPreview {
  ReminderPreview({
    this.people = 0,
    this.push = 0,
    this.email = 0,
    this.notReplied = 0,
    this.players = 0,
    this.flos = 0,
    this.coaches = 0,
    this.names = const [],
    this.timesSent = 0,
    this.lastAt,
    this.lastBy,
    this.lastPeople,
  });

  final int people;
  final int push;
  final int email;
  final int notReplied;
  final int players;
  final int flos;
  final int coaches;
  final List<({String name, String roles})> names;
  final int timesSent;
  final DateTime? lastAt;
  final String? lastBy;
  final int? lastPeople;

  static int _i(dynamic v) =>
      v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

  factory ReminderPreview.fromJson(dynamic body) {
    dynamic j = body;
    if (j is List) j = j.isEmpty ? null : j.first;
    if (j is! Map) return ReminderPreview();
    final names = <({String name, String roles})>[];
    final raw = j['names'];
    if (raw is List) {
      for (final n in raw) {
        if (n is Map) {
          names.add((
            name: '${n['name'] ?? ''}'.trim(),
            roles: '${n['roles'] ?? ''}'.trim()
          ));
        }
      }
    }
    final at = j['last_at'];
    final by = j['last_by'];
    final lp = j['last_people'];
    return ReminderPreview(
      people: _i(j['people']),
      push: _i(j['push']),
      email: _i(j['email']),
      notReplied: _i(j['not_replied']),
      players: _i(j['players']),
      flos: _i(j['flos']),
      coaches: _i(j['coaches']),
      names: names,
      timesSent: _i(j['times_sent']),
      lastAt: at == null ? null : DateTime.tryParse('$at')?.toLocal(),
      lastBy: by == null || '$by'.trim().isEmpty ? null : '$by'.trim(),
      lastPeople: lp == null ? null : _i(lp),
    );
  }
}

Future<ReminderPreview> fetchReminderPreview(int eventId) async {
  final r = await SupaFlow.client
      .rpc('get_event_reminder_preview', params: {'p_event_id': eventId});
  return ReminderPreview.fromJson(r);
}

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String _two(int n) => n.toString().padLeft(2, '0');

/// "today 19:02", "yesterday 19:02" or "Mon 10 Nov 20:15".
String reminderWhen(DateTime at, DateTime now) {
  final d = DateTime(at.year, at.month, at.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(d).inDays;
  final time = '${_two(at.hour)}:${_two(at.minute)}';
  if (diff == 0) return 'today $time';
  if (diff == 1) return 'yesterday $time';
  return '${_days[at.weekday - 1]} ${at.day} ${_months[at.month - 1]} $time';
}

String _people(int n) => n == 1 ? '1 person' : '$n people';

/// Menu subtitle: "Last sent yesterday 19:02 by Ken · 14 people".
String reminderMenuLine(ReminderPreview? p, DateTime now) {
  if (p == null) return "Push to everyone who hasn't replied";
  if (p.lastAt == null) return 'Not sent yet';
  final by = p.lastBy == null ? '' : ' by ${p.lastBy}';
  final n = p.lastPeople == null ? '' : ' · ${_people(p.lastPeople!)}';
  return 'Last sent ${reminderWhen(p.lastAt!, now)}$by$n';
}

/// Last-sent box title, "Last sent yesterday at 19:02".
String reminderLastTitle(ReminderPreview p, DateTime now) {
  final w = reminderWhen(p.lastAt!, now);
  final i = w.lastIndexOf(' ');
  return 'Last sent ${w.substring(0, i)} at ${w.substring(i + 1)}';
}

/// "By Ken, to 14 people. Sent twice for this event."
String reminderLastDetail(ReminderPreview p) {
  final parts = <String>[];
  if (p.lastBy != null) parts.add('By ${p.lastBy}');
  if (p.lastPeople != null) {
    parts.add('${parts.isEmpty ? 'To' : 'to'} ${_people(p.lastPeople!)}');
  }
  var s = parts.isEmpty ? '' : '${parts.join(', ')}.';
  if (p.timesSent == 2) s += ' Sent twice for this event.';
  if (p.timesSent > 2) s += ' Sent ${p.timesSent} times for this event.';
  return s.trim();
}

/// "15 haven't replied. A parent with two children, or a coach who is also
/// a parent, gets one message. 4 by push, 9 by email."
String reminderNote(ReminderPreview p) {
  final s = <String>[
    p.notReplied == 1 ? "1 hasn't replied." : "${p.notReplied} haven't replied."
  ];
  if (p.people < p.notReplied) {
    s.add('A parent with two children, or a coach who is also a parent, '
        'gets one message.');
  }
  if (p.email == 0) {
    s.add(p.push == 1 ? 'By push.' : 'All by push.');
  } else if (p.push == 0) {
    s.add(p.email == 1 ? 'By email.' : 'All by email.');
  } else {
    s.add('${p.push} by push, ${p.email} by email.');
  }
  return s.join(' ');
}

/// Opens the confirm sheet. Resolves true when the admin taps Send.
Future<bool> showReminderSheet(BuildContext context, int eventId,
    {ReminderPreview? preview}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: V3.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _ReminderSheet(eventId: eventId, preview: preview),
  );
  return ok ?? false;
}

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet({required this.eventId, this.preview});
  final int eventId;
  final ReminderPreview? preview;

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  ReminderPreview? _p;
  bool _failed = false;
  bool _showNames = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Always re-read: replies may have come in since the menu opened.
  Future<void> _load() async {
    _p = widget.preview;
    try {
      final p = await fetchReminderPreview(widget.eventId);
      if (mounted) setState(() => _p = p);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Widget _chip(int n, String one, String many) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
              color: V3.card2, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text('$n', style: V3.tight(20)),
            const SizedBox(height: 2),
            Text(n == 1 ? one : many,
                style: V3.inter(12, weight: FontWeight.w500, color: V3.muted)),
          ]),
        ),
      );

  Widget _lastBox(ReminderPreview p) {
    final now = DateTime.now();
    final sent = p.lastAt != null;
    final detail = sent ? reminderLastDetail(p) : '';
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: sent ? V3.amberTint : V3.card2,
        border: Border.all(color: sent ? V3.amberLine : V3.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.schedule, size: 20, color: sent ? V3.amberText : V3.muted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(sent ? reminderLastTitle(p, now) : 'No reminder sent yet',
                  style: V3.inter(14,
                      weight: FontWeight.w600,
                      color: sent ? V3.amberText : V3.text)),
              const SizedBox(height: 2),
              Text(sent ? detail : 'This is the first one for this event.',
                  style: V3.inter(13,
                      color: sent ? const Color(0xFFE8D9B5) : V3.muted)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _button(String label,
          {required bool primary, required VoidCallback onTap}) =>
      Expanded(
        child: SizedBox(
          height: 50,
          child: TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              backgroundColor: primary ? V3.green : V3.card2,
              foregroundColor: primary ? V3.bg : V3.text,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(label,
                style: V3.inter(16,
                    weight: FontWeight.w600, color: primary ? V3.bg : V3.text)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final children = <Widget>[
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
      Text('Send a reminder?', style: V3.tight(20)),
    ];

    if (p == null) {
      children.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: _failed
              ? Text("Couldn't load who will get it.",
                  style: V3.inter(14, color: V3.muted))
              : const CircularProgressIndicator(color: V3.green),
        ),
      ));
      children.add(Row(children: [
        _button('Close',
            primary: false, onTap: () => Navigator.pop(context, false)),
      ]));
    } else if (p.people == 0) {
      children.addAll([
        const SizedBox(height: 16),
        Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('0',
                  style:
                      V3.tight(44, weight: FontWeight.w700, color: V3.green)),
              const SizedBox(width: 8),
              Text('people to remind',
                  style: V3.inter(16, weight: FontWeight.w500)),
            ]),
        const SizedBox(height: 10),
        Text("Everyone has replied, so there's nobody to remind.",
            style: V3.inter(14, color: V3.muted)),
        if (p.lastAt != null) _lastBox(p),
        const SizedBox(height: 20),
        Row(children: [
          _button('Close',
              primary: true, onTap: () => Navigator.pop(context, false)),
        ]),
      ]);
    } else {
      children.addAll([
        const SizedBox(height: 4),
        Text(
            "Everyone who hasn't replied yet gets a push or an email "
            'asking them to reply.',
            style: V3.inter(14, color: V3.muted, height: 1.4)),
        const SizedBox(height: 16),
        Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${p.people}',
                  style:
                      V3.tight(44, weight: FontWeight.w700, color: V3.green)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    p.people == 1
                        ? 'person will be reminded'
                        : 'people will be reminded',
                    style: V3.inter(16, weight: FontWeight.w500)),
              ),
            ]),
        const SizedBox(height: 14),
        Row(children: [
          _chip(p.players, 'Player', 'Players'),
          const SizedBox(width: 8),
          _chip(p.flos, 'FLO', 'FLOs'),
          const SizedBox(width: 8),
          _chip(p.coaches, 'Coach', 'Coaches'),
        ]),
        const SizedBox(height: 10),
        Text(reminderNote(p),
            style: V3.inter(13, color: V3.muted, height: 1.45)),
        if (p.names.isNotEmpty)
          InkWell(
            onTap: () => setState(() => _showNames = !_showNames),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(_showNames ? 'Hide names ‹' : 'See who ›',
                  style:
                      V3.inter(14, weight: FontWeight.w500, color: V3.green)),
            ),
          ),
        if (_showNames)
          for (final n in p.names)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(
                    child: Text(n.name.isEmpty ? 'No name' : n.name,
                        style: V3.inter(14))),
                Text(n.roles, style: V3.inter(13, color: V3.muted)),
              ]),
            ),
        _lastBox(p),
        const SizedBox(height: 20),
        Row(children: [
          _button('Cancel',
              primary: false, onTap: () => Navigator.pop(context, false)),
          const SizedBox(width: 10),
          _button('Send to ${p.people}',
              primary: true, onTap: () => Navigator.pop(context, true)),
        ]),
      ]);
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .88),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }
}
