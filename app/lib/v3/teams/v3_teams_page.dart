// v3 Teams list: one card per team with crest, counts, your roles and the
// admins' pending-request strip. Mockup: app-v3/teams-design/tm-teams.png.
import 'package:flutter/material.dart';

import '/auth/supabase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '../v3_theme.dart';
import 'v3_team_models.dart';

class V3TeamsPage extends StatefulWidget {
  const V3TeamsPage({super.key});

  // Same route as the FlutterFlow Teams page so the menu link still works.
  static String routeName = 'Teams';
  static String routePath = 'teams';

  @override
  State<V3TeamsPage> createState() => _V3TeamsPageState();
}

class _V3TeamsPageState extends State<V3TeamsPage> {
  List<TeamSummary>? _teams;
  int _overall = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await GetUserTeamSummaryCall.call(
          pUserId: currentUserUid, supabaseJWTtoken: currentJwtToken);
      if (!mounted) return;
      if (!r.succeeded || r.jsonBody is! Map) {
        setState(() => _failed = true);
        return;
      }
      final j = Map<String, dynamic>.from(r.jsonBody as Map);
      final list = (j['teams'] is List) ? j['teams'] as List : const [];
      setState(() {
        _overall = (j['overall_highest_role_level'] as num?)?.toInt() ?? 0;
        _teams = list
            .whereType<Map>()
            .map((e) => TeamSummary.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _open(String route, [Map<String, String>? params]) async {
    await context.pushNamed(route, queryParameters: params ?? const {});
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text('Teams', style: V3.tight(20)),
      ),
      body: _teams == null
          ? Center(
              child: _failed
                  ? Text('Could not load your teams.',
                      style: V3.inter(15, color: V3.muted))
                  : const CircularProgressIndicator(color: V3.green))
          : RefreshIndicator(
              color: V3.green,
              backgroundColor: V3.card,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                children: [
                  // Join / Create sit at the top, the user's teams below
                  // (Ken, 2026-11-09).
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 6, 0, 18),
                    child: Row(children: [
                      Expanded(
                          child: _outlineButton(
                              Icons.keyboard_alt_outlined,
                              'Join a team',
                              () => _open(JoinTeamNewWidget.routeName))),
                      if (_overall >= 110) ...[
                        const SizedBox(width: 10),
                        Expanded(
                            child: _outlineButton(Icons.add, 'Create a team',
                                () => _open(CreateTeamNewWidget.routeName))),
                      ],
                    ]),
                  ),
                  if (_teams!.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 10, 4, 20),
                      child: Text(
                          'You are not on a team yet. Join one with the code from your coach, or create a new team.',
                          style: V3.inter(15.5, color: V3.muted, height: 1.4)),
                    ),
                  for (final t in _teams!) _teamCard(t),
                ],
              ),
            ),
    );
  }

  Widget _teamCard(TeamSummary t) {
    final admin = t.roleLevel >= 100;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: V3.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _open(V3TeamPage.routeName,
              {'teamID': serializeParam(t.teamId, ParamType.int)!}),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              Row(children: [
                V3Crest(t.clubCrest, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.teamName, style: V3.tight(18)),
                        const SizedBox(height: 3),
                        Text(
                            [
                              if (t.clubName.isNotEmpty) t.clubName,
                              '${t.players} ${t.players == 1 ? 'player' : 'players'}',
                            ].join(' · '),
                            style: V3.inter(14, color: V3.muted)),
                        const SizedBox(height: 7),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final r in t.rolesSorted)
                            V3Pill(r,
                                green: r == 'Admin' ||
                                    r == 'SuperUser' ||
                                    r == 'Coach'),
                        ]),
                      ]),
                ),
                const Icon(Icons.chevron_right, color: V3.muted, size: 24),
              ]),
              if (admin && t.pending > 0) ...[
                const SizedBox(height: 12),
                V3PendingStrip(t.pending,
                    onTap: () => _open(PendingRequestsWidget.routeName, {
                          'paramTeamID':
                              serializeParam(t.teamId, ParamType.int)!
                        })),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _outlineButton(IconData icon, String label, VoidCallback onTap) =>
      SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
              foregroundColor: V3.green,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              side: const BorderSide(color: V3.green, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14))),
          icon: Icon(icon, size: 20),
          label: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: V3.inter(15, weight: FontWeight.w700, color: V3.green)),
        ),
      );
}
