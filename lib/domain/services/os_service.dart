abstract class OsService {
  void updateBadge(int count);
  void updateDockProgress(double progress);
  void resetDockProgress();
  Future<void> showNotification({
    required String title,
    required String body,
    bool silent = false,
  });

  /// Returns the current total CPU usage as a percentage, or null if
  /// unsupported on the current platform.
  Future<double?> getCpuUsage();
}
