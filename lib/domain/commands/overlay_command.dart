import 'package:fpv_overlay_app/domain/models/app_configuration.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';

abstract class OverlayCommand {
  Stream<String> execute(
    OverlayTask task,
    AppConfiguration config,
    String outputPath,
  );
}
