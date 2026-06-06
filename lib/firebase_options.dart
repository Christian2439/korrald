// ⚠️  TEMPLATE — Replace placeholder values before running the app.
//
// Option A (recommended): Run FlutterFire CLI to auto-generate this file:
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
//
// Option B: Fill in values manually from:
//   Firebase Console → Project Settings → Your Apps → SDK setup and configuration

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default Firebase options for the current platform.
///
/// Generated values should be sourced from your [google-services.json] (Android)
/// and [GoogleService-Info.plist] (iOS). See README.md → Setup for details.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Web is not supported in v1. Configure web options if needed.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ── Android ──────────────────────────────────────────────────────────────
  // Values sourced from: android/app/google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY',
    appId: 'YOUR_ANDROID_APP_ID',             // e.g. 1:123456789:android:abc123
    messagingSenderId: 'YOUR_SENDER_ID',       // e.g. 123456789012
    projectId: 'YOUR_PROJECT_ID',              // e.g. korrald-test
    storageBucket: 'YOUR_PROJECT_ID.firebasestorage.app',
  );

  // ── iOS ───────────────────────────────────────────────────────────────────
  // Values sourced from: ios/Runner/GoogleService-Info.plist
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',                 // e.g. 1:123456789:ios:abc123
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.firebasestorage.app',
    iosBundleId: 'com.example.korrald',        // Must match Info.plist BUNDLE_ID
  );
}
