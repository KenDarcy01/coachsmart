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
    await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return '';
  } on AuthException catch (e) {
    try {
      final exists = await Supabase.instance.client
          .rpc('check_email_exists', params: {'p_email': email});
      if (exists == false) {
        return 'No account found with that email address.';
      } else {
        return 'Incorrect password. Please try again.';
      }
    } catch (_) {
      return e.message;
    }
  } catch (e) {
    return 'An unexpected error occurred: ${e.toString()}';
  }
}
