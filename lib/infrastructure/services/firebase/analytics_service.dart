import 'package:firebase_analytics/firebase_analytics.dart';

/// Thin singleton wrapper around [FirebaseAnalytics].
///
/// All methods are no-ops when Firebase has not been initialised (e.g. during
/// unit tests), making the service safe to call from any layer without
/// needing to mock Firebase in tests.
class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  // Lazy accessor – returns null if Firebase is not yet initialised.
  FirebaseAnalytics? get _client {
    try {
      return FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  Future<void> logEvent(
    String name, {
    Map<String, Object?>? parameters,
  }) async {
    await _client?.logEvent(name: name, parameters: parameters);
  }

  Future<void> setUserId(String id) async {
    await _client?.setUserId(id: id);
  }

  Future<void> setUserProperty(String name, String value) async {
    await _client?.setUserProperty(name: name, value: value);
  }

  Future<void> setCurrentScreen(String screenName) async {
    await _client?.logScreenView(screenName: screenName);
  }
}
