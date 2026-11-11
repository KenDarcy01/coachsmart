// One unread count for the whole v3 app, so the Notifications page, the
// Home bell and the app icon badge always agree (Ken, 2026-11-11).
//
// The count is the number of the user's notifications with is_read = false,
// the same number get_user_home_events returns and the push job writes to
// the iOS badge. It is refreshed:
//  - when Home loads (from the home data, no extra call),
//  - after anything on the Notifications page changes a row,
//  - whenever one of the user's rows is inserted or updated (realtime), so
//    a new notification, a request another admin handled or a reminder
//    cleared by another parent's answer moves the bell straight away,
//  - when the app comes back to the foreground.
// Every change also sets the app icon badge (iOS / Android; web has none).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';

import '/app_state.dart';
import '/backend/supabase/supabase.dart';

class V3Unread with WidgetsBindingObserver {
  V3Unread._();
  static final V3Unread instance = V3Unread._();

  /// The current unread count. Widgets listen to this.
  final ValueNotifier<int> count = ValueNotifier<int>(0);

  RealtimeChannel? _channel;
  String _user = '';
  Timer? _debounce;
  bool _observing = false;

  /// Start (or move to another user) the realtime listener. Safe to call on
  /// every Home load.
  void start() {
    final uid = SupaFlow.client.auth.currentUser?.id ?? '';
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    if (uid == _user && _channel != null) return;
    _stopChannel();
    _user = uid;
    if (uid.isEmpty) return;
    try {
      _channel = SupaFlow.client
          .channel('v3-unread-$uid')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'recipient_user_id',
                value: uid),
            callback: (_) => _soon(),
          )
          .subscribe();
    } catch (_) {}
  }

  void _stopChannel() {
    final ch = _channel;
    _channel = null;
    if (ch == null) return;
    try {
      SupaFlow.client.removeChannel(ch);
    } catch (_) {}
  }

  void _soon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), refresh);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  /// Set the count from a number already loaded (Home data).
  void set(int n) {
    if (n < 0) n = 0;
    count.value = n;
    try {
      final home = FFAppState().homePageEvents;
      if (home.unreadNotifications != n) {
        FFAppState().update(() => home.unreadNotifications = n);
      }
    } catch (_) {}
    _badge(n);
  }

  /// Count the unread rows again and update the bell and the badge.
  Future<int> refresh() async {
    final uid = SupaFlow.client.auth.currentUser?.id;
    if (uid == null) {
      set(0);
      return 0;
    }
    try {
      final n = await SupaFlow.client
          .from('notifications')
          .count(CountOption.exact)
          .eq('recipient_user_id', uid)
          .eq('is_read', false);
      set(n);
      return n;
    } catch (_) {
      return count.value;
    }
  }

  Future<void> _badge(int n) async {
    if (kIsWeb) return;
    try {
      if (!await FlutterAppBadger.isAppBadgeSupported()) return;
      if (n <= 0) {
        FlutterAppBadger.removeBadge();
      } else {
        FlutterAppBadger.updateBadgeCount(n);
      }
    } catch (_) {}
  }
}
