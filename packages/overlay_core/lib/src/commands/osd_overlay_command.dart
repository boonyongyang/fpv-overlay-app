import 'dart:async';
import 'dart:io';

import '../runtime/overlay_runtime.dart';
import '../models/overlay_task.dart';
import 'overlay_command.dart';
import 'process_runner_mixin.dart';

class OsdOverlayCommand with ProcessRunnerMixin implements OverlayCommand {
  @override
  Process? activeProcess;

  @override
  void cancel() => activeProcess?.kill();

  @override
  Stream<String> execute(
    OverlayTask task,
    OverlayRuntime runtime,
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

    final bundledExecutablePath = runtime.bundledOsdExecutablePath;
    final scriptPath = runtime.osdScriptPath;
    yield 'Runtime: FFmpeg = ${runtime.ffmpegPath}';
    if (bundledExecutablePath != null) {
      yield 'Runtime: OSD executable = $bundledExecutablePath';
    } else {
      yield 'Runtime: Python = ${runtime.pythonPath}';
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
      runtime.ffmpegPath,
    ];

    final o3Path = runtime.o3OverlayToolPath;
    if (o3Path != null && o3Path.isNotEmpty) {
      args.addAll(['--tool', o3Path]);
    }

    if (bundledExecutablePath != null) {
      yield* streamProcess(bundledExecutablePath, args);
      return;
    }

    yield* streamProcess(runtime.pythonPath, [scriptPath, ...args]);
  }
}
