import 'package:flutter/material.dart';
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
            'Support & FAQ',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Everything you need to know about FPV Overlay Toolbox.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 48),
          _HelpSection(
            title: 'Getting Started',
            items: [
              _HelpItem(
                question: 'How do I add videos?',
                answer:
                    'You can drag and drop your video files (.mp4 or .mov) directly onto the Overlay Queue, or use the "Select Pairs" button.',
              ),
              _HelpItem(
                question: 'What are "Telemetry Files"?',
                answer:
                    'These are data logs from your flight controller. We support .srt (DJI/Subtitles) and .osd (Betaflight/Inav) formats.',
              ),
              _HelpItem(
                question: 'How does automatic matching work?',
                answer:
                    'If your video is named DJI_001.mp4 and your telemetry is DJI_001.srt, the app will automatically pair them if they are in the same folder or selected together.',
              ),
            ],
          ),
          const SizedBox(height: 32),
          _HelpSection(
            title: 'Supported File Types',
            items: [
              _HelpItem(
                question: 'Video Files (.mp4, .mov)',
                answer:
                    'The primary footage from your drone, action camera, or goggles. High resolution (4K/HD) is supported.',
              ),
              _HelpItem(
                question: 'Subtitle Metadata (.srt)',
                answer:
                    'Simple text-based telemetry files used for DJI (Caddx/Vista) and Walksnail overlays. These allow for fast rendering without re-encoding.',
              ),
              _HelpItem(
                question: 'Graphical OSD Logs (.osd)',
                answer:
                    'High-fidelity data logs usually exported from Blackbox. These allow the toolbox to recreate the full visual OSD with all flight metrics and gauges.',
              ),
            ],
          ),
          const SizedBox(height: 32),
          _HelpSection(
            title: 'Compatible Hardware',
            items: [
              _HelpItem(
                question: 'DJI O3 Air Unit',
                answer:
                    'Supports both high-quality OSD Rendering and basic SRT subtitles. For OSD, ensure the "Canvas Mode" is set to HD in your Goggles. The telemetry is stored inside the MP4, but the engine handles extraction.',
              ),
              _HelpItem(
                question: 'Caddx Vista & Original Air Unit',
                answer:
                    'Primarily supports SRT subtitles. Most firmwares generate a companion .srt file alongside the video on the SD card. Use the "SRT Fast" mode for zero re-encode time.',
              ),
              _HelpItem(
                question: 'Betaflight & INAV (Blackbox)',
                answer:
                    'External telemetry logs (.osd files) can be generated from Blackbox logs using external tools. This app can then render those logs as a high-fidelity graphical overlay on any video source.',
              ),
              _HelpItem(
                question: 'Walksnail Avatar / FatShark Dominator',
                answer:
                    'Similar to DJI O3, these systems generate .srt files. Pair them with your video for automated subtitle overlays.',
              ),
            ],
          ),
          const SizedBox(height: 32),
          _HelpSection(
            title: 'Community & Branding',
            items: [
              _HelpItem(
                question: 'What does the new icon represent?',
                answer:
                    'Our solid cyan square icon represents the clean, high-performance nature of FPV racing. It symbolizes the precision and speed of our overlay engine.',
              ),
            ],
          ),
          const SizedBox(height: 32),
          _HelpSection(
            title: 'Technical Details',
            items: [
              _HelpItem(
                question: 'Which overlay type should I choose?',
                answer:
                    'SRT is much faster but has basic subtitles. OSD Rendering creates a high-definition graphical overlay but takes longer to process as it re-encodes the video.',
              ),
              _HelpItem(
                question: 'Where do my files go?',
                answer:
                    'The app will ask for an output directory when you start processing. All finished videos are saved as [original]_overlay.mp4.',
              ),
            ],
          ),
          const SizedBox(height: 32),
          _HelpSection(
            title: 'Troubleshooting',
            items: [
              _HelpItem(
                question: 'The processing fails immediately.',
                answer:
                    'Check the "System Info" tab to ensure FFmpeg and the Overlay Engine are correctly "BUNDLED" or found on your system path.',
              ),
              _HelpItem(
                question: 'The overlay is out of sync.',
                answer:
                    'The app assumes the telemetry starts at the same time as the video. Ensure your SD card was logging continuously.',
              ),
              _HelpItem(
                question: 'Why are some files not appearing in the queue?',
                answer:
                    'The engine automatically filters out empty (0-byte) files. Additionally, the app requires both a video (.mp4/.mov) and a matching telemetry file (.srt/.osd) with the same filename to create a task.',
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
            child: Row(
              children: [
                Icon(Icons.code_rounded,
                    color: theme.colorScheme.primary, size: 32),
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
                        'This toolbox is free and open source. If you find a bug or want to contribute, visit our GitHub repository.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                OutlinedButton(
                  onPressed: () {
                    // In a real app we'd use url_launcher
                  },
                  child: const Text('View on GitHub'),
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
  final List<_HelpItem> items;

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
        ...items,
      ],
    );
  }
}

class _HelpItem extends StatelessWidget {
  final String question;
  final String answer;

  const _HelpItem({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedAlignment: Alignment.topLeft,
        children: [
          Text(
            answer,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
