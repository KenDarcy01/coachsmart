// v3 Attendance: who is attending, who has not replied and who declined,
// on one page with tabs. Replaces the FlutterFlow AttendeeList and
// AttendeeListAdmins pages in v3 only (the v2 app keeps its own pages).
// Ken (2026-11-09): squad cards at the top like today, squad under the name
// on the second row (admins tap it to move the member), no Lineup button in
// the cards (Lineup lives on the event page with a squad choice).
import 'package:flutter/material.dart';

import '/auth/supabase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '../teams/v3_team_models.dart' show V3Avatar, initials;
import '../v3_theme.dart';
import 'v3_attendance_models.dart';

class V3AttendancePage extends StatefulWidget {
  const V3AttendancePage(
      {super.key, required this.eventId, this.responseId, this.testData});

  final int eventId;

  /// Tab to open on: 3 attending, 4 declined, anything else no reply.
  final int? responseId;

  /// Widget tests pass the RPC result here instead of calling Supabase.
  @visibleForTesting
  final Map<String, dynamic>? testData;

  @override
  State<V3AttendancePage> createState() => _V3AttendancePageState();
}

class _V3AttendancePageState extends State<V3AttendancePage> {
  AttendanceData? _data;
  bool _loading = true;
  String? _error;
  late int _tab =
      (widget.responseId == kAttending || widget.responseId == kDeclined)
          ? widget.responseId!
          : kNoReply;
  int? _squadFilter; // null = everyone, 0 = No squad
  bool _publishing = false;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.testData != null) {
      setState(() {
        _data = AttendanceData.fromJson(widget.testData!);
        _loading = false;
      });
      return;
    }
    try {
      final r = await SupaFlow.client.rpc('get_event_attendance_v3',
          params: {'p_event_id': widget.eventId});
      final d = AttendanceData.fromJson(r is Map ? r : {});
      if (!mounted) return;
      setState(() {
        _data = d.hasError ? null : d;
        _error = d.hasError ? d.error : null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'The attendance list could not be loaded.';
      });
    }
  }

  void _snack(String text, {bool warn = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(text,
            textAlign: TextAlign.center, style: V3.inter(14, color: V3.bg)),
        backgroundColor: warn ? V3.amber : V3.green));
  }

  // ---------------------------------------------------------------- actions

  /// Admin replies on a member's behalf: a new event_attendance row, the
  /// same as the v2 ⋮ menu (the latest row is the member's reply).
  Future<void> _reply(AttMember m, int responseId) async {
    setState(() => _busy.add(m.memberId));
    try {
      await EventAttendanceTable().insert({
        'event_id': widget.eventId,
        'member_id': m.memberId,
        'response_id': responseId,
      });
      await _load();
      _snack(responseId == kAttending
          ? '${m.firstName} marked as attending'
          : '${m.firstName} marked as declined');
    } catch (_) {
      _snack('Could not save that reply. Please try again.', warn: true);
    } finally {
      if (mounted) setState(() => _busy.remove(m.memberId));
    }
  }

  Future<void> _publish() async {
    setState(() => _publishing = true);
    try {
      await SupaFlow.client.rpc('create_match_squad_from_attendance', params: {
        'p_event_id': widget.eventId,
        'p_user_id': currentUserUid,
      });
      await _load();
      _snack('Match day squads published');
    } catch (_) {
      _snack('Could not publish the squads. Please try again.', warn: true);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _export() async {
    final d = _data!;
    final pick = await _sheet<String>('Export the squads', [
      _SheetItem(Icons.table_chart_outlined, 'Google Sheets',
          'Shared with the team admins', 'sheets'),
      _SheetItem(Icons.grid_on, 'Microsoft Excel', 'Emailed to you', 'xls'),
      _SheetItem(
          Icons.description_outlined, 'CSV file', 'Emailed to you', 'csv'),
    ]);
    if (pick == null) return;
    try {
      ApiCallResponse r;
      if (pick == 'sheets') {
        r = await ExportEdgeFunctionGoogleSheetCall.call(
            eventID: widget.eventId,
            userEmail: currentUserEmail,
            matchSquadId: d.matchSquadId);
      } else if (pick == 'xls') {
        r = await ExportToXLSCall.call(
            eventId: widget.eventId,
            userEmail: currentUserEmail,
            matchSquadId: d.matchSquadId);
      } else {
        r = await ExportToCSVCall.call(
            eventId: widget.eventId,
            userEmail: currentUserEmail,
            matchSquadId: d.matchSquadId);
      }
      if (!r.succeeded) throw Exception(r.bodyText);
      _snack(pick == 'sheets'
          ? 'Google Sheet created and shared with the team admins'
          : 'Export emailed to $currentUserEmail');
    } catch (_) {
      _snack('The export did not go through. Please try again.', warn: true);
    }
  }

  /// Tap the squad under a name: move the member to another squad for the
  /// event's code (member_squad_link, as the team page does).
  Future<void> _moveSquad(AttMember m) async {
    final d = _data!;
    if (!d.admin || d.codeId == 0) return;
    final picked = await _sheet<int>('${m.firstName}: which squad?', [
      for (final s in d.squads)
        _SheetItem(null, s.squadName, null, s.squadId,
            leading: _SquadDot(s, size: 26), selected: s.squadId == m.squadId),
      _SheetItem(Icons.remove_circle_outline, 'No squad', null, 0,
          selected: m.squadId == 0, muted: true),
    ]);
    if (picked == null || picked == m.squadId || !mounted) return;
    setState(() => _busy.add(m.memberId));
    try {
      final existing = await MemberSquadLinkTable().queryRows(
          queryFn: (q) => q
              .eq('member_id', m.memberId)
              .eq('team_id', d.teamId)
              .eq('code_id', d.codeId));
      if (existing.isNotEmpty) {
        if (picked == 0) {
          await MemberSquadLinkTable().delete(
              matchingRows: (q) =>
                  q.eq('member_squad_id', existing.first.memberSquadId));
        } else {
          await MemberSquadLinkTable().update(
              data: {'squad_id': picked},
              matchingRows: (q) =>
                  q.eq('member_squad_id', existing.first.memberSquadId));
        }
      } else if (picked != 0) {
        await MemberSquadLinkTable().insert({
          'member_id': m.memberId,
          'squad_id': picked,
          'code_id': d.codeId,
          'team_id': d.teamId,
        });
      }
      await _load();
    } catch (_) {
      _snack('Could not change the squad. Please try again.', warn: true);
    } finally {
      if (mounted) setState(() => _busy.remove(m.memberId));
    }
  }

  Future<void> _openMember(AttMember m) async {
    await context.pushNamed(V3MemberPage.routeName, queryParameters: {
      'memberID': serializeParam(m.memberId, ParamType.int)!,
      'teamID': serializeParam(_data!.teamId, ParamType.int)!,
    });
    if (mounted) _load();
  }

  Future<void> _rowMenu(AttMember m) async {
    final d = _data!;
    final sub = [
      d.roles
          .firstWhere((r) => r.roleId == m.roleId, orElse: () => d.roles.first)
          .roleName,
      if (m.squadName.isNotEmpty) m.squadName,
      tabLabel(m.tab),
    ].join(' · ');
    final pick = await _sheet<String>(
        m.memberName,
        [
          if (m.tab != kAttending)
            _SheetItem(Icons.check, 'Mark as attending', null, 'attend'),
          if (m.tab != kDeclined)
            _SheetItem(Icons.close, 'Mark as declined', null, 'decline',
                color: V3.redText),
          _SheetItem(Icons.person_outline, 'Open member page', null, 'member'),
        ],
        subtitle: sub);
    if (pick == 'attend') _reply(m, kAttending);
    if (pick == 'decline') _reply(m, kDeclined);
    if (pick == 'member') _openMember(m);
  }

  Future<T?> _sheet<T>(String title, List<_SheetItem<T>> items,
      {String? subtitle}) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: V3.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                            color: V3.barGrey,
                            borderRadius: BorderRadius.circular(3)))),
                const SizedBox(height: 14),
                Text(title, style: V3.tight(20)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: V3.inter(14, color: V3.muted)),
                ],
                const SizedBox(height: 6),
                for (final it in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: it.leading ??
                        Icon(it.icon,
                            color: it.color ?? (it.muted ? V3.muted : V3.green),
                            size: 26),
                    title: Text(it.title,
                        style: V3.inter(17,
                            weight: FontWeight.w500,
                            color:
                                it.color ?? (it.muted ? V3.muted : V3.text))),
                    subtitle: it.subtitle == null
                        ? null
                        : Text(it.subtitle!,
                            style: V3.inter(13, color: V3.muted)),
                    trailing: it.selected
                        ? const Icon(Icons.check, color: V3.green)
                        : null,
                    onTap: () => Navigator.pop(ctx, it.value),
                  ),
              ]),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: AppBar(
        backgroundColor: V3.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: V3.green, size: 32),
            onPressed: () => Navigator.of(context).maybePop()),
        title: Text(
            d?.eventTitle.isNotEmpty == true ? d!.eventTitle : 'Attendance',
            overflow: TextOverflow.ellipsis,
            style: V3.tight(17, weight: FontWeight.w600)),
        actions: [
          if (d != null && d.admin && d.isMatch && d.published)
            IconButton(
                tooltip: 'Export',
                icon: const Icon(Icons.ios_share, color: V3.green),
                onPressed: _export),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: V3.green))
          : _error != null
              ? Center(
                  child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: V3.inter(15, color: V3.muted))))
              : RefreshIndicator(
                  color: V3.green,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                    children: _body(d!),
                  ),
                ),
    );
  }

  List<Widget> _body(AttendanceData d) {
    final rows = d.rows(_tab, _squadFilter);
    final groups = d.groups(rows);
    return [
      _tabs(d),
      if (d.admin && d.isMatch && _tab == kAttending) _squadStrip(d),
      if (d.hasSquads) _squadCards(d),
      if (groups.isEmpty)
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
            child: Text(
                _squadFilter == null
                    ? emptyText(_tab)
                    : 'Nobody here for this squad.',
                textAlign: TextAlign.center,
                style: V3.inter(15, color: V3.muted, height: 1.4))),
      for (final g in groups) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
          child: Row(children: [
            Expanded(
                child: Text(g.$1.plural.toUpperCase(),
                    style: V3.inter(13,
                        weight: FontWeight.w700,
                        color: V3.green,
                        letterSpacing: .8))),
            Text('${g.$2.length}',
                style: V3.inter(13, weight: FontWeight.w600, color: V3.muted)),
          ]),
        ),
        Container(
          decoration: BoxDecoration(
              color: V3.card, borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: [
            for (var i = 0; i < g.$2.length; i++)
              _row(d, g.$2[i], last: i == g.$2.length - 1),
          ]),
        ),
      ],
    ];
  }

  Widget _tabs(AttendanceData d) {
    Widget seg(int tab, Color on) {
      final sel = _tab == tab;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() {
            _tab = tab;
            _squadFilter = null;
          }),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
                color: sel ? V3.card : Colors.transparent,
                borderRadius: BorderRadius.circular(9)),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('${d.count(tab)}',
                  style: V3.tight(16,
                      weight: FontWeight.w700,
                      color: sel ? on : V3.text,
                      height: 1.15)),
              Text(tabLabel(tab),
                  style: V3.inter(13,
                      weight: FontWeight.w600,
                      color: sel ? on : V3.muted,
                      height: 1.2)),
            ]),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: V3.card2, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        seg(kAttending, V3.green),
        seg(kNoReply, V3.text),
        seg(kDeclined, V3.redText),
      ]),
    );
  }

  /// Admins on a match: publish the match day squads (needed before the
  /// export and the lineup), then the published time.
  Widget _squadStrip(AttendanceData d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
          color: V3.card, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        const Icon(Icons.grid_view_outlined, color: V3.green, size: 24),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Match day squads',
              style: V3.inter(15, weight: FontWeight.w600)),
          Text(publishedLabel(d.publishedAt),
              style: V3.inter(13, color: V3.muted)),
        ])),
        const SizedBox(width: 8),
        SizedBox(
          height: 36,
          child: d.published
              ? OutlinedButton.icon(
                  onPressed: _export,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: V3.green,
                      side: const BorderSide(color: V3.green, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.ios_share, size: 16),
                  label: Text('Export',
                      style: V3.inter(13, weight: FontWeight.w600)))
              : FilledButton.icon(
                  onPressed: _publishing ? null : _publish,
                  style: FilledButton.styleFrom(
                      backgroundColor: V3.green,
                      foregroundColor: V3.bg,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  icon: _publishing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: V3.bg))
                      : const Icon(Icons.publish, size: 16),
                  label: Text(d.published ? 'Republish' : 'Publish',
                      style:
                          V3.inter(13, weight: FontWeight.w700, color: V3.bg))),
        ),
      ]),
    );
  }

  /// Squad cards as on the v2 page: wide cards with the squad name, its
  /// picture, the count and role counts (Ken, 2026-11-11: bigger, no All
  /// card). Tap a card to show only that squad, tap it again for everyone.
  Widget _squadCards(AttendanceData d) {
    final cards = d.squadCards(_tab);
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final c = cards[i];
          final sel = c.squadId == _squadFilter;
          final pic = c.squad != null
              ? _SquadDot(c.squad!, size: 44)
              : Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                      color: V3.barGrey, shape: BoxShape.circle));
          return GestureDetector(
            onTap: () => setState(() => _squadFilter = sel ? null : c.squadId),
            child: Container(
              width: 250,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                  color: V3.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: sel ? V3.green : V3.line, width: sel ? 2 : 1.5)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: V3.inter(18,
                                  weight: FontWeight.w600, color: V3.green))),
                      const SizedBox(width: 8),
                      pic,
                    ]),
                    Text('${c.count}',
                        style:
                            V3.tight(34, weight: FontWeight.w700, height: 1.1)),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(c.lines.join('\n'),
                          overflow: TextOverflow.fade,
                          style: V3.inter(15, color: V3.muted, height: 1.35)),
                    ),
                  ]),
            ),
          );
        },
      ),
    );
  }

  Widget _row(AttendanceData d, AttMember m, {required bool last}) {
    final busy = _busy.contains(m.memberId);
    final squad = d.squad(m.squadId);
    final squadLine = Row(mainAxisSize: MainAxisSize.min, children: [
      if (squad != null) ...[
        _SquadDot(squad, size: 12),
        const SizedBox(width: 6),
      ],
      Text(squad != null ? squad.squadName : 'No squad',
          style: V3.inter(13, color: V3.muted)),
      if (d.admin && d.hasSquads) ...[
        const SizedBox(width: 2),
        const Icon(Icons.unfold_more, size: 15, color: V3.muted),
      ],
    ]);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          border:
              last ? null : const Border(bottom: BorderSide(color: V3.line))),
      child: Row(children: [
        V3Avatar(initials(m.firstName, m.lastName), size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: d.admin ? () => _openMember(m) : null,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.memberName, style: V3.inter(16, weight: FontWeight.w500)),
              if (d.hasSquads) ...[
                const SizedBox(height: 2),
                d.admin
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: busy ? null : () => _moveSquad(m),
                        child: squadLine)
                    : squadLine,
              ],
            ]),
          ),
        ),
        if (busy)
          const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: V3.green))
        else if (d.admin)
          IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.more_vert, color: V3.muted),
              onPressed: () => _rowMenu(m)),
      ]),
    );
  }
}

class _SheetItem<T> {
  const _SheetItem(this.icon, this.title, this.subtitle, this.value,
      {this.leading, this.selected = false, this.muted = false, this.color});
  final IconData? icon;
  final String title;
  final String? subtitle;
  final T value;
  final Widget? leading;
  final bool selected, muted;
  final Color? color;
}

/// A squad's picture, or a dot in its colour (green when it has none).
class _SquadDot extends StatelessWidget {
  const _SquadDot(this.squad, {required this.size});
  final AttSquad squad;
  final double size;

  Color get _colour {
    final hex = squad.squadColour.replaceAll('#', '');
    if (hex.length == 6) {
      final v = int.tryParse(hex, radix: 16);
      if (v != null) return Color(0xFF000000 | v);
    }
    return V3.green;
  }

  @override
  Widget build(BuildContext context) {
    if (squad.squadImage.isNotEmpty) {
      return ClipOval(
          child: Image.network(squad.squadImage,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _dot()));
    }
    return _dot();
  }

  Widget _dot() => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: _colour, shape: BoxShape.circle));
}
