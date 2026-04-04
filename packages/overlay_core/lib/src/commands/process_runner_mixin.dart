import 'dart:async';
import 'dart:convert';
import 'dart:io';

mixin ProcessRunnerMixin {
  Process? get activeProcess;
  set activeProcess(Process? value);

  Stream<String> streamProcess(String executable, List<String> args) async* {
    try {
      yield '\$ $executable ${args.join(' ')}';
      final process = await Process.start(executable, args);
      activeProcess = process;

      final controller = StreamController<String>();

      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(controller.add);

      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => controller.add('STDERR: $line'));

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
