// v3 Member page: name, code, linked accounts, roles, squads, statistics
// and remove. Admins edit; coaches read. Mockup: tm-member.png.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '/auth/supabase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '../v3_theme.dart';
import 'v3_team_models.dart';

class V3MemberPage extends StatefulWidget {
  const V3MemberPage({super.key, required this.memberId, required this.teamId});
  final int memberId;
  final int teamId;

  // Same route as the FlutterFlow MemberDetails page.
  static String routeName = 'MemberDetails';
  static String routePath = 'MemberDetails';

  @override
  State<V3MemberPage> createState() => _V3MemberPageState();
}

class _V3MemberPageState extends State<V3MemberPage> {
  MemberDetails? _m;
  TeamRoster? _roster;
  DateTime? _joined;
  bool _failed = false;
  bool _busy = false;

  bool get _admin => (_roster?.userRoleLevel ?? 0) >= 100;
  TeamMember? get _rosterMember => _roster?.member(widget.memberId);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        GetMemberTeamDetailsCall.call(
            supabaseJWTtoken: currentJwtToken,
            pMemberId: widget.memberId,
            pTeamId: widget.teamId),
        GetTeamMembersByRoleCall.call(
            pUserId: currentUserUid,
            supabaseJWTtoken: currentJwtToken,
            pTeamId: widget.teamId),
        MemberTeamLinkTable().queryRows(
            queryFn: (q) => q
                .eq('member_id', widget.memberId)
                .eq('team_id', widget.teamId)),
      ]);
      if (!mounted) return;
      final d = results[0] as ApiCallResponse;
      final r = results[1] as ApiCallResponse;
      final links = results[2] as List<MemberTeamLinkRow>;
      if (!d.succeeded || d.jsonBody is! Map) {
        setState(() => _failed = true);
        return;
      }
      setState(() {
        _m = MemberDetails.fromJson(
            Map<String, dynamic>.from(d.jsonBody as Map));
        _roster = r.succeeded && r.jsonBody is Map
            ? TeamRoster.fromJson(Map<String, dynamic>.from(r.jsonBody as Map))
            : null;
        _joined = links.isNotEmpty ? links.first.createdAt : null;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _snack(String text, {bool warn = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: warn ? V3.red : V3.card2,
          content: Text(text,
              style:
                  V3.inter(15, weight: FontWeight.w500, color: Colors.white))));

  Future<void> _run(Future<void> Function() action, String failText) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } catch (_) {
      if (mounted) _snack(failText, warn: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editName() async {
    final m = _m!;
    final first = TextEditingController(text: m.firstName);
    final last = TextEditingController(text: m.lastName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: V3.card,
        title: Text('Edit name', style: V3.tight(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _dialogField(first, 'First name'),
          const SizedBox(height: 10),
          _dialogField(last, 'Last name'),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: V3.inter(15, color: V3.muted))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Save',
                  style:
                      V3.inter(15, weight: FontWeight.w700, color: V3.green))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final f = first.text.trim(), l = last.text.trim();
    if (f.isEmpty && l.isEmpty) return;
    await _run(
        () => MembersTable().update(
            data: {'first_name': f, 'last_name': l},
            matchingRows: (q) => q.eq('member_id', widget.memberId)),
        'Could not save the name.');
  }

  Widget _dialogField(TextEditingController c, String label) => TextField(
        controller: c,
        textCapitalization: TextCapitalization.words,
        style: V3.inter(16),
        cursorColor: V3.green,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: V3.inter(14, color: V3.muted),
          filled: true,
          fillColor: V3.bg,
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: V3.line)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: V3.green, width: 1.5)),
        ),
      );

  Future<void> _toggleRole(MemberRole role) async {
    final m = _m!;
    final has = m.hasRole(role.roleId);
    if (has && m.roles.length == 1) {
      _snack('A member must hold at least one role.', warn: true);
      return;
    }
    await _run(() async {
      final links = await MemberTeamLinkTable().queryRows(
          queryFn: (q) =>
              q.eq('member_id', widget.memberId).eq('team_id', widget.teamId));
      if (links.isEmpty) throw StateError('no link');
      final mtId = links.first.memberTeamId;
      if (has) {
        await MemberTeamRoleLinkTable().delete(
            matchingRows: (q) =>
                q.eq('member_team_id', mtId).eq('role_id', role.roleId));
      } else {
        await MemberTeamRoleLinkTable()
            .insert({'member_team_id': mtId, 'role_id': role.roleId});
      }
    }, 'Could not change the role.');
  }

  Future<void> _pickSquad(ClubCode code) async {
    final squads = await SquadsTable().queryRows(
        queryFn: (q) => q
            .eq('team_id', widget.teamId)
            .order('squad_list_seq', ascending: true));
    if (!mounted) return;
    final current = _rosterMember?.squadFor(code.codeId)?.squadId ?? 0;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: V3.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
                Text('${code.name} squad', style: V3.tight(20)),
                const SizedBox(height: 6),
                for (final s in squads)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ClipOval(
                        child: (s.squadImage ?? '').isNotEmpty
                            ? Image.network(s.squadImage!,
                                width: 30, height: 30, fit: BoxFit.cover)
                            : Container(
                                width: 30, height: 30, color: V3.green)),
                    title: Text(s.squadName ?? '',
                        style: V3.inter(17, weight: FontWeight.w500)),
                    trailing: s.squadId == current
                        ? const Icon(Icons.check, color: V3.green)
                        : null,
                    onTap: () => Navigator.pop(context, s.squadId),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.remove_circle_outline,
                      color: V3.muted, size: 28),
                  title: Text('No squad',
                      style: V3.inter(17,
                          weight: FontWeight.w500, color: V3.muted)),
                  trailing: current == 0
                      ? const Icon(Icons.check, color: V3.green)
                      : null,
                  onTap: () => Navigator.pop(context, 0),
                ),
              ]),
        ),
      ),
    );
    if (picked == null || picked == current || !mounted) return;
    await _run(() async {
      final existing = await MemberSquadLinkTable().queryRows(
          queryFn: (q) => q
              .eq('member_id', widget.memberId)
              .eq('team_id', widget.teamId)
              .eq('code_id', code.codeId));
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
          'member_id': widget.memberId,
          'squad_id': picked,
          'code_id': code.codeId,
          'team_id': widget.teamId,
        });
      }
    }, 'Could not change the squad.');
  }

  Future<void> _remove() async {
    final m = _m!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: V3.card,
        title: Text('Remove ${m.firstName}?', style: V3.tight(20)),
        content: Text(
            '${m.fullName} will be removed from ${m.teamName}. Their past attendance stays on record.',
            style: V3.inter(15, color: V3.muted, height: 1.4)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: V3.inter(15, color: V3.muted))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Remove',
                  style: V3.inter(15,
                      weight: FontWeight.w700, color: V3.redText))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final r = await RemoveMemberFromTeamCall.call(
        supabaseJWTtoken: currentJwtToken,
        pMemberId: widget.memberId,
        pTeamId: widget.teamId);
    if (!mounted) return;
    if (r.succeeded) {
      context.safePop();
    } else {
      setState(() => _busy = false);
      _snack('Could not remove this member. Please try again.', warn: true);
    }
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: _m!.memberCode));
    if (mounted) _snack('Member code copied.');
  }

  @override
  Widget build(BuildContext context) {
    final m = _m;
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: AppBar(
        backgroundColor: V3.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: V3.green, size: 40),
            onPressed: () => context.safePop()),
        title: Text('Member', style: V3.tight(20)),
      ),
      body: m == null
          ? Center(
              child: _failed
                  ? Text('Could not load this member.',
                      style: V3.inter(15, color: V3.muted))
                  : const CircularProgressIndicator(color: V3.green))
          : Stack(children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
                children: [
                  Row(children: [
                    V3Avatar(initials(m.firstName, m.lastName), size: 64),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.fullName, style: V3.tight(24)),
                            const SizedBox(height: 3),
                            GestureDetector(
                              onTap: _copyCode,
                              child: Text.rich(TextSpan(
                                style: V3.inter(14, color: V3.muted),
                                children: [
                                  const TextSpan(text: 'Member code '),
                                  TextSpan(
                                      text: m.memberCode,
                                      style: V3.inter(14,
                                          weight: FontWeight.w700)),
                                  TextSpan(
                                      text: ' · Copy',
                                      style: V3.inter(14,
                                          weight: FontWeight.w600,
                                          color: V3.green)),
                                ],
                              )),
                            ),
                          ]),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  _infoCard(m),
                  _section('Roles'),
                  _roles(m),
                  if (_roster != null &&
                      _roster!.codes.isNotEmpty &&
                      m.roles.any((r) => r.roleLevel == 10)) ...[
                    _section('Squads'),
                    _squads(),
                  ],
                  const SizedBox(height: 22),
                  if ((_roster?.userRoleLevel ?? 0) >= 20)
                    _outline(
                        'Statistics',
                        Icons.bar_chart,
                        V3.green,
                        () => context.pushNamed(MemberAnalyticsWidget.routeName,
                                queryParameters: {
                                  'memberId': serializeParam(
                                      widget.memberId, ParamType.int)!,
                                })),
                  if (_admin)
                    _outline('Remove from team', null, V3.redText, _remove,
                        border: V3.red),
                ],
              ),
              if (_busy)
                const Positioned.fill(
                    child: ColoredBox(
                        color: Color(0x66000000),
                        child: Center(
                            child:
                                CircularProgressIndicator(color: V3.green)))),
            ]),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
        child: Text(t, style: V3.tight(19, weight: FontWeight.w700)),
      );

  Widget _row(String k, Widget v, {bool last = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
            border:
                last ? null : const Border(bottom: BorderSide(color: V3.line))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 120,
              child: Text(k, style: V3.inter(14.5, color: V3.muted))),
          Expanded(child: Align(alignment: Alignment.centerRight, child: v)),
        ]),
      );

  Widget _infoCard(MemberDetails m) {
    final joined = _joined == null
        ? ''
        : DateFormat('MMM yyyy').format(_joined!.toLocal());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
          color: V3.card, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        _row(
            'Name',
            Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                  child: Text(m.fullName,
                      style: V3.inter(16, weight: FontWeight.w500))),
              if (_admin)
                GestureDetector(
                  onTap: _editName,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text('Edit',
                        style: V3.inter(14,
                            weight: FontWeight.w600, color: V3.green)),
                  ),
                ),
            ])),
        _row(
            m.linkedUsers.length == 1 ? 'Linked account' : 'Linked accounts',
            m.linkedUsers.isEmpty
                ? Text('None yet', style: V3.inter(15, color: V3.muted))
                : Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    for (final u in m.linkedUsers) ...[
                      Text(u.name.isEmpty ? u.email : u.name,
                          style: V3.inter(15.5, weight: FontWeight.w500)),
                      if (u.name.isNotEmpty)
                        Text(u.email, style: V3.inter(13, color: V3.muted)),
                      if (u != m.linkedUsers.last) const SizedBox(height: 6),
                    ],
                  ]),
            last: joined.isEmpty),
        if (joined.isNotEmpty)
          _row('Joined',
              Text(joined, style: V3.inter(16, weight: FontWeight.w500)),
              last: true),
      ]),
    );
  }

  Widget _roles(MemberDetails m) {
    final roles = m.validRoles.isNotEmpty ? m.validRoles : m.roles;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final r in roles)
          GestureDetector(
            onTap: _admin && !_busy ? () => _toggleRole(r) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: m.hasRole(r.roleId) ? V3.greenTint : V3.card2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: m.hasRole(r.roleId) ? V3.green : Colors.transparent,
                    width: 1.5),
              ),
              child: Text(r.roleName,
                  style: V3.inter(15,
                      weight: FontWeight.w600,
                      color: m.hasRole(r.roleId) ? V3.green : V3.muted)),
            ),
          ),
      ]),
      if (_admin)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
              'Tap to add or remove a role. A member always keeps at least one.',
              style: V3.inter(13.5, color: V3.muted, height: 1.4)),
        ),
    ]);
  }

  Widget _squads() {
    final r = _roster!;
    final rm = _rosterMember;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
          color: V3.card, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        for (final c in r.codes)
          _row(
              c.name,
              V3SquadChip(rm?.squadFor(c.codeId),
                  onTap: _admin ? () => _pickSquad(c) : null),
              last: c == r.codes.last),
      ]),
    );
  }

  Widget _outline(String label, IconData? icon, Color color, VoidCallback onTap,
          {Color? border}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: _busy ? null : onTap,
            style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: border ?? color, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[
                Icon(icon, size: 22, color: color),
                const SizedBox(width: 8)
              ],
              Text(label,
                  style: V3.inter(16, weight: FontWeight.w700, color: color)),
            ]),
          ),
        ),
      );
}
