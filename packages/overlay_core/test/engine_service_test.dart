import 'package:file/memory.dart';
import 'package:overlay_core/overlay_core.dart';
import 'package:test/test.dart';

void main() {
  late MemoryFileSystem fs;
  late EngineService service;

  setUp(() {
    fs = MemoryFileSystem();
    service = EngineService(fileSystem: fs);
  });

  group('EngineService', () {
    test('matches simple video and srt pairs', () async {
      fs.file('/data/DJI_001.mp4').createSync(recursive: true);
      fs.file('/data/DJI_001.srt')
        ..createSync()
        ..writeAsStringSync('dummy content');

      final tasks = await service.findFilePairs('/data');

      expect(tasks.length, 1);
      expect(tasks.first.status, TaskStatus.pending);
      expect(tasks.first.type, OverlayType.srt);
      expect(tasks.first.videoPath, '/data/DJI_001.mp4');
      expect(tasks.first.srtPath, '/data/DJI_001.srt');
    });

    test('creates a combined task when both OSD and SRT exist', () async {
      fs.file('/data/DJIG0040.mp4').createSync(recursive: true);
      fs.file('/data/DJIG0040.osd')
        ..createSync()
        ..writeAsStringSync('osd');
      fs.file('/data/DJIG0040.srt')
        ..createSync()
        ..writeAsStringSync('srt');

      final tasks = await service.findFilePairs('/data');

      expect(tasks.length, 1);
      expect(tasks.first.type, OverlayType.combined);
    });

    test('reuses preceding OSD for a later split segment', () async {
      fs.file('/data/DJIG0077.mp4').createSync(recursive: true);
      fs.file('/data/DJIG0077.osd')
        ..createSync()
        ..writeAsStringSync('osd');
      fs.file('/data/DJIG0078.mp4').createSync();
      fs.file('/data/DJIG0078.srt')
        ..createSync()
        ..writeAsStringSync('srt');

      final tasks = await service.findFilePairs('/data');
      final task78 = tasks.firstWhere((t) => t.videoPath!.contains('0078'));

      expect(task78.type, OverlayType.combined);
      expect(task78.osdPath, '/data/DJIG0077.osd');
      expect(task78.srtPath, '/data/DJIG0078.srt');
    });
  });
}
