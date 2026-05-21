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

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
import 'dart:convert';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<String> supabaseMagicLinkLogin(String email) async {
  try {
    // Attempt to send a magic link to the provided email
    await Supabase.instance.client.auth.signInWithOtp(
      email: email,
      emailRedirectTo:
          'https://my.coachsmart.app/homePage', // IMPORTANT: Change this URL to your app's home page
    );
    // If the email is successfully sent, return an empty string to indicate no error
    return '';
  } on AuthException catch (e) {
    // Catch a Supabase AuthException and return its message as the error
    return e.message;
  } catch (e) {
    // Catch any other unexpected error and return a generic message
    return 'An unexpected error occurred: ${e.toString()}';
  }
}
