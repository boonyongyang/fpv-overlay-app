import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fpv_overlay_app/infrastructure/services/http_update_service.dart';

void main() {
  group('HttpUpdateService', () {
    http.Response manifest(String version) => http.Response(
          jsonEncode({
            'version': version,
            'release_url': 'https://github.com/example/releases/tag/v$version',
            'published_at': '2026-03-27T00:00:00Z',
          }),
          200,
        );

    test('returns UpdateInfo when remote version is newer', () async {
      final client = MockClient((_) async => manifest('1.1.0'));
      final service = HttpUpdateService(client: client);
      final result = await service.checkForUpdate('1.0.0');
      expect(result, isNotNull);
      expect(result!.version, '1.1.0');
      expect(result.releaseUrl, contains('v1.1.0'));
      expect(result.publishedAt, '2026-03-27T00:00:00Z');
    });

    test('returns null when remote version equals current', () async {
      final client = MockClient((_) async => manifest('1.0.0'));
      final service = HttpUpdateService(client: client);
      final result = await service.checkForUpdate('1.0.0');
      expect(result, isNull);
    });

    test('returns null when remote version is older', () async {
      final client = MockClient((_) async => manifest('0.9.0'));
      final service = HttpUpdateService(client: client);
      final result = await service.checkForUpdate('1.0.0');
      expect(result, isNull);
    });

    test('returns null on non-200 response', () async {
      final client = MockClient((_) async => http.Response('Not Found', 404));
      final service = HttpUpdateService(client: client);
      final result = await service.checkForUpdate('1.0.0');
      expect(result, isNull);
    });

    test('returns null on network error', () async {
      final client =
          MockClient((_) async => throw const SocketException('no network'));
      final service = HttpUpdateService(client: client);
      final result = await service.checkForUpdate('1.0.0');
      expect(result, isNull);
    });

    test('returns null on malformed JSON', () async {
      final client = MockClient((_) async => http.Response('not json', 200));
      final service = HttpUpdateService(client: client);
      final result = await service.checkForUpdate('1.0.0');
      expect(result, isNull);
    });

    test('detects minor version bump as newer', () async {
      final client = MockClient((_) async => manifest('1.2.0'));
      final service = HttpUpdateService(client: client);
      final result = await service.checkForUpdate('1.1.5');
      expect(result, isNotNull);
      expect(result!.version, '1.2.0');
    });

    test('detects major version bump as newer', () async {
      final client = MockClient((_) async => manifest('2.0.0'));
      final service = HttpUpdateService(client: client);
      final result = await service.checkForUpdate('1.9.9');
      expect(result, isNotNull);
    });

    test('detects patch version bump as newer', () async {
      final client = MockClient((_) async => manifest('1.0.1'));
      final service = HttpUpdateService(client: client);
      final result = await service.checkForUpdate('1.0.0');
      expect(result, isNotNull);
      expect(result!.version, '1.0.1');
    });
  });
}
