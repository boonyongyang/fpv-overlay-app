import 'package:fpv_overlay_app/domain/models/overlay_task.dart';

class RecentOverlayRun {
  final DateTime timestamp;
  final String sourceName;
  final TaskStatus status;
  final OverlayType overlayType;
  final Duration? renderDuration;
  final String? outputPath;
  final String? failureCode;
  final String? failureSummary;

  const RecentOverlayRun({
    required this.timestamp,
    required this.sourceName,
    required this.status,
    required this.overlayType,
    this.renderDuration,
    this.outputPath,
    this.failureCode,
    this.failureSummary,
  });

  Map<String, Object?> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'sourceName': sourceName,
      'status': status.name,
      'overlayType': overlayType.name,
      'renderDurationMs': renderDuration?.inMilliseconds,
      'outputPath': outputPath,
      'failureCode': failureCode,
      'failureSummary': failureSummary,
    };
  }

  factory RecentOverlayRun.fromJson(Map<String, Object?> json) {
    return RecentOverlayRun(
      timestamp: DateTime.parse(json['timestamp']! as String),
      sourceName: json['sourceName']! as String,
      status: TaskStatus.values.byName(json['status']! as String),
      overlayType: OverlayType.values.byName(json['overlayType']! as String),
      renderDuration: json['renderDurationMs'] == null
          ? null
          : Duration(milliseconds: json['renderDurationMs']! as int),
      outputPath: json['outputPath'] as String?,
      failureCode: json['failureCode'] as String?,
      failureSummary: json['failureSummary'] as String?,
    );
  }
}

class OverlayStatsSnapshot {
  final int totalCompletedRuns;
  final int totalFailedRuns;
  final int totalCancelledRuns;
  final int totalSrtRuns;
  final int totalOsdRuns;
  final int totalCombinedRuns;
  final int totalTimedRuns;
  final Duration totalRenderTime;
  final DateTime? lastCompletedAt;
  final List<RecentOverlayRun> recentRuns;

  const OverlayStatsSnapshot({
    this.totalCompletedRuns = 0,
    this.totalFailedRuns = 0,
    this.totalCancelledRuns = 0,
    this.totalSrtRuns = 0,
    this.totalOsdRuns = 0,
    this.totalCombinedRuns = 0,
    this.totalTimedRuns = 0,
    this.totalRenderTime = Duration.zero,
    this.lastCompletedAt,
    this.recentRuns = const [],
  });

  int get totalRuns =>
      totalCompletedRuns + totalFailedRuns + totalCancelledRuns;

  Duration get averageRenderTime {
    if (totalTimedRuns == 0) return Duration.zero;
    return Duration(
      milliseconds: totalRenderTime.inMilliseconds ~/ totalTimedRuns,
    );
  }

  OverlayStatsSnapshot copyWith({
    int? totalCompletedRuns,
    int? totalFailedRuns,
    int? totalCancelledRuns,
    int? totalSrtRuns,
    int? totalOsdRuns,
    int? totalCombinedRuns,
    int? totalTimedRuns,
    Duration? totalRenderTime,
    Object? lastCompletedAt = _absentStatsField,
    List<RecentOverlayRun>? recentRuns,
  }) {
    return OverlayStatsSnapshot(
      totalCompletedRuns: totalCompletedRuns ?? this.totalCompletedRuns,
      totalFailedRuns: totalFailedRuns ?? this.totalFailedRuns,
      totalCancelledRuns: totalCancelledRuns ?? this.totalCancelledRuns,
      totalSrtRuns: totalSrtRuns ?? this.totalSrtRuns,
      totalOsdRuns: totalOsdRuns ?? this.totalOsdRuns,
      totalCombinedRuns: totalCombinedRuns ?? this.totalCombinedRuns,
      totalTimedRuns: totalTimedRuns ?? this.totalTimedRuns,
      totalRenderTime: totalRenderTime ?? this.totalRenderTime,
      lastCompletedAt: identical(lastCompletedAt, _absentStatsField)
          ? this.lastCompletedAt
          : lastCompletedAt as DateTime?,
      recentRuns: recentRuns ?? this.recentRuns,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'totalCompletedRuns': totalCompletedRuns,
      'totalFailedRuns': totalFailedRuns,
      'totalCancelledRuns': totalCancelledRuns,
      'totalSrtRuns': totalSrtRuns,
      'totalOsdRuns': totalOsdRuns,
      'totalCombinedRuns': totalCombinedRuns,
      'totalTimedRuns': totalTimedRuns,
      'totalRenderTimeMs': totalRenderTime.inMilliseconds,
      'lastCompletedAt': lastCompletedAt?.toIso8601String(),
      'recentRuns': recentRuns.map((run) => run.toJson()).toList(),
    };
  }

  factory OverlayStatsSnapshot.fromJson(Map<String, Object?> json) {
    final recentRunsJson = (json['recentRuns'] as List<dynamic>? ?? const []);
    return OverlayStatsSnapshot(
      totalCompletedRuns: json['totalCompletedRuns'] as int? ?? 0,
      totalFailedRuns: json['totalFailedRuns'] as int? ?? 0,
      totalCancelledRuns: json['totalCancelledRuns'] as int? ?? 0,
      totalSrtRuns: json['totalSrtRuns'] as int? ?? 0,
      totalOsdRuns: json['totalOsdRuns'] as int? ?? 0,
      totalCombinedRuns: json['totalCombinedRuns'] as int? ?? 0,
      totalTimedRuns: json['totalTimedRuns'] as int? ?? 0,
      totalRenderTime:
          Duration(milliseconds: json['totalRenderTimeMs'] as int? ?? 0),
      lastCompletedAt: json['lastCompletedAt'] == null
          ? null
          : DateTime.parse(json['lastCompletedAt']! as String),
      recentRuns: recentRunsJson
          .whereType<Map<Object?, Object?>>()
          .map(
            (entry) => RecentOverlayRun.fromJson(
              Map<String, Object?>.from(entry.cast<String, Object?>()),
            ),
          )
          .toList(),
    );
  }
}

const _absentStatsField = Object();
