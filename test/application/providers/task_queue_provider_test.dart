import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpv_overlay_app/application/providers/task_queue_provider.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';
import 'package:fpv_overlay_app/infrastructure/services/engine_service.dart';
import 'package:fpv_overlay_app/infrastructure/services/command_runner_service.dart';
import 'package:fpv_overlay_app/domain/services/os_service.dart';

class MockEngineService extends Mock implements EngineService {}

class MockCommandRunnerService extends Mock implements CommandRunnerService {}

class MockOsService extends Mock implements OsService {}

void main() {
  late TaskQueueProvider provider;
  late MockEngineService mockEngine;
  late MockCommandRunnerService mockRunner;
  late MockOsService mockOs;

  setUp(() {
    mockEngine = MockEngineService();
    mockRunner = MockCommandRunnerService();
    mockOs = MockOsService();

    provider = TaskQueueProvider(
      engineService: mockEngine,
      commandRunnerService: mockRunner,
      osService: mockOs,
    );

    // Setup default behavior for OsService
    when(() => mockOs.updateBadge(any())).thenReturn(null);
    when(() => mockOs.updateDockProgress(any())).thenReturn(null);
    when(() => mockOs.resetDockProgress()).thenReturn(null);
  });

  group('TaskQueueProvider - Task Management', () {
    test('Should add manual tasks correctly', () {
      provider.addManualTask(
        videoPath: '/path/video.mp4',
        overlayPath: '/path/audio.srt',
        type: OverlayType.srt,
      );

      expect(provider.tasks.length, 1);
      expect(provider.tasks.first.type, OverlayType.srt);
      expect(provider.tasks.first.status, TaskStatus.pending);
      verify(() => mockOs.updateBadge(1)).called(1);
    });

    test('Should merge partial tasks with same stem', () async {
      // 1. Add an orphan video
      final orphanVideo = OverlayTask(
        id: '1',
        videoPath: '/data/flight01.mp4',
        status: TaskStatus.missingTelemetry,
      );

      when(() => mockEngine.findPairsFromFiles(any()))
          .thenAnswer((_) async => [orphanVideo]);

      await provider.addTasksFromFiles(['/data/flight01.mp4']);
      expect(provider.tasks.length, 1);
      expect(provider.tasks.first.status, TaskStatus.missingTelemetry);

      // 2. Add the matching telemetry later
      final incomingSrt = OverlayTask(
        id: '2',
        overlayPath: '/data/flight01.srt',
        type: OverlayType.srt,
        status: TaskStatus.missingVideo,
      );

      when(() => mockEngine.findPairsFromFiles(any()))
          .thenAnswer((_) async => [incomingSrt]);

      final result = await provider.addTasksFromFiles(['/data/flight01.srt']);

      // Should have merged into the existing task
      expect(provider.tasks.length, 1);
      expect(provider.tasks.first.status, TaskStatus.pending);
      expect(provider.tasks.first.overlayPath, '/data/flight01.srt');
      expect(result.addedCount, 1);
      expect(result.partialCount, 0);
    });

    test('Should remove tasks correctly', () {
      provider.addManualTask(
        videoPath: 'v',
        overlayPath: 'o',
        type: OverlayType.srt,
      );
      final id = provider.tasks.first.id;

      provider.removeTask(id);
      expect(provider.tasks, isEmpty);
      verify(() => mockOs.updateBadge(1)).called(1);
      verify(() => mockOs.updateBadge(0)).called(1);
    });
  });
}
