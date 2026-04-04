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
- [ ] Attach a real release tag and upload the desktop artifacts
- [x] If publishing the CLI, bump `cli/pubspec.yaml` and use a matching `v*` tag

## Repo presentation

- [ ] Add 3-6 screenshots or short GIFs to the README
- [ ] Confirm the README install steps match the latest release artifacts
- [ ] Confirm the README links point to the correct GitHub repo and releases page
- [ ] Check that product naming is consistent across app UI, scripts, and docs

## Release artifacts

- [ ] Verify artifact names:
      - `fpv-overlay-toolbox-macos-<version>.dmg`
      - `fpv-overlay-toolbox-windows-<version>-setup.exe`
- [ ] Verify the bundled runtime exists inside the macOS `.app`
- [ ] Verify the Windows installer includes the runtime payload
- [ ] Smoke-test the `DJIG0024` / `DJIG0025` split-recording sample pair
- [ ] Verify CLI artifact names:
      - `fpv-overlay-cli-macos-arm64-<version>.tar.gz`
      - `fpv-overlay-cli-macos-x64-<version>.tar.gz`
- [ ] Run a clean-machine `brew install boonyongyang/tap/fpv-overlay` smoke test once the tap is updated

## Packaging and signing

- [ ] Decide whether the macOS build is acceptable as ad-hoc signed only
- [ ] If distributing broadly, notarize the macOS app and DMG
- [ ] Decide whether Windows code signing is needed for public trust and SmartScreen

## Open-source hygiene

- [x] Add a real `LICENSE` file
- [x] Document privacy behavior and local-only stats
- [ ] Remove any repo-local junk before tagging:
      - `build/`
      - `dist/`
      - virtualenvs
      - editor files

## Nice-to-have follow-up

- [x] Add GitHub Actions for tagged release builds
      The unified release flow now lives in `.github/workflows/release.yml`
- [ ] Add recursive folder scanning
- [ ] Add a lightweight sample pack specifically for source-repo regression tests
