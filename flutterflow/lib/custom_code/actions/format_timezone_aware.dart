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

// Can you see the code in my action?
import 'package:intl/intl.dart';

Future<String> formatTimezoneAware(DateTime? timestamp) async {
  if (timestamp == null) {
    return '';
  }

  try {
    // Convert to local timezone
    final localDateTime = timestamp.toLocal();

    // Format the datetime in a user-friendly way
    final formatter = DateFormat('MMM dd, yyyy at hh:mm a');
    return formatter.format(localDateTime);
  } catch (e) {
    // Handle any formatting errors gracefully
    return timestamp.toString();
  }
}
