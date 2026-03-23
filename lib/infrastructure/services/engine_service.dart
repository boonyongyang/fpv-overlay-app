import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:fpv_overlay_app/domain/models/overlay_task.dart';

const _uuid = Uuid();

/// Regex to split a DJI-style clip stem into an alpha prefix and numeric suffix.
/// e.g. "DJIG0078" → prefix "DJIG", number 78
final _segmentStemRe = RegExp(r'^(.*?)(\d+)$');

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
    final processedOsdStems = <String>{};

    for (final stem in videos.keys) {
      processedStems.add(stem);
      final hasOsd = osdFiles.containsKey(stem);
      final hasSrt = srtFiles.containsKey(stem);

      // When this clip has no exact-match OSD, look for a preceding segment's
      // OSD file. DJI cameras write a single .osd file for the first segment
      // of a flight even when the recording spans multiple video clips.
      // e.g. DJIG0077.osd covers DJIG0077.mp4 + DJIG0078.mp4 + …
      final String? resolvedOsdPath =
          hasOsd ? osdFiles[stem] : _findPrecedingOsd(stem, osdFiles);

      if (resolvedOsdPath != null) {
        processedOsdStems.add(p.basenameWithoutExtension(resolvedOsdPath));
      }

      if (resolvedOsdPath != null || hasSrt) {
        tasks.add(
          OverlayTask(
            id: _uuid.v4(),
            videoPath: videos[stem]!,
            osdPath: resolvedOsdPath,
            srtPath: hasSrt ? srtFiles[stem]! : null,
            status: TaskStatus.pending,
          ),
        );
      } else {
        // Orphan video – waiting for telemetry to be linked.
        tasks.add(
          OverlayTask(
            id: _uuid.v4(),
            videoPath: videos[stem]!,
            status: TaskStatus.missingTelemetry,
          ),
        );
      }
    }

    // Orphan telemetry files – waiting for a video to be linked.
    for (final stem in srtFiles.keys) {
      if (!processedStems.contains(stem)) {
        tasks.add(
          OverlayTask(
            id: _uuid.v4(),
            srtPath: srtFiles[stem]!,
            status: TaskStatus.missingVideo,
          ),
        );
      }
    }
    for (final stem in osdFiles.keys) {
      if (!processedStems.contains(stem) && !processedOsdStems.contains(stem)) {
        tasks.add(
          OverlayTask(
            id: _uuid.v4(),
            osdPath: osdFiles[stem]!,
            status: TaskStatus.missingVideo,
          ),
        );
      }
    }

    return tasks;
  }

  /// Finds the nearest preceding OSD file for a video stem that has no
  /// exact-match OSD (e.g. DJIG0078 → falls back to DJIG0077.osd).
  ///
  /// Strategy:
  ///   1. Parse [videoStem] into an alpha prefix + numeric index.
  ///   2. From [osdFiles], keep only OSD stems with the same prefix.
  ///   3. Return the path for the largest numeric index that is < [videoStem]'s index.
  String? _findPrecedingOsd(String videoStem, Map<String, String> osdFiles) {
    if (osdFiles.isEmpty) return null;

    final videoMatch = _segmentStemRe.firstMatch(videoStem);
    if (videoMatch == null) return null;

    final videoPrefix = videoMatch.group(1)!;
    final videoIndex = int.parse(videoMatch.group(2)!);

    String? bestStem;
    int bestIndex = -1;

    for (final osdStem in osdFiles.keys) {
      final osdMatch = _segmentStemRe.firstMatch(osdStem);
      if (osdMatch == null) continue;
      if (osdMatch.group(1) != videoPrefix) continue;

      final osdIndex = int.parse(osdMatch.group(2)!);
      if (osdIndex < videoIndex && osdIndex > bestIndex) {
        bestIndex = osdIndex;
        bestStem = osdStem;
      }
    }

    return bestStem != null ? osdFiles[bestStem] : null;
  }
}
