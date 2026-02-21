import 'package:flutter_test/flutter_test.dart';
import 'package:file/memory.dart';
import 'package:fpv_overlay_app/infrastructure/services/engine_service.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';

void main() {
  late MemoryFileSystem fs;
  late EngineService service;

  setUp(() {
    fs = MemoryFileSystem();
    service = EngineService(fileSystem: fs);
  });

  group('EngineService - File Matching', () {
    test('Should match simple video and srt pairs', () async {
      // Arrange
      fs.file('/data/DJI_001.mp4').createSync(recursive: true);
      fs.file('/data/DJI_001.srt').createSync();
      fs.file('/data/DJI_001.srt').writeAsStringSync('dummy content');

      // Act
      final tasks = await service.findFilePairs('/data');

      // Assert
      expect(tasks.length, 1);
      expect(tasks.first.status, TaskStatus.pending);
      expect(tasks.first.type, OverlayType.srt);
      expect(tasks.first.videoPath, '/data/DJI_001.mp4');
      expect(tasks.first.overlayPath, '/data/DJI_001.srt');
    });

    test('Should identify orphan videos (missing telemetry)', () async {
      // Arrange
      fs.file('/data/DJI_002.mp4').createSync(recursive: true);

      // Act
      final tasks = await service.findFilePairs('/data');

      // Assert
      expect(tasks.length, 1);
      expect(tasks.first.status, TaskStatus.missingTelemetry);
      expect(tasks.first.videoPath, '/data/DJI_002.mp4');
      expect(tasks.first.overlayPath, isNull);
    });

    test('Should identify orphan telemetry (missing video)', () async {
      // Arrange
      fs.file('/data/DJI_003.osd').createSync(recursive: true);
      fs.file('/data/DJI_003.osd').writeAsStringSync('dummy');

      // Act
      final tasks = await service.findFilePairs('/data');

      // Assert
      expect(tasks.length, 1);
      expect(tasks.first.status, TaskStatus.missingVideo);
      expect(tasks.first.type, OverlayType.osd);
      expect(tasks.first.overlayPath, '/data/DJI_003.osd');
    });

    test('Should ignore empty telemetry files', () async {
      // Arrange
      fs.file('/data/DJI_004.mp4').createSync(recursive: true);
      fs.file('/data/DJI_004.srt').createSync(); // 0 bytes

      // Act
      final tasks = await service.findFilePairs('/data');

      // Assert
      // Should be treated as orphan video because srt is 0 bytes
      expect(tasks.length, 1);
      expect(tasks.first.status, TaskStatus.missingTelemetry);
    });
  });
}
