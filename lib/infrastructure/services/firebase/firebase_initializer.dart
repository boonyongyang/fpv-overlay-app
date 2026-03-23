import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Bootstraps Firebase and wires up Crashlytics as the global Flutter error
/// handler so any unhandled exceptions are captured automatically.
///
/// Crashlytics collection is only enabled in release builds; this prevents
/// cluttering the Firebase console with noise from development sessions.
class FirebaseInitializer {
  FirebaseInitializer._();

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();

      final crashlytics = FirebaseCrashlytics.instance;
      await crashlytics.setCrashlyticsCollectionEnabled(kReleaseMode);

      // Forward Flutter framework errors to Crashlytics.
      FlutterError.onError = crashlytics.recordFlutterFatalError;

      // Forward Dart async errors that escape the Flutter framework.
      PlatformDispatcher.instance.onError = (error, stack) {
        crashlytics.recordError(error, stack, fatal: true);
        return true;
      };
    } catch (e) {
      debugPrint(
        '⚠️ Firebase initialization failed (not configured?): $e\n'
        'The app will run without analytics and crash reporting.',
      );
    }
  }
}
