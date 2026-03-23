import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Mixin that provides a reusable [streamProcess] helper for running an
/// external executable and streaming its stdout/stderr line-by-line.
///
/// Classes that mix this in must hold (and expose for cancellation) a nullable
/// [activeProcess] field.
mixin ProcessRunnerMixin {
  Process? get activeProcess;
  set activeProcess(Process? value);

  /// Starts [executable] with [args], streams every output line as a
  /// [String], and appends a success/failure sentinel at the end.
  Stream<String> streamProcess(String executable, List<String> args) async* {
    try {
      yield '\$ $executable ${args.join(' ')}';
      final process = await Process.start(executable, args);
      activeProcess = process;

      final controller = StreamController<String>();

      // Wire up stdout and stderr to the controller.
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(controller.add);

      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => controller.add('STDERR: $line'));

      // Close the sink once the process exits (fire-and-forget).
      unawaited(
        process.exitCode.then((code) {
          if (code == 0) {
            controller.add('✅ Process completed successfully.');
          } else {
            controller.add('❌ Process failed with exit code $code.');
          }
          controller.close();
        }),
      );

      yield* controller.stream;
    } on ProcessException catch (e) {
      yield 'Error: Failed to start process "$executable".';
      yield '❌ Exception: $e';
    } catch (e) {
      yield 'Error: Unexpected process exception.';
      yield '❌ Exception: $e';
    } finally {
      activeProcess = null;
    }
  }
}
