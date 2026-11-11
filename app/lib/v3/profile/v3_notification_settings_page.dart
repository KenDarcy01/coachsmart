// v3 Notification settings (Ken, 2026-11-11).
//
// How you hear from us: Push or Email (phone app only; the web app always
// uses email, because it saves no push token). Email clears users.fcm_token,
// which every send already treats as "email", so no server change is needed.
//
// Attendance alerts (admins only): the event's own rule stays the parent rule;
// each admin can turn it down for themselves per team. Stored in
// admin_alert_prefs through get_my_admin_alert_prefs / set_my_admin_alert_pref;
// notify_admins_attendance_change honours it (v2 too).
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/flutter_flow_util.dart';
import '../v3_theme.dart';
import 'v3_profile_models.dart';

/// One team the user manages, with their own attendance alert choice.
class AdminAlertPref {
  const AdminAlertPref(this.teamId, this.teamName, this.clubName, this.choice);
  final int teamId;
  final String teamName;
  final String clubName;

  /// 'event', 'changes' or 'off'.
  final String choice;

  AdminAlertPref copyWith(String c) =>
      AdminAlertPref(teamId, teamName, clubName, c);

  static List<AdminAlertPref> listFrom(dynamic rows) => [
        for (final r in (rows as List? ?? const []))
          AdminAlertPref(
            (r['team_id'] as num).toInt(),
            (r['team_name'] ?? '').toString(),
            (r['club_name'] ?? '').toString(),
            (r['attendance_alerts'] ?? 'event').toString(),
          ),
      ];
}

const kAlertChoices = <(String, String, String)>[
  ('event', 'Default', 'Alerts as set on each event'),
  ('changes', 'Changes of mind', 'Only when someone changes their answer'),
  ('off', 'None', 'No attendance alerts'),
];

String alertChoiceLabel(String c) => kAlertChoices
    .firstWhere((x) => x.$1 == c, orElse: () => kAlertChoices[0])
    .$2;

class V3NotificationSettingsPage extends StatefulWidget {
  const V3NotificationSettingsPage(
      {super.key, this.testTeams, this.testIsWeb, this.testPush});

  /// Widget tests pass these instead of calling Supabase / the platform.
  @visibleForTesting
  final List<AdminAlertPref>? testTeams;
  @visibleForTesting
  final bool? testIsWeb;
  @visibleForTesting
  final bool? testPush;

  @override
  State<V3NotificationSettingsPage> createState() =>
      _V3NotificationSettingsPageState();
}

class _V3NotificationSettingsPageState
    extends State<V3NotificationSettingsPage> {
  List<AdminAlertPref> _teams = const [];
  bool _loading = true;
  bool _push = true;
  bool _busyPush = false;
  int? _busyTeam;

  bool get _web => widget.testIsWeb ?? kIsWeb;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.testTeams != null) {
      setState(() {
        _teams = widget.testTeams!;
        _push = widget.testPush ?? true;
        _loading = false;
      });
      return;
    }
    final push = await PushPref.enabled();
    List<AdminAlertPref> teams = const [];
    try {
      teams = AdminAlertPref.listFrom(
          await SupaFlow.client.rpc('get_my_admin_alert_prefs'));
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _push = push;
      _teams = teams;
      _loading = false;
    });
  }

  void _snack(String m, {bool warn = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: warn ? V3.redText : V3.card2,
        content: Text(m, style: V3.inter(14, color: V3.text))));
  }

  Future<void> _setPush(bool on) async {
    if (on == _push || _busyPush) return;
    setState(() {
      _push = on;
      _busyPush = true;
    });
    if (widget.testTeams != null) {
      setState(() => _busyPush = false);
      return;
    }
    await PushPref.setEnabled(on);
    try {
      var token = '';
      if (on) {
        await actions.setFCMToken();
        final t = FFAppState().fcmToken;
        token = t.startsWith('Running on web') ? '' : t;
      }
      await UsersTable().update(
        data: {'fcm_token': token},
        matchingRows: (rows) => rows.eq('user_id', currentUserUid),
      );
      _snack(on
          ? 'Notifications will come as push'
          : 'Notifications will come by email');
    } catch (_) {
      _snack('Could not change this. Please try again.', warn: true);
    }
    if (mounted) setState(() => _busyPush = false);
  }

  Future<void> _pickAlert(AdminAlertPref t) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: V3.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                          color: V3.barGrey,
                          borderRadius: BorderRadius.circular(3)))),
              const SizedBox(height: 14),
              Text(t.teamName, style: V3.tight(19)),
              const SizedBox(height: 4),
              Text('Your attendance alerts',
                  style: V3.inter(13.5, color: V3.muted)),
              const SizedBox(height: 8),
              for (final c in kAlertChoices)
                _choiceRow(c.$2, c.$3, t.choice == c.$1,
                    () => Navigator.of(ctx).pop(c.$1)),
            ],
          ),
        ),
      ),
    );
    if (picked == null || picked == t.choice) return;
    final i = _teams.indexWhere((x) => x.teamId == t.teamId);
    setState(() {
      _teams = [..._teams]..[i] = t.copyWith(picked);
      _busyTeam = t.teamId;
    });
    if (widget.testTeams != null) {
      setState(() => _busyTeam = null);
      return;
    }
    try {
      await SupaFlow.client.rpc('set_my_admin_alert_pref',
          params: {'p_team_id': t.teamId, 'p_choice': picked});
    } catch (_) {
      if (mounted) {
        setState(() => _teams = [..._teams]..[i] = t);
        _snack('Could not save. Please try again.', warn: true);
      }
    }
    if (mounted) setState(() => _busyTeam = null);
  }

  // ---------------------------------------------------------------- build

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
            onPressed: () => Navigator.of(context).maybePop()),
        title: Text('Notification settings', style: V3.tight(20)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: V3.green))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              children: [
                _section('How we reach you'),
                if (_web)
                  _note('On the web app, notifications come by email.')
                else ...[
                  _card([
                    _choiceRow(
                        'Push', 'On this phone', _push, () => _setPush(true),
                        busy: _busyPush && _push),
                    _choiceRow('Email', 'To your login email', !_push,
                        () => _setPush(false),
                        busy: _busyPush && !_push, last: true),
                  ]),
                ],
                if (_teams.isNotEmpty) ...[
                  _section('Attendance alerts'),
                  _hint(
                      'Choose which attendance alerts you get for each team.'),
                  const SizedBox(height: 8),
                  _card([
                    for (final (i, t) in _teams.indexed)
                      _teamRow(t, last: i == _teams.length - 1),
                  ]),
                ],
              ],
            ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
        child: Text(t.toUpperCase(),
            style: V3.inter(13,
                weight: FontWeight.w700, color: V3.green, letterSpacing: .8)),
      );

  Widget _hint(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
        child: Text(t, style: V3.inter(13, color: V3.muted)),
      );

  Widget _note(String t) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: V3.card, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          const Icon(Icons.mail_outline, color: V3.green, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(t, style: V3.inter(14.5))),
        ]),
      );

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
            color: V3.card, borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: Column(children: children),
      );

  Widget _choiceRow(String title, String sub, bool on, VoidCallback onTap,
      {bool busy = false, bool last = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            border:
                last ? null : const Border(bottom: BorderSide(color: V3.line))),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title, style: V3.inter(16, weight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(sub, style: V3.inter(13, color: V3.muted)),
              ])),
          const SizedBox(width: 10),
          busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: V3.green))
              : Icon(on ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: on ? V3.green : V3.muted, size: 22),
        ]),
      ),
    );
  }

  Widget _teamRow(AdminAlertPref t, {bool last = false}) {
    final changed = t.choice != 'event';
    return InkWell(
      onTap: _busyTeam == null ? () => _pickAlert(t) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
            border:
                last ? null : const Border(bottom: BorderSide(color: V3.line))),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(t.teamName, style: V3.inter(16, weight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(alertChoiceLabel(t.choice),
                    style: V3.inter(13,
                        weight: changed ? FontWeight.w600 : FontWeight.w400,
                        color: changed ? V3.green : V3.muted)),
              ])),
          _busyTeam == t.teamId
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: V3.green))
              : const Icon(Icons.chevron_right, color: V3.muted),
        ]),
      ),
    );
  }
}
