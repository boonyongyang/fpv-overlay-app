class TaskFailure {
  final String code;
  final String summary;
  final String details;
  final int? exitCode;
  final String? suggestion;

  const TaskFailure({
    required this.code,
    required this.summary,
    required this.details,
    this.exitCode,
    this.suggestion,
  });
}
