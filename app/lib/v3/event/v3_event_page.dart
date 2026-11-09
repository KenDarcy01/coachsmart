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

/// Number of users a reminder went to. `populate_event_notifications`
/// returns one row `{"notifications_created": n}`, n being one notification
/// per user (a parent with two children counts once).
int reminderCount(dynamic body) {
  dynamic row = body;
  if (row is List) row = row.isEmpty ? null : row.first;
  if (row is Map) row = row['notifications_created'];
  if (row is int) return row;
  if (row is num) return row.toInt();
  return int.tryParse('$row') ?? 0;
}

String reminderMessage(int n) {
  if (n <= 0) return 'No reminder needed. Everyone has already replied.';
  if (n == 1) return 'Reminder sent to 1 person';
  return 'Reminder sent to $n people';
}

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
      _members.isNotEmpty;

  String _euro(int cents) => '€${(cents / 100).toStringAsFixed(2)}';

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
      if (!r.succeeded) {
        _snack('Could not send the reminder.', warn: true);
        return;
      }
      _snack(reminderMessage(reminderCount(r.jsonBody)));
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

  // Messages are centred (Ken, 2026-11-09).
  void _snack(String text, {bool warn = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(text,
            textAlign: TextAlign.center, style: V3.inter(14, color: V3.bg)),
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
        title: Text(_ev?.eventTitle ?? _homeEvent?.eventTitle ?? '',
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
          ? _loadingBody()
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
                      // No header block: the title is in the app bar and
                      // the date and team sit in Details (Ken, 2026-11-08).
                      // Replying is why most people open an event, so the
                      // reply rows come first (Ken, 2026-11-07).
                      const SizedBox(height: 4),
                      // No "Your reply" heading: the name buttons speak for
                      // themselves (Ken, 2026-11-09).
                      if (_showReplyBlock) _replyCard(),
                      if (_owing.isNotEmpty && (_ev!.paymentRequired))
                        _payButton(),
                      if (_showReplyBlock ||
                          (_owing.isNotEmpty && _ev!.paymentRequired))
                        const SizedBox(height: 14),
                      _tiles(),
                      // Car pooling gets its own strip under the tiles so it
                      // is obvious when switched on (Ken, 2026-11-09).
                      if (_ev!.carPoolingEnabled) _carPoolBar(),
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

  // The home list already knows this event, so show its title, team and
  // time at once and let the details fill in (Ken, 2026-11-07: opening an
  // event felt slow).
  EventsStruct? get _homeEvent {
    for (final e in FFAppState().homePageEvents.events) {
      if (e.eventId == _eventId) return e;
    }
    return null;
  }

  Widget _loadingBody() => const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(
            child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: V3.green))),
      );

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(text.toUpperCase(),
            style: V3.inter(13,
                weight: FontWeight.w700, color: V3.green, letterSpacing: .8)),
      );

  // Hero: crest, team + squad, title, date · time · countdown, pills.
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
            // Meet time if set, else the event start time, with no note
            // underneath (Ken, 2026-11-09: "at the start" was confusing).
            tile('Meet', e.meetTime.isEmpty && t != null ? hhmm(t) : e.meetTime,
                ''),
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

  void _openCarPool() => _open(CreateCarPoolWidget.routeName, {
        'paramEventID': serializeParam(_eventId, ParamType.int),
        'paramRoleLevel': serializeParam(_role, ParamType.int),
      });

  // Full-width green-outlined strip: car icon, "Car pooling", one line of
  // what it does, chevron. Shown only when the event has car pooling on.
  Widget _carPoolBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: _openCarPool,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
              color: V3.card,
              border: Border.all(color: V3.green, width: 1.5),
              borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Icon(Icons.directions_car_outlined,
                color: V3.green, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Car pooling',
                      style: V3.inter(16, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Offer a lift or find a seat',
                      style: V3.inter(13.5, color: V3.muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: V3.muted, size: 24),
          ]),
        ),
      ),
    );
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

  // One row per linked member, each with its own Attending / Decline
  // buttons. No "All attending / None attending" shortcut and no divider
  // between rows (Ken, 2026-11-09).
  // No card around the rows either: the buttons sit straight on the page
  // (Ken, 2026-11-09).
  Widget _replyCard() {
    final e = _ev!;
    return Column(children: [
      for (final m in _members) _memberRow(m, e.paymentRequired),
    ]);
  }

  // One row per linked member: two equal buttons with the first name inside,
  // "✓ Aoife" | "✗ Aoife", as v2 did (Ken, 2026-11-08). Unanswered: both
  // grey. Chosen: solid green or red; the other goes dim.
  Widget _memberRow(TeamMembersStruct m, bool paidEvent) {
    final busy = _busy.contains(m.memberId);
    final going = m.responseId == 3;
    final declined = m.responseId == 4;
    final answered = going || declined;
    final name = m.firstName.isNotEmpty ? m.firstName : m.lastName;
    const dim = Color(0xFF7C8089);

    Widget button(bool isGo) {
      final on = isGo ? going : declined;
      final Color bg;
      final Color fg;
      if (on) {
        bg = isGo ? V3.green : V3.red;
        fg = isGo ? V3.bg : Colors.white;
      } else if (answered) {
        bg = V3.card2;
        fg = dim;
      } else {
        // Unanswered: both buttons white so neither looks chosen
        // (Ken, 2026-11-09).
        bg = V3.card2;
        fg = V3.text;
      }
      return Expanded(
        child: GestureDetector(
          onTap: busy ? null : () => _reply(m, isGo ? 3 : 4),
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(isGo ? Icons.check : Icons.close, size: 18, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: V3.inter(15, weight: FontWeight.w700, color: fg)),
              ),
              if (isGo && paidEvent && m.memberPaid == 1) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .25),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('Paid',
                      style: V3.inter(11,
                          weight: FontWeight.w600,
                          color: on ? V3.bg : V3.green)),
                ),
              ],
            ]),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: busy
          ? const SizedBox(
              height: 44,
              child: Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: V3.green))))
          : Row(children: [
              button(true),
              const SizedBox(width: 8),
              button(false),
            ]),
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
    // Every role appears in every tile, zero included, in one order
    // (Ken, 2026-11-08). Players (level 10) are the big number itself.
    final roleOrder = <String>[];
    void collect(Iterable<({String name, int level})> rs) {
      for (final r in rs) {
        if (r.level > 10 && !roleOrder.contains(r.name)) roleOrder.add(r.name);
      }
    }

    collect(e.acceptedAttendanceSummary
        .map((r) => (name: r.roleNamePlural, level: r.roleLevel)));
    collect(e.noResponseAttendanceSummary
        .map((r) => (name: r.roleNamePlural, level: r.roleLevel)));
    collect(e.declinedAttendanceSummary
        .map((r) => (name: r.roleNamePlural, level: r.roleLevel)));
    String lines(Map<String, int> counts) =>
        roleOrder.map((r) => '$r: ${counts[r] ?? 0}').join('\n');
    final aLines = lines({
      for (final r in e.acceptedAttendanceSummary)
        r.roleNamePlural: r.memberCount
    });
    final nLines = lines({
      for (final r in e.noResponseAttendanceSummary)
        r.roleNamePlural: r.memberCount
    });
    final dLines = lines({
      for (final r in e.declinedAttendanceSummary)
        r.roleNamePlural: r.memberCount
    });

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

    // Three tiles the same height, no bar underneath (Ken, 2026-11-08).
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        tile('Attending', a, V3.green, const Color(0xFF1F2A19), aLines, 3),
        const SizedBox(width: 8),
        tile('No reply', n, const Color(0xFF9A9A9A), V3.card2, nLines, 0),
        const SizedBox(width: 8),
        tile('Declined', d, const Color(0xFFC3202A), const Color(0xFF3A1D1D),
            dLines, 4),
      ]),
    );
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

  // Details card: Type, Opposition, Link, Notes, Created by.
  Widget _details() {
    final e = _ev!;
    final rows = <Widget>[];
    final t = _when;
    if (t != null) {
      rows.add(_row(
          'When',
          '${DateFormat('EEE d MMM').format(t)} · ${hhmm(t)}'
              '${!_cancelled && t.isAfter(DateTime.now()) ? ' · ${countdown(t, DateTime.now())}' : ''}'));
    }
    final team = [
      e.teamName,
      if (_squadName.isNotEmpty) _squadName,
    ].join(' · ');
    if (team.isNotEmpty) rows.add(_row('Team', team));
    if (_cancelled) rows.add(_row('Status', 'Cancelled'));
    if (e.homeAway.isNotEmpty) rows.add(_row('Home / Away', e.homeAway));
    final type = [
      if (e.eventType.isNotEmpty) e.eventType,
      if (e.eventCode.isNotEmpty) e.eventCode,
    ].join(' · ');
    if (type.isNotEmpty) rows.add(_row('Type', type));
    if (e.opposition.isNotEmpty) rows.add(_row('Opposition', e.opposition));
    if (e.paymentRequired) {
      rows.add(_row('Cost', '${_euro(e.paymentAmount)} per player'));
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
