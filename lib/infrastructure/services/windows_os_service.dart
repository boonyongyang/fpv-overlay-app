import 'package:local_notifier/local_notifier.dart';
import 'package:windows_taskbar/windows_taskbar.dart';

import 'package:fpv_overlay_app/domain/services/os_service.dart';

class WindowsOsService implements OsService {
  @override
  void updateBadge(int count) {
    // Windows doesn't have a simple numeric badge.
    // We could use an overlay icon, but it requires an asset path.
  }

  @override
  void updateDockProgress(double progress) {
    WindowsTaskbar.setProgressMode(TaskbarProgressMode.normal);
    WindowsTaskbar.setProgress((progress * 100).toInt(), 100);
  }

  @override
  void resetDockProgress() {
    WindowsTaskbar.setProgressMode(TaskbarProgressMode.noProgress);
  }

  @override
  Future<void> showNotification({
    required String title,
    required String body,
    bool silent = false,
  }) async {
    final notification = LocalNotification(
      title: title,
      body: body,
      silent: silent,
    );
    await notification.show();
  }

  @override
  Future<double?> getCpuUsage() async => null;
}
