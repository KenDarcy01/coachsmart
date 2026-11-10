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

// FlutterFlow Custom Action
// Name: openLocationPin
// Arguments: locationPin (String, nullable), locationName (String, nullable)
//
// Replaces the built-in "Launch Map" action on the Event Details Location row.
// Launch Map passed the Google Maps share link as a search word with
// coordinates 0,0, so phones opened Apple Maps on nothing, and on the PWA it
// did nothing at all (the map launcher package has no web support).
//
// This opens the pin link itself (Google Maps app if installed, otherwise the
// browser). With no link it searches Google Maps for the location name.

import 'package:url_launcher/url_launcher.dart';

Future openLocationPin(
  String? locationPin,
  String? locationName,
) async {
  final pin = (locationPin ?? '').trim();
  final name = (locationName ?? '').trim();

  Uri? uri;

  // A pasted link, e.g. "https://maps.app.goo.gl/abc?g_st=aw" (also copes
  // with "Https://", a leading space, or text around the link).
  final match =
      RegExp(r'https?://\S+', caseSensitive: false).firstMatch(pin);
  if (match != null) {
    uri = Uri.tryParse(match.group(0)!);
  }

  // No link: search Google Maps for the venue name (or the pin text).
  if (uri == null) {
    final query = name.isNotEmpty
        ? name
        : (pin == 'location_pin' ? '' : pin);
    if (query.isEmpty) return;
    uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
  }

  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
