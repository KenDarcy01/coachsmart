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
// Event Details Location row. Opens the pasted map link (Google Maps app if
// installed, otherwise the browser). With no link it searches Google Maps for
// the venue name.
//
// iPhone PWA only: opening the link leaves a blank browser page on top of the
// app after Maps opens. So there the map-pin edge function turns the link into
// a place/position and Apple Maps is opened directly (maps://), which leaves
// nothing behind. If that fails it falls back to opening the link.

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

// Apple Maps app link, e.g. maps://?ll=53.37,-6.19&q=Pitch+19
Uri _appleMaps(Map<String, String> params) =>
    Uri.parse('maps://?${Uri(queryParameters: params).query}');

Future openLocationPin(
  String? locationPin,
  String? locationName,
) async {
  final pin = (locationPin ?? '').trim();
  final name = (locationName ?? '').trim();

  Uri? uri;

  // A pasted link, e.g. "https://maps.app.goo.gl/abc?g_st=aw"
  final match = RegExp(r'https?://\S+', caseSensitive: false).firstMatch(pin);
  if (match != null) {
    uri = Uri.tryParse(match.group(0)!);
  }

  // iPhone PWA: open Apple Maps directly so no blank page is left behind.
  if (kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    Uri? apple;
    if (uri != null) {
      try {
        final res = await SupaFlow.client.functions
            .invoke('map-pin', body: {'url': uri.toString()})
            .timeout(const Duration(seconds: 4));
        final data = res.data;
        if (data is Map) {
          final lat = data['lat'];
          final lng = data['lng'];
          final label = (data['name'] ?? name).toString().trim();
          final query = (data['query'] ?? '').toString().trim();
          if (lat is num && lng is num) {
            apple = _appleMaps({
              'll': '$lat,$lng',
              'q': label.isNotEmpty ? label : 'Location',
            });
          } else if (query.isNotEmpty) {
            apple = _appleMaps({'q': query});
          }
        }
      } catch (_) {
        // Fall back to opening the link below.
      }
    } else {
      final query = name.isNotEmpty ? name : (pin == 'location_pin' ? '' : pin);
      if (query.isNotEmpty) {
        apple = _appleMaps({'q': query});
      }
    }
    if (apple != null) {
      await launchUrl(apple, webOnlyWindowName: '_self');
      return;
    }
  }

  // No link: search Google Maps for the venue name (or the pin text).
  if (uri == null) {
    final query = name.isNotEmpty ? name : (pin == 'location_pin' ? '' : pin);
    if (query.isEmpty) return;
    uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
  }

  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
