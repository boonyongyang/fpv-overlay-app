import 'dart:io';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:local_notifier/local_notifier.dart';

import 'package:fpv_overlay_app/application/providers/navigation_provider.dart';
import 'package:fpv_overlay_app/application/providers/settings_provider.dart';
import 'package:fpv_overlay_app/application/providers/task_queue_provider.dart';
import 'package:fpv_overlay_app/infrastructure/services/command_runner_service.dart';
import 'package:fpv_overlay_app/infrastructure/services/engine_service.dart';
import 'package:fpv_overlay_app/infrastructure/services/picker_service.dart';
import 'package:fpv_overlay_app/infrastructure/services/storage_service.dart';
import 'package:fpv_overlay_app/presentation/pages/settings_page.dart';
import 'package:fpv_overlay_app/presentation/pages/task_queue_page.dart';
import 'package:fpv_overlay_app/presentation/pages/help_page.dart';
import 'package:fpv_overlay_app/domain/services/os_service.dart';
import 'package:fpv_overlay_app/infrastructure/services/macos_os_service.dart';
import 'package:fpv_overlay_app/infrastructure/services/windows_os_service.dart';
import 'package:fpv_overlay_app/infrastructure/services/placeholder_os_service.dart';
import 'package:fpv_overlay_app/presentation/widgets/fpv_logo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await localNotifier.setup(
    appName: 'FPV Overlay Toolbox',
    shortcutPolicy: ShortcutPolicy.requireCreate,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>(create: (_) => StorageService()),
        Provider<PickerService>(create: (_) => PickerService()),
        Provider<EngineService>(create: (_) => EngineService()),
        Provider<CommandRunnerService>(create: (_) => CommandRunnerService()),
        Provider<OsService>(create: (_) {
          if (Platform.isMacOS) return MacOSOsService();
          if (Platform.isWindows) return WindowsOsService();
          return PlaceholderOsService();
        }),
        ChangeNotifierProxyProvider<StorageService, SettingsProvider>(
          create: (context) => SettingsProvider(
            storageService: context.read<StorageService>(),
          ),
          update: (_, storage, previous) =>
              previous ?? SettingsProvider(storageService: storage),
        ),
        ChangeNotifierProxyProvider3<EngineService, CommandRunnerService,
            OsService, TaskQueueProvider>(
          create: (context) => TaskQueueProvider(
            engineService: context.read<EngineService>(),
            commandRunnerService: context.read<CommandRunnerService>(),
            osService: context.read<OsService>(),
          ),
          update: (_, engine, runner, os, previous) =>
              previous ??
              TaskQueueProvider(
                engineService: engine,
                commandRunnerService: runner,
                osService: os,
              ),
        ),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ],
      child: const FpvOverlayApp(),
    ),
  );
}

class FpvOverlayApp extends StatelessWidget {
  const FpvOverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FPV Overlay',
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: Colors.blueAccent,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blueAccent,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navProvider = context.watch<NavigationProvider>();
    final selectedIndex = navProvider.currentIndex;
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 800;

    return Scaffold(
      appBar: isMobile
          ? AppBar(
              title: Row(
                children: [
                  const FpvLogo(size: 24, color: Colors.cyanAccent),
                  const SizedBox(width: 10),
                  Text(
                    'FPV Overlay',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              backgroundColor: theme.colorScheme.surface,
              elevation: 0,
              centerTitle: false,
            )
          : null,
      bottomNavigationBar: isMobile
          ? BottomNavigationBar(
              currentIndex: selectedIndex,
              onTap: (index) => navProvider.setTab(index),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.movie_filter_rounded),
                  label: 'Queue',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.info_outline_rounded),
                  label: 'System',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.help_outline),
                  label: 'Help',
                ),
              ],
              selectedItemColor: theme.colorScheme.primary,
              unselectedItemColor: theme.colorScheme.onSurfaceVariant,
              backgroundColor: theme.colorScheme.surface,
              type: BottomNavigationBarType.fixed,
            )
          : null,
      body: Row(
        children: [
          // Sidebar (only on desktop)
          if (!isMobile)
            Container(
              width: 260,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                border: Border(
                  right: BorderSide(
                    color: theme.colorScheme.outlineVariant.withAlpha(50),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48), // Spacing for window controls
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const FpvLogo(size: 32, color: Colors.cyanAccent),
                            const SizedBox(width: 12),
                            Text(
                              'FPV Overlay',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Toolbox v1.0.0',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withAlpha(150),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SidebarItem(
                    icon: Icons.movie_filter_rounded,
                    label: 'Overlay Queue',
                    isSelected: selectedIndex == 0,
                    onTap: () => navProvider.setTab(0),
                  ),
                  _SidebarItem(
                    icon: Icons.info_outline_rounded,
                    label: 'System Info',
                    isSelected: selectedIndex == 1,
                    onTap: () => navProvider.setTab(1),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Material(
                      color: selectedIndex == 2
                          ? theme.colorScheme.primaryContainer.withAlpha(150)
                          : theme.colorScheme.surfaceContainerHighest
                              .withAlpha(100),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => navProvider.setTab(2),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.help_outline,
                                size: 16,
                                color: selectedIndex == 2
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Need help?',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: selectedIndex == 2
                                      ? theme.colorScheme.onPrimaryContainer
                                      : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: selectedIndex == 2
                                      ? FontWeight.bold
                                      : FontWeight.normal,
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
            ),
          // Main Content Area
          Expanded(
            child: Container(
              color: theme.colorScheme.surface,
              child: IndexedStack(
                index: selectedIndex,
                children: const [
                  TaskQueuePage(),
                  SettingsPage(),
                  HelpPage(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withAlpha(150)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
