# macOS App Update Pipeline

This repo now includes a dedicated GitHub Actions workflow for shipping macOS app
updates:

- workflow: `.github/workflows/release.yml`
- trigger: push a `v*` tag such as `v1.0.0`
- output:
  - `fpv-overlay-toolbox-macos-<version>.dmg`
  - `fpv-overlay-toolbox-macos-<version>.dmg.sha256`
  - `latest-macos.json`

## What `latest-macos.json` Is For

`latest-macos.json` is a stable update manifest that points at the newest macOS
release artifact and its checksum.

Once the repo exists on GitHub, the stable URL is:

`https://github.com/<owner>/<repo>/releases/latest/download/latest-macos.json`

That gives the app a future update-check target without requiring Sparkle right
away.

## What The Workflow Does

On each matching release tag, the workflow:

1. checks out the tagged revision
2. verifies the tag version matches `pubspec.yaml`
3. builds the macOS release app
4. packages the `.dmg`
5. computes the SHA-256 checksum
6. renders `latest-macos.json`
7. creates the GitHub release if it does not already exist
8. uploads the `.dmg`, checksum, and manifest as release assets

## Manual Dispatch

You can also run the workflow manually from GitHub Actions, but it still expects
an existing release tag such as `v1.0.0`.

## Important Repo Setting

Because this workflow creates releases and uploads assets, make sure GitHub
Actions has write access to repository contents:

- GitHub repo → Settings → Actions → General
- Workflow permissions → **Read and write permissions**
