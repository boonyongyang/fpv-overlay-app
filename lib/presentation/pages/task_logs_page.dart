import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:fpv_overlay_app/application/providers/task_queue_provider.dart';
import 'package:fpv_overlay_app/core/utils/platform_utils.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';
import 'package:fpv_overlay_app/presentation/utils/workspace_actions.dart';

enum _LogViewMode { activity, raw }

enum _ActivityTone { info, success, warning, error, neutral }

class TaskLogsPage extends StatefulWidget {
  final String taskId;

  const TaskLogsPage({
    super.key,
    required this.taskId,
  });

  @override
  State<TaskLogsPage> createState() => _TaskLogsPageState();
}

class _TaskLogsPageState extends State<TaskLogsPage> {
  final ScrollController _scrollController = ScrollController();
  int _lastLogCount = -1;
  bool _followLogs = true;
  _LogViewMode _viewMode = _LogViewMode.activity;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      _followLogs = (position.maxScrollExtent - position.pixels) < 96;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final queueProvider = context.watch<TaskQueueProvider>();
    OverlayTask? task;
    for (final candidate in queueProvider.tasks) {
      if (candidate.id == widget.taskId) {
        task = candidate;
        break;
      }
    }

    if (task != null && task.logs.length != _lastLogCount) {
      _lastLogCount = task.logs.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients || !_followLogs) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      });
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(task?.videoFileName ?? 'Render Activity'),
      ),
      body: SafeArea(
        child: task == null
            ? const _MissingTaskState()
            : _TaskLogView(
                task: task,
                scrollController: _scrollController,
                viewMode: _viewMode,
                onViewModeChanged: (mode) => setState(() => _viewMode = mode),
              ),
      ),
    );
  }
}

class _TaskLogView extends StatelessWidget {
  final OverlayTask task;
  final ScrollController scrollController;
  final _LogViewMode viewMode;
  final ValueChanged<_LogViewMode> onViewModeChanged;

  const _TaskLogView({
    required this.task,
    required this.scrollController,
    required this.viewMode,
    required this.onViewModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logs = task.logs;
    final activityEntries = _buildActivityEntries(logs);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LogHeader(task: task),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(label: task.status.name.replaceAll('_', ' ')),
              _StatusPill(label: task.type.name.toUpperCase()),
              _StatusPill(label: task.progressPhase ?? 'Idle'),
              _StatusPill(label: '${activityEntries.length} activity items'),
            ],
          ),
          if (task.failure != null || task.errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withAlpha(140),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                task.failure?.summary ?? task.errorMessage ?? 'Task failed.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _RunStatusCard(task: task),
          const SizedBox(height: 16),
          SegmentedButton<_LogViewMode>(
            segments: const [
              ButtonSegment<_LogViewMode>(
                value: _LogViewMode.activity,
                icon: Icon(Icons.bolt_rounded, size: 16),
                label: Text('Activity'),
              ),
              ButtonSegment<_LogViewMode>(
                value: _LogViewMode.raw,
                icon: Icon(Icons.terminal_rounded, size: 16),
                label: Text('Raw Console'),
              ),
            ],
            selected: <_LogViewMode>{viewMode},
            onSelectionChanged: (selection) {
              if (selection.isEmpty) return;
              onViewModeChanged(selection.first);
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withAlpha(50),
                ),
              ),
              child: viewMode == _LogViewMode.activity
                  ? _ActivityFeed(
                      entries: activityEntries,
                      scrollController: scrollController,
                    )
                  : _RawConsole(
                      logs: logs,
                      scrollController: scrollController,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  List<_ActivityEntry> _buildActivityEntries(List<String> logs) {
    final entries = <_ActivityEntry>[];

    for (final rawLine in logs) {
      final normalized = _normalizeLogLine(rawLine);
      final line = normalized.message.trim();
      if (line.isEmpty || line.contains('time=')) continue;

      if (line.contains('Pass 1 complete')) {
        _completeProgressEntry(
          entries,
          title: 'Rendering OSD frames',
          timestamp: normalized.timestamp,
        );
      } else if (line.contains('Pass 2 complete')) {
        _completeProgressEntry(
          entries,
          title: 'Compositing video',
          timestamp: normalized.timestamp,
        );
      } else if (line.contains('✅ Process completed successfully')) {
        _completeProgressEntry(
          entries,
          title: task.progressPhase ?? _lastProgressTitle(entries),
          timestamp: normalized.timestamp,
        );
      }

      final progressEntry = _parseProgressEntry(normalized);
      if (progressEntry != null) {
        if (entries.isNotEmpty &&
            entries.last.isProgress &&
            entries.last.title == progressEntry.title) {
          entries[entries.length - 1] = progressEntry;
        } else {
          entries.add(progressEntry);
        }
        continue;
      }

      final eventEntry = _parseEventEntry(normalized);
      if (eventEntry != null) {
        if (entries.isNotEmpty &&
            entries.last.title == eventEntry.title &&
            entries.last.detail == eventEntry.detail) {
          continue;
        }
        entries.add(eventEntry);
      }
    }

    if (task.status == TaskStatus.completed) {
      _completeProgressEntry(
        entries,
        title: task.progressPhase ?? _lastProgressTitle(entries),
      );
    }

    return entries;
  }

  void _completeProgressEntry(
    List<_ActivityEntry> entries, {
    required String? title,
    String? timestamp,
  }) {
    if (title == null || title.isEmpty) return;
    for (var index = entries.length - 1; index >= 0; index--) {
      final entry = entries[index];
      if (!entry.isProgress || entry.title != title) continue;
      entries[index] = entry.copyWith(
        detail: _completedProgressDetail(entry),
        progress: 1.0,
        timestamp: timestamp ?? entry.timestamp,
      );
      return;
    }

    entries.add(
      _ActivityEntry(
        title: title,
        detail: '100% complete',
        timestamp: timestamp,
        tone: _ActivityTone.info,
        progress: 1.0,
        isProgress: true,
      ),
    );
  }

  String _completedProgressDetail(_ActivityEntry entry) {
    final detail = entry.detail;
    if (detail == null || detail.isEmpty) return '100% complete';

    final frameMatch = RegExp(r'(\d+)\s*/\s*(\d+)\s+frames').firstMatch(detail);
    if (frameMatch != null) {
      final total = frameMatch.group(2)!;
      return '$total / $total frames';
    }

    return '100% complete';
  }

  String? _lastProgressTitle(List<_ActivityEntry> entries) {
    for (var index = entries.length - 1; index >= 0; index--) {
      if (entries[index].isProgress) return entries[index].title;
    }
    return null;
  }

  _ActivityEntry? _parseProgressEntry(_NormalizedLogLine line) {
    final osdFrameMatch = RegExp(r'OSD frame (\d+)/(\d+)').firstMatch(
      line.message,
    );
    if (osdFrameMatch != null) {
      final current = int.parse(osdFrameMatch.group(1)!);
      final total = int.parse(osdFrameMatch.group(2)!);
      final progress = total == 0 ? 0.0 : current / total;
      return _ActivityEntry(
        title: 'Rendering OSD frames',
        detail: '$current / $total frames',
        timestamp: line.timestamp,
        tone: _ActivityTone.info,
        progress: progress.clamp(0.0, 1.0).toDouble(),
        isProgress: true,
      );
    }

    final compositingMatch = RegExp(r'Compositing:\s*(\d+)%').firstMatch(
      line.message,
    );
    if (compositingMatch != null) {
      final value = int.parse(compositingMatch.group(1)!);
      return _ActivityEntry(
        title: 'Compositing video',
        detail: '$value% complete',
        timestamp: line.timestamp,
        tone: _ActivityTone.info,
        progress: (value / 100).clamp(0.0, 1.0).toDouble(),
        isProgress: true,
      );
    }

    final renderingMatch = RegExp(r'Rendering:\s*(\d+)%').firstMatch(
      line.message,
    );
    if (renderingMatch != null) {
      final value = int.parse(renderingMatch.group(1)!);
      return _ActivityEntry(
        title: 'Rendering SRT overlay',
        detail: '$value% complete',
        timestamp: line.timestamp,
        tone: _ActivityTone.info,
        progress: (value / 100).clamp(0.0, 1.0).toDouble(),
        isProgress: true,
      );
    }

    return null;
  }

  _ActivityEntry? _parseEventEntry(_NormalizedLogLine line) {
    final message = line.message;
    if (message.startsWith('▶')) {
      return _ActivityEntry(
        title: 'Batch task started',
        detail: message.substring(1).trim(),
        timestamp: line.timestamp,
        tone: _ActivityTone.info,
      );
    }
    if (message.startsWith('▸ Video:')) {
      return _ActivityEntry(
        title: 'Video source',
        detail: p.basename(message.substring('▸ Video:'.length).trim()),
        timestamp: line.timestamp,
        tone: _ActivityTone.neutral,
      );
    }
    if (message.startsWith('▸ OSD:')) {
      return _ActivityEntry(
        title: 'OSD source',
        detail: p.basename(message.substring('▸ OSD:'.length).trim()),
        timestamp: line.timestamp,
        tone: _ActivityTone.neutral,
      );
    }
    if (message.startsWith('▸ SRT:')) {
      return _ActivityEntry(
        title: 'SRT source',
        detail: p.basename(message.substring('▸ SRT:'.length).trim()),
        timestamp: line.timestamp,
        tone: _ActivityTone.neutral,
      );
    }
    if (message.startsWith('◎ Output:')) {
      return _ActivityEntry(
        title: 'Output target',
        detail: p.basename(message.substring('◎ Output:'.length).trim()),
        timestamp: line.timestamp,
        tone: _ActivityTone.info,
      );
    }
    if (message.startsWith('✓')) {
      return _ActivityEntry(
        title: 'Render completed',
        detail: message.substring(1).trim(),
        timestamp: line.timestamp,
        tone: _ActivityTone.success,
      );
    }
    if (message.startsWith('★')) {
      return _ActivityEntry(
        title: 'Result ready',
        detail: p.basename(
          message
              .replaceFirst('★ Result ready at', '')
              .replaceFirst(RegExp(r'\.$'), '')
              .trim(),
        ),
        timestamp: line.timestamp,
        tone: _ActivityTone.success,
      );
    }
    if (message.startsWith('✖')) {
      return _ActivityEntry(
        title: 'Task failed',
        detail: message.substring(1).trim(),
        timestamp: line.timestamp,
        tone: _ActivityTone.error,
      );
    }
    if (message.startsWith('⚠')) {
      return _ActivityEntry(
        title: 'Unhandled failure',
        detail: message.substring(1).trim(),
        timestamp: line.timestamp,
        tone: _ActivityTone.error,
      );
    }
    if (message.startsWith('⏹')) {
      return _ActivityEntry(
        title: 'Render cancelled',
        detail: message.substring(1).trim(),
        timestamp: line.timestamp,
        tone: _ActivityTone.warning,
      );
    }
    if (message.contains('Pass 1 complete')) {
      return _ActivityEntry(
        title: 'Pass 1 complete',
        detail: 'OSD rendering finished. Moving into compositing.',
        timestamp: line.timestamp,
        tone: _ActivityTone.info,
      );
    }
    if (message.contains('Pass 2:')) {
      return _ActivityEntry(
        title: 'Pass 2 started',
        detail: 'Compositing overlay onto the source video.',
        timestamp: line.timestamp,
        tone: _ActivityTone.info,
      );
    }
    if (message.contains('Pass 2 complete')) {
      return _ActivityEntry(
        title: 'Pass 2 complete',
        detail: 'Final compositing finished and the output was written.',
        timestamp: line.timestamp,
        tone: _ActivityTone.success,
      );
    }
    if (message.contains('Applying OSD HD Rendering') ||
        message.contains('Starting OSD HD Rendering')) {
      return _ActivityEntry(
        title: 'Preparing OSD render',
        detail: 'Setting up HD overlay generation.',
        timestamp: line.timestamp,
        tone: _ActivityTone.info,
      );
    }
    if (message.contains('Parsing SRT telemetry')) {
      return _ActivityEntry(
        title: 'Parsing telemetry',
        detail: 'Reading subtitle-based telemetry data.',
        timestamp: line.timestamp,
        tone: _ActivityTone.info,
      );
    }
    if (message.contains('Rendering SRT HUD')) {
      return _ActivityEntry(
        title: 'Rendering SRT overlay',
        detail: 'Compositing text telemetry onto the video.',
        timestamp: line.timestamp,
        tone: _ActivityTone.info,
      );
    }
    if (message.contains('✅ Process completed successfully')) {
      return _ActivityEntry(
        title: 'Engine reported success',
        detail: 'The render pipeline returned a successful exit.',
        timestamp: line.timestamp,
        tone: _ActivityTone.success,
      );
    }
    if (_looksLikeNoise(message)) return null;

    return _ActivityEntry(
      title: message,
      timestamp: line.timestamp,
      tone: _ActivityTone.neutral,
    );
  }

  _NormalizedLogLine _normalizeLogLine(String rawLine) {
    final match = RegExp(r'^\[([^\]]+)\]\s*(.*)$').firstMatch(rawLine);
    if (match == null) {
      return _NormalizedLogLine(message: rawLine, timestamp: null);
    }
    return _NormalizedLogLine(
      message: match.group(2) ?? rawLine,
      timestamp: _formatTimestamp(match.group(1)),
    );
  }

  bool _looksLikeNoise(String line) {
    return line.startsWith('ffmpeg version') ||
        line.startsWith('Input #') ||
        line.startsWith('Output #') ||
        line.startsWith('Stream #') ||
        line.startsWith('Metadata:');
  }

  String? _formatTimestamp(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final hh = parsed.hour.toString().padLeft(2, '0');
    final mm = parsed.minute.toString().padLeft(2, '0');
    final ss = parsed.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }
}

class _RunStatusCard extends StatelessWidget {
  final OverlayTask task;

  const _RunStatusCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = task.progress.clamp(0.0, 1.0).toDouble();
    final headline = _headline();
    final detail = _detail();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withAlpha(54),
            theme.colorScheme.surfaceContainerHighest.withAlpha(30),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withAlpha(40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _accentColor(context).withAlpha(24),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_icon(), color: _accentColor(context), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (task.duration != null)
                _StatusPill(label: _formatDuration(task.duration!)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: task.status == TaskStatus.processing || progress > 0
                  ? progress
                  : null,
              minHeight: 10,
              backgroundColor: theme.colorScheme.surface.withAlpha(180),
              color: _accentColor(context),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                task.progressPhase ?? 'Idle',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _accentColor(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _headline() {
    switch (task.status) {
      case TaskStatus.processing:
        return 'Render is live';
      case TaskStatus.completed:
        return 'Render finished successfully';
      case TaskStatus.failed:
        return 'Render failed';
      case TaskStatus.cancelled:
        return 'Render was cancelled';
      case TaskStatus.pending:
        return 'Waiting to start';
      case TaskStatus.missingTelemetry:
        return 'Telemetry still missing';
      case TaskStatus.missingVideo:
        return 'Video still missing';
    }
  }

  String _detail() {
    switch (task.status) {
      case TaskStatus.processing:
        return task.progressPhase == null
            ? 'The engine is setting up this task.'
            : 'The engine is currently working on ${task.progressPhase!.toLowerCase()}.';
      case TaskStatus.completed:
        return task.outputPath != null
            ? 'Output written to ${p.basename(task.outputPath!)}.'
            : 'Output is ready in the selected destination folder.';
      case TaskStatus.failed:
        return task.failure?.summary ??
            task.errorMessage ??
            'Review the activity feed or raw console if you need the trace.';
      case TaskStatus.cancelled:
        return 'No more work will be done for this task unless you rerun it.';
      case TaskStatus.pending:
        return 'The task is fully linked and ready for the queue.';
      case TaskStatus.missingTelemetry:
        return 'Add an .srt or .osd file to make this task renderable.';
      case TaskStatus.missingVideo:
        return 'Attach the source video to make this task renderable.';
    }
  }

  IconData _icon() {
    switch (task.status) {
      case TaskStatus.processing:
        return Icons.motion_photos_on_rounded;
      case TaskStatus.completed:
        return Icons.check_circle_outline_rounded;
      case TaskStatus.failed:
        return Icons.error_outline_rounded;
      case TaskStatus.cancelled:
        return Icons.stop_circle_outlined;
      case TaskStatus.pending:
        return Icons.rocket_launch_rounded;
      case TaskStatus.missingTelemetry:
        return Icons.link_off_rounded;
      case TaskStatus.missingVideo:
        return Icons.video_call_rounded;
    }
  }

  Color _accentColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (task.status) {
      case TaskStatus.processing:
        return theme.colorScheme.primary;
      case TaskStatus.completed:
        return const Color(0xFF7FF2B3);
      case TaskStatus.failed:
        return theme.colorScheme.error;
      case TaskStatus.cancelled:
        return theme.colorScheme.tertiary;
      case TaskStatus.pending:
        return theme.colorScheme.primary;
      case TaskStatus.missingTelemetry:
      case TaskStatus.missingVideo:
        return theme.colorScheme.tertiary;
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    }
    return '${duration.inSeconds}s';
  }
}

class _ActivityFeed extends StatelessWidget {
  final List<_ActivityEntry> entries;
  final ScrollController scrollController;

  const _ActivityFeed({
    required this.entries,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No activity yet. Once the engine starts producing meaningful events, they will appear here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _ActivityEntryTile(entry: entries[index]);
      },
    );
  }
}

class _RawConsole extends StatelessWidget {
  final List<String> logs;
  final ScrollController scrollController;

  const _RawConsole({
    required this.logs,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (logs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No raw console output yet.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(18),
      child: SelectableText(
        logs.join('\n'),
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          height: 1.45,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _LogHeader extends StatelessWidget {
  final OverlayTask task;

  const _LogHeader({required this.task});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 760;
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: () =>
                  copyDiagnosticsToClipboard(context, selectedTask: task),
              icon: const Icon(Icons.content_copy_rounded, size: 16),
              label: const Text('Copy report'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _copyRawLogs(context, task),
              icon: const Icon(Icons.article_rounded, size: 16),
              label: const Text('Copy logs'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                final source = task.videoPath ?? task.osdPath ?? task.srtPath;
                if (source != null) {
                  PlatformUtils.revealFile(source);
                }
              },
              icon: const Icon(Icons.folder_open_rounded, size: 16),
              label: const Text('Reveal source'),
            ),
            if (task.outputPath != null)
              OutlinedButton.icon(
                onPressed: () => PlatformUtils.revealFile(task.outputPath!),
                icon: const Icon(Icons.video_file_rounded, size: 16),
                label: const Text('Reveal output'),
              ),
          ],
        );

        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Render Activity',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'A condensed live view for ${task.videoFileName}, with the raw console available only when you need it.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
          ],
        );

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              const SizedBox(height: 14),
              actions,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            const SizedBox(width: 16),
            Flexible(child: actions),
          ],
        );
      },
    );
  }

  Future<void> _copyRawLogs(BuildContext context, OverlayTask task) async {
    final messenger = ScaffoldMessenger.of(context);
    final text = task.logs.join('\n');
    if (text.isEmpty) return;
    await copyRawLogsToClipboard(context, text);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Raw logs copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;

  const _StatusPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActivityEntryTile extends StatelessWidget {
  final _ActivityEntry entry;

  const _ActivityEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _toneColor(theme, entry.tone);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(54)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_toneIcon(entry), size: 16, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (entry.detail != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        entry.detail!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (entry.timestamp != null)
                Text(
                  entry.timestamp!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          if (entry.progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: entry.progress,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surface.withAlpha(140),
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _toneIcon(_ActivityEntry entry) {
    if (entry.isProgress) return Icons.timelapse_rounded;
    switch (entry.tone) {
      case _ActivityTone.info:
        return Icons.bolt_rounded;
      case _ActivityTone.success:
        return Icons.check_circle_outline_rounded;
      case _ActivityTone.warning:
        return Icons.pause_circle_outline_rounded;
      case _ActivityTone.error:
        return Icons.error_outline_rounded;
      case _ActivityTone.neutral:
        return Icons.subdirectory_arrow_right_rounded;
    }
  }

  Color _toneColor(ThemeData theme, _ActivityTone tone) {
    switch (tone) {
      case _ActivityTone.info:
        return theme.colorScheme.primary;
      case _ActivityTone.success:
        return const Color(0xFF7FF2B3);
      case _ActivityTone.warning:
        return theme.colorScheme.tertiary;
      case _ActivityTone.error:
        return theme.colorScheme.error;
      case _ActivityTone.neutral:
        return theme.colorScheme.onSurfaceVariant;
    }
  }
}

class _MissingTaskState extends StatelessWidget {
  const _MissingTaskState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'This task is no longer in the queue.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _NormalizedLogLine {
  final String message;
  final String? timestamp;

  const _NormalizedLogLine({
    required this.message,
    required this.timestamp,
  });
}

class _ActivityEntry {
  final String title;
  final String? detail;
  final String? timestamp;
  final _ActivityTone tone;
  final double? progress;
  final bool isProgress;

  const _ActivityEntry({
    required this.title,
    this.detail,
    this.timestamp,
    required this.tone,
    this.progress,
    this.isProgress = false,
  });

  _ActivityEntry copyWith({
    String? title,
    String? detail,
    String? timestamp,
    _ActivityTone? tone,
    double? progress,
    bool? isProgress,
  }) {
    return _ActivityEntry(
      title: title ?? this.title,
      detail: detail ?? this.detail,
      timestamp: timestamp ?? this.timestamp,
      tone: tone ?? this.tone,
      progress: progress ?? this.progress,
      isProgress: isProgress ?? this.isProgress,
    );
  }
}
