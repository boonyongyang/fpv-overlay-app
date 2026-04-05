# macOS App Updates

## In-App Update Flow (macOS)

The macOS desktop app ships a full self-update experience accessible from
**Settings → App Updates**.

### States

| State | What the user sees |
|-------|--------------------|
| Idle / up to date | Current version label + "Up to date" + **Check for Updates** button |
| Checking | Spinner + "Checking…" |
| Update available | Version + published date + **Download** + **View Release** |
| Downloading | Progress bar (0–100 %) + **Cancel** |
| Ready to install | **Install & Relaunch** button + "The app will quit and relaunch with the new version." |

### Install & Relaunch mechanism

When the user taps **Install & Relaunch** the app:

1. Mounts the downloaded DMG silently (`hdiutil attach -nobrowse -noverify -noautoopen`).
2. Finds the `.app` inside the mounted volume.
3. Writes a detached bash script to `/tmp/fpv_overlay_update_<pid>.sh`.
4. The script polls the parent PID (`kill -0 <pid>`) until the app exits.
5. Once the app is gone it runs `ditto` to copy the new `.app` bundle over the
   installed one, then re-opens the app with `open`.
6. Falls back to `open <volumePath>` if `ditto` fails (e.g. permissions issue —
   user sees the DMG and can drag-install manually).
7. Cleans up the DMG volume and temp script.
8. The Flutter app calls `exit(0)` immediately after spawning the script.

The script is spawned with `ProcessStartMode.detached` so it survives the
parent process exit.

> **Dev mode**: `installUpdate()` detects dev builds by checking whether
> `Platform.resolvedExecutable` contains `.app/Contents/MacOS`. In dev mode
> the install step is skipped to avoid clobbering your local build.

---

## Release Artifact Pipeline

### Workflow

- Workflow: `.github/workflows/release.yml`
- Trigger: `v*` tag push
- Outputs per release:
  - `fpv-overlay-toolbox-macos-<version>.dmg`
  - `fpv-overlay-toolbox-macos-<version>.dmg.sha256`
  - `latest-macos.json`

### `latest-macos.json`

Stable URL the app polls at startup and on manual check:

```
https://github.com/boonyongyang/fpv-overlay-app/releases/latest/download/latest-macos.json
```

Shape:

```json
{
  "platform": "macos",
  "channel": "stable",
  "version": "1.0.3",
  "release_tag": "v1.0.3",
  "published_at": "2026-04-06T00:00:00Z",
  "artifact_name": "fpv-overlay-toolbox-macos-1.0.3.dmg",
  "artifact_url": "https://github.com/.../fpv-overlay-toolbox-macos-1.0.3.dmg",
  "sha256": "<hex>",
  "release_url": "https://github.com/.../releases/tag/v1.0.3",
  "manifest_url": "https://github.com/.../releases/latest/download/latest-macos.json"
}
```

`artifact_url` and `sha256` are used by `UpdateProvider.startDownload()` to
stream the DMG and verify integrity before offering the Install & Relaunch step.

### What the workflow does

On each `v*` tag push:

1. Checks out the tagged revision.
2. Verifies the tag version matches `pubspec.yaml`.
3. Builds the macOS release app.
4. Packages the `.dmg`.
5. Computes the SHA-256 checksum.
6. Renders `latest-macos.json` with `artifact_url` and `sha256` filled in.
7. Creates the GitHub release if it does not already exist.
8. Uploads the `.dmg`, checksum file, and manifest as release assets.

### Important repo setting

The workflow creates releases and uploads assets, so the repo must have:

> GitHub repo → Settings → Actions → General → Workflow permissions →
> **Read and write permissions**
