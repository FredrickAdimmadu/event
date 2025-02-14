// File generated by FlutterFire CLI.
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBZSM4Zn50SXPpf1xv_uWfv4U1AKcJmBzI',
    appId: '1:1056062674368:web:18c6e70c12adedb4d26425',
    messagingSenderId: '1056062674368',
    projectId: 'instagram-8be62',
    authDomain: 'instagram-8be62.firebaseapp.com',
    databaseURL: 'https://instagram-8be62-default-rtdb.firebaseio.com',
    storageBucket: 'instagram-8be62.appspot.com',
    measurementId: 'G-MS9RBPMGSY',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDLn7O5-QWtFWxCUBiVOGj_mLRo1EW_1tI',
    appId: '1:1056062674368:android:efc0f27a7772de3ad26425',
    messagingSenderId: '1056062674368',
    projectId: 'instagram-8be62',
    databaseURL: 'https://instagram-8be62-default-rtdb.firebaseio.com',
    storageBucket: 'instagram-8be62.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDdUn6rcRXdWcAOoR6DgbcpVJkOgRSzcp8',
    appId: '1:1056062674368:ios:183f7fab656fdba8d26425',
    messagingSenderId: '1056062674368',
    projectId: 'instagram-8be62',
    databaseURL: 'https://instagram-8be62-default-rtdb.firebaseio.com',
    storageBucket: 'instagram-8be62.appspot.com',
    iosBundleId: 'com.example.event',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDdUn6rcRXdWcAOoR6DgbcpVJkOgRSzcp8',
    appId: '1:1056062674368:ios:8bc852586e8d498cd26425',
    messagingSenderId: '1056062674368',
    projectId: 'instagram-8be62',
    databaseURL: 'https://instagram-8be62-default-rtdb.firebaseio.com',
    storageBucket: 'instagram-8be62.appspot.com',
    iosBundleId: 'com.example.event.RunnerTests',
  );
}
