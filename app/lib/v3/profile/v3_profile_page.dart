// v3 Profile and settings: one page from the menu (Ken said build it,
// 2026-11-10) replacing the FlutterFlow Update User Details page in v3.
// Your details (name, phone, default club) with Save, your members with a
// sheet (copy code, member page, leave team), account (change password,
// notification settings, sign out) and about (help, privacy, terms, delete).
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '/auth/supabase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '../auth/v3_auth_widgets.dart';
import '../teams/v3_team_models.dart' show V3Avatar;
import '../tracking/v3_track.dart';
import '../v3_theme.dart';
import 'v3_notification_settings_page.dart';
import 'v3_profile_models.dart';

class V3ProfilePage extends StatefulWidget {
  const V3ProfilePage({super.key, this.testData});

  /// Widget tests pass the RPC result here instead of calling Supabase.
  @visibleForTesting
  final Map<String, dynamic>? testData;

  @override
  State<V3ProfilePage> createState() => _V3ProfilePageState();
}

class _V3ProfilePageState extends State<V3ProfilePage> {
  ProfileData? _data;
  bool _loading = true;
  String? _error;
  bool _saving = false;
  bool _push = true;
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  int _club = 0;

  @override
  void initState() {
    super.initState();
    _load();
    PushPref.enabled().then((v) {
      if (mounted) setState(() => _push = v);
    });
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final Map<String, dynamic> body;
      if (widget.testData != null) {
        body = widget.testData!;
      } else {
        final r = await SupaFlow.client
            .rpc('get_edit_user_data', params: {'p_user_id': currentUserUid});
        body = r is Map ? Map<String, dynamic>.from(r) : {};
      }
      final d = ProfileData.fromJson(body);
      if (widget.testData == null && d.members.isNotEmpty) {
        try {
          final rows = await SupaFlow.client
              .from('member_team_role_link')
              .select('member_team_id, roles(role_name, role_level)')
              .inFilter('member_team_id',
                  [for (final m in d.members) m.memberTeamId]);
          d.applyRoles(rows);
        } catch (_) {}
      } else if (body['roles'] is List) {
        d.applyRoles(body['roles'] as List);
      }
      if (!mounted) return;
      _first.text = d.firstName;
      _last.text = d.lastName;
      _phone.text = d.phone;
      _club = d.defaultClub;
      setState(() {
        _data = d;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Your profile could not be loaded.';
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

  bool get _dirty {
    final d = _data;
    if (d == null) return false;
    return _first.text.trim() != d.firstName ||
        _last.text.trim() != d.lastName ||
        _phone.text.trim() != d.phone ||
        _club != d.defaultClub;
  }

  // ---------------------------------------------------------------- actions

  Future<void> _save() async {
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty) {
      _snack('Enter your first and last name.', warn: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await UsersTable().update(
        data: {
          'first_name': _first.text.trim(),
          'last_name': _last.text.trim(),
          'phone_number':
              _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          if (_club > 0) 'default_club': _club,
        },
        matchingRows: (rows) => rows.eq('user_id', currentUserUid),
      );
      await _load();
      _snack('Profile saved');
    } catch (_) {
      _snack('Could not save your details. Please try again.', warn: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _memberSheet(UserMember m) async {
    final pick = await _sheet<String>(m.fullName, m.subtitle, [
      _Item(Icons.copy, 'Copy member code', 'copy', trailing: m.memberCode),
      if (m.canOpenMemberPage)
        _Item(Icons.person_outline, 'Open member page', 'open'),
      _Item(Icons.logout, 'Leave this team', 'leave', red: true),
    ]);
    if (pick == null || !mounted) return;
    if (pick == 'copy') {
      await Clipboard.setData(ClipboardData(text: m.memberCode));
      _snack('Member code ${m.memberCode} copied');
    } else if (pick == 'open') {
      await context.pushNamed(V3MemberPage.routeName, queryParameters: {
        'memberID': serializeParam(m.memberId, ParamType.int)!,
        'teamID': serializeParam(m.teamId, ParamType.int)!,
      });
      if (mounted) _load();
    } else if (pick == 'leave') {
      _leaveTeam(m);
    }
  }

  /// Same steps as the v2 page: drop the member's roles and team link; if
  /// the member is in no other team, the user link, replies and member go too.
  Future<void> _leaveTeam(UserMember m) async {
    final ok = await _confirm(
        'Leave ${m.teamName}?',
        '${m.fullName} is removed from the team and its events. '
            'A team code is needed to join again.',
        'Leave team');
    if (!ok || !mounted) return;
    try {
      final links = await MemberTeamLinkTable().queryRows(
          queryFn: (q) =>
              q.eq('member_id', m.memberId).eq('team_id', m.teamId));
      for (final l in links) {
        await MemberTeamRoleLinkTable().delete(
            matchingRows: (q) => q.eq('member_team_id', l.memberTeamId));
      }
      await MemberTeamLinkTable().delete(
          matchingRows: (q) =>
              q.eq('member_id', m.memberId).eq('team_id', m.teamId));
      final others = await MemberTeamLinkTable().queryRows(
          queryFn: (q) =>
              q.eq('member_id', m.memberId).neq('team_id', m.teamId));
      if (others.isEmpty) {
        await UserMemberLinkTable()
            .delete(matchingRows: (q) => q.eq('member_id', m.memberId));
        await EventAttendanceTable()
            .delete(matchingRows: (q) => q.eq('member_id', m.memberId));
        await MembersTable()
            .delete(matchingRows: (q) => q.eq('member_id', m.memberId));
      }
      await _load();
      _snack('${m.firstName} has left ${m.teamName}');
    } catch (_) {
      _snack('Could not leave the team. Please try again.', warn: true);
    }
  }

  Future<void> _signOut() async {
    GoRouter.of(context).prepareAuthEvent();
    await authManager.signOut();
    GoRouter.of(context).clearRedirectLocation();
    if (mounted) context.goNamedAuth(V3SignInPage.routeName, context.mounted);
  }

  Future<void> _deleteAccount() async {
    final d = _data!;
    final names = {for (final m in d.members) m.fullName}.join(', ');
    final typed = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: V3.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: StatefulBuilder(
              builder: (ctx, setSheet) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _grab(),
                    Text('Delete your account?', style: V3.tight(20)),
                    const SizedBox(height: 4),
                    Text(
                        'Your login is closed and you are signed out on every device. '
                        '${names.isEmpty ? '' : 'Your members ($names) stay with their teams until a team admin removes them. '}'
                        'This cannot be undone.',
                        style: V3.inter(14, color: V3.muted, height: 1.45)),
                    const SizedBox(height: 14),
                    V3Field(
                      label: 'Type DELETE to confirm',
                      controller: typed,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) => setSheet(() {}),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                          onPressed: typed.text.trim().toUpperCase() == 'DELETE'
                              ? () => Navigator.pop(ctx, true)
                              : null,
                          style: FilledButton.styleFrom(
                              backgroundColor: V3.red,
                              disabledBackgroundColor: V3.card2,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14))),
                          child: Text('Delete my account',
                              style: V3.inter(16,
                                  weight: FontWeight.w700,
                                  color: typed.text.trim().toUpperCase() ==
                                          'DELETE'
                                      ? Colors.white
                                      : V3.muted))),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: V3.green,
                              side:
                                  const BorderSide(color: V3.green, width: 1.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14))),
                          child: Text('Keep my account',
                              style: V3.inter(16, weight: FontWeight.w700))),
                    ),
                  ]),
            ),
          ),
        ),
      ),
    );
    typed.dispose();
    if (ok != true || !mounted) return;
    try {
      final r = await DeleteUserCall.call(supabaseJWTtoken: currentJwtToken);
      if (!r.succeeded) throw Exception(r.bodyText);
      await _signOut();
    } catch (_) {
      _snack('The account could not be deleted. Please try again.', warn: true);
    }
  }

  // ------------------------------------------------------- calendar feed

  /// The private calendar link (calendar-feed edge function). Phones
  /// subscribe once and refresh it themselves (Ken, 2026-11-11).
  static const _feedBase =
      'gyfporsbdftvtakdvukt.supabase.co/functions/v1/calendar-feed?t=';

  Future<String?> _calendarToken({bool reset = false}) async {
    try {
      final t = await SupaFlow.client
          .rpc('get_my_calendar_token', params: {'p_reset': reset});
      return t is String && t.isNotEmpty ? t : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _calendar() async {
    final android = defaultTargetPlatform == TargetPlatform.android;
    final pick = await _sheet<String>(
        'Add events to my calendar',
        'Your CoachSmart events appear in your calendar and stay up to date '
            'as they change. Calendars check for changes every hour or so, '
            'so the app is still the quickest place to see a change.',
        [
          _Item(Icons.event_available_outlined,
              android ? 'Add to Google Calendar' : 'Add to this phone', 'add'),
          _Item(Icons.copy, 'Copy the calendar link', 'copy'),
          _Item(Icons.refresh, 'Get a new link', 'reset'),
          _Item(Icons.close, 'Cancel', ''),
        ]);
    if (pick == null || pick.isEmpty || !mounted) return;
    if (pick == 'reset') {
      final r = await _sheet<bool>(
          'Get a new calendar link?',
          'Calendars using the old link stop getting your events. '
              'Add your calendar again with the new link.',
          [
            _Item(Icons.refresh, 'Get a new link', true, red: true),
            _Item(Icons.close, 'Cancel', false),
          ]);
      if (r != true || !mounted) return;
    }
    final token = await _calendarToken(reset: pick == 'reset');
    if (!mounted) return;
    if (token == null) {
      _snack('Could not get your calendar link. Please try again.', warn: true);
      return;
    }
    final https = 'https://$_feedBase$token';
    final webcal = 'webcal://$_feedBase$token';
    V3Track.event('calendar_feed', {'action': pick});
    switch (pick) {
      case 'add':
        // iPhone and Mac open the subscribe prompt for webcal links; Google
        // Calendar adds a feed through its own link.
        await launchURL(android
            ? 'https://calendar.google.com/calendar/r?cid=${Uri.encodeComponent(webcal)}'
            : webcal);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: https));
        _snack('Calendar link copied');
      case 'reset':
        await Clipboard.setData(ClipboardData(text: https));
        _snack('New calendar link copied. Add it to your calendar again.');
    }
  }

  Future<bool> _confirm(String title, String body, String yes) async {
    final r = await _sheet<bool>(title, body, [
      _Item(Icons.logout, yes, true, red: true),
      _Item(Icons.close, 'Cancel', false),
    ]);
    return r == true;
  }

  Future<T?> _sheet<T>(String title, String? sub, List<_Item<T>> items) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: V3.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _grab(),
                Text(title, style: V3.tight(20)),
                if (sub != null && sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(sub, style: V3.inter(14, color: V3.muted, height: 1.4)),
                ],
                const SizedBox(height: 6),
                for (final it in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(it.icon,
                        color: it.red ? V3.redText : V3.green, size: 26),
                    title: Text(it.title,
                        style: V3.inter(17,
                            weight: FontWeight.w500,
                            color: it.red ? V3.redText : V3.text)),
                    trailing: it.trailing == null
                        ? null
                        : Text(it.trailing!,
                            style: V3.inter(15, color: V3.muted)),
                    onTap: () => Navigator.pop(ctx, it.value),
                  ),
              ]),
        ),
      ),
    );
  }

  Widget _grab() => Center(
      child: Container(
          width: 40,
          height: 5,
          margin: const EdgeInsets.only(top: 14, bottom: 14),
          decoration: BoxDecoration(
              color: V3.barGrey, borderRadius: BorderRadius.circular(3))));

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
        title: Text('Profile', style: V3.tight(20)),
        actions: [
          if (d != null)
            TextButton(
                onPressed: _dirty && !_saving ? _save : null,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: V3.green))
                    : Text('Save',
                        style: V3.inter(15,
                            weight: FontWeight.w600,
                            color: _dirty ? V3.green : V3.muted))),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: V3.green))
          : _error != null
              ? Center(
                  child: Text(_error!, style: V3.inter(15, color: V3.muted)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                  children: _body(d!),
                ),
    );
  }

  List<Widget> _body(ProfileData d) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 18),
        child: Row(children: [
          V3Avatar(initialsFor(_first.text, _last.text),
              size: 64, highlight: true),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('${_first.text} ${_last.text}'.trim(),
                    style: V3.tight(22)),
                const SizedBox(height: 2),
                Text(d.email, style: V3.inter(14, color: V3.muted)),
              ])),
        ]),
      ),
      _section('Your details'),
      _card([
        _field(
            'First name', _first, TextCapitalization.words, TextInputType.name),
        _field(
            'Last name', _last, TextCapitalization.words, TextInputType.name),
        _field('Phone (optional)', _phone, TextCapitalization.none,
            TextInputType.phone,
            hint: 'Add a number', last: d.clubs.length <= 1),
        if (d.clubs.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Default club', style: V3.inter(12.5, color: V3.muted)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in d.clubs)
                  GestureDetector(
                    onTap: () => setState(() => _club = c.clubId),
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: _club == c.clubId ? V3.green : V3.card2,
                          borderRadius: BorderRadius.circular(12)),
                      child: Text(c.clubName,
                          style: V3.inter(13.5,
                              weight: FontWeight.w600,
                              color: _club == c.clubId ? V3.bg : V3.text)),
                    ),
                  ),
              ]),
            ]),
          ),
      ]),
      _section('Your members'),
      _card([
        for (final m in d.members)
          _row(Icons.person, m.fullName, m.subtitle, () => _memberSheet(m)),
        _row(Icons.group_add_outlined, 'Join another team', 'Enter a team code',
            () async {
          await context.pushNamed(JoinTeamNewWidget.routeName);
          if (mounted) _load();
        }, last: true),
      ]),
      _section('Account'),
      _card([
        _row(Icons.lock_outline, 'Change password', null, () {
          Navigator.of(context).push(MaterialPageRoute(
              settings: const RouteSettings(name: 'V3ChangePasswordPage'),
              builder: (_) => V3ChangePasswordPage(email: d.email)));
        }),
        _row(Icons.notifications_none, 'Notification settings',
            kIsWeb ? 'By email on the web app' : (_push ? 'Push' : 'Email'),
            () async {
          await Navigator.of(context).push(MaterialPageRoute(
              settings: const RouteSettings(name: 'V3NotificationSettingsPage'),
              builder: (_) => const V3NotificationSettingsPage()));
          final v = await PushPref.enabled();
          if (mounted) setState(() => _push = v);
        }),
        _row(Icons.event_available_outlined, 'Add events to my calendar',
            'Your events show in your phone calendar', _calendar),
        _row(Icons.logout, 'Sign out', null, _signOut, last: true),
      ]),
      _section('About'),
      _card([
        _row(Icons.help_outline, 'Help and FAQ', null,
            () => launchURL('https://coachsmart.app/help')),
        _row(Icons.description_outlined, 'Privacy policy', null,
            () => launchURL('https://coachsmart.app/privacy.html')),
        _row(Icons.description_outlined, 'Terms of use', null,
            () => launchURL('https://coachsmart.app/terms.html')),
        _row(Icons.delete_outline, 'Delete account',
            'Closes your login for good', _deleteAccount,
            red: true, last: true),
      ]),
      Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Text(kV3VersionLabel,
            textAlign: TextAlign.center,
            style: V3.inter(12.5, color: V3.muted)),
      ),
    ];
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
        child: Text(t.toUpperCase(),
            style: V3.inter(13,
                weight: FontWeight.w700, color: V3.green, letterSpacing: .8)),
      );

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
            color: V3.card, borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: Column(children: children),
      );

  Widget _field(String label, TextEditingController c, TextCapitalization cap,
      TextInputType type,
      {String? hint, bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          border:
              last ? null : const Border(bottom: BorderSide(color: V3.line))),
      child: TextField(
        controller: c,
        textCapitalization: cap,
        keyboardType: type,
        style: V3.inter(16, weight: FontWeight.w500),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          isDense: true,
          labelText: label,
          labelStyle: V3.inter(14, color: V3.muted),
          floatingLabelStyle: V3.inter(12.5, color: V3.muted),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          hintText: hint,
          hintStyle: V3.inter(16, color: V3.muted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(top: 4, bottom: 2),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String title, String? sub, VoidCallback? onTap,
      {Widget? trailing, bool red = false, bool last = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
            border:
                last ? null : const Border(bottom: BorderSide(color: V3.line))),
        child: Row(children: [
          Icon(icon, color: red ? V3.redText : V3.green, size: 22),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: V3.inter(16,
                        weight: FontWeight.w500,
                        color: red ? V3.redText : V3.text)),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(sub, style: V3.inter(13, color: V3.muted)),
                ],
              ])),
          trailing ?? const Icon(Icons.chevron_right, color: V3.muted),
        ]),
      ),
    );
  }
}

class _Item<T> {
  const _Item(this.icon, this.title, this.value,
      {this.red = false, this.trailing});
  final IconData icon;
  final String title;
  final T value;
  final bool red;
  final String? trailing;
}
