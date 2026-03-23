import 'package:flutter/foundation.dart';

import 'package:fpv_overlay_app/domain/models/local_overlay_stats.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';
import 'package:fpv_overlay_app/infrastructure/services/local_stats_service.dart';

class LocalStatsProvider extends ChangeNotifier {
  LocalStatsProvider({required LocalStatsService localStatsService})
      : _localStatsService = localStatsService;

  static const _maxRecentRuns = 50;

  final LocalStatsService _localStatsService;

  OverlayStatsSnapshot _snapshot = const OverlayStatsSnapshot();
  bool _isLoading = true;

  OverlayStatsSnapshot get snapshot => _snapshot;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _snapshot = await _localStatsService.loadStats();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> clearStats() async {
    _snapshot = const OverlayStatsSnapshot();
    await _localStatsService.clearStats();
    notifyListeners();
  }

  Future<void> recordRun(OverlayTask task) async {
    if (!_shouldRecord(task)) return;

    final recentRun = RecentOverlayRun(
      timestamp: task.endTime ?? DateTime.now(),
      sourceName: task.videoFileName,
      status: task.status,
      overlayType: task.type,
      renderDuration: task.duration,
      outputPath: task.status == TaskStatus.completed ? task.outputPath : null,
      failureCode: task.failure?.code,
      failureSummary: task.failure?.summary,
    );

    final recentRuns = [recentRun, ..._snapshot.recentRuns]
        .take(_maxRecentRuns)
        .toList(growable: false);

    _snapshot = _snapshot.copyWith(
      totalCompletedRuns: _snapshot.totalCompletedRuns +
          (task.status == TaskStatus.completed ? 1 : 0),
      totalFailedRuns: _snapshot.totalFailedRuns +
          (task.status == TaskStatus.failed ? 1 : 0),
      totalCancelledRuns: _snapshot.totalCancelledRuns +
          (task.status == TaskStatus.cancelled ? 1 : 0),
      totalSrtRuns:
          _snapshot.totalSrtRuns + (task.type == OverlayType.srt ? 1 : 0),
      totalOsdRuns:
          _snapshot.totalOsdRuns + (task.type == OverlayType.osd ? 1 : 0),
      totalCombinedRuns: _snapshot.totalCombinedRuns +
          (task.type == OverlayType.combined ? 1 : 0),
      totalTimedRuns:
          _snapshot.totalTimedRuns + (task.duration == null ? 0 : 1),
      totalRenderTime:
          _snapshot.totalRenderTime + (task.duration ?? Duration.zero),
      lastCompletedAt: task.status == TaskStatus.completed
          ? (task.endTime ?? DateTime.now())
          : _snapshot.lastCompletedAt,
      recentRuns: recentRuns,
    );

    await _localStatsService.saveStats(_snapshot);
    notifyListeners();
  }

  bool _shouldRecord(OverlayTask task) {
    if (task.startTime == null) return false;
    return task.status == TaskStatus.completed ||
        task.status == TaskStatus.failed ||
        task.status == TaskStatus.cancelled;
  }
}
