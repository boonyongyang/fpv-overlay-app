import 'dart:async';
import 'dart:io';

import '../runtime/overlay_runtime.dart';
import '../models/overlay_task.dart';
import 'overlay_command.dart';
import 'process_runner_mixin.dart';

class SrtOverlayCommand with ProcessRunnerMixin implements OverlayCommand {
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

    final srtPath = task.srtPath;
    if (srtPath == null || srtPath.isEmpty) {
      yield 'Error: No SRT telemetry file specified.';
      return;
    }

    final bundledExecutablePath = runtime.bundledSrtExecutablePath;
    final scriptPath = runtime.srtScriptPath;
    yield 'Runtime: FFmpeg = ${runtime.ffmpegPath}';
    if (bundledExecutablePath != null) {
      yield 'Runtime: SRT executable = $bundledExecutablePath';
    } else {
      yield 'Runtime: Python = ${runtime.pythonPath}';
      yield 'Runtime: SRT script = $scriptPath';
    }

    if (bundledExecutablePath == null && !File(scriptPath).existsSync()) {
      yield 'Error: SRT overlay script not found at $scriptPath';
      return;
    }

    yield 'Starting SRT Telemetry HUD Overlay…';

    final args = <String>[
      '--srt',
      srtPath,
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
