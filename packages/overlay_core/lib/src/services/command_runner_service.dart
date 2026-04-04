import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../commands/combined_overlay_command.dart';
import '../commands/osd_overlay_command.dart';
import '../commands/overlay_command.dart';
import '../commands/srt_overlay_command.dart';
import '../models/overlay_task.dart';
import '../runtime/overlay_runtime.dart';

class CommandRunnerService {
  OverlayCommand? _activeCommand;

  void cancelCurrentTask() {
    _activeCommand?.cancel();
  }

  Stream<String> executeTask(
    OverlayTask task,
    OverlayRuntime runtime,
    String outputPath,
  ) async* {
    final outputDir = p.dirname(outputPath);
    final outDir = Directory(outputDir);
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    final OverlayCommand? command = _getCommand(task.type);
    _activeCommand = command;

    if (command != null) {
      yield* command.execute(task, runtime, outputPath);
    } else {
      yield 'Error: Unknown or unsupported task type: ${task.type}';
    }

    _activeCommand = null;
  }

  OverlayCommand? _getCommand(OverlayType type) {
    switch (type) {
      case OverlayType.srt:
        return SrtOverlayCommand();
      case OverlayType.osd:
        return OsdOverlayCommand();
      case OverlayType.combined:
        return CombinedOverlayCommand();
      default:
        return null;
    }
  }
}
