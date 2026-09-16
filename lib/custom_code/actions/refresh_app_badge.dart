// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:flutter/foundation.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import '/auth/supabase_auth/auth_util.dart';

/// Queries the DB for the current user's unread notification count and
/// updates the OS app badge immediately. Call this after any action that
/// marks notifications as read (e.g. on the Notifications page on-load,
/// or on the back button after viewing notifications).
Future refreshAppBadge() async {
  if (kIsWeb) return;
  try {
    final bool supported = await FlutterAppBadger.isAppBadgeSupported();
    if (!supported) return;

    final response = await SupaFlow.client
        .from('notifications')
        .select('id')
        .eq('recipient_user_id', currentUserUid)
        .eq('is_read', false)
        .eq('is_delivered', true);

    final int unreadCount = (response as List).length;
    FlutterAppBadger.updateBadgeCount(unreadCount);
  } catch (_) {}
}
