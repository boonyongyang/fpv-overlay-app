import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:fpv_overlay_app/application/providers/settings_provider.dart';
import 'package:fpv_overlay_app/application/providers/task_queue_provider.dart';
import 'package:fpv_overlay_app/application/providers/workspace_provider.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';
import 'package:fpv_overlay_app/infrastructure/services/picker_service.dart';
import 'package:fpv_overlay_app/presentation/utils/workspace_actions.dart';
import 'package:fpv_overlay_app/presentation/widgets/task_queue/action_bars.dart';
import 'package:fpv_overlay_app/presentation/widgets/task_queue/dashboard_stats_row.dart';
import 'package:fpv_overlay_app/presentation/widgets/task_queue/empty_state_view.dart';
import 'package:fpv_overlay_app/presentation/widgets/task_queue/snack_bar_helpers.dart';
import 'package:fpv_overlay_app/presentation/widgets/task_queue/task_card.dart';

class TaskQueuePage extends StatefulWidget {
  const TaskQueuePage({super.key});

  @override
  State<TaskQueuePage> createState() => _TaskQueuePageState();
}

class _TaskQueuePageState extends State<TaskQueuePage> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final queueProvider = context.watch<TaskQueueProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final workspace = context.watch<WorkspaceProvider>();
    final pickerService = context.read<PickerService>();
    final allTasks = queueProvider.tasks;
    final visibleTasks = workspace.buildVisibleTasks(allTasks);

    return DropTarget(
      onDragDone: (detail) async {
        final filePaths = detail.files.map((file) => file.path).toList();
        if (filePaths.isEmpty) return;

        final parentPath = _parentPath(filePaths.first);
        if (parentPath != null) {
          unawaited(settingsProvider.addRecentInputDirectory(parentPath));
        }

        final result = await queueProvider.addTasksFromFiles(filePaths);
        if (!context.mounted) return;
        showAddResultSnackBar(context, result);
      },
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompactLayout =
              constraints.maxWidth < 1120 || constraints.maxHeight < 720;
          final showHeaderActions = allTasks.isNotEmpty;

          return Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isCompactLayout ? 20 : 32,
                  isCompactLayout ? 24 : 36,
                  isCompactLayout ? 20 : 32,
                  20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _QueueHeader(
                      compact: isCompactLayout,
                      showActions: showHeaderActions,
                      totalTasks: allTasks.length,
                      visibleTasks: visibleTasks.length,
                      queueProvider: queueProvider,
                    ),
                    if (allTasks.isNotEmpty) ...[
                      SizedBox(height: isCompactLayout ? 16 : 20),
                      DashboardStatsRow(queueProvider: queueProvider),
                      // if (showPerformanceInsights)
                      //   PerformanceInsightsCard(queueProvider: queueProvider),
                      // SizedBox(height: isCompactLayout ? 16 : 20),
                      // QueueControlStrip(
                      //   tasks: allTasks,
                      //   totalCount: allTasks.length,
                      //   visibleCount: visibleTasks.length,
                      // ),
                    ],
                    SizedBox(height: isCompactLayout ? 16 : 20),
                    Expanded(
                      child: allTasks.isEmpty
                          ? EmptyStateView(
                              compact: isCompactLayout,
                              onAddFiles: () => addFilesToQueue(context),
                              onAddFolder: () => addFolderToQueue(context),
                              onOpenTutorial: () => openTutorial(context),
                              onOpenSettings: () => openSettings(context),
                              onRecentInputSelected: (path) =>
                                  addFolderToQueue(context, presetPath: path),
                              onRecentOutputSelected: (path) =>
                                  openOutputDirectory(context, path: path),
                              recentInputDirectories: settingsProvider
                                  .config.recentInputDirectories,
                              recentOutputDirectories: settingsProvider
                                  .config.recentOutputDirectories,
                            )
                          : _QueueContent(
                              visibleTasks: visibleTasks,
                              onOpenLogs: (taskId) async {
                                workspace.setSelectedTask(taskId);
                                await openTaskLogs(context, taskId);
                              },
                            ),
                    ),
                    if (allTasks.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      BottomActionBar(
                        compact: isCompactLayout,
                        queueProvider: queueProvider,
                        settingsProvider: settingsProvider,
                        pickerService: pickerService,
                      ),
                    ],
                  ],
                ),
              ),
              if (_isDragging) const _DragOverlay(),
            ],
          );
        },
      ),
    );
  }

  String? _parentPath(String path) {
    final separatorIndex = path.lastIndexOf(RegExp(r'[\\/]'));
    if (separatorIndex <= 0) return null;
    return path.substring(0, separatorIndex);
  }
}

class _QueueHeader extends StatelessWidget {
  final bool compact;
  final bool showActions;
  final int totalTasks;
  final int visibleTasks;
  final TaskQueueProvider queueProvider;

  const _QueueHeader({
    required this.compact,
    required this.showActions,
    required this.totalTasks,
    required this.visibleTasks,
    required this.queueProvider,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = compact
        ? theme.textTheme.headlineMedium
        : theme.textTheme.headlineLarge;
    final readyCount = queueProvider.tasks
        .where((task) => task.status == TaskStatus.pending)
        .length;
    final processingCount = queueProvider.tasks
        .where((task) => task.status == TaskStatus.processing)
        .length;
    final needsFixCount = queueProvider.tasks
        .where(
          (task) =>
              task.status == TaskStatus.missingTelemetry ||
              task.status == TaskStatus.missingVideo,
        )
        .length;
    final completedCount = queueProvider.tasks
        .where((task) => task.status == TaskStatus.completed)
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = compact || constraints.maxWidth < 920;
        final summary = totalTasks == 0
            ? 'Use the quick actions below to build your first batch.'
            : _buildSummary(
                totalTasks: totalTasks,
                visibleTasks: visibleTasks,
                readyCount: readyCount,
                processingCount: processingCount,
                needsFixCount: needsFixCount,
                completedCount: completedCount,
              );

        final headerCopy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overlay Workspace',
              style: titleStyle?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -1.1,
                height: 0.96,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Text(
                summary,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ],
        );

        final actions = showActions
            ? HeaderActions(
                compact: stacked,
                queueProvider: queueProvider,
                onOpenCommandPalette: () => openCommandPalette(context),
              )
            : null;

        if (stacked || actions == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              headerCopy,
              if (actions != null) ...[
                const SizedBox(height: 16),
                actions,
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: headerCopy),
            const SizedBox(width: 20),
            actions,
          ],
        );
      },
    );
  }

  String _buildSummary({
    required int totalTasks,
    required int visibleTasks,
    required int readyCount,
    required int processingCount,
    required int needsFixCount,
    required int completedCount,
  }) {
    final visibilityNote =
        visibleTasks == totalTasks ? '' : ' $visibleTasks currently visible.';

    if (processingCount > 0) {
      final blockedNote =
          needsFixCount > 0 ? ', $needsFixCount still need links' : '';
      return '$processingCount render live, $readyCount queued next$blockedNote.$visibilityNote';
    }

    if (readyCount > 0) {
      final blockedNote =
          needsFixCount > 0 ? ' $needsFixCount still need links.' : '';
      return '$readyCount overlays are ready to start.$blockedNote$visibilityNote';
    }

    if (needsFixCount > 0) {
      return '$needsFixCount items still need source links before they can render.$visibilityNote';
    }

    if (completedCount == totalTasks) {
      return 'Batch finished. Open results or clear the queue for the next pass.$visibilityNote';
    }

    return 'Showing $visibleTasks of $totalTasks items with status tabs and queue controls.';
  }
}

class QueueControlStrip extends StatelessWidget {
  final List<OverlayTask> tasks;
  final int totalCount;
  final int visibleCount;

  const QueueControlStrip({
    super.key,
    required this.tasks,
    required this.totalCount,
    required this.visibleCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workspace = context.watch<WorkspaceProvider>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: theme.colorScheme.outlineVariant.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Batch filters',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '$visibleCount / $totalCount visible',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: QueueStatusFilter.values.map((filter) {
              final count = _filterCount(filter);
              return ChoiceChip(
                label: Text('${_statusLabel(filter)} · $count'),
                selected: workspace.statusFilter == filter,
                onSelected: (_) => workspace.setStatusFilter(filter),
              );
            }).toList(growable: false),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(QueueStatusFilter filter) {
    switch (filter) {
      case QueueStatusFilter.all:
        return 'All';
      case QueueStatusFilter.actionable:
        return 'Actionable';
      case QueueStatusFilter.processing:
        return 'Processing';
      case QueueStatusFilter.completed:
        return 'Completed';
      case QueueStatusFilter.failed:
        return 'Failed';
      case QueueStatusFilter.needsFix:
        return 'Needs fix';
    }
  }

  int _filterCount(QueueStatusFilter filter) {
    return tasks.where((task) {
      switch (filter) {
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
    }).length;
  }
}

class _QueueContent extends StatelessWidget {
  final List<OverlayTask> visibleTasks;
  final ValueChanged<String> onOpenLogs;

  const _QueueContent({
    required this.visibleTasks,
    required this.onOpenLogs,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (visibleTasks.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border:
              Border.all(color: theme.colorScheme.outlineVariant.withAlpha(50)),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.filter_alt_off_rounded,
                  size: 48,
                  color: theme.colorScheme.primary.withAlpha(160),
                ),
                const SizedBox(height: 16),
                Text(
                  'No tasks match the selected status',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a different status tab to bring more queue items back into view.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: visibleTasks.length,
      itemBuilder: (context, index) {
        final task = visibleTasks[index];
        return TaskCard(
          task: task,
          onOpenLogs: () => onOpenLogs(task.id),
        );
      },
    );
  }
}

class _DragOverlay extends StatelessWidget {
  const _DragOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedOpacity(
        opacity: 1,
        duration: const Duration(milliseconds: 200),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withAlpha(220),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(26),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withAlpha(50), width: 2),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_upload_rounded,
                    color: Colors.white,
                    size: 72,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Drop files to build queue tasks',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
