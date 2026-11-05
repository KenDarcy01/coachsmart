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

List<dynamic> updateHomeEventList(
  List<dynamic> eventsList,
  int listIndex,
  dynamic updatedEvent,
) {
  if (listIndex >= 0 && listIndex < eventsList.length) {
    final updatedList = List<dynamic>.from(eventsList);
    updatedList[listIndex] = updatedEvent;
    return updatedList;
  }
  return eventsList;
}
