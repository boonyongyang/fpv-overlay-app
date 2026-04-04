import '../models/overlay_task.dart';

class OverlayProgressParser {
  const OverlayProgressParser();

  static final _osdFrameRe = RegExp(r'OSD frame (\d+)/(\d+)');
  static final _compositingRe = RegExp(r'Compositing:\s*(\d+)%');
  static final _renderingRe = RegExp(r'Rendering:\s*(\d+)%');

  void apply(OverlayTask task, String line) {
    final osdMatch = _osdFrameRe.firstMatch(line);
    if (osdMatch != null) {
      final current = int.parse(osdMatch.group(1)!);
      final total = int.parse(osdMatch.group(2)!);
      if (total > 0) {
        task.progress = (current / total) * 0.7;
        task.progressPhase = 'Rendering OSD frames';
      }
      return;
    }

    if (line.contains('Pass 1 complete')) {
      task.progress = 0.7;
      task.progressPhase = 'Compositing video';
      return;
    }

    final compMatch = _compositingRe.firstMatch(line);
    if (compMatch != null) {
      final pct = int.parse(compMatch.group(1)!);
      task.progress = 0.7 + (pct / 100) * 0.3;
      task.progressPhase = 'Compositing video';
      return;
    }

    final renderMatch = _renderingRe.firstMatch(line);
    if (renderMatch != null) {
      final pct = int.parse(renderMatch.group(1)!);
      task.progress = pct / 100;
      task.progressPhase = 'Rendering SRT overlay';
      return;
    }

    if (line.contains('Starting OSD HD Rendering') ||
        line.contains('Applying OSD HD Rendering')) {
      task.progressPhase = 'Preparing OSD rendering';
    } else if (line.contains('Pass 2:')) {
      task.progressPhase = 'Compositing video';
    } else if (line.contains('Rendering SRT HUD')) {
      task.progressPhase = 'Rendering SRT overlay';
    } else if (line.contains('Parsing SRT telemetry')) {
      task.progressPhase = 'Parsing SRT telemetry';
    }
  }
}
