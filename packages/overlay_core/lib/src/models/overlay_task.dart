import 'dart:convert';

import 'package:path/path.dart' as p;

import 'task_failure.dart';

enum TaskStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
  missingTelemetry,
  missingVideo,
}

enum OverlayType {
  srt,
  osd,
  combined,
  unknown,
}

class OverlayTask {
  final String id;
  final DateTime createdAt;
  String? videoPath;
  String? osdPath;
  String? srtPath;

  TaskStatus status;
  double progress;
  String? progressPhase;
  String? errorMessage;
  String? outputPath;
  TaskFailure? failure;
  final List<String> logs;

  DateTime? startTime;
  DateTime? endTime;
  double? cpuUsageAtStart;

  OverlayTask({
    required this.id,
    DateTime? createdAt,
    this.videoPath,
    this.osdPath,
    this.srtPath,
    this.status = TaskStatus.pending,
    this.progress = 0.0,
    this.errorMessage,
    this.outputPath,
    this.failure,
    List<String>? logs,
  })  : createdAt = createdAt ?? DateTime.now(),
        logs = logs ?? [];

  OverlayType get type {
    final hasOsd = osdPath != null;
    final hasSrt = srtPath != null;
    if (hasOsd && hasSrt) return OverlayType.combined;
    if (hasOsd) return OverlayType.osd;
    if (hasSrt) return OverlayType.srt;
    return OverlayType.unknown;
  }

  String get videoFileName {
    if (videoPath == null) {
      final orphanPath = osdPath ?? srtPath;
      if (orphanPath != null) {
        return '${p.basenameWithoutExtension(orphanPath)} [No Video]';
      }
      return 'Unnamed Task';
    }
    return p.basename(videoPath!);
  }

  String get stem {
    if (videoPath != null) return p.basenameWithoutExtension(videoPath!);
    if (osdPath != null) return p.basenameWithoutExtension(osdPath!);
    if (srtPath != null) return p.basenameWithoutExtension(srtPath!);
    return 'unknown';
  }

  Duration? get duration {
    if (startTime == null) return null;
    if (endTime != null) return endTime!.difference(startTime!);
    return DateTime.now().difference(startTime!);
  }

  OverlayTask copyWith({
    String? videoPath,
    String? osdPath,
    String? srtPath,
    TaskStatus? status,
  }) {
    return OverlayTask(
      id: id,
      createdAt: createdAt,
      videoPath: videoPath ?? this.videoPath,
      osdPath: osdPath ?? this.osdPath,
      srtPath: srtPath ?? this.srtPath,
      status: status ?? this.status,
      progress: progress,
      errorMessage: errorMessage,
      outputPath: outputPath,
      failure: failure,
      logs: List.of(logs),
    );
  }

  /// Serialises the task for queue persistence.
  ///
  /// Transient state (logs, progress, timing, failure details) is not saved.
  /// A [TaskStatus.processing] task is saved as [TaskStatus.failed] because
  /// it was interrupted mid-render. [TaskStatus.cancelled] tasks are excluded
  /// by the caller — they represent user-dismissed work.
  Map<String, dynamic> toJson() {
    final savedStatus =
        status == TaskStatus.processing ? TaskStatus.failed : status;
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      if (videoPath != null) 'videoPath': videoPath,
      if (osdPath != null) 'osdPath': osdPath,
      if (srtPath != null) 'srtPath': srtPath,
      'status': savedStatus.name,
      if (outputPath != null) 'outputPath': outputPath,
    };
  }

  factory OverlayTask.fromJson(Map<String, dynamic> json) {
    return OverlayTask(
      id: json['id'] as String,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      videoPath: json['videoPath'] as String?,
      osdPath: json['osdPath'] as String?,
      srtPath: json['srtPath'] as String?,
      status: TaskStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => TaskStatus.pending,
      ),
      outputPath: json['outputPath'] as String?,
    );
  }

  static List<OverlayTask> listFromJson(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => OverlayTask.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String listToJson(List<OverlayTask> tasks) {
    final saveable = tasks
        .where((t) => t.status != TaskStatus.cancelled)
        .map((t) => t.toJson())
        .toList();
    return jsonEncode(saveable);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is OverlayTask && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'OverlayTask(id: $id, createdAt: $createdAt, '
      'status: $status, type: $type, '
      'video: $videoPath, osd: $osdPath, srt: $srtPath)';
}
