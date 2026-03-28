# Auto-Release Pipeline & In-App Updater Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate three overlapping release workflows into one unified `release.yml`, and add a non-intrusive in-app update checker that shows a dismissible banner when a newer version is available on GitHub.

**Architecture:** `UpdateService` (domain interface) → `HttpUpdateService` (infrastructure, fetches `latest-macos.json`) → `UpdateProvider` (ChangeNotifier, checks on startup) → `UpdateBanner` widget (thin strip, Consumer). CI/CD: a `validate` job gates four parallel build jobs; a `publish` job collects artifacts and creates the GitHub release once.

**Tech Stack:** Flutter, Provider/ChangeNotifier, `package_info_plus`, `http`, `url_launcher`, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-03-27-auto-release-updater-design.md`

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Add | `lib/domain/models/update_info.dart` | Plain data class: version, releaseUrl, publishedAt |
| Add | `lib/domain/services/update_service.dart` | Abstract interface: `checkForUpdate(String) → Future<UpdateInfo?>` |
| Add | `lib/infrastructure/services/http_update_service.dart` | Fetches manifest, parses JSON, compares semver, silent-fails |
| Add | `lib/application/providers/update_provider.dart` | ChangeNotifier: checks on startup, exposes hasUpdate + dismiss() |
| Add | `lib/presentation/widgets/update_banner.dart` | Dismissible 40px strip, Consumer<UpdateProvider> |
| Add | `test/infrastructure/services/http_update_service_test.dart` | Unit tests: newer/same/older/404/error |
| Add | `test/application/providers/update_provider_test.dart` | Unit tests: initial state, update found, dismiss, error |
| Add | `test/presentation/widgets/update_banner_test.dart` | Widget tests: hidden/visible/dismiss |
| Add | `.github/workflows/release.yml` | Unified release: validate → 4 parallel builds → publish |
| Modify | `pubspec.yaml` | Add package_info_plus, http, url_launcher |
| Modify | `lib/main.dart` | Register UpdateService + UpdateProvider; insert UpdateBanner |
| Delete | `.github/workflows/macos-app-updates.yml` | Replaced by release.yml |
| Delete | `.github/workflows/desktop-release.yml` | Replaced by release.yml |
| Delete | `.github/workflows/cli-release.yml` | Replaced by release.yml |

---

## Task 1: Add pubspec dependencies

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add three packages to pubspec.yaml**

In `pubspec.yaml`, after the `uuid: ^4.5.2` line (inside `dependencies:`), add:

```yaml
  package_info_plus: ^8.0.0
  http: ^1.2.0
  url_launcher: ^6.3.0
```

The dependencies block should look like:
```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  provider: ^6.1.5+1
  file_selector: ^1.0.3
  path: ^1.9.0
  shared_preferences: ^2.5.3
  desktop_drop: ^0.5.0
  local_notifier: ^0.1.6
  macos_dock_progress: ^1.1.0
  app_badge_plus: ^1.2.6
  file: ^7.0.1
  windows_taskbar: ^1.1.2
  uuid: ^4.5.2
  package_info_plus: ^8.0.0
  http: ^1.2.0
  url_launcher: ^6.3.0
  overlay_core:
    path: packages/overlay_core
```

- [ ] **Step 2: Install dependencies**

```bash
fvm flutter pub get
```

Expected: `Got dependencies!` with no errors.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add package_info_plus, http, url_launcher dependencies"
```

---

## Task 2: Domain model and service interface

**Files:**
- Create: `lib/domain/models/update_info.dart`
- Create: `lib/domain/services/update_service.dart`

No tests needed — plain data class and abstract interface have no logic to test.

- [ ] **Step 1: Create UpdateInfo model**

```dart
// lib/domain/models/update_info.dart
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.releaseUrl,
    required this.publishedAt,
  });

  final String version;
  final String releaseUrl;
  final String publishedAt;
}
```

- [ ] **Step 2: Create UpdateService interface**

```dart
// lib/domain/services/update_service.dart
import 'package:fpv_overlay_app/domain/models/update_info.dart';

abstract class UpdateService {
  Future<UpdateInfo?> checkForUpdate(String currentVersion);
}
```

- [ ] **Step 3: Verify analyzer passes**

```bash
fvm flutter analyze lib/domain/models/update_info.dart lib/domain/services/update_service.dart
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/domain/models/update_info.dart lib/domain/services/update_service.dart
git commit -m "feat: add UpdateInfo model and UpdateService interface"
```

---

## Task 3: HttpUpdateService (TDD)

**Files:**
- Create: `lib/infrastructure/services/http_update_service.dart`
- Create: `test/infrastructure/services/http_update_service_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
// test/infrastructure/services/http_update_service_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fpv_overlay_app/infrastructure/services/http_update_service.dart';

void main() {
  group('HttpUpdateService', () {
    http.Response _manifest(String version) => http.Response(
          jsonEncode({
            'version': version,
            'release_url':
                'https://github.com/example/releases/tag/v$version',
            'published_at': '2026-03-27T00:00:00Z',
          }),
          200,
        );

    test('returns UpdateInfo when remote version is newer', () async {
      final client = MockClient((_) async => _manifest('1.1.0'));
      final service = HttpUpdateService(client: client);
      final result = await service.checkForUpdate('1.0.0');
      expect(result, isNotNull);
      expect(result!.version, '1.1.0');
      expect(result.releaseUrl, contains('v1.1.0'));
      expect(result.publishedAt, '2026-03-27T00:00:00Z');
    });

    test('returns null when remote version equals current', () async {
      final client = MockClient((_) async => _manifest('1.0.0'));
      final service = HttpUpdateService(client: client);
      final result = await service.checkForUpdate('1.0.0');
      expect(result, isNull);
    });

    test('returns null when remote version is older', () async {
      final client = MockClient((_) async => _manifest('0.9.0'));
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
      final client =
          MockClient((_) async => http.Response('not json', 200));
      final service = HttpUpdateService(client: client);
      final result = await service.checkForUpdate('1.0.0');
      expect(result, isNull);
    });

    test('detects minor version bump as newer', () async {
      final client = MockClient((_) async => _manifest('1.2.0'));
      final service = HttpUpdateService(client: client);
      final result = await service.checkForUpdate('1.1.5');
      expect(result, isNotNull);
      expect(result!.version, '1.2.0');
    });

    test('detects major version bump as newer', () async {
      final client = MockClient((_) async => _manifest('2.0.0'));
      final service = HttpUpdateService(client: client);
      final result = await service.checkForUpdate('1.9.9');
      expect(result, isNotNull);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
fvm flutter test test/infrastructure/services/http_update_service_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: 'package:fpv_overlay_app/infrastructure/services/http_update_service.dart'`

- [ ] **Step 3: Implement HttpUpdateService**

```dart
// lib/infrastructure/services/http_update_service.dart
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

  static List<int> _parse(String version) => List.generate(
        3,
        (i) {
          final parts = version.split('.');
          return i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0;
        },
      );
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
fvm flutter test test/infrastructure/services/http_update_service_test.dart
```

Expected: All 8 tests PASS. (Note: tests that exercise the HTTP path will pass because MockClient bypasses `Platform.isMacOS`. The platform guard is exercised in integration context.)

- [ ] **Step 5: Commit**

```bash
git add lib/infrastructure/services/http_update_service.dart \
        test/infrastructure/services/http_update_service_test.dart
git commit -m "feat: add HttpUpdateService with semver comparison"
```

---

## Task 4: UpdateProvider (TDD)

**Files:**
- Create: `lib/application/providers/update_provider.dart`
- Create: `test/application/providers/update_provider_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
// test/application/providers/update_provider_test.dart
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
fvm flutter test test/application/providers/update_provider_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: 'package:fpv_overlay_app/application/providers/update_provider.dart'`

- [ ] **Step 3: Implement UpdateProvider**

```dart
// lib/application/providers/update_provider.dart
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
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
fvm flutter test test/application/providers/update_provider_test.dart
```

Expected: All 8 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/application/providers/update_provider.dart \
        test/application/providers/update_provider_test.dart
git commit -m "feat: add UpdateProvider with startup update check"
```

---

## Task 5: UpdateBanner widget

**Files:**
- Create: `lib/presentation/widgets/update_banner.dart`
- Create: `test/presentation/widgets/update_banner_test.dart`

- [ ] **Step 1: Write the failing widget tests**

```dart
// test/presentation/widgets/update_banner_test.dart
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
);

Widget _wrap(UpdateProvider provider) => ChangeNotifierProvider<UpdateProvider>.value(
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
fvm flutter test test/presentation/widgets/update_banner_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: 'package:fpv_overlay_app/presentation/widgets/update_banner.dart'`

- [ ] **Step 3: Implement UpdateBanner**

```dart
// lib/presentation/widgets/update_banner.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fpv_overlay_app/application/providers/update_provider.dart';

class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final updateProvider = context.watch<UpdateProvider>();
    if (!updateProvider.hasUpdate) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final info = updateProvider.availableUpdate!;

    return Container(
      height: 40,
      color: theme.colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(
            Icons.system_update_rounded,
            size: 14,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Text(
            'v${info.version} available',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => unawaited(
              launchUrl(
                Uri.parse(info.releaseUrl),
                mode: LaunchMode.externalApplication,
              ),
            ),
            child: Text(
              'View release',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline,
                decorationColor: theme.colorScheme.primary,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 14),
            onPressed: () => context.read<UpdateProvider>().dismiss(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
fvm flutter test test/presentation/widgets/update_banner_test.dart
```

Expected: All 3 tests PASS.

- [ ] **Step 5: Run the full test suite**

```bash
fvm flutter test
```

Expected: All tests pass with no regressions.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/widgets/update_banner.dart \
        test/presentation/widgets/update_banner_test.dart
git commit -m "feat: add UpdateBanner widget"
```

---

## Task 6: Wire into the app

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Add imports to main.dart**

At the top of `lib/main.dart`, after the existing imports (after `onboarding_overlay.dart`), add:

```dart
import 'package:fpv_overlay_app/application/providers/update_provider.dart';
import 'package:fpv_overlay_app/domain/services/update_service.dart';
import 'package:fpv_overlay_app/infrastructure/services/http_update_service.dart';
import 'package:fpv_overlay_app/presentation/widgets/update_banner.dart';
```

- [ ] **Step 2: Register UpdateService and UpdateProvider in MultiProvider**

In `_AppProviders.build`, the `providers` list currently ends with:
```dart
ChangeNotifierProvider(create: (_) => WorkspaceProvider()),
```

Replace that closing bracket of the list with:
```dart
        ChangeNotifierProvider(create: (_) => WorkspaceProvider()),
        Provider<UpdateService>(create: (_) => HttpUpdateService()),
        ChangeNotifierProvider(
          create: (context) => UpdateProvider(
            updateService: context.read<UpdateService>(),
          ),
        ),
```

- [ ] **Step 3: Insert UpdateBanner in the main scaffold**

In `_MainScreenState.build`, find the `Expanded` widget that wraps the `ColoredBox` (around line 188):

```dart
          Expanded(
            child: ColoredBox(
              color: theme.colorScheme.surface,
              child: IndexedStack(
                index: selectedIndex,
                children: const [
                  TaskQueuePage(),
                  SettingsPage(),
                  HelpPage(),
                ],
              ),
            ),
          ),
```

Replace it with:

```dart
          Expanded(
            child: Column(
              children: [
                const UpdateBanner(),
                Expanded(
                  child: ColoredBox(
                    color: theme.colorScheme.surface,
                    child: IndexedStack(
                      index: selectedIndex,
                      children: const [
                        TaskQueuePage(),
                        SettingsPage(),
                        HelpPage(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
```

- [ ] **Step 4: Verify the app analyzes cleanly**

```bash
fvm flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 5: Run tests**

```bash
fvm flutter test
```

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart
git commit -m "feat: wire UpdateProvider and UpdateBanner into app"
```

---

## Task 7: Unified release.yml + delete old workflows

**Files:**
- Create: `.github/workflows/release.yml`
- Delete: `.github/workflows/macos-app-updates.yml`
- Delete: `.github/workflows/desktop-release.yml`
- Delete: `.github/workflows/cli-release.yml`

No automated tests for GitHub Actions — validated by running the workflow on a real tag push.

- [ ] **Step 1: Create `.github/workflows/release.yml`**

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:
    inputs:
      release_tag:
        description: 'Existing git tag to build and publish (e.g. v1.0.0)'
        required: true
        type: string

# ---------------------------------------------------------------------------
# validate — resolves the tag, checks out the repo, verifies version metadata
# ---------------------------------------------------------------------------
jobs:
  validate:
    name: Validate release metadata
    runs-on: ubuntu-latest
    outputs:
      tag: ${{ steps.meta.outputs.tag }}
      version: ${{ steps.meta.outputs.version }}
      ref: ${{ steps.meta.outputs.ref }}

    steps:
      - name: Resolve tag and version
        id: meta
        shell: bash
        run: |
          if [[ "$GITHUB_EVENT_NAME" == "workflow_dispatch" ]]; then
            TAG="${{ inputs.release_tag }}"
          else
            TAG="$GITHUB_REF_NAME"
          fi
          if [[ ! "$TAG" =~ ^v[0-9] ]]; then
            echo "Invalid tag format '$TAG' — expected v<semver>" >&2
            exit 1
          fi
          VERSION="${TAG#v}"
          echo "tag=$TAG"         >> "$GITHUB_OUTPUT"
          echo "version=$VERSION" >> "$GITHUB_OUTPUT"
          echo "ref=refs/tags/$TAG" >> "$GITHUB_OUTPUT"

      - name: Checkout
        uses: actions/checkout@v4
        with:
          ref: ${{ steps.meta.outputs.ref }}
          fetch-depth: 0

      - name: Validate pubspec version matches tag
        shell: bash
        run: |
          PUBSPEC_VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f1)"
          if [[ "$PUBSPEC_VERSION" != "${{ steps.meta.outputs.version }}" ]]; then
            echo "pubspec.yaml version ($PUBSPEC_VERSION) does not match tag (${{ steps.meta.outputs.version }})" >&2
            exit 1
          fi

      - name: Validate CLI release metadata
        shell: bash
        run: |
          chmod +x tools/verify_cli_release_metadata.sh
          tools/verify_cli_release_metadata.sh --tag "${{ steps.meta.outputs.tag }}"

  # ---------------------------------------------------------------------------
  # build-macos — Flutter macOS DMG
  # ---------------------------------------------------------------------------
  build-macos:
    name: Build macOS DMG
    needs: validate
    runs-on: macos-14
    outputs:
      sha256: ${{ steps.checksum.outputs.sha256 }}
      artifact_name: ${{ steps.artifact.outputs.artifact_name }}
      checksum_name: ${{ steps.artifact.outputs.checksum_name }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          ref: ${{ needs.validate.outputs.ref }}

      - name: Set artifact names
        id: artifact
        shell: bash
        run: |
          ARTIFACT_NAME="fpv-overlay-toolbox-macos-${{ needs.validate.outputs.version }}.dmg"
          CHECKSUM_NAME="${ARTIFACT_NAME}.sha256"
          echo "artifact_name=$ARTIFACT_NAME" >> "$GITHUB_OUTPUT"
          echo "checksum_name=$CHECKSUM_NAME"  >> "$GITHUB_OUTPUT"

      - name: Setup FVM
        uses: leoafarias/fvm-action@v1
        with:
          cache: true

      - name: Install Flutter dependencies
        run: fvm flutter pub get

      - name: Ensure CocoaPods is available
        run: |
          if ! command -v pod >/dev/null 2>&1; then
            sudo gem install cocoapods
          fi

      - name: Install macOS pods
        run: cd macos && pod install

      - name: Prepare build scripts
        run: |
          chmod +x \
            tools/build_macos_overlay_runtime.sh \
            tools/prepare_macos_app_runtime.sh \
            tools/create_dmg.sh

      - name: Build macOS app
        run: fvm flutter build macos --release

      - name: Package DMG
        run: tools/create_dmg.sh

      - name: Compute checksum
        id: checksum
        shell: bash
        run: |
          DMG="dist/${{ steps.artifact.outputs.artifact_name }}"
          if [[ ! -f "$DMG" ]]; then
            echo "Expected DMG not found: $DMG" >&2; exit 1
          fi
          SHA256="$(shasum -a 256 "$DMG" | awk '{print $1}')"
          printf '%s  %s\n' "$SHA256" "${{ steps.artifact.outputs.artifact_name }}" \
            > "dist/${{ steps.artifact.outputs.checksum_name }}"
          echo "sha256=$SHA256" >> "$GITHUB_OUTPUT"

      - name: Upload macOS artifacts
        uses: actions/upload-artifact@v4
        with:
          name: macos-dmg
          path: |
            dist/${{ steps.artifact.outputs.artifact_name }}
            dist/${{ steps.artifact.outputs.checksum_name }}
          if-no-files-found: error
          retention-days: 1

  # ---------------------------------------------------------------------------
  # build-windows — Flutter Windows installer
  # ---------------------------------------------------------------------------
  build-windows:
    name: Build Windows installer
    needs: validate
    runs-on: windows-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          ref: ${{ needs.validate.outputs.ref }}

      - name: Setup FVM
        uses: leoafarias/fvm-action@v1
        with:
          cache: true

      - name: Install Flutter dependencies
        run: fvm flutter pub get

      - name: Install Inno Setup
        run: choco install innosetup --no-progress -y

      - name: Build Windows app
        run: fvm flutter build windows --release

      - name: Package Windows installer
        shell: pwsh
        run: .\tools\create_windows_installer.ps1

      - name: Upload Windows artifact
        uses: actions/upload-artifact@v4
        with:
          name: windows-installer
          path: dist/windows/*-setup.exe
          if-no-files-found: error
          retention-days: 1

  # ---------------------------------------------------------------------------
  # build-cli-arm64 / build-cli-x64 — CLI archives
  # ---------------------------------------------------------------------------
  build-cli-arm64:
    name: Build CLI (macOS arm64)
    needs: validate
    runs-on: macos-14
    outputs:
      sha256: ${{ steps.checksum.outputs.sha256 }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          ref: ${{ needs.validate.outputs.ref }}

      - name: Setup FVM
        uses: leoafarias/fvm-action@v1
        with:
          cache: true

      - name: Prepare build scripts
        run: |
          chmod +x \
            tools/build_macos_overlay_runtime.sh \
            tools/build_cli_runtime_macos.sh \
            tools/build_cli_release_macos.sh \
            tools/render_homebrew_formula.sh \
            tools/verify_cli_release_metadata.sh

      - name: Build CLI release archive
        run: make build-cli-release-macos

      - name: Compute checksum
        id: checksum
        shell: bash
        run: |
          ARCHIVE="$(ls build/cli-release/*.tar.gz | head -1)"
          SHA256="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"
          ARTIFACT="$(basename "$ARCHIVE")"
          printf '%s  %s\n' "$SHA256" "$ARTIFACT" \
            > "build/cli-release/${ARTIFACT%.tar.gz}.sha256"
          echo "sha256=$SHA256" >> "$GITHUB_OUTPUT"

      - name: Upload CLI arm64 artifacts
        uses: actions/upload-artifact@v4
        with:
          name: cli-arm64
          path: |
            build/cli-release/*.tar.gz
            build/cli-release/*.sha256
          if-no-files-found: error
          retention-days: 1

  build-cli-x64:
    name: Build CLI (macOS x64)
    needs: validate
    runs-on: macos-13
    outputs:
      sha256: ${{ steps.checksum.outputs.sha256 }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          ref: ${{ needs.validate.outputs.ref }}

      - name: Setup FVM
        uses: leoafarias/fvm-action@v1
        with:
          cache: true

      - name: Prepare build scripts
        run: |
          chmod +x \
            tools/build_macos_overlay_runtime.sh \
            tools/build_cli_runtime_macos.sh \
            tools/build_cli_release_macos.sh \
            tools/render_homebrew_formula.sh \
            tools/verify_cli_release_metadata.sh

      - name: Build CLI release archive
        run: make build-cli-release-macos

      - name: Compute checksum
        id: checksum
        shell: bash
        run: |
          ARCHIVE="$(ls build/cli-release/*.tar.gz | head -1)"
          SHA256="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"
          ARTIFACT="$(basename "$ARCHIVE")"
          printf '%s  %s\n' "$SHA256" "$ARTIFACT" \
            > "build/cli-release/${ARTIFACT%.tar.gz}.sha256"
          echo "sha256=$SHA256" >> "$GITHUB_OUTPUT"

      - name: Upload CLI x64 artifacts
        uses: actions/upload-artifact@v4
        with:
          name: cli-x64
          path: |
            build/cli-release/*.tar.gz
            build/cli-release/*.sha256
          if-no-files-found: error
          retention-days: 1

  # ---------------------------------------------------------------------------
  # publish — creates the GitHub release and uploads all assets
  # ---------------------------------------------------------------------------
  publish:
    name: Publish release
    needs:
      - validate
      - build-macos
      - build-windows
      - build-cli-arm64
      - build-cli-x64
    runs-on: ubuntu-latest
    permissions:
      contents: write

    env:
      TAG: ${{ needs.validate.outputs.tag }}
      VERSION: ${{ needs.validate.outputs.version }}
      MACOS_SHA256: ${{ needs.build-macos.outputs.sha256 }}
      ARM64_SHA256: ${{ needs.build-cli-arm64.outputs.sha256 }}
      X64_SHA256: ${{ needs.build-cli-x64.outputs.sha256 }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          ref: ${{ needs.validate.outputs.ref }}

      - name: Download all build artifacts
        uses: actions/download-artifact@v4
        with:
          path: build/release-assets

      - name: Create GitHub release (if not already exists)
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          if gh release view "$TAG" >/dev/null 2>&1; then
            echo "Release $TAG already exists — skipping create."
          else
            gh release create "$TAG" \
              --verify-tag \
              --title "$TAG" \
              --generate-notes
          fi

      - name: Upload all build artifacts to release
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          shopt -s globstar nullglob
          gh release upload "$TAG" \
            build/release-assets/macos-dmg/*.dmg \
            build/release-assets/macos-dmg/*.sha256 \
            build/release-assets/windows-installer/*.exe \
            build/release-assets/cli-arm64/*.tar.gz \
            build/release-assets/cli-arm64/*.sha256 \
            build/release-assets/cli-x64/*.tar.gz \
            build/release-assets/cli-x64/*.sha256 \
            --clobber

      - name: Render macOS update manifest
        run: |
          chmod +x tools/render_macos_update_manifest.sh
          MACOS_DMG="$(ls build/release-assets/macos-dmg/*.dmg | head -1)"
          ARTIFACT_NAME="$(basename "$MACOS_DMG")"
          tools/render_macos_update_manifest.sh \
            --output build/release-assets/latest-macos.json \
            --repository "${GITHUB_REPOSITORY}" \
            --release-tag "$TAG" \
            --version "$VERSION" \
            --artifact-name "$ARTIFACT_NAME" \
            --sha256 "$MACOS_SHA256" \
            --published-at "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

      - name: Render Homebrew formula
        run: |
          chmod +x tools/render_homebrew_formula.sh
          tools/render_homebrew_formula.sh \
            --tag "$TAG" \
            --version "$VERSION" \
            --arm64-sha "$ARM64_SHA256" \
            --x64-sha "$X64_SHA256" \
            --output build/release-assets/fpv-overlay.rb

      - name: Upload manifest and Homebrew formula to release
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh release upload "$TAG" \
            build/release-assets/latest-macos.json \
            build/release-assets/fpv-overlay.rb \
            --clobber
```

- [ ] **Step 2: Delete the three old workflow files**

```bash
git rm .github/workflows/macos-app-updates.yml \
       .github/workflows/desktop-release.yml \
       .github/workflows/cli-release.yml
```

- [ ] **Step 3: Verify the new workflow file is valid YAML**

```bash
python3 -c "import yaml, sys; yaml.safe_load(open('.github/workflows/release.yml'))" && echo "YAML OK"
```

Expected: `YAML OK`

- [ ] **Step 4: Run the full test suite one final time**

```bash
make check
```

Expected: Analyzer + all tests pass.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: consolidate release workflows into unified release.yml"
```

---

## How to trigger a release

When code is ready to ship:

```bash
# 1. Bump version in both places (must match)
#    - pubspec.yaml:     version: 1.0.1+2
#    - cli/pubspec.yaml: version: 1.0.1

# 2. Verify versions are consistent
make verify-cli-release-metadata

# 3. Tag and push — this triggers release.yml automatically
git tag -a v1.0.1 -m "v1.0.1"
git push origin v1.0.1
```

GitHub Actions will then: validate → build macOS DMG + Windows installer + CLI arm64 + CLI x64 → publish release with all artifacts + `latest-macos.json` + Homebrew formula.
