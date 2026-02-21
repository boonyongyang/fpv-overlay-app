import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:fpv_overlay_app/domain/models/app_configuration.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';
import 'package:fpv_overlay_app/domain/models/task_addition_result.dart';
import 'package:fpv_overlay_app/infrastructure/services/engine_service.dart';
import 'package:fpv_overlay_app/infrastructure/services/command_runner_service.dart';
import 'package:fpv_overlay_app/domain/services/os_service.dart';

class TaskQueueProvider extends ChangeNotifier {
  final EngineService _engineService;
  final CommandRunnerService _commandRunnerService;
  final OsService _osService;

  final List<OverlayTask> _tasks = [];
  bool _isProcessing = false;

  TaskQueueProvider({
    required EngineService engineService,
    required CommandRunnerService commandRunnerService,
    required OsService osService,
  })  : _engineService = engineService,
        _commandRunnerService = commandRunnerService,
        _osService = osService;

  List<OverlayTask> get tasks => List.unmodifiable(_tasks);
  bool get isProcessing => _isProcessing;

  void addTask(OverlayTask task) {
    _tasks.add(task);
    _updateDockState();
    notifyListeners();
  }

  void addManualTask({
    required String videoPath,
    required String overlayPath,
    required OverlayType type,
  }) {
    final task = OverlayTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      videoPath: videoPath,
      overlayPath: overlayPath,
      type: type,
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

      // Try to merge with existing tasks with the same stem
      for (final existing in _tasks) {
        if (existing.stem == newStem) {
          // If existing is already pending/completed, skip incoming subset
          if (existing.status == TaskStatus.pending ||
              existing.status == TaskStatus.processing ||
              existing.status == TaskStatus.completed) {
            duplicateCount++;
            handled = true;
            break;
          }

          // Case 0: Exact same file paths already in an incomplete task
          if ((existing.videoPath == newTask.videoPath &&
                  newTask.videoPath != null) ||
              (existing.overlayPath == newTask.overlayPath &&
                  newTask.overlayPath != null)) {
            duplicateCount++;
            handled = true;
            break;
          }

          // Case 1: Merge missing telemetry with incoming telemetry
          if (existing.status == TaskStatus.missingTelemetry &&
              newTask.overlayPath != null) {
            existing.overlayPath = newTask.overlayPath;
            existing.type = newTask.type;
            existing.status = TaskStatus.pending;
            addedCount++;
            handled = true;
            break;
          }

          // Case 2: Merge missing video with incoming video
          if (existing.status == TaskStatus.missingVideo &&
              newTask.videoPath != null) {
            existing.videoPath = newTask.videoPath;
            existing.status = TaskStatus.pending;
            addedCount++;
            handled = true;
            break;
          }
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

  void updateTaskFiles(String taskId,
      {String? videoPath, String? overlayPath}) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = _tasks[index];
    if (videoPath != null) task.videoPath = videoPath;
    if (overlayPath != null) {
      task.overlayPath = overlayPath;
      final ext = p.extension(overlayPath).toLowerCase();
      if (ext == '.srt') {
        task.type = OverlayType.srt;
      } else if (ext == '.osd') {
        task.type = OverlayType.osd;
      }
    }

    // Auto-resolve status if both paths are now present
    if (task.videoPath != null && task.overlayPath != null) {
      task.status = TaskStatus.pending;
    }

    notifyListeners();
  }

  void removeTask(String id) {
    _tasks.removeWhere((t) => t.id == id && t.status != TaskStatus.processing);
    _updateDockState();
    notifyListeners();
  }

  void clearCompleted() {
    _tasks.removeWhere((t) => t.status == TaskStatus.completed);
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

  Future<double?> _getCPUUsage() async {
    try {
      // macOS specific command to get total CPU usage %
      final result = await Process.run('ps', ['-A', '-o', '%cpu']);
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).split('\n');
        double total = 0.0;
        for (var line in lines.skip(1)) {
          final val = double.tryParse(line.trim());
          if (val != null) total += val;
        }
        return total;
      }
    } catch (_) {}
    return null;
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

  Future<void> startQueue(AppConfiguration config, String outputDir) async {
    if (_isProcessing) return;
    _isProcessing = true;
    _updateDockState();
    notifyListeners();

    for (int i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      if (task.status == TaskStatus.pending ||
          task.status == TaskStatus.failed) {
        task.status = TaskStatus.processing;
        task.startTime = DateTime.now();
        task.cpuUsageAtStart = await _getCPUUsage();
        task.logs.clear();
        task.errorMessage = null;
        task.progress = 0.0;
        notifyListeners();

        try {
          final stem = p.basenameWithoutExtension(task.videoFileName);
          final preferredPath = '${stem}_overlay.mp4';
          task.outputPath = _getUniqueOutputPath(outputDir, preferredPath);

          final stream =
              _commandRunnerService.executeTask(task, config, task.outputPath!);

          await for (final line in stream) {
            task.logs.add(line);
            if (line.contains('time=')) continue;
            notifyListeners();
          }

          task.endTime = DateTime.now();

          if (task.logs.isNotEmpty &&
              task.logs.last.contains('✅ Process completed successfully')) {
            task.status = TaskStatus.completed;
            task.progress = 1.0;

            _osService.showNotification(
              title: 'Overlay Finished',
              body: '${task.videoFileName} is ready!',
              silent: true,
            );
          } else {
            task.status = TaskStatus.failed;
            task.errorMessage = 'Execution failed. Check logs.';
          }
        } catch (e) {
          task.endTime = DateTime.now();
          task.status = TaskStatus.failed;
          task.errorMessage = e.toString();
        }

        _updateDockState();
        notifyListeners();
      }
    }

    _isProcessing = false;

    final completedCount =
        _tasks.where((t) => t.status == TaskStatus.completed).length;
    if (completedCount > 0) {
      _osService.showNotification(
        title: 'Queue Completed',
        body: 'Successfully processed $completedCount videos.',
      );
    }

    _updateDockState();
    notifyListeners();
  }
}
