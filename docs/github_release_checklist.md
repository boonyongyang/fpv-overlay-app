# GitHub Release Checklist

Use this checklist before publishing a public GitHub release for FPV Overlay
Toolbox.

## Hard blockers

- [ ] Fresh macOS install test from the generated `.dmg`
- [ ] Fresh Windows install test from the generated installer `.exe`
- [ ] Confirm the bundled runtime works without a user-installed FFmpeg or
      Python
- [x] Move large sample media out of the normal git clone path
      Source repo now keeps only `samples/manifest.json` plus notes
- [x] Attach a real release tag and upload the desktop artifacts
      Unified release workflow in `.github/workflows/release.yml`
- [x] Bump `cli/pubspec.yaml` and `cli/lib/src/app.dart` to match the release tag

## Repo presentation

- [ ] Add 3-6 screenshots or short GIFs to the README
- [x] Confirm the README install steps match the latest release artifacts
- [x] Confirm the README links point to the correct GitHub repo and releases page
- [x] Check that product naming is consistent across app UI, scripts, and docs

## Release artifacts

- [x] Verify artifact names:
      - `fpv-overlay-toolbox-macos-<version>.dmg`
      - `fpv-overlay-toolbox-windows-<version>-setup.exe`
- [ ] Verify the bundled runtime exists inside the macOS `.app`
- [ ] Verify the Windows installer includes the runtime payload
- [ ] Smoke-test the `DJIG0024` / `DJIG0025` split-recording sample pair
- [x] Verify CLI artifact names:
      - `fpv-overlay-cli-macos-arm64-<version>.tar.gz`
      - `fpv-overlay-cli-macos-x64-<version>.tar.gz`
- [ ] Run a clean-machine `brew install boonyongyang/tap/fpv-overlay` smoke test once the tap is updated

## Packaging and signing

- [x] macOS: ad-hoc signed only — documented in README (right-click → Open)
- [ ] If distributing broadly, notarize the macOS app and DMG
- [x] Windows: unsigned — documented in README (SmartScreen → More info → Run anyway)

## Open-source hygiene

- [x] Add a real `LICENSE` file
- [x] Document privacy behavior and local-only stats
- [x] `.gitignore` excludes `build/`, `dist/`, `*.dmg`, virtualenvs, editor files

## Nice-to-have follow-up

- [x] GitHub Actions for tagged release builds
      Unified release flow in `.github/workflows/release.yml`
- [x] In-app update check and auto-download (macOS)
      `UpdateProvider` + `HttpUpdateService` + Settings page panel
- [ ] Add recursive folder scanning
- [ ] Add a lightweight sample pack specifically for source-repo regression tests
