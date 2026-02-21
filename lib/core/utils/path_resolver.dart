import 'dart:io';
import 'package:path/path.dart' as p;

class PathResolver {
  /// Returns the path to the internal 'resources' directory.
  /// When running as a bundled macOS app, this points to Contents/Resources/bin.
  /// During development, it points to a root project 'bin' folder or similar.
  static String getInternalResourcesPath() {
    final exePath = Platform.resolvedExecutable;

    if (Platform.isMacOS) {
      // If we are inside a macOS .app bundle
      if (exePath.contains('.app/Contents/MacOS')) {
        return p
            .normalize(p.join(p.dirname(exePath), '..', 'Resources', 'bin'));
      }
    } else if (Platform.isWindows) {
      // If we are in a Windows installed bundle
      if (exePath.contains('\\data\\')) {
        return p.join(
            p.dirname(exePath), 'data', 'flutter_assets', 'assets', 'bin');
      }
    }

    // Fallback for local development or if not bundled
    return p.join(Directory.current.path, 'assets', 'bin');
  }

  static String get ffmpegPath {
    final extension = Platform.isWindows ? '.exe' : '';
    final path = p.join(getInternalResourcesPath(), 'ffmpeg$extension');
    if (File(path).existsSync()) {
      return path;
    }
    return 'ffmpeg$extension'; // Fallback to system path if not bundled
  }

  static String get pythonPath {
    final extension = Platform.isWindows ? '.exe' : '';
    final binaryName = Platform.isWindows ? 'python' : 'python3';
    final path = p.join(getInternalResourcesPath(), '$binaryName$extension');
    if (File(path).existsSync()) {
      return path;
    }
    return '$binaryName$extension'; // Fallback to system path
  }

  static String? get o3OverlayToolPath {
    final path = p.join(getInternalResourcesPath(), 'O3_OverlayTool');
    if (Directory(path).existsSync()) {
      return path;
    }

    // Check development fallback
    final devPath = p.join(Directory.current.path, 'O3_OverlayTool');
    if (Directory(devPath).existsSync()) {
      return devPath;
    }

    return null;
  }
}
