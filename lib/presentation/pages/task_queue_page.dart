import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:fpv_overlay_app/application/providers/settings_provider.dart';
import 'package:fpv_overlay_app/application/providers/task_queue_provider.dart';
import 'package:fpv_overlay_app/domain/services/telemetry.dart';
import 'package:fpv_overlay_app/infrastructure/services/picker_service.dart';
import 'package:fpv_overlay_app/presentation/widgets/fpv_logo.dart';
import 'package:fpv_overlay_app/presentation/widgets/task_queue/action_bars.dart';
import 'package:fpv_overlay_app/presentation/widgets/task_queue/dashboard_stats_row.dart';
import 'package:fpv_overlay_app/presentation/widgets/task_queue/empty_state_view.dart';
import 'package:fpv_overlay_app/presentation/widgets/task_queue/performance_insights_card.dart';
import 'package:fpv_overlay_app/presentation/widgets/task_queue/snack_bar_helpers.dart';
import 'package:fpv_overlay_app/presentation/widgets/task_queue/task_card.dart';

class TaskQueuePage extends StatefulWidget {
  const TaskQueuePage({super.key});

  @override
  State<TaskQueuePage> createState() => _TaskQueuePageState();
}

class _TaskQueuePageState extends State<TaskQueuePage> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final queueProvider = context.watch<TaskQueueProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final pickerService = context.read<PickerService>();

    return DropTarget(
      onDragDone: (detail) async {
        final filePaths = detail.files.map((f) => f.path).toList();
        if (filePaths.isNotEmpty) {
          Telemetry.filesDropped(filePaths.length);
          final result = await queueProvider.addTasksFromFiles(filePaths);
          if (!context.mounted) return;
          showAddResultSnackBar(context, result);
        }
      },
      onDragEntered: (detail) => setState(() => _isDragging = true),
      onDragExited: (detail) => setState(() => _isDragging = false),
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Overlay Queue',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Drop files here or use the buttons to add media.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      HeaderActions(
                        queueProvider: queueProvider,
                        settingsProvider: settingsProvider,
                        pickerService: pickerService,
                      ),
                    ],
                  ),
                ),
              ),
              if (queueProvider.tasks.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        DashboardStatsRow(queueProvider: queueProvider),
                        PerformanceInsightsCard(queueProvider: queueProvider),
                      ],
                    ),
                  ),
                ),
              if (queueProvider.tasks.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyStateView(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(32, 16, 32, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final task = queueProvider.tasks[index];
                        return TaskCard(task: task);
                      },
                      childCount: queueProvider.tasks.length,
                    ),
                  ),
                ),
            ],
          ),
          if (queueProvider.tasks.isNotEmpty)
            Positioned(
              left: 32,
              right: 32,
              bottom: 32,
              child: BottomActionBar(
                queueProvider: queueProvider,
                settingsProvider: settingsProvider,
                pickerService: pickerService,
              ),
            ),
          if (_isDragging)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _isDragging ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withAlpha(200),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(30),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withAlpha(50),
                              width: 2,
                            ),
                          ),
                          child: const FpvLogo(
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Drop to Add to Queue',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
