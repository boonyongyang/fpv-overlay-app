import 'package:flutter/material.dart';
import 'package:fpv_overlay_app/core/constants/app_identity.dart';
import 'package:fpv_overlay_app/core/utils/platform_utils.dart';
import 'package:fpv_overlay_app/presentation/widgets/fpv_logo.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Colors.cyan.withAlpha(20),
                border: Border.all(color: Colors.cyan.withAlpha(50)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withAlpha(30),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const FpvLogo(
                size: 120,
                color: Colors.cyan,
              ),
            ),
          ),
          const SizedBox(height: 48),
          const SizedBox(height: 16),
          Text(
            'Support & Reference',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Practical guidance for matching files, using the desktop workspace efficiently, and troubleshooting local runtime issues.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 48),
          const _HelpSection(
            title: 'Getting Started',
            items: [
              _HelpCard(
                icon: Icons.add_photo_alternate_rounded,
                title: 'How do I add videos?',
                description:
                    'Drag and drop your video files directly onto the Overlay Queue, or use the "Add Task" button to explicitly choose SRT or OSD rendering.',
              ),
              _HelpCard(
                icon: Icons.description_rounded,
                title: 'What are Telemetry Files?',
                description:
                    'Data logs from your flight controller. We support .srt (DJI/Subtitles) and .osd (Betaflight/Inav) formats.',
              ),
              _HelpCard(
                icon: Icons.sync_rounded,
                title: 'Automatic matching',
                description:
                    'If your video is named DJI_001.mp4 and your telemetry is DJI_001.srt, the app will automatically pair them if they are in the same folder.',
              ),
              _HelpCard(
                icon: Icons.keyboard_command_key_rounded,
                title: 'Command palette',
                description:
                    'Press Cmd/Ctrl + K anywhere in the app shell to jump to queue actions, navigation, diagnostics, and the workflow tour.',
              ),
              _HelpCard(
                icon: Icons.article_rounded,
                title: 'Where are task details?',
                description:
                    'Open a task to view its full renderer log, queue lifecycle messages, and failure trace instead of using an inline inspector.',
              ),
            ],
          ),
          const SizedBox(height: 32),
          const _HelpSection(
            title: 'Supported File Types',
            items: [
              _HelpCard(
                icon: Icons.movie_rounded,
                title: 'Video Files (.mp4, .mov)',
                description:
                    'Primary footage from drone/goggles. High resolution (4K/HD) is fully supported.',
              ),
              _HelpCard(
                icon: Icons.subtitles_rounded,
                title: 'Subtitle Metadata (.srt)',
                description:
                    'Simple text-based logs (DJI, Walksnail). Fast rendering without re-encoding.',
              ),
              _HelpCard(
                icon: Icons.graphic_eq_rounded,
                title: 'Graphical OSD Logs (.osd)',
                description:
                    'High-fidelity logs from Blackbox. Recreates the full visual OSD gauges but requires full re-encode.',
              ),
            ],
          ),
          const SizedBox(height: 32),
          const _HelpSection(
            title: 'Troubleshooting',
            items: [
              _HelpCard(
                icon: Icons.error_outline_rounded,
                title: 'OSD rendering fails',
                description:
                    'Check Settings & Diagnostics to see which FFmpeg and Python paths were resolved. Packaged releases bundle them inside.',
              ),
              _HelpCard(
                icon: Icons.warning_amber_rounded,
                title: 'Sync Issues',
                description:
                    'The app assumes telemetry begins at the same time as the video. Discrepancies require adjusting start times.',
              ),
              _HelpCard(
                icon: Icons.help_outline_rounded,
                title: 'Files missing in queue',
                description:
                    'Both a video (.mp4) and matching telemetry (.srt/.osd) with the identical filename are required to form a task.',
              ),
              _HelpCard(
                icon: Icons.privacy_tip_rounded,
                title: 'Is this app cloud-backed?',
                description:
                    'No. Media processing, queue diagnostics, and stats stay on the local machine. The app does not ship with analytics or remote crash reporting.',
              ),
            ],
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withAlpha(50),
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: theme.colorScheme.primary.withAlpha(100)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.code_rounded,
                      color: theme.colorScheme.primary,
                      size: 32,
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Open Source Project',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'The app is open source and the renderer is documented against upstream FPV overlay references. Use the repository for releases, issues, and implementation notes.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: () =>
                          PlatformUtils.openUrl(AppIdentity.repositoryUrl),
                      child: const Text('View Repo'),
                    ),
                    OutlinedButton(
                      onPressed: () =>
                          PlatformUtils.openUrl(AppIdentity.releasesUrl),
                      child: const Text('Download Releases'),
                    ),
                    OutlinedButton(
                      onPressed: () => PlatformUtils.openUrl(
                        AppIdentity.upstreamOsdOverlayUrl,
                      ),
                      child: const Text('OSD Reference'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 64),
        ],
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  final String title;
  final List<Widget> items;

  const _HelpSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: items,
        ),
      ],
    );
  }
}

class _HelpCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _HelpCard({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: theme.colorScheme.outlineVariant.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 36),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
