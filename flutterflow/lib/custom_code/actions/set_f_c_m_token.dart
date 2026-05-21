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
    show kIsWeb; // Import for platform check
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

  // If not web, proceed with FCM setup
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
  if (settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional) {
    // --- 2. Get the FCM Device Token ---
    FFAppState().update(() {
      FFAppState().fcmToken = 'Getting FCM token...';
    });
    String? token = await _firebaseMessaging.getToken();

    if (token != null) {
      FFAppState().update(() {
        FFAppState().fcmToken = token; // Store the actual token
      });
    } else {
      FFAppState().update(() {
        FFAppState().fcmToken = 'Failed to retrieve FCM token.';
      });
    }
  } else {
    FFAppState().update(() {
      FFAppState().fcmToken = 'Notification permissions denied.';
    });
  }
}
