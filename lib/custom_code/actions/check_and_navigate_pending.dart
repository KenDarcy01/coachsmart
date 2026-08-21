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

import 'package:shared_preferences/shared_preferences.dart';

Future<String> checkAndNavigatePending() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? eventIdStr = prefs.getString('pending_notification_event_id');

  if (eventIdStr == null || eventIdStr.isEmpty) {
    print('[NotifHandler] ▶ [ColdStart] No pending navigation found');
    return '';
  }

  await prefs.remove('pending_notification_event_id');
  print('[NotifHandler] ▶ [ColdStart] Consuming pending eventID=$eventIdStr ✓');
  return eventIdStr;
}
