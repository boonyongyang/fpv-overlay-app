import 'dart:async';
import 'dart:io';

import 'package:fpv_overlay_app/domain/models/overlay_task.dart';
import 'package:fpv_overlay_app/infrastructure/services/firebase/analytics_service.dart';

/// Centralised telemetry facade.
///
/// All methods are fire-and-forget – callers do not need to `await` them.
/// Analytics calls are silently skipped when [setEnabled] is `false`,
/// which also makes business-logic tests trivially clean without mocking.
class Telemetry {
  Telemetry._();

  static bool _enabled = true;

  static void setEnabled(bool enabled) => _enabled = enabled;

  static AnalyticsService get _analytics => AnalyticsService.instance;

  // -----------------------------------------------------------------
  // App Lifecycle Events
  // -----------------------------------------------------------------

  /// Fired once on every cold start.
  static void appLaunched({required String appVersion}) {
    if (!_enabled) return;
    unawaited(
      _analytics.logEvent(
        'app_launched',
        parameters: {
          'platform': Platform.operatingSystem,
          'os_version': Platform.operatingSystemVersion,
          'app_version': appVersion,
        },
      ),
    );
  }

  // -----------------------------------------------------------------
  // UI Interaction Events
  // -----------------------------------------------------------------

  static void tappedButton(String buttonId) {
    if (!_enabled) return;
    unawaited(
      _analytics.logEvent(
        'ui_button_tap',
        parameters: {'button_id': buttonId},
      ),
    );
  }

  static void switchedTab(int index, String name) {
    if (!_enabled) return;
    unawaited(
      _analytics.logEvent(
        'ui_tab_switched',
        parameters: {'index': index, 'name': name},
      ),
    );
  }

  // -----------------------------------------------------------------
  // Settings / Preference Events
  // -----------------------------------------------------------------

  static void changedSetting(String key, Object value) {
    if (!_enabled) return;
    unawaited(
      _analytics.logEvent(
        'setting_changed',
        parameters: {'key': key, 'value': value.toString()},
      ),
    );
  }

  // -----------------------------------------------------------------
  // File Discovery Events
  // -----------------------------------------------------------------

  /// Fired after a folder scan completes.
  static void folderScanned({
    required int videosFound,
    required int matchesMade,
    required int orphanCount,
  }) {
    if (!_enabled) return;
    unawaited(
      _analytics.logEvent(
        'folder_scanned',
        parameters: {
          'videos_found': videosFound,
          'matches_made': matchesMade,
          'orphan_count': orphanCount,
        },
      ),
    );
  }

  /// Fired when user drops files via drag-and-drop.
  static void filesDropped(int fileCount) {
    if (!_enabled) return;
    unawaited(
      _analytics.logEvent(
        'files_dropped',
        parameters: {'file_count': fileCount},
      ),
    );
  }

  /// Fired when an orphan task is completed by linking a missing file.
  static void taskLinked(String taskId, String linkedFileType) {
    if (!_enabled) return;
    unawaited(
      _analytics.logEvent(
        'task_linked',
        parameters: {'task_id': taskId, 'linked_type': linkedFileType},
      ),
    );
  }

  // -----------------------------------------------------------------
  // Task Lifecycle Events
  // -----------------------------------------------------------------

  static void taskAdded(OverlayTask task) {
    if (!_enabled) return;
    unawaited(
      _analytics.logEvent(
        'task_added',
        parameters: {
          'task_id': task.id,
          'type': task.type.name,
          'has_video': task.videoPath != null,
          'has_overlay': task.osdPath != null || task.srtPath != null,
        },
      ),
    );
  }

  static void queueStarted(int totalTasks) {
    if (!_enabled) return;
    unawaited(
      _analytics.logEvent(
        'queue_started',
        parameters: {'total_tasks': totalTasks},
      ),
    );
  }

  static void taskProcessing(String taskId) {
    if (!_enabled) return;
    unawaited(
      _analytics.logEvent(
        'task_processing',
        parameters: {'task_id': taskId},
      ),
    );
  }

  static void taskCompleted(OverlayTask task, int durationSec) {
    if (!_enabled) return;
    unawaited(
      _analytics.logEvent(
        'task_completed',
        parameters: {
          'task_id': task.id,
          'type': task.type.name,
          'duration_sec': durationSec,
        },
      ),
    );
  }

  static void taskFailed(String taskId, String error) {
    if (!_enabled) return;
    unawaited(
      _analytics.logEvent(
        'task_failed',
        parameters: {'task_id': taskId, 'error': error},
      ),
    );
  }

  static void taskRemoved(String taskId) {
    if (!_enabled) return;
    unawaited(
      _analytics.logEvent(
        'task_removed',
        parameters: {'task_id': taskId},
      ),
    );
  }

  static void taskCancelled(String taskId) {
    if (!_enabled) return;
    unawaited(
      _analytics.logEvent(
        'task_cancelled',
        parameters: {'task_id': taskId},
      ),
    );
  }

  /// Fired when the entire queue finishes (all tasks processed or cancelled).
  static void queueCompleted({
    required int totalTasks,
    required int completedCount,
    required int failedCount,
    required int cancelledCount,
    required int totalDurationSec,
  }) {
    if (!_enabled) return;
    unawaited(
      _analytics.logEvent(
        'queue_completed',
        parameters: {
          'total_tasks': totalTasks,
          'completed': completedCount,
          'failed': failedCount,
          'cancelled': cancelledCount,
          'total_duration_sec': totalDurationSec,
        },
      ),
    );
  }

  // -----------------------------------------------------------------
  // Performance & System Events
  // -----------------------------------------------------------------

  static void cpuUsage(double percent) {
    if (!_enabled) return;
    unawaited(
      _analytics.logEvent(
        'system_cpu_usage',
        parameters: {'percent': percent},
      ),
    );
  }
}
