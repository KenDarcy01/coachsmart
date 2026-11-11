// v3 Requests for one team (the FlutterFlow Pending Requests page): join
// requests with Approve (role sheet) / Decline, and access requests with
// Give access / Decline. Same calls as v2: get_pending_team_requests,
// confirm_member_join, deny_member_join, confirm_user_member_access,
// deny_user_member_access.
import 'package:flutter/material.dart';

import '/backend/supabase/supabase.dart';
import '/custom_code/actions/index.dart' as actions;
import '../v3_theme.dart';
import 'v3_requests_models.dart';
import 'v3_role_picker.dart';
import 'v3_team_models.dart' show V3Avatar, initials;

class V3RequestsPage extends StatefulWidget {
  const V3RequestsPage(
      {super.key, required this.teamId, this.testData, this.testTeamName});

  final int teamId;

  /// Widget tests pass the RPC result here instead of calling Supabase.
  @visibleForTesting
  final Map<String, dynamic>? testData;
  @visibleForTesting
  final String? testTeamName;

  @override
  State<V3RequestsPage> createState() => _V3RequestsPageState();
}

class _V3RequestsPageState extends State<V3RequestsPage> {
  TeamRequests? _data;
  String _teamName = '';
  bool _loading = true;
  String? _error;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.testData != null) {
      setState(() {
        _data = TeamRequests.fromJson(widget.testData!);
        _teamName = widget.testTeamName ?? '';
        _loading = false;
      });
      return;
    }
    try {
      final r = await SupaFlow.client.rpc('get_pending_team_requests',
          params: {'p_team_id': widget.teamId});
      final d = TeamRequests.fromJson(r is Map ? r : const {});
      if (_teamName.isEmpty) {
        try {
          final t = await TeamsTable().queryRows(
              queryFn: (q) => q.eq('team_id', widget.teamId).limit(1));
          if (t.isNotEmpty) _teamName = t.first.teamName ?? '';
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
        _error = d.ok ? null : 'Requests could not be loaded.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Requests could not be loaded.';
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

  String _key(TeamRequest r) => '${r.isAccess ? 'a' : 'j'}${r.refId}';

  // ---------------------------------------------------------------- actions

  Future<void> _approveJoin(TeamRequest r) async {
    var roles = _data?.roles ?? const [];
    if (roles.isEmpty) {
      try {
        final x = await SupaFlow.client
            .rpc('get_team_roles', params: {'p_team_id': widget.teamId});
        roles = x is List ? x : const [];
      } catch (_) {}
    }
    if (!mounted) return;
    if (roles.isEmpty) {
      _snack('No roles found for this team.', warn: true);
      return;
    }
    final picked = await pickRoles(context,
        roles: roles,
        title: _teamName.isEmpty ? r.name : '${r.name} · $_teamName');
    if (picked == null || picked.isEmpty || !mounted) return;
    await _run(r, () async {
      final x = await SupaFlow.client.rpc('confirm_member_join', params: {
        'p_member_team_id': r.refId,
        'p_role_ids': picked,
      });
      if (x is Map && x['success'] == false) throw Exception(x['message']);
      return '${r.name} added to the team';
    });
  }

  Future<void> _declineJoin(TeamRequest r) => _run(r, () async {
        await SupaFlow.client
            .rpc('deny_member_join', params: {'p_member_team_id': r.refId});
        return 'Request declined';
      });

  Future<void> _approveAccess(TeamRequest r) => _run(r, () async {
        await SupaFlow.client.rpc('confirm_user_member_access',
            params: {'p_user_member_id': r.refId});
        return 'Access given';
      });

  Future<void> _declineAccess(TeamRequest r) => _run(r, () async {
        await SupaFlow.client.rpc('deny_user_member_access',
            params: {'p_user_member_id': r.refId});
        return 'Access declined';
      });

  Future<void> _run(TeamRequest r, Future<String> Function() work) async {
    final k = _key(r);
    setState(() => _busy.add(k));
    try {
      final msg = await work();
      await _load();
      try {
        await actions.updateAppBadge();
      } catch (_) {}
      _snack(msg);
    } catch (_) {
      _snack('That did not go through. Please try again.', warn: true);
    } finally {
      if (mounted) setState(() => _busy.remove(k));
    }
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
            icon: const Icon(Icons.chevron_left, color: V3.green, size: 40),
            onPressed: () => Navigator.of(context).maybePop()),
        title: Text('Requests', style: V3.tight(20)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: V3.green))
          : _error != null || d == null
              ? Center(
                  child: Text(_error ?? 'Requests could not be loaded.',
                      style: V3.inter(15, color: V3.muted)))
              : RefreshIndicator(
                  color: V3.green,
                  onRefresh: _load,
                  child: d.isEmpty
                      ? ListView(children: [_empty()])
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                          children: [
                            if (d.joins.isNotEmpty) ...[
                              _section('Join requests', d.joins.length),
                              for (final r in d.joins) _card(r),
                            ],
                            if (d.access.isNotEmpty) ...[
                              _section('Access requests', d.access.length),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(
                                    "Someone wants to see an existing member's events and reply for them, like a second parent.",
                                    style: V3.inter(13.5,
                                        color: V3.muted, height: 1.45)),
                              ),
                              for (final r in d.access) _card(r),
                            ],
                          ],
                        ),
                ),
    );
  }

  Widget _empty() => Padding(
        padding: const EdgeInsets.fromLTRB(32, 140, 32, 32),
        child: Column(children: [
          Text('No requests waiting.',
              textAlign: TextAlign.center, style: V3.inter(16)),
          const SizedBox(height: 6),
          Text(
              _teamName.isEmpty
                  ? 'New join and access requests for this team show up here.'
                  : 'New join and access requests for $_teamName show up here.',
              textAlign: TextAlign.center,
              style: V3.inter(14, color: V3.muted, height: 1.4)),
        ]),
      );

  Widget _section(String title, int count) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
        child: Row(children: [
          Expanded(
              child: Text(title.toUpperCase(),
                  style: V3.inter(13,
                      weight: FontWeight.w700,
                      color: V3.green,
                      letterSpacing: .8))),
          Text('$count', style: V3.inter(13, color: V3.muted)),
        ]),
      );

  Widget _card(TeamRequest r) {
    final busy = _busy.contains(_key(r));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
          color: V3.card, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.only(top: 2),
              child: V3Avatar(initials(r.firstName, r.lastName))),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name, style: V3.inter(16, weight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(r.subtitle(_teamName),
                  style: V3.inter(13, color: V3.muted, height: 1.35)),
            ]),
          ),
          const SizedBox(width: 8),
          Text(whenLabel(r.requestedAt, DateTime.now()),
              style: V3.inter(12.5, color: V3.muted)),
        ]),
        const SizedBox(height: 10),
        busy
            ? const SizedBox(
                height: 38,
                child: Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: V3.green))))
            : Row(children: [
                Expanded(
                    child: FilledButton.icon(
                        onPressed: () =>
                            r.isAccess ? _approveAccess(r) : _approveJoin(r),
                        style: FilledButton.styleFrom(
                            backgroundColor: V3.green,
                            foregroundColor: V3.bg,
                            minimumSize: const Size(0, 38),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        icon: const Icon(Icons.check, size: 18),
                        label: Text(r.isAccess ? 'Give access' : 'Approve',
                            style: V3.inter(14,
                                weight: FontWeight.w600, color: V3.bg)))),
                const SizedBox(width: 8),
                Expanded(
                    child: FilledButton(
                        onPressed: () =>
                            r.isAccess ? _declineAccess(r) : _declineJoin(r),
                        style: FilledButton.styleFrom(
                            backgroundColor: V3.card2,
                            foregroundColor: V3.redText,
                            minimumSize: const Size(0, 38),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        child: Text('Decline',
                            style: V3.inter(14,
                                weight: FontWeight.w600, color: V3.redText)))),
              ]),
      ]),
    );
  }
}
