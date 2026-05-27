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

Future<String> fetchSupabaseAccessToken() async {
  final supabase = Supabase.instance.client;
  final session = supabase.auth.currentSession;

  if (session != null && session.accessToken.isNotEmpty) {
    return session.accessToken;
  } else {
    // Better for FlutterFlow: return an empty string instead of crashing
    return '';
  }
}
