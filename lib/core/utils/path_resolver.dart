import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:fpv_overlay_app/domain/models/app_configuration.dart';

class PathResolver {
  static AppConfiguration? _appConfig;

  /// Set the application configuration to enable dynamic path resolution.
  static void setAppConfiguration(AppConfiguration config) {
    _appConfig = config;
  }

  /// Returns the path to the internal 'resources' directory.
  /// In a shipped macOS .app Flutter assets live under:
  ///   Contents/Frameworks/App.framework/Resources/flutter_assets/assets/bin
  /// During development (`flutter run`) that bundle path is not populated, so
  /// we fall back to the source-tree assets/bin/ directory.
  static String getInternalResourcesPath() {
    final exePath = Platform.resolvedExecutable;

    if (Platform.isMacOS) {
      if (exePath.contains('.app/Contents/MacOS')) {
        final bundledCandidates = <String>[
          // Flutter macOS app bundle asset location.
          p.normalize(
            p.join(
              p.dirname(exePath),
              '..',
              'Frameworks',
              'App.framework',
              'Resources',
              'flutter_assets',
              'assets',
              'bin',
            ),
          ),
          // Legacy / custom copied resource layout.
          p.normalize(p.join(p.dirname(exePath), '..', 'Resources', 'bin')),
        ];

        for (final bundledPath in bundledCandidates) {
          if (Directory(bundledPath).existsSync()) {
            return bundledPath;
          }
        }
      }
    } else if (Platform.isWindows) {
      final bundledCandidates = <String>[
        p.join(p.dirname(exePath), 'data', 'flutter_assets', 'assets', 'bin'),
        p.join(
          Directory.current.path,
          'data',
          'flutter_assets',
          'assets',
          'bin',
        ),
      ];

      for (final bundledPath in bundledCandidates) {
        if (Directory(bundledPath).existsSync()) {
          return bundledPath;
        }
      }
    }

    // Development fallback: source-tree assets/bin/
    return p.join(Directory.current.path, 'assets', 'bin');
  }

  static String? get bundledRuntimePath {
    final exePath = Platform.resolvedExecutable;

    if (Platform.isMacOS && exePath.contains('.app/Contents/MacOS')) {
      final runtimePath = p.normalize(
        p.join(p.dirname(exePath), '..', 'Resources', 'runtime'),
      );
      if (Directory(runtimePath).existsSync()) {
        return runtimePath;
      }
    }

    if (Platform.isWindows && exePath.contains('\\')) {
      final runtimePath = p.join(p.dirname(exePath), 'runtime');
      if (Directory(runtimePath).existsSync()) {
        return runtimePath;
      }
    }

    final devRuntimePath = p.join(Directory.current.path, 'build', 'runtime');
    if (Directory(devRuntimePath).existsSync()) {
      return devRuntimePath;
    }

    return null;
  }

  static String? _runtimeFile(String name) {
    final runtimePath = bundledRuntimePath;
    if (runtimePath == null) {
      return null;
    }

    final candidate = p.join(runtimePath, name);
    if (File(candidate).existsSync()) {
      return candidate;
    }

    return null;
  }

  static String? _runtimeToolExecutable(String toolName) {
    final runtimePath = bundledRuntimePath;
    if (runtimePath == null) {
      return null;
    }

    final extension = Platform.isWindows ? '.exe' : '';
    final bundledToolPath =
        p.join(runtimePath, toolName, '$toolName$extension');
    if (File(bundledToolPath).existsSync()) {
      return bundledToolPath;
    }

    return null;
  }

  static String? get bundledOsdExecutablePath =>
      _runtimeToolExecutable('osd_overlay');

  static String? get bundledSrtExecutablePath =>
      _runtimeToolExecutable('srt_overlay');

  static String? get ffprobePath {
    final extension = Platform.isWindows ? '.exe' : '';
    final bundledPath = _runtimeFile('ffprobe$extension');
    if (bundledPath != null) {
      return bundledPath;
    }

    final assetPath = p.join(getInternalResourcesPath(), 'ffprobe$extension');
    if (File(assetPath).existsSync()) {
      return assetPath;
    }

    return 'ffprobe$extension';
  }

  static String get ffmpegPath {
    final extension = Platform.isWindows ? '.exe' : '';
    final bundledPath = _runtimeFile('ffmpeg$extension');
    if (bundledPath != null) {
      return bundledPath;
    }

    final assetPath = p.join(getInternalResourcesPath(), 'ffmpeg$extension');
    if (File(assetPath).existsSync()) {
      return assetPath;
    }
    return 'ffmpeg$extension'; // Fallback to system path if not bundled
  }

  static String get pythonPath {
    final extension = Platform.isWindows ? '.exe' : '';
    final binaryName = Platform.isWindows ? 'python' : 'python3';

    // 1. Bundled Python alongside the app (shipping scenario)
    final bundledPath =
        p.join(getInternalResourcesPath(), '$binaryName$extension');
    if (File(bundledPath).existsSync()) {
      return bundledPath;
    }

    // 2. On macOS / Linux, search known locations for a Python that has numpy.
    //    This handles the common Homebrew situation where `python3` → 3.13 (no
    //    packages) but `python3.11` in the same /bin has all the packages installed.
    if (!Platform.isWindows) {
      final candidates = <String>[
        '/opt/homebrew/bin/python3.11', // Apple Silicon Homebrew (most common)
        '/opt/homebrew/bin/python3.12',
        '/opt/homebrew/bin/python3.13',
        '/opt/homebrew/bin/python3',
        '/usr/local/bin/python3.11', // Intel Homebrew
        '/usr/local/bin/python3.12',
        '/usr/local/bin/python3',
        '/usr/bin/python3',
      ];
      for (final candidate in candidates) {
        if (!File(candidate).existsSync()) continue;
        // Quick check: can this interpreter import numpy?
        final result = Process.runSync(
          candidate,
          ['-c', 'import numpy, PIL, pandas'],
          stdoutEncoding: null,
          stderrEncoding: null,
        );
        if (result.exitCode == 0) {
          return candidate;
        }
      }
      // No numpy-capable Python found – fall back to whatever python3 is on PATH.
    }

    return '$binaryName$extension';
  }

  static String? get o3OverlayToolPath {
    // 1. User-configured path (highest priority)
    if (_appConfig?.o3OverlayToolPath != null &&
        _appConfig!.o3OverlayToolPath!.isNotEmpty) {
      final customPath = _appConfig!.o3OverlayToolPath!;
      if (Directory(customPath).existsSync()) {
        return customPath;
      }
    }

    // 2. Bundled alongside the app resources
    final bundledPath = p.join(getInternalResourcesPath(), 'O3_OverlayTool');
    if (Directory(bundledPath).existsSync()) {
      return bundledPath;
    }

    // 3. Source-tree dev fallback
    final devPath = p.join(Directory.current.path, 'O3_OverlayTool');
    if (Directory(devPath).existsSync()) {
      return devPath;
    }

    // 4. Auto-detect from common download locations (macOS / Linux)
    if (!Platform.isWindows) {
      final home = Platform.environment['HOME'] ?? '';
      final downloadsDir = p.join(home, 'Downloads');
      for (final name in [
        'O3_OverlayTool-1.1.0',
        'O3_OverlayTool-1.0.0',
        'O3_OverlayTool',
      ]) {
        final autoPath = p.join(downloadsDir, name);
        if (Directory(autoPath).existsSync()) {
          return autoPath;
        }
      }
    }

    return null;
  }

  /// Path to the bundled osd_overlay.py script.
  static String get osdScriptPath =>
      p.join(getInternalResourcesPath(), 'osd_overlay.py');

  /// Path to the bundled srt_overlay.py script.
  static String get srtScriptPath =>
      p.join(getInternalResourcesPath(), 'srt_overlay.py');

  /// Path to the bundled OSD font PNG directory (assets/bin/fonts/).
  static String get bundledFontsPath =>
      p.join(getInternalResourcesPath(), 'fonts');
}
