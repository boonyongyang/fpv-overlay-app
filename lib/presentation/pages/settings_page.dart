import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:fpv_overlay_app/application/providers/local_stats_provider.dart';
import 'package:fpv_overlay_app/application/providers/settings_provider.dart';
import 'package:fpv_overlay_app/application/providers/task_queue_provider.dart';
import 'package:fpv_overlay_app/core/utils/platform_utils.dart';
import 'package:fpv_overlay_app/domain/models/app_configuration.dart';
import 'package:fpv_overlay_app/domain/models/local_overlay_stats.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';
import 'package:fpv_overlay_app/infrastructure/services/picker_service.dart';
import 'package:fpv_overlay_app/presentation/utils/workspace_actions.dart';
import 'package:fpv_overlay_app/presentation/widgets/workspace/environment_summary_card.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final statsProvider = context.watch<LocalStatsProvider>();
    final queueProvider = context.watch<TaskQueueProvider>();
    final pickerService = context.read<PickerService>();
    final theme = Theme.of(context);

    if (settingsProvider.isLoading || statsProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stats & Settings',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  'Local overlay history, runtime diagnostics, and app preferences.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          _Section(
            title: 'Local Overlay Stats',
            icon: Icons.insights_rounded,
            children: [
              _StatsSummaryGrid(snapshot: statsProvider.snapshot),
              const SizedBox(height: 16),
              _StatsDetailsRow(snapshot: statsProvider.snapshot),
              const SizedBox(height: 16),
              _RecentRunsCard(snapshot: statsProvider.snapshot),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmClearStats(context, statsProvider),
                  icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                  label: const Text('Clear Local Stats'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _Section(
            title: 'Settings & Diagnostics',
            icon: Icons.tune_rounded,
            children: [
              EnvironmentSummaryCard(
                config: settingsProvider.config,
                onCopyReport: () => copyDiagnosticsToClipboard(context),
              ),
              const SizedBox(height: 16),
              _SettingTile(
                title: 'Default Output Directory',
                subtitle: settingsProvider.config.defaultOutputDirectory ??
                    'No default path set (the app will ask each time)',
                action: OutlinedButton.icon(
                  onPressed: () async {
                    final dir = await pickerService.pickDirectory(
                      initialDirectory:
                          settingsProvider.config.defaultOutputDirectory,
                    );
                    if (dir != null) {
                      unawaited(
                        settingsProvider.updateConfig(
                          defaultOutputDirectory: dir,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.folder_open_rounded, size: 16),
                  label: Text(
                    settingsProvider.config.defaultOutputDirectory == null
                        ? 'Set Default'
                        : 'Change',
                  ),
                ),
                onClear: settingsProvider.config.defaultOutputDirectory != null
                    ? () => settingsProvider.updateConfig(
                          defaultOutputDirectory: null,
                        )
                    : null,
              ),
              const SizedBox(height: 16),
              _SettingTile(
                title: 'O3_OverlayTool Directory (Optional)',
                subtitle: settingsProvider.config.o3OverlayToolPath ??
                    'Not set - bundled fonts are used by default',
                action: OutlinedButton.icon(
                  onPressed: () async {
                    final dir = await pickerService.pickDirectory(
                      initialDirectory:
                          settingsProvider.config.o3OverlayToolPath,
                    );
                    if (dir != null) {
                      unawaited(
                        settingsProvider.updateConfig(
                          o3OverlayToolPath: dir,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.folder_open_rounded, size: 16),
                  label: Text(
                    settingsProvider.config.o3OverlayToolPath == null
                        ? 'Browse'
                        : 'Change',
                  ),
                ),
                onClear: settingsProvider.config.o3OverlayToolPath != null
                    ? () =>
                        settingsProvider.updateConfig(o3OverlayToolPath: null)
                    : null,
              ),
              const SizedBox(height: 20),
              _RecentDirectoriesCard(config: settingsProvider.config),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _QuickActionCard(
                    icon: Icons.folder_shared_rounded,
                    label: 'Open Output',
                    onTap: () {
                      final path =
                          settingsProvider.config.defaultOutputDirectory ??
                              settingsProvider.config.lastUsedOutputDirectory;
                      if (path != null) {
                        PlatformUtils.openDirectory(path);
                      }
                    },
                  ),
                  _QuickActionCard(
                    icon: Icons.content_copy_rounded,
                    label: 'Copy Report',
                    onTap: () => copyDiagnosticsToClipboard(context),
                  ),
                  _QuickActionCard(
                    icon: Icons.keyboard_command_key_rounded,
                    label: 'Command Palette',
                    onTap: () => openCommandPalette(context),
                  ),
                  _QuickActionCard(
                    icon: Icons.refresh_rounded,
                    label: 'Reset Settings',
                    isDestructive: true,
                    onTap: () => _confirmResetSettings(
                      context,
                      settingsProvider,
                    ),
                  ),
                ],
              ),
              if (queueProvider.tasks.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Current queue context',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${queueProvider.tasks.length} tasks are currently loaded in this session. Use the command palette or queue filters to jump between them quickly.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 64),
        ],
      ),
    );
  }

  Future<void> _confirmClearStats(
    BuildContext context,
    LocalStatsProvider statsProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Local Stats?'),
        content: const Text(
          'This removes the saved overlay history and lifetime counters from this device only.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await statsProvider.clearStats();
    }
  }

  Future<void> _confirmResetSettings(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings?'),
        content: const Text(
          'This clears saved paths and app preferences. Local overlay stats are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Reset',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await settingsProvider.resetConfig();
    }
  }
}

class _RecentDirectoriesCard extends StatelessWidget {
  final AppConfiguration config;

  const _RecentDirectoriesCard({required this.config});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasInputs = config.recentInputDirectories.isNotEmpty;
    final hasOutputs = config.recentOutputDirectories.isNotEmpty;

    if (!hasInputs && !hasOutputs) {
      return const SizedBox.shrink();
    }

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent workspace folders',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (hasInputs) ...[
            Text(
              'Recent input folders',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: config.recentInputDirectories.map((path) {
                return ActionChip(
                  avatar: const Icon(Icons.folder_copy_rounded, size: 16),
                  label: SizedBox(
                    width: 220,
                    child: Text(
                      path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  onPressed: () => openDirectory(path),
                );
              }).toList(growable: false),
            ),
          ],
          if (hasOutputs) ...[
            const SizedBox(height: 16),
            Text(
              'Recent output folders',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: config.recentOutputDirectories.map((path) {
                return ActionChip(
                  avatar: const Icon(Icons.output_rounded, size: 16),
                  label: SizedBox(
                    width: 220,
                    child: Text(
                      path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  onPressed: () => openDirectory(path),
                );
              }).toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  void openDirectory(String path) {
    unawaited(PlatformUtils.openDirectory(path));
  }
}

class _StatsSummaryGrid extends StatelessWidget {
  const _StatsSummaryGrid({required this.snapshot});

  final OverlayStatsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _StatCard(
          label: 'Total Runs',
          value: snapshot.totalRuns.toString(),
          icon: Icons.video_collection_rounded,
        ),
        _StatCard(
          label: 'Completed',
          value: snapshot.totalCompletedRuns.toString(),
          icon: Icons.check_circle_outline_rounded,
          accent: const Color(0xFF63D471),
        ),
        _StatCard(
          label: 'Failed',
          value: snapshot.totalFailedRuns.toString(),
          icon: Icons.error_outline_rounded,
          accent: const Color(0xFFFF6B6B),
        ),
        _StatCard(
          label: 'Cancelled',
          value: snapshot.totalCancelledRuns.toString(),
          icon: Icons.cancel_outlined,
          accent: const Color(0xFFFFD166),
        ),
        _StatCard(
          label: 'Total Render Time',
          value: _formatDuration(snapshot.totalRenderTime),
          icon: Icons.timer_outlined,
        ),
        _StatCard(
          label: 'Average Time',
          value: _formatDuration(snapshot.averageRenderTime),
          icon: Icons.speed_rounded,
        ),
      ],
    );
  }
}

class _StatsDetailsRow extends StatelessWidget {
  const _StatsDetailsRow({required this.snapshot});

  final OverlayStatsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 920;

        if (stacked) {
          return Column(
            children: [
              _OverlayBreakdownCard(snapshot: snapshot),
              const SizedBox(height: 16),
              _StatsMetaCard(snapshot: snapshot),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _OverlayBreakdownCard(snapshot: snapshot)),
            const SizedBox(width: 16),
            Expanded(child: _StatsMetaCard(snapshot: snapshot)),
          ],
        );
      },
    );
  }
}

class _OverlayBreakdownCard extends StatelessWidget {
  const _OverlayBreakdownCard({required this.snapshot});

  final OverlayStatsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overlay Type Breakdown',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _MetricLine(label: 'SRT Fast', value: snapshot.totalSrtRuns),
          const SizedBox(height: 12),
          _MetricLine(label: 'OSD HD', value: snapshot.totalOsdRuns),
          const SizedBox(height: 12),
          _MetricLine(label: 'OSD + SRT', value: snapshot.totalCombinedRuns),
        ],
      ),
    );
  }
}

class _StatsMetaCard extends StatelessWidget {
  const _StatsMetaCard({required this.snapshot});

  final OverlayStatsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity Summary',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _MetaRow(
            label: 'Last completed',
            value: snapshot.lastCompletedAt == null
                ? 'No completed overlays yet'
                : _formatTimestamp(snapshot.lastCompletedAt!),
          ),
          const SizedBox(height: 12),
          _MetaRow(
            label: 'Success ratio',
            value: snapshot.totalRuns == 0
                ? '0%'
                : '${((snapshot.totalCompletedRuns / snapshot.totalRuns) * 100).round()}%',
          ),
          const SizedBox(height: 12),
          const _MetaRow(
            label: 'Saved locally',
            value: 'This device only',
          ),
        ],
      ),
    );
  }
}

class _RecentRunsCard extends StatelessWidget {
  const _RecentRunsCard({required this.snapshot});

  final OverlayStatsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Runs',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (snapshot.recentRuns.isEmpty)
            Text(
              'No overlays have been recorded on this device yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Column(
              children: snapshot.recentRuns.take(8).map((run) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RecentRunTile(run: run),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _RecentRunTile extends StatelessWidget {
  const _RecentRunTile({required this.run});

  final RecentOverlayRun run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = switch (run.status) {
      TaskStatus.completed => const Color(0xFF63D471),
      TaskStatus.failed => theme.colorScheme.error,
      TaskStatus.cancelled => const Color(0xFFFFD166),
      _ => theme.colorScheme.onSurfaceVariant,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(50),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  run.sourceName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ChipLabel(label: _overlayTypeLabel(run.overlayType)),
                    _ChipLabel(label: _statusLabel(run.status)),
                    _ChipLabel(label: _formatTimestamp(run.timestamp)),
                    if (run.renderDuration != null)
                      _ChipLabel(label: _formatDuration(run.renderDuration!)),
                  ],
                ),
                if (run.failureSummary != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    run.failureSummary!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(50),
        ),
      ),
      child: child,
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ?? theme.colorScheme.primary;
    return SizedBox(
      width: 180,
      child: _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 14),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value.toString(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withAlpha(60),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.title,
    required this.subtitle,
    required this.action,
    this.onClear,
  });

  final String title;
  final String subtitle;
  final Widget action;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(50),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFamily: subtitle.contains('/') ? 'SF Mono' : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (onClear != null)
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.clear_rounded, size: 18),
              tooltip: 'Clear saved path',
            ),
          action,
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: isDestructive
          ? theme.colorScheme.errorContainer.withAlpha(50)
          : theme.colorScheme.primaryContainer.withAlpha(30),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDestructive
                  ? theme.colorScheme.error.withAlpha(50)
                  : theme.colorScheme.primary.withAlpha(50),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isDestructive
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDestructive
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  if (duration == Duration.zero) return '0s';
  if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }
  if (duration.inMinutes > 0) {
    return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
  }
  return '${duration.inSeconds}s';
}

String _formatTimestamp(DateTime dateTime) {
  final local = dateTime.toLocal();
  final date =
      '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return '$date $time';
}

String _overlayTypeLabel(OverlayType type) {
  switch (type) {
    case OverlayType.srt:
      return 'SRT Fast';
    case OverlayType.osd:
      return 'OSD HD';
    case OverlayType.combined:
      return 'OSD + SRT';
    case OverlayType.unknown:
      return 'Unknown';
  }
}

String _statusLabel(TaskStatus status) {
  switch (status) {
    case TaskStatus.completed:
      return 'Completed';
    case TaskStatus.failed:
      return 'Failed';
    case TaskStatus.cancelled:
      return 'Cancelled';
    case TaskStatus.pending:
      return 'Pending';
    case TaskStatus.processing:
      return 'Processing';
    case TaskStatus.missingTelemetry:
      return 'Missing Telemetry';
    case TaskStatus.missingVideo:
      return 'Missing Video';
  }
}
