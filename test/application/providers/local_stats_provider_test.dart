import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fpv_overlay_app/application/providers/local_stats_provider.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';
import 'package:fpv_overlay_app/domain/models/task_failure.dart';
import 'package:fpv_overlay_app/infrastructure/services/local_stats_service.dart';

void main() {
  late LocalStatsProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    provider = LocalStatsProvider(localStatsService: LocalStatsService());
    await provider.load();
  });

  OverlayTask buildTask({
    required String id,
    required TaskStatus status,
    required OverlayType type,
    Duration duration = const Duration(seconds: 30),
    String? failureCode,
    String? failureSummary,
  }) {
    final task = OverlayTask(
      id: id,
      videoPath: '/data/$id.mp4',
      osdPath: type == OverlayType.osd || type == OverlayType.combined
          ? '/data/$id.osd'
          : null,
      srtPath: type == OverlayType.srt || type == OverlayType.combined
          ? '/data/$id.srt'
          : null,
      status: status,
    );
    task.startTime = DateTime.parse('2026-03-08T10:00:00Z');
    task.endTime = task.startTime!.add(duration);
    task.outputPath = '/out/${id}_overlay.mp4';
    if (failureCode != null || failureSummary != null) {
      task.failure = TaskFailure(
        code: failureCode ?? 'ERR',
        summary: failureSummary ?? 'Failed',
        details: failureSummary ?? 'Failed',
      );
    }
    return task;
  }

  test('records completed failed and cancelled runs correctly', () async {
    await provider.recordRun(
      buildTask(
        id: 'completed',
        status: TaskStatus.completed,
        type: OverlayType.combined,
        duration: const Duration(seconds: 60),
      ),
    );
    await provider.recordRun(
      buildTask(
        id: 'failed',
        status: TaskStatus.failed,
        type: OverlayType.osd,
        failureCode: 'RENDER_FAIL',
        failureSummary: 'Render failed',
      ),
    );
    await provider.recordRun(
      buildTask(
        id: 'cancelled',
        status: TaskStatus.cancelled,
        type: OverlayType.srt,
        duration: const Duration(seconds: 10),
      ),
    );

    expect(provider.snapshot.totalCompletedRuns, 1);
    expect(provider.snapshot.totalFailedRuns, 1);
    expect(provider.snapshot.totalCancelledRuns, 1);
    expect(provider.snapshot.totalCombinedRuns, 1);
    expect(provider.snapshot.totalOsdRuns, 1);
    expect(provider.snapshot.totalSrtRuns, 1);
    expect(provider.snapshot.totalRenderTime, const Duration(seconds: 100));
    expect(
      provider.snapshot.averageRenderTime,
      const Duration(milliseconds: 33333),
    );
    expect(provider.snapshot.recentRuns, hasLength(3));
    expect(provider.snapshot.recentRuns.first.sourceName, 'cancelled.mp4');
  });

  test('caps recent history at 50 runs and keeps newest first', () async {
    for (var i = 0; i < 55; i++) {
      await provider.recordRun(
        buildTask(
          id: 'run_$i',
          status: TaskStatus.completed,
          type: OverlayType.srt,
          duration: const Duration(seconds: 5),
        ),
      );
    }

    expect(provider.snapshot.recentRuns, hasLength(50));
    expect(provider.snapshot.recentRuns.first.sourceName, 'run_54.mp4');
    expect(provider.snapshot.recentRuns.last.sourceName, 'run_5.mp4');
  });

  test('does not record tasks that never started processing', () async {
    final task = OverlayTask(
      id: 'not_started',
      videoPath: '/data/not_started.mp4',
      srtPath: '/data/not_started.srt',
      status: TaskStatus.failed,
    );

    await provider.recordRun(task);

    expect(provider.snapshot.totalRuns, 0);
  });

  test('clearStats resets counters without touching config storage', () async {
    await provider.recordRun(
      buildTask(
        id: 'completed',
        status: TaskStatus.completed,
        type: OverlayType.srt,
      ),
    );

    await provider.clearStats();

    expect(provider.snapshot.totalRuns, 0);
    expect(provider.snapshot.recentRuns, isEmpty);
  });
}
