import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:fpv_overlay_app/domain/models/app_configuration.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';
import 'package:fpv_overlay_app/domain/commands/overlay_command.dart';
import 'package:fpv_overlay_app/infrastructure/commands/srt_overlay_command.dart';
import 'package:fpv_overlay_app/infrastructure/commands/osd_overlay_command.dart';
import 'package:fpv_overlay_app/infrastructure/commands/combined_overlay_command.dart';

class CommandRunnerService {
  OverlayCommand? _activeCommand;

  void cancelCurrentTask() {
    _activeCommand?.cancel();
  }

  /// Executes the task by delegating to the specialized OverlayCommand.
  Stream<String> executeTask(
    OverlayTask task,
    AppConfiguration config,
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
      yield* command.execute(task, config, outputPath);
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
