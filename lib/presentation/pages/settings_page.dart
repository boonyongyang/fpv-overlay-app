import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io';

import 'package:fpv_overlay_app/core/utils/platform_utils.dart';
import 'package:fpv_overlay_app/application/providers/settings_provider.dart';
import 'package:fpv_overlay_app/infrastructure/services/picker_service.dart';
import 'package:fpv_overlay_app/core/utils/path_resolver.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final pickerService = context.read<PickerService>();
    final theme = Theme.of(context);

    if (settingsProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Info',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  'Environment configuration and quick maintenance.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 48),

          // 2. Preferences Section (New)
          _Section(
            title: 'Application Preferences',
            icon: Icons.tune_rounded,
            children: [
              _SettingTile(
                title: 'Default Output Directory',
                subtitle: settingsProvider.config.defaultOutputDirectory ??
                    'No default path set (will ask every time)',
                action: OutlinedButton.icon(
                  onPressed: () async {
                    final dir = await pickerService.pickDirectory(
                      initialDirectory:
                          settingsProvider.config.defaultOutputDirectory,
                    );
                    if (dir != null) {
                      settingsProvider.updateConfig(
                          defaultOutputDirectory: dir);
                    }
                  },
                  icon: const Icon(Icons.folder_open_rounded, size: 16),
                  label: Text(
                      settingsProvider.config.defaultOutputDirectory == null
                          ? 'Set Default'
                          : 'Change'),
                ),
                onClear: settingsProvider.config.defaultOutputDirectory != null
                    ? () => settingsProvider.updateConfig(
                        defaultOutputDirectory: null)
                    : null,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // 3. Quick Actions Section (New)
          _Section(
            title: 'Quick Actions',
            icon: Icons.bolt_rounded,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _QuickActionCard(
                    icon: Icons.folder_shared_rounded,
                    label: 'Open Output',
                    onTap: () {
                      final path =
                          settingsProvider.config.defaultOutputDirectory ??
                              settingsProvider.config.lastUsedOutputDirectory;
                      if (path != null) {
                        PlatformUtils.openDirectory(path);
                      }
                    },
                  ),
                  _QuickActionCard(
                    icon: Icons.content_copy_rounded,
                    label: 'Copy Report',
                    onTap: () {
                      final report = '''
FPV Overlay Toolbox System Report
---------------------------------
FFmpeg: ${PathResolver.ffmpegPath}
Python: ${PathResolver.pythonPath}
Overlay Tool: ${PathResolver.o3OverlayToolPath}
OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}
''';
                      Clipboard.setData(ClipboardData(text: report));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('System report copied to clipboard'),
                          behavior: SnackBarBehavior.floating,
                          width: 300,
                        ),
                      );
                    },
                  ),
                  _QuickActionCard(
                    icon: Icons.refresh_rounded,
                    label: 'Reset App',
                    isDestructive: true,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Reset Settings?'),
                          content: const Text(
                              'This will clear all saved paths and preferences. The app will restart with defaults.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                settingsProvider.resetConfig();
                                Navigator.pop(context);
                              },
                              child: const Text('Reset',
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 32),

          // 4. Core Engine Section
          _Section(
            title: 'Core Engine (Auto-Configured)',
            icon: Icons.settings_applications_rounded,
            children: [
              _DependencyStatus(
                title: 'FFmpeg Binary',
                description: 'Required for SRT overlays and video encoding.',
                resolvedPath: PathResolver.ffmpegPath,
                isBundled: PathResolver.ffmpegPath != 'ffmpeg',
              ),
              _DependencyStatus(
                title: 'Python 3 Interpreter',
                description: 'Used to run the OSD rendering scripts.',
                resolvedPath: PathResolver.pythonPath,
                isBundled: PathResolver.pythonPath != 'python3',
              ),
              _DependencyStatus(
                title: 'O3_OverlayTool Source',
                description: 'The Python scripts for rendering gauges.',
                resolvedPath: PathResolver.o3OverlayToolPath ?? 'Not Found',
                isBundled: PathResolver.o3OverlayToolPath != null,
                isError: PathResolver.o3OverlayToolPath == null,
              ),
            ],
          ),
          const SizedBox(height: 64),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _Section(
      {required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget action;
  final VoidCallback? onClear;

  const _SettingTile({
    required this.title,
    required this.subtitle,
    required this.action,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: theme.colorScheme.outlineVariant.withAlpha(50)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFamily: subtitle.contains('/') ? 'SF Mono' : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (onClear != null)
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.clear_rounded, size: 18),
              tooltip: 'Clear default path',
            ),
          action,
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: isDestructive
          ? theme.colorScheme.errorContainer.withAlpha(50)
          : theme.colorScheme.primaryContainer.withAlpha(30),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDestructive
                  ? theme.colorScheme.error.withAlpha(50)
                  : theme.colorScheme.primary.withAlpha(50),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 18,
                  color: isDestructive
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDestructive
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DependencyStatus extends StatelessWidget {
  final String title;
  final String description;
  final String resolvedPath;
  final bool isBundled;
  final bool isError;

  const _DependencyStatus({
    required this.title,
    required this.description,
    required this.resolvedPath,
    required this.isBundled,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow.withAlpha(150),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (isBundled && !isError)
                  const _Badge(label: 'BUNDLED', color: Colors.green)
                else if (isError)
                  const _Badge(label: 'MISSING', color: Colors.red)
                else
                  const _Badge(label: 'SYSTEM', color: Colors.orange),
              ],
            ),
            const SizedBox(height: 4),
            Text(description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
            const SizedBox(height: 12),
            Text(
              resolvedPath,
              style: TextStyle(
                fontFamily: 'SF Mono',
                fontSize: 10,
                color:
                    isError ? Colors.red : theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
