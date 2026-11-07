// v3 Event details. Same data as the FlutterFlow page (get_user_event_details)
// laid out as in /mnt/project-files/coachsmart/app-v3/event-details/
// CHOSEN-event-*.png: hero, Meet / Venue / Directions tiles, match tools,
// your reply, pay, attendance tiles, payments (admins) and a details card.
// Admin actions sit behind the three-dot Manage sheet.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '/auth/supabase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '../home/v3_home_data.dart';
import '../v3_theme.dart';

class V3EventPage extends StatefulWidget {
  const V3EventPage(
      {super.key, required this.eventID, this.fromSearch, this.testData});

  final int? eventID;
  final bool? fromSearch;

  /// Widget tests pass the RPC result here instead of calling Supabase.
  @visibleForTesting
  final Map<String, dynamic>? testData;

  // Same route as the FlutterFlow page so every existing pushNamed lands here.
  static String routeName = 'EventDetails';
  static String routePath = 'eventDetails';

  @override
  State<V3EventPage> createState() => _V3EventPageState();
}

class _V3EventPageState extends State<V3EventPage> {
  UserEventDetailsStruct? _ev;
  // Fields the RPC returns that the exported struct doesn't carry yet.
  Map<String, dynamic> _raw = {};
  bool _loading = true;
  String? _error;
  final Set<int> _busy = {}; // member ids with a reply being saved
  bool _paying = false;
  bool _teamAllowsLineup = false;
  bool _teamSessionPlan = false;

  int get _eventId => widget.eventID ?? 0;
  bool get _fromSearch => widget.fromSearch ?? false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.testData != null) {
      setState(() {
        _ev = UserEventDetailsStruct.maybeFromMap(widget.testData);
        _raw = widget.testData!;
        _loading = false;
      });
      return;
    }
    try {
      final r = await GetUserEventDetailsCall.call(
        pEventId: _eventId,
        pUserId: currentUserUid,
        supabaseJWTtoken: currentJwtToken,
      );
      final ev = UserEventDetailsStruct.maybeFromMap(r.jsonBody);
      if (ev == null || ev.eventId == 0) {
        setState(() {
          _loading = false;
          _error = 'This event could not be loaded.';
        });
        return;
      }
      FFAppState().userEventDetails = ev;
      setState(() {
        _ev = ev;
        _raw = r.jsonBody is Map ? Map<String, dynamic>.from(r.jsonBody) : {};
        _loading = false;
        _error = null;
      });
      _loadTeamFlags(ev.teamId);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'This event could not be loaded.';
      });
    }
  }

  // Team feature switches that gate the Lineup and Session plan tools.
  Future<void> _loadTeamFlags(int teamId) async {
    try {
      final row = await SupaFlow.client
          .from('teams')
          .select('allow_lineup, session_plan')
          .eq('team_id', teamId)
          .maybeSingle();
      if (!mounted || row == null) return;
      setState(() {
        _teamAllowsLineup = row['allow_lineup'] == true;
        _teamSessionPlan = row['session_plan'] == true;
      });
    } catch (_) {}
  }

  // ---------------------------------------------------------------- derived

  DateTime? get _when {
    final e = _ev;
    if (e == null) return null;
    try {
      return DateFormat("EEEE, dd MMMM, yyyy 'at' HH:mm", 'en_US')
          .parseUtc(e.eventDateTimeFormatted)
          .toLocal();
    } catch (_) {
      return null;
    }
  }

  String get _status => (_raw['event_status'] ?? '').toString();
  String get _squadName => (_raw['squad_name'] ?? '').toString();
  bool get _cancelled => _status == 'cancelled';
  bool get _isMatch => (_ev?.eventType ?? '').toLowerCase() == 'match';
  int get _role => _ev?.userHighestRoleLevel ?? 0;
  bool get _admin => _role >= 100;
  List<TeamMembersStruct> get _members => _ev?.teamMembers ?? const [];
  List<TeamMembersStruct> get _unanswered =>
      _members.where((m) => m.responseId == 0).toList();
  List<TeamMembersStruct> get _owing => _members
      .where((m) =>
          m.roleLevel == 10 &&
          m.responseId == 3 &&
          m.memberPaymentStatus != 'confirmed')
      .toList();
  bool get _showReplyBlock =>
      (_ev?.requestAttendance ?? false) &&
      !_fromSearch &&
      !_cancelled &&
      _members.isNotEmpty &&
      (_members.length >= 2 || _unanswered.isNotEmpty);

  String _crestUrl() {
    final home = FFAppState().homePageEvents;
    for (final e in home.events) {
      if (e.eventId == _eventId) {
        for (final c in home.clubs) {
          if (c.clubId == e.clubId && c.clubId != 0) return c.crest;
        }
      }
    }
    return '';
  }

  String _euro(int cents) => '€${(cents / 100).toStringAsFixed(2)}';

  String _dayLabel(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return t.hour >= 17 ? 'Tonight' : 'Today';
    if (diff == 1) return 'Tomorrow';
    return DateFormat('EEE d MMM').format(t);
  }

  // ---------------------------------------------------------------- actions

  Future<void> _reply(TeamMembersStruct m, int responseId) async {
    if (m.responseId == responseId) return;
    setState(() => _busy.add(m.memberId));
    try {
      final row = await EventAttendanceTable().insert({
        'event_id': _eventId,
        'member_id': m.memberId,
        'response_id': responseId,
      });
      await NotifyAdminsAttendanceChangeCall.call(
        supabaseJWTtoken: currentJwtToken,
        pMemberIdParam: m.memberId,
        pEventIdParam: _eventId,
        pResponseId: responseId,
        pAttendanceId: row.attendanceId,
      );
      await _load();
    } catch (_) {
      _snack('Could not save the reply. Please try again.', warn: true);
    } finally {
      if (mounted) setState(() => _busy.remove(m.memberId));
    }
  }

  Future<void> _replyAll(int responseId) async {
    for (final m in _unanswered) {
      await _reply(m, responseId);
    }
  }

  // Same flow as the FlutterFlow page: create the Stripe checkout session for
  // every attending player who hasn't paid, then open the checkout page.
  Future<void> _pay() async {
    final e = _ev!;
    final owing = _owing;
    if (owing.isEmpty) {
      _snack('All payments for this event are already made.');
      return;
    }
    setState(() => _paying = true);
    try {
      final token = await actions.fetchSupabaseAccessToken();
      final r = await CreateCheckoutSessionVersionTwoCall.call(
        supabaseAccessToken: token,
        appEventID: _eventId,
        appUserID: currentUserUid,
        productName: e.eventTitle,
        amount: e.paymentAmount * owing.length,
        appSuccessUrl: 'https://my.coachsmart.app/checkoutSuccess',
        appCancelUrl: 'https://my.coachsmart.app/cehckoutFailed',
        memberIdsList: owing.map((m) => m.memberId).toList(),
        unitPrice: e.paymentAmount,
      );
      final url = StripeCheckoutStruct.maybeFromMap(r.jsonBody)?.checkoutUrl;
      if (url == null || url.isEmpty) {
        _snack('Could not start the payment. Please try again.', warn: true);
        return;
      }
      if (!mounted) return;
      await context.pushNamed(
        CheckoutWidget.routeName,
        queryParameters: {
          'paramEventId': serializeParam(_eventId, ParamType.int),
          'paramNumPayments': serializeParam(owing.length, ParamType.int),
          'paramPaymentAmount': serializeParam(e.paymentAmount, ParamType.int),
          'paramCheckoutUrl': serializeParam(url, ParamType.String),
          'paramPayingMembers': serializeParam(
              owing.map((m) => m.toMap()).toList(), ParamType.JSON,
              isList: true),
        }.withoutNulls,
      );
      await _load();
    } catch (_) {
      _snack('Could not start the payment. Please try again.', warn: true);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _open(String route, Map<String, String?> params) async {
    await context.pushNamed(route, queryParameters: params.withoutNulls);
    _load();
  }

  Map<String, String?> _matchParams() => {
        'eventId': serializeParam(_eventId, ParamType.int),
        'teamId': serializeParam(_ev?.teamId, ParamType.int),
        'currentAuthToken': serializeParam(currentJwtToken, ParamType.String),
      };

  void _openWeb(String title, String url) {
    if (kIsWeb) {
      launchURL(url);
    } else {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _V3WebPage(title: title, url: url)));
    }
  }

  void _openAttendees(int responseId) {
    final e = _ev!;
    final common = {
      'eventID': serializeParam(_eventId, ParamType.int),
      'responseID': serializeParam(responseId, ParamType.int),
      'teamID': serializeParam(e.teamId, ParamType.int),
      'eventRoleLevel': serializeParam(e.eventRoleLevel, ParamType.int),
    };
    if (_admin && e.teamHasSquads) {
      _open(AttendeeListAdminsWidget.routeName, {
        ...common,
        'userRoleLevel': serializeParam(_role, ParamType.int),
        'eventCodeId': serializeParam(e.codeId, ParamType.int),
      });
    } else {
      _open(AttendeeListWidget.routeName, common);
    }
  }

  Future<void> _setFlag(String column, bool value) async {
    try {
      await EventsTable().update(
        data: {column: value},
        matchingRows: (rows) => rows.eq('event_id', _eventId),
      );
      await _load();
    } catch (_) {
      _snack('Could not save that setting.', warn: true);
    }
  }

  Future<void> _sendReminder() async {
    try {
      final r = await PopulateEventNotificationsCall.call(
        supabaseJWTtoken: currentJwtToken,
        pEventIdParam: _eventId,
        pRoleLevel: 10,
        pRoleGrade: 10,
      );
      _snack(r.succeeded ? 'Reminder sent' : 'Could not send the reminder.',
          warn: !r.succeeded);
    } catch (_) {
      _snack('Could not send the reminder.', warn: true);
    }
  }

  // Cancel, reinstate or delete: the same status writes as the FlutterFlow
  // edit page (events.status plus event_attendance.status).
  Future<void> _setStatus(String status) async {
    try {
      await EventsTable().update(
        data: {'status': status},
        matchingRows: (rows) => rows.eq('event_id', _eventId),
      );
      await EventAttendanceTable().update(
        data: {'status': status},
        matchingRows: (rows) => rows.eq('event_id', _eventId),
      );
      if (status == 'deleted') {
        if (mounted) _back();
        return;
      }
      await _load();
    } catch (_) {
      _snack('Could not update the event.', warn: true);
    }
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: V3.card,
        title: Text(title, style: V3.tight(20)),
        content: Text(body, style: V3.inter(15, color: V3.muted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Keep', style: V3.inter(15, color: V3.muted))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(action,
                  style: V3.inter(15,
                      weight: FontWeight.w600, color: V3.redText))),
        ],
      ),
    );
    return ok ?? false;
  }

  void _snack(String text, {bool warn = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(text, style: V3.inter(14, color: V3.bg)),
        backgroundColor: warn ? V3.amber : V3.green));
  }

  void _back() {
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.goNamed(V3HomePage.routeName);
    }
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: AppBar(
        backgroundColor: V3.bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: V3.green, size: 34),
          onPressed: _back,
        ),
        centerTitle: true,
        title: Text(_ev?.eventTitle ?? '',
            maxLines: 1, overflow: TextOverflow.ellipsis, style: V3.tight(17)),
        actions: [
          if (_admin && _ev != null)
            IconButton(
              icon: const Icon(Icons.more_vert, color: V3.green, size: 26),
              onPressed: _showManage,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: V3.green))
          : _error != null
              ? Center(
                  child: Text(_error!, style: V3.inter(15, color: V3.muted)))
              : RefreshIndicator(
                  color: V3.green,
                  backgroundColor: V3.card,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    children: [
                      _hero(),
                      // Replying is why most people open an event, so the
                      // reply rows come first (Ken, 2026-11-07).
                      if (_showReplyBlock) ...[
                        _section('Your reply'),
                        _replyCard(),
                      ],
                      if (_owing.isNotEmpty && (_ev!.paymentRequired))
                        _payButton(),
                      if (_showReplyBlock ||
                          (_owing.isNotEmpty && _ev!.paymentRequired))
                        const SizedBox(height: 14),
                      _tiles(),
                      if (_tools().isNotEmpty) _toolsRow(),
                      // Then the event detail, and attendance last
                      // (Ken, 2026-11-07).
                      _section('Details'),
                      _details(),
                      if (_role >= 20 && _ev!.requestAttendance) ...[
                        _section('Attendance'),
                        _attendance(),
                      ],
                      if (_admin && _ev!.paymentRequired) ...[
                        _section('Payments'),
                        _payments(),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(text.toUpperCase(),
            style: V3.inter(13,
                weight: FontWeight.w700, color: V3.green, letterSpacing: .8)),
      );

  // Hero: crest, team + squad, title, date · time · countdown, pills.
  Widget _hero() {
    final e = _ev!;
    final t = _when;
    final crest = _crestUrl();
    final team = [
      e.teamName,
      if (_squadName.isNotEmpty) _squadName,
    ].join(' · ');
    final strike = _cancelled ? TextDecoration.lineThrough : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (crest.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 14, top: 2),
              child: SizedBox(
                width: 56,
                height: 56,
                child: Image.network(crest,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(team.toUpperCase(),
                    style: V3.inter(13,
                        weight: FontWeight.w700,
                        color: V3.green,
                        letterSpacing: .6)),
                const SizedBox(height: 2),
                Text(e.eventTitle,
                    style: V3
                        .tight(24, weight: FontWeight.w700, height: 1.15)
                        .copyWith(decoration: strike)),
                const SizedBox(height: 6),
                if (t != null)
                  RichText(
                    text: TextSpan(
                      style: V3.inter(16, weight: FontWeight.w500),
                      children: [
                        TextSpan(text: '${_dayLabel(t)} · '),
                        TextSpan(
                            text: hhmm(t),
                            style: V3.inter(16,
                                weight: FontWeight.w600, color: V3.green)),
                        if (!_cancelled && t.isAfter(DateTime.now()))
                          TextSpan(text: ' · ${countdown(t, DateTime.now())}'),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: _heroPills()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _heroPills() {
    final e = _ev!;
    final out = <Widget>[];
    if (_cancelled) out.add(_pill('Cancelled', V3.redTint, V3.redText));
    if (e.homeAway.isNotEmpty) out.add(_pill(e.homeAway, V3.card2, V3.text));
    if (e.paymentRequired && e.eventPaid > 0 && _owing.isEmpty) {
      out.add(_pill('Paid', V3.greenTint, V3.green));
    }
    if (e.requestAttendance && !_fromSearch && !_cancelled) {
      if (_members.length == 1 && _unanswered.isEmpty) {
        final m = _members.first;
        final going = m.responseId == 3;
        out.add(GestureDetector(
          onTap: () => _showChangeReply(m),
          child: going
              ? _pill('✓ Attending', V3.greenTint, V3.green)
              : _pill('✗ Declined', V3.redTint, V3.redText),
        ));
      } else if (_unanswered.isNotEmpty) {
        final n = _unanswered.length;
        out.add(_pill('$n ${n == 1 ? 'reply' : 'replies'} needed', V3.redTint,
            V3.redText));
      }
    }
    return out;
  }

  Widget _pill(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child:
            Text(text, style: V3.inter(13, weight: FontWeight.w600, color: fg)),
      );

  // Meet / Venue / Directions.
  Widget _tiles() {
    final e = _ev!;
    Widget tile(String label, String value, String sub) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: V3.card, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                    style: V3.inter(12,
                        weight: FontWeight.w500,
                        color: V3.muted,
                        letterSpacing: .5)),
                const SizedBox(height: 4),
                Text(value.isEmpty ? '—' : value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: V3.inter(17, weight: FontWeight.w600)),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: V3.inter(13, color: V3.muted)),
                ],
              ],
            ),
          ),
        );
    final t = _when;
    // IntrinsicHeight gives the stretched row a bounded height inside the
    // list; without it the tiles get infinite height and nothing below renders.
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            tile('Meet', e.meetTime.isEmpty && t != null ? hhmm(t) : e.meetTime,
                e.meetTime.isEmpty ? 'at the start' : ''),
            const SizedBox(width: 8),
            tile(
                e.homeAway.toLowerCase() == 'away' ? 'Away venue' : 'Venue',
                e.locationName,
                e.opposition.isNotEmpty && _isMatch ? 'v ${e.opposition}' : ''),
            if (e.locationPin.isNotEmpty) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () =>
                    launchMap(address: e.locationPin, title: e.locationName),
                child: Container(
                  width: 52,
                  decoration: BoxDecoration(
                      color: V3.card, borderRadius: BorderRadius.circular(14)),
                  child:
                      const Icon(Icons.navigation, color: V3.green, size: 24),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Match tools by role; Session plan on other event types.
  List<_Tool> _tools() {
    final e = _ev!;
    final out = <_Tool>[];
    if (_isMatch) {
      if (_role >= 20) {
        out.add(_Tool('Score', Icons.timer_outlined,
            () => _open(MatchScoreWidget.routeName, _matchParams())));
      }
      out.add(_Tool(
          'Live',
          Icons.visibility_outlined,
          () => _openWeb('Live',
              'https://coachsmart.app/webviews/match-live.html?token=$currentJwtToken&eventId=$_eventId')));
      if (_role >= 20) {
        out.add(_Tool('Stats', Icons.bar_chart,
            () => _open(MatchStatsWidget.routeName, _matchParams())));
      }
      if (_role >= 30) {
        out.add(_Tool(
            'Report',
            Icons.description_outlined,
            () => _open(MatchReportWidget.routeName, {
                  'paramEventID': serializeParam(_eventId, ParamType.int),
                  'paramRoleLevel': serializeParam(_role, ParamType.int),
                })));
      }
      if (_role >= 30 && _teamAllowsLineup) {
        out.add(_Tool(
            'Lineup',
            Icons.grid_view_outlined,
            () => _openWeb('Lineup',
                'https://coachsmart.app/webviews/team_selector.html?token=$currentJwtToken&eventId=$_eventId&teamId=${e.teamId}&squadId=${e.squadId}')));
      }
    } else if (_role >= 30 && _teamSessionPlan) {
      out.add(_Tool(
          'Session plan',
          Icons.assignment_outlined,
          () => _open(SessionPlannerWidget.routeName, {
                'pEventId': serializeParam(_eventId, ParamType.int),
              })));
    }
    return out;
  }

  Widget _toolsRow() {
    final tools = _tools();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          for (var i = 0; i < tools.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: tools[i].onTap,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
                  decoration: BoxDecoration(
                      color: V3.card, borderRadius: BorderRadius.circular(14)),
                  child: Column(children: [
                    Icon(tools[i].icon, color: V3.muted, size: 24),
                    const SizedBox(height: 6),
                    Text(tools[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: V3.inter(12, weight: FontWeight.w500)),
                  ]),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // One row per linked member: avatar, name, Paid tag, Attending / Decline.
  Widget _replyCard() {
    final e = _ev!;
    final rows = <Widget>[];
    for (var i = 0; i < _members.length; i++) {
      final m = _members[i];
      rows.add(
          _memberRow(m, e.paymentRequired, last: i == _members.length - 1));
    }
    return Column(children: [
      _card(rows),
      if (_unanswered.length >= 2)
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 4),
          child: Row(children: [
            Expanded(
                child: TextButton(
                    onPressed: () => _replyAll(3),
                    child: Text('All attending',
                        style: V3.inter(14,
                            weight: FontWeight.w600, color: V3.green)))),
            Expanded(
                child: TextButton(
                    onPressed: () => _replyAll(4),
                    child: Text('None attending',
                        style: V3.inter(14,
                            weight: FontWeight.w600, color: V3.redText)))),
          ]),
        ),
    ]);
  }

  Widget _memberRow(TeamMembersStruct m, bool paidEvent, {required bool last}) {
    final busy = _busy.contains(m.memberId);
    final going = m.responseId == 3;
    final declined = m.responseId == 4;
    final name = m.firstName.isNotEmpty ? m.firstName : m.lastName;
    // Unanswered: solid green Attending and solid red Decline. Answered: the
    // chosen one stays solid, the other goes grey so the choice is obvious.
    final answered = going || declined;
    Widget seg(String label, bool on, bool isGo, IconData icon) {
      final solid = isGo ? V3.green : V3.red;
      final bg = answered && !on ? V3.card2 : solid;
      final fg = answered && !on ? V3.muted : (isGo ? V3.bg : Colors.white);
      return GestureDetector(
        onTap: busy ? null : () => _reply(m, isGo ? 3 : 4),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: fg),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 5),
              Text(label,
                  style: V3.inter(15, weight: FontWeight.w700, color: fg)),
            ],
          ]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          border:
              last ? null : const Border(bottom: BorderSide(color: V3.line))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration:
                  const BoxDecoration(color: V3.card2, shape: BoxShape.circle),
              child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                  style:
                      V3.tight(14, weight: FontWeight.w700, color: V3.green)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(children: [
                Flexible(
                    child: Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: V3.inter(16, weight: FontWeight.w500))),
                const SizedBox(width: 6),
                Text(m.roleName, style: V3.inter(13, color: V3.muted)),
                if (paidEvent && m.memberPaid == 1) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: V3.greenTint,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('Paid',
                        style: V3.inter(11,
                            weight: FontWeight.w600, color: V3.green)),
                  ),
                ],
              ]),
            ),
            if (busy)
              const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: V3.green)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: seg(going ? 'Attending ✓' : 'Attending', going, true,
                    Icons.check)),
            const SizedBox(width: 8),
            Expanded(
                child: seg(declined ? 'Declined' : 'Decline', declined, false,
                    Icons.close)),
          ]),
        ],
      ),
    );
  }

  Widget _payButton() {
    final e = _ev!;
    final owing = _owing;
    final names = owing.map((m) => m.firstName).where((n) => n.isNotEmpty);
    final who = owing.length == 1
        ? ' for ${names.isEmpty ? 'this event' : names.first}'
        : ' for ${owing.length} players';
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 2),
      child: SizedBox(
        height: 48,
        child: FilledButton.icon(
          onPressed: _paying ? null : _pay,
          style: FilledButton.styleFrom(
              backgroundColor: V3.amber,
              foregroundColor: V3.bg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          icon: const Icon(Icons.shopping_cart_outlined, size: 20),
          label: Text(
              _paying
                  ? 'Opening checkout…'
                  : 'Pay ${_euro(e.paymentAmount * owing.length)}$who',
              style: V3.inter(16, weight: FontWeight.w700, color: V3.bg)),
        ),
      ),
    );
  }

  // Attending · No reply · Declined tiles with per-role lines, then a bar.
  Widget _attendance() {
    final e = _ev!;
    final a = e.acceptedPlayerCount;
    final n = e.noResponsePlayerCount;
    final d = e.declinedPlayerCount;
    final total = a + n + d;
    String lines(Iterable<MapEntry<String, int>> roles) => roles
        .where((r) => r.value > 0)
        .map((r) => '${r.key}: ${r.value}')
        .join(' · ');
    final aLines = lines(e.acceptedAttendanceSummary
        .where((r) => r.roleLevel > 10)
        .map((r) => MapEntry(r.roleNamePlural, r.memberCount)));
    final nLines = lines(e.noResponseAttendanceSummary
        .where((r) => r.roleLevel > 10)
        .map((r) => MapEntry(r.roleNamePlural, r.memberCount)));
    final dLines = lines(e.declinedAttendanceSummary
        .where((r) => r.roleLevel > 10)
        .map((r) => MapEntry(r.roleNamePlural, r.memberCount)));

    Widget tile(String label, int count, Color dot, Color bg, String sub,
            int responseId) =>
        Expanded(
          child: GestureDetector(
            onTap: () => _openAttendees(responseId),
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
              decoration: BoxDecoration(
                  color: bg, borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Text(label, style: V3.inter(14)),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                      width: 18,
                      height: 18,
                      margin: const EdgeInsets.only(right: 8),
                      decoration:
                          BoxDecoration(color: dot, shape: BoxShape.circle)),
                  Text('$count',
                      style: V3.tight(28, weight: FontWeight.w700, height: 1)),
                ]),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(sub,
                      textAlign: TextAlign.center,
                      style: V3.inter(12, color: V3.muted, height: 1.35)),
                ],
              ]),
            ),
          ),
        );

    return Column(children: [
      // Each tile is as tall as its own content (Ken, 2026-11-07).
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        tile('Attending', a, V3.green, const Color(0xFF1F2A19), aLines, 3),
        const SizedBox(width: 8),
        tile('No reply', n, const Color(0xFF9A9A9A), V3.card2, nLines, 0),
        const SizedBox(width: 8),
        tile('Declined', d, const Color(0xFFC3202A), const Color(0xFF3A1D1D),
            dLines, 4),
      ]),
      const SizedBox(height: 12),
      _bar([
        (a, V3.green),
        (n, V3.barGrey),
        (d, V3.red),
      ], total),
    ]);
  }

  Widget _bar(List<(int, Color)> parts, int total) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 8,
          child: total == 0
              ? Container(color: V3.line)
              : Row(children: [
                  for (final p in parts)
                    if (p.$1 > 0)
                      Expanded(flex: p.$1, child: Container(color: p.$2)),
                ]),
        ),
      );

  // Admin payments block: gross, net, paid v attending, link to details.
  Widget _payments() {
    final e = _ev!;
    final paid = e.newNumPayments;
    final attending = e.acceptedPlayerCount;
    final projected = e.paymentAmount * attending;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: V3.card, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_euro(e.newGrossAmount),
                        style: V3.tight(26, weight: FontWeight.w700)),
                    Text('Net ${_euro(e.newNetAmount)} after fees',
                        style: V3.inter(14, color: V3.muted)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _open(PaymentTransactionsWidget.routeName, {
                  'paramEventID': serializeParam(_eventId, ParamType.int),
                }),
                child: Text('Details ›',
                    style:
                        V3.inter(14, weight: FontWeight.w600, color: V3.green)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _bar([
            (paid, V3.green),
            (attending - paid > 0 ? attending - paid : 0, V3.barGrey),
          ], attending > paid ? attending : paid),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: V3.inter(14, color: V3.muted),
              children: [
                TextSpan(
                    text: '$paid of $attending',
                    style: V3.inter(14, weight: FontWeight.w600)),
                TextSpan(
                    text:
                        ' attending have paid · projected ${_euro(projected)}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Details card: Type, Opposition, Car pooling, Link, Notes, Created by.
  Widget _details() {
    final e = _ev!;
    final rows = <Widget>[];
    final type = [
      if (e.eventType.isNotEmpty) e.eventType,
      if (e.eventCode.isNotEmpty) e.eventCode,
    ].join(' · ');
    if (type.isNotEmpty) rows.add(_row('Type', type));
    if (e.opposition.isNotEmpty) rows.add(_row('Opposition', e.opposition));
    if (e.paymentRequired) {
      rows.add(_row('Cost', '${_euro(e.paymentAmount)} per player'));
    }
    if (e.carPoolingEnabled) {
      rows.add(_row('Car pooling', 'Offer or find seats',
          onTap: () => _open(CreateCarPoolWidget.routeName, {
                'paramEventID': serializeParam(_eventId, ParamType.int),
                'paramRoleLevel': serializeParam(_role, ParamType.int),
              })));
    }
    if (e.eventLink.isNotEmpty) {
      rows.add(_row('Link', _linkLabel(e.eventLink),
          onTap: () => launchURL(e.eventLink)));
    }
    if (e.eventDetails.trim().isNotEmpty) {
      rows.add(_row('Notes', e.eventDetails.trim()));
    }
    if (e.createdBy.isNotEmpty) rows.add(_row('Created by', e.createdBy));
    return _card(rows);
  }

  String _linkLabel(String url) {
    final u = Uri.tryParse(url);
    if (u == null || u.host.isEmpty) return url;
    return u.host.replaceFirst('www.', '');
  }

  Widget _row(String k, String v, {VoidCallback? onTap}) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 92, child: Text(k, style: V3.inter(15, color: V3.muted))),
          Expanded(
              child: Text(v,
                  style: V3.inter(15,
                      color: onTap != null ? V3.green : V3.text,
                      height: 1.35))),
          if (onTap != null)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.chevron_right, color: V3.muted, size: 20),
            ),
        ],
      ),
    );
    return onTap == null ? child : InkWell(onTap: onTap, child: child);
  }

  Widget _card(List<Widget> rows) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
            color: V3.card, borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              decoration: BoxDecoration(
                  border: i == rows.length - 1
                      ? null
                      : const Border(bottom: BorderSide(color: V3.line))),
              child: rows[i],
            ),
        ]),
      );

  // ------------------------------------------------------------------ sheets

  void _showChangeReply(TeamMembersStruct m) {
    showModalBottomSheet(
      context: context,
      backgroundColor: V3.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _grab(),
            Text('Your reply', style: V3.tight(20)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _reply(m, 3);
                  },
                  style: FilledButton.styleFrom(
                      backgroundColor: V3.green,
                      foregroundColor: V3.bg,
                      minimumSize: const Size(0, 46)),
                  child: Text('Attending',
                      style:
                          V3.inter(15, weight: FontWeight.w700, color: V3.bg)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _reply(m, 4);
                  },
                  style: FilledButton.styleFrom(
                      backgroundColor: V3.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 46)),
                  child: Text('Decline',
                      style: V3.inter(15,
                          weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _grab() => Container(
        width: 40,
        height: 5,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
            color: const Color(0xFF444A56),
            borderRadius: BorderRadius.circular(3)),
      );

  // Manage sheet for admins (role 100+).
  void _showManage() {
    final e = _ev!;
    showModalBottomSheet(
      context: context,
      backgroundColor: V3.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Widget item(IconData icon, String title, String sub,
              {VoidCallback? onTap, Widget? trailing, bool red = false}) {
            final color = red ? V3.redText : V3.text;
            return InkWell(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: V3.line))),
                child: Row(children: [
                  Icon(icon,
                      size: 22,
                      color: red
                          ? V3.redText
                          : (onTap != null ? V3.green : V3.muted)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: V3.inter(17,
                                weight: FontWeight.w500, color: color)),
                        if (sub.isNotEmpty)
                          Text(sub, style: V3.inter(13, color: V3.muted)),
                      ],
                    ),
                  ),
                  trailing ??
                      (onTap != null
                          ? const Icon(Icons.chevron_right,
                              color: V3.muted, size: 22)
                          : const SizedBox.shrink()),
                ]),
              ),
            );
          }

          Widget sw(bool on, Future<void> Function(bool) onChanged) => Switch(
                value: on,
                activeThumbColor: Colors.white,
                activeTrackColor: V3.green,
                inactiveTrackColor: const Color(0xFF3A3F4A),
                onChanged: (v) async {
                  await onChanged(v);
                  setSheet(() {});
                },
              );

          final cur = _ev ?? e;
          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _grab(),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Manage event', style: V3.tight(20))),
                  const SizedBox(height: 6),
                  item(Icons.edit_outlined, 'Edit event',
                      'Title, time, venue, squad, details', onTap: () {
                    Navigator.pop(ctx);
                    _open(EditEventWidget.routeName, {
                      'paramEventId': serializeParam(_eventId, ParamType.int),
                    });
                  }),
                  item(Icons.notifications_outlined, 'Send reminder',
                      "Push to everyone who hasn't replied", onTap: () {
                    Navigator.pop(ctx);
                    _sendReminder();
                  }),
                  item(Icons.notifications_outlined, 'Alert admins on changes',
                      'Attending to declined and back only',
                      trailing: sw(cur.notifyAdminsChanges,
                          (v) => _setFlag('notify_admins_changes', v))),
                  item(Icons.notifications_outlined,
                      'Alert admins on every reply', '',
                      trailing: sw(cur.notifyAdminsAll,
                          (v) => _setFlag('notify_admins_all', v))),
                  item(Icons.directions_car_outlined, 'Car pooling', '',
                      trailing: sw(cur.carPoolingEnabled,
                          (v) => _setFlag('car_pooling', v))),
                  if (cur.paymentRequired)
                    item(Icons.shopping_cart_outlined, 'Payments',
                        '${_euro(cur.newGrossAmount)} collected · ${cur.newNumPayments} of ${cur.acceptedPlayerCount} paid',
                        onTap: () {
                      Navigator.pop(ctx);
                      _open(PaymentTransactionsWidget.routeName, {
                        'paramEventID': serializeParam(_eventId, ParamType.int),
                      });
                    }),
                  if (_cancelled)
                    item(Icons.restore, 'Reinstate event',
                        'Put the event back on everyone\'s list', onTap: () {
                      Navigator.pop(ctx);
                      _setStatus('active');
                    })
                  else
                    item(Icons.cancel_outlined, 'Cancel event', '', red: true,
                        onTap: () async {
                      Navigator.pop(ctx);
                      if (await _confirm(
                          'Cancel this event?',
                          'It stays on the list marked cancelled. You can reinstate it later.',
                          'Cancel event')) {
                        _setStatus('cancelled');
                      }
                    }),
                  item(Icons.delete_outline, 'Delete event', '', red: true,
                      onTap: () async {
                    Navigator.pop(ctx);
                    if (await _confirm(
                        'Delete this event?',
                        'It disappears from everyone\'s list. This cannot be undone from the app.',
                        'Delete')) {
                      _setStatus('deleted');
                    }
                  }),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Tool {
  _Tool(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

// Full-screen webview for the tools that live on coachsmart.app.
class _V3WebPage extends StatelessWidget {
  const _V3WebPage({required this.title, required this.url});
  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: V3.bg,
      body: SafeArea(
        child: custom_widgets.NativeWebView(
          width: double.infinity,
          height: double.infinity,
          url: url,
          onLogout: () async => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }
}
