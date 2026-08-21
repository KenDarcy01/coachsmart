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

Future<String> sendPasswordResetEmail(
  String emailAddress,
) async {
  try {
    final emailRegex = RegExp(
        r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
    if (!emailRegex.hasMatch(emailAddress)) {
      return 'The email address format is invalid.';
    }

    await Supabase.instance.client.auth.resetPasswordForEmail(
      emailAddress,
      redirectTo: 'https://my.coachsmart.app/updatePassword',
    );

    return 'If an account exists for this email, a password reset link has been sent.';
  } on AuthException catch (e) {
    print('Supabase Auth Error: ${e.message}');
    return 'Failed to send password reset email. Please try again.';
  } catch (e) {
    print('Unexpected Error: $e');
    return 'An unexpected error occurred.';
  }
}
