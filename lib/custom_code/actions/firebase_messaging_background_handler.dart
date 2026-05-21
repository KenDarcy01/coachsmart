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

// This must be a top-level function (or static method if in a class)
// and cannot be an anonymous function.
// It runs when the app is in the background or terminated and a message is received.
// Workaround: Use 'dynamic' for the parameter type to help FlutterFlow's editor save,
// then cast back to RemoteMessage inside the function.
Future<void> firebaseMessagingBackgroundHandler(dynamic messageData) async {
  // Explicitly cast messageData back to RemoteMessage
  final RemoteMessage message = messageData as RemoteMessage;

  // Initialize Firebase if not already initialized (important for background tasks)
  // This check is crucial because this handler might run when the app is not fully initialized.
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
    print('Handling background message: Firebase initialized.');
  }

  print('Handling background message: ${message.messageId}');
  print('Message data: ${message.data}');

  if (message.notification != null) {
    print('Notification Title: ${message.notification?.title}');
    print('Notification Body: ${message.notification?.body}');
  }

  // --- IMPORTANT: Add your custom background processing logic here ---
  // Examples:
  // - You could update a local database (e.g., using Supabase client if initialized).
  // - You could show a local notification (requires a local notification package).
  // - You could trigger a Supabase Edge Function to process data.
  // Be aware of execution limits for background tasks (typically a few seconds).
  // Avoid complex UI operations or long-running tasks.
}
