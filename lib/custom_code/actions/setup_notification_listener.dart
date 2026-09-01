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

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/scheduler.dart';

// Singleton so repeated calls (e.g. hot-reload, navigating back) don't stack subscriptions.
RealtimeChannel? _notifChannel;
bool _lifecycleListenerAdded = false;

Future<void> setupNotificationListener() async {
  final supabase = SupaFlow.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return;

  // ── 1. Refresh count helper ───────────────────────────────────────────────
  Future<void> refreshCount() async {
    try {
      final rows = await supabase
          .from('notifications')
          .select('id')
          .eq('recipient_user_id', userId)
          .eq('is_read', false);
      final count = (rows as List).length;
      FFAppState().updateHomePageEventsStruct(
        (s) => s..unreadNotifications = count,
      );
    } catch (_) {}
  }

  // ── 2. Supabase Realtime — postgres_changes on notifications ─────────────
  _notifChannel?.unsubscribe();
  _notifChannel = supabase
      .channel('home-notif-$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'recipient_user_id',
          value: userId,
        ),
        callback: (_) async => await refreshCount(),
      )
      .subscribe();

  // ── 3. App lifecycle — refresh when app returns to foreground ─────────────
  if (!_lifecycleListenerAdded) {
    _lifecycleListenerAdded = true;
    WidgetsBinding.instance.addObserver(
      _NotifLifecycleObserver(onResume: refreshCount),
    );
  }

  // ── 4. Immediate refresh on call ─────────────────────────────────────────
  await refreshCount();
}

class _NotifLifecycleObserver extends WidgetsBindingObserver {
  final Future<void> Function() onResume;
  _NotifLifecycleObserver({required this.onResume});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}
