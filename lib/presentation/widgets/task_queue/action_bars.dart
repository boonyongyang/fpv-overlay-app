import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:fpv_overlay_app/application/providers/settings_provider.dart';
import 'package:fpv_overlay_app/application/providers/task_queue_provider.dart';
import 'package:fpv_overlay_app/core/utils/platform_utils.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';
import 'package:fpv_overlay_app/domain/services/telemetry.dart';
import 'package:fpv_overlay_app/infrastructure/services/picker_service.dart';
import 'package:fpv_overlay_app/presentation/widgets/task_queue/snack_bar_helpers.dart';

class HeaderActions extends StatelessWidget {
  final TaskQueueProvider queueProvider;
  final SettingsProvider settingsProvider;
  final PickerService pickerService;

  const HeaderActions({
    super.key,
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
        ActionButton(
          onPressed: isProcessing
              ? null
              : () async {
                  Telemetry.tappedButton('select_pairs');
                  final files = await pickerService.pickFiles(
                    initialDirectory:
                        settingsProvider.config.lastUsedInputDirectory,
                    allowMultiple: true,
                    extensions: ['mp4', 'mov', 'srt', 'osd'],
                    label: 'Video & Telemetry Files',
                  );
                  if (files.isNotEmpty) {
                    final dir = Directory(files.first).parent.path;
                    unawaited(
                      settingsProvider.updateConfig(
                        lastUsedInputDirectory: dir,
                      ),
                    );
                    final result = await queueProvider.addTasksFromFiles(files);
                    if (context.mounted) {
                      showAddResultSnackBar(context, result);
                    }
                  }
                },
          icon: Icons.add_photo_alternate_rounded,
          label: 'Select Pairs',
          isPrimary: true,
        ),
        const SizedBox(width: 12),
        ActionButton(
          onPressed: isProcessing
              ? null
              : () async {
                  Telemetry.tappedButton('scan_folder');
                  final dir = await pickerService.pickDirectory(
                    initialDirectory:
                        settingsProvider.config.lastUsedInputDirectory,
                  );
                  if (dir != null) {
                    unawaited(
                      settingsProvider.updateConfig(
                        lastUsedInputDirectory: dir,
                      ),
                    );
                    final result =
                        await queueProvider.addTasksFromDirectory(dir);
                    if (context.mounted) {
                      Telemetry.folderScanned(
                        videosFound: result.addedCount + result.partialCount,
                        matchesMade: result.addedCount,
                        orphanCount: result.partialCount,
                      );
                      showAddResultSnackBar(context, result);
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
}

class BottomActionBar extends StatelessWidget {
  final TaskQueueProvider queueProvider;
  final SettingsProvider settingsProvider;
  final PickerService pickerService;

  const BottomActionBar({
    super.key,
    required this.queueProvider,
    required this.settingsProvider,
    required this.pickerService,
  });

  @override
  Widget build(BuildContext context) {
    final isProcessing = queueProvider.isProcessing;
    final isCancelling = queueProvider.isCancelling;
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
    } else if (isCancelling) {
      mainLabel = 'Cancelling...';
      subLabel = 'Waiting for current task to stop';
      buttonText = 'Cancelling...';
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
          if (isProcessing) ...[
            OutlinedButton.icon(
              onPressed:
                  isCancelling ? null : () => queueProvider.cancelQueue(),
              icon: Icon(
                isCancelling
                    ? Icons.hourglass_empty_rounded
                    : Icons.stop_circle_outlined,
                size: 18,
              ),
              label: Text(isCancelling ? 'Cancelling...' : 'Cancel'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isCancelling
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.error,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          if (isComplete) ...[
            OutlinedButton.icon(
              onPressed: () => queueProvider.clearAll(),
              icon: const Icon(Icons.delete_sweep_rounded),
              label: const Text('Clear Queue'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          FilledButton.icon(
            onPressed: !canAction
                ? null
                : () async {
                    if (isComplete) {
                      Telemetry.tappedButton('open_results');
                      final outputDir =
                          settingsProvider.config.defaultOutputDirectory ??
                              settingsProvider.config.lastUsedOutputDirectory;
                      if (outputDir != null) {
                        unawaited(PlatformUtils.openDirectory(outputDir));
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
                      Telemetry.tappedButton('start_queue');
                      unawaited(
                        settingsProvider.updateConfig(
                          lastUsedOutputDirectory: outputDir,
                        ),
                      );
                      unawaited(
                        queueProvider.startQueue(
                          settingsProvider.config,
                          outputDir,
                        ),
                      );
                    }
                  },
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
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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

class ActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final bool isPrimary;

  const ActionButton({
    super.key,
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
