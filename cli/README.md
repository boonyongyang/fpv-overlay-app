# CLI Plan

This folder is the planned home for a standalone command-line distribution of FPV Overlay Toolbox.

The goal is not to create a second renderer. The goal is to expose the same local render engine through a terminal-first product that users can install with Homebrew.

## Final Recommendation

Build a standalone Dart CLI that reuses the current renderer runtime and shared headless logic.

Do not:

- reimplement the renderer in Dart
- ship a Python-only CLI that expects users to manage `numpy` / `pandas` / `Pillow`
- keep the CLI logic inside Flutter-only providers
- make the CLI depend on the desktop app bundle layout

Do:

- extract reusable non-UI logic into a pure Dart shared package
- keep `osd_overlay.py` and `srt_overlay.py` as the rendering source of truth
- continue packaging `ffmpeg`, `ffprobe`, and frozen overlay executables for release builds
- install the CLI through a custom Homebrew tap backed by GitHub release artifacts

## Product Goal

Primary user story:

```bash
brew install boonyongyang/tap/fpv-overlay
fpv-overlay render --video clip.mp4 --srt clip.srt --osd clip.osd
```

Supported render modes must stay aligned with the desktop app:

- video + SRT
- video + OSD
- video + OSD + SRT
- folder batch matching by filename stem
- DJI split-segment fallback where a later video reuses the nearest earlier `.osd`

## Current Codebase Reality

The desktop app is already split more cleanly than a normal Flutter app:

- Flutter owns the product shell, queue UI, settings UI, notifications, and persistence.
- Dart already owns file pairing, task state, subprocess orchestration, output naming, and some progress parsing.
- Python + FFmpeg own the actual render pipeline.

Important detail: not all headless logic is currently in `EngineService`.

Headless behavior currently lives in multiple places:

- `lib/infrastructure/services/engine_service.dart`
  file matching and direct `.osd` fallback during initial scan
- `lib/application/providers/task_queue_provider.dart`
  merge behavior, orphan resolution, additional `.osd` auto-attachment, output naming, queue execution, and progress parsing
- `lib/infrastructure/services/command_runner_service.dart`
  render dispatch
- `lib/infrastructure/commands/*.dart`
  child process command construction
- `lib/core/utils/path_resolver.dart`
  runtime discovery
- `lib/domain/services/task_failure_parser.dart`
  failure classification

This means the correct extraction target is a real headless core package, not just copying `EngineService` into `cli/`.

## Revised Architecture

Target structure:

```text
packages/
  overlay_core/
    lib/
      src/
        commands/
        diagnostics/
        matching/
        models/
        progress/
        queue/
        runtime/
    test/
cli/
  bin/
    fpv_overlay.dart
  lib/
    src/
      commands/
      formatting/
      terminal/
  test/
```

### `packages/overlay_core`

This package should be pure Dart, not Flutter.

It should own:

- task models and failure models
- file matching
- batch session behavior
- output path generation
- runtime discovery
- subprocess execution
- progress parsing
- doctor/diagnostics reporting

It should not own:

- desktop notifications
- dock/taskbar progress
- `shared_preferences`
- drag-and-drop
- command palette or onboarding
- Flutter widgets or providers

### `cli/`

This package should be thin:

- parse args
- call `overlay_core`
- print progress, summaries, and failures
- provide a stable terminal interface

## Data Model Decisions

### Keep

These can move into shared headless code with minimal churn:

- `OverlayTask`
- `TaskStatus`
- `OverlayType`
- `TaskFailure`
- `TaskAdditionResult`
- `TaskFailureParser`

### Replace

Do not move `AppConfiguration` into shared code unchanged.

Reason:

- it mixes desktop-persisted preferences with actual runtime execution needs
- fields like `lastUsedInputDirectory` and onboarding state are UI concerns
- the CLI should be stateless by default

Instead create narrower headless types:

- `RuntimeOverrides`
  explicit executable/runtime overrides from CLI flags or env vars
- `RenderRequest`
  one render invocation with video, optional SRT, optional OSD, output, and mode
- `BatchSession`
  in-memory queue used by both desktop and CLI

The desktop app can translate its saved settings into those headless types.

## What To Extract And How

### 1. Runtime discovery

Replace `PathResolver` with an instance-based service such as `RuntimeLocator`.

Search order should be:

1. explicit CLI flags
2. environment variables
3. packaged runtime directory for the standalone CLI
4. packaged app-bundle runtime for the desktop app
5. development fallback paths
6. system `PATH` fallback for dev only

Suggested env vars:

- `FPV_OVERLAY_RUNTIME_DIR`
- `FPV_OVERLAY_FFMPEG`
- `FPV_OVERLAY_FFPROBE`
- `FPV_OVERLAY_OSD_EXECUTABLE`
- `FPV_OVERLAY_SRT_EXECUTABLE`

Important refinement:

For Homebrew installs, prefer an env-backed runtime path over trying to infer everything from the symlinked `bin/` wrapper alone.

### 2. Queue and pairing behavior

Split the headless queue logic out of `TaskQueueProvider`.

Create something like:

- `OverlayBatchSession.addFiles(List<String> paths)`
- `OverlayBatchSession.addDirectory(String path)`
- `OverlayBatchSession.resolveLinks()`
- `OverlayBatchSession.renderAll(...)`

This shared session should own:

- task merging when new partial files arrive later
- same-stem merge rules
- same-directory requirement for `.osd` auto-attachment
- nearest preceding `.osd` fallback
- unique output-path generation

The desktop provider should become a thin adapter around that session.

### 3. Rendering orchestration

Move these into `overlay_core`:

- `CommandRunnerService`
- `ProcessRunnerMixin`
- `OverlayCommand`
- `OsdOverlayCommand`
- `SrtOverlayCommand`
- `CombinedOverlayCommand`

Then replace direct static path lookups with injected runtime dependencies.

### 4. Progress parsing

Extract the regex progress logic from `TaskQueueProvider` into a dedicated shared parser.

Create something like:

- `OverlayProgressEvent`
- `OverlayProgressParser.parseLine(String line)`

The desktop app can use it for UI progress bars.
The CLI can use it for terminal summaries or progress lines.

## CLI Command Contract

The CLI should have only a few stable commands in v1.

### `render`

Common workflow:

```bash
fpv-overlay render --video clip.mp4 --srt clip.srt --osd clip.osd
```

Rules:

- `--video` is required
- at least one of `--srt` or `--osd` is required
- public docs can position `video + srt (+ optional osd)` as the main path
- implementation should still allow OSD-only for parity with the desktop app

Recommended flags:

- `--video <path>`
- `--srt <path>`
- `--osd <path>`
- `--output <path>`
- `--output-dir <path>` as an alternative to `--output`
- `--overwrite`
- `--verbose`
- `--dry-run`

Output behavior:

- if `--output` is set, use it
- else if `--output-dir` is set, write `<stem>_overlay.mp4` into that directory
- else default to `<video-dir>/<stem>_overlay.mp4`
- if a file exists and `--overwrite` is not set, append `_1`, `_2`, and so on

### `batch`

Common workflow:

```bash
fpv-overlay batch --input-dir ./flight-pack --output-dir ./renders
```

Rules:

- scan one directory non-recursively in v1 to preserve current desktop semantics
- reuse the same matching and fallback rules as the desktop app
- continue processing later tasks if one task fails

Recommended flags:

- `--input-dir <path>`
- `--output-dir <path>`
- `--overwrite`
- `--dry-run`
- `--verbose`

Recommended v1 behavior:

- if `--output-dir` is omitted, default to `<input-dir>/renders`
- `--dry-run` should print the task plan without rendering
- summary should include counts for completed, failed, skipped, and partial inputs

### `doctor`

This command should validate the runtime, not just print guessed paths.

Checks should include:

- CLI version
- executable path
- runtime directory
- `ffmpeg` existence and `-version` execution
- `ffprobe` existence
- `osd_overlay` executable existence and `--help` execution
- `srt_overlay` executable existence and `--help` execution
- temp directory write access

Optional later flag:

- `--json`

### `--version`

Print:

- CLI version
- release channel if any
- runtime version info if bundled

## Exit Codes

Define exit behavior before implementation so shell automation stays stable.

Recommended:

- `0` all requested work succeeded
- `1` one or more renders failed
- `2` usage error or invalid input
- `3` runtime not found or runtime validation failed

## Runtime Layout

Standalone release bundle layout:

```text
fpv-overlay
runtime/
  ffmpeg
  ffprobe
  osd_overlay/
    osd_overlay
    ...
  srt_overlay/
    srt_overlay
    ...
```

Homebrew install layout should become:

```text
bin/fpv-overlay
libexec/fpv-overlay
libexec/runtime/...
```

Recommended formula behavior:

- install the real compiled binary under `libexec`
- install the runtime bundle under `libexec/runtime`
- install a small wrapper into `bin/` using Homebrew's env-script pattern so the runtime dir is explicit

That wrapper should set:

```text
FPV_OVERLAY_RUNTIME_DIR=#{libexec}/runtime
```

This is more reliable than guessing from symlinked Homebrew paths at runtime.

## Packaging Strategy

### Release artifact format

Ship prebuilt release archives first.

Recommended artifact names:

- `fpv-overlay-cli-macos-arm64-<version>.tar.gz`
- `fpv-overlay-cli-macos-x64-<version>.tar.gz`

The archive should already contain:

- compiled Dart CLI executable
- `ffmpeg`
- `ffprobe`
- frozen `osd_overlay`
- frozen `srt_overlay`

### Build flow

Create dedicated CLI build scripts instead of overloading the app-bundle scripts.

Suggested scripts:

- `tools/build_cli_runtime_macos.sh`
- `tools/build_cli_release_macos.sh`

The build flow should be:

1. build frozen Python overlay executables
2. fetch or copy `ffmpeg` and `ffprobe`
3. compile Dart CLI with `dart compile exe`
4. assemble the release directory
5. archive and checksum it

## Homebrew Distribution Plan

Start with a custom tap, not `homebrew/core`.

Homebrew's docs explicitly support third-party taps and `brew tap-new` generated tap repositories:

- https://docs.brew.sh/Taps
- https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap
- https://docs.brew.sh/Formula-Cookbook
- https://docs.brew.sh/Bottles

Recommended rollout:

### Stage A: custom tap with release archives

1. create `boonyongyang/homebrew-tap`
2. add `Formula/fpv-overlay.rb`
3. point the formula at the GitHub release tarball(s)
4. install the binary and runtime into the keg
5. expose `bin/fpv-overlay`

User install command:

```bash
brew install boonyongyang/tap/fpv-overlay
```

### Stage B: bottle automation

After the formula stabilizes, use the default `brew tap-new` workflows to build bottles automatically from the tap if that reduces manual checksum maintenance.

That is a follow-up optimization, not a blocker for the first CLI release.

## Scope Recommendation For First Release

Keep the first public CLI release intentionally narrow.

Recommended initial scope:

- macOS only
- Apple Silicon first unless you are prepared to build and test Intel separately
- sequential rendering only
- non-recursive batch scanning
- plain-text terminal output

Reason:

- PyInstaller and FFmpeg payloads are architecture-specific
- Intel macOS support requires separate build/test validation
- keeping v1 narrow reduces packaging drift while the interface stabilizes

If Intel support matters immediately, treat it as a separate release-track requirement and add explicit artifact generation for both architectures before announcing Homebrew support.

## Test Plan

### Shared core tests

Move headless tests from `flutter_test` to pure Dart `package:test` where possible.

Required coverage:

- exact stem pairing
- combined task creation
- orphan video and orphan telemetry behavior
- late merge behavior for partial tasks
- same-directory `.osd` auto-attachment
- nearest preceding `.osd` fallback
- unique output naming
- progress line parsing
- runtime locator precedence
- failure classification

### CLI tests

Required coverage:

- arg parsing
- `render --dry-run`
- `batch --dry-run`
- `doctor`
- exit codes

### Release smoke tests

Use the external sample pack for real release verification:

- `DJIG0024.mp4`
- `DJIG0024.osd`
- `DJIG0024.srt`
- `DJIG0025.mp4`
- `DJIG0025.srt`

Required smoke checks:

- exact-match combined render
- split-segment fallback render
- CLI works without user-installed Python
- CLI works without user-installed FFmpeg
- Homebrew-installed runtime resolves correctly

## Detailed Implementation Sequence

### Milestone 1: shared headless extraction

Exit criteria:

- `overlay_core` exists
- desktop app compiles against it
- existing pairing behavior is preserved by tests

Concrete steps:

1. create `packages/overlay_core`
2. move models and parsers first
3. move command orchestration and process helpers
4. replace static `PathResolver` usage with injected runtime locator
5. extract queue/session logic out of `TaskQueueProvider`
6. convert relevant tests to pure Dart

### Milestone 2: CLI skeleton

Exit criteria:

- `fpv-overlay render --dry-run`
- `fpv-overlay batch --dry-run`
- `fpv-overlay doctor`

Concrete steps:

1. create `cli/pubspec.yaml`
2. add arg parsing
3. implement dry-run rendering request validation
4. implement plain-text summaries
5. define exit codes

### Milestone 3: real render execution

Exit criteria:

- CLI can run the same runtime as desktop
- sequential batch rendering works end-to-end

Concrete steps:

1. wire CLI commands to `overlay_core` executor
2. print task-level progress and final summaries
3. map failures to stable exit codes
4. validate output-path collision handling

### Milestone 4: release packaging

Exit criteria:

- tarball release artifact produced locally
- artifact runs on a clean machine without Python or FFmpeg

Concrete steps:

1. add CLI runtime build scripts
2. compile the Dart executable
3. assemble release bundle
4. checksum the artifact
5. run clean-machine smoke tests

### Milestone 5: Homebrew tap

Exit criteria:

- `brew install boonyongyang/tap/fpv-overlay` works on a clean machine

Concrete steps:

1. create tap repo with `brew tap-new`
2. add formula using the release archive
3. add wrapper script env for runtime dir
4. install and test from the tap
5. document install and upgrade flow

## Risks And Mitigations

### Risk: shared code still depends on Flutter

Mitigation:

- move code in small slices
- convert tests to pure Dart as you go

### Risk: runtime lookup breaks under Homebrew symlinks

Mitigation:

- use `FPV_OVERLAY_RUNTIME_DIR` from the installed wrapper script
- keep relative-path lookup only as a fallback

### Risk: CLI and desktop behavior drift

Mitigation:

- one shared `overlay_core`
- one shared batch-session implementation
- one shared progress parser

### Risk: Intel macOS support delays release

Mitigation:

- explicitly scope v1 to arm64 if needed
- add x64 as a planned follow-up instead of an implicit promise

## Definition Of Ready To Implement

The plan is ready to implement when you agree with these decisions:

1. shared pure Dart `overlay_core` package first
2. Dart CLI plus packaged runtime, not Python-only distribution
3. custom Homebrew tap first, `homebrew/core` not required
4. `render`, `batch`, and `doctor` only for v1
5. macOS arm64-only first release is acceptable unless Intel is explicitly required

If those five decisions stand, implementation can start without needing another architecture pass.
