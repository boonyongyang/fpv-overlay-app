import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:fpv_overlay_app/domain/models/update_info.dart';
import 'package:fpv_overlay_app/domain/services/update_service.dart';

class HttpUpdateService implements UpdateService {
  HttpUpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _manifestUrl =
      'https://github.com/boonyongyang/fpv-overlay-app'
      '/releases/latest/download/latest-macos.json';

  @override
  Future<UpdateInfo?> checkForUpdate(String currentVersion) async {
    if (!Platform.isMacOS) return null;
    try {
      final response = await _client
          .get(Uri.parse(_manifestUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final remoteVersion = json['version'] as String;
      final releaseUrl = json['release_url'] as String;
      final publishedAt = json['published_at'] as String;
      if (!_isNewer(remoteVersion, currentVersion)) return null;
      return UpdateInfo(
        version: remoteVersion,
        releaseUrl: releaseUrl,
        publishedAt: publishedAt,
      );
    } catch (_) {
      return null;
    }
  }

  static bool _isNewer(String remote, String current) {
    final r = _parse(remote);
    final c = _parse(current);
    for (var i = 0; i < 3; i++) {
      if (r[i] > c[i]) return true;
      if (r[i] < c[i]) return false;
    }
    return false;
  }

  static List<int> _parse(String version) {
    final parts = version.split('.');
    return List.generate(
      3,
      (i) => i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0,
    );
  }
}
