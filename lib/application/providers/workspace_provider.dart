import 'package:flutter/foundation.dart';

import 'package:fpv_overlay_app/domain/models/app_configuration.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';

enum QueueStatusFilter {
  all,
  actionable,
  processing,
  completed,
  failed,
  needsFix,
}

enum QueueSortMode {
  actionableFirst,
  newestFirst,
  filenameAscending,
}

class WorkspaceProvider extends ChangeNotifier {
  QueueStatusFilter _statusFilter = QueueStatusFilter.all;
  QueueSortMode _sortMode = QueueSortMode.actionableFirst;
  String? _selectedTaskId;
  bool _isCommandPaletteOpen = false;
  bool _isOnboardingVisible = false;
  bool _hasInitializedOnboarding = false;

  QueueStatusFilter get statusFilter => _statusFilter;
  QueueSortMode get sortMode => _sortMode;
  String? get selectedTaskId => _selectedTaskId;
  bool get isCommandPaletteOpen => _isCommandPaletteOpen;
  bool get isOnboardingVisible => _isOnboardingVisible;

  void syncFromConfiguration(AppConfiguration config) {
    final shouldShowOnboarding = !config.hasCompletedOnboarding;
    final didChange = !_hasInitializedOnboarding ||
        shouldShowOnboarding != _isOnboardingVisible;
    _hasInitializedOnboarding = true;
    _isOnboardingVisible = shouldShowOnboarding;
    if (didChange) {
      notifyListeners();
    }
  }

  void setStatusFilter(QueueStatusFilter value) {
    if (_statusFilter == value) return;
    _statusFilter = value;
    notifyListeners();
  }

  void setSortMode(QueueSortMode value) {
    if (_sortMode == value) return;
    _sortMode = value;
    notifyListeners();
  }

  void setSelectedTask(String? taskId) {
    if (_selectedTaskId == taskId) return;
    _selectedTaskId = taskId;
    notifyListeners();
  }

  void toggleCommandPalette() {
    _isCommandPaletteOpen = !_isCommandPaletteOpen;
    notifyListeners();
  }

  void openCommandPalette() {
    if (_isCommandPaletteOpen) return;
    _isCommandPaletteOpen = true;
    notifyListeners();
  }

  void closeCommandPalette() {
    if (!_isCommandPaletteOpen) return;
    _isCommandPaletteOpen = false;
    notifyListeners();
  }

  void dismissOnboarding() {
    if (!_isOnboardingVisible) return;
    _isOnboardingVisible = false;
    notifyListeners();
  }

  List<OverlayTask> buildVisibleTasks(List<OverlayTask> tasks) {
    final filtered = tasks.where(_matchesFilters).toList(growable: false);
    filtered.sort(_compareTasks);
    return filtered;
  }

  bool _matchesFilters(OverlayTask task) {
    return _matchesStatus(task);
  }

  bool _matchesStatus(OverlayTask task) {
    switch (_statusFilter) {
      case QueueStatusFilter.all:
        return true;
      case QueueStatusFilter.actionable:
        return task.status == TaskStatus.pending ||
            task.status == TaskStatus.failed ||
            task.status == TaskStatus.missingTelemetry ||
            task.status == TaskStatus.missingVideo;
      case QueueStatusFilter.processing:
        return task.status == TaskStatus.processing;
      case QueueStatusFilter.completed:
        return task.status == TaskStatus.completed;
      case QueueStatusFilter.failed:
        return task.status == TaskStatus.failed;
      case QueueStatusFilter.needsFix:
        return task.status == TaskStatus.failed ||
            task.status == TaskStatus.missingTelemetry ||
            task.status == TaskStatus.missingVideo;
    }
  }

  int _compareTasks(OverlayTask left, OverlayTask right) {
    switch (_sortMode) {
      case QueueSortMode.actionableFirst:
        final leftPriority = _sortPriority(left.status);
        final rightPriority = _sortPriority(right.status);
        if (leftPriority != rightPriority) {
          return leftPriority.compareTo(rightPriority);
        }
        return right.createdAt.compareTo(left.createdAt);
      case QueueSortMode.newestFirst:
        return right.createdAt.compareTo(left.createdAt);
      case QueueSortMode.filenameAscending:
        return left.videoFileName.toLowerCase().compareTo(
              right.videoFileName.toLowerCase(),
            );
    }
  }

  int _sortPriority(TaskStatus status) {
    switch (status) {
      case TaskStatus.processing:
        return 0;
      case TaskStatus.pending:
        return 1;
      case TaskStatus.failed:
        return 2;
      case TaskStatus.missingTelemetry:
      case TaskStatus.missingVideo:
        return 3;
      case TaskStatus.cancelled:
        return 4;
      case TaskStatus.completed:
        return 5;
    }
  }
}
