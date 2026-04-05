import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

import 'package:fpv_overlay_app/domain/models/update_info.dart';
import 'package:fpv_overlay_app/domain/services/update_service.dart';

class UpdateProvider extends ChangeNotifier {
  UpdateProvider({
    required UpdateService updateService,
    String? currentVersion,
    http.Client? httpClient,
  })  : _updateService = updateService,
        _currentVersion = currentVersion,
        _httpClient = httpClient ?? http.Client() {
    unawaited(refresh());
  }

  final UpdateService _updateService;
  final http.Client _httpClient;

  /// Injected in tests to bypass [PackageInfo.fromPlatform].
  final String? _currentVersion;

  UpdateInfo? _availableUpdate;
  String? _resolvedVersion;
  bool _isChecking = false;
  bool _isDownloading = false;
  double? _downloadProgress;
  String? _downloadedPath;
  String? _statusMessage;
  bool _cancelRequested = false;

  UpdateInfo? get availableUpdate => _availableUpdate;
  bool get hasUpdate => _availableUpdate != null;
  String? get resolvedVersion => _resolvedVersion;
  bool get isChecking => _isChecking;
  bool get isDownloading => _isDownloading;
  double? get downloadProgress => _downloadProgress;
  String? get downloadedPath => _downloadedPath;
  bool get readyToInstall => _downloadedPath != null;
  String? get statusMessage => _statusMessage;

  void dismiss() {
    if (_availableUpdate == null) return;
    _availableUpdate = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      final version =
          _currentVersion ?? (await PackageInfo.fromPlatform()).version;
      _resolvedVersion = version;
      final update = await _updateService.checkForUpdate(version);
      if (update != null) {
        _availableUpdate = update;
      }
      notifyListeners();
    } catch (_) {
      // silently absorb all errors — update check must never crash the app
    }
  }

  Future<void> checkForUpdates() async {
    if (_isChecking || _isDownloading) return;
    _isChecking = true;
    _statusMessage = null;
    _availableUpdate = null;
    notifyListeners();
    try {
      final version =
          _currentVersion ?? (await PackageInfo.fromPlatform()).version;
      _resolvedVersion = version;
      final update = await _updateService.checkForUpdate(version);
      if (update != null) {
        _availableUpdate = update;
        _statusMessage = null;
      } else {
        _statusMessage = 'Up to date';
      }
    } catch (_) {
      _statusMessage = 'Check failed';
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  Future<void> startDownload() async {
    if (!Platform.isMacOS) return;
    if (_availableUpdate == null || _isDownloading) return;

    final update = _availableUpdate!;
    _isDownloading = true;
    _downloadProgress = 0;
    _cancelRequested = false;
    _downloadedPath = null;
    _statusMessage = null;
    notifyListeners();

    final artifactName = p.basename(update.artifactUrl);
    final destPath = p.join(Directory.systemTemp.path, artifactName);
    final destFile = File(destPath);

    try {
      final request = http.Request('GET', Uri.parse(update.artifactUrl));
      final response = await _httpClient.send(request);
      final total = response.contentLength ?? 0;
      var received = 0;

      final sink = destFile.openWrite();
      await for (final chunk in response.stream) {
        if (_cancelRequested) {
          await sink.close();
          if (await destFile.exists()) await destFile.delete();
          _isDownloading = false;
          _downloadProgress = null;
          _cancelRequested = false;
          notifyListeners();
          return;
        }
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          _downloadProgress = received / total;
          notifyListeners();
        }
      }
      await sink.close();

      // Verify SHA256
      final result = await Process.run('shasum', ['-a', '256', destPath]);
      final actualSha = (result.stdout as String).trim().split(' ').first;
      if (actualSha != update.sha256) {
        if (await destFile.exists()) await destFile.delete();
        _statusMessage = 'Download verification failed';
        _isDownloading = false;
        _downloadProgress = null;
        notifyListeners();
        return;
      }

      _downloadedPath = destPath;
      _isDownloading = false;
      _downloadProgress = null;
      notifyListeners();
    } catch (_) {
      if (await destFile.exists()) await destFile.delete();
      _statusMessage = 'Download failed';
      _isDownloading = false;
      _downloadProgress = null;
      notifyListeners();
    }
  }

  /// Installs the downloaded update and relaunches the app.
  ///
  /// On macOS release builds: mounts the DMG silently, writes a detached
  /// installer script that waits for this process to exit, copies the new
  /// .app bundle over the existing one with `ditto`, relaunches, then
  /// quits the current app.
  ///
  /// Falls back to opening the DMG manually if not running from a .app
  /// bundle (e.g. in dev mode) or if `ditto` fails.
  Future<void> installUpdate() async {
    if (_downloadedPath == null || !Platform.isMacOS) return;

    final bundlePath = _resolveAppBundlePath();
    if (bundlePath == null) {
      // Dev build — just open the DMG for manual drag-install.
      await Process.run('open', [_downloadedPath!]);
      return;
    }

    // Mount the DMG silently.
    final attachResult = await Process.run('hdiutil', [
      'attach',
      _downloadedPath!,
      '-nobrowse',
      '-noverify',
      '-noautoopen',
    ]);

    if (attachResult.exitCode != 0) {
      _statusMessage = 'Failed to mount update package';
      notifyListeners();
      return;
    }

    // Parse the volume mount point (last tab-separated field of the last
    // line that starts with /Volumes/).
    String? volumePath;
    for (final line in (attachResult.stdout as String).split('\n').reversed) {
      final candidate = line.split('\t').last.trim();
      if (candidate.startsWith('/Volumes/')) {
        volumePath = candidate;
        break;
      }
    }

    if (volumePath == null) {
      _statusMessage = 'Could not locate mounted volume';
      notifyListeners();
      return;
    }

    // Find the .app bundle inside the mounted volume.
    final appInVolume = Directory(volumePath)
        .listSync()
        .whereType<Directory>()
        .where((e) => e.path.endsWith('.app'))
        .map((e) => e.path)
        .firstOrNull;

    if (appInVolume == null) {
      await Process.run('hdiutil', ['detach', volumePath, '-quiet']);
      _statusMessage = 'No app bundle found in update package';
      notifyListeners();
      return;
    }

    // Write a detached bash script.
    // The script polls until this process exits, then installs and relaunches.
    final currentPid = pid;
    final dmgPath = _downloadedPath!;
    final scriptPath = '/tmp/fpv_overlay_update_$currentPid.sh';

    final script = '''#!/bin/bash
# Wait for the old app to quit.
while kill -0 $currentPid 2>/dev/null; do
  sleep 0.3
done
sleep 0.3

# Install the new version.
if ditto "$appInVolume" "$bundlePath"; then
  open "$bundlePath"
  hdiutil detach "$volumePath" -quiet 2>/dev/null || true
  rm -f "$dmgPath"
else
  # ditto failed — open the volume so the user can drag-install manually.
  open "$volumePath"
fi
rm -f "$scriptPath"
''';

    await File(scriptPath).writeAsString(script);
    await Process.run('chmod', ['+x', scriptPath]);

    // Launch the script detached so it survives this process exiting.
    await Process.start('bash', [scriptPath], mode: ProcessStartMode.detached);

    // Quit the current app — the script will relaunch the new version.
    exit(0);
  }

  /// Returns the current .app bundle root, or null when running outside a
  /// bundle (e.g. during development).
  String? _resolveAppBundlePath() {
    final exe = Platform.resolvedExecutable;
    if (!exe.contains('.app/Contents/MacOS')) return null;
    // .../App.app/Contents/MacOS/exec → navigate up two levels.
    return p.normalize(p.join(p.dirname(exe), '..', '..'));
  }

  void cancelDownload() {
    _cancelRequested = true;
  }
}
