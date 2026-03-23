import 'package:flutter/material.dart';

class EmptyStateView extends StatelessWidget {
  final bool compact;
  final Future<void> Function() onAddFiles;
  final Future<void> Function() onAddFolder;
  final Future<void> Function() onOpenTutorial;
  final VoidCallback onOpenSettings;
  final Future<void> Function(String path) onRecentInputSelected;
  final Future<void> Function(String path) onRecentOutputSelected;
  final List<String> recentInputDirectories;
  final List<String> recentOutputDirectories;

  const EmptyStateView({
    super.key,
    this.compact = false,
    required this.onAddFiles,
    required this.onAddFolder,
    required this.onOpenTutorial,
    required this.onOpenSettings,
    required this.onRecentInputSelected,
    required this.onRecentOutputSelected,
    required this.recentInputDirectories,
    required this.recentOutputDirectories,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = compact ||
            constraints.maxWidth < 720 ||
            constraints.maxHeight < 680;
        final horizontalPadding = isCompact ? 20.0 : 40.0;
        final verticalPadding = isCompact ? 16.0 : 32.0;
        final minHeight = constraints.hasBoundedHeight
            ? (constraints.maxHeight - (verticalPadding * 2))
                .clamp(0.0, double.infinity)
                .toDouble()
            : 0.0;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isCompact ? 460 : 520),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(isCompact ? 18 : 24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withAlpha(15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.video_library_rounded,
                        size: isCompact ? 48 : 64,
                        color: theme.colorScheme.primary.withAlpha(120),
                      ),
                    ),
                    SizedBox(height: isCompact ? 18 : 24),
                    Text(
                      'Build your first overlay batch',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Import files, scan a folder, or open the quick tour. Partial matches stay visible until they are linked.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    SizedBox(height: isCompact ? 20 : 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: onAddFiles,
                          icon: const Icon(Icons.add_photo_alternate_rounded),
                          label: const Text('Add Files'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: onAddFolder,
                          icon: const Icon(Icons.folder_copy_rounded),
                          label: const Text('Scan Folder'),
                        ),
                        OutlinedButton.icon(
                          onPressed: onOpenTutorial,
                          icon: const Icon(Icons.school_rounded),
                          label: const Text('Quick Tour'),
                        ),
                        OutlinedButton.icon(
                          onPressed: onOpenSettings,
                          icon: const Icon(Icons.settings_rounded),
                          label: const Text('Settings'),
                        ),
                      ],
                    ),
                    SizedBox(height: isCompact ? 18 : 24),
                    const Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        _InstructionStep(
                          icon: Icons.file_present_rounded,
                          text: 'Mix video and telemetry in one import',
                        ),
                        _InstructionStep(
                          icon: Icons.link_rounded,
                          text: 'Keep partial matches visible until ready',
                        ),
                      ],
                    ),
                    if (recentInputDirectories.isNotEmpty ||
                        recentOutputDirectories.isNotEmpty) ...[
                      SizedBox(height: isCompact ? 22 : 28),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Recent launch points',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (recentInputDirectories.isNotEmpty)
                        _RecentSection(
                          compact: isCompact,
                          title: 'Recent input folders',
                          paths: recentInputDirectories,
                          icon: Icons.folder_copy_rounded,
                          onSelected: onRecentInputSelected,
                        ),
                      if (recentOutputDirectories.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _RecentSection(
                          compact: isCompact,
                          title: 'Recent output folders',
                          paths: recentOutputDirectories,
                          icon: Icons.output_rounded,
                          onSelected: onRecentOutputSelected,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RecentSection extends StatelessWidget {
  final bool compact;
  final String title;
  final List<String> paths;
  final IconData icon;
  final Future<void> Function(String path) onSelected;

  const _RecentSection({
    required this.compact,
    required this.title,
    required this.paths,
    required this.icon,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: paths.map((path) {
            return ActionChip(
              avatar: Icon(
                icon,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              label: SizedBox(
                width: compact ? 150 : 180,
                child: Text(
                  path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              onPressed: () => onSelected(path),
            );
          }).toList(growable: false),
        ),
      ],
    );
  }
}

class _InstructionStep extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InstructionStep({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.primary.withAlpha(100),
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
