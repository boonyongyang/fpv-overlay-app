import 'package:flutter_test/flutter_test.dart';

import 'package:fpv_overlay_app/domain/services/task_failure_parser.dart';

void main() {
  group('TaskFailureParser', () {
    test('classifies missing ffmpeg executable', () {
      final failure = TaskFailureParser.fromLogs(<String>[
        r'$ ffmpeg -version',
        'Error: Failed to start process "ffmpeg".',
        '❌ Exception: ProcessException: No such file or directory',
      ]);

      expect(failure.code, 'RUNTIME_FFMPEG_NOT_FOUND');
      expect(failure.summary, 'FFmpeg is missing or could not be launched.');
    });

    test('classifies missing python dependencies', () {
      final failure = TaskFailureParser.fromLogs(<String>[
        'Runtime: Python = /usr/local/bin/python3',
        'Installing missing Python packages: numpy, pillow, pandas …',
        'Error: Auto-install failed: externally-managed-environment',
        '❌ Process failed with exit code 1.',
      ]);

      expect(failure.code, 'PYTHON_DEPENDENCIES_MISSING');
      expect(failure.exitCode, 1);
    });

    test('classifies ffmpeg render failures', () {
      final failure = TaskFailureParser.fromLogs(<String>[
        'Rendering SRT HUD onto video...',
        'Error: Render failed (exit 1):',
        'STDERR: Unknown encoder libx264',
        '❌ Process failed with exit code 1.',
      ]);

      expect(failure.code, 'RENDER_FFMPEG_FAILED');
      expect(failure.exitCode, 1);
      expect(failure.summary, contains('Render failed'));
    });
  });
}
