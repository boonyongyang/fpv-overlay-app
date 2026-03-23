import 'dart:io';

import 'package:flutter/material.dart';

import 'package:fpv_overlay_app/core/utils/path_resolver.dart';
import 'package:fpv_overlay_app/domain/models/app_configuration.dart';

class EnvironmentSummaryCard extends StatelessWidget {
  final AppConfiguration config;
  final VoidCallback? onCopyReport;
  final String title;
  final EdgeInsetsGeometry? padding;

  const EnvironmentSummaryCard({
    super.key,
    required this.config,
    this.onCopyReport,
    this.title = 'Environment Summary',
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outputStrategy = config.defaultOutputDirectory != null
        ? 'Default folder'
        : 'Choose at render time';

    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: theme.colorScheme.outlineVariant.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 520;
              final titleRow = Row(
                children: [
                  Icon(
                    Icons.memory_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              );
              final copyButton = onCopyReport != null
                  ? FilledButton.tonalIcon(
                      onPressed: onCopyReport,
                      icon: const Icon(Icons.content_copy_rounded, size: 16),
                      label: const Text('Copy report'),
                    )
                  : null;

              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleRow,
                    if (copyButton != null) ...[
                      const SizedBox(height: 12),
                      copyButton,
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: titleRow),
                  if (copyButton != null) ...[
                    const SizedBox(width: 12),
                    copyButton,
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SummaryTile(
                label: 'FFmpeg',
                value: PathResolver.ffmpegPath,
                icon: Icons.movie_creation_rounded,
              ),
              _SummaryTile(
                label: 'Python',
                value: PathResolver.pythonPath,
                icon: Icons.terminal_rounded,
              ),
              _SummaryTile(
                label: 'Overlay assets',
                value: PathResolver.o3OverlayToolPath ?? 'Bundled fonts only',
                icon: Icons.layers_rounded,
              ),
              _SummaryTile(
                label: 'Platform',
                value:
                    '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
                icon: Icons.desktop_windows_rounded,
              ),
              _SummaryTile(
                label: 'Output strategy',
                value: outputStrategy,
                icon: Icons.output_rounded,
              ),
              _SummaryTile(
                label: 'Default output',
                value: config.defaultOutputDirectory ?? 'Not configured',
                icon: Icons.folder_open_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'All rendering stays local to the device. This app does not upload media, analytics, or crash reports.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 240),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withAlpha(180),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
