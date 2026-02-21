import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:macos_dock_progress/macos_dock_progress.dart';
import 'package:fpv_overlay_app/domain/services/os_service.dart';

class MacOSOsService implements OsService {
  @override
  void updateBadge(int count) {
    AppBadgePlus.updateBadge(count);
  }

  @override
  void updateDockProgress(double progress) {
    DockProgress.setProgress(progress);
  }

  @override
  void resetDockProgress() {
    DockProgress.resetProgress();
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
}
