// v3 Home: the Timeline design in docs/design/home-v3/HOME-V3-DESIGN.md.
// Same data as the FlutterFlow page (get_user_home_events); a team chip bar
// over one rail of events with a day numeral per day and in-place replies.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/auth/supabase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '../notifications/v3_unread.dart';
import '../profile/v3_profile_models.dart' show PushPref;
import '../v3_crest_image.dart';
import '../v3_theme.dart';
import 'v3_home_data.dart';
import 'v3_team_chip.dart';
import 'v3_timeline_row.dart';
import '/v3/tracking/v3_track.dart';

class V3HomePage extends StatefulWidget {
  const V3HomePage({super.key});

  static String routeName = 'HomePage';
  static String routePath = 'homePage';

  @override
  State<V3HomePage> createState() => _V3HomePageState();
}

class _V3HomePageState extends State<V3HomePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _loaded = false;
  bool _failed = false;
  int _selectedTeam = 0; // persists while the app is open; All on cold start
  final Set<int> _busy = {};
  DateTime _now = DateTime.now();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _firstLoad());
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  // Same start-up steps as the FlutterFlow page, but the home data loads
  // first; the push token and platform updates run behind it so they
  // don't delay the list (Ken, 2026-11-07: first load felt slow).
  Future<void> _firstLoad() async {
    V3Track.screen('HomePage');
    unawaited(_registerDevice());
    await _load();
    if (!mounted) return;
    final pendingEventId = await actions.checkAndNavigatePending();
    if (pendingEventId != '' && mounted) {
      context.pushNamed(NotificationsWidget.routeName);
    }
  }

  Future<void> _registerDevice() async {
    try {
      // Push switched off on the profile page: keep the token cleared.
      if (!await PushPref.enabled()) return;
      await actions.setFCMToken();
      await UsersTable().update(
        data: {
          'fcm_token':
              FFAppState().fcmToken == 'Running on web. FCM setup skipped.'
                  ? ''
                  : FFAppState().fcmToken,
        },
        matchingRows: (rows) => rows.eqOrNull('user_id', currentUserUid),
      );
      await actions.updateUserPlatform();
    } catch (_) {}
  }

  Future<void> _load() async {
    final res = await GetUserHomeEventsCall.call(
      pUserId: currentUserUid,
      supabaseJWTtoken: currentJwtToken,
    );
    if (!mounted) return;
    if (!res.succeeded) {
      setState(() {
        _failed = true;
        _loaded = true;
      });
      return;
    }
    final data = UserEventsHomeStruct.maybeFromMap(res.jsonBody ?? '');
    if (data == null || data.userOnboarded != true) {
      context.pushNamed(OnBoardingWidget.routeName);
      return;
    }
    FFAppState().homePageEvents = data;
    FFAppState().notificationBadgeCount = data.unreadNotifications;
    // One count for the bell, the Notifications page and the app badge.
    V3Unread.instance
      ..start()
      ..set(data.unreadNotifications);
    precacheCrests(context, data.clubs.map((c) => c.crest));
    setState(() {
      _failed = false;
      _loaded = true;
      _now = DateTime.now();
    });
  }

  UserEventsHomeStruct get _home => FFAppState().homePageEvents;

  /// Chips in the order user_teams arrives, without the "All Teams" row.
  List<UserTeamsStruct> get _teams =>
      _home.userTeams.where((t) => t.teamId != 0).toList();

  List<EventsStruct> get _events => _home.events
      .where(
        (e) =>
            (_selectedTeam == 0 || e.teamId == _selectedTeam) &&
            e.eventStatus != 'deleted',
      )
      .toList();

  String _crestFor(int clubId) {
    for (final c in _home.clubs) {
      if (c.clubId == clubId) return c.crest;
    }
    return '';
  }

  String _clubNameFor(int clubId) {
    for (final c in _home.clubs) {
      if (c.clubId == clubId) return c.clubName;
    }
    return '';
  }

  bool _isCoachOn(EventsStruct e) => e.userHighestRoleOnTeam >= 30;

  // ---- actions -----------------------------------------------------------

  // One tap answers for every member of the user's on this event (Ken,
  // 2026-11-07: parents with two children reply once, then fix one on the
  // event page if needed). The home RPC carries one member per event, so
  // the event details RPC supplies the full list.
  //
  // The row updates in place straight away and is put back if the write
  // fails (design §5.8, §9); nothing reloads the whole list.
  Future<void> _reply(EventsStruct e, int responseId) async {
    if (e.memberId == 0) {
      _openEvent(e);
      return;
    }
    final before = (
      response: e.responseId,
      accepted: e.acceptedCount,
      declined: e.declinedCount,
      noReply: e.noResponseCount,
    );
    setState(() {
      _busy.add(e.eventId);
      e.responseId = responseId;
      e.noResponseCount = math.max(0, e.noResponseCount - 1);
      if (responseId == 3) e.acceptedCount = e.acceptedCount + 1;
      if (responseId == 4) e.declinedCount = e.declinedCount + 1;
    });
    try {
      var memberIds = <int>[e.memberId];
      try {
        final r = await GetUserEventDetailsCall.call(
          pEventId: e.eventId,
          pUserId: currentUserUid,
          supabaseJWTtoken: currentJwtToken,
        );
        final d = UserEventDetailsStruct.maybeFromMap(r.jsonBody);
        final ids = d?.teamMembers
                .where((m) => m.responseId != responseId)
                .map((m) => m.memberId)
                .toList() ??
            [];
        if (ids.isNotEmpty) memberIds = ids;
      } catch (_) {
        // Fall back to the one member the home list knows about.
      }
      for (final memberId in memberIds) {
        final row = await EventAttendanceTable().insert({
          'event_id': e.eventId,
          'member_id': memberId,
          'response_id': responseId,
        });
        V3Track.attendance(e.eventId, responseId, 'home');
        await NotifyAdminsAttendanceChangeCall.call(
          supabaseJWTtoken: currentJwtToken,
          pMemberIdParam: memberId,
          pEventIdParam: e.eventId,
          pResponseId: responseId,
          pAttendanceId: row.attendanceId,
        );
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          e.responseId = before.response;
          e.acceptedCount = before.accepted;
          e.declinedCount = before.declined;
          e.noResponseCount = before.noReply;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not save your reply. Please try again.',
              style: V3.inter(14, color: V3.bg),
            ),
            backgroundColor: V3.amber,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(e.eventId));
    }
  }

  Future<void> _openEvent(EventsStruct e) async {
    await context.pushNamed(
      EventDetailsWidget.routeName,
      queryParameters: {
        'eventID': serializeParam(e.eventId, ParamType.int),
        'fromSearch': serializeParam(false, ParamType.bool),
      }.withoutNulls,
    );
    if (mounted) _load(); // replies made on the event page
  }

  void _openMatches() {
    Navigator.of(context).push(MaterialPageRoute(
        settings: const RouteSettings(name: 'V3MatchesPage'),
        builder: (_) => const V3MatchesPage()));
  }

  // One Coaching tab (games and plans) replaces Resources and Favourites
  // (Ken, 2026-11-11). Every club gets the same games list.
  void _openCoaching() {
    Navigator.of(context).push(MaterialPageRoute(
        settings: const RouteSettings(name: 'V3Coaching'),
        builder: (_) => const V3Coaching()));
  }

  Future<void> _signOut() async {
    GoRouter.of(context).prepareAuthEvent();
    await authManager.signOut();
    GoRouter.of(context).clearRedirectLocation();
    if (mounted) context.goNamedAuth(V3SignInPage.routeName, context.mounted);
  }

  // ---- build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final role = _home.highestRoleLevel;
    final coach = role >= 30;
    return PopScope(
      canPop: false,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: V3.bg,
        drawer: _drawer(role),
        appBar: AppBar(
          backgroundColor: V3.bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          toolbarHeight: 56,
          leading: IconButton(
            icon: const Icon(Icons.menu, color: V3.green, size: 28),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          title: Text('Home', style: V3.inter(17, weight: FontWeight.w600)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: IconButton(
                onPressed: () async {
                  await context.pushNamed(NotificationsWidget.routeName);
                  if (mounted) _load();
                },
                // An 8 px green dot, not a number (design §5.1). Own widget
                // rather than NotificationBadgeWidget, whose tap handler
                // swallowed this one.
                icon: ValueListenableBuilder<int>(
                  valueListenable: V3Unread.instance.count,
                  builder: (context, n, _) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(
                        Icons.notifications_sharp,
                        color: V3.green,
                        size: 28,
                      ),
                      if (n > 0)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            key: const Key('v3-home-bell-dot'),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: V3.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: !_loaded
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Image.asset(
                        'assets/images/Launcher_Icon_v2.png',
                        width: 120,
                        height: 120,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: V3.green,
                      ),
                    ),
                  ],
                ),
              )
            : _failed
                ? _errorBody()
                : Column(
                    children: [
                      _chipBar(),
                      Expanded(
                        child: RefreshIndicator(
                          color: V3.green,
                          backgroundColor: V3.card,
                          onRefresh: _load,
                          child: _timeline(),
                        ),
                      ),
                    ],
                  ),
        // Parents get no bottom bar (design §5.10).
        bottomNavigationBar: _loaded && !_failed && coach ? _tabs(role) : null,
      ),
    );
  }

  Widget _errorBody() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Couldn't load your events",
              style: V3.inter(18, weight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              style: V3.inter(15, color: V3.muted),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _load,
              style: FilledButton.styleFrom(
                backgroundColor: V3.green,
                foregroundColor: V3.bg,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );

  // ---- team chips (design §5.2) -------------------------------------------

  Widget _chipBar() {
    final teams = _teams;
    return SizedBox(
      // Room above and below the chips (Ken, 2026-11-11: too tight).
      height: 68,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        children: [
          V3TeamChip(
            label: 'All',
            selected: _selectedTeam == 0,
            onTap: () => setState(() => _selectedTeam = 0),
          ),
          for (final t in teams) ...[
            const SizedBox(width: 8),
            V3TeamChip(
              label: t.teamName,
              crestUrl: _crestFor(t.clubId),
              clubName: _clubNameFor(t.clubId),
              selected: _selectedTeam == t.teamId,
              onTap: () => setState(() => _selectedTeam = t.teamId),
            ),
          ],
        ],
      ),
    );
  }

  // ---- timeline (design §5.3 to §6.8) -------------------------------------

  Widget _timeline() {
    final items = buildTimeline(_events, _now);
    final green = nextDay(items);
    final children = <Widget>[];
    if (_home.showAdvert) children.add(_advert());
    // A white "Events" heading separates the chips from the rail
    // (Ken, 2026-11-11).
    children.add(Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Text('Events', style: V3.tight(24, weight: FontWeight.w700)),
    ));
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.quiet) {
        children.add(V3QuietDayRow(day: item.day, firstRow: i == 0));
        continue;
      }
      final e = item.event!;
      children.add(
        V3TimelineRow(
          key: ValueKey('event-${e.eventId}'),
          item: item,
          now: _now,
          isCoach: _isCoachOn(e),
          busy: _busy.contains(e.eventId),
          firstRow: i == 0,
          nextDayGreen: green != null && item.day.isAtSameMomentAs(green),
          crestUrl: _crestFor(e.clubId),
          clubName: _clubNameFor(e.clubId),
          onTap: () => _openEvent(e),
          onReply: (r) => _reply(e, r),
        ),
      );
    }
    children.add(const SizedBox(height: 24));
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Narrow side margins: the event text needs the width (Ken, 2026-11-11).
      padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
      children: children,
    );
  }

  // The National Draw box from v2, as a quieter card. Still hard-coded;
  // v3 will make it a club setting.
  Widget _advert() => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: V3.card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF155B81),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'GAA',
                  style: V3.tight(11,
                      weight: FontWeight.w800, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'National Draw',
                      style: V3.inter(15, weight: FontWeight.w600),
                    ),
                    Text('Support your club',
                        style: V3.inter(13, color: V3.muted)),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () => launchURL(
                  'https://buy.stripe.com/00w9ATfp29iqe7N3Tmds404?client_reference_id=$currentUserUid',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: V3.green,
                  foregroundColor: V3.bg,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Buy tickets',
                  style: V3.inter(14, weight: FontWeight.w600, color: V3.bg),
                ),
              ),
            ],
          ),
        ),
      );

  // ---- bottom tabs ---------------------------------------------------------

  Widget _tabs(int role) {
    final items = <_Tab>[
      _Tab('Home', Icons.home_rounded, null, active: true),
      // Matches lives in the main menu for now; five tabs were too squashed
      // (Ken, 2026-11-09).
      if (_home.isGaaMember && role >= 30)
        _Tab('Coaching', Icons.menu_book_rounded, _openCoaching),
      if (role >= 100)
        _Tab('Add event', Icons.add_circle, () async {
          await context.pushNamed(V3EventFormPage.createRouteName);
          if (mounted) _load();
        }),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: V3.tabBar,
        border: Border(top: BorderSide(color: V3.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (final t in items)
                Expanded(
                  child: InkWell(
                    onTap: t.onTap,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          t.icon,
                          size: 26,
                          color: t.active ? V3.green : V3.muted,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.label,
                          style: V3.inter(
                            12,
                            weight: FontWeight.w500,
                            color: t.active ? V3.green : V3.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- drawer --------------------------------------------------------------

  Widget _drawer(int role) {
    Widget item(IconData icon, String label, VoidCallback onTap) => ListTile(
          leading: Icon(icon, color: V3.text, size: 28),
          title: Text(label, style: V3.tight(18, weight: FontWeight.w400)),
          onTap: () {
            Navigator.pop(context);
            onTap();
          },
        );
    return Drawer(
      backgroundColor: V3.bg,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            InkWell(
              onTap: () async {
                Navigator.pop(context);
                await context.pushNamed(EditUserWidget.routeName);
                if (mounted) _load();
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_home.firstName} ${_home.lastName}',
                      style: V3.tight(22),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _home.emailAddress,
                      style: V3.inter(14, color: V3.muted),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Profile and settings',
                      style: V3.inter(
                        14,
                        weight: FontWeight.w600,
                        color: V3.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(color: V3.line, height: 1),
            const SizedBox(height: 8),
            item(
              Icons.groups_sharp,
              'Teams',
              () => context.pushNamed(V3TeamsPage.routeName),
            ),
            item(Icons.sports, 'Matches', _openMatches),
            if (role >= 30)
              item(
                Icons.search,
                'Search events',
                () => context.pushNamed(SearchPageWidget.routeName),
              ),
            if (role >= 30)
              item(
                Icons.auto_graph,
                'Analytics',
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                      settings: const RouteSettings(name: 'V3AnalyticsPage'),
                      builder: (_) => const V3AnalyticsPage()),
                ),
              ),
            item(Icons.logout, 'Sign out', _signOut),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text('v3 preview', style: V3.inter(14, color: V3.green)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab {
  _Tab(this.label, this.icon, this.onTap, {this.active = false});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
}

/// A full-screen webview page (native only; on the web the URL opens in a tab).
