import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:fpv_overlay_app/domain/models/update_info.dart';
import 'package:fpv_overlay_app/domain/services/update_service.dart';

class UpdateProvider extends ChangeNotifier {
  UpdateProvider({
    required UpdateService updateService,
    String? currentVersion,
  })  : _updateService = updateService,
        _currentVersion = currentVersion {
    unawaited(refresh());
  }

  final UpdateService _updateService;

  /// Injected in tests to bypass [PackageInfo.fromPlatform].
  final String? _currentVersion;

  UpdateInfo? _availableUpdate;

  UpdateInfo? get availableUpdate => _availableUpdate;
  bool get hasUpdate => _availableUpdate != null;

  void dismiss() {
    if (_availableUpdate == null) return;
    _availableUpdate = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      final version =
          _currentVersion ?? (await PackageInfo.fromPlatform()).version;
      final update = await _updateService.checkForUpdate(version);
      if (update == null) return;
      _availableUpdate = update;
      notifyListeners();
    } catch (_) {
      // silently absorb all errors — update check must never crash the app
    }
  }
}
