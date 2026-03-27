# Auto-Release Pipeline & In-App Updater Design

**Date:** 2026-03-27
**Status:** Approved

## Goals

1. Eliminate manual build/upload steps — pushing a `v*` tag is the only manual action required to ship a release.
2. Consolidate three overlapping release workflows into one, removing a duplicate DMG build and a three-way race condition on GitHub release creation.
3. Add a non-intrusive in-app update checker that notifies users when a new version is available without blocking them or requiring an in-app download.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Release trigger | Manual `v*` tag | Keeps developer control over when something ships; avoids every commit becoming a release |
| Scope | Desktop + CLI unified | Both wrap `overlay_core`; they change together; one tag, one release |
| Updater UX | Silent startup check + dismissible banner | Non-intrusive; no in-app download logic needed; fits existing `latest-macos.json` manifest |
| Platform scope for updater | macOS only | Windows has its own installer update flow; Linux not targeted |
| Version sourcing | `package_info_plus` | Reads from compiled bundle — `pubspec.yaml` is the single source of truth, no manual sync |

---

## Part 1: CI/CD Consolidation

### Workflow Changes

**Delete:**
- `.github/workflows/macos-app-updates.yml`
- `.github/workflows/desktop-release.yml`
- `.github/workflows/cli-release.yml`

**Keep unchanged:**
- `.github/workflows/ci.yml` — analyze + test on push to main / PR to main

**Add:**
- `.github/workflows/release.yml`

### `release.yml` Structure

**Trigger:** `push` to tags matching `v*`, plus `workflow_dispatch` (manual re-run with a tag input).

**Job graph:**

```
build-macos    (macos-14)         ─┐
build-windows  (windows-latest)   ─┤──→ publish (ubuntu-latest)
build-cli-arm64 (macos-14)        ─┤
build-cli-x64  (macos-13)         ─┘
```

All four build jobs run in parallel. `publish` has `needs` on all four.

### Build Job Responsibilities

Each build job:
1. Checks out the repo at the tag ref
2. Builds its artifact (DMG / Windows installer / CLI archive)
3. Computes SHA256 of the artifact
4. Writes `sha256` and `artifact_name` to `GITHUB_OUTPUT`
5. Uploads artifact via `actions/upload-artifact@v4`

**`build-macos`** — uses `leoafarias/fvm-action`, installs pods, runs `fvm flutter build macos --release`, packages DMG via `tools/create_dmg.sh`.

**`build-windows`** — uses FVM, installs Inno Setup, runs `fvm flutter build windows --release`, packages installer via `tools/create_windows_installer.ps1`.

**`build-cli-arm64` / `build-cli-x64`** — uses FVM, runs `make build-cli-release-macos`, outputs archive + SHA256.

### `publish` Job Responsibilities

1. **Validate** tag format (`v*`) and that pubspec version matches the tag — single validation point, not repeated across jobs.
2. **Download** all four artifacts via `actions/download-artifact@v4`.
3. **Create GitHub release** once via `gh release create` — no race condition.
4. **Upload** all release assets: DMG + `.sha256`, Windows installer, CLI archives + `.sha256` files.
5. **Render `latest-macos.json`** via `tools/render_macos_update_manifest.sh` using `needs.build-macos.outputs.sha256`.
6. **Render Homebrew formula** via `tools/render_homebrew_formula.sh` using CLI SHA256 outputs.
7. **Upload** `latest-macos.json` and `fpv-overlay.rb` to the release.

### What This Fixes

| Problem today | Fixed by |
|---------------|----------|
| macOS DMG built twice (in `macos-app-updates` and `desktop-release`) | Single `build-macos` job |
| Three workflows all call `gh release create` simultaneously | Single `publish` job creates release |
| Version validation duplicated across workflows | Single check in `publish` |
| Three files to maintain | One `release.yml` |

---

## Part 2: In-App Updater

### Version Sourcing

Replace the hardcoded `AppIdentity.version = '1.0.0'` with `package_info_plus`. The `UpdateProvider` calls `PackageInfo.fromPlatform()` once on init to get the running version from the compiled bundle.

**Dependencies to add to `pubspec.yaml`:**
- `package_info_plus: ^8.0.0` — reads version from compiled bundle
- `http: ^1.2.0` — used by `HttpUpdateService` to fetch the manifest
- `url_launcher: ^6.3.0` — opens the GitHub releases page in the browser

### New Files

#### `lib/domain/models/update_info.dart`
```
UpdateInfo {
  final String version       // e.g. "1.2.0"
  final String releaseUrl    // GitHub release page URL
  final String publishedAt   // ISO 8601 string
}
```
Plain Dart class, no Flutter dependency.

#### `lib/domain/services/update_service.dart`
```
abstract class UpdateService {
  Future<UpdateInfo?> checkForUpdate(String currentVersion);
}
```
Returns `UpdateInfo` if a newer version is available, `null` if up-to-date or on any error.

#### `lib/infrastructure/services/http_update_service.dart`
Implements `UpdateService`. Behaviour:
- Fetches `https://github.com/boonyongyang/fpv-overlay-app/releases/latest/download/latest-macos.json`
- Parses JSON into `UpdateInfo`
- Compares semver: if `fetched.version > currentVersion` → return `UpdateInfo`; else `null`
- On any exception (network, timeout, parse error, non-200 response) → return `null` silently
- macOS only: on other platforms returns `null` immediately without making a request

#### `lib/application/providers/update_provider.dart`
Extends `ChangeNotifier`. Injected via `MultiProvider` at root.

State:
- `UpdateInfo? availableUpdate` — non-null means an update is ready to advertise
- `bool hasUpdate` → `availableUpdate != null`

Methods:
- Constructor calls `_checkOnStartup()` fire-and-forget
- `void dismiss()` — sets `availableUpdate = null`, notifies listeners (session-only; update reappears on next launch)

#### `lib/presentation/widgets/update_banner.dart`
`Consumer<UpdateProvider>` widget. Returns `SizedBox.shrink()` when `!hasUpdate`.

When visible: a thin ~40px strip at the top of the main content area (above the task queue), containing:
- Label: `"v{version} available"`
- Tappable link: `"View release"` — opens `availableUpdate.releaseUrl` via `url_launcher`
- `✕` icon button → calls `updateProvider.dismiss()`

`url_launcher` and `http` are listed above under Version Sourcing.

### Wiring

**`lib/main.dart` / root `MultiProvider`:**
```dart
ChangeNotifierProvider(
  create: (_) => UpdateProvider(updateService: sl<UpdateService>()),
),
```

**`UpdateBanner` placement:** Inserted above the task queue widget in the main scaffold, below the toolbar/title bar.

### Error Handling

All network errors are caught inside `HttpUpdateService` — `UpdateProvider` never sees an exception. If the check fails, `hasUpdate` stays `false` and the user sees nothing. The update check must never affect app startup time in a visible way (fires asynchronously, does not block the UI).

---

## File Change Summary

| Action | File |
|--------|------|
| Delete | `.github/workflows/macos-app-updates.yml` |
| Delete | `.github/workflows/desktop-release.yml` |
| Delete | `.github/workflows/cli-release.yml` |
| Add | `.github/workflows/release.yml` |
| Add | `lib/domain/models/update_info.dart` |
| Add | `lib/domain/services/update_service.dart` |
| Add | `lib/infrastructure/services/http_update_service.dart` |
| Add | `lib/application/providers/update_provider.dart` |
| Add | `lib/presentation/widgets/update_banner.dart` |
| Modify | `lib/core/constants/app_identity.dart` — remove `version` constant |
| Modify | `pubspec.yaml` — add `package_info_plus`, `http`, `url_launcher` |
| Modify | `lib/main.dart` — register `UpdateService` + `UpdateProvider` |
| Modify | Main scaffold widget — insert `UpdateBanner` above task queue |

## Out of Scope

- Auto-download or in-app installation of updates
- Windows update manifest / in-app updater (Windows uses its own installer)
- CLI update checker
- Beta / release channels
- Persisting dismissal across sessions
