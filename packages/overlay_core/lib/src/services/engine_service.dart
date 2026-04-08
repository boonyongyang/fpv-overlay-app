import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/overlay_task.dart';

const _uuid = Uuid();
final _segmentStemRe = RegExp(r'^(.*?)(\d+)$');

class EngineService {
  final FileSystem _fileSystem;

  EngineService({FileSystem? fileSystem})
      : _fileSystem = fileSystem ?? const LocalFileSystem();

  Future<List<OverlayTask>> findFilePairs(
    String inputDirPath, {
    bool recursive = false,
  }) async {
    final inputDir = _fileSystem.directory(inputDirPath);
    if (!await inputDir.exists()) {
      throw Exception('Input directory does not exist: $inputDirPath');
    }

    if (!recursive) {
      final List<File> files = [];
      await for (final entity in inputDir.list()) {
        if (entity is File) files.add(entity);
      }
      return _matchFiles(files.map((f) => f.path).toList());
    }

    // Recursive scan: group files by their parent directory so that
    // matching and OSD fallback logic stay scoped per folder.
    final dirGroups = <String, List<String>>{};
    await for (final entity in inputDir.list(recursive: true)) {
      if (entity is File) {
        final dir = p.dirname(entity.path);
        (dirGroups[dir] ??= []).add(entity.path);
      }
    }

    final results = <OverlayTask>[];
    for (final paths in dirGroups.values) {
      results.addAll(await _matchFiles(paths));
    }
    return results;
  }

  Future<List<OverlayTask>> findPairsFromFiles(List<String> filePaths) async {
    return _matchFiles(filePaths);
  }

  Future<List<OverlayTask>> _matchFiles(List<String> filePaths) async {
    final videos = <String, String>{};
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
        tasks.add(
          OverlayTask(
            id: _uuid.v4(),
            videoPath: videos[stem]!,
            status: TaskStatus.missingTelemetry,
          ),
        );
      }
    }

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
