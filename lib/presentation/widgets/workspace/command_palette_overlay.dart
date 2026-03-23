import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:fpv_overlay_app/application/providers/task_queue_provider.dart';
import 'package:fpv_overlay_app/application/providers/workspace_provider.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';
import 'package:fpv_overlay_app/presentation/utils/workspace_actions.dart';

class CommandPaletteOverlay extends StatefulWidget {
  const CommandPaletteOverlay({super.key});

  @override
  State<CommandPaletteOverlay> createState() => _CommandPaletteOverlayState();
}

class _CommandPaletteOverlayState extends State<CommandPaletteOverlay> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _queryController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _queryController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workspace = context.read<WorkspaceProvider>();
    final tasks = context.watch<TaskQueueProvider>().tasks;
    final selectedTask = _findSelectedTask(
      tasks,
      context.watch<WorkspaceProvider>().selectedTaskId,
    );
    final entries = _buildEntries(context, tasks, selectedTask)
        .where(_matchesQuery)
        .toList(growable: false);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          workspace.closeCommandPalette();
        },
        const SingleActivator(
          LogicalKeyboardKey.keyK,
          meta: true,
        ): workspace.toggleCommandPalette,
        const SingleActivator(
          LogicalKeyboardKey.keyK,
          control: true,
        ): workspace.toggleCommandPalette,
      },
      child: Material(
        color: Colors.black.withAlpha(150),
        child: InkWell(
          onTap: workspace.closeCommandPalette,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth < 1100 || constraints.maxHeight < 720;
              final maxHeight =
                  (constraints.maxHeight * (compact ? 0.78 : 0.82))
                      .clamp(360.0, compact ? 540.0 : 620.0)
                      .toDouble();

              return Center(
                child: InkWell(
                  onTap: () {},
                  borderRadius: BorderRadius.circular(compact ? 24 : 28),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: compact ? 680 : 760,
                      maxHeight: maxHeight,
                    ),
                    margin: EdgeInsets.all(compact ? 16 : 24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(compact ? 24 : 28),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withAlpha(60),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(80),
                          blurRadius: 48,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            compact ? 14 : 20,
                            compact ? 14 : 20,
                            compact ? 14 : 20,
                            compact ? 10 : 12,
                          ),
                          child: LayoutBuilder(
                            builder: (context, headerConstraints) {
                              final stackedHeader =
                                  headerConstraints.maxWidth < 520;
                              final searchField = TextField(
                                controller: _queryController,
                                focusNode: _focusNode,
                                autofocus: true,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(
                                    Icons.keyboard_command_key_rounded,
                                  ),
                                  hintText: 'Search commands and navigation',
                                  isDense: compact,
                                  filled: true,
                                  fillColor:
                                      theme.colorScheme.surfaceContainerLow,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              );

                              if (stackedHeader) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    searchField,
                                    const SizedBox(height: 10),
                                    _ShortcutBadge(
                                      label:
                                          Platform.isMacOS ? 'Cmd K' : 'Ctrl K',
                                      compact: true,
                                    ),
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: searchField),
                                  const SizedBox(width: 12),
                                  _ShortcutBadge(
                                    label:
                                        Platform.isMacOS ? 'Cmd K' : 'Ctrl K',
                                    compact: compact,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: entries.isEmpty
                              ? Center(
                                  child: Text(
                                    'No matching commands',
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding: EdgeInsets.all(compact ? 10 : 12),
                                  itemBuilder: (context, index) {
                                    final entry = entries[index];
                                    return _CommandEntryTile(
                                      compact: compact,
                                      entry: entry,
                                      onTap: () async {
                                        workspace.closeCommandPalette();
                                        await entry.onSelected();
                                      },
                                    );
                                  },
                                  separatorBuilder: (_, __) =>
                                      SizedBox(height: compact ? 6 : 8),
                                  itemCount: entries.length,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  bool _matchesQuery(_CommandEntry entry) {
    final normalizedQuery = _queryController.text.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;
    return entry.title.toLowerCase().contains(normalizedQuery) ||
        entry.description.toLowerCase().contains(normalizedQuery) ||
        entry.shortcut.toLowerCase().contains(normalizedQuery);
  }

  List<_CommandEntry> _buildEntries(
    BuildContext context,
    List<OverlayTask> tasks,
    OverlayTask? selectedTask,
  ) {
    final queue = context.read<TaskQueueProvider>();
    final hasReadyTasks = tasks.any(
      (task) =>
          task.status == TaskStatus.pending || task.status == TaskStatus.failed,
    );
    final isProcessing = queue.isProcessing;

    return [
      _CommandEntry(
        icon: Icons.add_photo_alternate_rounded,
        title: 'Add files',
        description: 'Choose video and telemetry files to add to the queue.',
        shortcut: 'A',
        onSelected: () => addFilesToQueue(context),
      ),
      _CommandEntry(
        icon: Icons.folder_copy_rounded,
        title: 'Scan folder',
        description: 'Import a directory and let the matcher build tasks.',
        shortcut: 'F',
        onSelected: () => addFolderToQueue(context),
      ),
      _CommandEntry(
        icon: Icons.rocket_launch_rounded,
        title: 'Start queue',
        description: 'Begin rendering all ready tasks in the queue.',
        shortcut: 'Enter',
        enabled: !isProcessing && hasReadyTasks,
        onSelected: () => startQueueFromWorkspace(context),
      ),
      _CommandEntry(
        icon: Icons.stop_circle_rounded,
        title: 'Cancel queue',
        description: 'Request cancellation for the active render.',
        shortcut: 'Esc',
        enabled: isProcessing,
        onSelected: () async {
          queue.cancelQueue();
        },
      ),
      _CommandEntry(
        icon: Icons.delete_sweep_rounded,
        title: 'Clear completed',
        description: 'Remove completed and cancelled items from the queue.',
        shortcut: 'Shift C',
        enabled: tasks.any(
          (task) =>
              task.status == TaskStatus.completed ||
              task.status == TaskStatus.cancelled,
        ),
        onSelected: () async {
          queue.clearCompleted();
        },
      ),
      _CommandEntry(
        icon: Icons.layers_clear_rounded,
        title: 'Clear queue',
        description: 'Remove all non-processing items from the queue.',
        shortcut: 'Shift X',
        enabled: tasks.isNotEmpty,
        onSelected: () async {
          queue.clearAll();
        },
      ),
      _CommandEntry(
        icon: Icons.settings_rounded,
        title: 'Open settings',
        description: 'Jump to runtime configuration and local stats.',
        shortcut: ',',
        onSelected: () async {
          openSettings(context);
        },
      ),
      _CommandEntry(
        icon: Icons.help_outline_rounded,
        title: 'Open help',
        description: 'Open support, usage notes, and project links.',
        shortcut: '?',
        onSelected: () async {
          openHelp(context);
        },
      ),
      _CommandEntry(
        icon: Icons.school_rounded,
        title: 'Open workflow tour',
        description: 'Review the onboarding tour and product workflow.',
        shortcut: 'T',
        onSelected: () => openTutorial(context),
      ),
      _CommandEntry(
        icon: Icons.content_copy_rounded,
        title: 'Copy diagnostics',
        description:
            'Copy environment details, queue summary, and the current task log context.',
        shortcut: 'D',
        onSelected: () => copyDiagnosticsToClipboard(
          context,
          selectedTask: selectedTask,
        ),
      ),
      _CommandEntry(
        icon: Icons.folder_open_rounded,
        title: 'Open output directory',
        description: 'Reveal the current default or last-used output folder.',
        shortcut: 'O',
        onSelected: () => openOutputDirectory(context),
      ),
    ];
  }

  OverlayTask? _findSelectedTask(
      List<OverlayTask> tasks, String? selectedTaskId,) {
    if (selectedTaskId == null) return null;
    for (final task in tasks) {
      if (task.id == selectedTaskId) return task;
    }
    return null;
  }
}

class _CommandEntryTile extends StatelessWidget {
  final bool compact;
  final _CommandEntry entry;
  final VoidCallback onTap;

  const _CommandEntryTile({
    required this.compact,
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: entry.enabled ? 1 : 0.45,
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: entry.enabled ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(compact ? 10 : 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withAlpha(180),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(entry.icon, color: theme.colorScheme.primary),
                ),
                SizedBox(width: compact ? 12 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: compact ? 2 : 4),
                      Text(
                        entry.description,
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: compact ? 10 : 12),
                _ShortcutBadge(label: entry.shortcut, compact: compact),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutBadge extends StatelessWidget {
  final String label;
  final bool compact;

  const _ShortcutBadge({
    required this.label,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: compact ? 11 : null,
        ),
      ),
    );
  }
}

class _CommandEntry {
  final IconData icon;
  final String title;
  final String description;
  final String shortcut;
  final bool enabled;
  final Future<void> Function() onSelected;

  const _CommandEntry({
    required this.icon,
    required this.title,
    required this.description,
    required this.shortcut,
    required this.onSelected,
    this.enabled = true,
  });
}
