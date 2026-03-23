import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fpv_overlay_app/application/providers/local_stats_provider.dart';
import 'package:fpv_overlay_app/application/providers/settings_provider.dart';
import 'package:fpv_overlay_app/application/providers/task_queue_provider.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';
import 'package:fpv_overlay_app/domain/services/os_service.dart';
import 'package:fpv_overlay_app/infrastructure/services/command_runner_service.dart';
import 'package:fpv_overlay_app/infrastructure/services/engine_service.dart';
import 'package:fpv_overlay_app/infrastructure/services/local_stats_service.dart';
import 'package:fpv_overlay_app/infrastructure/services/picker_service.dart';
import 'package:fpv_overlay_app/infrastructure/services/storage_service.dart';
import 'package:fpv_overlay_app/presentation/pages/settings_page.dart';

class _MockEngineService extends Mock implements EngineService {}

class _MockCommandRunnerService extends Mock implements CommandRunnerService {}

class _MockOsService extends Mock implements OsService {}

void main() {
  late SettingsProvider settingsProvider;
  late LocalStatsProvider statsProvider;
  late TaskQueueProvider queueProvider;

  OverlayTask buildCompletedTask() {
    final task = OverlayTask(
      id: 'DJIG0025',
      videoPath: '/data/DJIG0025.mp4',
      osdPath: '/data/DJIG0024.osd',
      srtPath: '/data/DJIG0025.srt',
      status: TaskStatus.completed,
    );
    task.startTime = DateTime.parse('2026-03-08T10:00:00Z');
    task.endTime = DateTime.parse('2026-03-08T10:01:00Z');
    task.outputPath = '/out/DJIG0025_overlay.mp4';
    return task;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settingsProvider = SettingsProvider(storageService: StorageService());
    statsProvider = LocalStatsProvider(localStatsService: LocalStatsService());
    final mockOs = _MockOsService();
    when(() => mockOs.updateBadge(any())).thenReturn(null);
    when(() => mockOs.updateDockProgress(any())).thenReturn(null);
    when(() => mockOs.resetDockProgress()).thenReturn(null);
    queueProvider = TaskQueueProvider(
      engineService: _MockEngineService(),
      commandRunnerService: _MockCommandRunnerService(),
      osService: mockOs,
      localStatsProvider: statsProvider,
    );
    await settingsProvider.updateConfig(defaultOutputDirectory: '/out');
    await statsProvider.load();
    await statsProvider.recordRun(buildCompletedTask());
  });

  Widget buildPage() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<LocalStatsProvider>.value(value: statsProvider),
        ChangeNotifierProvider<TaskQueueProvider>.value(value: queueProvider),
        Provider<PickerService>(create: (_) => PickerService()),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SettingsPage()),
      ),
    );
  }

  testWidgets('renders stats summary and settings sections', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(find.text('Stats & Settings'), findsOneWidget);
    expect(find.text('Local Overlay Stats'), findsOneWidget);
    expect(find.text('Recent Runs'), findsOneWidget);
    expect(find.text('Settings & Diagnostics'), findsOneWidget);
    expect(find.text('DJIG0025.mp4'), findsOneWidget);
  });

  testWidgets('clear local stats confirmation resets the history',
      (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Clear Local Stats'));
    await tester.tap(find.text('Clear Local Stats'));
    await tester.pumpAndSettle();

    expect(find.text('Clear Local Stats?'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(
      find.text('No overlays have been recorded on this device yet.'),
      findsOneWidget,
    );
  });
}
