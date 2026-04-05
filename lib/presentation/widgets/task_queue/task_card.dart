import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:fpv_overlay_app/application/providers/navigation_provider.dart';
import 'package:fpv_overlay_app/application/providers/settings_provider.dart';
import 'package:fpv_overlay_app/application/providers/task_queue_provider.dart';
import 'package:fpv_overlay_app/core/utils/platform_utils.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';
import 'package:fpv_overlay_app/infrastructure/services/picker_service.dart';

class TaskCard extends StatelessWidget {
  final OverlayTask task;
  final VoidCallback? onOpenLogs;

  const TaskCard({
    super.key,
    required this.task,
    this.onOpenLogs,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isProcessing = task.status == TaskStatus.processing;
    final isCompleted = task.status == TaskStatus.completed;
    final isFailed = task.status == TaskStatus.failed;

    Color statusColor = theme.colorScheme.onSurfaceVariant;
    IconData statusIcon = Icons.timer_rounded;
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
    } else if (task.status == TaskStatus.cancelled) {
      statusColor = theme.colorScheme.onSurfaceVariant;
      statusIcon = Icons.cancel_rounded;
      statusLabel = 'Cancelled';
    } else if (task.status == TaskStatus.missingTelemetry) {
      statusColor = theme.colorScheme.tertiary;
      statusIcon = Icons.add_link_rounded;
      statusLabel = 'Waiting for Telemetry';
    } else if (task.status == TaskStatus.missingVideo) {
      statusColor = theme.colorScheme.tertiary;
      statusIcon = Icons.video_file_rounded;
      statusLabel = 'Waiting for Video';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackedHeader = constraints.maxWidth < 760;
        final taskActions = _TaskActions(
          task: task,
          isProcessing: isProcessing,
          isCompleted: isCompleted,
          onOpenLogs: onOpenLogs,
        );
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tooltip(
              message: 'Reveal source in Finder',
              child: InkWell(
                onTap: () {
                  final path = task.videoPath ?? task.osdPath ?? task.srtPath;
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
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  statusLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
                if (task.type != OverlayType.unknown)
                  _TypeBadge(
                    label: task.type == OverlayType.srt
                        ? 'SRT Telemetry'
                        : task.type == OverlayType.combined
                            ? 'OSD + SRT'
                            : 'OSD HD Rendering',
                    color: task.type == OverlayType.srt
                        ? Colors.blue
                        : task.type == OverlayType.combined
                            ? Colors.purple
                            : Colors.orange,
                  )
                else
                  const _TypeBadge(
                    label: 'Link Telemetry',
                    color: Colors.grey,
                  ),
                if (task.startTime != null)
                  _ElapsedTimer(
                    startTime: task.startTime!,
                    endTime: task.endTime,
                    isActive: isProcessing,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary.withAlpha(180),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                Text(
                  'Added ${_formatCreatedAt(task.createdAt)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 16.0),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isProcessing
                  ? theme.colorScheme.primary.withAlpha(120)
                  : theme.colorScheme.outlineVariant.withAlpha(50),
              width: isProcessing ? 2 : 1,
            ),
            boxShadow: isProcessing
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withAlpha(30),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
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
                  padding: EdgeInsets.all(stackedHeader ? 18 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (stackedHeader)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _StatusIcon(
                                  color: statusColor,
                                  icon: statusIcon,
                                ),
                                const SizedBox(width: 14),
                                Expanded(child: titleBlock),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Align(
                              alignment: Alignment.centerRight,
                              child: taskActions,
                            ),
                          ],
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _StatusIcon(color: statusColor, icon: statusIcon),
                            const SizedBox(width: 16),
                            Expanded(child: titleBlock),
                            const SizedBox(width: 12),
                            taskActions,
                          ],
                        ),
                      _TaskSnapshotStrip(
                        task: task,
                        isProcessing: isProcessing,
                        isCompleted: isCompleted,
                        isFailed: isFailed,
                      ),
                      if (isFailed) _FailurePanel(task: task),
                      if (isProcessing) ...[
                        const SizedBox(height: 20),
                        if (task.progressPhase != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    task.progressPhase!,
                                    style:
                                        theme.textTheme.labelMedium?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                if (task.progress > 0)
                                  Text(
                                    '${(task.progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                                    style:
                                        theme.textTheme.labelMedium?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: task.progress > 0 ? task.progress : null,
                            minHeight: 6,
                            backgroundColor:
                                theme.colorScheme.primary.withAlpha(30),
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
                      decoration: BoxDecoration(color: Colors.blueAccent),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatCreatedAt(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}

/// A lightweight timer widget that ticks every second only while the task is
/// actively processing. For completed/failed tasks it renders a static label,
/// so there is zero ongoing cost.
class _ElapsedTimer extends StatefulWidget {
  final DateTime startTime;
  final DateTime? endTime;
  final bool isActive;
  final TextStyle? style;

  const _ElapsedTimer({
    required this.startTime,
    this.endTime,
    required this.isActive,
    this.style,
  });

  @override
  State<_ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<_ElapsedTimer> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(_ElapsedTimer old) {
    super.didUpdateWidget(old);
    if (old.isActive != widget.isActive) {
      _timer?.cancel();
      _timer = null;
      _startTimerIfNeeded();
    }
  }

  void _startTimerIfNeeded() {
    if (widget.isActive) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final totalSeconds = d.inSeconds;
    if (totalSeconds < 60) return '${totalSeconds}s';
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = widget.endTime != null
        ? widget.endTime!.difference(widget.startTime)
        : DateTime.now().difference(widget.startTime);

    return Text(_formatDuration(elapsed), style: widget.style);
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

class _TaskSnapshotStrip extends StatelessWidget {
  final OverlayTask task;
  final bool isProcessing;
  final bool isCompleted;
  final bool isFailed;

  const _TaskSnapshotStrip({
    required this.task,
    required this.isProcessing,
    required this.isCompleted,
    required this.isFailed,
  });

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _SnapshotTile(
        label: 'Video',
        value: task.videoPath != null
            ? p.basename(task.videoPath!)
            : 'Missing video',
        icon: task.videoPath != null
            ? Icons.video_file_rounded
            : Icons.videocam_off_rounded,
        color: task.videoPath != null
            ? Theme.of(context).colorScheme.onSurface
            : Theme.of(context).colorScheme.tertiary,
      ),
      _SnapshotTile(
        label: 'Telemetry',
        value: _telemetryValue(),
        icon: _telemetryIcon(),
        color: _telemetryColor(context),
      ),
      _SnapshotTile(
        label: _nextLabel(),
        value: _nextValue(),
        icon: _nextIcon(),
        color: _nextColor(context),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 860) {
            return Column(
              children: [
                for (var index = 0; index < tiles.length; index++) ...[
                  if (index > 0) const SizedBox(height: 10),
                  tiles[index],
                ],
              ],
            );
          }

          return Row(
            children: [
              for (var index = 0; index < tiles.length; index++) ...[
                if (index > 0) const SizedBox(width: 12),
                Expanded(child: tiles[index]),
              ],
            ],
          );
        },
      ),
    );
  }

  String _telemetryValue() {
    switch (task.type) {
      case OverlayType.combined:
        return 'OSD + SRT linked';
      case OverlayType.osd:
        return 'OSD linked';
      case OverlayType.srt:
        return 'SRT linked';
      case OverlayType.unknown:
        return 'Missing telemetry';
    }
  }

  IconData _telemetryIcon() {
    switch (task.type) {
      case OverlayType.combined:
        return Icons.layers_rounded;
      case OverlayType.osd:
        return Icons.memory_rounded;
      case OverlayType.srt:
        return Icons.subtitles_rounded;
      case OverlayType.unknown:
        return Icons.link_off_rounded;
    }
  }

  Color _telemetryColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (task.type) {
      case OverlayType.combined:
        return const Color(0xFFB88CFF);
      case OverlayType.osd:
        return const Color(0xFFFFC66D);
      case OverlayType.srt:
        return const Color(0xFF75D1FF);
      case OverlayType.unknown:
        return theme.colorScheme.tertiary;
    }
  }

  String _nextLabel() {
    if (isCompleted) return 'Output';
    if (isFailed) return 'Failure';
    if (task.status == TaskStatus.cancelled) return 'Result';
    return 'Next step';
  }

  String _nextValue() {
    if (isCompleted) {
      return task.outputPath != null
          ? p.basename(task.outputPath!)
          : 'Saved to output folder';
    }
    if (isProcessing) {
      return task.progressPhase ?? 'Rendering overlay';
    }
    if (isFailed) {
      return task.failure?.summary ??
          task.errorMessage ??
          'Render failed before completion';
    }
    if (task.status == TaskStatus.missingTelemetry) {
      return 'Attach an .srt or .osd file';
    }
    if (task.status == TaskStatus.missingVideo) {
      return 'Attach the source video';
    }
    if (task.status == TaskStatus.cancelled) {
      return 'Stopped before the output finished';
    }
    return 'Ready to render';
  }

  IconData _nextIcon() {
    if (isCompleted) return Icons.video_file_rounded;
    if (isFailed) return Icons.error_outline_rounded;
    if (isProcessing) return Icons.auto_awesome_motion_rounded;
    if (task.status == TaskStatus.missingTelemetry) {
      return Icons.add_link_rounded;
    }
    if (task.status == TaskStatus.missingVideo) return Icons.video_call_rounded;
    if (task.status == TaskStatus.cancelled) return Icons.stop_circle_outlined;
    return Icons.rocket_launch_rounded;
  }

  Color _nextColor(BuildContext context) {
    final theme = Theme.of(context);
    if (isCompleted) return const Color(0xFF7FF2B3);
    if (isFailed) return theme.colorScheme.error;
    if (isProcessing) return theme.colorScheme.primary;
    if (task.status == TaskStatus.missingTelemetry ||
        task.status == TaskStatus.missingVideo) {
      return theme.colorScheme.tertiary;
    }
    return theme.colorScheme.primary;
  }
}

class _SnapshotTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SnapshotTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(64),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: theme.colorScheme.outlineVariant.withAlpha(50)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withAlpha(24),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskActions extends StatelessWidget {
  final OverlayTask task;
  final bool isProcessing;
  final bool isCompleted;
  final VoidCallback? onOpenLogs;

  const _TaskActions({
    required this.task,
    required this.isProcessing,
    required this.isCompleted,
    this.onOpenLogs,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> actions = [];
    final provider = context.read<TaskQueueProvider>();
    final settings = context.read<SettingsProvider>();
    final picker = context.read<PickerService>();

    if (task.status == TaskStatus.missingTelemetry) {
      actions.add(
        _LinkAction(
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
        ),
      );
    }

    if (task.status == TaskStatus.missingVideo) {
      actions.add(
        _LinkAction(
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
        ),
      );
    }

    final hasUsefulLogs = onOpenLogs != null &&
        (isProcessing ||
            isCompleted ||
            task.status == TaskStatus.failed ||
            task.status == TaskStatus.cancelled);
    if (hasUsefulLogs) {
      actions.add(
        _LinkAction(
          label: isProcessing ? 'Activity' : 'Details',
          icon: Icons.terminal_rounded,
          onPressed: onOpenLogs!,
        ),
      );
    }

    if (isCompleted && task.outputPath != null) {
      actions.add(
        _LinkAction(
          label: 'Result',
          icon: Icons.folder_open_rounded,
          onPressed: () => PlatformUtils.revealFile(task.outputPath!),
        ),
      );
    }

    if (!isProcessing) {
      actions.add(
        _CircleAction(
          icon: Icons.close_rounded,
          tooltip: 'Remove',
          isDestructive: true,
          onPressed: () => provider.removeTask(task.id),
        ),
      );
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: actions,
    );
  }
}

class _LinkAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _LinkAction({
    required this.label,
    required this.onPressed,
    this.icon = Icons.add_link_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
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
                color: theme.colorScheme.outlineVariant.withAlpha(50),
              ),
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

class _FailurePanel extends StatefulWidget {
  final OverlayTask task;

  const _FailurePanel({required this.task});

  @override
  State<_FailurePanel> createState() => _FailurePanelState();
}

class _FailurePanelState extends State<_FailurePanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final failure = widget.task.failure;
    final summary = failure?.summary ??
        widget.task.errorMessage ??
        'Execution failed. Check the raw trace for details.';
    final details = failure?.details ?? widget.task.logs.join('\n').trim();
    final failureCode = failure?.code ?? 'PROCESS_FAILED';
    final exitCode = failure?.exitCode;
    final suggestion = failure?.suggestion;
    final isRuntimeIssue = failureCode.startsWith('RUNTIME_') ||
        failureCode == 'PYTHON_DEPENDENCIES_MISSING' ||
        failureCode == 'OSD_READER_IMPORT_FAILED';

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withAlpha(150),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_rounded,
                size: 18,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  summary,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FailureChip(label: failureCode),
              if (exitCode != null) _FailureChip(label: 'exit $exitCode'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 16,
                ),
                label: Text(
                  _expanded ? 'Hide details' : 'Show details',
                  style: const TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: theme.colorScheme.error,
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: details));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied failure details.')),
                  );
                },
                icon: const Icon(Icons.content_copy_rounded, size: 14),
                label: const Text(
                  'Copy trace',
                  style: TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: theme.colorScheme.onErrorContainer,
                ),
              ),
            ],
          ),
          if (isRuntimeIssue) ...[
            TextButton.icon(
              onPressed: () => context.read<NavigationProvider>().setTab(1),
              icon: const Icon(Icons.settings_rounded, size: 14),
              label: const Text(
                'Open Settings',
                style: TextStyle(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: theme.colorScheme.error,
              ),
            ),
          ],
          if (_expanded) ...[
            if (suggestion != null && suggestion.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withAlpha(140),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  suggestion,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (details.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withAlpha(180),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(
                  details,
                  maxLines: 14,
                  style: TextStyle(
                    fontFamily: 'SF Mono',
                    fontSize: 11,
                    color: theme.colorScheme.onSurface,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _FailureChip extends StatelessWidget {
  final String label;

  const _FailureChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withAlpha(170),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
