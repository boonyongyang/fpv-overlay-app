import '../models/overlay_task.dart';
import '../runtime/overlay_runtime.dart';

abstract class OverlayCommand {
  Stream<String> execute(
    OverlayTask task,
    OverlayRuntime runtime,
    String outputPath,
  );

  void cancel() {}
}
