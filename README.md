# ✈️ FPV Overlay Toolbox

A powerful, open-source macOS desktop utility designed for FPV pilots to effortlessly apply telemetry overlays to their flight videos. This tool bridges the gap between raw flight data and polished, ready-to-share videos.

---

## 🚀 Features

- **SRT Fast Overlay**: Directly burn DJI subtitle-based telemetry tracks into your video using FFmpeg. Fast, lightweight, and perfect for quick reviews.
- **OSD HD Rendering**: Interface with the `O3_OverlayTool` to generate high-fidelity, graphical OSD gauges (requires Python).
- **Batch Processing**: Add entire folders or pick specific files to queue multiple videos for processing.
- **Smart Pairing**: Automatically matches video files with their corresponding telemetry `.srt` or `.osd` files based on filename.
- **macOS Optimized**: Native feeling UI with sandboxing disabled for seamless system integration with local binaries.

## 🛠 Prerequisites

To use the full power of the FPV Overlay Toolbox, you need the following tools installed on your system:

1.  **FFmpeg**: Required for all video encoding and SRT burn-in.
    - *Install via Homebrew:* `brew install ffmpeg`
2.  **Python 3**: Required for graphical OSD rendering.
3.  **O3_OverlayTool**: The Python-based rendering engine.
    - Clone it from the official repository and point to its path in the app settings.

## ⚙️ Setup

1.  **Paths Configuration**: Open the **Configuration** tab in the app.
2.  Set the absolute path to your `ffmpeg` binary (usually `/usr/local/bin/ffmpeg` or `/opt/homebrew/bin/ffmpeg`).
3.  Set the path to your `python3` executable.
4.  Point to the directory where you cloned the `O3_OverlayTool`.

## 📖 How it Works

1.  **Add Media**: Click "Add Media" or "Scan Folder". The app will find pairs like `DJIG001.mp4` and `DJIG001.srt`.
2.  **Select Processing Type**: Choose between SRT (Fast) or OSD (High Quality) modes.
3.  **Generate**: Select an output directory and hit "Generate Overlays". The app will process each task sequentially and provide real-time status updates.

---

## 🛡 Disclaimer

This is a community-driven tool. Always ensure your telemetry files match your video recording for accurate sync.

## 📄 License

Open-source. Contributions are welcome!

