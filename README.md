# FPV Overlay Toolbox [![CI](https://github.com/boonyongyang/fpv-overlay-app/actions/workflows/ci.yml/badge.svg)](https://github.com/boonyongyang/fpv-overlay-app/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

FPV Overlay Toolbox is a Flutter desktop app for turning flight footage plus telemetry into finished FPV overlay videos on macOS and Windows.

It is built as a real utility first, and as a portfolio-quality Flutter desktop codebase second: queue-driven workflows, local-only diagnostics, platform-aware UX, and packaging/release automation all live in the same repo.

## Why This Exists

Most FPV overlay workflows are still fragmented:

- subtitle overlays are quick but visually limited
- full OSD overlays often depend on scripts or manual setup
- long DJI recordings complicate clip-to-telemetry matching
- sharing a working setup usually means walking someone through FFmpeg, Python, and asset dependencies by hand

FPV Overlay Toolbox wraps that into one desktop workflow with one queue, one diagnostics surface, and one product shell.

## What It Does

- fast subtitle overlays from `.srt`
- full graphical overlays from `.osd`
- combined `.osd` + `.srt` renders in one output
- DJI split-recording recovery where a later clip can reuse an earlier `.osd`
- overview-first queue management with clear-all actions and render activity views
- local diagnostics for FFmpeg, Python, output strategy, and bundled overlay assets
- desktop-native behavior including drag-and-drop, notifications, macOS dock progress, and Windows taskbar progress

## Install / Download

Release builds are published through [GitHub Releases](https://github.com/boonyongyang/fpv-overlay-app/releases).

### macOS

Download the latest `.dmg` from Releases, mount it, and drag the app to `/Applications`.

> **First launch:** The app is ad-hoc signed. macOS may show a Gatekeeper prompt on first open. Right-click the app → **Open** to bypass it. You only need to do this once.

### Windows

Download the latest `-setup.exe` from Releases and run it. Windows SmartScreen may show a warning on first run — click **More info → Run anyway**.

### CLI (macOS)

```bash
brew install boonyongyang/tap/fpv-overlay
```

Or download a `.tar.gz` archive directly from Releases.

### Run From Source

The repo pins Flutter with [`.fvmrc`](.fvmrc).

```bash
fvm flutter pub get
fvm flutter run -d macos
```

Useful local commands:

```bash
make pub-get
make bootstrap
make analyze
make test
make build-macos-release
make package-macos-runtime
make dmg
```

Windows packaging must be run on Windows:

```powershell
make build-windows-release
make package-windows-runtime
make windows-installer
```

## Supported Scope

- Public support target: desktop
- macOS: primary release path
- Windows: packaged installer path
- Linux: not currently a published target
- Mobile folders may exist in the tree, but the public product focus is desktop

## Workflow

1. Add mixed video and telemetry files, or scan a folder.
2. The matching engine pairs files by stem and keeps incomplete tasks visible instead of discarding them.
3. If a later DJI split clip has no exact `.osd`, the queue can reuse the nearest preceding `.osd`.
4. Review queue items, start the batch render, and open the render activity view only when deeper execution detail is needed.
5. Copy a diagnostics report at any point if the environment or a specific task needs investigation.

## Architecture

The repo uses a layered Flutter desktop structure:

- `presentation/` for the desktop shell, onboarding, command palette, activity views, and navigation
- `application/` for queue state, settings state, navigation state, and workspace actions
- `domain/` for task models, failure parsing, and render command contracts
- `infrastructure/` for matching, persistence, subprocess orchestration, and platform services

See [ARCHITECTURE.md](ARCHITECTURE.md) for the deeper system breakdown, queue lifecycle, render pipeline, and release surfaces.

## Privacy / Local-Only Posture

FPV Overlay Toolbox processes local files on the local machine.

- media files are not uploaded during normal app use
- local stats remain on-device
- diagnostics reports are copied manually by the user when needed
- the public repo does not include Firebase analytics or crash-reporting configuration

See [PRIVACY.md](PRIVACY.md) for the explicit privacy statement.

## Samples And Regression Media

The source repo intentionally does **not** commit the raw DJI sample media.

- sample metadata lives in [samples/manifest.json](samples/manifest.json)
- usage notes live in [samples/README.md](samples/README.md)
- raw regression inputs should be distributed through GitHub release assets or another lightweight download path

The canonical sample pack includes:

- `DJIG0024.mp4`
- `DJIG0024.osd`
- `DJIG0024.srt`
- `DJIG0025.mp4`
- `DJIG0025.srt`

That pack exercises the split-recording case where clip `25` reuses the earlier `.osd` timeline.

## Maintainer Docs

- architecture guide: [ARCHITECTURE.md](ARCHITECTURE.md)
- release checklist: [docs/github_release_checklist.md](docs/github_release_checklist.md)
- maintainer release checklist: [docs/maintainer_release_checklist.md](docs/maintainer_release_checklist.md)
- macOS app update notes: [docs/macos_app_updates.md](docs/macos_app_updates.md)
- unified release workflow: [.github/workflows/release.yml](.github/workflows/release.yml)
- CLI release notes: [docs/cli_release.md](docs/cli_release.md)
- third-party notices: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)

## Contributing

Start with:

- [CONTRIBUTING.md](CONTRIBUTING.md)
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- [ARCHITECTURE.md](ARCHITECTURE.md)

The most useful contribution areas right now are queue workflow improvements, better diagnostics, media-path edge cases, and packaging polish.

## Credits / Upstream References

- The OSD layout and rendering behavior were informed by the upstream [`wtfos-configurator` `osd-overlay`](https://github.com/fpv-wtf/wtfos-configurator/tree/master/src/osd-overlay) implementation.
- `OsdFileReader.py` is derived from the [O3_OverlayTool project](https://github.com/xNuclearSquirrel/O3_OverlayTool/releases).

See [assets/bin/README.md](assets/bin/README.md) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for the current provenance notes.

## License

MIT

See [LICENSE](LICENSE).
