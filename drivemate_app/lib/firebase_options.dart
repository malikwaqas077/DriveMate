// Generated manually for DriveMate. If you later use FlutterFire CLI,
// you can replace this file with the generated version.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static Future<FirebaseApp> initialize() {
    return Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  /// Web client ID for Google Sign-In on Android (serverClientId).
  /// Get it from: Firebase Console → Authentication → Sign-in method → Google → Web SDK configuration → Web client ID.
  /// Leave null if you don't use Google Sign-In on Android.
  static const String? googleSignInWebClientId = '98973897901-poqc7mksroa76n5e96ol4cvkq9rljhdb.apps.googleusercontent.com';

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAIvn_EVuZ6t8uyPwk9lBdfQCqZeMIseio',
    appId: '1:98973897901:web:51fb5a776a457544c1a224',
    messagingSenderId: '98973897901',
    projectId: 'drivemate-ac4ad',
    authDomain: 'drivemate-ac4ad.firebaseapp.com',
    storageBucket: 'drivemate-ac4ad.firebasestorage.app',
    measurementId: 'G-RSQTTM614F',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCQpYeZKWyyt9oXbPEZdYxLeyFIrd8R4FE',
    appId: '1:98973897901:android:49e93f76bf9afab7c1a224',
    messagingSenderId: '98973897901',
    projectId: 'drivemate-ac4ad',
    storageBucket: 'drivemate-ac4ad.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCUC3y62bkHXsAXRe7pNLLH2L3jZh5s53o',
    appId: '1:98973897901:ios:25ce95a984334bfac1a224',
    messagingSenderId: '98973897901',
    projectId: 'drivemate-ac4ad',
    storageBucket: 'drivemate-ac4ad.firebasestorage.app',
    iosBundleId: 'app.techsol.drivemate',
  );

}