# FPV Overlay Toolbox

FPV Overlay Toolbox is a Flutter desktop app for turning flight footage plus telemetry into finished FPV overlay videos.

It supports:

- fast subtitle overlays from `.srt`
- full graphical overlays from `.osd`
- combined `.osd` + `.srt` renders in one output
- DJI split-recording flows where a later clip reuses the earlier segment's `.osd`

The project is published as a source-first open-source desktop app. The main value is the utility itself, and the codebase is intentionally structured to also showcase professional Flutter desktop product work: layered app architecture, queue state management, diagnostics, packaging scripts, and platform-aware UX.

## Desktop UX Highlights

- **Command palette** with `Cmd/Ctrl + K` for queue actions, navigation, diagnostics, and the workflow tour
- **Controllable queue workspace** with search, status filters, overlay-type filters, and sort modes
- **Focused task log view** for renderer output, failure traces, and copyable diagnostics
- **First-run onboarding** plus a reusable workflow tour
- **Local runtime diagnostics** for FFmpeg, Python, output strategy, and overlay assets
- **Desktop-native behavior** including drag-and-drop, notifications, macOS dock progress, and Windows taskbar progress

## What Problem It Solves

Most FPV overlay workflows are still fragmented:

- subtitle overlays are quick but visually limited
- full OSD overlays are often tied to scripts or one-off tooling
- long DJI recordings complicate clip-to-telemetry matching
- sharing a working setup usually means explaining FFmpeg, Python, and asset dependencies by hand

FPV Overlay Toolbox wraps that into a desktop workflow with one queue, one diagnostics surface, and one product shell.

## How The Workflow Works

1. Add mixed video and telemetry files, or scan a folder.
2. The matching engine pairs files by stem and keeps incomplete tasks visible instead of discarding them.
3. If a later DJI split clip has no exact `.osd`, the queue can reuse the nearest preceding `.osd`.
4. Review queue items, open task logs when needed, then start the batch render.
5. Copy a diagnostics report at any point if the environment or a specific task needs investigation.

## Architecture At A Glance

The repo keeps a clear layered structure:

- `presentation/` for the desktop UI, onboarding, command palette, and task log views
- `application/` for ChangeNotifier-driven workspace, settings, navigation, and queue state
- `domain/` for task models, failure classification, and command interfaces
- `infrastructure/` for file matching, storage, platform services, and subprocess orchestration

Key implementation decisions:

- **Flutter owns the desktop product shell**  
  Queue UX, diagnostics, state transitions, onboarding, and desktop presentation are all handled in Flutter.

- **Renderer logic stays isolated**  
  Python + FFmpeg are still the right fit for the OSD rendering path, but they live behind command abstractions so the UI layer stays clean.

- **Source-first local product posture**  
  Overlay stats, queue diagnostics, and media processing remain local to the device. This repo does not ship analytics or cloud reporting.

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

That pack exercises the important split-recording case where clip `25` reuses the earlier `.osd` timeline.

## Development

The repo pins Flutter with [`.fvmrc`](.fvmrc).

Install dependencies:

```bash
fvm flutter pub get
```

Run the app locally:

```bash
fvm flutter run -d macos
```

Useful commands:

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

## Packaging Scripts

The repo includes desktop packaging scripts and runtime bundling helpers, including:

- [tools/prepare_macos_app_runtime.sh](tools/prepare_macos_app_runtime.sh)
- [tools/create_dmg.sh](tools/create_dmg.sh)
- [tools/build_windows_overlay_runtime.ps1](tools/build_windows_overlay_runtime.ps1)
- [tools/prepare_windows_release.ps1](tools/prepare_windows_release.ps1)
- [tools/create_windows_installer.ps1](tools/create_windows_installer.ps1)

This public pass focuses on a strong source codebase and desktop product UX. Packaging scripts are included, but this README does not claim fully validated public release artifacts.

## Contributing

Start with:

- [CONTRIBUTING.md](CONTRIBUTING.md)
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)

The most useful contribution areas right now are queue workflow improvements, better diagnostics, media-path edge cases, and packaging polish.

## Credits / Upstream References

- The OSD layout and rendering behavior were informed by the upstream [`wtfos-configurator` `osd-overlay`](https://github.com/fpv-wtf/wtfos-configurator/tree/master/src/osd-overlay) implementation.
- `OsdFileReader.py` is derived from the [O3_OverlayTool project](https://github.com/xNuclearSquirrel/O3_OverlayTool/releases).

See [assets/bin/README.md](assets/bin/README.md) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for the current provenance notes.

## License

MIT

See [LICENSE](LICENSE).
