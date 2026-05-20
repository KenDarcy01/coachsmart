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

import 'package:flutter_app_badger/flutter_app_badger.dart';

Future<String?> updateAppBadge(int? badgeCount) async {
  try {
    // 1. Check if the device supports badging at all
    bool isSupported = await FlutterAppBadger.isAppBadgeSupported();
    if (!isSupported) {
      return "Device does not support app icon badges.";
    }

    int count = badgeCount ?? 0;

    if (count <= 0) {
      FlutterAppBadger.removeBadge();
    } else {
      FlutterAppBadger.updateBadgeCount(count);
    }

    return "success"; // Return success string
  } catch (e) {
    // 2. Return the actual error message if something crashes
    return "Error updating badge: ${e.toString()}";
  }
}
