import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:overlay_core/overlay_core.dart'
    show OverlayProgressParser, OverlayTaskPlanner;

import 'package:fpv_overlay_app/application/providers/local_stats_provider.dart';
import 'package:fpv_overlay_app/domain/models/app_configuration.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';
import 'package:fpv_overlay_app/domain/models/task_addition_result.dart';
import 'package:fpv_overlay_app/domain/services/task_failure_parser.dart';

import 'package:fpv_overlay_app/infrastructure/services/engine_service.dart';
import 'package:fpv_overlay_app/infrastructure/services/command_runner_service.dart';
import 'package:fpv_overlay_app/infrastructure/runtime/path_resolver_runtime.dart';
import 'package:fpv_overlay_app/domain/services/os_service.dart';

class TaskQueueProvider extends ChangeNotifier {
  final EngineService _engineService;
  final CommandRunnerService _commandRunnerService;
  final OsService _osService;
  final LocalStatsProvider _localStatsProvider;
  final OverlayTaskPlanner _taskPlanner;
  final OverlayProgressParser _progressParser;

  final List<OverlayTask> _tasks = [];
  bool _isProcessing = false;
  bool _cancelRequested = false;
  bool _clearAfterCancel = false;

  TaskQueueProvider({
    required EngineService engineService,
    required CommandRunnerService commandRunnerService,
    required OsService osService,
    required LocalStatsProvider localStatsProvider,
    OverlayTaskPlanner? taskPlanner,
    OverlayProgressParser? progressParser,
  })  : _engineService = engineService,
        _commandRunnerService = commandRunnerService,
        _osService = osService,
        _localStatsProvider = localStatsProvider,
        _taskPlanner = taskPlanner ?? OverlayTaskPlanner(),
        _progressParser = progressParser ?? const OverlayProgressParser();

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
    final task = _taskPlanner.createManualTask(
      videoPath: videoPath,
      overlayPath: overlayPath,
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
    final result = _taskPlanner.mergeIncoming(_tasks, incoming);

    if (result.addedCount > 0 ||
        result.partialCount > 0 ||
        incoming.isNotEmpty) {
      _updateDockState();
      notifyListeners();
    }

    return result;
  }

  void updateTaskFiles(
    String taskId, {
    String? videoPath,
    String? overlayPath,
  }) {
    _taskPlanner.updateTaskFiles(
      _tasks,
      taskId,
      videoPath: videoPath,
      overlayPath: overlayPath,
    );
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

  Future<void> startQueue(AppConfiguration _, String outputDir) async {
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
          task.outputPath =
              _taskPlanner.getUniqueOutputPath(outputDir, preferredPath);
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

          final stream = _commandRunnerService.executeTask(
            task,
            const PathResolverRuntime(),
            task.outputPath!,
          );

          await for (final line in stream) {
            task.logs.add(line);
            _progressParser.apply(task, line);
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
