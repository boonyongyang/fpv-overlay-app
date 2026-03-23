import 'package:flutter/material.dart';

import 'package:fpv_overlay_app/application/providers/task_queue_provider.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';

class DashboardStatsRow extends StatelessWidget {
  final TaskQueueProvider queueProvider;
  const DashboardStatsRow({super.key, required this.queueProvider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final int total = queueProvider.tasks.length;
    final int completed = queueProvider.tasks
        .where((t) => t.status == TaskStatus.completed)
        .length;
    final int failed =
        queueProvider.tasks.where((t) => t.status == TaskStatus.failed).length;
    final int cancelled = queueProvider.tasks
        .where((t) => t.status == TaskStatus.cancelled)
        .length;
    final int pending = total - completed - failed - cancelled;

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
            color: theme.colorScheme.primary,
          ),
          const _StatDivider(),
          _StatItem(
            label: 'Pending',
            value: pending.toString(),
            color: theme.colorScheme.onSurface,
          ),
          const _StatDivider(),
          _StatItem(
            label: 'Done',
            value: completed.toString(),
            color: Colors.greenAccent,
          ),
          const _StatDivider(),
          _StatItem(
            label: 'Failed',
            value: failed.toString(),
            color: Colors.redAccent,
          ),
          if (cancelled > 0) ...[
            const _StatDivider(),
            _StatItem(
              label: 'Cancelled',
              value: cancelled.toString(),
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
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

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
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
