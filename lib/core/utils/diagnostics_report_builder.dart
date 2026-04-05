import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:fpv_overlay_app/core/constants/app_identity.dart';
import 'package:fpv_overlay_app/core/utils/path_resolver.dart';
import 'package:fpv_overlay_app/domain/models/app_configuration.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';

String buildDiagnosticsReport({
  required AppConfiguration config,
  required List<OverlayTask> tasks,
  OverlayTask? selectedTask,
}) {
  final completed = tasks.where((task) => task.status == TaskStatus.completed);
  final failed = tasks.where((task) => task.status == TaskStatus.failed);
  final processing =
      tasks.where((task) => task.status == TaskStatus.processing).length;
  final outputStrategy = config.defaultOutputDirectory != null
      ? 'Default output directory'
      : 'Ask on render start';

  final buffer = StringBuffer()
    ..writeln('${AppIdentity.name} Diagnostics')
    ..writeln('========================================')
    ..writeln('Generated: ${DateTime.now().toIso8601String()}')
    ..writeln(
      'Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    )
    ..writeln('FFmpeg: ${PathResolver.ffmpegPath}')
    ..writeln('Python: ${PathResolver.pythonPath}')
    ..writeln(
      'Overlay assets: ${PathResolver.o3OverlayToolPath ?? 'Bundled fonts only'}',
    )
    ..writeln('Output strategy: $outputStrategy')
    ..writeln(
      'Default output: ${config.defaultOutputDirectory ?? 'Not configured'}',
    )
    ..writeln(
      'Last input directory: ${config.lastUsedInputDirectory ?? 'Not configured'}',
    )
    ..writeln(
      'Last output directory: ${config.lastUsedOutputDirectory ?? 'Not configured'}',
    )
    ..writeln()
    ..writeln('Queue Summary')
    ..writeln('-------------')
    ..writeln('Tasks total: ${tasks.length}')
    ..writeln('Processing: $processing')
    ..writeln('Completed: ${completed.length}')
    ..writeln('Failed: ${failed.length}')
    ..writeln(
      'Waiting for links: ${tasks.where(_isWaitingForLinks).length}',
    );

  if (tasks.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('Recent Queue Items')
      ..writeln('------------------');
    for (final task in tasks.take(5)) {
      buffer.writeln(
        '- ${task.videoFileName} | ${task.status.name} | ${task.type.name}',
      );
    }
  }

  if (selectedTask != null) {
    buffer
      ..writeln()
      ..writeln('Selected Task')
      ..writeln('-------------')
      ..writeln('Name: ${selectedTask.videoFileName}')
      ..writeln('Status: ${selectedTask.status.name}')
      ..writeln('Overlay type: ${selectedTask.type.name}')
      ..writeln('Video: ${selectedTask.videoPath ?? 'Missing'}')
      ..writeln('OSD: ${selectedTask.osdPath ?? 'Missing'}')
      ..writeln('SRT: ${selectedTask.srtPath ?? 'Missing'}')
      ..writeln('Output: ${selectedTask.outputPath ?? 'Not produced yet'}')
      ..writeln('Progress phase: ${selectedTask.progressPhase ?? 'Idle'}');

    final failure = selectedTask.failure;
    if (failure != null) {
      buffer
        ..writeln('Failure code: ${failure.code}')
        ..writeln('Failure summary: ${failure.summary}');
    }

    if (selectedTask.logs.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Recent Logs')
        ..writeln('-----------');
      for (final line in selectedTask.logs.take(10)) {
        buffer.writeln(line);
      }
    }
  }

  return buffer.toString().trimRight();
}

bool _isWaitingForLinks(OverlayTask task) {
  return task.status == TaskStatus.missingTelemetry ||
      task.status == TaskStatus.missingVideo;
}

String basenameOrPlaceholder(String? path) {
  if (path == null || path.isEmpty) return 'Not available';
  return p.basename(path);
}
