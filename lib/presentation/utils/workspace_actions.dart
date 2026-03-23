import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:fpv_overlay_app/application/providers/navigation_provider.dart';
import 'package:fpv_overlay_app/application/providers/settings_provider.dart';
import 'package:fpv_overlay_app/application/providers/task_queue_provider.dart';
import 'package:fpv_overlay_app/application/providers/workspace_provider.dart';
import 'package:fpv_overlay_app/core/utils/diagnostics_report_builder.dart';
import 'package:fpv_overlay_app/core/utils/platform_utils.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';
import 'package:fpv_overlay_app/infrastructure/services/picker_service.dart';
import 'package:fpv_overlay_app/presentation/pages/task_logs_page.dart';
import 'package:fpv_overlay_app/presentation/pages/tutorial_page.dart';
import 'package:fpv_overlay_app/presentation/widgets/task_queue/snack_bar_helpers.dart';

Future<void> addFilesToQueue(BuildContext context) async {
  final picker = context.read<PickerService>();
  final settings = context.read<SettingsProvider>();
  final queue = context.read<TaskQueueProvider>();

  final files = await picker.pickFiles(
    initialDirectory: settings.config.lastUsedInputDirectory,
    allowMultiple: true,
    extensions: ['mp4', 'mov', 'srt', 'osd'],
    label: 'Media and telemetry files',
  );
  if (files.isEmpty) return;

  final parentDirectory = _parentDirectory(files.first);
  if (parentDirectory != null) {
    unawaited(settings.addRecentInputDirectory(parentDirectory));
  }

  final result = await queue.addTasksFromFiles(files);
  if (!context.mounted) return;
  showAddResultSnackBar(context, result);
}

Future<void> addFolderToQueue(
  BuildContext context, {
  String? presetPath,
}) async {
  final picker = context.read<PickerService>();
  final settings = context.read<SettingsProvider>();
  final queue = context.read<TaskQueueProvider>();

  final directory = presetPath ??
      await picker.pickDirectory(
        initialDirectory: settings.config.lastUsedInputDirectory,
      );
  if (directory == null || directory.isEmpty) return;

  unawaited(settings.addRecentInputDirectory(directory));
  final result = await queue.addTasksFromDirectory(directory);
  if (!context.mounted) return;
  showAddResultSnackBar(context, result);
}

Future<void> startQueueFromWorkspace(BuildContext context) async {
  final settings = context.read<SettingsProvider>();
  final picker = context.read<PickerService>();
  final queue = context.read<TaskQueueProvider>();

  String? outputDirectory = settings.config.defaultOutputDirectory;
  outputDirectory ??= await picker.pickDirectory(
    initialDirectory: settings.config.lastUsedOutputDirectory,
  );
  if (outputDirectory == null || outputDirectory.isEmpty) return;

  unawaited(settings.addRecentOutputDirectory(outputDirectory));
  unawaited(queue.startQueue(settings.config, outputDirectory));
}

Future<void> copyDiagnosticsToClipboard(
  BuildContext context, {
  OverlayTask? selectedTask,
}) async {
  final settings = context.read<SettingsProvider>();
  final queue = context.read<TaskQueueProvider>();
  final report = buildDiagnosticsReport(
    config: settings.config,
    tasks: queue.tasks,
    selectedTask: selectedTask,
  );
  await Clipboard.setData(ClipboardData(text: report));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Diagnostics report copied to clipboard'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

Future<void> openOutputDirectory(BuildContext context, {String? path}) async {
  final settings = context.read<SettingsProvider>();
  final target = path ??
      settings.config.defaultOutputDirectory ??
      settings.config.lastUsedOutputDirectory;
  if (target == null || target.isEmpty) return;
  await PlatformUtils.openDirectory(target);
}

Future<void> openTutorial(BuildContext context) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const TutorialPage(),
      fullscreenDialog: true,
    ),
  );
}

Future<void> openTaskLogs(BuildContext context, String taskId) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TaskLogsPage(taskId: taskId),
    ),
  );
}

Future<void> copyRawLogsToClipboard(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
}

void openSettings(BuildContext context) {
  context.read<NavigationProvider>().setTab(1);
}

void openHelp(BuildContext context) {
  context.read<NavigationProvider>().setTab(2);
}

void openQueue(BuildContext context) {
  context.read<NavigationProvider>().setTab(0);
}

void openCommandPalette(BuildContext context) {
  context.read<WorkspaceProvider>().openCommandPalette();
}

String? _parentDirectory(String path) {
  final lastSeparator = path.lastIndexOf(RegExp(r'[\\/]'));
  if (lastSeparator <= 0) return null;
  return path.substring(0, lastSeparator);
}
