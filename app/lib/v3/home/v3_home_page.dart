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
import '../sponsors/v3_sponsors.dart';
import '../messages/v3_message_widgets.dart';
import '../messages/v3_messages_models.dart';
import '../messages/v3_messages_page.dart';
import '../lotto/v3_lotto_link.dart';
import '/v3/tracking/v3_track.dart';
import '../pitches/v3_pitch_api.dart';
import '../clubs/v3_club_home.dart';
import '../clubs/v3_follow_api.dart';
import '../clubs/v3_follow_club_page.dart';
import '../matches/v3_matches_models.dart';

class V3HomePage extends StatefulWidget {
  const V3HomePage({super.key});

  static String routeName = 'HomePage';
  static String routePath = 'homePage';

  @override
  State<V3HomePage> createState() => _V3HomePageState();
}

class _V3HomePageState extends State<V3HomePage> with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _loaded = false;
  bool _failed = false;
  int _selectedTeam = 0; // persists while the app is open; All on cold start
  final Set<int> _busy = {};
  DateTime _now = DateTime.now();
  Timer? _tick;

  // Important pop-ups and the news bar (Ken, 2026-11-14).
  static const _messagesApi = MessagesApi();
  MyMessages _msgs = const MyMessages();

  /// Clubs whose pitch planner this officer can open (officers with the
  /// Pitch planner tick only, Ken 2026-11-25); empty hides the menu item.
  List<int> _pitchClubs = const [];

  /// Officer with the Messages tick for at least one club.
  bool _canMessage = false;

  /// The pitch planner club: one of the user's own clubs first (a
  /// SuperUser can plan for every club).
  int? get _pitchClub {
    if (_pitchClubs.isEmpty) return null;
    final mine = {for (final c in _home.clubs) c.clubId};
    return _pitchClubs.firstWhere(mine.contains,
        orElse: () => _pitchClubs.first);
  }

  bool _popupOpen = false;

  // Club followers (Ken, 2026-11-26): clubs followed with a club code, and
  // whether this user is on no team at all (Home is then the club home).
  static const _followApi = FollowApi();
  List<FollowedClub> _followed = const [];
  bool _followerOnly = false;
  LiveMatchesData? _clubMatches;
  int _selectedClub = 0;

  // Home (club) and Events tabs (Ken, 2026-11-26): team members land on
  // Events; Home is the club screen, with a badge for club news and
  // fundraisers not seen yet.
  bool _clubTab = false;

  bool get _onClubScreen => _followerOnly || _clubTab;

  /// Clubs on ClubSmart the user is on a team in or follows
  /// (get_my_home_clubs). A club with only teams on CoachSmart is left out
  /// (Ken, 2026-11-26).
  List<FollowedClub> _homeClubs = const [];
  List<FollowedClub> get _myClubs => _homeClubs;

  /// No ClubSmart club: no Home (club) tab, and Events keeps the club news,
  /// fundraisers and partner as before.
  bool get _hasClubTab => _homeClubs.isNotEmpty;

  int get _clubBadge =>
      [..._msgs.news, ..._msgs.fundraisers].where((m) => !m.seen).length;

  void _markClubSeen() {
    final unseen = [
      for (final m in [..._msgs.news, ..._msgs.fundraisers])
        if (!m.seen) m
    ];
    if (unseen.isEmpty) return;
    for (final m in unseen) {
      m.seen = true;
    }
    unawaited(_messagesApi
        .markSeen([for (final m in unseen) m.id]).catchError((_) {}));
  }

  void _openClubTab() {
    if (_clubTab) return;
    V3Track.event('club_tab_opened', {'badge': _clubBadge});
    setState(() => _clubTab = true);
    if (_clubMatches == null) unawaited(_loadClubMatches());
    // Seen once Home is open: the badge clears and stays cleared.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _clubTab) setState(_markClubSeen);
    });
  }

  void _openEventsTab() {
    if (_clubTab) setState(() => _clubTab = false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
      if (_onClubScreen && (_clubMatches?.live.isNotEmpty ?? false)) {
        _loadClubMatches();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _firstLoad());
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPitchAccess());
    V3Sponsors.notifier.addListener(_sponsorsChanged);
    V3Sponsors.load();
  }

  void _sponsorsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPitchAccess() async {
    try {
      const api = PitchApi();
      final t = await api.myClubTools();
      List<int> ids(dynamic v) => [
            if (v is List)
              for (final x in v)
                if (x is num) x.toInt()
          ];
      MessagesAccess.sendEveryone = t['send_everyone'] == true;
      if (mounted) {
        setState(() {
          _pitchClubs = ids(t['pitch_clubs']);
          _canMessage = ids(t['message_clubs']).isNotEmpty;
        });
      }
    } catch (_) {
      // No club tools for this user.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    V3Sponsors.notifier.removeListener(_sponsorsChanged);
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
    await _loadMessages(popUp: true);
    if (!mounted) return;
    final pendingEventId = await actions.checkAndNavigatePending();
    if (pendingEventId != '' && mounted) {
      context.pushNamed(NotificationsWidget.routeName);
    }
  }

  // Back in the app from the background counts as opening it: unread
  // important messages pop up again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _loaded && !_failed) {
      _loadMessages(popUp: true);
    }
  }

  Future<void> _loadMessages({bool popUp = false}) async {
    try {
      final m = await _messagesApi.mine();
      if (!mounted) return;
      setState(() {
        _msgs = m;
        if (_clubTab) _markClubSeen();
      });
      // Lotto links open already signed in; get the codes ready now.
      V3LottoLink.prefetch(
          [...m.fundraisers, ...m.news, ...m.important].map((x) => x.linkUrl));
      if (popUp && m.important.isNotEmpty && !_popupOpen) {
        _popupOpen = true;
        await showImportantMessages(context, m.important, _messagesApi);
        _popupOpen = false;
        if (mounted)
          setState(() => _msgs = MyMessages(
              news: _msgs.news,
              fundraisers: _msgs.fundraisers,
              pinned: _msgs.pinned,
              isSuperUser: _msgs.isSuperUser));
      }
    } catch (_) {
      // No messages is fine; Home works without them.
    }
  }

  Future<void> _refresh() async {
    await _load();
    await _loadMessages();
    await V3Sponsors.load(force: true);
    if (_onClubScreen) await _loadClubMatches();
  }

  void _openFundraiser(AppMessage m) {
    V3Track.event('fundraiser_tap');
    unawaited(_messagesApi.tap(m.id).catchError((_) {}));
    V3LottoLink.open(m.linkUrl);
  }

  Future<void> _openNews() async {
    V3Track.event('news_opened');
    await showNewsSheet(context, _msgs.news, _messagesApi);
    if (mounted) setState(() {});
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
    var followed = const <FollowedClub>[];
    try {
      followed = await _followApi.myClubs();
    } catch (_) {}
    if (!mounted) return;
    // No team: onboarding, unless the user follows a club (2026-11-26).
    final onTeam = data != null && data.userOnboarded == true;
    if (data == null || (!onTeam && followed.isEmpty)) {
      context.pushNamed(OnBoardingWidget.routeName);
      return;
    }
    var homeClubs = const <FollowedClub>[];
    if (onTeam) {
      try {
        homeClubs = await _followApi.homeClubs();
      } catch (_) {}
      if (!mounted) return;
    }
    _followed = followed;
    _homeClubs = homeClubs;
    _followerOnly = !onTeam;
    if (_followerOnly || !_hasClubTab) _clubTab = false;
    if (_selectedClub != 0 && !_myClubs.any((c) => c.clubId == _selectedClub)) {
      _selectedClub = 0;
    }
    if (_followerOnly) {
      unawaited(_loadClubMatches());
      precacheCrests(context, followed.map((c) => c.crest));
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

  Future<void> _loadClubMatches() async {
    try {
      final r = await SupaFlow.client
          .rpc('get_live_matches', params: {'p_upcoming_days': 14});
      if (!mounted) return;
      setState(() =>
          _clubMatches = LiveMatchesData.fromJson(r is Map ? r : const {}));
    } catch (_) {
      if (mounted && _clubMatches == null) {
        setState(() => _clubMatches = LiveMatchesData.fromJson(const {}));
      }
    }
  }

  Future<void> _openClubMatch(LiveMatchRow m) async {
    await Navigator.of(context).push(MaterialPageRoute(
        settings: const RouteSettings(name: 'V3MatchLivePage'),
        builder: (_) =>
            V3MatchLivePage(eventId: m.eventId, squad: m.squadKey)));
    if (mounted) _loadClubMatches();
  }

  Future<void> _openJoinTeam() async {
    await Navigator.of(context).push(MaterialPageRoute(
        settings: const RouteSettings(name: 'V3JoinTeamPage'),
        builder: (_) => const V3JoinTeamPage()));
    if (mounted) _load();
  }

  Future<void> _openFollowClub() async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
        settings: const RouteSettings(name: 'V3FollowClubPage'),
        builder: (_) => const V3FollowClubPage()));
    if (changed == true && mounted) await _refresh();
  }

  Future<void> _confirmUnfollow(FollowedClub c) async {
    final go = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: V3.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            V3CrestImage(c.crest, size: 52),
            const SizedBox(height: 10),
            Text('Stop following ${c.name}?',
                textAlign: TextAlign.center,
                style: V3.tight(20, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text("You can follow it again with the club's code.",
                textAlign: TextAlign.center,
                style: V3.inter(15, color: V3.muted)),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                    backgroundColor: V3.red, foregroundColor: Colors.white),
                child: Text('Unfollow',
                    style: V3.inter(16,
                        weight: FontWeight.w700, color: Colors.white)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(minimumSize: const Size(44, 48)),
              child: Text('Cancel', style: V3.inter(16, color: V3.muted)),
            ),
          ]),
        ),
      ),
    );
    if (go != true || !mounted) return;
    try {
      await _followApi.unfollow(c.clubId);
      V3Track.event('club_unfollowed', {'club_id': c.clubId});
    } catch (_) {}
    if (mounted) await _refresh();
  }

  String get _greetingLine {
    final h = _now.hour;
    final part = h < 12 ? 'morning' : (h < 18 ? 'afternoon' : 'evening');
    final name = _home.firstName.trim();
    return name.isEmpty ? 'Good $part' : 'Good $part, $name';
  }

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
    return PopScope(
      canPop: false,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: V3.bg,
        // The floating menu pill sits over the events (2026-11-18).
        extendBody: true,
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
          // Just the CS mark in place of "Home" (Ken, 2026-11-12: logo
          // only, no wordmark).
          title: Image.asset('assets/images/cs_mark.png',
              height: 26, semanticLabel: 'CoachSmart'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: IconButton(
                onPressed: () async {
                  await context.pushNamed(NotificationsWidget.routeName);
                  if (mounted) _load();
                },
                // Red badge with the unread count, as in v2 (Ken,
                // 2026-11-11; the design's green dot was dropped). Own
                // widget rather than NotificationBadgeWidget, whose tap
                // handler swallowed this one.
                icon: ValueListenableBuilder<int>(
                  valueListenable: V3Unread.instance.count,
                  builder: (context, n, _) => n > 0
                      ? Badge(
                          label: Text(n > 99 ? '99+' : '$n',
                              style: V3.inter(12,
                                  weight: FontWeight.w700,
                                  color: Colors.white)),
                          backgroundColor: V3.red,
                          offset: const Offset(4, -4),
                          child: const Icon(Icons.notifications_sharp,
                              color: V3.green, size: 28),
                        )
                      : const Icon(Icons.notifications_sharp,
                          color: V3.green, size: 28),
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
                // The greeting scrolls away with the events; the team chips
                // stay pinned at the top (Ken, 2026-11-12: no fixed panel).
                : RefreshIndicator(
                    color: V3.green,
                    backgroundColor: V3.card,
                    onRefresh: _refresh,
                    // Builder: only a context inside the Scaffold sees the
                    // menu pill's height in its bottom padding.
                    child: Builder(
                      builder: (c) => _onClubScreen
                          ? _clubHome(MediaQuery.paddingOf(c).bottom)
                          : _timeline(MediaQuery.paddingOf(c).bottom),
                    ),
                  ),
        // Everyone on a team gets Home (club) and Events (Ken, 2026-11-26);
        // followers on no team have only the club screen, so no bar.
        bottomNavigationBar:
            _loaded && !_failed && !_followerOnly && (_hasClubTab || role >= 30)
                ? _tabs(role)
                : null,
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

  // ---- greeting (option B, Ken 2026-11-12) ---------------------------------

  /// Events today, and events from tomorrow to the end of this week
  /// (Monday to Sunday), not cancelled or deleted, across all teams.
  (int, int) get _todayAndRestOfWeek {
    final today = DateTime(_now.year, _now.month, _now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekEnd = today.add(Duration(days: 8 - today.weekday));
    var todayN = 0, restN = 0;
    for (final e in _home.events) {
      if (e.eventStatus == 'deleted' || isCancelled(e)) continue;
      final t = eventLocalTime(e);
      if (t == null || t.isBefore(today) || !t.isBefore(weekEnd)) continue;
      if (t.isBefore(tomorrow)) {
        todayN++;
      } else {
        restN++;
      }
    }
    return (todayN, restN);
  }

  /// Upcoming events still waiting for this user's answer, all teams.
  int get _toReply => _home.events
      .where((e) => e.eventStatus != 'deleted' && needsReply(e))
      .length;

  Widget _greeting() {
    final h = _now.hour;
    final part = h < 12 ? 'morning' : (h < 18 ? 'afternoon' : 'evening');
    final name = _home.firstName.trim();
    final (todayN, restN) = _todayAndRestOfWeek;
    final String week;
    if (todayN == 0 && restN == 0) {
      week = 'Nothing on this week';
    } else {
      final today = todayN == 0
          ? 'Nothing today'
          : (todayN == 1 ? '1 event today' : '$todayN events today');
      week = restN == 0
          ? '$today · no more this week'
          : '$today · $restN more this week';
    }
    final toReply = _toReply;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name.isEmpty ? 'Good $part' : 'Good $part, $name',
            style: V3.tight(26, weight: FontWeight.w700, height: 1.15),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('EEEE d MMMM').format(_now),
            style: V3.inter(15, color: const Color(0xFFA1A1A2)),
          ),
          const SizedBox(height: 2),
          // Today's count, then what is left this week (Ken, 2026-11-12).
          Text(week, style: V3.inter(15, weight: FontWeight.w600)),
          // How many still need an answer, or "all up to date" when none
          // do (Ken, 2026-11-12).
          const SizedBox(height: 2),
          Text(
            toReply == 0
                ? "You're all up to date"
                : (toReply == 1
                    ? '1 event to reply to'
                    : '$toReply events to reply to'),
            style: V3.inter(15, weight: FontWeight.w600, color: V3.green),
          ),
        ],
      ),
    );
  }

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
              // Tapping the selected chip clears back to All (Ken, 2026-11-11).
              onTap: () => setState(() =>
                  _selectedTeam = _selectedTeam == t.teamId ? 0 : t.teamId),
            ),
          ],
        ],
      ),
    );
  }

  // ---- club home for followers on no team (2026-11-26) --------------------

  Widget _clubHome(double bottomInset) => V3ClubHome(
        clubs: _followerOnly ? _followed : _myClubs,
        matches: _clubMatches,
        selectedClub: _selectedClub,
        onSelectClub: (id) => setState(() => _selectedClub = id),
        greeting: _greetingLine,
        now: _now,
        bottomInset: bottomInset,
        onOpenMatch: _openClubMatch,
        onOpenMatches: _openMatches,
        onJoinTeam: _followerOnly ? _openJoinTeam : null,
        topCards: [
          // Important messages stay here until they end (Ken, 2026-11-26).
          for (final m in _msgs.pinned)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: V3PinnedImportant(m, key: ValueKey('pinned-${m.id}')),
            ),
          if (_msgs.news.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: V3NewsCards(
                  news: _msgs.news, onTap: _openNews, stacked: true),
            ),
          if (_msgs.fundraisers.isNotEmpty)
            V3FundraiserRow(items: _msgs.fundraisers, onTap: _openFundraiser),
        ],
      );

  // ---- timeline (design §5.3 to §6.8) -------------------------------------

  Widget _timeline(double bottomInset) {
    final items = buildTimeline(_events, _now);
    final green = nextDay(items);
    final children = <Widget>[];
    // Club news, fundraisers and the club partner live on Home (club) now;
    // Events is just the user's events (Ken, 2026-11-26). Without a
    // ClubSmart club there is no Home tab, so they stay here.
    if (!_hasClubTab) {
      if (_msgs.news.isNotEmpty) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: V3NewsCards(news: _msgs.news, onTap: _openNews),
        ));
      }
      if (_msgs.fundraisers.isNotEmpty) {
        children.add(
            V3FundraiserRow(items: _msgs.fundraisers, onTap: _openFundraiser));
      }
      final team = _selectedTeam == 0 ? null : _selectedTeam;
      final sponsor = V3Sponsors.forHome(team);
      if (sponsor != null) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: V3SponsorCard(
              key: ValueKey('sponsor-${sponsor.id}-${team ?? 0}'),
              sponsor: sponsor,
              place: V3SponsorPlace.home,
              teamId: team),
        ));
      }
    }
    // The greeting above the chips now heads the page; the "Events" title
    // went with option B (Ken, 2026-11-12).
    children.add(const SizedBox(height: 6));
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
    // Room for the floating menu pill: extendBody passes its height on as
    // bottom padding to contexts inside the Scaffold (Ken, 2026-11-23: the
    // last card sat behind the pill).
    children.add(SizedBox(height: 24 + bottomInset));
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Centred as in the version Ken picked (2026-11-12 06:44).
        SliverToBoxAdapter(child: Center(child: _greeting())),
        SliverPersistentHeader(
          pinned: true,
          delegate: _PinnedChips(_chipBar()),
        ),
        SliverPadding(
          // Narrow side margins: the event text needs the width (Ken,
          // 2026-11-11).
          padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
          sliver: SliverList(delegate: SliverChildListDelegate(children)),
        ),
      ],
    );
  }

  // ---- bottom tabs ---------------------------------------------------------

  // Floating pill menu in the Strava style (Ken picked mock B, 2026-11-18,
  // app-v3/home-menu-pill/): Home and Coaching sit in a rounded, slightly
  // see-through pill, the open tab in its own darker pill; Add event is a
  // round green + beside it, since it is an action rather than a page.
  // The Scaffold uses extendBody so the events scroll behind the pill.
  Widget _tabs(int role) {
    final items = <_Tab>[
      if (_hasClubTab)
        _Tab('Home', Icons.shield_rounded, _openClubTab,
            active: _clubTab, badge: _clubTab ? 0 : _clubBadge),
      _Tab('Events', Icons.calendar_month_rounded, _openEventsTab,
          active: !_clubTab),
      // Matches lives in the main menu for now; five tabs were too squashed
      // (Ken, 2026-11-09).
      if (_home.isGaaMember && role >= 30)
        _Tab('Coaching', Icons.menu_book_rounded, _openCoaching),
    ];
    final canAdd = role >= 100;
    const shadow = [
      BoxShadow(color: Color(0x8C000000), blurRadius: 28, offset: Offset(0, 8)),
    ];
    return DecoratedBox(
      // Fades the events out under the pill so it never sits on a hard edge.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x0014181B), Color(0xD914181B)],
          stops: [0, 0.55],
        ),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 64,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xE61E222B),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: const Color(0x12FFFFFF)),
                    boxShadow: shadow,
                  ),
                  child: Row(
                    children: [
                      for (final t in items)
                        Expanded(
                          child: Material(
                            color: t.active ? V3.tabBar : Colors.transparent,
                            shape: StadiumBorder(
                              side: t.active
                                  ? const BorderSide(color: Color(0x2E87C232))
                                  : BorderSide.none,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: t.onTap,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Badge(
                                    isLabelVisible: t.badge > 0,
                                    label: Text(
                                        t.badge > 9 ? '9+' : '${t.badge}',
                                        style: V3.inter(11,
                                            weight: FontWeight.w700,
                                            color: Colors.white)),
                                    backgroundColor: V3.red,
                                    offset: const Offset(8, -6),
                                    child: Icon(
                                      t.icon,
                                      size: 24,
                                      color: t.active ? V3.green : V3.text,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    t.label,
                                    style: V3.inter(
                                      12,
                                      weight: FontWeight.w600,
                                      color: t.active ? V3.green : V3.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (canAdd) ...[
                const SizedBox(width: 10),
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: shadow,
                  ),
                  child: Material(
                    color: V3.green,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () async {
                        await context
                            .pushNamed(V3EventFormPage.createRouteName);
                        if (mounted) _load();
                      },
                      child: Semantics(
                        button: true,
                        label: 'Add event',
                        child: const Icon(Icons.add_rounded,
                            size: 34, color: V3.bg),
                      ),
                    ),
                  ),
                ),
              ],
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
            if (!_followerOnly)
              item(
                Icons.groups_sharp,
                'Teams',
                () => context.pushNamed(V3TeamsPage.routeName),
              ),
            item(Icons.sports, 'Matches', _openMatches),
            if (_followerOnly)
              item(Icons.group_add_outlined, 'Join a team', _openJoinTeam),
            // My clubs (2026-11-26): clubs followed with a club code; tap
            // one to stop following it.
            if (_followed.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text('MY CLUBS',
                    style: V3.inter(12,
                        weight: FontWeight.w700,
                        color: V3.muted,
                        letterSpacing: 1.2)),
              ),
              for (final c in _followed)
                ListTile(
                  leading: V3CrestImage(c.crest,
                      size: 30,
                      fallback: const Icon(Icons.shield_outlined,
                          color: V3.text, size: 28)),
                  title: Text(c.name,
                      style: V3.tight(18, weight: FontWeight.w400)),
                  trailing:
                      Text('Following', style: V3.inter(13, color: V3.muted)),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmUnfollow(c);
                  },
                ),
            ],
            item(
                Icons.add_circle_outline,
                _followed.isEmpty ? 'Follow a club' : 'Follow another club',
                _openFollowClub),
            const Divider(color: V3.line, height: 17),

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
            if (_pitchClub != null)
              item(
                Icons.grid_view,
                'Pitches',
                () => context.pushNamed(V3PitchesPage.routeName,
                    queryParameters: {'club': '$_pitchClub'}),
              ),
            if (_canMessage)
              item(
                Icons.campaign_outlined,
                'Messages',
                () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                      settings: const RouteSettings(name: 'V3MessagesPage'),
                      builder: (_) => const V3MessagesPage()));
                  if (mounted) _loadMessages(popUp: true);
                },
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
  _Tab(this.label, this.icon, this.onTap,
      {this.active = false, this.badge = 0});
  final int badge;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
}

/// A full-screen webview page (native only; on the web the URL opens in a tab).

/// Keeps the team chips pinned under the app bar while the greeting and
/// events scroll.
class _PinnedChips extends SliverPersistentHeaderDelegate {
  _PinnedChips(this.child);
  final Widget child;

  @override
  double get minExtent => 68;
  @override
  double get maxExtent => 68;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      ColoredBox(color: V3.bg, child: child);

  @override
  bool shouldRebuild(_PinnedChips old) => true;
}
