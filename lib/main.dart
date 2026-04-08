import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';
import 'package:local_notifier/local_notifier.dart';

import 'package:fpv_overlay_app/application/providers/local_stats_provider.dart';
import 'package:fpv_overlay_app/application/providers/navigation_provider.dart';
import 'package:fpv_overlay_app/application/providers/settings_provider.dart';
import 'package:fpv_overlay_app/application/providers/workspace_provider.dart';
import 'package:fpv_overlay_app/core/constants/app_identity.dart';
import 'package:fpv_overlay_app/application/providers/task_queue_provider.dart';
import 'package:fpv_overlay_app/domain/models/app_configuration.dart';
import 'package:fpv_overlay_app/infrastructure/services/command_runner_service.dart';
import 'package:fpv_overlay_app/infrastructure/services/engine_service.dart';
import 'package:fpv_overlay_app/infrastructure/services/local_stats_service.dart';
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
import 'package:fpv_overlay_app/presentation/widgets/navigation/app_sidebar.dart';
import 'package:fpv_overlay_app/presentation/widgets/workspace/command_palette_overlay.dart';
import 'package:fpv_overlay_app/presentation/widgets/workspace/onboarding_overlay.dart';
import 'package:fpv_overlay_app/application/providers/update_provider.dart';
import 'package:fpv_overlay_app/domain/services/update_service.dart';
import 'package:fpv_overlay_app/infrastructure/services/http_update_service.dart';
import 'package:fpv_overlay_app/presentation/widgets/update_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await localNotifier.setup(
    appName: AppIdentity.name,
    shortcutPolicy: ShortcutPolicy.requireCreate,
  );

  runApp(
    const _AppProviders(
      child: FpvOverlayApp(),
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
        Provider<LocalStatsService>(create: (_) => LocalStatsService()),
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
        ChangeNotifierProvider(
          create: (context) => LocalStatsProvider(
            localStatsService: context.read<LocalStatsService>(),
          )..load(),
        ),
        ChangeNotifierProxyProvider5<
            StorageService,
            EngineService,
            CommandRunnerService,
            OsService,
            LocalStatsProvider,
            TaskQueueProvider>(
          create: (context) => TaskQueueProvider(
            storageService: context.read<StorageService>(),
            engineService: context.read<EngineService>(),
            commandRunnerService: context.read<CommandRunnerService>(),
            osService: context.read<OsService>(),
            localStatsProvider: context.read<LocalStatsProvider>(),
          ),
          update: (_, storage, engine, runner, os, localStats, previous) =>
              previous ??
              TaskQueueProvider(
                storageService: storage,
                engineService: engine,
                commandRunnerService: runner,
                osService: os,
                localStatsProvider: localStats,
              ),
        ),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => WorkspaceProvider()),
        Provider<UpdateService>(create: (_) => HttpUpdateService()),
        ChangeNotifierProvider(
          create: (context) => UpdateProvider(
            updateService: context.read<UpdateService>(),
          ),
        ),
      ],
      child: child,
    );
  }
}

class FpvOverlayApp extends StatelessWidget {
  const FpvOverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppIdentity.name,
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
  AppConfiguration? _lastSyncedConfiguration;
  bool _sidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navProvider = context.watch<NavigationProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final workspace = context.watch<WorkspaceProvider>();
    final selectedIndex = navProvider.currentIndex;
    final mediaWidth = MediaQuery.of(context).size.width;
    final isTouchPlatform = Platform.isAndroid || Platform.isIOS;
    final isMobile = isTouchPlatform && mediaWidth < 960;
    final forceCollapsedSidebar = mediaWidth < 980;
    final isSidebarCollapsed =
        !isMobile && (forceCollapsedSidebar || _sidebarCollapsed);
    final sidebarWidth = isSidebarCollapsed
        ? 84.0
        : mediaWidth < 1080
            ? 216.0
            : 260.0;

    if (!settingsProvider.isLoading &&
        _lastSyncedConfiguration != settingsProvider.config) {
      _lastSyncedConfiguration = settingsProvider.config;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context
            .read<WorkspaceProvider>()
            .syncFromConfiguration(settingsProvider.config);
      });
    }

    final scaffold = Scaffold(
      appBar: isMobile ? _buildMobileAppBar(context, theme) : null,
      bottomNavigationBar:
          isMobile ? _buildBottomNav(theme, selectedIndex, navProvider) : null,
      body: Row(
        children: [
          if (!isMobile)
            AppSidebar(
              width: sidebarWidth,
              compact: !isSidebarCollapsed && sidebarWidth < 240,
              collapsed: isSidebarCollapsed,
              selectedIndex: selectedIndex,
              onTabSelected: navProvider.setTab,
              onToggleCollapsed: forceCollapsedSidebar
                  ? null
                  : () =>
                      setState(() => _sidebarCollapsed = !_sidebarCollapsed),
            ),
          Expanded(
            child: Column(
              children: [
                const UpdateBanner(),
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
          ),
        ],
      ),
    );

    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: AppIdentity.name,
          menus: [
            if (PlatformProvidedMenuItem.hasMenu(
              PlatformProvidedMenuItemType.about,
            ))
              const PlatformProvidedMenuItem(
                type: PlatformProvidedMenuItemType.about,
              ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Preferences...',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.comma,
                    meta: true,
                  ),
                  onSelected: () => navProvider.setTab(1),
                ),
                PlatformMenuItem(
                  label: 'Command Palette',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyK,
                    meta: true,
                  ),
                  onSelected: () => workspace.toggleCommandPalette(),
                ),
              ],
            ),
            if (PlatformProvidedMenuItem.hasMenu(
              PlatformProvidedMenuItemType.servicesSubmenu,
            ))
              const PlatformProvidedMenuItem(
                type: PlatformProvidedMenuItemType.servicesSubmenu,
              ),
            PlatformMenuItemGroup(
              members: [
                if (PlatformProvidedMenuItem.hasMenu(
                  PlatformProvidedMenuItemType.hide,
                ))
                  const PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.hide,
                  ),
                if (PlatformProvidedMenuItem.hasMenu(
                  PlatformProvidedMenuItemType.hideOtherApplications,
                ))
                  const PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.hideOtherApplications,
                  ),
                if (PlatformProvidedMenuItem.hasMenu(
                  PlatformProvidedMenuItemType.showAllApplications,
                ))
                  const PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.showAllApplications,
                  ),
              ],
            ),
            if (PlatformProvidedMenuItem.hasMenu(
              PlatformProvidedMenuItemType.quit,
            ))
              const PlatformProvidedMenuItem(
                type: PlatformProvidedMenuItemType.quit,
              ),
          ],
        ),
        PlatformMenu(
          label: 'Window',
          menus: [
            if (PlatformProvidedMenuItem.hasMenu(
              PlatformProvidedMenuItemType.minimizeWindow,
            ))
              const PlatformProvidedMenuItem(
                type: PlatformProvidedMenuItemType.minimizeWindow,
              ),
            if (PlatformProvidedMenuItem.hasMenu(
              PlatformProvidedMenuItemType.zoomWindow,
            ))
              const PlatformProvidedMenuItem(
                type: PlatformProvidedMenuItemType.zoomWindow,
              ),
            if (PlatformProvidedMenuItem.hasMenu(
              PlatformProvidedMenuItemType.toggleFullScreen,
            ))
              const PlatformProvidedMenuItem(
                type: PlatformProvidedMenuItemType.toggleFullScreen,
              ),
            PlatformMenuItemGroup(
              members: [
                if (PlatformProvidedMenuItem.hasMenu(
                  PlatformProvidedMenuItemType.arrangeWindowsInFront,
                ))
                  const PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.arrangeWindowsInFront,
                  ),
              ],
            ),
          ],
        ),
        PlatformMenu(
          label: 'Help',
          menus: [
            PlatformMenuItem(
              label: '${AppIdentity.name} Help',
              onSelected: () => navProvider.setTab(2),
            ),
          ],
        ),
      ],
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(
            LogicalKeyboardKey.keyK,
            meta: true,
          ): workspace.toggleCommandPalette,
          const SingleActivator(
            LogicalKeyboardKey.keyK,
            control: true,
          ): workspace.toggleCommandPalette,
        },
        child: Stack(
          children: [
            scaffold,
            if (workspace.isCommandPaletteOpen) const CommandPaletteOverlay(),
            if (workspace.isOnboardingVisible) const OnboardingOverlay(),
          ],
        ),
      ),
    );
  }

  AppBar _buildMobileAppBar(BuildContext context, ThemeData theme) {
    return AppBar(
      title: Row(
        children: [
          const FpvLogo(size: 24, color: Colors.cyanAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppIdentity.name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
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
          label: 'Stats',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.help_outline_rounded),
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
