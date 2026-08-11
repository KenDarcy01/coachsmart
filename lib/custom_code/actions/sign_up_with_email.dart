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

Future<String?> signUpWithEmail(
  String email,
  String password,
  String confirmPassword,
) async {
  if (password != confirmPassword) {
    return 'Passwords do not match.';
  }

  try {
    final supabase = SupaFlow.client;

    final AuthResponse res = await supabase.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo:
          'https://coach-smart-new-mpqa5l.web.app/auth/confirmed.html',
    );

    // Supabase returns success silently for existing emails —
    // empty identities is the only indicator the account already exists.
    if (res.user != null && (res.user!.identities?.isEmpty ?? true)) {
      return 'An account with this email already exists. Please sign in instead.';
    }

    return null;
  } on AuthException catch (e) {
    return e.message;
  }
}
