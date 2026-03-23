import 'package:fpv_overlay_app/domain/models/task_failure.dart';

class TaskFailureParser {
  static final RegExp _exitCodeRe =
      RegExp(r'exit code (\d+)', caseSensitive: false);

  static TaskFailure fromLogs(List<String> logs) {
    final normalizedLogs = logs
        .map((line) => line.trimRight())
        .where((line) => line.trim().isNotEmpty)
        .toList();
    final trace = normalizedLogs.join('\n').trim();
    final traceLower = trace.toLowerCase();
    final commandLine = normalizedLogs.firstWhere(
      (line) => line.startsWith(r'$ '),
      orElse: () => '',
    );
    final exitCode = _extractExitCode(trace);
    final summary = _extractSummary(normalizedLogs);
    final processStartFailure = traceLower.contains('processexception') ||
        traceLower.contains('failed to start process') ||
        traceLower.contains('no such file or directory');

    if (processStartFailure && commandLine.contains('ffmpeg')) {
      return TaskFailure(
        code: 'RUNTIME_FFMPEG_NOT_FOUND',
        summary: 'FFmpeg is missing or could not be launched.',
        details: trace,
        exitCode: exitCode,
        suggestion:
            'Install FFmpeg and ensure it is on PATH, or bundle ffmpeg into the release app.',
      );
    }

    if (processStartFailure && commandLine.contains('python')) {
      return TaskFailure(
        code: 'RUNTIME_PYTHON_NOT_FOUND',
        summary: 'Python is missing or could not be launched.',
        details: trace,
        exitCode: exitCode,
        suggestion:
            'Install Python 3 and ensure it is on PATH, or bundle python3 into the release app.',
      );
    }

    if (traceLower.contains('missing python dependency') ||
        traceLower.contains('auto-install failed')) {
      return TaskFailure(
        code: 'PYTHON_DEPENDENCIES_MISSING',
        summary: summary,
        details: trace,
        exitCode: exitCode,
        suggestion:
            'Install numpy, pillow, and pandas for the detected Python interpreter.',
      );
    }

    if (traceLower.contains('cannot import osdfilereader')) {
      return TaskFailure(
        code: 'OSD_READER_IMPORT_FAILED',
        summary: summary,
        details: trace,
        exitCode: exitCode,
        suggestion:
            'Ensure OsdFileReader.py is bundled with the app or configure O3_OverlayTool in Settings.',
      );
    }

    if (traceLower.contains('osd rendering script not found') ||
        traceLower.contains('srt overlay script not found')) {
      return TaskFailure(
        code: 'APP_SCRIPT_MISSING',
        summary: summary,
        details: trace,
        exitCode: exitCode,
        suggestion:
            'The app bundle is missing a required overlay script. Rebuild or reinstall the app.',
      );
    }

    if (traceLower.contains('permission denied')) {
      return TaskFailure(
        code: 'FILE_PERMISSION_DENIED',
        summary: summary,
        details: trace,
        exitCode: exitCode,
        suggestion:
            'Check that the app can read the source files and write to the selected output folder.',
      );
    }

    if (traceLower.contains('video file not found')) {
      return TaskFailure(
        code: 'INPUT_VIDEO_MISSING',
        summary: summary,
        details: trace,
        exitCode: exitCode,
        suggestion: 'Re-link the source video and try again.',
      );
    }

    if (traceLower.contains('osd file not found')) {
      return TaskFailure(
        code: 'INPUT_OSD_MISSING',
        summary: summary,
        details: trace,
        exitCode: exitCode,
        suggestion: 'Re-link the OSD file and try again.',
      );
    }

    if (traceLower.contains('srt file not found')) {
      return TaskFailure(
        code: 'INPUT_SRT_MISSING',
        summary: summary,
        details: trace,
        exitCode: exitCode,
        suggestion: 'Re-link the SRT file and try again.',
      );
    }

    if (traceLower.contains('error reading osd file')) {
      return TaskFailure(
        code: 'OSD_PARSE_FAILED',
        summary: summary,
        details: trace,
        exitCode: exitCode,
        suggestion: 'Verify the OSD file is valid and not truncated.',
      );
    }

    if (traceLower.contains('no telemetry frames found')) {
      return TaskFailure(
        code: 'SRT_TELEMETRY_EMPTY',
        summary: summary,
        details: trace,
        exitCode: exitCode,
        suggestion:
            'Use a DJI telemetry SRT file rather than a plain subtitle SRT.',
      );
    }

    if (traceLower.contains('compositing failed') ||
        traceLower.contains('render failed')) {
      return TaskFailure(
        code: 'RENDER_FFMPEG_FAILED',
        summary: summary,
        details: trace,
        exitCode: exitCode,
        suggestion: 'Expand the raw trace to inspect the FFmpeg stderr tail.',
      );
    }

    final code = exitCode != null ? 'PROCESS_EXIT_$exitCode' : 'PROCESS_FAILED';
    return TaskFailure(
      code: code,
      summary: summary,
      details: trace,
      exitCode: exitCode,
      suggestion: 'Expand the details to inspect the raw trace.',
    );
  }

  static TaskFailure fromException(
    Object error,
    StackTrace stackTrace, {
    List<String> logs = const [],
  }) {
    final traceParts = <String>[
      ...logs,
      'Exception: $error',
      stackTrace.toString(),
    ]..removeWhere((part) => part.trim().isEmpty);

    return TaskFailure(
      code: 'UNHANDLED_EXCEPTION',
      summary: error.toString(),
      details: traceParts.join('\n'),
      suggestion:
          'Expand the details to inspect the exception and stack trace.',
    );
  }

  static int? _extractExitCode(String trace) {
    final match = _exitCodeRe.firstMatch(trace);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  static String _extractSummary(List<String> logs) {
    for (final line in logs.reversed) {
      final trimmed = line.trim();
      if (trimmed.startsWith('Error:')) {
        return trimmed.substring('Error:'.length).trim();
      }
    }

    for (final line in logs.reversed) {
      final trimmed = line.trim();
      if (trimmed.startsWith('❌')) {
        return trimmed.substring(1).trim();
      }
      if (trimmed.startsWith('STDERR:')) {
        return trimmed.substring('STDERR:'.length).trim();
      }
    }

    if (logs.isEmpty) {
      return 'Execution failed. Check the raw trace for details.';
    }

    return logs.last.trim();
  }
}
