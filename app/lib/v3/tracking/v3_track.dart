// v3 usage analytics (Ken, 2026-11-11): Firebase Analytics / GA4, same
// Firebase project as the old app. Plan:
// https://claude.ai/artifact/SvX3dTdAEFcRNz2sGKzU9g
//
// - Every v3 user carries the user property app_gen = v3, so reports can
//   be filtered to v3 and the old app's numbers are left alone.
// - After sign-in the GA4 user ID is the CoachSmart user id (a uuid, never a
//   name or email), with user properties club, role (coach/player) and
//   teams (number of teams).
// - Screen views come from V3TrackObserver (named routes only).
// - Named events via V3Track.event(); parameters are ids and short labels,
//   never names or free text.
// - The FlutterFlow auto events (Button_backend_call and so on) are dropped in
//   v3: see lib/backend/firebase_analytics/analytics.dart.
//
// Every call is fire-and-forget and never throws, so analytics can't break a
// screen. In tests (no Firebase app) everything is a no-op unless a sink is set.

import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '/backend/supabase/supabase.dart';

/// Where events go. Tests swap in a recording sink.
abstract class V3TrackSink {
  Future<void> event(String name, Map<String, Object> params);
  Future<void> screen(String name);
  Future<void> userId(String? id);
  Future<void> userProperty(String name, String? value);
}

class _FirebaseSink implements V3TrackSink {
  FirebaseAnalytics get _fa => FirebaseAnalytics.instance;
  @override
  Future<void> event(String name, Map<String, Object> params) =>
      _fa.logEvent(name: name, parameters: params.isEmpty ? null : params);
  @override
  Future<void> screen(String name) =>
      _fa.logScreenView(screenName: name, screenClass: name);
  @override
  Future<void> userId(String? id) => _fa.setUserId(id: id);
  @override
  Future<void> userProperty(String name, String? value) =>
      _fa.setUserProperty(name: name, value: value);
}

class V3Track {
  V3Track._();

  /// Set by tests. When null, events go to Firebase if it is initialised.
  @visibleForTesting
  static V3TrackSink? sink;

  static V3TrackSink? get _sink {
    if (sink != null) return sink;
    try {
      if (Firebase.apps.isEmpty) return null;
    } catch (_) {
      return null;
    }
    return _firebase;
  }

  static final _firebase = _FirebaseSink();
  static String? _identified;
  static bool _started = false;

  /// GA4 limits: event and parameter names 40 chars, values 100 chars.
  static String cleanName(String s) {
    var n = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
    n = n.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
    if (n.isEmpty || !RegExp(r'^[a-z]').hasMatch(n)) n = 'e_$n';
    return n.length > 40 ? n.substring(0, 40) : n;
  }

  static Map<String, Object> cleanParams(Map<String, Object?>? p) {
    final out = <String, Object>{};
    p?.forEach((k, v) {
      if (v == null) return;
      final key = cleanName(k);
      if (v is num) {
        out[key] = v;
      } else if (v is bool) {
        out[key] = v ? 1 : 0;
      } else {
        final s = v.toString();
        if (s.isEmpty) return;
        out[key] = s.length > 100 ? s.substring(0, 100) : s;
      }
    });
    return out;
  }

  static void _run(Future<void> Function(V3TrackSink s) f) {
    final s = _sink;
    if (s == null) return;
    try {
      unawaited(f(s).catchError((_) {}));
    } catch (_) {}
  }

  /// Called once at start-up: tags this install as v3.
  static void start() {
    if (_started) return;
    _started = true;
    _run((s) async {
      await s.userProperty('app_gen', 'v3');
      await s.userProperty('surface', surfaceName());
    });
  }

  static String surfaceName() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return defaultTargetPlatform.name;
    }
  }

  /// A named event, e.g. V3Track.event('event_created', {'team_id': 12}).
  static void event(String name, [Map<String, Object?>? params]) {
    final n = cleanName(name);
    final p = cleanParams(params);
    _run((s) => s.event(n, p));
  }

  /// A reply to an event. responseId: 3 accepted, 4 declined (the
  /// event_response_type ids the app uses); from: home, event, notification
  /// or coach (a coach replying for a member).
  static void attendance(int eventId, int responseId, String from) =>
      event('attendance_responded', {
        'event_id': eventId,
        'response': responseLabel(responseId),
        'from': from,
      });

  static String responseLabel(int id) => switch (id) {
        3 => 'accepted',
        4 => 'declined',
        _ => 'r$id',
      };

  /// An edge function call (AI and PDF features), e.g. generate-session-plan
  /// with action generate -> event generate_session_plan, action generate.
  static void feature(String fn, [Object? action]) => event(fn, {
        if (action != null) 'action': '$action',
      });

  static void screen(String name) {
    if (name.isEmpty) return;
    _run((s) => s.screen(name.length > 100 ? name.substring(0, 100) : name));
  }

  /// Called whenever the signed-in user changes. Sets the GA4 user id and
  /// the club / role / teams properties (looked up once per user).
  static void identify(String? uid) {
    final id = (uid == null || uid.isEmpty) ? null : uid;
    if (id == _identified) return;
    _identified = id;
    if (id == null) {
      _run((s) async {
        await s.userId(null);
        await s.userProperty('club', null);
        await s.userProperty('role', null);
        await s.userProperty('teams', null);
      });
      return;
    }
    _run((s) async {
      await s.userId(id);
      final props = await _lookup(id);
      if (_identified != id) return;
      for (final e in props.entries) {
        await s.userProperty(e.key, e.value);
      }
    });
  }

  /// club = the user's default club name, role = coach if they hold any
  /// grade-100 role, else player; teams = how many teams they are on.
  static Future<Map<String, String?>> _lookup(String uid) async {
    final out = <String, String?>{};
    try {
      final c = SupaFlow.client;
      final u = await c
          .from('users')
          .select('default_club')
          .eq('user_id', uid)
          .maybeSingle();
      final clubId = u?['default_club'];
      if (clubId != null) {
        final club = await c
            .from('clubs')
            .select('club_name')
            .eq('club_id', clubId)
            .maybeSingle();
        out['club'] = clubLabel(club?['club_name']?.toString());
      }
      final uml = await c
          .from('user_member_link')
          .select('member_id')
          .eq('user_id', uid);
      if (uml.isEmpty) {
        out['role'] = 'none';
        out['teams'] = '0';
        return out;
      }
      final mtl = await c
          .from('member_team_link')
          .select('member_team_id,team_id')
          .inFilter('member_id', [for (final r in uml) r['member_id']]);
      out['teams'] = teamsBucket({for (final r in mtl) r['team_id']}.length);
      if (mtl.isEmpty) {
        out['role'] = 'none';
        return out;
      }
      final mtrl = await c
          .from('member_team_role_link')
          .select('role_id')
          .inFilter(
              'member_team_id', [for (final r in mtl) r['member_team_id']]);
      final roleIds = {for (final r in mtrl) r['role_id']}.toList();
      var coach = false;
      if (roleIds.isNotEmpty) {
        final admin = await c
            .from('roles')
            .select('role_id')
            .inFilter('role_id', roleIds)
            .eq('role_grade', 100)
            .limit(1);
        coach = admin.isNotEmpty;
      }
      out['role'] = coach ? 'coach' : 'player';
    } catch (_) {}
    return out;
  }

  /// GA4 user property values are capped at 36 characters.
  static String? clubLabel(String? name) {
    final n = name?.trim() ?? '';
    if (n.isEmpty) return null;
    return n.length > 36 ? n.substring(0, 36) : n;
  }

  static String teamsBucket(int n) => n >= 5 ? '5+' : '$n';

  /// Test helper: forget who is signed in.
  @visibleForTesting
  static void reset() {
    _identified = null;
    _started = false;
  }
}

/// Logs a screen view for every named route that comes into view (pushed,
/// or shown again when the route above it is popped). Unnamed routes
/// (dialogs, sheets) are skipped.
class V3TrackObserver extends NavigatorObserver {
  static String? nameOf(Route<dynamic>? r) {
    if (r is! PageRoute) return null;
    final n = r.settings.name;
    // '_initialize' is the start-up route; Home logs itself.
    if (n == null || n.isEmpty || n.startsWith('/') || n.startsWith('_')) {
      return null;
    }
    return n;
  }

  void _show(Route<dynamic>? r) {
    final n = nameOf(r);
    if (n != null) V3Track.screen(n);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _show(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _show(newRoute);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _show(previousRoute);
}
