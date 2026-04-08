import 'package:shared_preferences/shared_preferences.dart';
import 'package:fpv_overlay_app/domain/models/app_configuration.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';

class StorageService {
  static const String _taskQueueKey = 'task_queue';
  static const String _lastInputKey = 'last_input_dir';
  static const String _lastOutputKey = 'last_output_dir';
  static const String _defaultOutputKey = 'default_output_dir';
  static const String _o3OverlayToolPathKey = 'o3_overlay_tool_path';
  static const String _hasCompletedOnboardingKey = 'has_completed_onboarding';
  static const String _recentInputDirsKey = 'recent_input_dirs';
  static const String _recentOutputDirsKey = 'recent_output_dirs';

  Future<AppConfiguration> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return AppConfiguration(
      lastUsedInputDirectory: prefs.getString(_lastInputKey),
      lastUsedOutputDirectory: prefs.getString(_lastOutputKey),
      defaultOutputDirectory: prefs.getString(_defaultOutputKey),
      o3OverlayToolPath: prefs.getString(_o3OverlayToolPathKey),
      hasCompletedOnboarding:
          prefs.getBool(_hasCompletedOnboardingKey) ?? false,
      recentInputDirectories: List.unmodifiable(
        prefs.getStringList(_recentInputDirsKey) ?? const [],
      ),
      recentOutputDirectories: List.unmodifiable(
        prefs.getStringList(_recentOutputDirsKey) ?? const [],
      ),
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
    if (config.o3OverlayToolPath != null) {
      await prefs.setString(_o3OverlayToolPathKey, config.o3OverlayToolPath!);
    } else {
      await prefs.remove(_o3OverlayToolPathKey);
    }
    await prefs.setBool(
      _hasCompletedOnboardingKey,
      config.hasCompletedOnboarding,
    );
    await prefs.setStringList(
      _recentInputDirsKey,
      config.recentInputDirectories,
    );
    await prefs.setStringList(
      _recentOutputDirsKey,
      config.recentOutputDirectories,
    );
  }

  Future<List<OverlayTask>?> loadTaskQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_taskQueueKey);
    if (raw == null) return null;
    try {
      return OverlayTask.listFromJson(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTaskQueue(List<OverlayTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_taskQueueKey, OverlayTask.listToJson(tasks));
  }

  Future<void> clearTaskQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_taskQueueKey);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_taskQueueKey);
    await prefs.remove(_lastInputKey);
    await prefs.remove(_lastOutputKey);
    await prefs.remove(_defaultOutputKey);
    await prefs.remove(_o3OverlayToolPathKey);
    await prefs.remove(_hasCompletedOnboardingKey);
    await prefs.remove(_recentInputDirsKey);
    await prefs.remove(_recentOutputDirsKey);
  }
}
