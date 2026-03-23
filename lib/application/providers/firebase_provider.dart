import 'package:flutter/widgets.dart';
import 'package:fpv_overlay_app/infrastructure/services/firebase/analytics_service.dart';
import 'package:fpv_overlay_app/infrastructure/services/firebase/crashlytics_service.dart';

/// Exposes the Firebase service singletons to the widget tree via
/// [InheritedWidget].
///
/// Prefer accessing Firebase services directly through their `.instance`
/// getters in business-logic code. This provider exists so widgets can
/// retrieve the services without importing infrastructure packages directly.
class FirebaseProvider extends InheritedWidget {
  const FirebaseProvider({required super.child, super.key});

  AnalyticsService get analytics => AnalyticsService.instance;
  CrashlyticsService get crashlytics => CrashlyticsService.instance;

  static FirebaseProvider of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<FirebaseProvider>();
    assert(provider != null, 'No FirebaseProvider found in widget tree.');
    return provider!;
  }

  @override
  bool updateShouldNotify(FirebaseProvider oldWidget) => false;
}
