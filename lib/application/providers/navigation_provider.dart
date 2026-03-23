import 'package:flutter/foundation.dart';
import 'package:fpv_overlay_app/domain/services/telemetry.dart';

class NavigationProvider extends ChangeNotifier {
  static const _tabNames = ['overlay_queue', 'system_info', 'help'];

  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void setTab(int index) {
    if (index == _currentIndex) return;
    _currentIndex = index;
    Telemetry.switchedTab(index, _tabNames.elementAtOrNull(index) ?? 'unknown');
    notifyListeners();
  }
}
