import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Thin singleton wrapper around [FirebaseCrashlytics].
///
/// All methods are no-ops when Firebase has not been initialised (e.g. during
/// unit tests), making the service safe to call from any layer without
/// needing to mock Firebase in tests.
class CrashlyticsService {
  CrashlyticsService._();

  static final CrashlyticsService instance = CrashlyticsService._();

  // Lazy accessor – returns null if Firebase is not yet initialised.
  FirebaseCrashlytics? get _client {
    try {
      return FirebaseCrashlytics.instance;
    } catch (_) {
      return null;
    }
  }

  /// Dynamically enable or disable Crashlytics collection.
  /// Called when the user toggles the analytics opt-out setting.
  Future<void> setEnabled(bool enabled) async {
    await _client?.setCrashlyticsCollectionEnabled(enabled);
  }

  /// Attach an arbitrary key-value pair to subsequent crash reports.
  Future<void> setCustomKey(String key, Object value) async {
    await _client?.setCustomKey(key, value);
  }

  /// Write a breadcrumb message visible in the next crash report.
  Future<void> log(String message) async {
    await _client?.log(message);
  }

  /// Record a non-fatal [error] with its [stack] trace.
  Future<void> recordError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
  }) async {
    await _client?.recordError(error, stack, fatal: fatal);
  }
}
