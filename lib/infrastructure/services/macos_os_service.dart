import 'dart:io';

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

  @override
  Future<double?> getCpuUsage() async {
    try {
      final result = await Process.run('ps', ['-A', '-o', '%cpu']);
      if (result.exitCode == 0) {
        return (result.stdout as String).split('\n').skip(1).fold<double>(0.0,
            (total, line) {
          return total + (double.tryParse(line.trim()) ?? 0.0);
        });
      }
    } catch (_) {}
    return null;
  }
}
