abstract class OsService {
  void updateBadge(int count);
  void updateDockProgress(double progress);
  void resetDockProgress();
  Future<void> showNotification({
    required String title,
    required String body,
    bool silent = false,
  });
}
