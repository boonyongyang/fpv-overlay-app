# Bundled Dependencies

To make the **FPV Overlay Toolbox** a standalone macOS app, drop the following binaries and folders inside this directory:

### 1. FFmpeg
- Download a static macOS binary for FFmpeg (`ffmpeg`).
- Ensure it's marked as executable (`chmod +x ffmpeg`)
- Place it here: `assets/bin/ffmpeg`

### 2. Python Environment
- Place a standalone Python interpreter or binary here:
- `assets/bin/python3`

### 3. O3_OverlayTool
- Clone or copy the `O3_OverlayTool` repository here.
- It should look like this: `assets/bin/O3_OverlayTool/VideoMaker.py`

---

## How it works

When the app runs, it will use `PathResolver` to check for these files.
- **Development**: It checks the root `assets/bin` folder.
- **Production (macOS app)**: To bundle these into the `.app`, you should add a build phase script in Xcode to copy `assets/bin/` into the `Contents/Resources/bin` directory of the app bundle, or package it inside the flutter assets (though executing binaries from flutter assets requires copying them to temp directories first).

Because this app uses these internal paths, the user no longer needs to configure any paths manually. If these files are missing, the app will gracefully fall back to checking the system `PATH` (e.g., `ffmpeg` or `python3`).
