import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:fpv_overlay_app/application/providers/navigation_provider.dart';
import 'package:fpv_overlay_app/domain/models/task_addition_result.dart';

/// Shows a [SnackBar] summarising the outcome of a task-addition operation.
void showAddResultSnackBar(BuildContext context, TaskAdditionResult result) {
  final colorScheme = Theme.of(context).colorScheme;
  final bool isError = result.addedCount == 0 && result.partialCount == 0;

  final String message;
  if (result.addedCount > 0 || result.partialCount > 0) {
    final parts = <String>[
      if (result.addedCount > 0)
        '${result.addedCount} task${result.addedCount > 1 ? 's' : ''}',
      if (result.partialCount > 0)
        '${result.partialCount} partial item${result.partialCount > 1 ? 's' : ''}',
    ];
    final suffix = result.duplicateCount > 0
        ? ' (${result.duplicateCount} skipped as duplicates)'
        : '';
    message = 'Added ${parts.join(' and ')}$suffix';
  } else if (result.duplicateCount > 0) {
    message = 'All ${result.duplicateCount} items skipped as duplicates';
  } else {
    message = 'No valid video-telemetry pairs found';
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: TextStyle(
          color: isError ? colorScheme.onError : colorScheme.onPrimaryContainer,
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
