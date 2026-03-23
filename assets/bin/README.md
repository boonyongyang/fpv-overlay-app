# Overlay Runtime Assets

This directory contains the Python overlay scripts and font assets used by the desktop app.

## Contents

| Item | Purpose |
|---|---|
| `osd_overlay.py` | Two-pass OSD HD rendering compositor |
| `srt_overlay.py` | SRT subtitle overlay script |
| `OsdFileReader.py` | Binary OSD file parser (imported by `osd_overlay.py`) |
| `fonts/` | 28 OSD font sprite sheets (BetaFlight, INAV, DJI OG) |
| `ffmpeg`, `ffprobe` | Bundled into the macOS release app under `Contents/Resources/runtime/` |

## How it works

`PathResolver` in `lib/core/utils/path_resolver.dart` locates these files at runtime:

- **Production (macOS .app):** Resolves to Flutter's app-bundle asset path under `App.framework/.../flutter_assets/assets/bin/`.
- **Production (Windows .exe):** Resolves to `data/flutter_assets/assets/bin/` next to the executable.
- **Development (`flutter run`):** Falls back to this source-tree directory (`assets/bin/`). FFmpeg and Python are resolved from bundled binaries when present, otherwise from the system PATH / Homebrew.

## Build packaging

The scripts and font sheets committed here are bundled automatically via Flutter's asset pipeline.

The repository does not commit third-party runtime binaries, but the macOS release packaging flow now downloads static `ffmpeg`/`ffprobe` archives and freezes the Python overlays into standalone executables before building the DMG.
