import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';

class EngineService {
  final FileSystem _fileSystem;

  EngineService({FileSystem? fileSystem})
      : _fileSystem = fileSystem ?? const LocalFileSystem();

  /// Scans a directory and returns a list of OverlayTasks based on matching
  /// video files and their corresponding .srt or .osd telemetry files.
  Future<List<OverlayTask>> findFilePairs(String inputDirPath) async {
    final inputDir = _fileSystem.directory(inputDirPath);
    if (!await inputDir.exists()) {
      throw Exception('Input directory does not exist: $inputDirPath');
    }

    final List<File> files = [];
    await for (final entity in inputDir.list()) {
      if (entity is File) files.add(entity);
    }

    return _matchFiles(files.map((f) => f.path).toList());
  }

  Future<List<OverlayTask>> findPairsFromFiles(List<String> filePaths) async {
    return _matchFiles(filePaths);
  }

  Future<List<OverlayTask>> _matchFiles(List<String> filePaths) async {
    final videos = <String, String>{}; // Maps file stem to full path
    final srtFiles = <String, String>{};
    final osdFiles = <String, String>{};

    for (final path in filePaths) {
      final extension = p.extension(path).toLowerCase();
      final stem = p.basenameWithoutExtension(path);

      if (extension == '.mp4' || extension == '.mov') {
        videos[stem] = path;
      } else if (extension == '.srt') {
        final stat = await _fileSystem.file(path).stat();
        if (stat.size > 0) {
          srtFiles[stem] = path;
        }
      } else if (extension == '.osd') {
        final stat = await _fileSystem.file(path).stat();
        if (stat.size > 0) {
          osdFiles[stem] = path;
        }
      }
    }

    final tasks = <OverlayTask>[];
    final processedStems = <String>{};

    for (final stem in videos.keys) {
      processedStems.add(stem);
      if (osdFiles.containsKey(stem)) {
        tasks.add(OverlayTask(
          id: DateTime.now().microsecondsSinceEpoch.toString() + stem,
          videoPath: videos[stem]!,
          overlayPath: osdFiles[stem]!,
          type: OverlayType.osd,
          status: TaskStatus.pending,
        ));
      } else if (srtFiles.containsKey(stem)) {
        tasks.add(OverlayTask(
          id: DateTime.now().microsecondsSinceEpoch.toString() + stem,
          videoPath: videos[stem]!,
          overlayPath: srtFiles[stem]!,
          type: OverlayType.srt,
          status: TaskStatus.pending,
        ));
      } else {
        // Orphan Video
        tasks.add(OverlayTask(
          id: DateTime.now().microsecondsSinceEpoch.toString() + stem,
          videoPath: videos[stem]!,
          status: TaskStatus.missingTelemetry,
        ));
      }
    }

    // Check for orphan telemetry files
    for (final stem in srtFiles.keys) {
      if (!processedStems.contains(stem)) {
        tasks.add(OverlayTask(
          id: DateTime.now().microsecondsSinceEpoch.toString() + stem,
          overlayPath: srtFiles[stem]!,
          type: OverlayType.srt,
          status: TaskStatus.missingVideo,
        ));
      }
    }
    for (final stem in osdFiles.keys) {
      if (!processedStems.contains(stem)) {
        tasks.add(OverlayTask(
          id: DateTime.now().microsecondsSinceEpoch.toString() + stem,
          overlayPath: osdFiles[stem]!,
          type: OverlayType.osd,
          status: TaskStatus.missingVideo,
        ));
      }
    }

    return tasks;
  }
}
