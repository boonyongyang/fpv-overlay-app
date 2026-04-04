import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/overlay_task.dart';
import '../models/task_addition_result.dart';

final _taskPlannerSegmentStemRe = RegExp(r'^(.*?)(\d+)$');
const _plannerUuid = Uuid();

class OverlayTaskPlanner {
  final FileSystem _fileSystem;

  OverlayTaskPlanner({FileSystem? fileSystem})
      : _fileSystem = fileSystem ?? const LocalFileSystem();

  OverlayTask createManualTask({
    required String videoPath,
    required String overlayPath,
  }) {
    final ext = p.extension(overlayPath).toLowerCase();
    return OverlayTask(
      id: _plannerUuid.v4(),
      videoPath: videoPath,
      osdPath: ext == '.osd' ? overlayPath : null,
      srtPath: ext == '.srt' ? overlayPath : null,
    );
  }

  TaskAdditionResult mergeIncoming(
    List<OverlayTask> existingTasks,
    List<OverlayTask> incoming,
  ) {
    int addedCount = 0;
    int duplicateCount = 0;
    int partialCount = 0;

    for (final newTask in incoming) {
      final newStem = newTask.stem;
      bool handled = false;

      for (final existing in existingTasks) {
        if (existing.stem != newStem) continue;

        if (existing.status == TaskStatus.pending ||
            existing.status == TaskStatus.processing ||
            existing.status == TaskStatus.completed) {
          bool merged = false;
          if (existing.osdPath == null && newTask.osdPath != null) {
            existing.osdPath = newTask.osdPath;
            merged = true;
          }
          if (existing.srtPath == null && newTask.srtPath != null) {
            existing.srtPath = newTask.srtPath;
            merged = true;
          }
          if (merged) {
            addedCount++;
          } else {
            duplicateCount++;
          }
          handled = true;
          break;
        }

        if (existing.status == TaskStatus.missingTelemetry) {
          bool gotTelemetry = false;
          if (newTask.osdPath != null) {
            existing.osdPath = newTask.osdPath;
            gotTelemetry = true;
          }
          if (newTask.srtPath != null) {
            existing.srtPath = newTask.srtPath;
            gotTelemetry = true;
          }
          if (gotTelemetry) {
            existing.status = TaskStatus.pending;
            addedCount++;
          } else {
            duplicateCount++;
          }
          handled = true;
          break;
        }

        if (existing.status == TaskStatus.missingVideo &&
            newTask.videoPath != null) {
          existing.videoPath = newTask.videoPath;
          if (newTask.osdPath != null) existing.osdPath = newTask.osdPath;
          if (newTask.srtPath != null) existing.srtPath = newTask.srtPath;
          existing.status = TaskStatus.pending;
          addedCount++;
          handled = true;
          break;
        }
      }

      if (!handled) {
        existingTasks.add(newTask);
        if (newTask.status == TaskStatus.pending) {
          addedCount++;
        } else {
          partialCount++;
        }
      }
    }

    final fallbackResolvedCount = applyPrecedingOsdFallbacks(existingTasks);
    if (fallbackResolvedCount > 0) {
      addedCount += fallbackResolvedCount;
      partialCount = partialCount > fallbackResolvedCount
          ? partialCount - fallbackResolvedCount
          : 0;
    }

    return TaskAdditionResult(
      addedCount: addedCount,
      duplicateCount: duplicateCount,
      partialCount: partialCount,
    );
  }

  void updateTaskFiles(
    List<OverlayTask> tasks,
    String taskId, {
    String? videoPath,
    String? overlayPath,
  }) {
    final index = tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = tasks[index];
    if (videoPath != null) task.videoPath = videoPath;
    if (overlayPath != null) {
      final ext = p.extension(overlayPath).toLowerCase();
      if (ext == '.osd') {
        task.osdPath = overlayPath;
      } else if (ext == '.srt') {
        task.srtPath = overlayPath;
      }
    }

    if (task.videoPath != null &&
        (task.osdPath != null || task.srtPath != null)) {
      task.status = TaskStatus.pending;
    }

    applyPrecedingOsdFallbacks(tasks);
  }

  int applyPrecedingOsdFallbacks(List<OverlayTask> tasks) {
    final candidates = <_OsdCandidate>[];
    for (final task in tasks) {
      final osdPath = task.osdPath;
      if (osdPath == null || osdPath.isEmpty) continue;

      final stem = p.basenameWithoutExtension(osdPath);
      final match = _taskPlannerSegmentStemRe.firstMatch(stem);
      if (match == null) continue;

      candidates.add(
        _OsdCandidate(
          path: osdPath,
          directory: p.dirname(osdPath),
          prefix: match.group(1)!,
          index: int.parse(match.group(2)!),
        ),
      );
    }

    int resolvedCount = 0;
    for (final task in tasks) {
      if (!_canAutoAttachOsd(task)) continue;

      final videoPath = task.videoPath!;
      final match = _taskPlannerSegmentStemRe
          .firstMatch(p.basenameWithoutExtension(videoPath));
      if (match == null) continue;

      final videoDirectory = p.dirname(videoPath);
      final videoPrefix = match.group(1)!;
      final videoIndex = int.parse(match.group(2)!);

      _OsdCandidate? bestCandidate;
      for (final candidate in candidates) {
        if (candidate.directory != videoDirectory ||
            candidate.prefix != videoPrefix) {
          continue;
        }

        final isBetterExactMatch = candidate.index == videoIndex;
        final isBetterFallback = candidate.index < videoIndex &&
            (bestCandidate == null || candidate.index > bestCandidate.index);

        if (isBetterExactMatch || isBetterFallback) {
          bestCandidate = candidate;
        }

        if (isBetterExactMatch) break;
      }

      if (bestCandidate == null) continue;

      task.osdPath = bestCandidate.path;
      if (task.videoPath != null &&
          (task.osdPath != null || task.srtPath != null)) {
        task.status = TaskStatus.pending;
      }
      resolvedCount++;
    }

    if (resolvedCount > 0) {
      final consumedOsdPaths = tasks
          .where((t) => t.videoPath != null && t.osdPath != null)
          .map((t) => t.osdPath!)
          .toSet();
      tasks.removeWhere(
        (task) =>
            task.videoPath == null &&
            task.status == TaskStatus.missingVideo &&
            task.osdPath != null &&
            task.srtPath == null &&
            consumedOsdPaths.contains(task.osdPath),
      );
    }

    return resolvedCount;
  }

  String getUniqueOutputPath(String directory, String filename) {
    final name = p.basenameWithoutExtension(filename);
    final ext = p.extension(filename);
    String outputPath = p.join(directory, '$name$ext');
    int counter = 1;

    while (_fileSystem.file(outputPath).existsSync()) {
      outputPath = p.join(directory, '${name}_$counter$ext');
      counter++;
    }
    return outputPath;
  }

  bool _canAutoAttachOsd(OverlayTask task) {
    if (task.videoPath == null || task.osdPath != null) return false;

    switch (task.status) {
      case TaskStatus.pending:
      case TaskStatus.failed:
      case TaskStatus.missingTelemetry:
        return true;
      case TaskStatus.processing:
      case TaskStatus.completed:
      case TaskStatus.cancelled:
      case TaskStatus.missingVideo:
        return false;
    }
  }
}

class _OsdCandidate {
  final String path;
  final String directory;
  final String prefix;
  final int index;

  const _OsdCandidate({
    required this.path,
    required this.directory,
    required this.prefix,
    required this.index,
  });
}
