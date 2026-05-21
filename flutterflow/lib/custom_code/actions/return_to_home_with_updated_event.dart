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

Future<void> returnToHomeWithUpdatedEvent(
  BuildContext context,
  int listIndex,
  dynamic updatedEvent,
  dynamic currentDataType,
) async {
  // Update the data type directly
  if (currentDataType is Map && currentDataType['events'] is List) {
    List<dynamic> events = currentDataType['events'];

    if (listIndex >= 0 && listIndex < events.length) {
      events[listIndex] = updatedEvent;
    }
  }

  // Navigate back to home page
  Navigator.pop(context);
}
