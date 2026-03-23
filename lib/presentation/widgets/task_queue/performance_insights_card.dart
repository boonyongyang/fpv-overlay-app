import 'package:flutter/material.dart';

import 'package:fpv_overlay_app/application/providers/task_queue_provider.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';

class PerformanceInsightsCard extends StatelessWidget {
  final TaskQueueProvider queueProvider;
  const PerformanceInsightsCard({super.key, required this.queueProvider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completed = queueProvider.tasks
        .where((t) => t.status == TaskStatus.completed)
        .toList();

    if (completed.isEmpty) return const SizedBox.shrink();

    final durations =
        completed.where((t) => t.duration != null).map((t) => t.duration!);
    final avgRenderTime = durations.isEmpty
        ? Duration.zero
        : Duration(
            milliseconds: durations
                    .map((d) => d.inMilliseconds)
                    .reduce((a, b) => a + b) ~/
                durations.length,
          );
    final totalTimeSaved = Duration(
      milliseconds:
          durations.map((d) => d.inMilliseconds).fold(0, (a, b) => a + b),
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withAlpha(60),
            theme.colorScheme.tertiaryContainer.withAlpha(40),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withAlpha(40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.insights_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Performance Insights',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final metrics = [
                _ReportMetric(
                  label: 'Avg Render Time',
                  value: '${avgRenderTime.inSeconds}s',
                  icon: Icons.speed_rounded,
                ),
                _ReportMetric(
                  label: 'Total Time',
                  value: _formatDuration(totalTimeSaved),
                  icon: Icons.timer_rounded,
                ),
                _ReportMetric(
                  label: 'CPU Load',
                  value: completed.last.cpuUsageAtStart != null
                      ? '${completed.last.cpuUsageAtStart!.toStringAsFixed(0)}%'
                      : 'N/A',
                  icon: Icons.memory_rounded,
                ),
              ];

              if (constraints.maxWidth < 720) {
                return Column(
                  children: [
                    for (var index = 0; index < metrics.length; index++) ...[
                      if (index > 0) const SizedBox(height: 12),
                      metrics[index],
                    ],
                  ],
                );
              }

              return Row(
                children: metrics
                    .map((metric) => Expanded(child: metric))
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    return '${d.inSeconds}s';
  }
}

class _ReportMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ReportMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withAlpha(145),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
