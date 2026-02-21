import 'package:flutter/foundation.dart';
import 'package:fpv_overlay_app/domain/models/app_configuration.dart';
import 'package:fpv_overlay_app/infrastructure/services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
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
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateConfig({
    String? lastUsedInputDirectory,
    String? lastUsedOutputDirectory,
    String? defaultOutputDirectory,
  }) async {
    _config = _config.copyWith(
      lastUsedInputDirectory: lastUsedInputDirectory,
      lastUsedOutputDirectory: lastUsedOutputDirectory,
      defaultOutputDirectory: defaultOutputDirectory,
    );
    notifyListeners();
    await _storageService.saveConfig(_config);
  }

  Future<void> resetConfig() async {
    await _storageService.clearAll();
    _config = const AppConfiguration();
    notifyListeners();
  }
}
