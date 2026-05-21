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

import 'dart:convert';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<String> supabaseLogin(String email, String password) async {
  try {
    // Attempt to sign in with the provided email and password
    await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    // If sign-in is successful, return an empty string to indicate no error
    return '';
  } on AuthException catch (e) {
    // Catch a Supabase AuthException and return its message as the error
    return e.message;
  } catch (e) {
    // Catch any other unexpected error and return a generic message
    return 'An unexpected error occurred: ${e.toString()}';
  }
}
