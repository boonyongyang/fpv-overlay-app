import 'dart:io';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:local_notifier/local_notifier.dart';

import 'package:fpv_overlay_app/application/providers/firebase_provider.dart';
import 'package:fpv_overlay_app/application/providers/navigation_provider.dart';
import 'package:fpv_overlay_app/application/providers/settings_provider.dart';
import 'package:fpv_overlay_app/application/providers/task_queue_provider.dart';
import 'package:fpv_overlay_app/infrastructure/services/command_runner_service.dart';
import 'package:fpv_overlay_app/infrastructure/services/engine_service.dart';
import 'package:fpv_overlay_app/domain/services/telemetry.dart';
import 'package:fpv_overlay_app/infrastructure/services/firebase/firebase_initializer.dart';
import 'package:fpv_overlay_app/infrastructure/services/picker_service.dart';
import 'package:fpv_overlay_app/infrastructure/services/storage_service.dart';
import 'package:fpv_overlay_app/presentation/navigation/firebase_route_observer.dart';
import 'package:fpv_overlay_app/presentation/pages/settings_page.dart';
import 'package:fpv_overlay_app/presentation/pages/task_queue_page.dart';
import 'package:fpv_overlay_app/presentation/pages/help_page.dart';
import 'package:fpv_overlay_app/domain/services/os_service.dart';
import 'package:fpv_overlay_app/infrastructure/services/macos_os_service.dart';
import 'package:fpv_overlay_app/infrastructure/services/windows_os_service.dart';
import 'package:fpv_overlay_app/infrastructure/services/placeholder_os_service.dart';
import 'package:fpv_overlay_app/presentation/widgets/fpv_logo.dart';
import 'package:fpv_overlay_app/presentation/widgets/navigation/app_sidebar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FirebaseInitializer.init();

  Telemetry.appLaunched(appVersion: '1.0.0');

  await localNotifier.setup(
    appName: 'FPV Overlay Toolbox',
    shortcutPolicy: ShortcutPolicy.requireCreate,
  );

  runApp(
    const FirebaseProvider(
      child: _AppProviders(
        child: FpvOverlayApp(),
      ),
    ),
  );
}

/// Houses the [MultiProvider] tree so [main] stays readable.
class _AppProviders extends StatelessWidget {
  const _AppProviders({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<StorageService>(create: (_) => StorageService()),
        Provider<PickerService>(create: (_) => PickerService()),
        Provider<EngineService>(create: (_) => EngineService()),
        Provider<CommandRunnerService>(create: (_) => CommandRunnerService()),
        Provider<OsService>(
          create: (_) {
            if (Platform.isMacOS) return MacOSOsService();
            if (Platform.isWindows) return WindowsOsService();
            return PlaceholderOsService();
          },
        ),
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
      child: child,
    );
  }
}

class FpvOverlayApp extends StatelessWidget {
  const FpvOverlayApp({super.key});

  // Keep the observer alive for the lifetime of the app.
  static final _routeObserver = FirebaseRouteObserver();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FPV Overlay',
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: Colors.cyan,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.cyan,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      navigatorObservers: [FpvOverlayApp._routeObserver],
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navProvider = context.watch<NavigationProvider>();
    final selectedIndex = navProvider.currentIndex;
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      appBar: isMobile ? _buildMobileAppBar(context, theme) : null,
      bottomNavigationBar:
          isMobile ? _buildBottomNav(theme, selectedIndex, navProvider) : null,
      body: Row(
        children: [
          if (!isMobile)
            AppSidebar(
              selectedIndex: selectedIndex,
              onTabSelected: navProvider.setTab,
            ),
          Expanded(
            child: ColoredBox(
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

  AppBar _buildMobileAppBar(BuildContext context, ThemeData theme) {
    return AppBar(
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
    );
  }

  BottomNavigationBar _buildBottomNav(
    ThemeData theme,
    int selectedIndex,
    NavigationProvider navProvider,
  ) {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      onTap: navProvider.setTab,
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
    );
  }
}
