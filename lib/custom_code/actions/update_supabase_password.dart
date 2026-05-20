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

import 'dart:io';
import 'package:supabase/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<String> updateSupabasePassword(
  String newPassword,
  String confirmPassword,
) async {
  // Check if the two passwords match.
  if (newPassword != confirmPassword) {
    return 'The passwords do not match. Please try again.';
  }

  try {
    // Call the Supabase authentication API to update the user's password.
    final response = await Supabase.instance.client.auth.updateUser(
      UserAttributes(
        password: newPassword,
      ),
    );

    // Check for a successful update.
    if (response.user != null) {
      return 'Success';
    } else {
      // Handle the case where the user object is null but no error was thrown.
      return 'An unexpected error occurred. Please try again.';
    }
  } on AuthException catch (e) {
    // Catch specific Supabase authentication exceptions.
    print('Supabase Auth Error: ${e.message}');
    return 'Failed to update password: ${e.message}';
  } catch (e) {
    // Catch any other unexpected errors.
    print('Unexpected Error: $e');
    return 'An unexpected error occurred.';
  }
}
