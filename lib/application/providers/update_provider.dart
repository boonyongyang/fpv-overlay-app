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

  Future<void> openInstaller() async {
    if (_downloadedPath == null) return;
    await Process.run('open', [_downloadedPath!]);
  }

  void cancelDownload() {
    _cancelRequested = true;
  }
}
