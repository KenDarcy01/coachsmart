// v3 Team page: crest and counts, team code with Share, pending strip,
// code chips, search, then members grouped by role with squad chips.
// Mockup: app-v3/teams-design/tm-team.png.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '/auth/supabase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '../v3_theme.dart';
import 'v3_team_models.dart';

class V3TeamPage extends StatefulWidget {
  const V3TeamPage({super.key, required this.teamId});
  final int teamId;

  // Same route as the FlutterFlow TeamMembers page.
  static String routeName = 'TeamMembers';
  static String routePath = 'teamMembers';

  @override
  State<V3TeamPage> createState() => _V3TeamPageState();
}

class _V3TeamPageState extends State<V3TeamPage> {
  TeamRoster? _roster;
  TeamSummary? _summary;
  bool _failed = false;
  int? _codeId; // which code's squads are shown
  final _search = TextEditingController();

  bool get _admin => (_roster?.userRoleLevel ?? 0) >= 100;
  bool get _canOpenMember => (_roster?.userRoleLevel ?? 0) >= 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        GetTeamMembersByRoleCall.call(
            pUserId: currentUserUid,
            supabaseJWTtoken: currentJwtToken,
            pTeamId: widget.teamId),
        GetUserTeamSummaryCall.call(
            pUserId: currentUserUid, supabaseJWTtoken: currentJwtToken),
      ]);
      if (!mounted) return;
      final r = results[0];
      if (!r.succeeded || r.jsonBody is! Map) {
        setState(() => _failed = true);
        return;
      }
      final roster =
          TeamRoster.fromJson(Map<String, dynamic>.from(r.jsonBody as Map));
      TeamSummary? summary;
      final s = results[1];
      if (s.succeeded && s.jsonBody is Map) {
        final teams = (s.jsonBody as Map)['teams'];
        if (teams is List) {
          for (final t in teams.whereType<Map>()) {
            final ts = TeamSummary.fromJson(Map<String, dynamic>.from(t));
            if (ts.teamId == widget.teamId) summary = ts;
          }
        }
      }
      setState(() {
        _roster = roster;
        _summary = summary;
        _failed = false;
        _codeId ??= roster.codes.isNotEmpty ? roster.codes.first.codeId : null;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: V3.card2,
          content: Text(text, style: V3.inter(15, weight: FontWeight.w500))));

  Future<void> _shareCode() async {
    final r = _roster!;
    final text =
        'Join ${r.teamName} on CoachSmart. Open the app, choose Join a team and enter the code ${r.teamCode}. Get CoachSmart at https://coachsmart.app';
    try {
      if (kIsWeb) throw UnsupportedError('web');
      await SharePlus.instance.share(
          ShareParams(text: text, subject: 'Join ${r.teamName} on CoachSmart'));
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) _snack('Invite text copied. Paste it into a message.');
    }
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: _roster!.teamCode));
    if (mounted) _snack('Team code copied.');
  }

  Future<void> _export() async {
    final r = await ExportTeamListXLSCall.call(
        pTeamId: widget.teamId, userEmail: currentUserEmail);
    if (!mounted) return;
    _snack(r.succeeded
        ? 'The team list is on its way to $currentUserEmail.'
        : 'Could not export the team list. Please try again.');
  }

  Future<void> _openPending() async {
    await context.pushNamed(PendingRequestsWidget.routeName, queryParameters: {
      'paramTeamID': serializeParam(widget.teamId, ParamType.int)!,
    });
    if (mounted) _load();
  }

  Future<void> _openMember(TeamMember m) async {
    if (!_canOpenMember) return;
    await context.pushNamed(V3MemberPage.routeName, queryParameters: {
      'memberID': serializeParam(m.memberId, ParamType.int)!,
      'teamID': serializeParam(widget.teamId, ParamType.int)!,
    });
    if (mounted) _load();
  }

  Future<void> _pickSquad(TeamMember m) async {
    final codeId = _codeId;
    if (!_admin || codeId == null) return;
    final squads = await SquadsTable().queryRows(
        queryFn: (q) => q
            .eq('team_id', widget.teamId)
            .order('squad_list_seq', ascending: true));
    if (!mounted) return;
    final current = m.squadFor(codeId)?.squadId ?? 0;
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
                Text('${m.firstName}: ${_codeName(codeId)} squad',
                    style: V3.tight(20)),
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
    try {
      final existing = await MemberSquadLinkTable().queryRows(
          queryFn: (q) => q
              .eq('member_id', m.memberId)
              .eq('team_id', widget.teamId)
              .eq('code_id', codeId));
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
          'code_id': codeId,
          'team_id': widget.teamId,
        });
      }
      await _load();
    } catch (_) {
      if (mounted) _snack('Could not change the squad. Please try again.');
    }
  }

  String _codeName(int codeId) {
    for (final c in _roster!.codes) {
      if (c.codeId == codeId) return c.name;
    }
    return '';
  }

  void _menu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: V3.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                  color: V3.barGrey, borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.ios_share, color: V3.text),
            title: Text('Email me the team list (Excel)',
                style: V3.inter(16, weight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(context);
              _export();
            },
          ),
          ListTile(
            leading: const Icon(Icons.how_to_reg_outlined, color: V3.text),
            title: Text('Pending requests',
                style: V3.inter(16, weight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(context);
              _openPending();
            },
          ),
          const SizedBox(height: 10),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _roster;
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: AppBar(
        backgroundColor: V3.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: V3.green, size: 30),
            onPressed: () => context.safePop()),
        title: Text('Team', style: V3.tight(20)),
        actions: [
          if (_admin)
            IconButton(
                icon: const Icon(Icons.more_vert, color: V3.muted),
                onPressed: _menu),
        ],
      ),
      body: r == null
          ? Center(
              child: _failed
                  ? Text('Could not load this team.',
                      style: V3.inter(15, color: V3.muted))
                  : const CircularProgressIndicator(color: V3.green))
          : RefreshIndicator(
              color: V3.green,
              backgroundColor: V3.card,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 40),
                children: [
                  _header(r),
                  _codeCard(r),
                  if (_admin && (_summary?.pending ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: V3PendingStrip(_summary!.pending,
                          onTap: _openPending),
                    ),
                  if (_admin && r.codes.length > 1) _codeChips(r),
                  _searchField(),
                  for (final g in r.groups) ..._group(g),
                ],
              ),
            ),
    );
  }

  Widget _header(TeamRoster r) {
    final players = _summary?.players ?? r.count((l) => l == 10);
    final coaches = _summary?.coaches ?? r.count((l) => l >= 20 && l < 100);
    final admins = _summary?.admins ?? r.count((l) => l >= 100);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 14),
      child: Row(children: [
        V3Crest(_summary?.clubCrest ?? '', size: 64),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.teamName, style: V3.tight(22)),
            const SizedBox(height: 3),
            Text(
                [
                  if ((_summary?.clubName ?? '').isNotEmpty) _summary!.clubName,
                  countsLine(players, coaches, admins),
                ].join(' · '),
                style: V3.inter(14, color: V3.muted, height: 1.3)),
          ]),
        ),
      ]),
    );
  }

  Widget _codeCard(TeamRoster r) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: V3.card,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _copyCode,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Team code · share it to invite',
                            style: V3.inter(13, color: V3.muted)),
                        const SizedBox(height: 2),
                        Text(r.teamCode,
                            style: V3
                                .tight(20, weight: FontWeight.w700)
                                .copyWith(letterSpacing: 1.5)),
                      ]),
                ),
                FilledButton(
                  onPressed: _shareCode,
                  style: FilledButton.styleFrom(
                      backgroundColor: V3.green,
                      foregroundColor: V3.bg,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  child: Text('Share',
                      style:
                          V3.inter(14, weight: FontWeight.w700, color: V3.bg)),
                ),
              ]),
            ),
          ),
        ),
      );

  Widget _codeChips(TeamRoster r) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in r.codes)
            GestureDetector(
              onTap: () => setState(() => _codeId = c.codeId),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                    color: c.codeId == _codeId ? V3.green : V3.card,
                    borderRadius: BorderRadius.circular(20)),
                child: Text(c.name,
                    style: V3.inter(14.5,
                        weight: FontWeight.w600,
                        color: c.codeId == _codeId ? V3.bg : V3.muted)),
              ),
            ),
        ]),
      );

  Widget _searchField() => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          style: V3.inter(15.5),
          cursorColor: V3.green,
          decoration: InputDecoration(
            hintText: 'Search members',
            hintStyle: V3.inter(15, color: const Color(0xFF6F737C)),
            prefixIcon: const Icon(Icons.search, color: V3.muted),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, color: V3.muted, size: 20),
                    onPressed: () => setState(() => _search.clear())),
            filled: true,
            fillColor: V3.card,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: V3.line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: V3.green, width: 1.5)),
          ),
        ),
      );

  List<Widget> _group(RoleGroup g) {
    final q = _search.text.trim().toLowerCase();
    final members = q.isEmpty
        ? g.members
        : g.members.where((m) => m.fullName.toLowerCase().contains(q)).toList();
    if (members.isEmpty) return const [];
    final showSquad = g.roleLevel == 10 && _codeId != null;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 2),
        child: Row(children: [
          Text(g.roleNamePlural, style: V3.tight(17, weight: FontWeight.w700)),
          const Spacer(),
          Text('${members.length}',
              style: V3.inter(14, weight: FontWeight.w600, color: V3.muted)),
        ]),
      ),
      for (final m in members)
        InkWell(
          onTap: _canOpenMember ? () => _openMember(m) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: V3.line))),
            child: Row(children: [
              V3Avatar(initials(m.firstName, m.lastName),
                  highlight: g.roleLevel >= 100),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(m.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: V3.inter(16.5, weight: FontWeight.w500))),
              if (showSquad)
                V3SquadChip(m.squadFor(_codeId!),
                    onTap: _admin ? () => _pickSquad(m) : null),
              if (_canOpenMember) ...[
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: V3.muted, size: 22),
              ],
            ]),
          ),
        ),
    ];
  }
}
