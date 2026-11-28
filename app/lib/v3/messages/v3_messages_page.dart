// v3 Messages (super users only for now, Ken 2026-11-14): the list of sent
// messages with how many have seen them, and the screen to write one.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../v3_crest_image.dart';
import '../v3_theme.dart';
import '/v3/tracking/v3_track.dart';
import 'v3_message_widgets.dart';
import 'v3_messages_models.dart';

class V3MessagesPage extends StatefulWidget {
  const V3MessagesPage({super.key, this.api = const MessagesApi()});
  final MessagesApi api;

  @override
  State<V3MessagesPage> createState() => _V3MessagesPageState();
}

class _V3MessagesPageState extends State<V3MessagesPage> {
  List<AppMessage>? _list;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    V3Track.screen('V3MessagesPage');
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await widget.api.sent();
      if (mounted) {
        setState(() {
          _list = l;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _open([AppMessage? m]) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
        settings: const RouteSettings(name: 'V3MessageForm'),
        builder: (_) => V3MessageFormPage(api: widget.api, message: m)));
    if (changed == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final list = _list ?? const <AppMessage>[];
    Widget section(String label, String status) {
      final items = list.where((m) => m.status(now) == status).toList();
      if (items.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
            child: Text(label,
                style: V3.inter(12,
                    weight: FontWeight.w600,
                    color: V3.muted,
                    letterSpacing: 0.5)),
          ),
          for (final m in items)
            _SentCard(m, status: status, onTap: () => _open(m)),
        ],
      );
    }

    return Scaffold(
      backgroundColor: V3.bg,
      appBar: AppBar(
        backgroundColor: V3.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: V3.green),
        title: Text('Messages', style: V3.tight(20, weight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'New message',
            onPressed: () => _open(),
            icon: const Icon(Icons.add, color: V3.green, size: 28),
          ),
        ],
      ),
      body: _list == null
          ? Center(
              child: _failed
                  ? TextButton(
                      onPressed: _load,
                      child: Text("Couldn't load. Tap to retry",
                          style: V3.inter(15, color: V3.green)))
                  : const CircularProgressIndicator(color: V3.green))
          : RefreshIndicator(
              color: V3.green,
              backgroundColor: V3.card,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Column(children: [
                        Text('No messages yet',
                            style: V3.inter(17, weight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(
                            'Send an important pop-up or a news item\nto a club, a team or everyone.',
                            textAlign: TextAlign.center,
                            style: V3.inter(14, color: V3.muted)),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: () => _open(),
                          style: FilledButton.styleFrom(
                              backgroundColor: V3.green,
                              foregroundColor: V3.bg),
                          child: Text('New message',
                              style: V3.inter(15,
                                  weight: FontWeight.w600, color: V3.bg)),
                        ),
                      ]),
                    ),
                  section('LIVE NOW', 'live'),
                  section('SCHEDULED', 'scheduled'),
                  section('ENDED', 'ended'),
                ],
              ),
            ),
    );
  }
}

class _SentCard extends StatelessWidget {
  const _SentCard(this.m, {required this.status, required this.onTap});
  final AppMessage m;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEE d MMM');
    final quiet = m.kind != MessageKind.important;
    final kind = switch (m.kind) {
      MessageKind.news => 'News',
      MessageKind.fundraiser => 'Fundraiser',
      MessageKind.important => '⚠ Important',
    };
    final when = switch (status) {
      'scheduled' => 'from ${df.format(m.startsAt!)}',
      'ended' => 'ended ${df.format(m.endedAt ?? m.endsAt!)}',
      _ => m.endsAt == null ? '' : 'until ${df.format(m.endsAt!)}',
    };
    final people =
        m.audience == MessageAudience.all ? '' : ' · ${m.audience.label}';
    final seen = quiet
        ? 'Seen by ${m.seenCount} of ${m.reach}'
            '${m.isFundraiser ? ' · ${m.tapCount} tapped' : ''}'
        : 'Closed by ${m.dismissedCount} of ${m.reach}';
    final pct = m.reach == 0
        ? 0.0
        : ((quiet ? m.seenCount : m.dismissedCount) / m.reach).clamp(0.0, 1.0);
    return Opacity(
      opacity: status == 'ended' ? 0.6 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: V3.card,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$kind · ${m.sentTo}$people · $when',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: V3.inter(12.5,
                          weight: FontWeight.w500,
                          color: quiet ? V3.muted : V3.amberText)),
                  const SizedBox(height: 3),
                  Text(m.title, style: V3.tight(17)),
                  const SizedBox(height: 2),
                  Text(status == 'scheduled' ? 'Not shown yet' : seen,
                      style: V3.inter(13, color: V3.muted)),
                  if (status != 'scheduled') ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        color: V3.green,
                        backgroundColor: V3.barGrey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// New / edit message

class V3MessageFormPage extends StatefulWidget {
  const V3MessageFormPage(
      {super.key, this.api = const MessagesApi(), this.message});
  final MessagesApi api;
  final AppMessage? message;

  @override
  State<V3MessageFormPage> createState() => _V3MessageFormPageState();
}

class _V3MessageFormPageState extends State<V3MessageFormPage> {
  late MessageKind _kind;
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _link;
  late final TextEditingController _linkLabel;
  int? _clubId;
  List<int> _teamIds = [];
  String _sendToLabel = 'Everyone on CoachSmart';
  String _clubCrest = '';
  late MessageAudience _audience;
  late DateTime _startsAt;
  late DateTime _endsAt;
  bool _startNow = true;
  bool _endsTouched = false;
  int? _count;
  int? _pushCount;
  bool _push = false;
  int _countCall = 0;
  bool _busy = false;
  List<TargetClub>? _targets;

  AppMessage? get _m => widget.message;

  @override
  void initState() {
    super.initState();
    final m = _m;
    _kind = m?.kind ?? MessageKind.important;
    _title = TextEditingController(text: m?.title ?? '');
    _body = TextEditingController(text: m?.body ?? '');
    _link = TextEditingController(text: m?.linkUrl ?? '');
    _linkLabel = TextEditingController(text: m?.linkLabel ?? '');
    _clubId = m?.clubId;
    _teamIds = [...?m?.teamIds];
    _audience = m?.audience ?? MessageAudience.all;
    _push = m?.push ?? false;
    final now = DateTime.now();
    _startNow = m == null || !(m.startsAt?.isAfter(now) ?? false);
    _startsAt = m?.startsAt ?? now;
    _endsAt = m?.endsAt ?? _defaultEnd(now);
    _endsTouched = m != null;
    if (m != null) {
      _sendToLabel = m.scope == 'all'
          ? 'Everyone on CoachSmart'
          : (m.teamNames.isNotEmpty
              ? m.teamNames.join(', ')
              : 'Whole club · ${m.fromName}');
      _clubCrest = m.crest;
    }
    for (final c in [_title, _body, _link, _linkLabel]) {
      c.addListener(() => setState(() {}));
    }
    _loadTargets();
    _recount();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _link.dispose();
    _linkLabel.dispose();
    super.dispose();
  }

  /// News a week, important two weeks, ending at the end of that day.
  DateTime _defaultEnd(DateTime from) {
    final d = from.add(Duration(days: _kind == MessageKind.news ? 7 : 14));
    return DateTime(d.year, d.month, d.day, 23, 59);
  }

  Future<void> _loadTargets() async {
    try {
      final t = await widget.api.targets();
      if (!mounted) return;
      setState(() => _targets = t);
      // A club officer starts on their own club (not everyone on CoachSmart).
      if (_m == null &&
          !MessagesAccess.sendEveryone &&
          _clubId == null &&
          t.isNotEmpty) {
        setState(() {
          _clubId = t.first.clubId;
          _clubCrest = t.first.crest;
        });
        _recount();
      }
      // Name the club on an existing club-wide message.
      if (_clubId != null && _teamIds.isEmpty) {
        for (final c in t) {
          if (c.clubId == _clubId) {
            setState(() {
              _sendToLabel = 'Whole club · ${c.name}';
              _clubCrest = c.crest;
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _recount() async {
    final call = ++_countCall;
    setState(() => _count = null);
    try {
      final n = await widget.api.count(_clubId, _teamIds, _audience);
      if (mounted && call == _countCall) setState(() => _count = n);
      final p = await widget.api.countPush(_clubId, _teamIds, _audience);
      if (mounted && call == _countCall) setState(() => _pushCount = p);
    } catch (_) {}
  }

  Future<void> _pickTarget() async {
    final t = _targets;
    if (t == null) return;
    final r = await Navigator.of(context).push<_Target>(MaterialPageRoute(
        builder: (_) =>
            _TargetPage(clubs: t, clubId: _clubId, teamIds: _teamIds.toSet())));
    if (r == null || !mounted) return;
    setState(() {
      _clubId = r.clubId;
      _teamIds = r.teamIds;
      _sendToLabel = r.label;
      _clubCrest = r.crest;
    });
    _recount();
  }

  Future<void> _pickAudience() async {
    final r = await showModalBottomSheet<MessageAudience>(
      context: context,
      backgroundColor: V3.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Text('People', style: V3.tight(18)),
          const SizedBox(height: 6),
          for (final a in MessageAudience.values)
            ListTile(
              title: Text(a.label, style: V3.inter(16)),
              trailing: a == _audience
                  ? const Icon(Icons.check, color: V3.green)
                  : null,
              onTap: () => Navigator.pop(ctx, a),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (r == null || !mounted) return;
    setState(() => _audience = r);
    _recount();
  }

  Future<DateTime?> _pickDateTime(DateTime initial, DateTime first) async {
    final d = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: DateTime(first.year, first.month, first.day),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return null;
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _pickStart() async {
    final r = await _pickDateTime(
        _startNow ? DateTime.now() : _startsAt, DateTime.now());
    if (r == null || !mounted) return;
    setState(() {
      _startNow = !r.isAfter(DateTime.now());
      _startsAt = r;
      if (!_endsTouched || !_endsAt.isAfter(r)) _endsAt = _defaultEnd(r);
    });
  }

  Future<void> _pickEnd() async {
    final from = _startNow ? DateTime.now() : _startsAt;
    final r = await _pickDateTime(_endsAt, from);
    if (r == null || !mounted) return;
    setState(() {
      _endsAt = r;
      _endsTouched = true;
    });
  }

  void _snack(String text, {bool bad = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(text, style: V3.inter(14, color: V3.bg)),
        backgroundColor: bad ? V3.amber : V3.green,
      ));

  Widget _pushTile(String n, String label, {bool hi = false}) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: hi ? V3.greenTint : V3.bg,
              borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n,
                style: V3.tight(28,
                    weight: FontWeight.w700, color: hi ? V3.green : V3.text)),
            const SizedBox(height: 2),
            Text(label, style: V3.inter(13, color: V3.muted)),
          ]),
        ),
      );

  Widget _pushLine(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: V3.line))),
        child: Row(children: [
          Expanded(child: Text(label, style: V3.inter(15, color: V3.muted))),
          Text(value, style: V3.inter(15, weight: FontWeight.w700)),
        ]),
      );

  /// Push confirm sheet: true = send (with the push, or without one when no
  /// phone has push on), false/null = back to the message.
  Future<bool?> _confirmPush(DateTime start) async {
    setState(() => _busy = true);
    PushReach? c;
    try {
      c = await widget.api.countPushDetail(_clubId, _teamIds, _audience);
    } catch (_) {}
    if (!mounted) return false;
    setState(() => _busy = false);
    if (c == null) {
      _snack('Could not count the phones. Please try again.', bad: true);
      return false;
    }
    final r = c;
    final n = r.phones;
    final ph = n == 1 ? 'phone' : 'phones';
    final when = _startNow
        ? 'right away'
        : 'when it starts showing, ${DateFormat('EEE d MMM, HH:mm').format(start)}';
    final yes = n > 0
        ? 'Send push to $n $ph'
        : (_startNow ? 'Send without a push' : 'Schedule without a push');
    final go = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: V3.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(n > 0 ? 'Send a push to $n $ph?' : 'No phones to push to',
                  style: V3.tight(20)),
              const SizedBox(height: 8),
              Text(
                  n > 0
                      ? '"${_title.text.trim()}" buzzes these phones $when. It can\'t be unsent.'
                      : 'Nobody in this audience has push turned on. The message still pops up when they open the app.',
                  style: V3.inter(15, color: V3.muted, height: 1.4)),
              const SizedBox(height: 14),
              Row(children: [
                _pushTile('$n', '$ph get a push', hi: true),
                const SizedBox(width: 10),
                _pushTile('${r.people}',
                    r.people == 1 ? 'person reached' : 'people reached'),
              ]),
              const SizedBox(height: 14),
              _pushLine('iPhone', '${r.ios}'),
              _pushLine('Android', '${r.android}'),
              if (r.other > 0) _pushLine('Other', '${r.other}'),
              _pushLine('No push', '${r.noPush}'),
              const SizedBox(height: 10),
              Text('Push only, no email. One per phone.',
                  style: V3.inter(13.5, color: V3.muted)),
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                      backgroundColor: V3.green,
                      foregroundColor: V3.bg,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  child: Text(yes,
                      style:
                          V3.inter(16, weight: FontWeight.w700, color: V3.bg)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: V3.inter(15, color: V3.muted)),
              ),
            ],
          ),
        ),
      ),
    );
    if (go == true && n == 0 && mounted) setState(() => _push = false);
    return go;
  }

  Future<bool> _confirm(String title, String body, String yes) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: V3.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: V3.tight(20)),
              const SizedBox(height: 8),
              Text(body, style: V3.inter(15, color: V3.muted, height: 1.4)),
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                      backgroundColor: V3.green,
                      foregroundColor: V3.bg,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  child: Text(yes,
                      style:
                          V3.inter(16, weight: FontWeight.w700, color: V3.bg)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: V3.inter(15, color: V3.muted)),
              ),
            ],
          ),
        ),
      ),
    );
    return r == true;
  }

  Future<void> _send() async {
    if (_busy || _title.text.trim().isEmpty) return;
    final start = _startNow ? DateTime.now() : _startsAt;
    if (!_endsAt.isAfter(start)) {
      _snack('"Stop showing" must be after "Show from".', bad: true);
      return;
    }
    final n = _count;
    final who = n == null ? 'everyone picked' : '$n people';
    // Push confirm (Ken 2026-11-28): a fresh phone count, and nothing is
    // saved or pushed until "Send push to N phones".
    final m0 = _m;
    final pushAsk = _kind == MessageKind.important &&
        _push &&
        m0?.pushSentAt == null &&
        !(m0?.push ?? false);
    if (pushAsk) {
      final go = await _confirmPush(start);
      if (go != true || !mounted) return;
    }
    final ok = _m != null ||
        pushAsk ||
        await _confirm(
            _kind == MessageKind.important
                ? 'Pop this up for $who?'
                : 'Show this in the news bar for $who?',
            _kind == MessageKind.important
                ? 'It shows each time they open the app until they close it.'
                    '${_push ? ' A push goes to ${_pushCount ?? 'their'} ${_pushCount == 1 ? 'phone' : 'phones'} too.' : ''}'
                : 'It stays in the bar until ${DateFormat('EEE d MMM, HH:mm').format(_endsAt)}.',
            _startNow ? 'Send now' : 'Schedule it');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final id = await widget.api.save(
        id: _m?.id,
        kind: _kind,
        title: _title.text,
        body: _body.text,
        linkUrl: normaliseLink(_link.text),
        linkLabel: _linkLabel.text,
        clubId: _clubId,
        teamIds: _teamIds,
        audience: _audience,
        startsAt: start,
        endsAt: _endsAt,
      );
      final m = _m;
      if (id > 0 &&
          m?.pushSentAt == null &&
          (_push || (m?.push ?? false))) {
        await widget.api.setPush(id, _kind == MessageKind.important && _push);
        if (_kind == MessageKind.important && _push) {
          V3Track.event('app_message_push');
        }
      }
      V3Track.event(_m == null ? 'app_message_sent' : 'app_message_edited');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack('Could not save the message. Please try again.', bad: true);
      }
    }
  }

  Future<void> _end({required bool delete}) async {
    final ok = await _confirm(
        delete ? 'Delete this message?' : 'Stop showing it now?',
        delete
            ? 'It disappears for everyone and leaves this list.'
            : 'It disappears for everyone straight away. It stays in your list under Ended.',
        delete ? 'Delete' : 'Stop now');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.api.end(_m!.id, delete: delete);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _snack('Could not update the message. Please try again.', bad: true);
      }
    }
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(t,
            style: V3.inter(12,
                weight: FontWeight.w600, color: V3.muted, letterSpacing: 0.5)),
      );

  Widget _field(TextEditingController c, String hint,
          {int lines = 1, bool bold = false, TextInputType? type}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: c,
          minLines: lines,
          maxLines: lines == 1 ? 1 : 8,
          keyboardType: type,
          textCapitalization: type == TextInputType.url
              ? TextCapitalization.none
              : TextCapitalization.sentences,
          style: V3.inter(15, weight: bold ? FontWeight.w600 : FontWeight.w400),
          cursorColor: V3.green,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: V3.inter(15, color: V3.muted),
            filled: true,
            fillColor: V3.card,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
      );

  Widget _row(String label, String value, VoidCallback? onTap,
          {Widget? lead, bool last = false, bool first = false}) =>
      Material(
        color: V3.card,
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(first ? 12 : 0),
            bottom: Radius.circular(last ? 12 : 0)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(first ? 12 : 0),
              bottom: Radius.circular(last ? 12 : 0)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
                border: last
                    ? null
                    : const Border(bottom: BorderSide(color: V3.line))),
            child: Row(children: [
              Text(label, style: V3.inter(15)),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (lead != null) ...[lead, const SizedBox(width: 8)],
                    Flexible(
                      child: Text(value,
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: V3.inter(14.5, color: V3.muted)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: V3.muted, size: 20),
            ]),
          ),
        ),
      );

  Widget _pushRow() {
    final sent = _m?.pushSentAt;
    final n = _pushCount;
    final phones = n == null ? 'phones' : (n == 1 ? '1 phone' : '$n phones');
    final hint = sent != null
        ? 'Push sent ${DateFormat('EEE d MMM, HH:mm').format(sent.toLocal())}'
            '${_m?.pushCount != null ? ' to ${_m!.pushCount} ${_m!.pushCount == 1 ? 'phone' : 'phones'}' : ''}. It isn\'t sent again.'
        : _push
            ? 'Goes to $phones with notifications on, ${_startNow ? 'as soon as you send' : 'when it starts showing'}. Push only, no email.'
            : 'Off. It still pops up when people open the app.';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 12),
      decoration: BoxDecoration(
          color: V3.card, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('Send a push too', style: V3.inter(15))),
            Switch(
              value: sent != null || _push,
              activeColor: V3.green,
              onChanged: sent != null ? null : (v) => setState(() => _push = v),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(hint,
                style: V3.inter(13, color: V3.muted, height: 1.35)),
          ),
        ],
      ),
    );
  }

  Widget _kindTab(MessageKind k, String title, String sub) {
    final on = _kind == k;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _kind = k;
          if (!_endsTouched) {
            _endsAt = _defaultEnd(_startNow ? DateTime.now() : _startsAt);
          }
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: on ? V3.card2 : Colors.transparent,
              borderRadius: BorderRadius.circular(9)),
          child: Column(children: [
            Text(title,
                style: V3.inter(14.5,
                    weight: FontWeight.w600,
                    color: on
                        ? (k == MessageKind.important ? V3.amberText : V3.text)
                        : V3.muted)),
            const SizedBox(height: 2),
            Text(sub, style: V3.inter(11.5, color: V3.muted)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEE d MMM, HH:mm');
    final ready = _title.text.trim().isNotEmpty && !_busy;
    final n = _count;
    final cta = _m != null
        ? 'Save changes'
        : (n == null
            ? 'Send'
            : (n == 1 ? 'Send to 1 person' : 'Send to $n people'));
    final preview = AppMessage(
      id: 0,
      kind: _kind,
      title: _title.text.trim().isEmpty ? 'Your title' : _title.text.trim(),
      body: _body.text.trim(),
      linkUrl: _link.text.trim(),
      linkLabel: _linkLabel.text.trim(),
      fromName: _clubId == null
          ? 'CoachSmart'
          : _sendToLabel.replaceFirst('Whole club · ', ''),
      crest: _clubId == null ? '' : _clubCrest,
      scope: _clubId == null ? 'all' : (_teamIds.isEmpty ? 'club' : 'team'),
      startsAt: _startNow ? DateTime.now() : _startsAt,
    );
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: AppBar(
        backgroundColor: V3.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: V3.green),
        title: Text(_m == null ? 'New message' : 'Edit message',
            style: V3.tight(20, weight: FontWeight.w700)),
        actions: [
          if (_m != null)
            PopupMenuButton<String>(
              color: V3.card2,
              icon: const Icon(Icons.more_vert, color: V3.green),
              onSelected: (v) => _end(delete: v == 'delete'),
              itemBuilder: (_) => [
                if (_m!.status(DateTime.now()) != 'ended')
                  PopupMenuItem(
                      value: 'stop',
                      child: Text('Stop showing now', style: V3.inter(15))),
                PopupMenuItem(
                    value: 'delete',
                    child:
                        Text('Delete', style: V3.inter(15, color: V3.redText))),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            _label('TYPE'),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: V3.card, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                _kindTab(
                    MessageKind.important, '⚠ Important', 'Pop-up on open'),
                _kindTab(MessageKind.news, 'News', 'Bar at the top'),
              ]),
            ),
            _label('MESSAGE'),
            _field(_title, 'Title', bold: true),
            _field(_body, 'Message', lines: 4),
            _field(_link, 'Link (optional)', type: TextInputType.url),
            if (_link.text.trim().isNotEmpty || _linkLabel.text.isNotEmpty)
              _field(_linkLabel, 'Link button text, e.g. Read the full notice'),
            _label('WHO SEES IT'),
            _row(
              'Send to',
              _targets == null && _clubId == null
                  ? 'Everyone on CoachSmart'
                  : _sendToLabel,
              _targets == null ? null : _pickTarget,
              first: true,
              lead: _clubId != null && _clubCrest.isNotEmpty
                  ? V3CrestImage(_clubCrest, size: 22)
                  : null,
            ),
            _row('People', _audience.label, _pickAudience, last: true),
            _label('WHEN'),
            _row('Show from', _startNow ? 'Now' : df.format(_startsAt),
                _pickStart,
                first: true),
            _row('Stop showing', df.format(_endsAt), _pickEnd, last: true),
            if (_kind == MessageKind.important) ...[
              _label('PUSH NOTIFICATION'),
              _pushRow(),
            ],
            _label('PREVIEW'),
            if (_kind == MessageKind.important)
              IgnorePointer(
                child: V3ImportantCard(message: preview, onDismiss: () {}),
              )
            else
              IgnorePointer(
                child:
                    V3NewsCards(news: [preview], onTap: () {}, heading: false),
              ),
            const SizedBox(height: 22),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: ready ? _send : null,
                style: FilledButton.styleFrom(
                  backgroundColor: V3.green,
                  foregroundColor: V3.bg,
                  disabledBackgroundColor: V3.card2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: V3.bg))
                    : Text(cta,
                        style: V3.inter(16,
                            weight: FontWeight.w700,
                            color: ready ? V3.bg : V3.muted)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Send to: everyone, a whole club, or some of its teams.

class _Target {
  const _Target(this.clubId, this.teamIds, this.label, this.crest);
  final int? clubId;
  final List<int> teamIds;
  final String label;
  final String crest;
}

class _TargetPage extends StatefulWidget {
  const _TargetPage(
      {required this.clubs, required this.clubId, required this.teamIds});
  final List<TargetClub> clubs;
  final int? clubId;
  final Set<int> teamIds;

  @override
  State<_TargetPage> createState() => _TargetPageState();
}

class _TargetPageState extends State<_TargetPage> {
  String _q = '';
  TargetClub? _club;
  late Set<int> _teams;

  @override
  void initState() {
    super.initState();
    _teams = {...widget.teamIds};
    for (final c in widget.clubs) {
      if (c.clubId == widget.clubId) _club = c;
    }
  }

  void _done() {
    final c = _club;
    if (c == null) {
      if (!MessagesAccess.sendEveryone) return;
      Navigator.pop(
          context, const _Target(null, [], 'Everyone on CoachSmart', ''));
      return;
    }
    final picked = [
      for (final t in c.teams)
        if (_teams.contains(t.teamId)) t
    ];
    Navigator.pop(
        context,
        _Target(
            c.clubId,
            [for (final t in picked) t.teamId],
            picked.isEmpty
                ? 'Whole club · ${c.name}'
                : picked.map((t) => t.name).join(', '),
            c.crest));
  }

  @override
  Widget build(BuildContext context) {
    final club = _club;
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: AppBar(
        backgroundColor: V3.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: V3.green),
        title: Text(club == null ? 'Send to' : club.name,
            style: V3.tight(20, weight: FontWeight.w700)),
        leading: club == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: V3.green),
                onPressed: () => setState(() {
                  _club = null;
                  _teams.clear();
                }),
              ),
        actions: [
          if (club != null)
            TextButton(
                onPressed: _done,
                child: Text('Done',
                    style: V3.inter(16,
                        weight: FontWeight.w600, color: V3.green))),
        ],
      ),
      body: club == null ? _clubList() : _teamList(club),
    );
  }

  Widget _clubList() {
    final q = _q.toLowerCase();
    final clubs = widget.clubs
        .where((c) => q.isEmpty || c.name.toLowerCase().contains(q))
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        if (MessagesAccess.sendEveryone)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(Icons.public, color: V3.green),
            title: Text('Everyone on CoachSmart',
                style: V3.inter(16, weight: FontWeight.w600)),
            subtitle: Text('Every club and team',
                style: V3.inter(13, color: V3.muted)),
            trailing: widget.clubId == null
                ? const Icon(Icons.check, color: V3.green)
                : null,
            onTap: () => Navigator.pop(
                context, const _Target(null, [], 'Everyone on CoachSmart', '')),
          ),
        const SizedBox(height: 8),
        TextField(
          onChanged: (v) => setState(() => _q = v),
          style: V3.inter(15),
          cursorColor: V3.green,
          decoration: InputDecoration(
            hintText: 'Find a club',
            hintStyle: V3.inter(15, color: V3.muted),
            prefixIcon: const Icon(Icons.search, color: V3.muted),
            filled: true,
            fillColor: V3.card,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 8),
        for (final c in clubs)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: SizedBox(
                width: 32, height: 32, child: V3CrestImage(c.crest, size: 32)),
            title: Text(c.name, style: V3.inter(16)),
            subtitle: Text(
                c.teams.length == 1 ? '1 team' : '${c.teams.length} teams',
                style: V3.inter(13, color: V3.muted)),
            trailing: const Icon(Icons.chevron_right, color: V3.muted),
            onTap: () => setState(() {
              _club = c;
              _teams.clear();
            }),
          ),
      ],
    );
  }

  Widget _teamList(TargetClub c) => ListView(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 32),
        children: [
          CheckboxListTile(
            value: _teams.isEmpty,
            activeColor: V3.green,
            checkColor: V3.bg,
            title: Text('Whole club',
                style: V3.inter(16, weight: FontWeight.w600)),
            subtitle: Text('Every team at ${c.name}',
                style: V3.inter(13, color: V3.muted)),
            onChanged: (_) => setState(() => _teams.clear()),
          ),
          const Divider(color: V3.line),
          for (final t in c.teams)
            CheckboxListTile(
              value: _teams.contains(t.teamId),
              activeColor: V3.green,
              checkColor: V3.bg,
              title: Text(t.name, style: V3.inter(16)),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _teams.add(t.teamId);
                } else {
                  _teams.remove(t.teamId);
                }
              }),
            ),
        ],
      );
}
