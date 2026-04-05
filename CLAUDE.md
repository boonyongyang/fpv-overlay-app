# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FPV Overlay Toolbox is a **Flutter desktop app** that turns FPV flight footage + telemetry into finished overlay videos. It wraps OSD/SRT overlay rendering (Python + FFmpeg) into a queue-based desktop product targeting macOS and Windows.

## Commands

This project uses [FVM](https://fvm.app/) to pin the Flutter version (see `.fvmrc`). Prefix `flutter` commands with `fvm`.

```bash
make bootstrap        # Install Flutter deps + CocoaPods (first time setup)
make check            # Run analyzer + tests (canonical CI gate)
make format           # dart format lib test
make analyze          # fvm flutter analyze
make test             # fvm flutter test
make runtime-check    # Verify ffmpeg and python3 are available

# Run locally
fvm flutter run -d macos

# Single test file
fvm flutter test test/application/providers/task_queue_provider_test.dart

# macOS builds
make build-macos-debug
make build-macos-release
```

## Architecture

**Layered Clean Architecture** with Provider + ChangeNotifier for state management.

```
presentation/   ← Pages, widgets, command palette, responsive layout
application/    ← ChangeNotifier providers (state management)
domain/         ← Models, interfaces, business logic (no Flutter deps)
infrastructure/ ← Platform implementations, subprocess orchestration
core/           ← Shared utils (PathResolver, PlatformUtils)
```

### Key Abstractions

**OverlayCommand** (`lib/domain/commands/overlay_command.dart`) — interface for rendering. Implementations in `lib/infrastructure/commands/`:
- `OsdOverlayCommand` — OSD binary telemetry overlay
- `SrtOverlayCommand` — SRT subtitle overlay
- `CombinedOverlayCommand` — smart dispatcher (OSD+SRT in one pass, or either alone)

All commands use `ProcessRunnerMixin` to stream subprocess output line-by-line via `Stream<String>`.

**EngineService** (`lib/infrastructure/services/engine_service.dart`) — file pair discovery. Matches videos with telemetry by stem (filename without extension). Handles DJI split-recording (e.g., DJIG0078.mp4 → falls back to DJIG0077.osd if no exact match).

**CommandRunnerService** (`lib/infrastructure/services/command_runner_service.dart`) — selects the correct `OverlayCommand` based on `task.type` and streams output back.

**PathResolver** (`lib/core/utils/path_resolver.dart`) — resolves paths for bundled assets (Python scripts, fonts, ffmpeg) across macOS .app bundles, Windows, and dev environments.

**TaskFailureParser** (`lib/domain/services/task_failure_parser.dart`) — classifies subprocess log output into structured `TaskFailure` with error code, summary, and actionable suggestion.

### State Management

`MultiProvider` at root with constructor-injected services:
- **Services** (singletons): `StorageService`, `LocalStatsService`, `EngineService`, `CommandRunnerService`, `OsService` (platform-specific)
- **ChangeNotifiers**: `TaskQueueProvider`, `SettingsProvider`, `NavigationProvider`, `LocalStatsProvider`, `WorkspaceProvider`

`TaskQueueProvider` is the core — holds `List<OverlayTask>`, handles file matching/merging, DJI split-recording fallback, and batch processing orchestration.

`WorkspaceProvider` manages transient UI state: queue search text, status/type filters, sort mode, command palette visibility, and first-run onboarding visibility.

`LocalStatsProvider` tracks persistent render stats (completed/failed/cancelled counts, recent run history capped at 50) backed by `LocalStatsService` via SharedPreferences.

### Platform Services

`OsService` interface with platform implementations:
- `MacOSOsService` — badge, dock progress, notifications
- `WindowsOsService` — taskbar progress
- `PlaceholderOsService` — no-op fallback

### Runtime Requirements

The app invokes Python scripts bundled in `assets/bin/` (`osd_overlay.py`, `srt_overlay.py`). In release builds, precompiled binaries may replace these. Runtime needs: **FFmpeg** and **Python 3** (with numpy, Pillow, pandas).

### Sample Media

Sample media (`DJIG0024.*`, `DJIG0025.*`) is **not committed** to the repo — `.gitignore` excludes `samples/*.mp4`, `samples/*.osd`, `samples/*.srt`. Metadata lives in `samples/manifest.json`; raw files are distributed via GitHub release assets.

## Code Style

Analysis options enforce:
- `strict-casts: true`, `strict-raw-types: true`
- Single quotes, always-declare-return-types, prefer-const-constructors
- `avoid_print` — use structured logging or task logs instead
- Trailing commas required

## Testing

Tests use `mocktail` for mocking. Test files mirror the `lib/` structure under `test/`.

Key test files:
- `test/application/providers/task_queue_provider_test.dart`
- `test/infrastructure/services/engine_service_test.dart`
- `test/domain/task_failure_parser_test.dart`

## Release Procedure

Follow this checklist **every time** a new version is released. Do not skip steps.

### Step 1 — Pre-release checks (automated)

```bash
make check           # analyzer + all tests must pass
dart format --output=none --set-exit-if-changed lib test cli/lib cli/bin packages/overlay_core/lib packages/overlay_core/test
chmod +x tools/verify_cli_release_metadata.sh && tools/verify_cli_release_metadata.sh --tag vX.Y.Z
```

### Step 2 — Version bump (when bumping versions)

- `pubspec.yaml` → `version: X.Y.Z+BUILD`
- `cli/pubspec.yaml` → `version: X.Y.Z`
- `cli/lib/src/app.dart` → `defaultValue: 'X.Y.Z'`
- All three must match the release tag base version

### Step 3 — Commit and push

```bash
git add -p   # stage only what belongs to the release
git commit -m "chore: release vX.Y.Z"
git push origin main
```

### Step 4 — Build local macOS DMG

```bash
make release   # runs: check → build → package-macos-runtime → dmg
# Outputs: dist/fpv-overlay-toolbox-macos-X.Y.Z.dmg
```

Update `dist/` by replacing the old DMG. The new DMG is the local install artifact.

### Step 5 — Tag and push (triggers CI release workflow)

```bash
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin vX.Y.Z
```

This triggers `.github/workflows/release.yml` which:
- Builds macOS DMG + Windows EXE + CLI arm64/x64
- Creates the GitHub release
- Uploads all artifacts + `latest-macos.json` + Homebrew formula

### Step 6 — Verify GitHub Actions

```bash
gh run list --limit 5   # confirm release workflow is running/passed
gh release view vX.Y.Z  # confirm all artifacts uploaded
```

### Step 7 — Update checklists

Mark completed items in:
- `docs/github_release_checklist.md`
- `docs/maintainer_release_checklist.md`

### Human-only tasks (cannot be automated)

- Test the DMG on a clean machine
- Test the Windows EXE on a Windows machine
- Add/update README screenshots in `docs/screenshots/`
