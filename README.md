# FPV Overlay Toolbox

A cross-platform desktop application built with Flutter for FPV pilots who want to burn telemetry overlays (`.srt` / `.osd`) onto their flight videos, with bundled overlay assets and a self-contained macOS release pipeline.

---

## Features

- **SRT Fast Overlay** — burn DJI-style subtitle telemetry into video via FFmpeg. No re-encode of the video stream; just a fast subtitle burn-in.
- **OSD HD Rendering** — two-pass Python+FFmpeg pipeline that reconstructs the full graphical OSD (gauges, attitude indicator, voltage, etc.) from a `.osd` binary log and composites it onto the video in HD quality.
- **Combined OSD + SRT** — when both `.osd` and `.srt` are present for the same clip, both are composited onto a single output in one pass.
- **Batch Queue** — drag-and-drop or scan entire folders; the engine auto-pairs video files with matching telemetry by filename stem.
- **Smart Pairing** — orphaned files (video without telemetry, or telemetry without video) are held in the queue and can be linked individually later.
- **Bundled Overlay Assets** — rendering scripts (`osd_overlay.py`, `srt_overlay.py`), `OsdFileReader.py`, and 28 OSD font sprite sheets ship with the app.
- **Self-Contained macOS Builds** — release packaging bundles standalone overlay executables plus `ffmpeg`/`ffprobe` into the `.app`, so end users do not need Homebrew or a local Python setup.
- **Smart Runtime Resolution** — the app prefers bundled runtimes when present, otherwise auto-detects FFmpeg and Python from standard system locations during development.
- **Desktop-native UX** — macOS dock badge & progress bar, Windows taskbar progress, system notifications, and drag-and-drop.
- **Privacy-first analytics** — Firebase Analytics + Crashlytics with a one-tap opt-out in the System Info tab.

---

## Installation

Download the latest release for your platform:

| Platform | Format |
|---|---|
| **macOS** | `.dmg` — drag to Applications and run |
| **Windows** | `.exe` installer |

> macOS release builds package the required overlay runtime into the app. Source builds still auto-detect dependencies from the host system.

---

## File Types Supported

| Extension | Format | Overlay mode |
|---|---|---|
| `.mp4`, `.mov` | Source video | — |
| `.srt` | DJI / Walksnail subtitle telemetry | SRT Fast |
| `.osd` | Betaflight / INAV / DJI binary OSD log | OSD HD Rendering |
| `.osd` + `.srt` | Both present for same clip | Combined (single output) |

---

## Architecture

The project follows a layered architecture with clear separation of concerns:

```
lib/
├── main.dart                  # App entry point & provider wiring
├── firebase_options.dart      # Auto-generated Firebase config
│
├── application/               # App-level state (ChangeNotifiers)
│   └── providers/
│       ├── firebase_provider.dart
│       ├── navigation_provider.dart
│       ├── settings_provider.dart
│       └── task_queue_provider.dart
│
├── core/                      # Cross-cutting utilities
│   └── utils/
│       ├── path_resolver.dart     # Dynamic FFmpeg/Python/script detection
│       └── platform_utils.dart    # Cross-platform shell helpers
│
├── domain/                    # Pure Dart: models, abstractions, contracts
│   ├── commands/
│   │   └── overlay_command.dart   # Abstract command interface
│   ├── models/
│   │   ├── app_configuration.dart
│   │   ├── overlay_task.dart      # Task model with status & overlay type enums
│   │   └── task_addition_result.dart
│   └── services/
│       ├── os_service.dart        # Abstract platform service
│       └── telemetry.dart         # Fire-and-forget analytics facade
│
├── infrastructure/            # Concrete implementations
│   ├── commands/
│   │   ├── combined_overlay_command.dart
│   │   ├── osd_overlay_command.dart
│   │   ├── process_runner_mixin.dart  # Shared subprocess streaming
│   │   └── srt_overlay_command.dart
│   └── services/
│       ├── command_runner_service.dart
│       ├── engine_service.dart        # File-pair matching logic
│       ├── macos_os_service.dart
│       ├── picker_service.dart
│       ├── placeholder_os_service.dart
│       ├── storage_service.dart       # SharedPreferences wrapper
│       ├── windows_os_service.dart
│       └── firebase/
│           ├── analytics_service.dart
│           ├── crashlytics_service.dart
│           └── firebase_initializer.dart
│
└── presentation/              # Flutter UI
    ├── navigation/
    │   └── firebase_route_observer.dart
    ├── pages/
    │   ├── help_page.dart
    │   ├── settings_page.dart
    │   └── task_queue_page.dart
    └── widgets/
        ├── fpv_logo.dart              # Custom-painted drone icon
        ├── navigation/
        │   └── app_sidebar.dart
        └── task_queue/
            ├── action_bars.dart
            ├── dashboard_stats_row.dart
            ├── empty_state_view.dart
            ├── performance_insights_card.dart
            ├── snack_bar_helpers.dart
            └── task_card.dart
```

### Key design decisions

- **Provider** for state management — lightweight and idiomatic for desktop.
- **Command pattern** — `OverlayCommand` decouples the UI from specific FFmpeg/Python invocations. Three concrete implementations: `SrtOverlayCommand`, `OsdOverlayCommand`, `CombinedOverlayCommand`.
- **`ProcessRunnerMixin`** — shared subprocess streaming logic eliminates duplication between overlay commands.
- **`OsService` abstraction** — `MacOSOsService`, `WindowsOsService`, and `PlaceholderOsService` keep platform-specific code (dock badge, taskbar progress, notifications) isolated from business logic.
- **`Telemetry` facade** — fire-and-forget analytics calls that silently no-op when disabled, so business-logic tests stay clean without mocking Firebase.
- **`PathResolver`** — resolves bundled overlay assets plus bundled-or-system FFmpeg/Python at runtime, with a development fallback to `assets/bin/`.

---

## Testing

```bash
flutter test
```

| Test file | Coverage |
|---|---|
| `test/domain/telemetry_test.dart` | Telemetry facade method signatures |
| `test/infrastructure/services/engine_service_test.dart` | File-pair matching with `MemoryFileSystem` |
| `test/application/providers/task_queue_provider_test.dart` | Task CRUD and queue state management |
| `test/integration/task_telemetry_test.dart` | End-to-end task lifecycle → analytics wiring |

---

## Getting Started (development)

```bash
# 1. Clone
git clone https://github.com/YangBo17/fpv-overlay-app.git
cd fpv-overlay-app

# 2. Install Flutter dependencies
flutter pub get

# 3. Run on macOS
flutter run -d macos
```

> **Developer note:** When running from source, the app auto-detects FFmpeg and Python from standard Homebrew install locations. You will need `ffmpeg` and `python3` with `numpy`, `pillow`, and `pandas` installed on your system for overlay processing to work.

## Release Packaging

The shortest release path is:

```bash
make release
```

That flow bootstraps Flutter dependencies, installs CocoaPods with the required UTF-8 locale, runs analysis and tests, builds the macOS app, bundles the overlay runtime into the `.app`, and creates a drag-to-Applications DMG in `dist/`.

If you want to run the steps individually:

```bash
make bootstrap
make check
make build-macos-release
make package-macos-runtime
make dmg
```

`make dmg` also prepares the bundled runtime automatically before packaging. If you need a custom app bundle path or version label:

```bash
./tools/create_dmg.sh "/path/to/FPV Overlay Toolbox.app" 1.0.0
```

The packaging scripts ad-hoc sign the local `.app` after embedding the runtime so it remains launchable. For public release-quality distribution, you should still codesign and notarize the `.app` and `.dmg` with your Apple Developer account before uploading to GitHub Releases.

### Samples

The repository includes a real split-segment regression case in [`samples/`](./samples):

- `DJIG0024.mp4/.osd/.srt`
- `DJIG0025.mp4/.srt`

This is useful for validating the long-recording DJI behavior where clip `25` reuses clip `24`'s single `.osd` file.

### Project utilities (not part of the Flutter app runtime)

The `tools/` directory contains standalone dev scripts:

| Script | Purpose |
|---|---|
| `tools/batch-overlay-unified.py` | Legacy CLI reference script for quick local experiments |
| `tools/build_macos_overlay_runtime.sh` | Builds standalone macOS overlay executables from the Python scripts with PyInstaller |
| `tools/prepare_macos_app_runtime.sh` | Bundles the overlay executables plus `ffmpeg`/`ffprobe` into the release `.app` |
| `tools/create_dmg.sh` | Packages the release `.app` into a DMG and prepares the bundled runtime first |
| `tools/generate_app_icons.py` | Generates app icon PNGs at various sizes |
| `tools/fpv-overlay` | Shell wrapper for the legacy batch processor |

> The published desktop app uses the production overlay pipeline in `assets/bin/`, not the legacy batch helper above.

---

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you'd like to change.

---

## License

MIT
