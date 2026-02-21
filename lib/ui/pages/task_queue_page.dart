import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';

import '../../application/providers/navigation_provider.dart';
import '../../domain/models/overlay_task.dart';
import '../../infrastructure/services/picker_service.dart';
import '../../models/task_addition_result.dart';
import '../../presentation/widgets/fpv_logo.dart';
import '../../providers/settings_provider.dart';
import '../../providers/task_queue_provider.dart';
import '../../core/utils/platform_utils.dart';

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
    final pickerService = context.read<PickerService>();
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 800;

    return DropTarget(
      onDragDone: (detail) async {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        final colorScheme = Theme.of(context).colorScheme;
        final filePaths = detail.files.map((f) => f.path).toList();

        if (filePaths.isNotEmpty) {
          final result = await queueProvider.addTasksFromFiles(filePaths);
          if (mounted) {
            String message;
            bool isError = false;

            if (result.addedCount > 0 || result.partialCount > 0) {
              final List<String> parts = [];
              if (result.addedCount > 0) {
                parts.add(
                    '${result.addedCount} task${result.addedCount > 1 ? 's' : ''}');
              }
              if (result.partialCount > 0) {
                parts.add(
                    '${result.partialCount} partial item${result.partialCount > 1 ? 's' : ''}');
              }
              message = 'Added ${parts.join(' and ')}';
              if (result.duplicateCount > 0) {
                message += ' (${result.duplicateCount} skipped as duplicates)';
              }
            } else if (result.duplicateCount > 0) {
              message =
                  'All ${result.duplicateCount} items skipped as duplicates';
              isError = true;
            } else {
              message = 'No valid video-telemetry pairs found';
              isError = true;
            }

            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  message,
                  style: TextStyle(
                    color: isError
                        ? colorScheme.onError
                        : colorScheme.onPrimaryContainer,
                    fontWeight: isError ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                behavior: SnackBarBehavior.floating,
                width: 320,
                backgroundColor:
                    isError ? colorScheme.error : colorScheme.primaryContainer,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                action: isError
                    ? SnackBarAction(
                        label: 'Help',
                        textColor: colorScheme.onError,
                        onPressed: () =>
                            context.read<NavigationProvider>().setTab(2),
                      )
                    : null,
              ),
            );
          }
        }
      },
      onDragEntered: (detail) => setState(() => _isDragging = true),
      onDragExited: (detail) => setState(() => _isDragging = false),
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // 1. Header with App Name and Main Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      isMobile ? 24 : 32, 48, isMobile ? 24 : 32, 24),
                  child: Flex(
                    direction: isMobile ? Axis.vertical : Axis.horizontal,
                    crossAxisAlignment: isMobile
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: isMobile ? 0 : 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Overlay Queue',
                              style: (isMobile
                                      ? theme.textTheme.headlineMedium
                                      : theme.textTheme.headlineLarge)
                                  ?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isMobile
                                  ? 'Select or drop files to start.'
                                  : 'Drop files here or use the buttons to add media.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isMobile) const SizedBox(height: 24),
                      _HeaderActions(
                        queueProvider: queueProvider,
                        settingsProvider: settingsProvider,
                        pickerService: pickerService,
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Dashbord Stats Row (Newly Added)
              if (queueProvider.tasks.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: isMobile ? 24 : 32),
                    child: Column(
                      children: [
                        _DashboardStatsRow(queueProvider: queueProvider),
                        _PerformanceInsightsCard(queueProvider: queueProvider),
                      ],
                    ),
                  ),
                ),

              // 3. Task List or Empty State
              if (queueProvider.tasks.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyStateView(),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                      isMobile ? 24 : 32, 16, isMobile ? 24 : 32, 140),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final task = queueProvider.tasks[index];
                        return _TaskCard(task: task);
                      },
                      childCount: queueProvider.tasks.length,
                    ),
                  ),
                ),
            ],
          ),

          // Refined Floating Action Bar
          if (queueProvider.tasks.isNotEmpty)
            Positioned(
              left: 32,
              right: 32,
              bottom: 32,
              child: _BottomActionBar(
                queueProvider: queueProvider,
                settingsProvider: settingsProvider,
                pickerService: pickerService,
              ),
            ),

          // Premium Drag Overlay
          if (_isDragging)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _isDragging ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withAlpha(200),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(30),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withAlpha(50), width: 2),
                          ),
                          child: const FpvLogo(
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Drop to Add to Queue',
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
        ],
      ),
    );
  }
}

class _DashboardStatsRow extends StatelessWidget {
  final TaskQueueProvider queueProvider;
  const _DashboardStatsRow({required this.queueProvider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final int total = queueProvider.tasks.length;
    final int completed = queueProvider.tasks
        .where((t) => t.status == TaskStatus.completed)
        .length;
    final int failed =
        queueProvider.tasks.where((t) => t.status == TaskStatus.failed).length;
    final int pending = total - completed - failed;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: theme.colorScheme.outlineVariant.withAlpha(50)),
      ),
      child: Row(
        children: [
          _StatItem(
              label: 'Total',
              value: total.toString(),
              color: theme.colorScheme.primary),
          _StatDivider(),
          _StatItem(
              label: 'Pending',
              value: pending.toString(),
              color: theme.colorScheme.onSurface),
          _StatDivider(),
          _StatItem(
              label: 'Done',
              value: completed.toString(),
              color: Colors.greenAccent),
          _StatDivider(),
          _StatItem(
              label: 'Failed',
              value: failed.toString(),
              color: Colors.redAccent),
          const Spacer(),
          if (completed > 0 || failed > 0)
            TextButton.icon(
              onPressed: () => queueProvider.clearCompleted(),
              icon: const Icon(Icons.cleaning_services_rounded, size: 14),
              label: const Text('Clear Done', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (total > 0 && !queueProvider.isProcessing)
            TextButton.icon(
              onPressed: () => queueProvider.clearAll(),
              icon: const Icon(Icons.delete_sweep_rounded, size: 14),
              label: const Text('Clear All', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: theme.colorScheme.error.withAlpha(180),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        Text(label,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.outline)),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: Theme.of(context).colorScheme.outlineVariant.withAlpha(80),
    );
  }
}

class _HeaderActions extends StatelessWidget {
  final TaskQueueProvider queueProvider;
  final SettingsProvider settingsProvider;
  final PickerService pickerService;

  const _HeaderActions({
    required this.queueProvider,
    required this.settingsProvider,
    required this.pickerService,
  });

  @override
  Widget build(BuildContext context) {
    final bool isProcessing = queueProvider.isProcessing;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          onPressed: isProcessing
              ? null
              : () async {
                  final files = await pickerService.pickFiles(
                    initialDirectory:
                        settingsProvider.config.lastUsedInputDirectory,
                    allowMultiple: true,
                    extensions: ['mp4', 'mov', 'srt', 'osd'],
                    label: 'Video & Telemetry Files',
                  );
                  if (files.isNotEmpty) {
                    final dir = Directory(files.first).parent.path;
                    settingsProvider.updateConfig(lastUsedInputDirectory: dir);
                    final result = await queueProvider.addTasksFromFiles(files);
                    if (context.mounted) {
                      _showAddFeedback(context, result);
                    }
                  }
                },
          icon: Icons.add_photo_alternate_rounded,
          label: 'Select Pairs',
          isPrimary: true,
        ),
        const SizedBox(width: 12),
        _ActionButton(
          onPressed: isProcessing
              ? null
              : () async {
                  final dir = await pickerService.pickDirectory(
                    initialDirectory:
                        settingsProvider.config.lastUsedInputDirectory,
                  );
                  if (dir != null) {
                    settingsProvider.updateConfig(lastUsedInputDirectory: dir);
                    final result =
                        await queueProvider.addTasksFromDirectory(dir);
                    if (context.mounted) {
                      _showAddFeedback(context, result);
                    }
                  }
                },
          icon: Icons.folder_copy_rounded,
          label: 'Scan Folder',
          isPrimary: false,
        ),
      ],
    );
  }

  void _showAddFeedback(BuildContext context, TaskAdditionResult result) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    String message;
    bool isError = false;

    if (result.addedCount > 0 || result.partialCount > 0) {
      final List<String> parts = [];
      if (result.addedCount > 0) {
        parts.add(
            '${result.addedCount} task${result.addedCount > 1 ? 's' : ''}');
      }
      if (result.partialCount > 0) {
        parts.add(
            '${result.partialCount} partial item${result.partialCount > 1 ? 's' : ''}');
      }
      message = 'Added ${parts.join(' and ')}';
      if (result.duplicateCount > 0) {
        message += ' (${result.duplicateCount} skipped as duplicates)';
      }
    } else if (result.duplicateCount > 0) {
      message = 'All ${result.duplicateCount} items skipped as duplicates';
      isError = true;
    } else {
      message = 'No valid video-telemetry pairs found';
      isError = true;
    }

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color:
                isError ? colorScheme.onError : colorScheme.onPrimaryContainer,
            fontWeight: isError ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        width: 320,
        backgroundColor:
            isError ? colorScheme.error : colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: isError
            ? SnackBarAction(
                label: 'Help',
                textColor: colorScheme.onError,
                onPressed: () => context.read<NavigationProvider>().setTab(2),
              )
            : null,
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final TaskQueueProvider queueProvider;
  final SettingsProvider settingsProvider;
  final PickerService pickerService;

  const _BottomActionBar({
    required this.queueProvider,
    required this.settingsProvider,
    required this.pickerService,
  });

  @override
  Widget build(BuildContext context) {
    final isProcessing = queueProvider.isProcessing;
    final theme = Theme.of(context);
    final int total = queueProvider.tasks.length;
    final int completed = queueProvider.tasks
        .where((t) => t.status == TaskStatus.completed)
        .length;
    final int readyToStart = queueProvider.tasks
        .where((t) =>
            t.status == TaskStatus.pending || t.status == TaskStatus.failed)
        .length;
    final bool isComplete = completed == total && total > 0;
    final int processingIndex = queueProvider.tasks
        .indexWhere((t) => t.status == TaskStatus.processing);

    String mainLabel = 'Ready to Process';
    String subLabel = '$readyToStart valid pairs ready';
    String buttonText = 'Generate Overlays';
    IconData buttonIcon = Icons.rocket_launch_rounded;
    bool canAction = readyToStart > 0;

    if (total == 0) {
      mainLabel = 'Queue Empty';
      subLabel = 'Drop video & telemetry files to start';
      buttonText = 'Generate Overlays';
      canAction = false;
    } else if (isProcessing) {
      mainLabel = 'Engine Processing...';
      subLabel = 'Task ${processingIndex + 1} of $total';
      buttonText = 'Rendering ${processingIndex + 1}/$total';
      canAction = false;
    } else if (isComplete) {
      mainLabel = 'Queue Complete';
      subLabel = 'All $total videos processed successfully';
      buttonText = 'Open Results';
      buttonIcon = Icons.folder_open_rounded;
      canAction = true;
    } else if (readyToStart > 0) {
      buttonText = 'Start $readyToStart Overlays';
      canAction = true;
    } else {
      mainLabel = 'Waiting for Links';
      subLabel = 'Add missing metadata to enable rendering';
      buttonText = 'Start Overlays';
      canAction = false;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withAlpha(245),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: theme.colorScheme.outlineVariant.withAlpha(80)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  mainLabel,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    subLabel,
                    key: ValueKey(subLabel),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          if (isComplete) ...[
            OutlinedButton.icon(
              onPressed: () => queueProvider.clearAll(),
              icon: const Icon(Icons.delete_sweep_rounded),
              label: const Text('Clear Queue'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(width: 12),
          ],
          FilledButton.icon(
            onPressed: !canAction
                ? null
                : () async {
                    if (isComplete) {
                      final outputDir =
                          settingsProvider.config.defaultOutputDirectory ??
                              settingsProvider.config.lastUsedOutputDirectory;
                      if (outputDir != null) {
                        PlatformUtils.openDirectory(outputDir);
                      }
                      return;
                    }

                    String? outputDir =
                        settingsProvider.config.defaultOutputDirectory;

                    outputDir ??= await pickerService.pickDirectory(
                      initialDirectory:
                          settingsProvider.config.lastUsedOutputDirectory,
                    );

                    if (outputDir != null) {
                      settingsProvider.updateConfig(
                          lastUsedOutputDirectory: outputDir);
                      queueProvider.startQueue(
                          settingsProvider.config, outputDir);
                    }
                  },
            icon: isProcessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : Icon(buttonIcon),
            label: Text(buttonText),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 22),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              backgroundColor: isProcessing
                  ? theme.colorScheme.primary.withAlpha(150)
                  : theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final OverlayTask task;
  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isProcessing = task.status == TaskStatus.processing;
    final isCompleted = task.status == TaskStatus.completed;
    final isFailed = task.status == TaskStatus.failed;

    Color statusColor = theme.colorScheme.onSurfaceVariant;
    IconData statusIcon = Icons.timer_outlined;
    String statusLabel = 'Queued';

    if (isProcessing) {
      statusColor = theme.colorScheme.primary;
      statusIcon = Icons.sync_rounded;
      statusLabel = 'Rendering...';
    } else if (isCompleted) {
      statusColor = const Color(0xFF4CAF50);
      statusIcon = Icons.check_circle_outline_rounded;
      statusLabel = 'Completed';
    } else if (isFailed) {
      statusColor = theme.colorScheme.error;
      statusIcon = Icons.error_outline_rounded;
      statusLabel = 'Failed';
    } else if (task.status == TaskStatus.missingTelemetry) {
      statusColor = theme.colorScheme.tertiary;
      statusIcon = Icons.add_link_rounded;
      statusLabel = 'Waiting for Telemetry';
    } else if (task.status == TaskStatus.missingVideo) {
      statusColor = theme.colorScheme.tertiary;
      statusIcon = Icons.video_file_outlined;
      statusLabel = 'Waiting for Video';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isProcessing
              ? theme.colorScheme.primary.withAlpha(150)
              : theme.colorScheme.outlineVariant.withAlpha(50),
          width: isProcessing ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (isProcessing)
            Positioned.fill(
              child: Opacity(
                opacity: 0.05,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatusIcon(color: statusColor, icon: statusIcon),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Tooltip(
                            message: 'Reveal Source in Finder',
                            child: InkWell(
                              onTap: () {
                                final path = task.videoPath ?? task.overlayPath;
                                if (path != null) {
                                  PlatformUtils.revealFile(path);
                                }
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Text(
                                task.videoFileName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                statusLabel,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                  width: 3,
                                  height: 3,
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: theme.colorScheme.outlineVariant)),
                              const SizedBox(width: 8),
                              _TypeBadge(
                                label: task.type == OverlayType.srt
                                    ? 'SRT Fast'
                                    : 'OSD HD Rendering',
                                color: task.type == OverlayType.srt
                                    ? Colors.blue
                                    : Colors.orange,
                              ),
                              if (task.duration != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                    width: 3,
                                    height: 3,
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color:
                                            theme.colorScheme.outlineVariant)),
                                const SizedBox(width: 8),
                                Text(
                                  '${task.duration!.inSeconds}s',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.primary
                                        .withAlpha(180),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    _TaskActions(
                        task: task,
                        isProcessing: isProcessing,
                        isCompleted: isCompleted),
                  ],
                ),
                if ((isProcessing || isFailed) && task.logs.isNotEmpty)
                  _LogView(logs: task.logs, isError: isFailed),
                if (isFailed && task.errorMessage != null)
                  _ErrorBanner(message: task.errorMessage!),
                if (isProcessing) ...[
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: task.progress > 0 ? task.progress : null,
                      minHeight: 6,
                      backgroundColor: theme.colorScheme.primary.withAlpha(30),
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isProcessing)
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.blueAccent)),
            ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _StatusIcon({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }
}

class _TaskActions extends StatelessWidget {
  final OverlayTask task;
  final bool isProcessing;
  final bool isCompleted;

  const _TaskActions({
    required this.task,
    required this.isProcessing,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> actions = [];
    final provider = context.read<TaskQueueProvider>();
    final settings = context.read<SettingsProvider>();
    final picker = context.read<PickerService>();

    if (task.status == TaskStatus.missingTelemetry) {
      actions.add(_LinkAction(
        label: 'Link Telemetry',
        onPressed: () async {
          final files = await picker.pickFiles(
            initialDirectory: settings.config.lastUsedInputDirectory,
            extensions: ['srt', 'osd'],
            label: 'Telemetry Data',
          );
          if (files.isNotEmpty) {
            provider.updateTaskFiles(task.id, overlayPath: files.first);
          }
        },
      ));
    }

    if (task.status == TaskStatus.missingVideo) {
      actions.add(_LinkAction(
        label: 'Link Video',
        onPressed: () async {
          final files = await picker.pickFiles(
            initialDirectory: settings.config.lastUsedInputDirectory,
            extensions: ['mp4', 'mov'],
            label: 'Video File',
          );
          if (files.isNotEmpty) {
            provider.updateTaskFiles(task.id, videoPath: files.first);
          }
        },
      ));
    }

    if (isCompleted && task.outputPath != null) {
      actions.add(_CircleAction(
        icon: Icons.folder_open_rounded,
        tooltip: 'Reveal Result in Finder',
        onPressed: () => PlatformUtils.revealFile(task.outputPath!),
      ));
    }

    if (!isProcessing) {
      if (actions.isNotEmpty) actions.add(const SizedBox(width: 8));
      actions.add(_CircleAction(
        icon: Icons.close_rounded,
        tooltip: 'Remove',
        isDestructive: true,
        onPressed: () => provider.removeTask(task.id),
      ));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: actions,
    );
  }
}

class _LinkAction extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _LinkAction({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add_link_rounded, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        foregroundColor: theme.colorScheme.secondary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: theme.colorScheme.secondary.withAlpha(20),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isDestructive;

  const _CircleAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(50),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: theme.colorScheme.outlineVariant.withAlpha(50)),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isDestructive
                  ? theme.colorScheme.error.withAlpha(180)
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _TypeBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _LogView extends StatelessWidget {
  final List<String> logs;
  final bool isError;

  const _LogView({required this.logs, required this.isError});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withAlpha(100),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.terminal_rounded,
              size: 14, color: isError ? Colors.redAccent : Colors.blueGrey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              logs.last,
              style: TextStyle(
                fontFamily: 'SF Mono',
                fontSize: 11,
                color:
                    isError ? Colors.redAccent.withAlpha(200) : Colors.blueGrey,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withAlpha(150),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_rounded, size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.video_library_rounded,
                  size: 80,
                  color: theme.colorScheme.primary.withAlpha(120),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'No Tasks in Queue',
                style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'Select your flight video (.mp4/.mov) and its matching telemetry file (.srt/.osd) to begin.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant, height: 1.5),
              ),
              const SizedBox(height: 48),
              _InstructionStep(
                  icon: Icons.file_present_rounded,
                  text: 'Select individual pairs of files'),
              const SizedBox(height: 16),
              _InstructionStep(
                  icon: Icons.folder_rounded,
                  text: 'Scan entire folders for automatic matching'),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InstructionStep({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary.withAlpha(100)),
        const SizedBox(width: 16),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _PerformanceInsightsCard extends StatelessWidget {
  final TaskQueueProvider queueProvider;
  const _PerformanceInsightsCard({required this.queueProvider});

  @override
  Widget build(BuildContext context) {
    final completedTasks = queueProvider.tasks
        .where((t) => t.status == TaskStatus.completed)
        .toList();

    if (completedTasks.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final totalDuration = completedTasks.fold<Duration>(
      Duration.zero,
      (prev, t) => prev + (t.duration ?? Duration.zero),
    );

    final avgCpuLoad =
        completedTasks.where((t) => t.cpuUsageAtStart != null).isEmpty
            ? null
            : completedTasks
                    .where((t) => t.cpuUsageAtStart != null)
                    .fold<double>(0, (prev, t) => prev + t.cpuUsageAtStart!) /
                completedTasks.where((t) => t.cpuUsageAtStart != null).length;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withAlpha(50),
            theme.colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.primary.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_rounded,
                  size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                'Performance Report',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(
                'LIVE INSIGHTS',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ReportMetric(
                label: 'Avg. Render Time',
                value:
                    '${(totalDuration.inSeconds / completedTasks.length).toStringAsFixed(1)}s',
                icon: Icons.timer_rounded,
              ),
              _ReportMetric(
                label: 'Total Time Saved',
                value:
                    '${totalDuration.inMinutes}m ${totalDuration.inSeconds % 60}s',
                icon: Icons.bolt_rounded,
              ),
              if (avgCpuLoad != null)
                _ReportMetric(
                  label: 'Workload Impact',
                  value: '${avgCpuLoad.toStringAsFixed(0)}% CPU',
                  icon: Icons.memory_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ReportMetric(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final bool isPrimary;

  const _ActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
