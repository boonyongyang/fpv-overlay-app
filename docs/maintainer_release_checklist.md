# Maintainer Release Checklist

The automated steps live in `CLAUDE.md → Release Procedure`. This file covers
decisions and machine-level validations that cannot be automated.

---

## 1. Push to GitHub ✅ Done

Repo is live at https://github.com/boonyongyang/fpv-overlay-app

CI runs on every push to `main`. Release workflow runs on every `v*` tag push.

Workflow write permissions are set (required for release creation and asset upload).

---

## 2. Add README Screenshots (pending)

The README has no visuals yet. Add 3–6 screenshots or short GIFs showing:

- The queue workspace (empty state + populated)
- A task card (completed, failed, or missing-telemetry state)
- The command palette (`Cmd+K`)
- The render activity view
- Onboarding / tutorial (optional)

Put them in `docs/screenshots/` and reference them from README.md.

---

## 3. Verify README Links ✅ Done

`AppIdentity` constants in `lib/core/constants/app_identity.dart` point to the correct repo.
All README, CONTRIBUTING, and CODE_OF_CONDUCT links verified.

---

## 4. macOS: Build and Test the DMG

On your Mac:

```bash
make release   # bootstrap → check → build → package → dmg
```

Then:
- Mount the generated `dist/fpv-overlay-toolbox-macos-<version>.dmg`
- Drag the app to `/Applications` on a **clean machine or VM** (no Xcode, no FFmpeg, no Python in PATH)
- Launch it and run the `DJIG0024` + `DJIG0025` split-recording sample pair end to end
- Confirm the bundled runtime (FFmpeg + Python) works without any user-installed deps

**Signing decision**: Ad-hoc signing is fine for direct downloads. If you want to distribute via a link that won't trigger Gatekeeper for most users, you need to notarize. Decide and act:

- **Ad-hoc only**: Users right-click → Open the first time. Document this in the README install steps.
- **Notarized**: Requires an Apple Developer account ($99/year). Run `xcrun notarytool` after the DMG is built.

---

## 5. Windows: Build and Test the Installer

On a Windows machine:

```powershell
make build-windows-release
make package-windows-runtime
make windows-installer
```

Then:
- Run the generated `dist/windows/fpv-overlay-toolbox-windows-<version>-setup.exe` on a **clean VM** (no FFmpeg, no Python)
- Smoke-test the same DJIG sample pair
- Confirm the runtime payload is bundled inside the installer

**SmartScreen decision**: Unsigned EXEs show a SmartScreen warning on first run. Options:
- **Unsigned**: Document the "Run anyway" click in the README install steps.
- **Signed**: Requires a code-signing certificate (OV cert ~$200–400/year from DigiCert etc.).

---

## 6. Distribute the Sample Pack

The raw sample files (`DJIG0024.mp4`, `.osd`, `.srt`, `DJIG0025.mp4`, `.srt`) are not in the repo. Make them available so others can run the regression smoke test:

- Upload them as assets to the v1.0.0 GitHub release, **or**
- Host them separately and update `samples/manifest.json` with the download URL

---

## 7. Tag and Publish ✅ Operational

Follow the full release procedure in `CLAUDE.md → Release Procedure`.

Quick summary:

1. `make check` — all tests must pass
2. Bump version in `pubspec.yaml`, `cli/pubspec.yaml`, `cli/lib/src/app.dart`
3. Commit + push to `main`
4. `make release` — builds local DMG in `dist/`
5. `git tag -a vX.Y.Z -m "vX.Y.Z" && git push origin vX.Y.Z`
6. CI release workflow automatically builds macOS DMG + Windows EXE + CLI
   arm64/x64, creates the GitHub release, and uploads all artifacts +
   `latest-macos.json` + Homebrew formula.
7. `gh run list --limit 5` to confirm the release workflow passed.

> `build/` and `dist/` are in `.gitignore` — no manual cleanup needed before tagging.

---

## Nice-to-Have Follow-Up

- **Verify tagged release CI**: After the first push, confirm the desktop and CLI
  release workflows both behave as expected from a `v*` tag.
- **Recursive folder scanning**: Currently only the top-level of a scanned
  directory is matched. Useful for SD card dumps with nested folders.
- **Regression sample pack**: A lightweight set of test clips committed to a
  separate repo or release asset specifically for CI smoke testing.
