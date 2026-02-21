import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fpv_overlay_app/domain/commands/overlay_command.dart';
import 'package:fpv_overlay_app/domain/models/app_configuration.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';
import 'package:fpv_overlay_app/core/utils/path_resolver.dart';

class SrtOverlayCommand implements OverlayCommand {
  @override
  Stream<String> execute(
    OverlayTask task,
    AppConfiguration config,
    String outputPath,
  ) async* {
    yield 'Starting SRT Fast Overlay with ffmpeg...';

    final args = [
      '-i',
      task.videoPath!,
      '-vf',
      "subtitles='${task.overlayPath}'",
      '-c:v',
      'libx264',
      '-crf',
      '23',
      '-preset',
      'medium',
      '-c:a',
      'aac',
      '-y',
      outputPath,
    ];

    yield* _streamProcess(PathResolver.ffmpegPath, args);
  }

  Stream<String> _streamProcess(String executable, List<String> args) async* {
    try {
      yield '\$ $executable ${args.join(' ')}';
      final process = await Process.start(executable, args);
      final controller = StreamController<String>();

      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => controller.add(line));
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => controller.add('STDERR: $line'));

      process.exitCode.then((code) {
        if (code == 0) {
          controller.add('✅ Process completed successfully.');
        } else {
          controller.add('❌ Process failed with exit code $code.');
        }
        controller.close();
      });

      yield* controller.stream;
    } catch (e) {
      yield '❌ Exception: $e';
    }
  }
}
