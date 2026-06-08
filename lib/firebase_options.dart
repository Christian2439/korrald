// ✅  Emulator-mode configuration — uses the local Firebase Emulator Suite.
//
// Project ID: "demo-korrald"
// The "demo-" prefix tells the Firebase emulator this is a local-only project
// that never touches production servers.  API keys and app IDs are intentionally
// dummy values; the emulator ignores them.
//
// Start the emulator before running the app:
//   firebase emulators:start
//   (or: firebase emulators:start --import=./emulator-data --export-on-exit)

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase options that point exclusively to the local Firebase Emulator Suite.
///
/// All traffic goes to 10.0.2.2 (Android) or localhost (desktop/iOS).
/// No real Firebase project is needed.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
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

  // ── Web ──────────────────────────────────────────────────────────────────
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDemoLocalEmulatorFakeKey000000000',
    appId: '1:000000000000:web:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-korrald',
    storageBucket: 'demo-korrald.firebasestorage.app',
    authDomain: 'demo-korrald.firebaseapp.com',
  );

  // ── Android ──────────────────────────────────────────────────────────────
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDemoLocalEmulatorFakeKey000000000',
    appId: '1:000000000000:android:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-korrald',
    storageBucket: 'demo-korrald.firebasestorage.app',
  );

  // ── iOS ───────────────────────────────────────────────────────────────────
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDemoLocalEmulatorFakeKey000000000',
    appId: '1:000000000000:ios:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-korrald',
    storageBucket: 'demo-korrald.firebasestorage.app',
    iosBundleId: 'com.example.korrald',
  );
}
