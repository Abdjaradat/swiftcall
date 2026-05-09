// File generated from google-services.json — project: swiftcall-eec90
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCdgXV1HjMLgJ6_QEnQR_H5mE-Mww_qc3I',
    appId: '1:1082599622155:android:d5762cba3ab4883bdce90e',
    messagingSenderId: '1082599622155',
    projectId: 'swiftcall-eec90',
    storageBucket: 'swiftcall-eec90.firebasestorage.app',
  );

  // iOS config — will be filled after running on iOS / adding GoogleService-Info.plist
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCdgXV1HjMLgJ6_QEnQR_H5mE-Mww_qc3I',
    appId: '1:1082599622155:ios:000000000000000dce90e',
    messagingSenderId: '1082599622155',
    projectId: 'swiftcall-eec90',
    storageBucket: 'swiftcall-eec90.firebasestorage.app',
    iosClientId: 'YOUR_IOS_CLIENT_ID',
    iosBundleId: 'com.swiftcall.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCdgXV1HjMLgJ6_QEnQR_H5mE-Mww_qc3I',
    appId: '1:1082599622155:web:000000000000000dce90e',
    messagingSenderId: '1082599622155',
    projectId: 'swiftcall-eec90',
    authDomain: 'swiftcall-eec90.firebaseapp.com',
    storageBucket: 'swiftcall-eec90.firebasestorage.app',
  );
}
