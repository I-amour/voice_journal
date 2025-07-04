// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
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
        return windows;
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
    apiKey: 'AIzaSyAPPwkWYXI2i3ldNxA4kPvyL7wOCRV1efs',
    appId: '1:1035142586824:web:4c39242a72b6a0199120fd',
    messagingSenderId: '1035142586824',
    projectId: 'voice-journal-94069',
    authDomain: 'voice-journal-94069.firebaseapp.com',
    storageBucket: 'voice-journal-94069.firebasestorage.app',
    measurementId: 'G-BM8QS4K61N',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAGQvQUmCnp0qGw8X8wXNXy07X_jaXd-vg',
    appId: '1:1035142586824:android:cc40ae7b01cda2c19120fd',
    messagingSenderId: '1035142586824',
    projectId: 'voice-journal-94069',
    storageBucket: 'voice-journal-94069.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCIkMWlFswX_WbbGOmUy9oTk56iUdcViCA',
    appId: '1:1035142586824:ios:074554994e5b6bc79120fd',
    messagingSenderId: '1035142586824',
    projectId: 'voice-journal-94069',
    storageBucket: 'voice-journal-94069.firebasestorage.app',
    iosBundleId: 'com.simi.calm',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCIkMWlFswX_WbbGOmUy9oTk56iUdcViCA',
    appId: '1:1035142586824:ios:b2e5ce337203de469120fd',
    messagingSenderId: '1035142586824',
    projectId: 'voice-journal-94069',
    storageBucket: 'voice-journal-94069.firebasestorage.app',
    iosBundleId: 'com.example.voiceJournal',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAPPwkWYXI2i3ldNxA4kPvyL7wOCRV1efs',
    appId: '1:1035142586824:web:1acfd3bd5b8f3dd59120fd',
    messagingSenderId: '1035142586824',
    projectId: 'voice-journal-94069',
    authDomain: 'voice-journal-94069.firebaseapp.com',
    storageBucket: 'voice-journal-94069.firebasestorage.app',
    measurementId: 'G-1ZMK0XY59V',
  );
}
