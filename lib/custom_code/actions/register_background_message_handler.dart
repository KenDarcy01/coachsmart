// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'index.dart'; // Imports other custom actions

import '/backend/api_requests/api_calls.dart';
import 'index.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

// ---------------------------------------------------------------------------
// DEBUG LOGGER
// ---------------------------------------------------------------------------

const String _tag = '[NotifHandler]';
int _bannerInstanceCount = 0;

void _log(String msg) => print('$_tag ✅ $msg');
void _logWarn(String msg) => print('$_tag ⚠️  $msg');
void _logError(String msg, [Object? e]) =>
    print('$_tag 🔴 $msg${e != null ? ' | error: $e' : ''}');
void _logStep(String step, String detail) => print('$_tag ▶ [$step] $detail');

void _logBannerState(
  String location,
  int instanceId, {
  required bool mounted,
  required bool ctrlNull,
  required bool slideNull,
  required bool fadeNull,
  required bool dismissing,
  required double dragOffset,
}) {
  print(
    '$_tag 🔍 [BannerState @ $location] '
    'instance=#$instanceId | '
    'mounted=$mounted | '
    'ctrl=${ctrlNull ? "NULL" : "ok"} | '
    'slide=${slideNull ? "NULL" : "ok"} | '
    'fade=${fadeNull ? "NULL" : "ok"} | '
    'dismissing=$dismissing | '
    'dragOffset=$dragOffset',
  );
}

// ---------------------------------------------------------------------------
// 1. LIFECYCLE
// ---------------------------------------------------------------------------

class _CooldownManager {
  static bool isActive = true;

  static void activate() {
    isActive = true;
    _logStep('Cooldown', 'Activated — popups suppressed for 2s');
    Future.delayed(const Duration(seconds: 2), () {
      isActive = false;
      _logStep('Cooldown', 'Expired — popups now enabled');
    });
  }
}

class _LifecycleWatcher extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _logStep('Lifecycle', 'App state → ${state.name}');
    if (state == AppLifecycleState.resumed) {
      _CooldownManager.activate();
      _refreshNavigatorContext();
    }
  }
}

// ---------------------------------------------------------------------------
// NAVIGATOR CONTEXT + STATE
//
// _navigatorContext (BuildContext): the Navigator widget's element.
//   Used for GoRouter navigation — context.pushNamed(queryParameters:...)
//   is a GoRouter extension on BuildContext that works from this element.
//
// _navigatorState (NavigatorState): derived from the same element.
//   Used for overlay resolution — navigatorState.overlay is the overlay
//   the navigator itself manages. Overlay.of(navigatorElement) looks UP
//   the tree for an ancestor Overlay; for the root navigator nothing is
//   above it, so that call always throws/returns null. Using .overlay
//   directly is the correct approach.
// ---------------------------------------------------------------------------

BuildContext? _navigatorContext;
NavigatorState? _navigatorState;

void _refreshNavigatorContext() {
  try {
    final Element? root = WidgetsBinding.instance.rootElement;
    if (root != null) {
      Element? found;
      void visitor(Element element) {
        if (found != null) return;
        if (element.widget is Navigator) {
          found = element;
        }
        element.visitChildren(visitor);
      }

      root.visitChildren(visitor);
      if (found != null) {
        // Assign to non-closure-captured locals so Dart can smart-cast them.
        final el = found!;
        _navigatorContext = el;
        if (el is StatefulElement && el.state is NavigatorState) {
          _navigatorState = el.state as NavigatorState;
        }
        _logStep(
            'NavContext',
            'Navigator refreshed ✓ | '
                'navigatorStateMounted=${_navigatorState?.mounted}');
      } else {
        _logWarn('NavContext — Navigator not found during refresh');
      }
    }
  } catch (e) {
    _logError('Navigator context refresh threw', e);
  }
}

void _initLifecycle() {
  _logStep('Lifecycle', 'Registering watcher');
  _CooldownManager.activate();
  WidgetsBinding.instance.addObserver(_LifecycleWatcher());
  _log('Lifecycle watcher registered');
}

// ---------------------------------------------------------------------------
// 2. FIREBASE
// ---------------------------------------------------------------------------

Future<void> _initFirebase() async {
  if (kIsWeb) {
    _logWarn('Firebase skipped — running on web');
    return;
  }
  _logStep('Firebase', 'Initialising...');
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
      _log('Firebase initialised ✓');
    } else {
      _log('Firebase already initialised — skipping');
    }
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _logStep('FCM', 'Token refreshed → ${newToken.substring(0, 16)}...');
      FFAppState().fcmToken = newToken;
    });
    _log('FCM token refresh listener attached ✓');
  } catch (e) {
    _logError('Firebase init failed', e);
  }
}

// ---------------------------------------------------------------------------
// 3. MARK READ HELPER
// ---------------------------------------------------------------------------

Future<void> _markNotificationRead(
  SupabaseClient supabase,
  String notificationId,
) async {
  _logStep('MarkRead', 'Marking notification $notificationId as read...');
  try {
    await supabase.from('notifications').update({
      'is_read': true,
      'when_read': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', notificationId);
    _log('Notification $notificationId marked is_read=true ✓');
  } catch (e) {
    _logError('Failed to mark notification $notificationId as read', e);
  }
}

// ---------------------------------------------------------------------------
// 4. NAVIGATION HELPERS
//
// routeName = 'EventDetails' (capital E) — from EventDetailsWidget:
//   static String routeName = 'EventDetails';
//   static String routePath = 'eventDetails';
//
// pushNamed uses routeName not routePath.
// ---------------------------------------------------------------------------

Future<void> _navigateFromPushLink(String linkPage) async {
  if (linkPage.isEmpty) {
    _logWarn('navigateFromPushLink — linkPage is empty, skipping');
    return;
  }
  _logStep('Navigate', 'Push link: $linkPage');

  if (kIsWeb) {
    final String webUrl = linkPage.startsWith('coachsmartv2://coachsmartv2.com')
        ? linkPage.replaceFirst(
            'coachsmartv2://coachsmartv2.com',
            'https://my.coachsmart.app',
          )
        : linkPage;
    _logStep('Navigate', 'Web — launching: $webUrl');
    try {
      final Uri uri = Uri.parse(webUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        _log('Web push navigation launched ✓');
      } else {
        _logError('canLaunchUrl returned false for: $webUrl');
      }
    } catch (e) {
      _logError('Web push navigation threw', e);
    }
    return;
  }

  try {
    final Uri uri = Uri.parse(linkPage);
    final String? eventIdStr = uri.queryParameters['eventID'];
    final int? eventId = eventIdStr != null ? int.tryParse(eventIdStr) : null;
    _logStep('Navigate', 'Parsed — path=${uri.path} | eventId=$eventId');
    if (eventId == null) {
      _logError('Could not parse eventID from push link: $linkPage');
      return;
    }
    _refreshNavigatorContext();
    if (_navigatorContext == null || !_navigatorContext!.mounted) {
      _logError('Navigator context not available for push navigation');
      return;
    }
    _navigatorContext!.pushNamed(
      'EventDetails',
      queryParameters: {
        'eventID': eventId.toString(),
        'fromSearch': 'false',
      },
    );
    _log('Push navigated to EventDetails with eventId=$eventId ✓');
  } catch (e) {
    _logError('Native push navigation threw', e);
  }
}

Future<void> _navigateFromBannerLink(String linkPage) async {
  if (linkPage.isEmpty) {
    _logWarn('navigateFromBannerLink — linkPage is empty, skipping');
    return;
  }
  _logStep('BannerNav', 'Banner link: $linkPage');

  if (kIsWeb) {
    final String webUrl = linkPage.startsWith('coachsmartv2://coachsmartv2.com')
        ? linkPage.replaceFirst(
            'coachsmartv2://coachsmartv2.com',
            'https://my.coachsmart.app',
          )
        : linkPage;
    _logStep('BannerNav', 'Web — launching: $webUrl');
    try {
      final Uri uri = Uri.parse(webUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        _log('Web banner navigation launched ✓');
      } else {
        _logError('canLaunchUrl returned false for: $webUrl');
      }
    } catch (e) {
      _logError('Web banner navigation threw', e);
    }
    return;
  }

  try {
    final Uri uri = Uri.parse(linkPage);
    final String? eventIdStr = uri.queryParameters['eventID'];
    final int? eventId = eventIdStr != null ? int.tryParse(eventIdStr) : null;
    _logStep('BannerNav', 'Parsed — path=${uri.path} | eventId=$eventId');
    if (eventId == null) {
      _logError('Could not parse eventID from banner link: $linkPage');
      return;
    }
    _refreshNavigatorContext();
    if (_navigatorContext == null || !_navigatorContext!.mounted) {
      _logError('Navigator context not available for banner navigation');
      return;
    }
    _navigatorContext!.pushNamed(
      'EventDetails',
      queryParameters: {
        'eventID': eventId.toString(),
        'fromSearch': 'false',
      },
    );
    _log('Banner navigated to EventDetails with eventId=$eventId ✓');
  } catch (e) {
    _logError('Native banner navigation threw', e);
  }
}

// ---------------------------------------------------------------------------
// 5. SUPABASE STREAM
//
// KEY DESIGN DECISION:
// is_delivered is NOT checked before showing the banner.
// _processedNotificationIds prevents re-firing when we write
// is_delivered=true back to the row (which triggers another stream event).
//
// Stream skips if:
//   - ID is in _processedNotificationIds (already handled this session)
//   - is_read = true (user already actioned it)
//   - created_at > 60s ago (stale notification)
// ---------------------------------------------------------------------------

final Set<String> _processedNotificationIds = {};

StreamSubscription<List<Map<String, dynamic>>>? _notificationSubscription;

void cancelNotificationStream() {
  if (_notificationSubscription != null) {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
    _log('Notification stream cancelled ✓');
  } else {
    _logWarn('cancelNotificationStream called with no active subscription');
  }
}

Future<void> _startNotificationStream(
  SupabaseClient supabase,
  String userId,
) async {
  cancelNotificationStream();
  _logStep('Stream', 'Opening realtime stream for user: $userId');

  _notificationSubscription = supabase
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('recipient_user_id', userId)
      .order('created_at', ascending: false)
      .limit(1)
      .listen(
        (List<Map<String, dynamic>> data) async {
          _logStep('Stream', 'Event received — rows: ${data.length}');

          if (data.isEmpty) {
            _logWarn('Stream emitted empty data — skipping');
            return;
          }

          final alert = data.first;
          final String alertId = alert['id']?.toString() ?? 'unknown';
          final bool isRead = alert['is_read'] ?? false;
          final String? createdAtStr = alert['created_at'];

          _logStep(
              'Stream',
              'id=$alertId | '
                  'is_read=$isRead | '
                  'is_delivered=${alert['is_delivered']} | '
                  'created_at=$createdAtStr | '
                  'app_title=${alert['app_title']} | '
                  'team_id=${alert['team_id']} | '
                  'link_page=${alert['link_page']}');

          if (_processedNotificationIds.contains(alertId)) {
            _logWarn('Skipping — notification $alertId already '
                'processed this session');
            return;
          }

          // if (isRead) {
          //  _logWarn('Skipping — notification $alertId already read');
          //  return;
          // }

          if (alert['is_delivered'] == true) {
            _logWarn(
                'Skipping — notification $alertId already delivered via another channel');
            return;
          }

          if (createdAtStr == null) {
            _logError('Skipping — notification $alertId has null created_at');
            return;
          }

          final createdAt = DateTime.parse('${createdAtStr}Z').toUtc();
          final DateTime nowUtc = DateTime.now().toUtc();
          final int ageSeconds = nowUtc.difference(createdAt).inSeconds.abs();

          _logStep(
              'Stream',
              'createdAt (UTC)=$createdAt | '
                  'nowUtc=$nowUtc | '
                  'ageSeconds=$ageSeconds (limit: 60s)');

          if (ageSeconds > 60) {
            _logWarn('Skipping — notification $alertId is ${ageSeconds}s '
                'old (limit: 60s)');
            return;
          }

          _processedNotificationIds.add(alertId);
          _log('Notification $alertId added to processed set ✓');

          _log('Notification $alertId passed all checks — handling');
          await _handleNewNotification(supabase, userId, alert);
        },
        onError: (error) {
          _logError('Realtime stream emitted error', error);
        },
      );

  _log('Notification stream active ✓');
}

// ---------------------------------------------------------------------------
// 6. HANDLER
// ---------------------------------------------------------------------------

Future<void> _handleNewNotification(
  SupabaseClient supabase,
  String userId,
  Map<String, dynamic> alert,
) async {
  final String alertId = alert['id'].toString();
  _logStep('Handler', 'Processing id=$alertId');

  _logStep('Handler', 'Retrieving JWT from Supabase session...');
  final String? jwtToken = supabase.auth.currentSession?.accessToken;

  if (jwtToken == null) {
    _logError('JWT token is null — session may have expired. '
        'Skipping handler for $alertId');
    return;
  }

  _logStep(
      'Handler',
      'JWT retrieved — length: ${jwtToken.length} chars | '
          'prefix: ${jwtToken.substring(0, 20)}...');

  _logStep(
      'Handler', 'Resolving team name from team_id=${alert['team_id']}...');
  String teamName = 'CoachSmart';
  final int? teamId = alert['team_id'] is int
      ? alert['team_id'] as int
      : int.tryParse(alert['team_id']?.toString() ?? '');

  if (teamId != null) {
    try {
      final teamResult = await supabase
          .from('teams')
          .select('team_name')
          .eq('team_id', teamId)
          .single();
      final String? resolved = teamResult['team_name']?.toString();
      if (resolved != null && resolved.isNotEmpty) {
        teamName = resolved;
        _log('Team name resolved: "$teamName" ✓');
      } else {
        _logWarn('team_name was null or empty for team_id=$teamId — '
            'using fallback "$teamName"');
      }
    } catch (e) {
      _logError(
          'Team name lookup failed for team_id=$teamId — '
          'using fallback "$teamName"',
          e);
    }
  } else {
    _logWarn('team_id is null on notification $alertId — '
        'using fallback "$teamName"');
  }

  _logStep('Handler', 'Calling GetUserHomeEventsCall for user=$userId...');
  try {
    final apiResult = await GetUserHomeEventsCall.call(
      pUserId: userId,
      supabaseJWTtoken: jwtToken,
    );
    _logStep(
        'Handler',
        'API result — succeeded=${apiResult.succeeded} | '
            'bodyNull=${apiResult.jsonBody == null}');
    if (apiResult.succeeded && apiResult.jsonBody != null) {
      _logStep('Handler', 'Updating FFAppState.homePageEvents...');
      FFAppState().update(() {
        FFAppState().homePageEvents =
            UserEventsHomeStruct.fromMap(apiResult.jsonBody);
      });
      _log('FFAppState.homePageEvents updated ✓');
    } else {
      _logWarn('API call did not succeed — home events not refreshed. '
          'Banner will still show.');
    }
  } catch (e) {
    _logError('GetUserHomeEventsCall threw an exception', e);
  }

  _logStep('Handler', 'Proceeding to badge update...');
  await _updateBadge(supabase, userId);

  try {
    await supabase
        .from('notifications')
        .update({'is_delivered': true}).eq('id', alertId);
    _log('Notification $alertId marked is_delivered=true ✓');
  } catch (e) {
    _logError('Failed to mark $alertId as is_delivered=true', e);
  }

  if (_CooldownManager.isActive) {
    _logWarn('Cooldown still active — popup suppressed for $alertId');
  } else {
    _log('Cooldown clear — triggering popup for $alertId');
    await _showPopup(alert, teamName, supabase);
  }

  _log('Handler fully complete for $alertId ✓');
}

// ---------------------------------------------------------------------------
// 7. BADGE
// ---------------------------------------------------------------------------

Future<void> _updateBadge(SupabaseClient supabase, String userId) async {
  if (kIsWeb) {
    _logWarn('Badge update skipped — not supported on web');
    return;
  }
  _logStep('Badge', 'Querying unread count for user=$userId...');
  try {
    final unreadResponse = await supabase
        .from('notifications')
        .select('id')
        .eq('recipient_user_id', userId)
        .eq('is_read', false)
        .eq('is_delivered', true);

    final int unreadCount = (unreadResponse as List).length;
    _logStep('Badge', 'Unread count = $unreadCount');

    final bool supported = await FlutterAppBadger.isAppBadgeSupported();
    _logStep('Badge', 'Badge supported: $supported');

    if (supported) {
      FlutterAppBadger.updateBadgeCount(unreadCount);
      _log('App badge set to $unreadCount ✓');
    }
  } catch (e) {
    _logError('Badge update failed', e);
  }
}

// ---------------------------------------------------------------------------
// 8. POPUP
// ---------------------------------------------------------------------------

Future<void> _showPopup(
  Map<String, dynamic> alert,
  String teamName,
  SupabaseClient supabase,
) async {
  _logStep('Popup', 'Resolving OverlayState...');
  _logStep('Popup', 'teamName="$teamName"');

  OverlayState? overlay;
  String overlaySource = 'none';

  // Strategy 1 — NavigatorState.overlay (the navigator's own overlay).
  // This is the correct approach: Overlay.of(navigatorElement) looks UP the
  // tree for an ancestor Overlay, which doesn't exist above the root navigator.
  // NavigatorState.overlay IS the overlay the navigator manages.
  try {
    if (_navigatorState != null && _navigatorState!.mounted) {
      final OverlayState? o = _navigatorState!.overlay;
      if (o != null) {
        overlay = o;
        overlaySource = 'navigatorState.overlay';
        _logStep('Popup', 'Overlay resolved via navigatorState.overlay ✓');
      } else {
        _logWarn('navigatorState.overlay is null');
      }
    } else {
      _logWarn('Stored navigatorState: '
          '${_navigatorState == null ? "null" : "not mounted"}');
    }
  } catch (e) {
    _logError('Strategy 1 (navigatorState.overlay) threw', e);
  }

  // Strategy 2 — root navigator via focusManager context.
  if (overlay == null) {
    try {
      final BuildContext? fc =
          WidgetsBinding.instance.focusManager.primaryFocus?.context;
      _logStep(
          'Popup',
          'focusManager context: ${fc != null ? "found" : "null"} | '
              'mounted: ${fc?.mounted}');
      if (fc != null && fc.mounted) {
        final NavigatorState? nav = Navigator.maybeOf(fc, rootNavigator: true);
        final OverlayState? o = nav?.overlay;
        if (o != null) {
          overlay = o;
          overlaySource = 'focusManager+rootNavigator';
          _logStep(
              'Popup', 'Overlay resolved via focusManager+rootNavigator ✓');
        }
      }
    } catch (e) {
      _logError('Strategy 2 (focusManager+rootNavigator) threw', e);
    }
  }

  // Strategy 3 — fresh tree walk to re-acquire NavigatorState.
  if (overlay == null) {
    try {
      _logStep('Popup', 'Strategy 3 — refreshing NavigatorState from tree...');
      _refreshNavigatorContext();
      if (_navigatorState != null && _navigatorState!.mounted) {
        final OverlayState? o = _navigatorState!.overlay;
        if (o != null) {
          overlay = o;
          overlaySource = 'fresh navigatorState walk';
          _logStep('Popup', 'Overlay resolved via fresh tree walk ✓');
        }
      }
    } catch (e) {
      _logError('Strategy 3 (fresh tree walk) threw', e);
    }
  }

  if (overlay == null) {
    _logError('All overlay strategies failed — banner cannot show. '
        'navigatorState='
        '${_navigatorState == null ? "null" : "not mounted"}');
    return;
  }

  _log('OverlayState resolved via $overlaySource ✓');

  final String title = alert['app_title']?.toString() ?? 'New notification';
  final String body = alert['app_body']?.toString() ?? '';
  final String linkPage = alert['link_page']?.toString() ?? '';
  final String notificationId = alert['id'].toString();

  _logStep(
      'Popup',
      'app_title="$title" | '
          'app_body="$body" | '
          'link_page="$linkPage" | '
          'notification_id="$notificationId" | '
          'teamName="$teamName"');

  _insertBanner(
      overlay, title, body, teamName, linkPage, notificationId, supabase);
}

// ---------------------------------------------------------------------------
// 9. BANNER MANAGER
// ---------------------------------------------------------------------------

OverlayEntry? _activeBannerEntry;
Timer? _autoDismissTimer;

void _dismissBanner() {
  _logStep(
      'BannerManager',
      'dismissBanner | '
          'entry=${_activeBannerEntry != null ? "exists" : "null"} | '
          'timer=${_autoDismissTimer != null ? "exists" : "null"}');
  _autoDismissTimer?.cancel();
  _autoDismissTimer = null;
  try {
    _activeBannerEntry?.remove();
  } catch (e) {
    _logError('_dismissBanner: entry.remove() threw (already detached?)', e);
  }
  _activeBannerEntry = null;
  _log('Banner dismissed and removed from overlay ✓');
}

void _pauseTimer() {
  _logStep(
      'BannerManager',
      'pauseTimer | '
          'timer=${_autoDismissTimer != null ? "exists" : "null"}');
  _autoDismissTimer?.cancel();
  _logStep('BannerManager', 'Auto-dismiss timer paused');
}

void _insertBanner(
  OverlayState overlay,
  String title,
  String body,
  String teamName,
  String linkPage,
  String notificationId,
  SupabaseClient supabase,
) {
  _logStep(
      'BannerManager',
      'insertBanner | '
          'existingEntry=${_activeBannerEntry != null} | '
          'teamName="$teamName" | '
          'linkPage="$linkPage" | '
          'notificationId="$notificationId"');

  if (_activeBannerEntry != null) {
    _logStep(
        'BannerManager', 'Removing existing banner before inserting new one');
    _autoDismissTimer?.cancel();
    try {
      _activeBannerEntry?.remove();
    } catch (e) {
      _logError('insertBanner: existing entry.remove() threw', e);
    }
    _activeBannerEntry = null;
  }

  final int instanceId = ++_bannerInstanceCount;

  _activeBannerEntry = OverlayEntry(
    builder: (_) => _SlickBanner(
      title: title,
      body: body,
      teamName: teamName,
      linkPage: linkPage,
      notificationId: notificationId,
      supabase: supabase,
      instanceId: instanceId,
      onDismiss: _dismissBanner,
      onDragStart: _pauseTimer,
    ),
  );

  try {
    overlay.insert(_activeBannerEntry!);
    _log('Banner #$instanceId inserted into overlay ✓');
  } catch (e) {
    _logError('overlay.insert() threw — banner not shown', e);
    _activeBannerEntry = null;
    return;
  }

  _autoDismissTimer = Timer(const Duration(seconds: 4), () {
    _logStep(
        'BannerManager', 'Auto-dismiss timer fired for banner #$instanceId');
    _dismissBanner();
  });

  _log('Auto-dismiss timer started (4s) for banner #$instanceId');
}

// ---------------------------------------------------------------------------
// 10. BANNER WIDGET
// ---------------------------------------------------------------------------

class _SlickBanner extends StatefulWidget {
  const _SlickBanner({
    required this.title,
    required this.body,
    required this.teamName,
    required this.linkPage,
    required this.notificationId,
    required this.supabase,
    required this.instanceId,
    required this.onDismiss,
    required this.onDragStart,
  });

  final String title;
  final String body;
  final String teamName;
  final String linkPage;
  final String notificationId;
  final SupabaseClient supabase;
  final int instanceId;
  final VoidCallback onDismiss;
  final VoidCallback onDragStart;

  @override
  State<_SlickBanner> createState() => _SlickBannerState();
}

class _SlickBannerState extends State<_SlickBanner>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;
  Animation<Offset>? _slide;
  Animation<double>? _fade;
  double _dragOffset = 0.0;
  bool _dismissing = false;

  void _i(String step, String detail) =>
      _logStep('Banner#${widget.instanceId}.$step', detail);
  void _iWarn(String msg) => _logWarn('Banner#${widget.instanceId} — $msg');
  void _iError(String msg, [Object? e]) =>
      _logError('Banner#${widget.instanceId} — $msg', e);

  void _dumpState(String location) {
    _logBannerState(
      location,
      widget.instanceId,
      mounted: mounted,
      ctrlNull: _ctrl == null,
      slideNull: _slide == null,
      fadeNull: _fade == null,
      dismissing: _dismissing,
      dragOffset: _dragOffset,
    );
  }

  void _safeSetState(String caller, VoidCallback fn) {
    _i(
        'safeSetState',
        'called from $caller | '
            'mounted=$mounted | '
            'ctrlNull=${_ctrl == null}');
    if (!mounted) {
      _iWarn('safeSetState[$caller] aborted — not mounted');
      _dumpState('safeSetState[$caller]:notMounted');
      return;
    }
    if (_ctrl == null) {
      _iWarn('safeSetState[$caller] aborted — controller is null');
      _dumpState('safeSetState[$caller]:ctrlNull');
      return;
    }
    try {
      setState(fn);
      _i('safeSetState', '$caller — setState completed ✓');
    } catch (e) {
      _iError('safeSetState[$caller] setState threw', e);
      _dumpState('safeSetState[$caller]:threw');
    }
  }

  @override
  void initState() {
    super.initState();
    _i(
        'initState',
        'begin — instance #${widget.instanceId} | '
            'title="${widget.title}" | '
            'teamName="${widget.teamName}" | '
            'notificationId="${widget.notificationId}" | '
            'linkPage="${widget.linkPage}"');

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 440),
    );
    _i('initState', 'AnimationController created ✓');

    _slide = Tween<Offset>(
      begin: const Offset(0.0, -1.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _ctrl!,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInQuart,
    ));
    _i('initState', 'slide animation created ✓');

    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl!,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
        reverseCurve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );
    _i('initState', 'fade animation created ✓');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _i('postFrameCallback',
          'fired | mounted=$mounted | ctrlNull=${_ctrl == null}');
      if (mounted && _ctrl != null) {
        _ctrl!.forward();
        _i('postFrameCallback', 'forward() called — animation started ✓');
      } else {
        _iWarn('postFrameCallback — skipping forward() | '
            'mounted=$mounted | ctrlNull=${_ctrl == null}');
        _dumpState('postFrameCallback:skipped');
      }
    });

    _i('initState', 'complete');
  }

  @override
  void dispose() {
    _i(
        'dispose',
        'begin | ctrlNull=${_ctrl == null} | '
            'dismissing=$_dismissing');
    _ctrl?.dispose();
    _ctrl = null;
    _i('dispose', 'complete');
    super.dispose();
  }

  Future<void> _animateOut() async {
    if (_dismissing) {
      _iWarn('animateOut — already dismissing, skipping');
      return;
    }
    if (!mounted) {
      _iWarn('animateOut — not mounted');
      _dumpState('animateOut:notMounted');
      return;
    }
    if (_ctrl == null) {
      _iWarn('animateOut — controller null, calling onDismiss directly');
      _dumpState('animateOut:ctrlNull');
      widget.onDismiss();
      return;
    }
    _dismissing = true;
    _i('animateOut', 'starting reverse animation...');
    try {
      await _ctrl!.reverse();
      _i('animateOut', 'reverse animation complete ✓');
    } catch (e) {
      _iError('animateOut reverse animation threw', e);
    }
    if (mounted) {
      widget.onDismiss();
    } else {
      _dismissBanner();
    }
  }

  Future<void> _handleTap() async {
    _i(
        'tap',
        'received | notificationId="${widget.notificationId}" | '
            'linkPage="${widget.linkPage}"');
    HapticFeedback.selectionClick();

    await Future.wait([
      _markNotificationRead(widget.supabase, widget.notificationId),
      _animateOut(),
    ]);

    if (widget.linkPage.isNotEmpty) {
      _i('tap', 'navigating after dismiss');
      await _navigateFromBannerLink(widget.linkPage);
    } else {
      _iWarn('tap — linkPage is empty, no navigation');
    }
  }

  @override
  Widget build(BuildContext context) {
    _i(
        'build',
        'called | ctrlNull=${_ctrl == null} | '
            'mounted=$mounted | dragOffset=$_dragOffset');

    if (_ctrl == null || _slide == null || _fade == null) {
      _iWarn('build — animations not ready, returning SizedBox.shrink()');
      return const SizedBox.shrink();
    }

    final double topPad = MediaQuery.of(context).padding.top;
    _i('build', 'topPad=$topPad');

    const Color cardBg = Color(0xFFE7EBEE);
    const Color titleColor = Color(0xFF1E222B);
    const Color subtitleColor = Color(0xFFA3A3A3);
    const Color pillColor = Color(0x1A1E222B);
    const Color borderColor = Color(0x9987C232);
    const Color iconBg = Color(0xFF87C232);
    const Color iconFg = Color(0xFF1E222B);
    const Color shadowColor = Color(0x591E222B);
    const Color accentBar = Color(0xFF87C232);

    return Stack(
      children: [
        Positioned(
          top: topPad + 10 + _dragOffset,
          left: 12,
          right: 12,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragStart: (_) {
              _i('drag', 'start | dragOffset=$_dragOffset');
              widget.onDragStart();
            },
            onVerticalDragUpdate: (details) {
              final double next = _dragOffset + details.delta.dy;
              if (next > 8.0) return;
              _safeSetState(
                  'dragUpdate', () => _dragOffset = next.clamp(-300.0, 8.0));
            },
            onVerticalDragEnd: (details) {
              final double? velocity = details.primaryVelocity;
              final bool flung = (velocity ?? 0) < -500;
              _i(
                  'drag',
                  'end | velocity=$velocity | '
                      'flung=$flung | dragOffset=$_dragOffset');
              if (flung || _dragOffset < -72) {
                _i('drag', 'threshold met — dismissing via swipe');
                HapticFeedback.lightImpact();
                _animateOut();
              } else {
                _i('drag', 'threshold not met — snapping back');
                _safeSetState('dragEnd:snapBack', () => _dragOffset = 0.0);
              }
            },
            onTap: _handleTap,
            child: SlideTransition(
              position: _slide!,
              child: FadeTransition(
                opacity: _fade!,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1.0),
                      boxShadow: const [
                        BoxShadow(
                          color: shadowColor,
                          blurRadius: 24,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 36,
                                  height: 4,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: pillColor,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: iconBg,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.notifications_rounded,
                                        size: 22,
                                        color: iconFg,
                                      ),
                                    ),
                                    const SizedBox(width: 11),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  widget.teamName.toUpperCase(),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 0.8,
                                                    color: subtitleColor,
                                                  ),
                                                ),
                                              ),
                                              const Text(
                                                'now',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: subtitleColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            widget.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: titleColor,
                                              height: 1.3,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            widget.body,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: subtitleColor,
                                              height: 1.4,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          const Row(
                                            children: [
                                              Icon(
                                                Icons.touch_app_rounded,
                                                size: 11,
                                                color: Color(0xFF87C232),
                                              ),
                                              SizedBox(width: 3),
                                              Text(
                                                'Tap to open event',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF87C232),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 3,
                            color: accentBar,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// ENTRY POINT
// ---------------------------------------------------------------------------

Future<void> registerBackgroundMessageHandler() async {
  print('$_tag ════════════════════════════════════════');
  print('$_tag registerBackgroundMessageHandler START');
  print('$_tag ════════════════════════════════════════');

  _initLifecycle();
  await _initFirebase();

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    _logStep('Init', 'Post-frame callback firing...');

    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      _logWarn('No authenticated user found — handler exiting early');
      return;
    }

    _log('Authenticated user: ${currentUser.id}');

    if (!kIsWeb) {
      FirebaseMessaging.onMessageOpenedApp
          .listen((RemoteMessage message) async {
        _logStep('PushTap', 'onMessageOpenedApp fired | data=${message.data}');
        final String? notificationId = message.data['notification_id'];
        final String? linkPage = message.data['link_page'];
        _logStep(
            'PushTap', 'notificationId=$notificationId | linkPage=$linkPage');
        if (notificationId != null && notificationId.isNotEmpty) {
          await _markNotificationRead(supabase, notificationId);
        } else {
          _logWarn('PushTap — notification_id missing from FCM data payload');
        }
        if (linkPage != null && linkPage.isNotEmpty) {
          _logStep('PushTap', 'Navigating: $linkPage');
          await _navigateFromPushLink(linkPage);
        } else {
          _logWarn('PushTap — link_page missing from FCM data payload');
        }
      });
      _log('onMessageOpenedApp listener registered ✓');

      final RemoteMessage? initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _logStep(
            'PushTap',
            'getInitialMessage — app launched from terminated state | '
                'data=${initialMessage.data}');
        final String? notificationId = initialMessage.data['notification_id'];
        final String? linkPage = initialMessage.data['link_page'];
        if (notificationId != null && notificationId.isNotEmpty) {
          await _markNotificationRead(supabase, notificationId);
        }
        if (linkPage != null && linkPage.isNotEmpty) {
          _logStep(
              'InitialMessage', 'Delaying 500ms then navigating: $linkPage');
          await Future.delayed(const Duration(milliseconds: 500));
          await _navigateFromPushLink(linkPage);
        }
      } else {
        _logStep(
            'Init', 'getInitialMessage — no initial message (normal launch)');
      }
    }

    _refreshNavigatorContext();

    await _startNotificationStream(supabase, currentUser.id);
    _log('registerBackgroundMessageHandler COMPLETE ✓');
  });
}
