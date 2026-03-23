import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fpv_overlay_app/domain/models/local_overlay_stats.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';
import 'package:fpv_overlay_app/infrastructure/services/local_stats_service.dart';

void main() {
  late LocalStatsService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = LocalStatsService();
  });

  test('empty load returns zeroed snapshot', () async {
    final snapshot = await service.loadStats();

    expect(snapshot.totalRuns, 0);
    expect(snapshot.totalCompletedRuns, 0);
    expect(snapshot.recentRuns, isEmpty);
  });

  test('save and load round-trips persisted stats', () async {
    final snapshot = OverlayStatsSnapshot(
      totalCompletedRuns: 2,
      totalFailedRuns: 1,
      totalCancelledRuns: 1,
      totalSrtRuns: 1,
      totalOsdRuns: 1,
      totalCombinedRuns: 2,
      totalTimedRuns: 4,
      totalRenderTime: const Duration(seconds: 240),
      lastCompletedAt: DateTime.parse('2026-03-08T10:00:00Z'),
      recentRuns: [
        RecentOverlayRun(
          timestamp: DateTime.parse('2026-03-08T10:00:00Z'),
          sourceName: 'DJIG0025.mp4',
          status: TaskStatus.completed,
          overlayType: OverlayType.combined,
          renderDuration: const Duration(seconds: 55),
          outputPath: '/out/DJIG0025_overlay.mp4',
        ),
      ],
    );

    await service.saveStats(snapshot);
    final loaded = await service.loadStats();

    expect(loaded.totalCompletedRuns, 2);
    expect(loaded.totalFailedRuns, 1);
    expect(loaded.totalTimedRuns, 4);
    expect(loaded.totalRenderTime, const Duration(seconds: 240));
    expect(loaded.recentRuns, hasLength(1));
    expect(loaded.recentRuns.first.sourceName, 'DJIG0025.mp4');
  });

  test('clear removes persisted stats', () async {
    await service.saveStats(
      const OverlayStatsSnapshot(totalCompletedRuns: 3),
    );

    await service.clearStats();
    final loaded = await service.loadStats();

    expect(loaded.totalRuns, 0);
    expect(loaded.recentRuns, isEmpty);
  });
}
