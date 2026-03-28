import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fpv_overlay_app/application/providers/update_provider.dart';
import 'package:fpv_overlay_app/domain/models/update_info.dart';
import 'package:fpv_overlay_app/domain/services/update_service.dart';

class MockUpdateService extends Mock implements UpdateService {}

const _info = UpdateInfo(
  version: '1.1.0',
  releaseUrl: 'https://github.com/example/releases/tag/v1.1.0',
  publishedAt: '2026-03-27T00:00:00Z',
);

void main() {
  late MockUpdateService mockService;
  late UpdateProvider provider;

  setUp(() {
    mockService = MockUpdateService();
    when(() => mockService.checkForUpdate(any()))
        .thenAnswer((_) async => null);
    // currentVersion injected to bypass PackageInfo.fromPlatform()
    provider = UpdateProvider(
      updateService: mockService,
      currentVersion: '1.0.0',
    );
  });

  test('hasUpdate is false initially before check completes', () {
    expect(provider.hasUpdate, isFalse);
    expect(provider.availableUpdate, isNull);
  });

  test('hasUpdate becomes true after refresh finds update', () async {
    when(() => mockService.checkForUpdate('1.0.0'))
        .thenAnswer((_) async => _info);
    await provider.refresh();
    expect(provider.hasUpdate, isTrue);
    expect(provider.availableUpdate!.version, '1.1.0');
  });

  test('hasUpdate stays false when no update available', () async {
    when(() => mockService.checkForUpdate('1.0.0'))
        .thenAnswer((_) async => null);
    await provider.refresh();
    expect(provider.hasUpdate, isFalse);
  });

  test('dismiss clears the available update', () async {
    when(() => mockService.checkForUpdate('1.0.0'))
        .thenAnswer((_) async => _info);
    await provider.refresh();
    expect(provider.hasUpdate, isTrue);
    provider.dismiss();
    expect(provider.hasUpdate, isFalse);
    expect(provider.availableUpdate, isNull);
  });

  test('dismiss is a no-op when no update is present', () {
    expect(() => provider.dismiss(), returnsNormally);
    expect(provider.hasUpdate, isFalse);
  });

  test('service exceptions are caught silently', () async {
    when(() => mockService.checkForUpdate(any()))
        .thenThrow(Exception('network error'));
    await expectLater(provider.refresh(), completes);
    expect(provider.hasUpdate, isFalse);
  });

  test('notifies listeners when update is found', () async {
    when(() => mockService.checkForUpdate('1.0.0'))
        .thenAnswer((_) async => _info);
    var notified = false;
    provider.addListener(() => notified = true);
    await provider.refresh();
    expect(notified, isTrue);
  });

  test('notifies listeners on dismiss', () async {
    when(() => mockService.checkForUpdate('1.0.0'))
        .thenAnswer((_) async => _info);
    await provider.refresh();
    var notified = false;
    provider.addListener(() => notified = true);
    provider.dismiss();
    expect(notified, isTrue);
  });
}
