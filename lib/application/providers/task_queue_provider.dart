import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:fpv_overlay_app/application/providers/local_stats_provider.dart';
import 'package:fpv_overlay_app/domain/models/app_configuration.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';
import 'package:fpv_overlay_app/domain/models/task_addition_result.dart';
import 'package:fpv_overlay_app/domain/services/task_failure_parser.dart';
import 'package:uuid/uuid.dart';

import 'package:fpv_overlay_app/infrastructure/services/engine_service.dart';
import 'package:fpv_overlay_app/infrastructure/services/command_runner_service.dart';
import 'package:fpv_overlay_app/domain/services/os_service.dart';

final _segmentStemRe = RegExp(r'^(.*?)(\d+)$');

class TaskQueueProvider extends ChangeNotifier {
  final EngineService _engineService;
  final CommandRunnerService _commandRunnerService;
  final OsService _osService;
  final LocalStatsProvider _localStatsProvider;

  final List<OverlayTask> _tasks = [];
  bool _isProcessing = false;
  bool _cancelRequested = false;
  bool _clearAfterCancel = false;

  TaskQueueProvider({
    required EngineService engineService,
    required CommandRunnerService commandRunnerService,
    required OsService osService,
    required LocalStatsProvider localStatsProvider,
  })  : _engineService = engineService,
        _commandRunnerService = commandRunnerService,
        _osService = osService,
        _localStatsProvider = localStatsProvider;

  List<OverlayTask> get tasks => List.unmodifiable(_tasks);
  bool get isProcessing => _isProcessing;
  bool get isCancelling => _cancelRequested;
  bool get willClearAfterCancel => _clearAfterCancel;

  void addTask(OverlayTask task) {
    _tasks.add(task);
    _updateDockState();
    notifyListeners();
  }

  void addManualTask({
    required String videoPath,
    required String overlayPath,
  }) {
    final ext = p.extension(overlayPath).toLowerCase();
    final task = OverlayTask(
      id: const Uuid().v4(),
      videoPath: videoPath,
      osdPath: ext == '.osd' ? overlayPath : null,
      srtPath: ext == '.srt' ? overlayPath : null,
    );
    addTask(task);
  }

  Future<TaskAdditionResult> addTasksFromDirectory(String directoryPath) async {
    final incoming = await _engineService.findFilePairs(directoryPath);
    return _processNewTasks(incoming);
  }

  Future<TaskAdditionResult> addTasksFromFiles(List<String> filePaths) async {
    final incoming = await _engineService.findPairsFromFiles(filePaths);
    return _processNewTasks(incoming);
  }

  TaskAdditionResult _processNewTasks(List<OverlayTask> incoming) {
    int addedCount = 0;
    int duplicateCount = 0;
    int partialCount = 0;

    for (final newTask in incoming) {
      final newStem = newTask.stem;
      bool handled = false;

      // Try to merge with an existing task that shares the same video stem.
      for (final existing in _tasks) {
        if (existing.stem != newStem) continue;

        // Active or finished task: absorb any new overlay type it is missing
        // (e.g. user later drops an SRT for a video that already has OSD queued).
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

        // Merge: existing has video but no telemetry, new task supplies overlay(s).
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

        // Merge: existing has telemetry but no video, new task supplies video.
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
        _tasks.add(newTask);
        if (newTask.status == TaskStatus.pending) {
          addedCount++;
        } else {
          partialCount++;
        }
      }
    }

    final fallbackResolvedCount = _applyPrecedingOsdFallbacks();
    if (fallbackResolvedCount > 0) {
      addedCount += fallbackResolvedCount;
      partialCount = partialCount > fallbackResolvedCount
          ? partialCount - fallbackResolvedCount
          : 0;
    }

    if (addedCount > 0 || partialCount > 0 || incoming.isNotEmpty) {
      _updateDockState();
      notifyListeners();
    }

    return TaskAdditionResult(
      addedCount: addedCount,
      duplicateCount: duplicateCount,
      partialCount: partialCount,
    );
  }

  void updateTaskFiles(
    String taskId, {
    String? videoPath,
    String? overlayPath,
  }) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = _tasks[index];
    if (videoPath != null) task.videoPath = videoPath;
    if (overlayPath != null) {
      final ext = p.extension(overlayPath).toLowerCase();
      if (ext == '.osd') {
        task.osdPath = overlayPath;
      } else if (ext == '.srt') {
        task.srtPath = overlayPath;
      }
    }

    // Auto-resolve status when video and at least one overlay are present.
    if (task.videoPath != null &&
        (task.osdPath != null || task.srtPath != null)) {
      task.status = TaskStatus.pending;
    }

    _applyPrecedingOsdFallbacks();
    _updateDockState();
    notifyListeners();
  }

  void removeTask(String id) {
    _tasks.removeWhere((t) => t.id == id && t.status != TaskStatus.processing);
    _updateDockState();
    notifyListeners();
  }

  void cancelQueue() {
    if (!_isProcessing || _cancelRequested) return;
    _cancelRequested = true;
    _commandRunnerService.cancelCurrentTask();
    notifyListeners();
  }

  void cancelAndClearAll() {
    if (_tasks.isEmpty) return;
    if (_isProcessing) {
      _clearAfterCancel = true;
      if (_cancelRequested) {
        notifyListeners();
      } else {
        cancelQueue();
      }
      return;
    }

    clearAll();
  }

  void clearCompleted() {
    _tasks.removeWhere(
      (t) =>
          t.status == TaskStatus.completed || t.status == TaskStatus.cancelled,
    );
    _updateDockState();
    notifyListeners();
  }

  void clearAll() {
    _tasks.removeWhere((t) => t.status != TaskStatus.processing);
    _updateDockState();
    notifyListeners();
  }

  void _updateDockState() {
    final pendingCount =
        _tasks.where((t) => t.status != TaskStatus.completed).length;
    _osService.updateBadge(pendingCount);

    if (_isProcessing) {
      _osService.updateDockProgress(0.5);
    } else {
      _osService.resetDockProgress();
    }
  }

  int _applyPrecedingOsdFallbacks() {
    final candidates = <_OsdCandidate>[];
    for (final task in _tasks) {
      final osdPath = task.osdPath;
      if (osdPath == null || osdPath.isEmpty) continue;

      final stem = p.basenameWithoutExtension(osdPath);
      final match = _segmentStemRe.firstMatch(stem);
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
    for (final task in _tasks) {
      if (!_canAutoAttachOsd(task)) continue;

      final videoPath = task.videoPath!;
      final match =
          _segmentStemRe.firstMatch(p.basenameWithoutExtension(videoPath));
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
      final consumedOsdPaths = _tasks
          .where((t) => t.videoPath != null && t.osdPath != null)
          .map((t) => t.osdPath!)
          .toSet();
      _tasks.removeWhere(
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

  String _getUniqueOutputPath(String directory, String filename) {
    final name = p.basenameWithoutExtension(filename);
    final ext = p.extension(filename);
    String outputPath = p.join(directory, '$name$ext');
    int counter = 1;

    while (File(outputPath).existsSync()) {
      outputPath = p.join(directory, '${name}_$counter$ext');
      counter++;
    }
    return outputPath;
  }

  // ── Progress parsing ────────────────────────────────────────────────────

  static final _osdFrameRe = RegExp(r'OSD frame (\d+)/(\d+)');
  static final _compositingRe = RegExp(r'Compositing:\s*(\d+)%');
  static final _renderingRe = RegExp(r'Rendering:\s*(\d+)%');

  void _appendSystemLog(OverlayTask task, String message) {
    final timestamp = DateTime.now().toIso8601String();
    task.logs.add('[$timestamp] $message');
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  /// Parses a log line and updates [task.progress] and [task.progressPhase].
  ///
  /// For OSD / combined tasks the budget is:
  ///   Pass 1 (OSD frame rendering)  → 0 % – 70 %
  ///   Pass 2 (FFmpeg compositing)   → 70 % – 100 %
  ///
  /// For SRT-only tasks the single FFmpeg render maps to 0 % – 100 %.
  void _updateProgress(OverlayTask task, String line) {
    // OSD frame rendering (Pass 1): "  OSD frame 601/3027 (9%)"
    final osdMatch = _osdFrameRe.firstMatch(line);
    if (osdMatch != null) {
      final current = int.parse(osdMatch.group(1)!);
      final total = int.parse(osdMatch.group(2)!);
      if (total > 0) {
        task.progress = (current / total) * 0.7;
        task.progressPhase = 'Rendering OSD frames';
      }
      return;
    }

    // Pass 1 done
    if (line.contains('Pass 1 complete')) {
      task.progress = 0.7;
      task.progressPhase = 'Compositing video';
      return;
    }

    // Pass 2 compositing: "  Compositing: 85%"
    final compMatch = _compositingRe.firstMatch(line);
    if (compMatch != null) {
      final pct = int.parse(compMatch.group(1)!);
      task.progress = 0.7 + (pct / 100) * 0.3;
      task.progressPhase = 'Compositing video';
      return;
    }

    // SRT rendering: "  Rendering: 45%"
    final renderMatch = _renderingRe.firstMatch(line);
    if (renderMatch != null) {
      final pct = int.parse(renderMatch.group(1)!);
      task.progress = pct / 100;
      task.progressPhase = 'Rendering SRT overlay';
      return;
    }

    // Phase label updates (no progress value change)
    if (line.contains('Starting OSD HD Rendering') ||
        line.contains('Applying OSD HD Rendering')) {
      task.progressPhase = 'Preparing OSD rendering';
    } else if (line.contains('Pass 2:')) {
      task.progressPhase = 'Compositing video';
    } else if (line.contains('Rendering SRT HUD')) {
      task.progressPhase = 'Rendering SRT overlay';
    } else if (line.contains('Parsing SRT telemetry')) {
      task.progressPhase = 'Parsing SRT telemetry';
    }
  }

  Future<void> startQueue(AppConfiguration config, String outputDir) async {
    if (_isProcessing) return;
    _isProcessing = true;
    _cancelRequested = false;
    _updateDockState();
    notifyListeners();

    for (int i = 0; i < _tasks.length; i++) {
      if (_cancelRequested) break;

      final task = _tasks[i];
      if (task.status == TaskStatus.pending ||
          task.status == TaskStatus.failed) {
        task.status = TaskStatus.processing;
        task.startTime = DateTime.now();
        task.cpuUsageAtStart = await _osService.getCpuUsage();
        task.logs.clear();
        task.errorMessage = null;
        task.failure = null;
        task.progress = 0.0;
        task.progressPhase = null;
        notifyListeners();

        try {
          final stem = p.basenameWithoutExtension(task.videoFileName);
          final preferredPath = '${stem}_overlay.mp4';
          task.outputPath = _getUniqueOutputPath(outputDir, preferredPath);
          _appendSystemLog(
            task,
            '▶ Queue starting task ${i + 1}/${_tasks.length} · ${task.type.name.toUpperCase()}',
          );
          _appendSystemLog(task, '▸ Video: ${task.videoPath ?? 'Missing'}');
          if (task.osdPath != null) {
            _appendSystemLog(task, '▸ OSD: ${task.osdPath}');
          }
          if (task.srtPath != null) {
            _appendSystemLog(task, '▸ SRT: ${task.srtPath}');
          }
          _appendSystemLog(task, '◎ Output: ${task.outputPath!}');

          final stream =
              _commandRunnerService.executeTask(task, config, task.outputPath!);

          await for (final line in stream) {
            task.logs.add(line);
            _updateProgress(task, line);
            if (line.contains('time=')) continue;
            notifyListeners();
          }

          task.endTime = DateTime.now();

          if (_cancelRequested) {
            task.status = TaskStatus.cancelled;
            task.progress = 0.0;
            _appendSystemLog(task, '⏹ Task cancelled by user request.');
          } else if (task.logs.isNotEmpty &&
              task.logs.last.contains('✅ Process completed successfully')) {
            task.status = TaskStatus.completed;
            task.progress = 1.0;
            _appendSystemLog(
              task,
              '✓ Task completed in ${_formatDuration(task.duration ?? Duration.zero)}.',
            );
            _appendSystemLog(
              task,
              '★ Result ready at ${task.outputPath ?? 'unknown output path'}.',
            );

            unawaited(
              _osService.showNotification(
                title: 'Overlay Finished',
                body: '${task.videoFileName} is ready!',
                silent: true,
              ),
            );
          } else {
            task.status = TaskStatus.failed;
            task.failure = TaskFailureParser.fromLogs(task.logs);
            task.errorMessage = task.failure!.summary;
            _appendSystemLog(task, '✖ Task failed: ${task.failure!.summary}');
            debugPrint(task.logs.join('\n'));
          }
        } catch (e, st) {
          task.endTime = DateTime.now();
          task.status = TaskStatus.failed;
          task.failure =
              TaskFailureParser.fromException(e, st, logs: task.logs);
          task.errorMessage = task.failure!.summary;
          _appendSystemLog(
            task,
            '⚠ Unhandled failure: ${task.failure!.summary}',
          );
          debugPrint('Task failed: ${task.id}\n$e\n$st');
        }

        unawaited(_localStatsProvider.recordRun(task));
        _updateDockState();
        notifyListeners();
        if (_cancelRequested) break;
      }
    }

    final shouldClearAfterCancel = _clearAfterCancel;
    _isProcessing = false;
    _cancelRequested = false;
    _clearAfterCancel = false;

    if (shouldClearAfterCancel) {
      _tasks.clear();
      _updateDockState();
      notifyListeners();
      return;
    }

    final completedCount =
        _tasks.where((t) => t.status == TaskStatus.completed).length;

    if (completedCount > 0) {
      unawaited(
        _osService.showNotification(
          title: 'Queue Completed',
          body: 'Successfully processed $completedCount videos.',
        ),
      );
    }

    _updateDockState();
    notifyListeners();
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
