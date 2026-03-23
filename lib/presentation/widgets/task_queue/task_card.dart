import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:fpv_overlay_app/application/providers/navigation_provider.dart';
import 'package:fpv_overlay_app/application/providers/settings_provider.dart';
import 'package:fpv_overlay_app/application/providers/task_queue_provider.dart';
import 'package:fpv_overlay_app/core/utils/platform_utils.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';
import 'package:fpv_overlay_app/domain/services/telemetry.dart';
import 'package:fpv_overlay_app/infrastructure/services/picker_service.dart';

class TaskCard extends StatelessWidget {
  final OverlayTask task;
  const TaskCard({super.key, required this.task});

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
    } else if (task.status == TaskStatus.cancelled) {
      statusColor = theme.colorScheme.onSurfaceVariant;
      statusIcon = Icons.cancel_outlined;
      statusLabel = 'Cancelled';
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
                                final path = task.videoPath ??
                                    task.osdPath ??
                                    task.srtPath;
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
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                              const SizedBox(width: 8),
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
                              if (task.startTime != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 3,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _ElapsedTimer(
                                  startTime: task.startTime!,
                                  endTime: task.endTime,
                                  isActive: isProcessing,
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
                      isCompleted: isCompleted,
                    ),
                  ],
                ),
                if (isProcessing && task.logs.isNotEmpty)
                  _LogView(logs: task.logs, isError: isFailed),
                if (isFailed) _FailurePanel(task: task),
                if (isProcessing) ...[
                  const SizedBox(height: 20),
                  if (task.progressPhase != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Text(
                            task.progressPhase!,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          if (task.progress > 0)
                            Text(
                              '${(task.progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                              style: theme.textTheme.labelMedium?.copyWith(
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
                decoration: BoxDecoration(color: Colors.blueAccent),
              ),
            ),
        ],
      ),
    );
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
              Telemetry.taskLinked(task.id, 'telemetry');
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
              Telemetry.taskLinked(task.id, 'video');
            }
          },
        ),
      );
    }

    if (isCompleted && task.outputPath != null) {
      actions.add(
        _CircleAction(
          icon: Icons.folder_open_rounded,
          tooltip: 'Reveal Result in Finder',
          onPressed: () => PlatformUtils.revealFile(task.outputPath!),
        ),
      );
    }

    if (!isProcessing) {
      if (actions.isNotEmpty) actions.add(const SizedBox(width: 8));
      actions.add(
        _CircleAction(
          icon: Icons.close_rounded,
          tooltip: 'Remove',
          isDestructive: true,
          onPressed: () => provider.removeTask(task.id),
        ),
      );
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
          Icon(
            Icons.terminal_rounded,
            size: 14,
            color: isError ? Colors.redAccent : Colors.blueGrey,
          ),
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
          Row(
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
              const Spacer(),
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
                'Open System Info',
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
                constraints: const BoxConstraints(maxHeight: 220),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withAlpha(180),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    details,
                    style: TextStyle(
                      fontFamily: 'SF Mono',
                      fontSize: 11,
                      color: theme.colorScheme.onSurface,
                    ),
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
