// File generated manually from google-services.json and GoogleService-Info.plist
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web not supported.');
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

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA3knUZy2xUIh4IVTjH9G0zsciAs_bYNFI',
    appId: '1:138045122903:android:1923bbe401ffbc57253612',
    messagingSenderId: '138045122903',
    projectId: 'punyadaan-e0972',
    storageBucket: 'punyadaan-e0972.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBHLJ41nljLGwOPKKXf7gu_YENmzXxrZDE',
    appId: '1:138045122903:ios:bebd957ac0b868b3253612',
    messagingSenderId: '138045122903',
    projectId: 'punyadaan-e0972',
    storageBucket: 'punyadaan-e0972.firebasestorage.app',
    iosBundleId: 'com.example.punyadaan',
  );
}
