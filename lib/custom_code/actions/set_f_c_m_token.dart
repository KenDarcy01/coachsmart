// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/ff_builtin_enums.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart' hide RepeatMode;
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Custom Action: setFCMToken
///
/// Gets this phone's push token and saves it to users.fcm_token for the
/// signed-in user. It only ever saves a real token:
/// - On web it does nothing, so the web app never blanks the phone's token.
/// - If notifications are denied, or no token comes back, the saved token is
///   left as it is (no status text is ever saved as a token).
///
/// FFAppState().fcmToken holds the real token, or stays as it was.
///
/// The Home page no longer needs its own "Update users fcm_token" step:
/// this action saves the token itself.
Future<void> setFCMToken() async {
  if (kIsWeb) {
    print('[setFCMToken] Web: skipped, token left as it is');
    return;
  }

  final String? userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) {
    print('[setFCMToken] Nobody signed in: skipped');
    return;
  }

  try {
    final FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Shows the prompt only the first time; afterwards it just returns the
    // current setting.
    final NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      print('[setFCMToken] Notifications not allowed '
          '(${settings.authorizationStatus.name}): token left as it is');
      return;
    }

    final String? token = await messaging.getToken();
    if (token == null || token.isEmpty) {
      print('[setFCMToken] No token returned: token left as it is');
      return;
    }

    FFAppState().update(() {
      FFAppState().fcmToken = token;
    });

    await Supabase.instance.client
        .from('users')
        .update({'fcm_token': token}).eq('user_id', userId);
    print('[setFCMToken] Token saved ✓');
  } catch (e) {
    print('[setFCMToken] Failed, token left as it is: $e');
  }
}
