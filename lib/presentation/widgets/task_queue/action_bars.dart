import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fpv_overlay_app/application/providers/settings_provider.dart';
import 'package:fpv_overlay_app/application/providers/task_queue_provider.dart';
import 'package:fpv_overlay_app/core/utils/platform_utils.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';
import 'package:fpv_overlay_app/infrastructure/services/picker_service.dart';
import 'package:fpv_overlay_app/presentation/utils/workspace_actions.dart';

class HeaderActions extends StatelessWidget {
  final bool compact;
  final TaskQueueProvider queueProvider;
  final VoidCallback onOpenCommandPalette;

  const HeaderActions({
    super.key,
    this.compact = false,
    required this.queueProvider,
    required this.onOpenCommandPalette,
  });

  @override
  Widget build(BuildContext context) {
    final bool isProcessing = queueProvider.isProcessing;
    final buttonPadding = EdgeInsets.symmetric(
      horizontal: compact ? 16 : 20,
      vertical: compact ? 15 : 18,
    );

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          onPressed: isProcessing ? null : () => addFilesToQueue(context),
          icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
          label: const Text('Add Files'),
          style: FilledButton.styleFrom(
            padding: buttonPadding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        ActionButton(
          compact: compact,
          onPressed: isProcessing ? null : () => addFolderToQueue(context),
          icon: Icons.folder_copy_rounded,
          label: 'Scan Folder',
          isPrimary: false,
        ),
        ActionButton(
          compact: compact,
          onPressed: onOpenCommandPalette,
          icon: Icons.keyboard_command_key_rounded,
          label: compact ? 'Palette' : 'Command Palette',
          isPrimary: false,
        ),
      ],
    );
  }
}

class BottomActionBar extends StatelessWidget {
  final bool compact;
  final TaskQueueProvider queueProvider;
  final SettingsProvider settingsProvider;
  final PickerService pickerService;

  const BottomActionBar({
    super.key,
    this.compact = false,
    required this.queueProvider,
    required this.settingsProvider,
    required this.pickerService,
  });

  @override
  Widget build(BuildContext context) {
    final isProcessing = queueProvider.isProcessing;
    final isCancelling = queueProvider.isCancelling;
    final willClearAfterCancel = queueProvider.willClearAfterCancel;
    final theme = Theme.of(context);
    final int total = queueProvider.tasks.length;
    final int completed = queueProvider.tasks
        .where((t) => t.status == TaskStatus.completed)
        .length;
    final int readyToStart = queueProvider.tasks
        .where(
          (t) =>
              t.status == TaskStatus.pending || t.status == TaskStatus.failed,
        )
        .length;
    final int needsFix = queueProvider.tasks
        .where(
          (t) =>
              t.status == TaskStatus.missingTelemetry ||
              t.status == TaskStatus.missingVideo,
        )
        .length;
    final bool isComplete = completed == total && total > 0;
    final int processingIndex = queueProvider.tasks
        .indexWhere((t) => t.status == TaskStatus.processing);
    String? activeTaskId;
    OverlayTask? activeTask;
    for (final task in queueProvider.tasks) {
      if (task.status == TaskStatus.processing) {
        activeTaskId = task.id;
        activeTask = task;
        break;
      }
    }

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
    } else if (isCancelling) {
      mainLabel = 'Cancelling...';
      subLabel = 'Waiting for current task to stop';
      buttonText = 'Cancelling...';
      canAction = false;
    } else if (isProcessing) {
      mainLabel = activeTask?.videoFileName ?? 'Engine Processing...';
      final phase = activeTask?.progressPhase ?? 'Rendering overlay';
      subLabel = '$phase · task ${processingIndex + 1} of $total';
      buttonText = 'Rendering ${processingIndex + 1}/$total';
      canAction = false;
    } else if (isComplete) {
      mainLabel = 'Queue Complete';
      subLabel = 'All $total videos processed successfully';
      buttonText = 'Open Results';
      buttonIcon = Icons.folder_open_rounded;
      canAction = true;
    } else if (readyToStart > 0) {
      mainLabel = '$readyToStart overlay${readyToStart == 1 ? '' : 's'} ready';
      subLabel = needsFix > 0
          ? '$needsFix item${needsFix == 1 ? '' : 's'} still need links.'
          : 'Everything currently in view is ready to render.';
      buttonText = 'Start $readyToStart Overlays';
      canAction = true;
    } else {
      mainLabel = 'Waiting for Links';
      subLabel = 'Add missing metadata to enable rendering';
      buttonText = 'Start Overlays';
      canAction = false;
    }

    Future<void> handlePrimaryAction() async {
      if (isComplete) {
        final outputDir = settingsProvider.config.defaultOutputDirectory ??
            settingsProvider.config.lastUsedOutputDirectory;
        if (outputDir != null) {
          unawaited(PlatformUtils.openDirectory(outputDir));
        }
        return;
      }

      String? outputDir = settingsProvider.config.defaultOutputDirectory;

      outputDir ??= await pickerService.pickDirectory(
        initialDirectory: settingsProvider.config.lastUsedOutputDirectory,
      );

      if (outputDir != null) {
        unawaited(settingsProvider.addRecentOutputDirectory(outputDir));
        unawaited(queueProvider.startQueue(settingsProvider.config, outputDir));
      }
    }

    final buttons = Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.end,
      children: [
        if (activeTaskId != null)
          OutlinedButton.icon(
            onPressed: () => openTaskLogs(context, activeTaskId!),
            icon: const Icon(Icons.terminal_rounded, size: 18),
            label: Text(compact ? 'Activity' : 'View Activity'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        if (isProcessing)
          OutlinedButton.icon(
            onPressed: isCancelling ? null : () => queueProvider.cancelQueue(),
            icon: Icon(
              isCancelling
                  ? Icons.hourglass_empty_rounded
                  : Icons.stop_circle_rounded,
              size: 18,
            ),
            label: Text(isCancelling ? 'Cancelling...' : 'Cancel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: isCancelling
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.error,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        if (total > 0)
          OutlinedButton.icon(
            onPressed: isCancelling && willClearAfterCancel
                ? null
                : () => queueProvider.cancelAndClearAll(),
            icon: const Icon(Icons.delete_sweep_rounded),
            label: Text(
              isProcessing
                  ? (willClearAfterCancel
                      ? 'Clearing after cancel...'
                      : 'Cancel & Clear')
                  : 'Clear All',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        FilledButton.icon(
          onPressed: canAction ? () => handlePrimaryAction() : null,
          icon: isProcessing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Icon(buttonIcon),
          label: Text(buttonText),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: isProcessing
                ? theme.colorScheme.primary.withAlpha(150)
                : theme.colorScheme.primary,
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = compact || constraints.maxWidth < 980;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withAlpha(245),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withAlpha(80),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(60),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mainLabel,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        subLabel,
                        key: ValueKey(subLabel),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(width: double.infinity, child: buttons),
                  ],
                )
              : Row(
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
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Flexible(child: buttons),
                  ],
                ),
        );
      },
    );
  }
}

class ActionButton extends StatelessWidget {
  final bool compact;
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final bool isPrimary;

  const ActionButton({
    super.key,
    this.compact = false,
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
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 20,
            vertical: compact ? 15 : 18,
          ),
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
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 20,
          vertical: compact ? 15 : 18,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
