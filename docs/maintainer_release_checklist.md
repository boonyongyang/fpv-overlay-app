# Maintainer Release Checklist

Everything below still requires a human decision, a real machine validation step,
or a GitHub-side action.

---

## 1. Push to GitHub

No remote is configured yet. Create the repo on GitHub, then:

```bash
git remote add origin https://github.com/<your-username>/fpv-overlay-app.git
git push -u origin main
```

Once pushed, the CI workflow (`.github/workflows/ci.yml`) will run automatically
on future pushes, and the unified release workflow (`.github/workflows/release.yml`)
will be available in Actions.

For the macOS update workflow, also check:

- GitHub repo → Settings → Actions → General
- Workflow permissions → **Read and write permissions**

That workflow creates GitHub releases and uploads update assets, so read-only
token permissions are not enough.

---

## 2. Add README Screenshots

The README has no visuals. Add 3–6 screenshots or short GIFs showing:

- The queue workspace (empty state + populated)
- A task card (completed, failed, or missing-telemetry state)
- The command palette (`Cmd+K`)
- The render activity view
- Onboarding / tutorial (optional)

Put them in `docs/screenshots/` and reference them from README.md.

---

## 3. Verify README Links

Check that these match your actual GitHub repo:
- `AppIdentity.repositoryUrl` in `lib/core/constants/app_identity.dart` — currently `https://github.com/boonyongyang/fpv-overlay-app`
- `AppIdentity.releasesUrl` — same repo `/releases`
- All links in README.md, CONTRIBUTING.md, and CODE_OF_CONDUCT.md

Update `AppIdentity` constants if your repo slug differs.

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

## 7. Tag and Publish v1.0.0

Once the DMG and EXE are validated:

```bash
# Clean up before tagging
rm -rf build/ dist/ .venv-media/ .venv-packaging/ .venv-packaging-windows/

git tag -a v1.0.0 -m "v1.0.0"
git push origin v1.0.0
```

Then on GitHub → Releases → create a new release from the tag and upload:
- `fpv-overlay-toolbox-macos-1.0.0.dmg`
- `fpv-overlay-toolbox-windows-1.0.0-setup.exe`
- (optional) sample pack archive

---

## Nice-to-Have Follow-Up

- **Verify tagged release CI**: After the first push, confirm the desktop and CLI
  release workflows both behave as expected from a `v*` tag.
- **Recursive folder scanning**: Currently only the top-level of a scanned
  directory is matched. Useful for SD card dumps with nested folders.
- **Regression sample pack**: A lightweight set of test clips committed to a
  separate repo or release asset specifically for CI smoke testing.
