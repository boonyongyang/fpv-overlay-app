import 'dart:async';
import 'dart:io';

import 'package:fpv_overlay_app/core/utils/path_resolver.dart';
import 'package:fpv_overlay_app/domain/commands/overlay_command.dart';
import 'package:fpv_overlay_app/domain/models/app_configuration.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';
import 'package:fpv_overlay_app/infrastructure/commands/process_runner_mixin.dart';

class SrtOverlayCommand with ProcessRunnerMixin implements OverlayCommand {
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

    final srtPath = task.srtPath;
    if (srtPath == null || srtPath.isEmpty) {
      yield 'Error: No SRT telemetry file specified.';
      return;
    }

    final bundledExecutablePath = PathResolver.bundledSrtExecutablePath;
    final scriptPath = PathResolver.srtScriptPath;
    yield 'Runtime: FFmpeg = ${PathResolver.ffmpegPath}';
    if (bundledExecutablePath != null) {
      yield 'Runtime: SRT executable = $bundledExecutablePath';
    } else {
      yield 'Runtime: Python = ${PathResolver.pythonPath}';
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
      PathResolver.ffmpegPath,
    ];

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
