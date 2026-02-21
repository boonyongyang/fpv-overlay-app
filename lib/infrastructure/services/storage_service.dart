import 'package:shared_preferences/shared_preferences.dart';
import 'package:fpv_overlay_app/domain/models/app_configuration.dart';

class StorageService {
  static const String _lastInputKey = 'last_input_dir';
  static const String _lastOutputKey = 'last_output_dir';
  static const String _defaultOutputKey = 'default_output_dir';

  Future<AppConfiguration> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return AppConfiguration(
      lastUsedInputDirectory: prefs.getString(_lastInputKey),
      lastUsedOutputDirectory: prefs.getString(_lastOutputKey),
      defaultOutputDirectory: prefs.getString(_defaultOutputKey),
    );
  }

  Future<void> saveConfig(AppConfiguration config) async {
    final prefs = await SharedPreferences.getInstance();

    if (config.lastUsedInputDirectory != null) {
      await prefs.setString(_lastInputKey, config.lastUsedInputDirectory!);
    }
    if (config.lastUsedOutputDirectory != null) {
      await prefs.setString(_lastOutputKey, config.lastUsedOutputDirectory!);
    }
    if (config.defaultOutputDirectory != null) {
      await prefs.setString(_defaultOutputKey, config.defaultOutputDirectory!);
    } else {
      await prefs.remove(_defaultOutputKey);
    }
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
