class TaskAdditionResult {
  final int addedCount;
  final int duplicateCount;
  final int partialCount;

  const TaskAdditionResult({
    required this.addedCount,
    required this.duplicateCount,
    this.partialCount = 0,
  });

  bool get hasAnyAction => addedCount > 0 || partialCount > 0;
  bool get onlyDuplicates =>
      duplicateCount > 0 && addedCount == 0 && partialCount == 0;
}
