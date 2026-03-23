import 'package:flutter/foundation.dart';
import 'package:fpv_overlay_app/core/utils/path_resolver.dart';
import 'package:fpv_overlay_app/domain/models/app_configuration.dart';
import 'package:fpv_overlay_app/infrastructure/services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  static const int _maxRecentDirectories = 5;

  final StorageService _storageService;

  AppConfiguration _config = const AppConfiguration();
  bool _isLoading = true;

  SettingsProvider({required StorageService storageService})
      : _storageService = storageService {
    _loadInitialConfig();
  }

  AppConfiguration get config => _config;
  bool get isLoading => _isLoading;

  Future<void> _loadInitialConfig() async {
    _config = await _storageService.loadConfig();
    PathResolver.setAppConfiguration(_config);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateConfig({
    Object? lastUsedInputDirectory = _sentinel,
    Object? lastUsedOutputDirectory = _sentinel,
    Object? defaultOutputDirectory = _sentinel,
    Object? o3OverlayToolPath = _sentinel,
    Object? hasCompletedOnboarding = _sentinel,
    Object? recentInputDirectories = _sentinel,
    Object? recentOutputDirectories = _sentinel,
  }) async {
    final resolvedLastInput = identical(lastUsedInputDirectory, _sentinel)
        ? _config.lastUsedInputDirectory
        : lastUsedInputDirectory as String?;
    final resolvedLastOutput = identical(lastUsedOutputDirectory, _sentinel)
        ? _config.lastUsedOutputDirectory
        : lastUsedOutputDirectory as String?;

    _config = _config.copyWith(
      lastUsedInputDirectory: resolvedLastInput,
      lastUsedOutputDirectory: resolvedLastOutput,
      defaultOutputDirectory: identical(defaultOutputDirectory, _sentinel)
          ? _config.defaultOutputDirectory
          : defaultOutputDirectory as String?,
      o3OverlayToolPath: identical(o3OverlayToolPath, _sentinel)
          ? _config.o3OverlayToolPath
          : o3OverlayToolPath as String?,
      hasCompletedOnboarding: identical(hasCompletedOnboarding, _sentinel)
          ? _config.hasCompletedOnboarding
          : hasCompletedOnboarding as bool,
      recentInputDirectories: identical(recentInputDirectories, _sentinel)
          ? _mergeRecentDirectories(
              _config.recentInputDirectories,
              resolvedLastInput,
            )
          : recentInputDirectories as List<String>,
      recentOutputDirectories: identical(recentOutputDirectories, _sentinel)
          ? _mergeRecentDirectories(
              _config.recentOutputDirectories,
              resolvedLastOutput,
            )
          : recentOutputDirectories as List<String>,
    );
    PathResolver.setAppConfiguration(_config);
    notifyListeners();
    await _storageService.saveConfig(_config);
  }

  Future<void> addRecentInputDirectory(String directory) {
    return updateConfig(lastUsedInputDirectory: directory);
  }

  Future<void> addRecentOutputDirectory(String directory) {
    return updateConfig(lastUsedOutputDirectory: directory);
  }

  Future<void> markOnboardingComplete() {
    return updateConfig(hasCompletedOnboarding: true);
  }

  Future<void> resetConfig() async {
    await _storageService.clearAll();
    _config = const AppConfiguration();
    PathResolver.setAppConfiguration(_config);
    notifyListeners();
  }

  List<String> _mergeRecentDirectories(
    List<String> existing,
    String? latest,
  ) {
    final merged = <String>[
      if (latest != null && latest.isNotEmpty) latest,
      ...existing.where((entry) => entry != latest && entry.isNotEmpty),
    ];
    return List<String>.unmodifiable(
      merged.take(_maxRecentDirectories).toList(),
    );
  }
}

const _sentinel = Object();
