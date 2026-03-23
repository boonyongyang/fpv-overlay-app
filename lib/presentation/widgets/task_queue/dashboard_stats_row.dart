import 'package:flutter/material.dart';

import 'package:fpv_overlay_app/application/providers/task_queue_provider.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';

class DashboardStatsRow extends StatelessWidget {
  final TaskQueueProvider queueProvider;
  const DashboardStatsRow({super.key, required this.queueProvider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasks = queueProvider.tasks;
    final int total = tasks.length;
    final int ready = tasks.where((t) => t.status == TaskStatus.pending).length;
    final int processing =
        tasks.where((t) => t.status == TaskStatus.processing).length;
    final int needsFix = tasks
        .where(
          (t) =>
              t.status == TaskStatus.missingTelemetry ||
              t.status == TaskStatus.missingVideo,
        )
        .length;
    final int completed =
        tasks.where((t) => t.status == TaskStatus.completed).length;
    final int failed = tasks.where((t) => t.status == TaskStatus.failed).length;
    final int cancelled =
        tasks.where((t) => t.status == TaskStatus.cancelled).length;
    final headline = _headline(
      total: total,
      ready: ready,
      processing: processing,
      needsFix: needsFix,
      completed: completed,
    );
    final detail = _detail(
      total: total,
      ready: ready,
      processing: processing,
      needsFix: needsFix,
      failed: failed,
    );

    final statItems = <Widget>[
      _StatItem(
        label: 'Total',
        value: total.toString(),
        color: theme.colorScheme.primary,
        icon: Icons.layers_rounded,
      ),
      _StatItem(
        label: 'Ready',
        value: ready.toString(),
        color: const Color(0xFF91E8C8),
        icon: Icons.rocket_launch_rounded,
      ),
      _StatItem(
        label: 'Live',
        value: processing.toString(),
        color: theme.colorScheme.primary,
        icon: Icons.sync_rounded,
      ),
      _StatItem(
        label: 'Needs Fix',
        value: needsFix.toString(),
        color: theme.colorScheme.tertiary,
        icon: Icons.link_off_rounded,
      ),
      _StatItem(
        label: 'Done',
        value: completed.toString(),
        color: Colors.greenAccent,
        icon: Icons.check_circle_outline_rounded,
      ),
      _StatItem(
        label: 'Failed',
        value: failed.toString(),
        color: Colors.redAccent,
        icon: Icons.error_outline_rounded,
      ),
      if (cancelled > 0)
        _StatItem(
          label: 'Cancelled',
          value: cancelled.toString(),
          color: theme.colorScheme.onSurfaceVariant,
          icon: Icons.stop_circle_outlined,
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(56),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: theme.colorScheme.outlineVariant.withAlpha(50)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 860;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha(24),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      processing > 0
                          ? Icons.motion_photos_on_rounded
                          : Icons.dashboard_customize_rounded,
                      color: theme.colorScheme.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headline,
                          style: theme.textTheme.titleSmall?.copyWith(
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
                ],
              ),
              const SizedBox(height: 16),
              if (compact)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: statItems,
                )
              else
                Row(
                  children: [
                    for (var index = 0; index < statItems.length; index++) ...[
                      if (index > 0) const _StatDivider(),
                      statItems[index],
                    ],
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  String _headline({
    required int total,
    required int ready,
    required int processing,
    required int needsFix,
    required int completed,
  }) {
    if (processing > 0) return 'Batch render is running';
    if (ready > 0) return '$ready overlays are ready to start';
    if (needsFix > 0) return 'Queue needs a few file links';
    if (completed == total && total > 0) {
      return 'Everything in this batch is done';
    }
    return 'Queue overview';
  }

  String _detail({
    required int total,
    required int ready,
    required int processing,
    required int needsFix,
    required int failed,
  }) {
    if (processing > 0) {
      final blockedNote = needsFix > 0 ? ' $needsFix still need links.' : '';
      return '$processing live right now, $ready ready next.$blockedNote';
    }
    if (ready > 0) {
      if (needsFix > 0) {
        return '$needsFix items are still blocked, but the batch can already begin.';
      }
      return 'Everything currently in the queue is linked and ready for render.';
    }
    if (needsFix > 0) {
      return 'Link the missing video or telemetry files to make the batch actionable.';
    }
    if (failed > 0) {
      return 'Review failed items, then retry them once the issue is fixed.';
    }
    if (total == 0) {
      return 'Import a folder or drop files here to start building a batch.';
    }
    return 'Use the status tabs below to review this batch.';
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withAlpha(160),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color.withAlpha(220)),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

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
