import 'package:flutter/foundation.dart';

import 'package:fpv_overlay_app/domain/services/os_service.dart';

class PlaceholderOsService implements OsService {
  @override
  void updateBadge(int count) {}

  @override
  void updateDockProgress(double progress) {}

  @override
  void resetDockProgress() {}

  @override
  Future<void> showNotification({
    required String title,
    required String body,
    bool silent = false,
  }) async {
    debugPrint('Notification: $title – $body');
  }

  @override
  Future<double?> getCpuUsage() async => null;
}
