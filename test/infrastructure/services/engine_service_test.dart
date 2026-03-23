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
      expect(tasks.first.srtPath, '/data/DJI_001.srt');
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
      expect(tasks.first.osdPath, isNull);
      expect(tasks.first.srtPath, isNull);
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
      expect(tasks.first.osdPath, '/data/DJI_003.osd');
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

    test(
        'Should create one combined task when both OSD and SRT exist for same clip',
        () async {
      // DJI O3/O4 cameras produce both an .osd and an .srt for every clip.
      // They must be baked into a SINGLE output MP4, not two separate files.
      // Arrange
      fs.file('/data/DJIG0040.mp4').createSync(recursive: true);
      fs.file('/data/DJIG0040.osd')
        ..createSync()
        ..writeAsStringSync('osd content');
      fs.file('/data/DJIG0040.srt')
        ..createSync()
        ..writeAsStringSync('srt content');

      // Act
      final tasks = await service.findFilePairs('/data');

      // Assert: one combined task
      expect(tasks.length, 1);
      final task = tasks.first;
      expect(task.type, OverlayType.combined);
      expect(task.status, TaskStatus.pending);
      expect(task.videoPath, '/data/DJIG0040.mp4');
      expect(task.osdPath, '/data/DJIG0040.osd');
      expect(task.srtPath, '/data/DJIG0040.srt');
    });
  });

  group('EngineService - Segment OSD fallback (DJI multi-clip flights)', () {
    // DJI FPV cameras split long flights into consecutive video segments
    // (e.g. DJIG0077.mp4, DJIG0078.mp4) but write a SINGLE .osd file
    // named after the first segment. The engine must automatically reuse
    // that OSD file for subsequent clips that have no exact-match OSD.

    test('Should reuse preceding OSD for next segment when only SRT exists',
        () async {
      fs.file('/data/DJIG0077.mp4').createSync(recursive: true);
      fs.file('/data/DJIG0077.osd')
        ..createSync()
        ..writeAsStringSync('osd');
      fs.file('/data/DJIG0077.srt')
        ..createSync()
        ..writeAsStringSync('srt');
      fs.file('/data/DJIG0078.mp4').createSync();
      fs.file('/data/DJIG0078.srt')
        ..createSync()
        ..writeAsStringSync('srt');

      final tasks = await service.findFilePairs('/data');
      final task78 = tasks.firstWhere((t) => t.videoPath!.contains('0078'));

      expect(task78.status, TaskStatus.pending);
      expect(task78.type, OverlayType.combined);
      // Should reuse DJIG0077.osd
      expect(task78.osdPath, '/data/DJIG0077.osd');
      expect(task78.srtPath, '/data/DJIG0078.srt');
    });

    test('Should reuse preceding OSD when second clip has no telemetry at all',
        () async {
      fs.file('/data/DJIG0077.mp4').createSync(recursive: true);
      fs.file('/data/DJIG0077.osd')
        ..createSync()
        ..writeAsStringSync('osd');
      fs.file('/data/DJIG0078.mp4').createSync();
      // No DJIG0078.osd, no DJIG0078.srt

      final tasks = await service.findFilePairs('/data');
      final task78 = tasks.firstWhere((t) => t.videoPath!.contains('0078'));

      expect(task78.status, TaskStatus.pending);
      expect(task78.type, OverlayType.osd);
      expect(task78.osdPath, '/data/DJIG0077.osd');
    });

    test('Should use exact-match OSD over fallback when both exist', () async {
      fs.file('/data/DJIG0077.mp4').createSync(recursive: true);
      fs.file('/data/DJIG0077.osd')
        ..createSync()
        ..writeAsStringSync('osd77');
      fs.file('/data/DJIG0078.mp4').createSync();
      fs.file('/data/DJIG0078.osd')
        ..createSync()
        ..writeAsStringSync('osd78');

      final tasks = await service.findFilePairs('/data');
      final task78 = tasks.firstWhere((t) => t.videoPath!.contains('0078'));

      expect(task78.osdPath, '/data/DJIG0078.osd');
    });

    test('Should not reuse OSD from a different prefix (different camera)',
        () async {
      // FOO0001.osd should NOT be reused for BAR0002.mp4
      fs.file('/data/BAR0002.mp4').createSync(recursive: true);
      fs.file('/data/FOO0001.osd')
        ..createSync()
        ..writeAsStringSync('osd');

      final tasks = await service.findFilePairs('/data');
      final taskBar = tasks.first;

      expect(taskBar.status, TaskStatus.missingTelemetry);
      expect(taskBar.osdPath, isNull);
    });

    test('Should pick nearest (highest) preceding OSD across multiple segments',
        () async {
      // Flight: 0075.osd, 0076.osd all present. 0079 has no OSD → should use 0078 fallback.
      // But here 0076 and 0077 exist; 0079 has no OSD → closest is 0077.
      fs.file('/data/DJIG0075.mp4').createSync(recursive: true);
      fs.file('/data/DJIG0075.osd')
        ..createSync()
        ..writeAsStringSync('osd75');
      fs.file('/data/DJIG0077.osd')
        ..createSync()
        ..writeAsStringSync('osd77');
      fs.file('/data/DJIG0079.mp4').createSync();

      final tasks = await service.findFilePairs('/data');
      final task79 = tasks.firstWhere((t) => t.videoPath!.contains('0079'));

      // Should pick the closest preceding OSD (0077), not 0075
      expect(task79.osdPath, '/data/DJIG0077.osd');
    });

    test('Should not emit an orphan OSD task when that OSD is already reused',
        () async {
      fs.file('/data/DJIG0077.osd')
        ..createSync(recursive: true)
        ..writeAsStringSync('osd77');
      fs.file('/data/DJIG0078.mp4').createSync();

      final tasks = await service.findFilePairs('/data');

      expect(tasks.length, 1);
      expect(tasks.first.status, TaskStatus.pending);
      expect(tasks.first.type, OverlayType.osd);
      expect(tasks.first.videoPath, '/data/DJIG0078.mp4');
      expect(tasks.first.osdPath, '/data/DJIG0077.osd');
    });

    test('Should match multiple flights in one folder independently', () async {
      fs.file('/data/DJIG0024.mp4').createSync(recursive: true);
      fs.file('/data/DJIG0024.osd')
        ..createSync()
        ..writeAsStringSync('osd24');
      fs.file('/data/DJIG0024.srt')
        ..createSync()
        ..writeAsStringSync('srt24');
      fs.file('/data/DJIG0025.mp4').createSync();
      fs.file('/data/DJIG0025.srt')
        ..createSync()
        ..writeAsStringSync('srt25');
      fs.file('/data/DJIG0030.mp4').createSync();
      fs.file('/data/DJIG0030.osd')
        ..createSync()
        ..writeAsStringSync('osd30');
      fs.file('/data/DJIG0030.srt')
        ..createSync()
        ..writeAsStringSync('srt30');

      final tasks = await service.findFilePairs('/data');

      expect(tasks.length, 3);

      final task25 = tasks.firstWhere((t) => t.videoPath!.contains('0025'));
      expect(task25.type, OverlayType.combined);
      expect(task25.osdPath, '/data/DJIG0024.osd');
      expect(task25.srtPath, '/data/DJIG0025.srt');

      final task30 = tasks.firstWhere((t) => t.videoPath!.contains('0030'));
      expect(task30.type, OverlayType.combined);
      expect(task30.osdPath, '/data/DJIG0030.osd');
      expect(task30.srtPath, '/data/DJIG0030.srt');
    });
  });
}
