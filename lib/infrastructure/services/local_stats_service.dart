import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:fpv_overlay_app/domain/models/local_overlay_stats.dart';

class LocalStatsService {
  static const _statsSnapshotKey = 'overlay_stats_snapshot';

  Future<OverlayStatsSnapshot> loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_statsSnapshotKey);
    if (raw == null || raw.isEmpty) {
      return const OverlayStatsSnapshot();
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return OverlayStatsSnapshot.fromJson(
        Map<String, Object?>.from(decoded),
      );
    } catch (_) {
      return const OverlayStatsSnapshot();
    }
  }

  Future<void> saveStats(OverlayStatsSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statsSnapshotKey, jsonEncode(snapshot.toJson()));
  }

  Future<void> clearStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_statsSnapshotKey);
  }
}
