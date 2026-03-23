import 'package:flutter/widgets.dart';
import 'package:fpv_overlay_app/infrastructure/services/firebase/analytics_service.dart';

/// A [RouteObserver] that automatically logs screen-view events to Firebase
/// Analytics whenever the visible page changes.
///
/// Register this as a navigator observer in [MaterialApp.navigatorObservers].
class FirebaseRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  final AnalyticsService _analytics = AnalyticsService.instance;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logScreenView(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) _logScreenView(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _logScreenView(newRoute);
  }

  void _logScreenView(Route<dynamic> route) {
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) {
      _analytics.setCurrentScreen(name);
    }
  }
}
