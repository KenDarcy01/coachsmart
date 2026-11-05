import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

Future initFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: "AIzaSyBXrlO3pCqoW4yatNw_su2rf1xpfw9yOyw",
            authDomain: "coach-smart-new-mpqa5l.firebaseapp.com",
            projectId: "coach-smart-new-mpqa5l",
            storageBucket: "coach-smart-new-mpqa5l.firebasestorage.app",
            messagingSenderId: "1026672336817",
            appId: "1:1026672336817:web:fed7e4298c2f3fbd4ca790"));
  } else {
    await Firebase.initializeApp();
  }
}
