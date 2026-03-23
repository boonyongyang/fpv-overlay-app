# Overlay Runtime Assets

This directory contains the production renderer sources used by the desktop app.

## What Lives Here

| Item | Role |
|---|---|
| `osd_overlay.py` | Full OSD compositor for `.osd` overlays, with optional SRT telemetry on the same render pass |
| `srt_overlay.py` | Subtitle-driven telemetry overlay path for `.srt` only workflows |
| `OsdFileReader.py` | Bundled OSD parser imported by `osd_overlay.py` |
| `fonts/` | Bundled OSD font sprite sheets used by the renderer |

Release builds bundle `ffmpeg` and `ffprobe` separately under the platform runtime directory:

- macOS: `Contents/Resources/runtime/`
- Windows: `runtime\`

## Provenance

The renderer in this repo is not a verbatim copy of one upstream source.

- The OSD layout and render behavior were informed by the upstream [`wtfos-configurator` `osd-overlay`](https://github.com/fpv-wtf/wtfos-configurator/tree/master/src/osd-overlay) implementation.
- `OsdFileReader.py` is a bundled parser derived from the [O3_OverlayTool project](https://github.com/xNuclearSquirrel/O3_OverlayTool/releases).

The scripts here adapt those ideas into the runtime model used by FPV Overlay Toolbox: command-line entrypoints, bundled fonts, split-segment handling, and packaged desktop releases.

## Runtime Resolution

`PathResolver` in `lib/core/utils/path_resolver.dart` resolves assets and runtimes like this:

- **Release app bundles:** prefer the embedded runtime and embedded overlay executables
- **Flutter asset bundle:** load renderer sources from `assets/bin/`
- **Development fallback:** use the source tree and local machine runtimes when no bundled runtime exists

## Packaging Notes

The scripts and font sheets committed here are shipped via Flutter assets.

The repo does not commit third-party runtime binaries. Instead, the packaging scripts download FFmpeg archives and freeze the Python entrypoints into standalone executables during macOS and Windows release packaging.

See `THIRD_PARTY_NOTICES.md` at the repo root for the current public-source
summary of provenance and redistribution follow-up items.
