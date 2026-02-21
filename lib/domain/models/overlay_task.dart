import 'package:path/path.dart' as p;

enum TaskStatus {
  pending,
  processing,
  completed,
  failed,
  missingTelemetry,
  missingVideo,
}

enum OverlayType {
  srt,
  osd,
  unknown,
}

class OverlayTask {
  final String id;
  String? videoPath;
  String? overlayPath;
  OverlayType type;

  TaskStatus status;
  double progress;
  String? errorMessage;
  String? outputPath;
  final List<String> logs;

  // Performance stats
  DateTime? startTime;
  DateTime? endTime;
  double? cpuUsageAtStart; // Snapshot of system load

  OverlayTask({
    required this.id,
    this.videoPath,
    this.overlayPath,
    this.type = OverlayType.unknown,
    this.status = TaskStatus.pending,
    this.progress = 0.0,
    this.errorMessage,
    this.outputPath,
    List<String>? logs,
  }) : logs = logs ?? [];

  /// Helper to get the video filename
  String get videoFileName {
    if (videoPath == null) {
      if (overlayPath != null) {
        return "${p.basenameWithoutExtension(overlayPath!)} [No Video]";
      }
      return "Unnamed Task";
    }
    return p.basename(videoPath!);
  }

  String get stem {
    if (videoPath != null) return p.basenameWithoutExtension(videoPath!);
    if (overlayPath != null) return p.basenameWithoutExtension(overlayPath!);
    return "unknown";
  }

  Duration? get duration {
    if (startTime == null) return null;
    if (endTime != null) return endTime!.difference(startTime!);
    return DateTime.now().difference(startTime!);
  }
}
