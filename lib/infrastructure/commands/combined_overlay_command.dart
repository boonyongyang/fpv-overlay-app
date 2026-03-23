import 'dart:async';
import 'dart:io';

import 'package:fpv_overlay_app/core/utils/path_resolver.dart';
import 'package:fpv_overlay_app/domain/commands/overlay_command.dart';
import 'package:fpv_overlay_app/domain/models/app_configuration.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';
import 'package:fpv_overlay_app/infrastructure/commands/process_runner_mixin.dart';

/// Produces a single output MP4 with OSD and/or SRT telemetry overlays applied.
///
/// When both OSD and SRT are present, `osd_overlay.py` renders both in a
/// single pass — matching the wtfos-configurator worker.ts which draws OSD
/// tiles and SRT text on the same canvas.
///
/// When only one overlay is present, only that step runs.
class CombinedOverlayCommand with ProcessRunnerMixin implements OverlayCommand {
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

    final osdPath = task.osdPath;
    final srtPath = task.srtPath;
    final hasOsd = osdPath != null && osdPath.isNotEmpty;
    final hasSrt = srtPath != null && srtPath.isNotEmpty;

    if (!hasOsd && !hasSrt) {
      yield 'Error: No OSD or SRT file specified.';
      return;
    }

    final bundledOsdExecutablePath = PathResolver.bundledOsdExecutablePath;
    final bundledSrtExecutablePath = PathResolver.bundledSrtExecutablePath;

    // ── OSD-only: single step, output directly ──────────────────────────────
    if (hasOsd && !hasSrt) {
      final scriptPath = PathResolver.osdScriptPath;
      yield 'Runtime: FFmpeg = ${PathResolver.ffmpegPath}';
      if (bundledOsdExecutablePath != null) {
        yield 'Runtime: OSD executable = $bundledOsdExecutablePath';
      } else {
        yield 'Runtime: Python = ${PathResolver.pythonPath}';
        yield 'Runtime: OSD script = $scriptPath';
      }

      if (bundledOsdExecutablePath == null && !File(scriptPath).existsSync()) {
        yield 'Error: OSD rendering script not found at $scriptPath';
        return;
      }
      yield 'Applying OSD HD Rendering…';
      final osdArgs = _buildOsdArgs(
        bundledOsdExecutablePath == null ? scriptPath : null,
        osdPath,
        videoPath,
        outputPath,
      );
      if (bundledOsdExecutablePath != null) {
        yield* streamProcess(bundledOsdExecutablePath, osdArgs);
      } else {
        yield* streamProcess(PathResolver.pythonPath, osdArgs);
      }
      return;
    }

    // ── SRT-only: single step, output directly ──────────────────────────────
    if (!hasOsd && hasSrt) {
      final srtScriptPath = PathResolver.srtScriptPath;
      yield 'Runtime: FFmpeg = ${PathResolver.ffmpegPath}';
      if (bundledSrtExecutablePath != null) {
        yield 'Runtime: SRT executable = $bundledSrtExecutablePath';
      } else {
        yield 'Runtime: Python = ${PathResolver.pythonPath}';
        yield 'Runtime: SRT script = $srtScriptPath';
      }

      if (bundledSrtExecutablePath == null &&
          !File(srtScriptPath).existsSync()) {
        yield 'Error: SRT overlay script not found at $srtScriptPath';
        return;
      }
      yield 'Applying SRT Telemetry HUD…';
      final srtArgs = _buildSrtArgs(
        bundledSrtExecutablePath == null ? srtScriptPath : null,
        srtPath,
        videoPath,
        outputPath,
      );
      if (bundledSrtExecutablePath != null) {
        yield* streamProcess(bundledSrtExecutablePath, srtArgs);
      } else {
        yield* streamProcess(PathResolver.pythonPath, srtArgs);
      }
      return;
    }

    // ── Both OSD + SRT: single step, pass --srt to osd_overlay.py ──────────
    // The DJI FPV goggle SRT telemetry (CH, delay, bitrate, battery, etc.) is
    // rendered directly onto the OSD frames – matching the wtfos-configurator
    // worker.ts which draws both OSD tiles and SRT text on the same canvas.
    final scriptPath = PathResolver.osdScriptPath;
    if (bundledOsdExecutablePath == null && !File(scriptPath).existsSync()) {
      yield 'Error: OSD rendering script not found at $scriptPath';
      return;
    }

    // At this point both hasOsd and hasSrt are true, so these are non-null.
    final osdPathNonNull = osdPath!;
    final srtPathNonNull = srtPath!;

    yield 'Runtime: FFmpeg = ${PathResolver.ffmpegPath}';
    if (bundledOsdExecutablePath != null) {
      yield 'Runtime: OSD executable = $bundledOsdExecutablePath';
    } else {
      yield 'Runtime: Python = ${PathResolver.pythonPath}';
      yield 'Runtime: OSD script = $scriptPath';
    }
    yield 'Applying OSD HD Rendering with SRT Telemetry…';
    final osdArgs = _buildOsdArgs(
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

    yield* streamProcess(PathResolver.pythonPath, osdArgs);
  }

  List<String> _buildOsdArgs(
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
      PathResolver.ffmpegPath,
    ];
    final o3Path = PathResolver.o3OverlayToolPath;
    if (o3Path != null && o3Path.isNotEmpty) {
      args.addAll(['--tool', o3Path]);
    }
    if (srtPath != null && srtPath.isNotEmpty) {
      args.addAll(['--srt', srtPath]);
    }
    return args;
  }

  List<String> _buildSrtArgs(
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
      PathResolver.ffmpegPath,
    ];
  }
}
