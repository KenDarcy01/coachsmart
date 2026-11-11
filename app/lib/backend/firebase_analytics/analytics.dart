import 'dart:math';

import 'package:firebase_analytics/firebase_analytics.dart';

const kMaxEventNameLength = 40;
const kMaxParameterLength = 100;
const kV3DropFlutterFlowEvents = true;

void logFirebaseEvent(String eventName, {Map<String?, dynamic>? parameters}) {
  // v3 (2026-11-11): FlutterFlow's auto events (Button_backend_call,
  // IconButton_navigate_back, screen_view...) don't say what was tapped, so
  // v3 drops them. Screens come from V3TrackObserver and named events from
  // V3Track (lib/v3/tracking/v3_track.dart). The old app is unaffected.
  if (kV3DropFlutterFlowEvents) return;
  // https://firebase.google.com/docs/reference/cpp/group/event-names
  assert(eventName.length <= kMaxEventNameLength);

  parameters ??= {};
  parameters.removeWhere((k, v) => k == null || v == null);
  final params = parameters.map((k, v) => MapEntry(k!, v));

  // FB Analytics allows num values but others need to be converted to strings
  // and cannot be more than 100 characters.
  for (final entry in params.entries) {
    if (entry.value is! num) {
      var valStr = entry.value.toString();
      if (valStr.length > kMaxParameterLength) {
        valStr = valStr.substring(0, min(valStr.length, kMaxParameterLength));
      }
      params[entry.key] = valStr;
    }
  }

  FirebaseAnalytics.instance
      .logEvent(name: eventName, parameters: params.cast<String, Object>());
}
