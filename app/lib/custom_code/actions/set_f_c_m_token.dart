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

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform; // Platform checks
import '/flutter_flow/flutter_flow_util.dart'; // Required for updateAppState

/// Custom Action: setFCMToken
///
/// This function handles the logic for obtaining the Firebase Cloud Messaging (FCM)
/// device token and updating a single FlutterFlow App State variable: `fcmToken`.
///
/// It focuses on requesting permissions and retrieving the token.
/// FCM listeners are now handled by a separate action (`registerBackgroundMessageHandler`).
///
/// The `fcmToken` variable will store:
/// - The actual retrieved FCM token (if successful).
/// - A status message indicating the last stage reached or an error encountered.
///
/// This version does NOT directly interact with Supabase to store the token.
/// Instead, it makes the token available via App State for a follow-on action.
///
/// This function is designed to be safely called in multiple scenarios:
/// 1. After a user successfully logs in or signs up with Supabase.
/// 2. On app initialization or on page load of your main authenticated page
///    (for returning users).
///
/// It includes a check to skip FCM-related operations when running on the web,
/// as FCM tokens are primarily for native mobile devices.
///
/// Prerequisites:
/// 1. Your FlutterFlow project is connected to a Firebase project.
/// 2. Firebase Cloud Messaging (FCM) is enabled in your Firebase project.
/// 3. `firebase_core` and `firebase_messaging` are added as dependencies.
/// 4. You have created a FlutterFlow App State variable:
///    - `fcmToken` (String)
Future<void> setFCMToken() async {
  // Set initial status in fcmToken App State
  FFAppState().update(() {
    FFAppState().fcmToken = 'Starting FCM token retrieval...';
  });

  // --- Check if running on web platform ---
  if (kIsWeb) {
    FFAppState().update(() {
      FFAppState().fcmToken = 'Running on web. FCM setup skipped.';
    });
    return; // Exit the function for web platform
  }

  // If not web, proceed with FCM setup. Never throws: any failure is left as
  // a status message in fcmToken (saved to users.fcm_token, so it can be seen
  // from the server; sends treat it as "no push" and fall back to email).
  try {
    final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

    // --- 1. Request Notification Permissions ---
    FFAppState().update(() {
      FFAppState().fcmToken = 'Requesting notification permissions...';
    });
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // Proceed only if permissions are granted or provisional
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      FFAppState().update(() {
        FFAppState().fcmToken = 'Notification permissions denied.';
      });
      return;
    }

    // --- 2. iPhone: wait for Apple's push ID (APNs token) ---
    // getToken() fails with "apns-token-not-set" if it is called before Apple
    // has handed the app its APNs token, which can take a few seconds after
    // launch (Ken's phone, 2026-11-22). Wait up to ~15s for it.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      FFAppState().update(() {
        FFAppState().fcmToken = 'Waiting for APNs token...';
      });
      String? apns;
      for (var i = 0; i < 15 && apns == null; i++) {
        try {
          apns = await _firebaseMessaging.getAPNSToken();
        } catch (_) {}
        if (apns == null) await Future.delayed(const Duration(seconds: 1));
      }
      if (apns == null) {
        FFAppState().update(() {
          FFAppState().fcmToken = 'No APNs token from Apple.';
        });
        return;
      }
    }

    // --- 3. Get the FCM Device Token (retry a few times) ---
    FFAppState().update(() {
      FFAppState().fcmToken = 'Getting FCM token...';
    });
    String? token;
    Object? lastError;
    for (var i = 0; i < 3 && token == null; i++) {
      try {
        token = await _firebaseMessaging.getToken();
      } catch (e) {
        lastError = e;
      }
      if (token == null && i < 2) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (token != null && token.isNotEmpty) {
      final t = token;
      FFAppState().update(() {
        FFAppState().fcmToken = t; // Store the actual token
      });
    } else {
      final msg = lastError == null
          ? 'Failed to retrieve FCM token.'
          : 'FCM error: ${_short(lastError)}';
      FFAppState().update(() {
        FFAppState().fcmToken = msg;
      });
    }
  } catch (e) {
    FFAppState().update(() {
      FFAppState().fcmToken = 'FCM error: ${_short(e)}';
    });
  }
}

/// True when fcmToken holds a real device token rather than a status message.
bool isRealFcmToken(String t) => t.length > 60 && !t.contains(' ');

String _short(Object e) {
  final s = e.toString();
  return s.length > 120 ? s.substring(0, 120) : s;
}
