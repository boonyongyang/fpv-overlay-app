import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:fpv_overlay_app/application/providers/settings_provider.dart';
import 'package:fpv_overlay_app/application/providers/workspace_provider.dart';
import 'package:fpv_overlay_app/presentation/pages/tutorial_page.dart';

class OnboardingOverlay extends StatelessWidget {
  const OnboardingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.black.withAlpha(160),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 1100 || constraints.maxHeight < 720;

          return Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: compact ? 920 : 980,
                maxHeight: compact ? 700 : 760,
              ),
              margin: EdgeInsets.all(compact ? 16 : 24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(compact ? 28 : 32),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withAlpha(60),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(90),
                    blurRadius: 52,
                    offset: const Offset(0, 24),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 18 : 24,
                      compact ? 16 : 20,
                      compact ? 18 : 24,
                      0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Welcome to FPV Overlay Toolbox',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _complete(context),
                          child: const Text('Skip for now'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: TutorialPage(
                      embedded: true,
                      showSkipButton: true,
                      onComplete: () => _complete(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _complete(BuildContext context) {
    unawaited(context.read<SettingsProvider>().markOnboardingComplete());
    context.read<WorkspaceProvider>().dismissOnboarding();
  }
}
