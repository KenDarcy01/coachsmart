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

import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

Future updateUserPlatform() async {
  final String platform;

  if (kIsWeb) {
    platform = 'web';
  } else if (Platform.isIOS) {
    platform = 'ios';
  } else {
    platform = 'android';
  }

  try {
    await Supabase.instance.client.rpc(
      'update_user_platform',
      params: {'p_platform': platform},
    );
  } catch (e) {
    debugPrint('[Platform] update_user_platform error: $e');
  }
}
