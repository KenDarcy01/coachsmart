// v3 Home. Same data as the FlutterFlow page (get_user_home_events), laid out
// as in /mnt/project-files/coachsmart/app-v3/home-design/CHOSEN-home.png.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/auth/supabase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '../v3_theme.dart';
import 'v3_event_card.dart';
import 'v3_home_data.dart';

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
  int _selectedClub = 0;
  int _selectedTeam = 0;
  final Set<int> _expanded = {};
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

  // Same start-up steps as the FlutterFlow page: register the push token,
  // record the platform, then load the home data.
  Future<void> _firstLoad() async {
    logFirebaseEvent('screen_view', parameters: {'screen_name': 'HomePage'});
    try {
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
    await _load();
    if (!mounted) return;
    final pendingEventId = await actions.checkAndNavigatePending();
    if (pendingEventId != '' && mounted) {
      context.pushNamed(NotificationsWidget.routeName);
    }
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
    setState(() {
      _failed = false;
      _loaded = true;
      _now = DateTime.now();
    });
  }

  UserEventsHomeStruct get _home => FFAppState().homePageEvents;

  List<ClubsStruct> get _realClubs =>
      _home.clubs.where((c) => c.clubId != 0).toList();

  List<UserTeamsStruct> get _teamsForSheet => _home.userTeams
      .where((t) =>
          t.teamId != 0 && (_selectedClub == 0 || t.clubId == _selectedClub))
      .toList();

  List<EventsStruct> get _events => _home.events
      .where((e) =>
          (_selectedClub == 0 || e.clubId == _selectedClub) &&
          (_selectedTeam == 0 || e.teamId == _selectedTeam) &&
          e.eventStatus != 'deleted')
      .toList();

  String _crestFor(int clubId) {
    for (final c in _home.clubs) {
      if (c.clubId == clubId) return c.crest;
    }
    return '';
  }

  bool _isCoachOn(EventsStruct e) => e.userHighestRoleOnTeam >= 30;

  // ---- actions -----------------------------------------------------------

  // One tap answers for every member of the user's on this event (Ken,
  // 2026-11-07: parents with two children reply once, then fix one on the
  // event page if needed). The home RPC carries one member per event, so
  // the event details RPC supplies the full list.
  Future<void> _reply(EventsStruct e, int responseId) async {
    if (e.memberId == 0) {
      _openEvent(e);
      return;
    }
    setState(() => _busy.add(e.eventId));
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
        await NotifyAdminsAttendanceChangeCall.call(
          supabaseJWTtoken: currentJwtToken,
          pMemberIdParam: memberId,
          pEventIdParam: e.eventId,
          pResponseId: responseId,
          pAttendanceId: row.attendanceId,
        );
      }
      await _load();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not save your reply. Please try again.',
                style: V3.inter(14, color: V3.bg)),
            backgroundColor: V3.amber));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy.remove(e.eventId);
          _expanded.remove(e.eventId);
        });
      }
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
    final url =
        'https://coachsmart.app/webviews/matches.html?token=$currentJwtToken';
    if (kIsWeb) {
      launchURL(url);
    } else {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => V3WebPage(title: 'Matches', url: url)));
    }
  }

  void _openResources() {
    if (_home.clubPathway) {
      context.pushNamed(
        ResourcesWidget.routeName,
        queryParameters: {
          'currentAuthToken': serializeParam(currentJwtToken, ParamType.String),
        }.withoutNulls,
      );
    } else {
      context.pushNamed(GamesAgesWidget.routeName);
    }
  }

  Future<void> _signOut() async {
    GoRouter.of(context).prepareAuthEvent();
    await authManager.signOut();
    GoRouter.of(context).clearRedirectLocation();
    if (mounted) context.goNamedAuth(AuthPageWidget.routeName, context.mounted);
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
        drawer: _drawer(role),
        appBar: AppBar(
          backgroundColor: V3.bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.menu, color: V3.green, size: 28),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          title: Text('Home', style: V3.tight(20)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: IconButton(
                onPressed: () =>
                    context.pushNamed(NotificationsWidget.routeName),
                icon: _home.unreadNotifications > 0
                    ? SizedBox(
                        width: 40,
                        height: 40,
                        child: custom_widgets.NotificationBadgeWidget(
                          width: 40,
                          height: 40,
                          iconColor: V3.green,
                          badgeColor: V3.red,
                          badgeTextColor: Colors.white,
                          iconSize: 28,
                        ),
                      )
                    : const Icon(Icons.notifications_sharp,
                        color: V3.green, size: 28),
              ),
            ),
          ],
        ),
        body: !_loaded
            ? const Center(child: CircularProgressIndicator(color: V3.green))
            : _failed
                ? _errorBody()
                : RefreshIndicator(
                    color: V3.green,
                    backgroundColor: V3.card,
                    onRefresh: _load,
                    child: _list(),
                  ),
        bottomNavigationBar: _loaded && !_failed ? _tabs(role) : null,
      ),
    );
  }

  Widget _errorBody() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("Couldn't load your events",
              style: V3.inter(18, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Check your connection and try again.',
              style: V3.inter(15, color: V3.muted)),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: _load,
              style: FilledButton.styleFrom(
                  backgroundColor: V3.green, foregroundColor: V3.bg),
              child: const Text('Retry')),
        ]),
      );

  Widget _list() {
    final events = _events;
    final groups = groupEvents(events, _now);

    final children = <Widget>[];
    if (_realClubs.length >= 2 || _teamsForSheet.length >= 2) {
      children.add(_filterRow());
    }
    if (_home.showAdvert) children.add(_advert());

    if (events.isEmpty) {
      children.add(_empty());
    }
    for (final g in groups) {
      children.add(_groupHeader(g));
      for (final e in g.events) {
        children.add(V3EventCard(
          event: e,
          now: _now,
          isNext: false, // no next-up highlight (Ken, 2026-11-07)
          isCoach: _isCoachOn(e),
          far: false,
          expanded: _expanded.contains(e.eventId),
          busy: _busy.contains(e.eventId),
          crestUrl: _crestFor(e.clubId),
          onTap: () => _openEvent(e),
          onReply: (r) => _reply(e, r),
          onExpand: () => setState(() => _expanded.add(e.eventId)),
        ));
      }
    }
    if (events.isNotEmpty && _selectedTeam != 0) {
      children.add(_endNote());
    }
    children.add(const SizedBox(height: 24));

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      children: children,
    );
  }

  Widget _groupHeader(EventGroup g) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              // White and larger so the day stands out (Ken, 2026-11-07).
              Text(g.label.toUpperCase(),
                  style: V3.tight(19, weight: FontWeight.w700, color: V3.text)),
              if (g.dateText.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(g.dateText,
                    style:
                        V3.inter(16, weight: FontWeight.w500, color: V3.text)),
              ],
            ]),
      );

  // Club crests (only with 2+ clubs) and the team filter button on the
  // right.
  // Crest row (only with 2+ clubs) and a row of team pills under it that
  // filter the list; tapping the selected pill clears the filter
  // (Ken, 2026-11-07, replacing the filter button and sheet).
  Widget _filterRow() {
    final clubs = _realClubs;
    final teams = _teamsForSheet;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (clubs.length >= 2)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _clubTile(0, null),
              for (final c in clubs) ...[
                const SizedBox(width: 12),
                _clubTile(c.clubId, c.crest),
              ],
            ]),
          ),
        ),
      if (teams.length >= 2)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (var i = 0; i < teams.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _teamPill(teams[i]),
              ],
            ]),
          ),
        ),
    ]);
  }

  Widget _teamPill(UserTeamsStruct t) {
    final on = _selectedTeam == t.teamId;
    return GestureDetector(
      onTap: () => setState(() => _selectedTeam = on ? 0 : t.teamId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? V3.green : V3.card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(t.teamName,
            style: V3.inter(14,
                weight: FontWeight.w600, color: on ? V3.bg : V3.text)),
      ),
    );
  }

  // Club crest 66px with a short green bar under the selected one, like
  // the v2 strip (Ken, 2026-11-06: no outline; 72 was too big, 52 too small).
  Widget _clubTile(int clubId, String? crest) {
    final on = _selectedClub == clubId;
    final img = crest == null
        ? Image.asset('assets/images/Launcher_Icon_v2.png', fit: BoxFit.contain)
        : Image.network(crest,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.shield_outlined, color: V3.muted, size: 40));
    return GestureDetector(
      onTap: () => setState(() {
        _selectedClub = on ? 0 : clubId;
        _selectedTeam = 0;
      }),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Opacity(
          opacity: on ? 1 : .5,
          child: SizedBox(width: 66, height: 66, child: img),
        ),
        const SizedBox(height: 6),
        Container(
          width: 38,
          height: 3,
          decoration: BoxDecoration(
            color: on ? V3.green : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ]),
    );
  }

  // The National Draw box from v2, as a quieter card. Still hard-coded;
  // v3 will make it a club setting.
  Widget _advert() => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
              color: V3.card, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: const Color(0xFF155B81),
                  borderRadius: BorderRadius.circular(10)),
              child: Text('GAA',
                  style: V3.tight(11,
                      weight: FontWeight.w800, color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('National Draw',
                        style: V3.inter(15, weight: FontWeight.w600)),
                    Text('Support your club',
                        style: V3.inter(13, color: V3.muted)),
                  ]),
            ),
            FilledButton(
              onPressed: () => launchURL(
                  'https://buy.stripe.com/00w9ATfp29iqe7N3Tmds404?client_reference_id=$currentUserUid'),
              style: FilledButton.styleFrom(
                  backgroundColor: V3.green,
                  foregroundColor: V3.bg,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: Text('Buy tickets',
                  style: V3.inter(14, weight: FontWeight.w600, color: V3.bg)),
            ),
          ]),
        ),
      );

  Widget _empty() => Padding(
        padding: const EdgeInsets.fromLTRB(30, 60, 30, 20),
        child: Column(children: [
          Text('Nothing coming up',
              style: V3.inter(18, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
              _selectedTeam != 0 || _selectedClub != 0
                  ? 'No upcoming events for this filter. Tap All teams to see everything.'
                  : 'New events from your teams will show up here.',
              textAlign: TextAlign.center,
              style: V3.inter(15, color: V3.muted, height: 1.5)),
        ]),
      );

  Widget _endNote() {
    String name = 'this team';
    for (final t in _home.userTeams) {
      if (t.teamId == _selectedTeam) name = t.teamName;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 30, 30, 10),
      child: Column(children: [
        Text("That's everything for $name",
            textAlign: TextAlign.center,
            style: V3.inter(18, weight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('Pull down to refresh, or tap the filter to see your other teams.',
            textAlign: TextAlign.center,
            style: V3.inter(15, color: V3.muted, height: 1.5)),
      ]),
    );
  }

  // ---- bottom tabs ---------------------------------------------------------

  Widget _tabs(int role) {
    final items = <_Tab>[
      _Tab('Home', Icons.home_rounded, null, active: true),
      _Tab('Matches', Icons.sports, _openMatches),
      if (_home.isGaaMember && role >= 30)
        _Tab('Resources', Icons.menu_book_rounded, _openResources),
      if (_home.isGaaMember && role >= 30)
        _Tab('Favourites', Icons.favorite,
            () => context.pushNamed(FavouritesNewWidget.routeName)),
      if (role >= 100)
        _Tab('Add event', Icons.add_circle,
            () => context.pushNamed(CreateEventWidget.routeName)),
    ];
    return Container(
      decoration: const BoxDecoration(
          color: V3.tabBar, border: Border(top: BorderSide(color: V3.line))),
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
                        Icon(t.icon,
                            size: 26, color: t.active ? V3.green : V3.muted),
                        const SizedBox(height: 4),
                        Text(t.label,
                            style: V3.inter(12,
                                weight: FontWeight.w500,
                                color: t.active ? V3.green : V3.muted)),
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
        child: ListView(padding: EdgeInsets.zero, children: [
          InkWell(
            onTap: () {
              Navigator.pop(context);
              context.pushNamed(
                EditUserWidget.routeName,
                queryParameters: {
                  'paramUserID':
                      serializeParam(currentUserUid, ParamType.String),
                }.withoutNulls,
              );
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_home.firstName} ${_home.lastName}',
                        style: V3.tight(22)),
                    const SizedBox(height: 4),
                    Text(_home.emailAddress,
                        style: V3.inter(14, color: V3.muted)),
                    const SizedBox(height: 8),
                    Text('Edit profile',
                        style: V3.inter(14,
                            weight: FontWeight.w600, color: V3.green)),
                  ]),
            ),
          ),
          const Divider(color: V3.line, height: 1),
          const SizedBox(height: 8),
          item(Icons.groups_sharp, 'Teams',
              () => context.pushNamed(TeamsWidget.routeName)),
          item(Icons.sports, 'Matches', _openMatches),
          if (role >= 30)
            item(Icons.search, 'Search events',
                () => context.pushNamed(SearchPageWidget.routeName)),
          if (role >= 30)
            item(
                Icons.auto_graph,
                'Analytics',
                () => context.pushNamed(
                      AnalyticsWidget.routeName,
                      queryParameters: {
                        'currentAuthToken':
                            serializeParam(currentJwtToken, ParamType.String),
                      }.withoutNulls,
                    )),
          item(Icons.logout, 'Sign out', _signOut),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text('v3 preview', style: V3.inter(14, color: V3.green)),
          ),
        ]),
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
class V3WebPage extends StatelessWidget {
  const V3WebPage({super.key, required this.title, required this.url});
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
