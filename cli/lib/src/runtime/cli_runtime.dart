import 'dart:io';

import 'package:overlay_core/overlay_core.dart';
import 'package:path/path.dart' as p;

class CliRuntime implements OverlayRuntime {
  CliRuntime({String? workingDirectory})
      : _workingDirectory =
            p.normalize(workingDirectory ?? Directory.current.path);

  final String _workingDirectory;

  String get executablePath => p.normalize(Platform.resolvedExecutable);

  String? get runtimeDirectory {
    final envPath = Platform.environment['FPV_OVERLAY_RUNTIME_DIR'];
    if (envPath != null && Directory(envPath).existsSync()) {
      return p.normalize(envPath);
    }

    for (final base in _candidateRoots) {
      for (final relativePath in const [
        'runtime',
        '../runtime',
        '../libexec/runtime',
        'build/runtime',
      ]) {
        final candidate = p.normalize(p.join(base, relativePath));
        if (Directory(candidate).existsSync()) {
          return candidate;
        }
      }
    }

    return null;
  }

  String get ffprobePath {
    final envPath = Platform.environment['FPV_OVERLAY_FFPROBE'];
    if (_isExistingFile(envPath)) {
      return p.normalize(envPath!);
    }

    final runtimeDir = runtimeDirectory;
    if (runtimeDir != null) {
      final candidate = p.join(runtimeDir, _platformExecutable('ffprobe'));
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }

    return _platformExecutable('ffprobe');
  }

  @override
  String get ffmpegPath {
    final envPath = Platform.environment['FPV_OVERLAY_FFMPEG'];
    if (_isExistingFile(envPath)) {
      return p.normalize(envPath!);
    }

    final runtimeDir = runtimeDirectory;
    if (runtimeDir != null) {
      final candidate = p.join(runtimeDir, _platformExecutable('ffmpeg'));
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }

    return _platformExecutable('ffmpeg');
  }

  @override
  String get pythonPath {
    final executable = Platform.isWindows ? 'python.exe' : 'python3';
    return executable;
  }

  @override
  String get osdScriptPath => _findAssetScript('osd_overlay.py');

  @override
  String get srtScriptPath => _findAssetScript('srt_overlay.py');

  @override
  String? get bundledOsdExecutablePath =>
      _findBundledExecutable('FPV_OVERLAY_OSD_EXECUTABLE', 'osd_overlay');

  @override
  String? get bundledSrtExecutablePath =>
      _findBundledExecutable('FPV_OVERLAY_SRT_EXECUTABLE', 'srt_overlay');

  @override
  String? get o3OverlayToolPath {
    final envPath = Platform.environment['FPV_OVERLAY_O3_TOOL_PATH'];
    if (envPath != null && Directory(envPath).existsSync()) {
      return p.normalize(envPath);
    }
    return null;
  }

  List<String> get _candidateRoots {
    final executableDir = p.dirname(executablePath);
    return <String>{
      _workingDirectory,
      p.normalize(p.join(_workingDirectory, '..')),
      p.normalize(p.join(_workingDirectory, '..', '..')),
      executableDir,
      p.normalize(p.join(executableDir, '..')),
      p.normalize(p.join(executableDir, '..', '..')),
    }.toList();
  }

  String _findAssetScript(String name) {
    for (final root in _candidateRoots) {
      final candidate = p.normalize(p.join(root, 'assets', 'bin', name));
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    return name;
  }

  String? _findBundledExecutable(String envKey, String name) {
    final envPath = Platform.environment[envKey];
    if (_isExistingFile(envPath)) {
      return p.normalize(envPath!);
    }

    final runtimeDir = runtimeDirectory;
    if (runtimeDir == null) return null;

    final candidate = p.join(runtimeDir, name, _platformExecutable(name));
    if (File(candidate).existsSync()) {
      return candidate;
    }

    return null;
  }

  String _platformExecutable(String name) {
    final extension = Platform.isWindows ? '.exe' : '';
    return '$name$extension';
  }

  bool _isExistingFile(String? path) {
    return path != null && path.isNotEmpty && File(path).existsSync();
  }
}
