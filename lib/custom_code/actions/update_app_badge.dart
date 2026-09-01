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

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<String?> updateAppBadge() async {
  if (kIsWeb) return 'skipped — web does not support badges';

  try {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return 'skipped — no authenticated user';

    final rows = await supabase
        .from('notifications')
        .select('id')
        .eq('recipient_user_id', userId)
        .eq('is_read', false);

    final int unreadCount = (rows as List).length;

    final bool supported = await FlutterAppBadger.isAppBadgeSupported();
    if (!supported) return 'device does not support badges';

    if (unreadCount <= 0) {
      FlutterAppBadger.removeBadge();
    } else {
      FlutterAppBadger.updateBadgeCount(unreadCount);
    }

    return 'success — badge set to $unreadCount';
  } catch (e) {
    return 'error: ${e.toString()}';
  }
}
