import 'package:flutter/material.dart';

class TutorialPage extends StatelessWidget {
  final VoidCallback? onComplete;
  final bool showDismissButton;
  final bool showSkipButton;
  final bool embedded;

  const TutorialPage({
    super.key,
    this.onComplete,
    this.showDismissButton = true,
    this.showSkipButton = false,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = TutorialDeck(
      onComplete: onComplete ?? () => Navigator.of(context).maybePop(),
      showSkipButton: showSkipButton,
      embedded: embedded,
    );

    if (embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Workflow Tour'),
        leading: showDismissButton
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
      ),
      body: SafeArea(child: content),
    );
  }
}

class TutorialDeck extends StatefulWidget {
  final VoidCallback onComplete;
  final bool showSkipButton;
  final bool embedded;

  const TutorialDeck({
    super.key,
    required this.onComplete,
    this.showSkipButton = false,
    this.embedded = false,
  });

  @override
  State<TutorialDeck> createState() => _TutorialDeckState();
}

class _TutorialDeckState extends State<TutorialDeck> {
  static const _steps = <_TutorialStepData>[
    _TutorialStepData(
      icon: Icons.dashboard_customize_rounded,
      eyebrow: 'Desktop workspace',
      title: 'Build a queue fast',
      description:
          'Drop files or scan a folder. The workspace keeps every task visible.',
      bullets: [
        'Mix video, SRT, and OSD files in one pass.',
        'Use filters to focus on what needs attention.',
      ],
    ),
    _TutorialStepData(
      icon: Icons.article_rounded,
      eyebrow: 'Task logs',
      title: 'Open the live output when needed',
      description:
          'Open any task to see the renderer output, lifecycle messages, and failure trace.',
      bullets: [
        'Use logs for progress, failures, and output confirmation.',
        'Copy a report when you need to debug the local setup.',
      ],
    ),
    _TutorialStepData(
      icon: Icons.keyboard_command_key_rounded,
      eyebrow: 'Power controls',
      title: 'Use the command palette',
      description:
          'Press Cmd/Ctrl + K for quick actions, settings, help, and diagnostics.',
      bullets: [
        'Start the queue, cancel work, or open folders instantly.',
        'Everything stays local on your machine.',
      ],
    ),
  ];

  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _advance() {
    if (_currentPage == _steps.length - 1) {
      widget.onComplete();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  void _goBack() {
    if (_currentPage == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = widget.embedded
        ? const EdgeInsets.fromLTRB(20, 20, 20, 16)
        : const EdgeInsets.fromLTRB(32, 24, 32, 24);

    return Padding(
      padding: padding,
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primaryContainer.withAlpha(180),
                    theme.colorScheme.surfaceContainerLow,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withAlpha(50),
                ),
              ),
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final compactStep = constraints.maxWidth < 720 ||
                          constraints.maxHeight < 440;
                      final bodyPadding = compactStep ? 20.0 : 28.0;

                      return SingleChildScrollView(
                        padding: EdgeInsets.all(bodyPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface.withAlpha(180),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                step.eyebrow.toUpperCase(),
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            SizedBox(height: compactStep ? 18 : 24),
                            if (compactStep) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surface.withAlpha(180),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  step.icon,
                                  size: 40,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                step.title,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.8,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                step.description,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ] else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface
                                          .withAlpha(180),
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: theme.colorScheme.primary
                                              .withAlpha(30),
                                          blurRadius: 32,
                                          offset: const Offset(0, 18),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      step.icon,
                                      size: 56,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          step.title,
                                          style: theme.textTheme.headlineMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -1,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          step.description,
                                          style: theme.textTheme.bodyLarge
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                            height: 1.45,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            SizedBox(height: compactStep ? 20 : 28),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: step.bullets
                                  .map(
                                    (bullet) => _TutorialBulletCard(
                                      compact: compactStep,
                                      text: bullet,
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 560;
              final indicators = Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_steps.length, (index) {
                  final active = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primary.withAlpha(60),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              );

              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: _currentPage == 0 ? null : _goBack,
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _advance,
                    icon: Icon(
                      _currentPage == _steps.length - 1
                          ? Icons.rocket_launch_rounded
                          : Icons.arrow_forward_rounded,
                    ),
                    label: Text(
                      _currentPage == _steps.length - 1 ? 'Start' : 'Next',
                    ),
                  ),
                ],
              );

              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.showSkipButton)
                      TextButton(
                        onPressed: widget.onComplete,
                        child: const Text('Skip'),
                      ),
                    const SizedBox(height: 8),
                    Center(child: indicators),
                    const SizedBox(height: 14),
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                );
              }

              return Row(
                children: [
                  if (widget.showSkipButton)
                    TextButton(
                      onPressed: widget.onComplete,
                      child: const Text('Skip'),
                    )
                  else
                    const SizedBox(width: 84),
                  const Spacer(),
                  indicators,
                  const Spacer(),
                  actions,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TutorialBulletCard extends StatelessWidget {
  final bool compact;
  final String text;

  const _TutorialBulletCard({
    required this.text,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: compact ? 180 : 220,
        maxWidth: compact ? 240 : 280,
      ),
      child: Container(
        padding: EdgeInsets.all(compact ? 14 : 18),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withAlpha(170),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: theme.colorScheme.outlineVariant.withAlpha(50)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: (compact
                        ? theme.textTheme.bodySmall
                        : theme.textTheme.bodyMedium)
                    ?.copyWith(height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialStepData {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;
  final List<String> bullets;

  const _TutorialStepData({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.bullets,
  });
}
