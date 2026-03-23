# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FPV Overlay Toolbox is a **Flutter desktop app** that turns FPV flight footage + telemetry into finished overlay videos. It wraps OSD/SRT overlay rendering (Python + FFmpeg) into a queue-based desktop product targeting macOS and Windows.

## Commands

This project uses [FVM](https://fvm.app/) to pin the Flutter version (see `.fvmrc`). Prefix `flutter` commands with `fvm`.

```bash
make bootstrap        # Install Flutter deps + CocoaPods (first time setup)
make check            # Run analyzer + tests (CI target)
make format           # dart format lib test
make analyze          # fvm flutter analyze
make test             # fvm flutter test
make runtime-check    # Verify ffmpeg and python3 are available

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

### Platform Services

`OsService` interface with platform implementations:
- `MacOSOsService` — badge, dock progress, notifications
- `WindowsOsService` — taskbar progress
- `PlaceholderOsService` — no-op fallback

### Runtime Requirements

The app invokes Python scripts bundled in `assets/bin/` (`osd_overlay.py`, `srt_overlay.py`). In release builds, precompiled binaries may replace these. Runtime needs: **FFmpeg** and **Python 3** (with numpy, Pillow, pandas).

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
