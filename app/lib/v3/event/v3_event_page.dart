// v3 Event details. Same data as the FlutterFlow page (get_user_event_details)
// in layout A of /mnt/project-files/coachsmart/app-v3/event-details-redesign/
// (Ken, 2026-11-12): replies, opposition card, Meet / Venue tiles, one banner
// per extra (cancelled, pay, payments summary, car pool), teams and tools by
// role (Parent, FLO, Coach, Admin), details, then teams and attendance. Admin actions sit
// behind the three-dot Manage sheet.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/auth/supabase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '../home/v3_home_data.dart';
import '../session_plan/v3_plan_view_page.dart';
import '../session_plan/v3_session_plan_api.dart' show spPlansChanged;
import '../lineup/v3_lineup_api.dart' show fetchPublishedSquads;
import '../lineup/v3_lineup_models.dart' show LineupSquad;
import '../v3_crest_image.dart';
import '../v3_open_location.dart';
import '../v3_theme.dart';
import 'v3_event_notify_sheet.dart';
import 'v3_event_teams.dart';
import 'v3_reminder_sheet.dart';
import 'v3_series_scope.dart';
import '/v3/tracking/v3_track.dart';

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

/// "Floodlights" look (Ken, 2026-11-13): near-black page with a green glow
/// at the top, outlined cards, Bebas Neue numbers and headings in neon
/// green. Mockup: app-v3/event-details-bold/vibe-T2.png. Tools keep the
/// "Club colours" solid squares (Ken's amendment).
class FL {
  static const bg = Color(0xFF07090A);
  static const card = Color(0xFF0F1214);
  static const line = Color(0xFF20252B);
  static const rowLine = Color(0xFF1A1E23);
  static const neon = Color(0xFF9BE33A);
  static const neonEdge = Color(0xFFB6FF5A);
  static const label = Color(0xFF6B7280);
  static const sub = Color(0xFF8A9099);
  static const off = Color(0xFF545A63);
  static const red = Color(0xFFFF5A5F);
  static const toolText = Color(0xFFD6D9DE);
  static const goEdge = Color(0xFF2B3A14);
  static const noEdge = Color(0xFF3A1517);

  static TextStyle bebas(double size,
          {Color color = V3.text,
          double letterSpacing = 1,
          double? height,
          List<Shadow>? glow}) =>
      GoogleFonts.bebasNeue(
          fontSize: size,
          color: color,
          letterSpacing: letterSpacing,
          height: height,
          shadows: glow);

  /// Small grey capitals for labels (MEET, VENUE, WHEN).
  static TextStyle caps({Color color = label, double spacing = 1.6}) => V3
      .inter(11, weight: FontWeight.w700, color: color, letterSpacing: spacing);

  static List<Shadow> glowOf(Color c, [double a = .5, double r = 16]) =>
      [Shadow(color: c.withValues(alpha: a), blurRadius: r)];

  static BoxDecoration box({Color edge = line, double radius = 16}) =>
      BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: edge));
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
  // member id -> the reply being saved, so only the tapped button spins.
  final Map<int, int> _busy = {};
  bool _paying = false;
  bool _teamAllowsLineup = false;
  // Bumped on every load so pull to refresh reloads the teams card too.
  int _teamsTick = 0;
  // Car pool summary for the green strip: open lifts and free seats.
  int? _lifts;
  int _seatsFree = 0;
  bool _reminding = false;

  int get _eventId => widget.eventID ?? 0;
  bool get _fromSearch => widget.fromSearch ?? false;

  @override
  void initState() {
    super.initState();
    _load();
    // A plan saved, attached or removed anywhere updates View plan.
    spPlansChanged.addListener(_loadPlan);
  }

  @override
  void dispose() {
    spPlansChanged.removeListener(_loadPlan);
    super.dispose();
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
        _teamsTick++;
        _raw = r.jsonBody is Map ? Map<String, dynamic>.from(r.jsonBody) : {};
        _loading = false;
        _error = null;
      });
      _loadTeamFlags(ev.teamId);
      _loadPlan();
      if (ev.carPoolingEnabled) _loadCarPools();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'This event could not be loaded.';
      });
    }
  }

  // The session's plan, for View plan (coaches and admins) and the
  // Create / Edit plan label (admins). Matches have no plan tools.
  String? _planId;

  Future<void> _loadPlan() async {
    if (_ev == null || _isMatch || _role < 30 || widget.testData != null) {
      return;
    }
    final id = await spEventPlanId(_eventId);
    if (mounted) setState(() => _planId = id);
  }

  Future<void> _editPlan() async {
    await openCoachingEventPlan(context, _eventId);
    _loadPlan();
  }

  Future<void> _loadCarPools() async {
    try {
      final r = await GetEventCarPoolsCall.call(
          pEventId: _eventId,
          pUserId: currentUserUid,
          supabaseJWTtoken: currentJwtToken);
      final body = r.jsonBody;
      final pools = body is Map && body['car_pools'] is List
          ? body['car_pools'] as List
          : const [];
      var free = 0;
      for (final p in pools) {
        if (p is Map && p['free_seats'] is num) {
          free += (p['free_seats'] as num).toInt();
        }
      }
      if (mounted) {
        setState(() {
          _lifts = pools.length;
          _seatsFree = free;
        });
      }
    } catch (_) {}
  }

  // Team feature switches that gate the Lineup and Session plan tools.
  Future<void> _loadTeamFlags(int teamId) async {
    try {
      final row = await SupaFlow.client
          .from('teams')
          .select('allow_lineup')
          .eq('team_id', teamId)
          .maybeSingle();
      if (!mounted || row == null) return;
      setState(() {
        _teamAllowsLineup = row['allow_lineup'] == true;
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
  // Nothing to pay on a cancelled event. Past events keep the button: the
  // payment reminder is often sent after the session.
  bool get _showPay =>
      (_ev?.paymentRequired ?? false) && !_cancelled && _owing.isNotEmpty;
  bool get _showReplyBlock =>
      (_ev?.requestAttendance ?? false) &&
      !_fromSearch &&
      !_cancelled &&
      _members.isNotEmpty;

  // "€10" for whole euros, "€7.50" otherwise.
  String _euro(int cents) => cents % 100 == 0
      ? '€${cents ~/ 100}'
      : '€${(cents / 100).toStringAsFixed(2)}';

  // ---------------------------------------------------------------- actions

  Future<void> _reply(TeamMembersStruct m, int responseId) async {
    if (m.responseId == responseId) return;
    setState(() => _busy[m.memberId] = responseId);
    try {
      final row = await EventAttendanceTable().insert({
        'event_id': _eventId,
        'member_id': m.memberId,
        'response_id': responseId,
      });
      V3Track.attendance(_eventId, responseId, 'event');
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
  String get _returnBase =>
      kIsWeb ? Uri.base.origin : 'https://my.coachsmart.app';

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
        // On the web the Stripe return lands back on this same site; the
        // apps keep the my.coachsmart.app links they are registered for.
        appSuccessUrl: '$_returnBase/checkoutSuccess',
        appCancelUrl: '$_returnBase/checkoutFailed',
        memberIdsList: owing.map((m) => m.memberId).toList(),
        unitPrice: e.paymentAmount,
      );
      final url = StripeCheckoutStruct.maybeFromMap(r.jsonBody)?.checkoutUrl;
      if (r.statusCode == 409) {
        // Someone else (the other parent) has paid since the page loaded.
        _snack('This has already been paid.');
        await _load();
        return;
      }
      if (url == null || url.isEmpty) {
        _snack('Could not start the payment. Please try again.', warn: true);
        return;
      }
      if (!mounted) return;
      // The server sets the price and leaves out anyone already paid for, so
      // the summary uses what it sent back when it says.
      final body = r.jsonBody is Map ? r.jsonBody as Map : const {};
      final ids = body['memberIds'] is List
          ? (body['memberIds'] as List).map((v) => '$v').toSet()
          : null;
      final paying = ids == null
          ? owing
          : owing.where((m) => ids.contains('${m.memberId}')).toList();
      final unit = body['unitPrice'] is num
          ? (body['unitPrice'] as num).toInt()
          : e.paymentAmount;
      await context.pushNamed(
        CheckoutWidget.routeName,
        queryParameters: {
          'paramEventId': serializeParam(_eventId, ParamType.int),
          'paramNumPayments': serializeParam(paying.length, ParamType.int),
          'paramPaymentAmount': serializeParam(unit, ParamType.int),
          'paramCheckoutUrl': serializeParam(url, ParamType.String),
          'paramPayingMembers': serializeParam(
              paying.map((m) => m.toMap()).toList(), ParamType.JSON,
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

  void _openAttendees(int responseId) {
    _open(AttendeeListWidget.routeName, {
      'eventID': serializeParam(_eventId, ParamType.int),
      'responseID': serializeParam(responseId, ParamType.int),
    });
  }

  /// Lineup (Ken, 2026-11-09): on the event page, not in the squad cards.
  /// The team selector works from the published match day squads, so ask
  /// for those first. Only squads with players published for this event
  /// are offered; with more than one ask which, and the lineup page shows
  /// a tab per squad to switch between (Ken, 2026-11-12).
  Future<void> _openLineup() async {
    final e = _ev!;
    try {
      final published = await MatchSquadsTable()
          .queryRows(queryFn: (q) => q.eq('event_id', _eventId).limit(1));
      if (!mounted) return;
      if (published.isEmpty) {
        _snack('Publish the match day squads first (Attending list).',
            warn: true);
        return;
      }
      var squadId = e.squadId;
      var squads = const <LineupSquad>[];
      if (squadId == 0) {
        squads = await fetchPublishedSquads(_eventId);
        if (!mounted) return;
        if (squads.length == 1) {
          squadId = squads.first.id;
        } else if (squads.length > 1) {
          final picked = await showModalBottomSheet<int>(
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
                      Text('Lineup for which squad?', style: V3.tight(20)),
                      const SizedBox(height: 2),
                      Text('Go back and pick again to see another squad.',
                          style: V3.inter(14, color: V3.muted)),
                      const SizedBox(height: 6),
                      for (final s in squads)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ClipOval(
                              child: s.image.isNotEmpty
                                  ? Image.network(s.image,
                                      width: 30, height: 30, fit: BoxFit.cover)
                                  : Container(
                                      width: 30, height: 30, color: V3.green)),
                          title: Text(s.name,
                              style: V3.inter(17, weight: FontWeight.w500)),
                          onTap: () => Navigator.pop(ctx, s.id),
                        ),
                    ]),
              ),
            ),
          );
          if (picked == null || !mounted) return;
          squadId = picked;
        }
      }
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
          settings: const RouteSettings(name: 'V3LineupPage'),
          builder: (_) => V3LineupPage(
              eventId: _eventId, teamId: e.teamId, squadId: squadId)));
    } catch (_) {
      _snack('Could not open the lineup. Please try again.', warn: true);
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
      final n = reminderCount(r.jsonBody);
      V3Track.event('reminder_sent', {'count': n});
      _snack(reminderMessage(n));
    } catch (_) {
      _snack('Could not send the reminder.', warn: true);
    }
  }

  // Cancel, reinstate or delete. For a repeating series the admin picks
  // "just this event" or "this and later events" (Ken, 2026-11-09); the
  // set_event_series_status RPC writes events.status and
  // event_attendance.status like the FlutterFlow edit page did.
  // Cancel or delete through the "Tell the team" sheet (Ken, 2026-11-12):
  // the series choice, who would be told and the action in one step.
  Future<void> _cancelOrDelete(EventAction a) async {
    final e = _ev;
    if (e == null) return;
    final later = await _seriesLater();
    if (!mounted) return;
    final t = _when;
    final pick = await showEventActionSheet(context,
        action: a,
        title: e.eventTitle,
        when: t == null ? '' : notifyWhen(t),
        venue: e.locationName,
        eventId: _eventId,
        later: later);
    if (pick == null) return;
    final n = await _setStatus(
        a == EventAction.cancel ? 'cancelled' : 'deleted',
        scope: pick.scope);
    if (n == 0) return;
    try {
      final told = await notifyEventChange(_eventId, a,
          note: pick.note, events: n, tell: pick.tell);
      V3Track.event('event_change_notify',
          {'kind': a.name, 'tell': pick.tell, 'told': told});
      if (pick.tell) {
        _snack(told == 1 ? '1 person told' : '$told people told');
      }
    } catch (_) {
      if (pick.tell) _snack('Could not tell the team.', warn: true);
    }
  }

  /// Returns how many events changed (0 when it failed or was dismissed).
  Future<int> _setStatus(String status, {String? scope}) async {
    try {
      if (scope != null) {
        return await _applyStatus(status, scope);
      }
      scope = 'one';
      final later = await _seriesLater();
      if (later > 1 && mounted) {
        final pick = await askSeriesScope(context,
            action: status == 'active'
                ? 'Reinstate'
                : status == 'cancelled'
                    ? 'Cancel'
                    : 'Delete',
            later: later);
        if (pick == null) return 0;
        scope = pick;
      }
      return await _applyStatus(status, scope);
    } catch (_) {
      _snack('Could not update the event.', warn: true);
      return 0;
    }
  }

  Future<int> _applyStatus(String status, String scope) async {
    try {
      V3Track.event('event_status_set', {'status': status, 'scope': scope});
      final res = await SupaFlow.client.rpc('set_event_series_status', params: {
        'p_event_id': _eventId,
        'p_scope': scope,
        'p_status': status,
      });
      final map = res is Map ? res : <String, dynamic>{};
      if (map['success'] != true) {
        _snack((map['message'] ?? 'Could not update the event.').toString(),
            warn: true);
        return 0;
      }
      final n = (map['events_updated'] as num?)?.toInt() ?? 1;
      if (status == 'deleted') {
        if (mounted) _back();
        return n;
      }
      await _load();
      return n;
    } catch (_) {
      _snack('Could not update the event.', warn: true);
      return 0;
    }
  }

  /// How many events of this one's series are on or after it (0 = none).
  Future<int> _seriesLater() async {
    try {
      final r = await GetUserEventEditDetailCall.call(
          pUserId: currentUserUid,
          pEventId: _eventId,
          supabaseJWTtoken: currentJwtToken);
      final cur =
          r.jsonBody is Map ? (r.jsonBody as Map)['current_event'] : null;
      if (cur is Map && cur['series_id'] != null) {
        return (cur['series_later'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
    return 0;
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
      backgroundColor: FL.bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: V3.green, size: 40),
          onPressed: _back,
        ),
        centerTitle: true,
        title: Text(
            (_ev?.eventTitle ?? _homeEvent?.eventTitle ?? '').toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FL.bebas(26, letterSpacing: 1.4)),
        actions: [
          if (_admin && _ev != null)
            IconButton(
              icon: const Icon(Icons.more_vert, color: V3.green, size: 26),
              onPressed: _showManage,
            ),
        ],
      ),
      body: Stack(children: [
        // Floodlight glow behind the top of the page.
        Positioned(
          left: -80,
          right: -80,
          top: -160,
          height: 420,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(colors: [
                  FL.neon.withValues(alpha: .22),
                  FL.neon.withValues(alpha: 0),
                ], stops: const [
                  0,
                  .7
                ]),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + kToolbarHeight),
          child: _loading
              ? _loadingBody()
              : _error != null
                  ? Center(
                      child:
                          Text(_error!, style: V3.inter(15, color: V3.muted)))
                  : RefreshIndicator(
                      color: FL.neon,
                      backgroundColor: FL.card,
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
                          // Layout A (Ken, 2026-11-12): replies, the
                          // opposition, Meet and Venue, one banner per extra,
                          // tools, details, then teams and attendance.
                          if (_cancelled) _cancelBanner(),
                          if (_showReplyBlock) ...[
                            _replyCard(),
                            const SizedBox(height: 10),
                          ],
                          if (_isMatch && _ev!.opposition.trim().isNotEmpty)
                            _oppositionCard(),
                          _tiles(),
                          if (_showPay) _payBanner(),
                          if (_admin && _ev!.paymentRequired && !_cancelled)
                            _paidSummaryBanner(),
                          if (_ev!.carPoolingEnabled && !_cancelled)
                            _carPoolBar(),
                          if (_tools().isNotEmpty && !_cancelled) _toolsRow(),
                          // Details above teams and attendance (Ken,
                          // 2026-11-12).
                          _section('Details'),
                          _details(),
                          const SizedBox(height: 10),
                          // Published teams (Ken, 2026-11-12), by role.
                          if (widget.testData == null ||
                              widget.testData!['teams'] is Map)
                            V3EventTeamsCard(
                                key: ValueKey('teams-$_teamsTick'),
                                eventId: _eventId,
                                role: _role,
                                onEdit: () => _openAttendees(3),
                                onSnack: _snack,
                                testData: widget.testData?['teams']
                                    as Map<String, dynamic>?),
                          if (_role >= 20 && _ev!.requestAttendance) ...[
                            _section('Attendance'),
                            _attendance(),
                          ],
                        ],
                      ),
                    ),
        ),
      ]),
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

  // Bebas heading in neon green with a fading green rule after it
  // (Floodlights, Ken 2026-11-13).
  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Row(children: [
          Text(text.toUpperCase(),
              style:
                  FL.bebas(22, color: FL.neon, letterSpacing: 1.6, height: 1)),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: const BoxDecoration(
                  gradient:
                      LinearGradient(colors: [FL.goEdge, Color(0x002B3A14)])),
            ),
          ),
        ]),
      );

  // Opposition card on matches, as a scoreboard line: crest, "CLONTARF V
  // RAHENY" in Bebas (the V muted), "MATCH · FOOTBALL" in small capitals,
  // and an outlined HOME / AWAY badge (Floodlights, Ken 2026-11-13).
  Widget _oppositionCard() {
    final e = _ev!;
    final ha = e.homeAway.trim();
    final sub = [
      'Match',
      if (e.eventCode.isNotEmpty) e.eventCode,
    ].join(' · ').toUpperCase();
    final club = _club;
    final ours = club.name.isNotEmpty ? club.name : _clubFromTeam(e.teamName);
    final bebas = FL.bebas(30, letterSpacing: 1, height: 1);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: FL.box(),
      child: Row(children: [
        V3CrestImage(club.crest.isEmpty ? null : club.crest,
            size: 40,
            fallback: Container(
                decoration: const BoxDecoration(
                    color: Color(0xFF1A1E23), shape: BoxShape.circle),
                child: const Icon(Icons.shield_outlined,
                    color: FL.label, size: 20))),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text.rich(
              TextSpan(children: [
                if (ours.isNotEmpty) TextSpan(text: '${ours.toUpperCase()} '),
                TextSpan(text: 'V ', style: bebas.copyWith(color: FL.off)),
                TextSpan(text: e.opposition.trim().toUpperCase()),
              ]),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: bebas,
            ),
            const SizedBox(height: 4),
            Text(sub, style: FL.caps(spacing: 1.4)),
          ]),
        ),
        if (ha.isNotEmpty) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 2),
            decoration: BoxDecoration(
                border: Border.all(color: FL.neon, width: 1.5),
                borderRadius: BorderRadius.circular(8)),
            child: Text(ha.toUpperCase(),
                style: FL.bebas(18, color: FL.neon, letterSpacing: 1.4)),
          ),
        ],
      ]),
    );
  }

  /// The event's club name and crest, from what Home already loaded.
  ({String name, String crest}) get _club {
    final id = _homeEvent?.clubId ?? 0;
    if (id != 0) {
      for (final c in FFAppState().homePageEvents.clubs) {
        if (c.clubId == id) return (name: c.clubName, crest: c.crest);
      }
    }
    return (name: '', crest: '');
  }

  // "Clontarf GAA Boys 2014" -> "Clontarf": the words before GAA, CLG, a
  // grade or an age.
  String _clubFromTeam(String team) {
    final out = <String>[];
    for (final w in team.split(RegExp(r'\s+'))) {
      if (RegExp(
              r'^(GAA|CLG|LGFA|Boys|Girls|Ladies|Camogie|Hurling|Football|Minor|Senior|Junior|U\d+|\d+)$',
              caseSensitive: false)
          .hasMatch(w)) {
        break;
      }
      out.add(w);
    }
    return out.join(' ');
  }

  // Meet and Venue tiles. Meet shows the meet time as typed ("9:30 / 10:30",
  // "TBC") or the start, with the start underneath; Venue wraps to two
  // lines with Directions under it. A cancelled event shows WAS with the
  // time struck through (Ken, 2026-11-12, layout A). Floodlights: values
  // in neon Bebas with a glow (Ken, 2026-11-13).
  Widget _tiles() {
    final e = _ev!;
    final t = _when;
    final start = t == null ? '' : hhmm(t);
    final day = t == null ? '' : DateFormat('EEE d MMM').format(t);
    final meet = e.meetTime.trim();
    final meetValue = meet.isNotEmpty ? meet : start;
    final meetSub = _cancelled || meet.isEmpty || start.isEmpty
        ? day
        : '${_isMatch ? 'Throw-in' : 'Start'} $start';
    final venue = e.locationName.trim();
    final venueTbc = venue.isEmpty || venue.toUpperCase() == 'TBC';
    final canGo = !venueTbc && e.locationPin.isNotEmpty;

    TextStyle value(Color c, {bool strike = false}) {
      final st = FL.bebas(38,
          color: c,
          letterSpacing: .8,
          height: 1,
          glow: strike ? null : FL.glowOf(c));
      return strike
          ? st.copyWith(
              decoration: TextDecoration.lineThrough, decorationColor: FL.sub)
          : st;
    }

    final meetTile = Container(
      padding: const EdgeInsets.all(14),
      decoration: FL.box(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_cancelled ? 'WAS' : 'MEET', style: FL.caps()),
        const SizedBox(height: 6),
        Text(meetValue.isEmpty ? '—' : meetValue.toUpperCase(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: _cancelled
                ? value(FL.sub, strike: true)
                : value(meet.toUpperCase() == 'TBC' ? V3.amber : FL.neon)),
        if (meetSub.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(meetSub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: V3.inter(13, weight: FontWeight.w500, color: FL.sub)),
        ],
      ]),
    );

    final venueTile = GestureDetector(
      onTap: canGo ? () => openLocationPin(e.locationPin, venue) : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: FL.box(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e.homeAway.toLowerCase() == 'away' ? 'AWAY VENUE' : 'VENUE',
              style: FL.caps()),
          const SizedBox(height: 6),
          Text(venueTbc ? 'TBC' : venue.toUpperCase(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: value(venueTbc ? V3.amber : FL.neon)
                  .copyWith(fontSize: venue.length > 14 ? 28 : 38)),
          if (venueTbc || canGo) ...[
            const SizedBox(height: 6),
            Text(venueTbc ? 'To be confirmed' : 'Directions ›',
                style: V3.inter(13,
                    weight: FontWeight.w600, color: canGo ? V3.text : FL.sub)),
          ],
        ]),
      ),
    );

    // IntrinsicHeight gives the stretched row a bounded height inside the
    // list; without it the tiles get infinite height and nothing below renders.
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: meetTile),
            const SizedBox(width: 10),
            Expanded(child: venueTile),
          ],
        ),
      ),
    );
  }

  // One coloured banner per extra: icon, title, a muted line, an optional
  // button on the right.
  Widget _banner({
    required IconData icon,
    required Color tint,
    required Color bg,
    required Color border,
    required String title,
    String sub = '',
    Widget? action,
    VoidCallback? onTap,
    double borderWidth = 1,
    Color? titleColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: border, width: borderWidth),
              borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Icon(icon, color: tint, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: V3.inter(15,
                            weight: FontWeight.w600,
                            color: titleColor ?? tint)),
                    if (sub.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(sub,
                          style: V3.inter(13, color: V3.muted, height: 1.3)),
                    ],
                  ]),
            ),
            if (action != null) ...[const SizedBox(width: 10), action],
          ]),
        ),
      ),
    );
  }

  Widget _bannerButton(String text, Color bg, Color fg, VoidCallback? onTap,
          {bool busy = false, Color? outline}) =>
      SizedBox(
        height: 38,
        child: TextButton(
          onPressed: busy ? null : onTap,
          style: TextButton.styleFrom(
              backgroundColor: bg,
              foregroundColor: fg,
              disabledBackgroundColor: bg,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                  side: outline == null
                      ? BorderSide.none
                      : BorderSide(color: outline, width: 1.5),
                  borderRadius: BorderRadius.circular(10))),
          child: busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg))
              : Text(text,
                  style: V3.inter(14, weight: FontWeight.w700, color: fg)),
        ),
      );

  static const _redText = Color(0xFFFF8A8E);
  static const _amberBg = Color(0xFF2B2512);
  static const _amberLine = Color(0xFF6B5520);

  // Red banner at the top of a cancelled event. The events table keeps no
  // reason, who or when, so the line is generic. Admins reinstate here.
  Widget _cancelBanner() => _banner(
        icon: Icons.block,
        tint: _redText,
        bg: const Color(0xFF3A1D1F),
        border: const Color(0xFF6B2A2E),
        title: 'Cancelled',
        sub: 'This event is not going ahead.',
        action: _admin
            ? _bannerButton('Reinstate', Colors.transparent, _redText,
                () => _setStatus('active'),
                outline: _redText)
            : null,
      );

  // Amber banner for a parent who owes: "€10 due for Aoife", who has paid
  // underneath, and the Pay button (replaces the green Pay button).
  Widget _payBanner() {
    final e = _ev!;
    final owing = _owing;
    final names = owing
        .map((m) => m.firstName.isNotEmpty ? m.firstName : m.lastName)
        .where((n) => n.isNotEmpty)
        .toList();
    final paid = _members
        .where((m) =>
            m.roleLevel == 10 &&
            m.responseId == 3 &&
            m.memberPaymentStatus == 'confirmed')
        .map((m) => m.firstName)
        .where((n) => n.isNotEmpty)
        .toList();
    final amount = _euro(e.paymentAmount * owing.length);
    return _banner(
      icon: Icons.euro,
      tint: V3.amber,
      bg: _amberBg,
      border: _amberLine,
      title: names.isEmpty ? '$amount due' : '$amount due for ${_and(names)}',
      sub: paid.isEmpty ? '' : '${_and(paid)} paid',
      action:
          _bannerButton('Pay $amount', V3.amber, V3.bg, _pay, busy: _paying),
    );
  }

  String _and(List<String> names) => names.length <= 1
      ? names.join()
      : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';

  // Admins on a paid event: "12 of 18 paid · €120" and Remind. Coaches
  // never see payments. Tapping the banner opens the payments page.
  Widget _paidSummaryBanner() {
    final e = _ev!;
    final paid = e.newNumPayments;
    final of = e.acceptedPlayerCount;
    final unpaid = of - paid > 0 ? of - paid : 0;
    return _banner(
      icon: Icons.euro,
      tint: V3.amber,
      bg: _amberBg,
      border: _amberLine,
      title: '$paid of $of paid · ${_euro(e.newGrossAmount)}',
      sub: unpaid == 0
          ? 'Everyone attending has paid'
          : '$unpaid attending ${unpaid == 1 ? 'player has' : 'players have'} not paid yet',
      onTap: () => _open(PaymentTransactionsWidget.routeName, {
        'paramEventID': serializeParam(_eventId, ParamType.int),
        'eventTitle': serializeParam(e.eventTitle, ParamType.String),
      }),
      action: unpaid == 0
          ? const Icon(Icons.chevron_right, color: V3.muted, size: 22)
          : _bannerButton('Remind $unpaid', V3.amber, V3.bg, _remindUnpaid,
              busy: _reminding),
    );
  }

  Future<void> _remindUnpaid() async {
    setState(() => _reminding = true);
    try {
      V3Track.event('payment_reminder_sent', {'event_id': _eventId});
      final r = await SupaFlow.client.rpc('send_event_payment_reminders',
          params: {'p_event_id': _eventId});
      if (r is Map && r['success'] == false) throw Exception(r['message']);
      final sent = r is Map ? (r['sent'] ?? 0) : 0;
      _snack(sent == 0
          ? 'Nobody to remind: no app user is linked to those players.'
          : sent == 1
              ? 'Reminder sent to 1 person'
              : 'Reminders sent to $sent people');
    } catch (_) {
      _snack('Could not send the reminders. Please try again.', warn: true);
    } finally {
      if (mounted) setState(() => _reminding = false);
    }
  }

  // Match tools by role; Session plan on other event types.
  List<_Tool> _tools() {
    final out = <_Tool>[];
    if (_isMatch) {
      if (_role >= 20) {
        out.add(_Tool(
            'Score',
            Icons.timer_outlined,
            () => Navigator.of(context).push(MaterialPageRoute(
                settings: const RouteSettings(name: 'V3ScoreKeeperPage'),
                builder: (_) => V3ScoreKeeperPage(eventId: _eventId)))));
      }
      out.add(_Tool(
          'Live',
          Icons.visibility_outlined,
          () => Navigator.of(context).push(MaterialPageRoute(
              settings: const RouteSettings(name: 'V3MatchLivePage'),
              builder: (_) => V3MatchLivePage(eventId: _eventId)))));
      // Parent: Live. FLO: Score, Live. Coach: + Stats, Report. Admin:
      // + Lineup (Ken, 2026-11-12: coaches can't make a lineup).
      if (_role >= 30) {
        out.add(_Tool('Stats', Icons.bar_chart,
            () => _open(MatchStatsWidget.routeName, _matchParams())));
      }
      if (_role >= 30) {
        out.add(_Tool(
            'Report',
            Icons.description_outlined,
            () => Navigator.of(context).push(MaterialPageRoute(
                settings: const RouteSettings(name: 'V3MatchReportPage'),
                builder: (_) => V3MatchReportPage(eventId: _eventId)))));
      }
      if (_admin && _teamAllowsLineup) {
        out.add(_Tool('Lineup', Icons.grid_view_outlined, _openLineup));
      }
    } else if (_role >= 30) {
      // View plan: the branded phone PDF for coaches and admins once the
      // session has a plan. Create / Edit plan: admins only (Ken, 2026-11-12).
      final planId = _planId;
      if (planId != null) {
        out.add(_Tool(
            'View plan',
            Icons.description_outlined,
            () => Navigator.of(context).push(MaterialPageRoute(
                settings: const RouteSettings(name: 'V3PlanViewPage'),
                builder: (_) => V3PlanViewPage(planId: planId)))));
      }
      if (_admin) {
        out.add(_Tool(planId == null ? 'Create plan' : 'Edit plan',
            Icons.assignment_outlined, _editPlan));
      }
    }
    return out;
  }

  void _openCarPool() => _open(CreateCarPoolWidget.routeName, {
        'paramEventID': serializeParam(_eventId, ParamType.int),
        'paramRoleLevel': serializeParam(_role, ParamType.int),
      });

  String _carPoolLine() {
    final n = _lifts;
    if (n == null || n == 0) return 'Offer a lift or find a seat';
    return '$n ${n == 1 ? 'lift' : 'lifts'} · '
        '$_seatsFree ${_seatsFree == 1 ? 'seat' : 'seats'} free';
  }

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
              color: FL.card,
              border: Border.all(color: FL.neon, width: 1.5),
              borderRadius: BorderRadius.circular(16)),
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
                  Text(_carPoolLine(), style: V3.inter(13.5, color: V3.muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: V3.muted, size: 24),
          ]),
        ),
      ),
    );
  }

  // Tool row: outlined cards, each with a solid colour square holding a
  // white icon and a bold label (Ken, 2026-11-13).
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
                  decoration: FL.box(),
                  child: Column(children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                          color: tools[i].colour,
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(tools[i].icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(height: 7),
                    Text(tools[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: V3.inter(12.5,
                            weight: FontWeight.w700, color: Colors.white)),
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
    final busy = _busy.containsKey(m.memberId);
    final saving = _busy[m.memberId];
    final going = m.responseId == 3;
    final declined = m.responseId == 4;
    final answered = going || declined;
    final name = m.firstName.isNotEmpty ? m.firstName : m.lastName;
    Widget button(bool isGo) {
      final on = isGo ? going : declined;
      final Color bg;
      final Color fg;
      Color edge = FL.line;
      List<BoxShadow>? glow;
      if (on) {
        // Floodlights: the chosen reply glows (Ken, 2026-11-13).
        bg = isGo ? FL.neon : V3.red;
        fg = isGo ? FL.bg : Colors.white;
        edge = isGo ? FL.neonEdge : const Color(0xFFFF7B7F);
        glow = [
          BoxShadow(
              color: (isGo ? FL.neon : V3.red).withValues(alpha: .45),
              blurRadius: 24)
        ];
      } else if (answered) {
        bg = FL.card;
        fg = FL.off;
      } else {
        // Unanswered: both buttons white so neither looks chosen
        // (Ken, 2026-11-09).
        bg = FL.card;
        fg = V3.text;
      }
      return Expanded(
        child: GestureDetector(
          onTap: busy ? null : () => _reply(m, isGo ? 3 : 4),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: edge),
                boxShadow: glow,
                borderRadius: BorderRadius.circular(14)),
            // The tapped button shows the spinner in place of its tick or
            // cross; the rest of the row stays put (Ken, 2026-11-11).
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (saving == (isGo ? 3 : 4))
                SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg))
              else
                Icon(isGo ? Icons.check : Icons.close, size: 18, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: V3.inter(17, weight: FontWeight.w700, color: fg)),
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
                          color: on ? FL.bg : FL.neon)),
                ),
              ],
            ]),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        button(true),
        const SizedBox(width: 8),
        button(false),
      ]),
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

    // Outlined tiles, big Bebas numbers: Attending neon with a glow, No
    // reply white, Declined red with a glow (Floodlights, Ken 2026-11-13).
    Widget tile(String label, int count, Color colour, Color edge, bool glow,
            String sub, int responseId) =>
        Expanded(
          child: GestureDetector(
            onTap: () => _openAttendees(responseId),
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
              decoration: FL.box(edge: edge),
              child: Column(children: [
                Text(label.toUpperCase(),
                    maxLines: 1, style: FL.caps(color: FL.sub, spacing: 1.4)),
                const SizedBox(height: 4),
                Text('$count',
                    style: FL.bebas(52,
                        color: colour,
                        height: 1,
                        glow: glow ? FL.glowOf(colour, .55, 18) : null)),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(sub,
                      textAlign: TextAlign.center,
                      style: V3.inter(12,
                          weight: FontWeight.w500,
                          color: FL.sub,
                          height: 1.55)),
                ],
              ]),
            ),
          ),
        );

    // Three tiles the same height, no bar underneath (Ken, 2026-11-08).
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        tile('Attending', a, FL.neon, FL.goEdge, true, aLines, 3),
        const SizedBox(width: 8),
        tile('No reply', n, const Color(0xFFE7E9EC), FL.line, false, nLines, 0),
        const SizedBox(width: 8),
        tile('Declined', d, FL.red, FL.noEdge, true, dLines, 4),
      ]),
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
    // Opposition and Home / Away sit in the opposition card on matches.
    final oppCard = _isMatch && e.opposition.trim().isNotEmpty;
    if (e.homeAway.isNotEmpty && !oppCard) {
      rows.add(_row('Home / Away', e.homeAway));
    }
    final type = [
      if (e.eventType.isNotEmpty) e.eventType,
      if (e.eventCode.isNotEmpty) e.eventCode,
    ].join(' · ');
    if (type.isNotEmpty) rows.add(_row('Type', type));
    if (e.opposition.isNotEmpty && !oppCard) {
      rows.add(_row('Opposition', e.opposition));
    }
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
              width: 96,
              child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(k.toUpperCase(), style: FL.caps(spacing: 1.4)))),
          Expanded(
              child: Text(v,
                  style: V3.inter(15,
                      color: onTap != null ? FL.neon : V3.text, height: 1.35))),
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
        decoration: FL.box(),
        child: Column(children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              decoration: BoxDecoration(
                  border: i == rows.length - 1
                      ? null
                      : const Border(bottom: BorderSide(color: FL.rowLine))),
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
    // Last-sent line under "Send reminder"; filled in when it loads.
    ReminderPreview? reminder;
    void Function(void Function())? refreshSheet;
    fetchReminderPreview(_eventId).then((p) {
      reminder = p;
      refreshSheet?.call(() {});
    }).catchError((_) {});
    showModalBottomSheet(
      context: context,
      backgroundColor: V3.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          refreshSheet = (f) {
            if (ctx.mounted) setSheet(f);
          };
          Widget item(IconData icon, String title, String sub,
              {VoidCallback? onTap,
              Widget? trailing,
              bool red = false,
              Color? subColor}) {
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
                          Text(sub,
                              style: V3.inter(13, color: subColor ?? V3.muted)),
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
                    _open(V3EventFormPage.editRouteName, {
                      'paramEventId': serializeParam(_eventId, ParamType.int),
                    });
                  }),
                  item(Icons.notifications_outlined, 'Send reminder',
                      reminderMenuLine(reminder, DateTime.now()),
                      subColor: reminder?.lastAt != null ? V3.amberText : null,
                      onTap: () async {
                    Navigator.pop(ctx);
                    V3Track.event('reminder_sheet_open');
                    final go = await showReminderSheet(context, _eventId,
                        preview: reminder);
                    if (go) _sendReminder();
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
                        'eventTitle':
                            serializeParam(cur.eventTitle, ParamType.String),
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
                        onTap: () {
                      Navigator.pop(ctx);
                      _cancelOrDelete(EventAction.cancel);
                    }),
                  item(Icons.delete_outline, 'Delete event', '', red: true,
                      onTap: () {
                    Navigator.pop(ctx);
                    _cancelOrDelete(EventAction.delete);
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

  /// Each tool's own colour (Club colours tool row, Ken 2026-11-13).
  Color get colour => switch (label) {
        'Score' => const Color(0xFFF5A524),
        'Live' => const Color(0xFFE5484D),
        'Stats' || 'View plan' => const Color(0xFF4C8DF6),
        'Report' => const Color(0xFFA78BFA),
        'Lineup' => const Color(0xFF2DD4BF),
        _ => const Color(0xFFF5A524), // Create / Edit plan
      };
}

// Full-screen webview for the tools that live on coachsmart.app.
