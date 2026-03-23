import 'package:flutter_test/flutter_test.dart';

import 'package:fpv_overlay_app/domain/services/telemetry.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';

// Helper to build a minimal [OverlayTask] for testing.
OverlayTask _sampleTask({
  String id = 'test_task_1',
  String? videoPath = '/video/flight.mp4',
  String? srtPath = '/video/flight.srt',
  String? outputPath,
}) {
  final task = OverlayTask(
    id: id,
    videoPath: videoPath,
    srtPath: srtPath,
  );
  if (outputPath != null) task.outputPath = outputPath;
  return task;
}

void main() {
  // Ensure Telemetry is disabled globally so no Firebase initialisation is
  // required.  Individual groups can override this if needed.
  setUpAll(() => Telemetry.setEnabled(false));
  tearDownAll(() => Telemetry.setEnabled(true));

  group('Telemetry – enabled guard', () {
    test('all methods are no-ops when disabled', () {
      // All calls should return immediately without throwing.
      Telemetry.appLaunched(appVersion: '1.0.0');
      Telemetry.tappedButton('test_btn');
      Telemetry.switchedTab(0, 'Queue');
      Telemetry.changedSetting('key', 'value');
      Telemetry.folderScanned(videosFound: 3, matchesMade: 2, orphanCount: 1);
      Telemetry.filesDropped(5);
      Telemetry.taskLinked('id', 'telemetry');
      Telemetry.taskAdded(_sampleTask());
      Telemetry.queueStarted(2);
      Telemetry.taskProcessing('id');
      Telemetry.taskCompleted(_sampleTask(), 30);
      Telemetry.taskFailed('id', 'err');
      Telemetry.taskRemoved('id');
      Telemetry.taskCancelled('id');
      Telemetry.queueCompleted(
        totalTasks: 3,
        completedCount: 2,
        failedCount: 1,
        cancelledCount: 0,
        totalDurationSec: 90,
      );
      Telemetry.cpuUsage(42.0);
      // If we reach here, the guard is working.
    });

    test('setEnabled toggles the flag without throwing', () {
      Telemetry.setEnabled(true);
      Telemetry.setEnabled(false);
    });
  });

  group('Telemetry – method signatures', () {
    // Verify every public method accepts the expected types and does not throw
    // when disabled (which is the state set by setUpAll above).

    test('appLaunched accepts app version string', () {
      Telemetry.appLaunched(appVersion: '1.0.0');
    });

    test('tappedButton accepts a string button-id', () {
      Telemetry.tappedButton('start_queue');
    });

    test('switchedTab accepts int index and string name', () {
      Telemetry.switchedTab(1, 'System Info');
    });

    test('changedSetting accepts key and Object value', () {
      Telemetry.changedSetting('theme', 'dark');
      Telemetry.changedSetting('font_size', 14);
      Telemetry.changedSetting('analytics_enabled', false);
    });

    test('folderScanned accepts file count metrics', () {
      Telemetry.folderScanned(videosFound: 10, matchesMade: 8, orphanCount: 2);
    });

    test('filesDropped accepts file count', () {
      Telemetry.filesDropped(4);
    });

    test('taskLinked accepts task id and linked type', () {
      Telemetry.taskLinked('task_1', 'video');
      Telemetry.taskLinked('task_2', 'telemetry');
    });

    test('taskAdded accepts an OverlayTask', () {
      Telemetry.taskAdded(_sampleTask());
    });

    test('queueStarted accepts the total task count', () {
      Telemetry.queueStarted(5);
    });

    test('taskCompleted accepts a task and duration in seconds', () {
      final task = _sampleTask(outputPath: '/out/flight_overlay.mp4');
      Telemetry.taskCompleted(task, 120);
    });

    test('taskFailed accepts a task-id and error string', () {
      Telemetry.taskFailed('task_42', 'ffmpeg exited with code 1');
    });

    test('taskRemoved accepts a task-id', () {
      Telemetry.taskRemoved('task_42');
    });

    test('taskCancelled accepts a task-id', () {
      Telemetry.taskCancelled('task_42');
    });

    test('queueCompleted accepts batch summary metrics', () {
      Telemetry.queueCompleted(
        totalTasks: 5,
        completedCount: 4,
        failedCount: 1,
        cancelledCount: 0,
        totalDurationSec: 300,
      );
    });

    test('cpuUsage accepts a percentage double', () {
      Telemetry.cpuUsage(73.5);
    });
  });
}
