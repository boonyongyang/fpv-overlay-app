import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:fpv_overlay_app/application/providers/update_provider.dart';
import 'package:fpv_overlay_app/domain/models/update_info.dart';
import 'package:fpv_overlay_app/domain/services/update_service.dart';
import 'package:fpv_overlay_app/presentation/widgets/update_banner.dart';

class MockUpdateService extends Mock implements UpdateService {}

const _info = UpdateInfo(
  version: '1.1.0',
  releaseUrl: 'https://github.com/example/releases/tag/v1.1.0',
  publishedAt: '2026-03-27T00:00:00Z',
  artifactUrl:
      'https://github.com/example/releases/download/v1.1.0/fpv-overlay-toolbox-macos-1.1.0.dmg',
  sha256: 'abc123',
);

Widget _wrap(UpdateProvider provider) =>
    ChangeNotifierProvider<UpdateProvider>.value(
      value: provider,
      child: const MaterialApp(
        home: Material(child: UpdateBanner()),
      ),
    );

UpdateProvider _providerWithNoUpdate() {
  final service = MockUpdateService();
  when(() => service.checkForUpdate(any())).thenAnswer((_) async => null);
  return UpdateProvider(updateService: service, currentVersion: '1.0.0');
}

Future<UpdateProvider> _providerWithUpdate() async {
  final service = MockUpdateService();
  when(() => service.checkForUpdate(any())).thenAnswer((_) async => _info);
  final provider =
      UpdateProvider(updateService: service, currentVersion: '1.0.0');
  await provider.refresh();
  return provider;
}

void main() {
  testWidgets('renders nothing when no update is available', (tester) async {
    await tester.pumpWidget(_wrap(_providerWithNoUpdate()));
    await tester.pump();
    expect(find.text('v1.1.0 available'), findsNothing);
    expect(find.text('View release'), findsNothing);
  });

  testWidgets('shows version and link when update is available',
      (tester) async {
    final provider = await _providerWithUpdate();
    await tester.pumpWidget(_wrap(provider));
    await tester.pump();
    expect(find.text('v1.1.0 available'), findsOneWidget);
    expect(find.text('View release'), findsOneWidget);
  });

  testWidgets('tapping dismiss hides the banner', (tester) async {
    final provider = await _providerWithUpdate();
    await tester.pumpWidget(_wrap(provider));
    await tester.pump();
    expect(find.text('v1.1.0 available'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(find.text('v1.1.0 available'), findsNothing);
  });
}
