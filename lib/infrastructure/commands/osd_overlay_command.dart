import 'dart:async';
import 'dart:io';

import 'package:fpv_overlay_app/core/utils/path_resolver.dart';
import 'package:fpv_overlay_app/domain/commands/overlay_command.dart';
import 'package:fpv_overlay_app/domain/models/app_configuration.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';
import 'package:fpv_overlay_app/infrastructure/commands/process_runner_mixin.dart';

class OsdOverlayCommand with ProcessRunnerMixin implements OverlayCommand {
  @override
  Process? activeProcess;

  @override
  void cancel() => activeProcess?.kill();

  @override
  Stream<String> execute(
    OverlayTask task,
    AppConfiguration config,
    String outputPath,
  ) async* {
    final videoPath = task.videoPath;
    if (videoPath == null || videoPath.isEmpty) {
      yield 'Error: No source video file specified.';
      return;
    }

    final overlayPath = task.osdPath;
    if (overlayPath == null || overlayPath.isEmpty) {
      yield 'Error: No OSD file specified.';
      return;
    }

    final bundledExecutablePath = PathResolver.bundledOsdExecutablePath;
    final scriptPath = PathResolver.osdScriptPath;
    yield 'Runtime: FFmpeg = ${PathResolver.ffmpegPath}';
    if (bundledExecutablePath != null) {
      yield 'Runtime: OSD executable = $bundledExecutablePath';
    } else {
      yield 'Runtime: Python = ${PathResolver.pythonPath}';
      yield 'Runtime: OSD script = $scriptPath';
    }

    if (bundledExecutablePath == null && !File(scriptPath).existsSync()) {
      yield 'Error: OSD rendering script not found at $scriptPath';
      yield 'Please ensure the app is correctly installed. '
          'Try reinstalling from the original DMG or installer.';
      return;
    }

    yield 'Starting OSD HD Rendering…';

    final args = <String>[
      '--osd',
      overlayPath,
      '--video',
      videoPath,
      '--output',
      outputPath,
      '--ffmpeg',
      PathResolver.ffmpegPath,
    ];

    // Pass the O3_OverlayTool directory if available – used for font lookup.
    // Auto-detected from ~/Downloads if the user has not set it manually.
    final o3Path = PathResolver.o3OverlayToolPath;
    if (o3Path != null && o3Path.isNotEmpty) {
      args.addAll(['--tool', o3Path]);
    }

    if (bundledExecutablePath != null) {
      yield* streamProcess(bundledExecutablePath, args);
      return;
    }

    yield* streamProcess(PathResolver.pythonPath, [scriptPath, ...args]);
  }
}
