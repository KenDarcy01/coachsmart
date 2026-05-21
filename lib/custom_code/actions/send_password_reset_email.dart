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
    // 1. Validate the email format with a simple regular expression.
    // This catches typos like "user@domain" and provides immediate feedback.
    final emailRegex = RegExp(
        r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
    if (!emailRegex.hasMatch(emailAddress)) {
      return 'The email address format is invalid.';
    }

    // 2. Trigger the secure Supabase password reset.
    // Supabase will handle the validation and email sending internally.
    Supabase.instance.client.auth.resetPasswordForEmail(emailAddress);

    // 3. Return a success message.
    // This message is a security best practice. It is vague to prevent
    // an attacker from knowing if an email address exists in the system.
    return 'If an account exists for this email, a password reset link has been sent.';
  } on AuthException catch (e) {
    // Supabase handles most of the validation, but we catch exceptions
    // in case of an API error.
    print('Supabase Auth Error: ${e.message}');
    return 'Failed to send password reset email. Please try again.';
  } catch (e) {
    // Catch any other unexpected errors.
    print('Unexpected Error: $e');
    return 'An unexpected error occurred.';
  }
}
