import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:fpv_overlay_app/application/providers/settings_provider.dart';
import 'package:fpv_overlay_app/core/utils/path_resolver.dart';
import 'package:fpv_overlay_app/core/utils/platform_utils.dart';
import 'package:fpv_overlay_app/domain/services/telemetry.dart';
import 'package:fpv_overlay_app/infrastructure/services/picker_service.dart';

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
                      unawaited(
                        settingsProvider.updateConfig(
                          defaultOutputDirectory: dir,
                        ),
                      );
                      Telemetry.changedSetting('default_output_dir', dir);
                    }
                  },
                  icon: const Icon(Icons.folder_open_rounded, size: 16),
                  label: Text(
                    settingsProvider.config.defaultOutputDirectory == null
                        ? 'Set Default'
                        : 'Change',
                  ),
                ),
                onClear: settingsProvider.config.defaultOutputDirectory != null
                    ? () => settingsProvider.updateConfig(
                          defaultOutputDirectory: null,
                        )
                    : null,
              ),
              _SettingTile(
                title: 'O3_OverlayTool Directory (Optional)',
                subtitle: settingsProvider.config.o3OverlayToolPath ??
                    'Not set – fonts are bundled, no download needed',
                action: OutlinedButton.icon(
                  onPressed: () async {
                    final dir = await pickerService.pickDirectory(
                      initialDirectory:
                          settingsProvider.config.o3OverlayToolPath,
                    );
                    if (dir != null) {
                      unawaited(
                        settingsProvider.updateConfig(
                          o3OverlayToolPath: dir,
                        ),
                      );
                      Telemetry.changedSetting('o3_overlay_tool_path', dir);
                    }
                  },
                  icon: const Icon(Icons.folder_open_rounded, size: 16),
                  label: Text(
                    settingsProvider.config.o3OverlayToolPath == null
                        ? 'Browse'
                        : 'Change',
                  ),
                ),
                onClear: settingsProvider.config.o3OverlayToolPath != null
                    ? () =>
                        settingsProvider.updateConfig(o3OverlayToolPath: null)
                    : null,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // 3. Privacy Section – analytics opt-out
          _Section(
            title: 'Privacy',
            icon: Icons.privacy_tip_rounded,
            children: [
              _AnalyticsToggleTile(settingsProvider: settingsProvider),
            ],
          ),

          const SizedBox(height: 32),

          // 4. Quick Actions Section (New)
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
                      Telemetry.tappedButton('open_output_dir');
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
                      Telemetry.tappedButton('copy_system_report');
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
                            'This will clear all saved paths and preferences. The app will restart with defaults.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Telemetry.tappedButton('reset_app');
                                settingsProvider.resetConfig();
                                Navigator.pop(context);
                              },
                              child: const Text(
                                'Reset',
                                style: TextStyle(color: Colors.red),
                              ),
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

          const SizedBox(height: 64),
        ],
      ),
    );
  }
}

class _AnalyticsToggleTile extends StatelessWidget {
  final SettingsProvider settingsProvider;
  const _AnalyticsToggleTile({required this.settingsProvider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = settingsProvider.config.analyticsEnabled;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                const Text(
                  'Usage Analytics & Crash Reports',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Send anonymous crash reports and usage data to help improve the app.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: enabled,
            onChanged: (value) {
              settingsProvider.updateAnalyticsEnabled(value);
              Telemetry.changedSetting('analytics_enabled', value);
            },
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
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
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
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
              Icon(
                icon,
                size: 18,
                color: isDestructive
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
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
