import 'package:flutter/material.dart';

import 'package:fpv_overlay_app/core/constants/app_identity.dart';
import 'package:fpv_overlay_app/presentation/widgets/fpv_logo.dart';

/// Desktop sidebar with branding, navigation items, and a help shortcut.
class AppSidebar extends StatelessWidget {
  final double width;
  final bool compact;
  final bool collapsed;
  final int selectedIndex;
  final void Function(int) onTabSelected;
  final VoidCallback? onToggleCollapsed;

  const AppSidebar({
    super.key,
    this.width = 260,
    this.compact = false,
    this.collapsed = false,
    required this.selectedIndex,
    required this.onTabSelected,
    this.onToggleCollapsed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: width,
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
          SizedBox(height: collapsed ? 18 : (compact ? 28 : 36)),
          _SidebarHeader(
            theme: theme,
            compact: compact,
            collapsed: collapsed,
            onToggleCollapsed: onToggleCollapsed,
          ),
          SizedBox(height: collapsed ? 12 : (compact ? 10 : 16)),
          SidebarItem(
            icon: Icons.movie_filter_rounded,
            label: 'Overlay Queue',
            isSelected: selectedIndex == 0,
            onTap: () => onTabSelected(0),
            compact: compact,
            collapsed: collapsed,
          ),
          SidebarItem(
            icon: Icons.settings_rounded,
            label: 'Stats & Settings',
            isSelected: selectedIndex == 1,
            onTap: () => onTabSelected(1),
            compact: compact,
            collapsed: collapsed,
          ),
          const Spacer(),
          _SidebarHelpButton(
            isSelected: selectedIndex == 2,
            onTap: () => onTabSelected(2),
            compact: compact,
            collapsed: collapsed,
          ),
        ],
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  final ThemeData theme;
  final bool compact;
  final bool collapsed;
  final VoidCallback? onToggleCollapsed;

  const _SidebarHeader({
    required this.theme,
    required this.compact,
    required this.collapsed,
    required this.onToggleCollapsed,
  });

  @override
  Widget build(BuildContext context) {
    final button = onToggleCollapsed == null
        ? null
        : Tooltip(
            message: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
            child: IconButton(
              onPressed: onToggleCollapsed,
              icon: Icon(
                collapsed
                    ? Icons.chevron_right_rounded
                    : Icons.chevron_left_rounded,
              ),
              style: IconButton.styleFrom(
                backgroundColor:
                    theme.colorScheme.surfaceContainerHighest.withAlpha(100),
                foregroundColor: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            if (button != null) button,
            const SizedBox(height: 14),
            const Tooltip(
              message: AppIdentity.name,
              child: FpvLogo(size: 28, color: Colors.cyanAccent),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 18.0 : 24.0,
        vertical: compact ? 12.0 : 16.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    FpvLogo(size: compact ? 28 : 32, color: Colors.cyanAccent),
                    SizedBox(width: compact ? 10 : 12),
                    Expanded(
                      child: Text(
                        AppIdentity.name,
                        maxLines: 2,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          height: 1.05,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (button != null) ...[
                const SizedBox(width: 8),
                button,
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            compact
                ? 'Desktop v${AppIdentity.version}'
                : 'Desktop workspace v${AppIdentity.version}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: compact ? 5 : 6,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              compact ? 'Cmd/Ctrl + K' : 'Cmd/Ctrl + K command palette',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarHelpButton extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final bool compact;
  final bool collapsed;

  const _SidebarHelpButton({
    required this.isSelected,
    required this.onTap,
    required this.compact,
    required this.collapsed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.all(compact ? 12.0 : 16.0),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withAlpha(150)
            : theme.colorScheme.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(compact ? 10 : 12),
            child: collapsed
                ? Tooltip(
                    message: 'Help',
                    child: Icon(
                      Icons.help_outline_rounded,
                      size: 18,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : Row(
                    children: [
                      Icon(
                        Icons.help_outline_rounded,
                        size: 16,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Need help?',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: isSelected
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
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

class SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool compact;
  final bool collapsed;

  const SidebarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.compact = false,
    this.collapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12.0 : 16.0,
        vertical: 4.0,
      ),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withAlpha(150)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12.0 : 16.0,
              vertical: compact ? 10.0 : 12.0,
            ),
            child: collapsed
                ? Tooltip(
                    message: label,
                    child: Icon(
                      icon,
                      size: compact ? 18 : 20,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : Row(
                    children: [
                      Icon(
                        icon,
                        size: compact ? 18 : 20,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(width: compact ? 12 : 16),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSurfaceVariant,
                          ),
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
