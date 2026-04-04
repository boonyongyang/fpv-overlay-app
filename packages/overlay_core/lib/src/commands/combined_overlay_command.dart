import 'dart:async';
import 'dart:io';

import '../runtime/overlay_runtime.dart';
import '../models/overlay_task.dart';
import 'overlay_command.dart';
import 'process_runner_mixin.dart';

class CombinedOverlayCommand with ProcessRunnerMixin implements OverlayCommand {
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

    final osdPath = task.osdPath;
    final srtPath = task.srtPath;
    final hasOsd = osdPath != null && osdPath.isNotEmpty;
    final hasSrt = srtPath != null && srtPath.isNotEmpty;

    if (!hasOsd && !hasSrt) {
      yield 'Error: No OSD or SRT file specified.';
      return;
    }

    final bundledOsdExecutablePath = runtime.bundledOsdExecutablePath;
    final bundledSrtExecutablePath = runtime.bundledSrtExecutablePath;

    if (hasOsd && !hasSrt) {
      final scriptPath = runtime.osdScriptPath;
      yield 'Runtime: FFmpeg = ${runtime.ffmpegPath}';
      if (bundledOsdExecutablePath != null) {
        yield 'Runtime: OSD executable = $bundledOsdExecutablePath';
      } else {
        yield 'Runtime: Python = ${runtime.pythonPath}';
        yield 'Runtime: OSD script = $scriptPath';
      }

      if (bundledOsdExecutablePath == null && !File(scriptPath).existsSync()) {
        yield 'Error: OSD rendering script not found at $scriptPath';
        return;
      }
      yield 'Applying OSD HD Rendering…';
      final osdArgs = _buildOsdArgs(
        runtime,
        bundledOsdExecutablePath == null ? scriptPath : null,
        osdPath,
        videoPath,
        outputPath,
      );
      if (bundledOsdExecutablePath != null) {
        yield* streamProcess(bundledOsdExecutablePath, osdArgs);
      } else {
        yield* streamProcess(runtime.pythonPath, osdArgs);
      }
      return;
    }

    if (!hasOsd && hasSrt) {
      final srtScriptPath = runtime.srtScriptPath;
      yield 'Runtime: FFmpeg = ${runtime.ffmpegPath}';
      if (bundledSrtExecutablePath != null) {
        yield 'Runtime: SRT executable = $bundledSrtExecutablePath';
      } else {
        yield 'Runtime: Python = ${runtime.pythonPath}';
        yield 'Runtime: SRT script = $srtScriptPath';
      }

      if (bundledSrtExecutablePath == null &&
          !File(srtScriptPath).existsSync()) {
        yield 'Error: SRT overlay script not found at $srtScriptPath';
        return;
      }
      yield 'Applying SRT Telemetry HUD…';
      final srtArgs = _buildSrtArgs(
        runtime,
        bundledSrtExecutablePath == null ? srtScriptPath : null,
        srtPath,
        videoPath,
        outputPath,
      );
      if (bundledSrtExecutablePath != null) {
        yield* streamProcess(bundledSrtExecutablePath, srtArgs);
      } else {
        yield* streamProcess(runtime.pythonPath, srtArgs);
      }
      return;
    }

    final scriptPath = runtime.osdScriptPath;
    if (bundledOsdExecutablePath == null && !File(scriptPath).existsSync()) {
      yield 'Error: OSD rendering script not found at $scriptPath';
      return;
    }

    final osdPathNonNull = osdPath!;
    final srtPathNonNull = srtPath!;

    yield 'Runtime: FFmpeg = ${runtime.ffmpegPath}';
    if (bundledOsdExecutablePath != null) {
      yield 'Runtime: OSD executable = $bundledOsdExecutablePath';
    } else {
      yield 'Runtime: Python = ${runtime.pythonPath}';
      yield 'Runtime: OSD script = $scriptPath';
    }
    yield 'Applying OSD HD Rendering with SRT Telemetry…';
    final osdArgs = _buildOsdArgs(
      runtime,
      bundledOsdExecutablePath == null ? scriptPath : null,
      osdPathNonNull,
      videoPath,
      outputPath,
      srtPath: srtPathNonNull,
    );
    if (bundledOsdExecutablePath != null) {
      yield* streamProcess(bundledOsdExecutablePath, osdArgs);
      return;
    }

    yield* streamProcess(runtime.pythonPath, osdArgs);
  }

  List<String> _buildOsdArgs(
    OverlayRuntime runtime,
    String? scriptPath,
    String osdPath,
    String videoPath,
    String outputPath, {
    String? srtPath,
  }) {
    final args = <String>[
      if (scriptPath != null) scriptPath,
      '--osd',
      osdPath,
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
    if (srtPath != null && srtPath.isNotEmpty) {
      args.addAll(['--srt', srtPath]);
    }
    return args;
  }

  List<String> _buildSrtArgs(
    OverlayRuntime runtime,
    String? scriptPath,
    String srtPath,
    String videoPath,
    String outputPath,
  ) {
    return <String>[
      if (scriptPath != null) scriptPath,
      '--srt',
      srtPath,
      '--video',
      videoPath,
      '--output',
      outputPath,
      '--ffmpeg',
      runtime.ffmpegPath,
    ];
  }
}
