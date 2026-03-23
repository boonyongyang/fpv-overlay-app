#!/usr/bin/env python3
"""
osd_overlay.py – OSD Overlay Pipeline (self-contained)
=======================================================
Composites a DJI .osd file onto a source MP4 in two passes:

  Pass 1 – Render each OSD frame as RGBA and pipe to ffmpeg → transparent .mov
  Pass 2 – Use ffmpeg overlay filter to blend the transparent .mov onto the
            source video → final .mp4

Usage:
    python3 osd_overlay.py --osd <file.osd> --video <file.mp4>
                           --output <out.mp4>
                           [--tool <O3_OverlayTool_dir>]
                           [--font <font.png>]
                           [--ffmpeg <ffmpeg_path>]
                           [--fps <float>]

OsdFileReader is imported from this script's own directory first. If it is not
present there, the --tool path is tried as a fallback.
"""

import argparse
import os
import re
import sys
import subprocess
import tempfile
from pathlib import Path

# ── Make OsdFileReader importable from this script's own directory ────────────
_SCRIPT_DIR = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))
sys.path.insert(0, str(_SCRIPT_DIR))


def parse_args():
    parser = argparse.ArgumentParser(description="OSD overlay pipeline")
    parser.add_argument("--osd",    required=True,  help="Path to .osd file")
    parser.add_argument("--video",  required=True,  help="Path to source video")
    parser.add_argument("--output", required=True,  help="Path to output MP4")
    parser.add_argument("--tool",   default="",     help="Optional: O3_OverlayTool directory (used for fonts / fallback imports)")
    parser.add_argument("--font",   default="",     help="Explicit path to font PNG (overrides auto-detection)")
    parser.add_argument("--ffmpeg", default="ffmpeg", help="ffmpeg executable (default: system ffmpeg)")
    parser.add_argument("--fps",    type=float, default=60.0, help="OSD frame rate (default: 60)")
    parser.add_argument("--srt",    default="",     help="Path to DJI SRT file for telemetry HUD overlay")
    parser.add_argument("--osd-start-offset", type=float, default=None,
                        help="Optional start offset, in seconds, when reusing an earlier segment's OSD file")
    return parser.parse_args()


def resolve_font(tool_path: Path, explicit_font: str) -> str:
    """Return the path to a valid font PNG, or exit with an actionable error."""
    if explicit_font and Path(explicit_font).exists():
        return explicit_font

    # Font file preference order (most compatible for DJI O3)
    candidates = [
        "WS_BFx4_Nexus_Moonlight_2160p.png",
        "WS_BFx4_Nexus_Moonlight_1440p.png",
        "WS_BTFL_Conthrax_Moonlight_2160p.png",
        "WS_BTFL_Conthrax_Moonlight_1440p.png",
        "WS_BTFL_Europa_Moonlight_2160p.png",
        "WS_BTFL_Blinder_Moonlight_2160p.png",
        "BFX1_DJI_OG_2160p.png",
        "OG_bf_36.png",
        "OG_bf_24.png",
    ]

    # Search: script dir fonts/ → tool dir fonts/
    search_dirs: list[Path] = [_SCRIPT_DIR / "fonts"]
    if tool_path != Path("") and tool_path != _SCRIPT_DIR:
        search_dirs.append(tool_path / "fonts")

    for search_dir in search_dirs:
        for name in candidates:
            candidate = search_dir / name
            if candidate.exists():
                print(f"Font: {candidate}", flush=True)
                return str(candidate)

    # ── No font found – emit a friendly, actionable error ────────────────────
    dirs_str = "\n    ".join(str(d) for d in search_dirs)
    print(
        "Error: No OSD font PNG file found.\n"
        f"  Searched in:\n    {dirs_str}\n\n"
        "  To fix this, choose one of the following:\n"
        "    1. Download O3_OverlayTool-1.1.0 to your ~/Downloads folder\n"
        "       https://github.com/xNuclearSquirrel/O3_OverlayTool/releases\n"
        "    2. Open Settings → Application Preferences → set the\n"
        "       'O3_OverlayTool Directory' to the folder you downloaded.\n"
        "    3. Pass --font <path_to_font.png> explicitly.",
        flush=True,
    )
    sys.exit(1)


def build_tile_renderer(font_image, osd_reader, target_size=None):
    """
    Return a (resolution, render_frame) pair for the given OSD + font.

    Mirrors the TypeScript wtfos-configurator VideoWorker behaviour:
      1. Compute the natural OSD canvas (fontTileW * charWidth ×
         fontTileH * charHeight) from the font image dimensions.
      2. Scale to FIT the target canvas, preserving the natural aspect
         ratio (same as TypeScript's osdScale = min(h_scale, w_scale)).
      3. Centre the scaled OSD on the output canvas; transparent margins
         appear where the OSD does not cover (matching the goggles view).

    Output frames are always *target_size* pixels (transparent background)
    so pass-2 can overlay at (0, 0) without any additional scaling.
    """
    import math
    import numpy as np
    from PIL import Image

    num_rows = 256
    # Font-native tile dimensions (used for crop coordinates inside the PNG)
    font_tile_h = font_image.height / num_rows
    font_tile_w = font_tile_h / 1.5  # 1:1.5 width:height ratio

    num_cols = max(1, min(4, int(font_image.width // font_tile_w)))

    grid_w = osd_reader.header["config"]["charWidth"]
    grid_h = osd_reader.header["config"]["charHeight"]

    # Natural OSD canvas in integer pixels
    natural_tile_w = max(1, int(font_tile_w))
    natural_tile_h = max(1, int(font_tile_h))
    natural_osd_w  = grid_w * natural_tile_w
    natural_osd_h  = grid_h * natural_tile_h

    if target_size:
        output_w, output_h = target_size
        # Scale to FIT while preserving aspect ratio (TypeScript osdScale logic)
        fit_scale = min(output_w / natural_osd_w, output_h / natural_osd_h)
        # Use ceiling so adjacent tiles overlap by ≤1 px rather than leaving gaps
        render_tile_size = (
            max(1, math.ceil(font_tile_w * fit_scale)),
            max(1, math.ceil(font_tile_h * fit_scale)),
        )
        scaled_tile_w = font_tile_w * fit_scale   # float for accurate positioning
        scaled_tile_h = font_tile_h * fit_scale
        scaled_osd_w  = int(natural_osd_w * fit_scale)
        scaled_osd_h  = int(natural_osd_h * fit_scale)
        # Centre OSD on the full output canvas
        x_offset = (output_w - scaled_osd_w) // 2
        y_offset = (output_h - scaled_osd_h) // 2
        resolution = target_size
    else:
        # Natural font resolution – no scaling or centering needed
        render_tile_size = (natural_tile_w, natural_tile_h)
        scaled_tile_w = float(natural_tile_w)
        scaled_tile_h = float(natural_tile_h)
        x_offset = 0
        y_offset = 0
        resolution = (natural_osd_w, natural_osd_h)

    tile_cache: dict = {}

    def get_tile(tile_index: int) -> "np.ndarray":
        if tile_index in tile_cache:
            return tile_cache[tile_index]

        col = tile_index // 256
        row = tile_index % 256
        col = min(col, num_cols - 1)
        row = min(row, 255)

        left  = int(col * font_tile_w)
        upper = int(row * font_tile_h)
        right = int(left + font_tile_w)
        lower = int(upper + font_tile_h)

        if right > font_image.width or lower > font_image.height:
            tile = Image.new("RGBA", render_tile_size, (0, 0, 0, 0))
        else:
            tile = font_image.crop((left, upper, right, lower))
            if tile.size != render_tile_size:
                tile = tile.resize(render_tile_size, Image.LANCZOS)

        arr = np.array(tile)
        tile_cache[tile_index] = arr
        return arr

    def render_frame(frame_content) -> "np.ndarray":
        tw, th = render_tile_size
        frame = np.zeros((resolution[1], resolution[0], 4), dtype=np.uint8)
        for i in range(grid_h):
            for j in range(grid_w):
                k = i * grid_w + j
                if k < len(frame_content):
                    tile = get_tile(frame_content[k])
                    # Float-based positions avoid accumulated integer rounding gaps
                    x = int(j * scaled_tile_w) + x_offset
                    y = int(i * scaled_tile_h) + y_offset
                    x2 = min(x + tw, resolution[0])
                    y2 = min(y + th, resolution[1])
                    if x2 > x and y2 > y:
                        frame[y:y2, x:x2] = tile[:y2 - y, :x2 - x]
        return frame

    return resolution, render_frame


# ---------------------------------------------------------------------------
# DJI FPV Goggle SRT parser & renderer
# (matches the wtfos-configurator osd-overlay/srt.ts SrtReader + worker.ts
# drawText calls)
# ---------------------------------------------------------------------------

def _ts_str_to_ms(ts):
    """Convert SRT timestamp string 'HH:MM:SS,mmm' to milliseconds."""
    ts = ts.strip().replace(",", ".")
    parts = ts.split(":")
    if len(parts) != 3:
        return 0
    h, m = int(parts[0]), int(parts[1])
    s = float(parts[2])
    return h * 3600000 + m * 60000 + int(s * 1000)


def parse_dji_fpv_srt(srt_path):
    """
    Parse DJI FPV goggle SRT telemetry format.

    Expected text per subtitle block (single line, space-separated key:value):
        signal:100 ch:2 flightTime:10 uavBat:24.3V glsBat:0.0V
        uavBatCells:6 glsBatCells:0 delay:27ms bitrate:50.8Mbps rcSignal:0

    Returns a list of dicts with start_ms, end_ms, and formatted fields.
    Returns an empty list if the file is not in DJI FPV format.
    """
    raw = Path(srt_path).read_text(encoding="utf-8", errors="replace")
    blocks = re.split(r"\n{2,}", raw.strip())
    frames = []
    detected_format = False

    for block in blocks:
        lines = [ln.strip() for ln in block.strip().split("\n") if ln.strip()]
        if len(lines) < 3:
            continue

        # Find timestamp line
        ts_idx = None
        for i, line in enumerate(lines):
            if "-->" in line:
                ts_idx = i
                break
        if ts_idx is None:
            continue

        parts = lines[ts_idx].split("-->")
        if len(parts) < 2:
            continue
        try:
            start_ms = _ts_str_to_ms(parts[0])
            end_ms = _ts_str_to_ms(parts[1])
        except Exception:
            continue

        # Parse key:value pairs from all lines after timestamp
        text = " ".join(lines[ts_idx + 1:])
        fields = {}
        for token in text.split():
            if ":" in token:
                key, _, val = token.partition(":")
                fields[key.lower()] = val

        # Detect DJI FPV format by checking for characteristic fields
        if not detected_format:
            if any(k in fields for k in ("ch", "delay", "bitrate", "uavbat")):
                detected_format = True
            else:
                return []  # Not DJI FPV format

        flight_time_sec = 0
        try:
            flight_time_sec = int(fields.get("flighttime", "0"))
        except ValueError:
            pass
        minutes = str(flight_time_sec // 60).zfill(2)
        seconds = str(flight_time_sec % 60).zfill(2)

        frames.append({
            "start_ms": start_ms,
            "end_ms":   end_ms,
            "ch":       "CH" + fields.get("ch", "0"),
            "flightTimeSec": flight_time_sec,
            "flightTime": f"{minutes}' {seconds}\"",
            "uavBat":   fields.get("uavbat", ""),
            "glsBat":   fields.get("glsbat", ""),
            "delay":    fields.get("delay", ""),
            "bitrate":  fields.get("bitrate", ""),
        })

    return frames


def _find_srt_frame(srt_frames, time_ms):
    """Find the SRT frame covering the given time (ms). Mirrors worker.ts logic."""
    if not srt_frames:
        return None
    # Before first subtitle: use the first frame as filler
    if time_ms < srt_frames[0]["start_ms"]:
        return srt_frames[0]
    # After last subtitle: show the last one
    if time_ms >= srt_frames[-1]["end_ms"]:
        return srt_frames[-1]
    for fr in srt_frames:
        if fr["start_ms"] <= time_ms < fr["end_ms"]:
            return fr
    return srt_frames[-1]


def _get_srt_font(size):
    """Load a TrueType font for SRT HUD text. Falls back to PIL default."""
    from PIL import ImageFont
    candidates = [
        # macOS
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial.ttf",
        "/System/Library/Fonts/SFNSDisplay.ttf",
        # Linux
        "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        # Windows
        "C:/Windows/Fonts/calibri.ttf",
        "C:/Windows/Fonts/arial.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except (IOError, OSError):
            continue
    try:
        return ImageFont.truetype("arial", size)
    except Exception:
        return ImageFont.load_default()


def _draw_srt_overlay(frame_arr, srt_frame, out_w, out_h):
    """
    Draw DJI FPV goggle SRT telemetry text on a rendered RGBA frame.

    Positions mirror the wtfos-configurator worker.ts drawText calls.
    The reference draws text on the OSD canvas (~1440x792 for a 60x22 HD
    grid) which then gets scaled to a 1280x720 frame.  We pre-compute the
    resulting frame-space positions and scale them to the actual output
    resolution.

    Reference 1280x720 frame positions (baseline coords, from TypeScript):
        CH2          (107, 706)  big
        delay/27ms   (1058, 639) small
        bitrate      (1173, 639) small
        uavBat/24.3V (942, 706)  big
        flightTime   (1067, 706) big
        glsBat/0.0V  (1200, 706) big
    """
    from PIL import Image, ImageDraw
    import numpy as np

    img = Image.fromarray(frame_arr)
    draw = ImageDraw.Draw(img)

    sx = out_w / 1280.0
    sy = out_h / 720.0

    big_size   = max(16, int(27 * sy))
    small_size = max(14, int(23 * sy))
    font_big   = _get_srt_font(big_size)
    font_small = _get_srt_font(small_size)

    stroke_w = max(1, int(2 * sy))

    def srt_text(text, rx, ry, font):
        """Draw outlined text at reference 1280x720 coords scaled to output."""
        px, py = int(rx * sx), int(ry * sy)
        try:
            draw.text(
                (px, py), text, font=font,
                fill=(255, 255, 255, 255),
                stroke_width=stroke_w,
                stroke_fill=(51, 51, 51, 255),
                anchor="ls",          # left-baseline, same as Canvas fillText
            )
        except TypeError:
            # Pillow < 8.0 fallback (no anchor/stroke)
            draw.text((px, py - int(font.size * 0.75)), text,
                      font=font, fill=(255, 255, 255, 255))

    # --- draw each SRT element at the reference positions ---
    if srt_frame.get("ch"):
        srt_text(srt_frame["ch"],       107,  706, font_big)
    if srt_frame.get("delay"):
        srt_text(srt_frame["delay"],    1058, 639, font_small)
    if srt_frame.get("bitrate"):
        srt_text(srt_frame["bitrate"],  1173, 639, font_small)
    if srt_frame.get("uavBat"):
        srt_text(srt_frame["uavBat"],   942,  706, font_big)
    if srt_frame.get("flightTime"):
        srt_text(srt_frame["flightTime"], 1067, 706, font_big)
    if srt_frame.get("glsBat"):
        srt_text(srt_frame["glsBat"],   1200, 706, font_big)

    return np.array(img)


def pass1_render_osd(
    osd_reader,
    render_frame,
    resolution,
    fps,
    ffmpeg,
    tmp_path,
    srt_frames=None,
    start_offset_sec=0.0,
    output_duration_sec=None,
):
    """
    Pass 1: Render OSD frames as RGBA and pipe to ffmpeg to produce a
    transparent .mov (QuickTime RLE, RGBA).
    """
    import math

    cmd = [
        ffmpeg, "-y",
        "-f", "rawvideo", "-vcodec", "rawvideo",
        "-pix_fmt", "rgba",
        "-s", f"{resolution[0]}x{resolution[1]}",
        "-r", str(fps),
        "-i", "-",
        "-c:v", "qtrle",
        "-pix_fmt", "rgba",
        tmp_path,
    ]

    print(f"Pass 1: Rendering OSD overlay ({resolution[0]}x{resolution[1]} @ {fps} fps)…", flush=True)
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stderr=subprocess.PIPE)

    blocks = osd_reader.frame_data.to_dict(orient="records")

    # Guard against files where timestamps are still None after parsing
    # (e.g. MSPOSD v2 with only frameNumber data).
    if not blocks:
        print("Error: OSD file contains no frames.", flush=True)
        sys.exit(1)
    if blocks[0]["timestamp"] is None:
        # Synthesise evenly-spaced timestamps at the requested fps
        for i, b in enumerate(blocks):
            b["timestamp"] = i / fps

    # Some DJI OSD files contain an out-of-order first frame timestamp
    # (sample: first row at ~472s followed by 0.08s, 0.25s, ...).
    # Rendering assumes timestamps are monotonic, so normalise here.
    non_monotonic = any(
        float(blocks[i]["timestamp"]) < float(blocks[i - 1]["timestamp"])
        for i in range(1, len(blocks))
    )
    if non_monotonic:
        print(
            "Warning: OSD timestamps are not monotonic; sorting frames by timestamp.",
            flush=True,
        )
        blocks.sort(key=lambda block: float(block["timestamp"]))

    t0 = float(blocks[0]["timestamp"])
    t1 = float(blocks[-1]["timestamp"])
    render_start = max(t0, float(start_offset_sec or 0.0))
    if render_start > t1:
        print(
            f"Warning: inferred OSD start offset {render_start:.2f}s exceeds "
            f"OSD duration {t1:.2f}s; rendering from the start instead.",
            flush=True,
        )
        render_start = t0

    if output_duration_sec is not None and output_duration_sec > 0:
        render_duration = float(output_duration_sec)
        n_frames = max(1, int(math.ceil(render_duration * fps)))
    else:
        render_duration = max(1.0 / fps, t1 - render_start)
        n_frames = max(1, int((t1 - render_start) * fps) + 1)

    print(
        f"  OSD timeline window: {render_start:.2f}s → "
        f"{render_start + render_duration:.2f}s",
        flush=True,
    )

    block_idx = 0
    while block_idx + 1 < len(blocks) and render_start >= blocks[block_idx + 1]["timestamp"]:
        block_idx += 1

    for fi in range(n_frames):
        relative_time = fi / fps
        absolute_time = render_start + relative_time

        while block_idx + 1 < len(blocks) and absolute_time >= blocks[block_idx + 1]["timestamp"]:
            block_idx += 1

        frame = render_frame(blocks[block_idx]["frameContent"])

        # Overlay SRT telemetry text if available
        if srt_frames:
            srt_frame = _find_srt_frame(srt_frames, relative_time * 1000)
            if srt_frame:
                frame = _draw_srt_overlay(
                    frame, srt_frame, resolution[0], resolution[1]
                )

        proc.stdin.write(frame.tobytes())

        if fi % 300 == 0:
            pct = int(fi / n_frames * 50)
            print(f"  OSD frame {fi + 1}/{n_frames} ({pct}%)", flush=True)

    proc.stdin.close()
    # Drain stderr and wait for ffmpeg to exit.  Do NOT call communicate() here
    # because it tries to flush stdin internally and raises ValueError when
    # stdin is already closed.
    stderr = proc.stderr.read()
    proc.wait()

    if proc.returncode != 0:
        print(
            f"Error: OSD rendering failed (exit {proc.returncode}):\n"
            f"{stderr.decode(errors='replace')[-800:]}",
            flush=True,
        )
        sys.exit(1)

    print("Pass 1 complete.", flush=True)


def get_video_size(ffmpeg: str, video_path: str):
    """
    Return (width, height) of the first video stream via ffprobe (or ffmpeg -i
    stderr fallback).  Returns (None, None) if detection fails.
    """
    import re

    # Derive ffprobe path alongside the given ffmpeg binary.
    if ffmpeg in ('ffmpeg', 'ffmpeg.exe'):
        probe = 'ffprobe'
    else:
        probe = str(Path(ffmpeg).parent / 'ffprobe')
        if not Path(probe).exists():
            probe = 'ffprobe'  # fall back to system ffprobe

    # 1. Try ffprobe CSV output: "width,height"
    try:
        r = subprocess.run(
            [probe, '-v', 'error', '-select_streams', 'v:0',
             '-show_entries', 'stream=width,height',
             '-of', 'csv=p=0', video_path],
            capture_output=True, text=True, timeout=10,
        )
        m = re.search(r'(\d{3,5}),(\d{3,5})', r.stdout)
        if m:
            w, h = int(m.group(1)), int(m.group(2))
            if w >= 320 and h >= 240:
                return w, h
    except Exception:
        pass

    # 2. Fallback: parse "ffmpeg -i" stderr (always exits non-zero, so ignore rc)
    try:
        r = subprocess.run([ffmpeg, '-i', video_path],
                           capture_output=True, text=True, timeout=10)
        # Matches e.g. "1920x1080" or "3840x2160" in the stream description
        for m in re.finditer(r'(\d{3,5})x(\d{3,5})', r.stderr):
            w, h = int(m.group(1)), int(m.group(2))
            if w >= 320 and h >= 240:
                return w, h
    except Exception:
        pass

    return None, None


def get_video_duration(ffmpeg: str, video_path: str):
    """Return source video duration in seconds, or None if detection fails."""
    if ffmpeg in ("ffmpeg", "ffmpeg.exe"):
        probe = "ffprobe"
    else:
        probe = str(Path(ffmpeg).parent / "ffprobe")
        if not Path(probe).exists():
            probe = "ffprobe"

    try:
        result = subprocess.run(
            [
                probe,
                "-v",
                "error",
                "-show_entries",
                "format=duration",
                "-of",
                "default=noprint_wrappers=1:nokey=1",
                video_path,
            ],
            capture_output=True,
            text=True,
            timeout=10,
        )
        duration = float(result.stdout.strip())
        if duration > 0:
            return duration
    except Exception:
        pass

    try:
        result = subprocess.run(
            [ffmpeg, "-i", video_path],
            capture_output=True,
            text=True,
            timeout=10,
        )
        match = re.search(r"Duration: (\d+):(\d+):(\d+\.\d+)", result.stderr)
        if match:
            hours = int(match.group(1))
            minutes = int(match.group(2))
            seconds = float(match.group(3))
            duration = hours * 3600 + minutes * 60 + seconds
            if duration > 0:
                return duration
    except Exception:
        pass

    return None


def _parse_segment_stem(path_or_stem):
    stem = Path(path_or_stem).stem
    match = re.match(r"^(.*?)(\d+)$", stem)
    if not match:
        return None, None
    return match.group(1), int(match.group(2))


def _find_matching_sibling_srt(video_path):
    video = Path(video_path)
    for suffix in (".srt", ".SRT"):
        candidate = video.with_suffix(suffix)
        if candidate.exists():
            return candidate
    return None


def _infer_offset_from_video_segments(ffmpeg: str, video_path: str, osd_path: str):
    video_prefix, video_index = _parse_segment_stem(video_path)
    osd_prefix, osd_index = _parse_segment_stem(osd_path)
    if (
        video_prefix is None
        or osd_prefix is None
        or video_prefix != osd_prefix
        or osd_index >= video_index
    ):
        return None

    segment_videos = {}
    for candidate in Path(video_path).parent.iterdir():
        if not candidate.is_file() or candidate.suffix.lower() not in (".mp4", ".mov"):
            continue
        prefix, index = _parse_segment_stem(candidate)
        if prefix == video_prefix and index is not None:
            segment_videos[index] = candidate

    offset = 0.0
    for index in range(osd_index, video_index):
        segment_path = segment_videos.get(index)
        if segment_path is None:
            return None

        duration = get_video_duration(ffmpeg, str(segment_path))
        if duration is None:
            return None
        offset += duration

    return offset if offset > 0 else None


def _infer_offset_from_srt_flight_time(srt_frames):
    if not srt_frames:
        return None
    for frame in srt_frames:
        flight_time_sec = frame.get("flightTimeSec")
        if flight_time_sec is not None and flight_time_sec > 0:
            return float(flight_time_sec)
    return None


def infer_segment_start_offset(
    ffmpeg: str,
    video_path: str,
    osd_path: str,
    srt_frames=None,
):
    """
    Infer the start offset when an earlier segment's .osd is reused for a later
    split clip. Prefers exact preceding clip durations; falls back to DJI SRT
    flight time only when those videos are unavailable.
    """
    if Path(video_path).stem == Path(osd_path).stem:
        return 0.0, "exact-match OSD"

    offset = _infer_offset_from_video_segments(ffmpeg, video_path, osd_path)
    if offset is not None:
        return offset, "preceding clip durations"

    if not srt_frames:
        sibling_srt = _find_matching_sibling_srt(video_path)
        if sibling_srt is not None:
            srt_frames = parse_dji_fpv_srt(str(sibling_srt))

    offset = _infer_offset_from_srt_flight_time(srt_frames)
    if offset is not None:
        return offset, "DJI SRT flightTime (approximate)"

    return 0.0, None


def _compute_16x9_pad_width(video_w, video_h):
    """
    Return the 16:9 target canvas width for the given source dimensions,
    mirroring the wtfos-configurator VideoWorker which outputs 1280x720 with
    black pillarboxes for any non-wide source.

    If the source is already 16:9 (or wider), None is returned (no padding).
    """
    if not video_w or not video_h:
        return None
    target_w = int(video_h * 16 / 9)
    if target_w % 2:
        target_w += 1          # ensure even for H.264
    return target_w if target_w > video_w else None


def pass2_composite(ffmpeg, video_path, tmp_path, output_path, video_w=None, video_h=None):
    """
    Pass 2: composite the transparent OSD .mov onto the source video.

    When the source is not already 16:9 (e.g. a 4:3 DJI clip), a black
    pillarbox canvas is added so the output always matches the 16:9 goggles
    viewport – exactly as the wtfos-configurator VideoWorker does:
      1. Fill output canvas black.
      2. Centre the source video horizontally ( pillarboxes on both sides).
      3. Overlay the OSD at the same horizontal offset so it aligns with the
         video content.
    """
    print("Pass 2: Compositing OSD onto source video…", flush=True)

    pad_w = _compute_16x9_pad_width(video_w, video_h)

    if video_w and video_h:
        if pad_w:
            # Non-16:9 source → add black pillarboxes (wtfos goggles-peel look).
            # The OSD .mov was rendered at the full padded canvas size in pass 1,
            # so it overlays at (0, 0) — no additional scaling or x-offset needed.
            pad_x = (pad_w - video_w) // 2
            filter_complex = (
                # Pad the source to 16:9 with centred black bars
                f"[0:v]pad={pad_w}:{video_h}:{pad_x}:0:color=black[padded];"
                # OSD is already at pad_w × video_h — overlay at top-left.
                # Let the main video continue if the overlay clip ends first.
                f"[padded][1:v]overlay=0:0:eof_action=pass:repeatlast=0"
            )
        else:
            # Already 16:9 – OSD is at video_w × video_h, overlay directly.
            filter_complex = "[0:v][1:v]overlay=0:0:eof_action=pass:repeatlast=0"
    else:
        filter_complex = "[0:v][1:v]overlay=0:0:eof_action=pass:repeatlast=0"

    cmd = [
        ffmpeg, "-y",
        "-i", video_path,
        "-i", tmp_path,
        "-filter_complex", filter_complex,
        "-c:v", "libx264",
        "-crf", "23",
        "-preset", "medium",
        "-c:a", "aac",
        output_path,
    ]

    # Run ffmpeg and parse progress from stderr
    process = subprocess.Popen(cmd, stderr=subprocess.PIPE, text=True)
    total_duration = None
    pct_last = -1
    stderr_tail = []
    try:
        while True:
            line = process.stderr.readline()
            if not line:
                break
            # Keep a rolling tail for error reporting
            stderr_tail.append(line)
            if len(stderr_tail) > 40:
                stderr_tail.pop(0)
            # Parse duration from ffmpeg output
            if total_duration is None:
                m = re.search(r"Duration: (\d+):(\d+):(\d+\.\d+)", line)
                if m:
                    h, m_, s = int(m.group(1)), int(m.group(2)), float(m.group(3))
                    total_duration = h * 3600 + m_ * 60 + s
            # Parse time progress
            if total_duration:
                m = re.search(r"time=(\d+):(\d+):(\d+\.\d+)", line)
                if m:
                    h, m_, s = int(m.group(1)), int(m.group(2)), float(m.group(3))
                    cur_time = h * 3600 + m_ * 60 + s
                    pct = int(cur_time / total_duration * 100)
                    if pct != pct_last and pct % 5 == 0:
                        print(f"  Compositing: {pct}%", flush=True)
                        pct_last = pct
        process.wait()
    except Exception:
        process.kill()
        raise

    if process.returncode != 0:
        detail = "".join(stderr_tail)[-800:]
        print(
            f"Error: Compositing failed (exit {process.returncode}):\n{detail}",
            flush=True,
        )
        sys.exit(process.returncode)

    out_w = pad_w if pad_w else video_w
    print(
        f"Pass 2 complete – output: {out_w}×{video_h}"
        f"{f' (pillarboxed from {video_w}×{video_h})' if pad_w else ''}.",
        flush=True,
    )


def main():
    args = parse_args()

    # --tool path is used ONLY for font lookup – never added to sys.path.
    # OsdFileReader is always loaded from this script's own directory (_SCRIPT_DIR)
    # so that the tkinter-free bundled version is always found first.
    tool_path = Path(args.tool) if args.tool else Path("")

    # ── Check Python dependencies ─────────────────────────────────────────────
    _REQUIRED = [("numpy", "numpy"), ("PIL", "pillow"), ("pandas", "pandas")]
    missing = []
    for mod, pkg in _REQUIRED:
        try:
            __import__(mod)
        except ImportError:
            missing.append(pkg)

    if missing:
        print(
            f"Installing missing Python packages: {', '.join(missing)} …",
            flush=True,
        )
        try:
            install_attempts = [
                [sys.executable, "-m", "pip", "install", "--quiet", "--user"] + missing,
                [
                    sys.executable,
                    "-m",
                    "pip",
                    "install",
                    "--quiet",
                    "--user",
                    "--break-system-packages",
                ] + missing,
                [sys.executable, "-m", "pip", "install", "--quiet"] + missing,
            ]
            install_error = None
            for install_cmd in install_attempts:
                install_result = subprocess.run(
                    install_cmd,
                    capture_output=True,
                    text=True,
                    timeout=120,
                )
                if install_result.returncode == 0:
                    install_error = None
                    break
                install_error = (
                    install_result.stderr.strip() or install_result.stdout.strip()
                )
            if install_error:
                raise RuntimeError(install_error)
            print("Packages installed successfully.", flush=True)
        except Exception as exc:
            print(
                f"Error: Auto-install failed: {exc}\n"
                f"Please install manually:\n"
                f"  {sys.executable} -m pip install {' '.join(missing)}\n"
                f"Or for the system pip3:\n"
                f"  pip3 install {' '.join(missing)}",
                flush=True,
            )
            sys.exit(1)

    try:
        import numpy as np          # noqa: F401
        from PIL import Image       # noqa: F401
    except ImportError as exc:
        print(
            f"Error: Missing Python dependency: {exc}\n"
            f"Install with: {sys.executable} -m pip install numpy pillow pandas",
            flush=True,
        )
        sys.exit(1)

    # ── Import OsdFileReader (bundled copy in _SCRIPT_DIR, or from --tool) ────
    try:
        from OsdFileReader import OsdFileReader  # noqa: F401
    except ImportError as exc:
        print(
            f"Error: Cannot import OsdFileReader: {exc}\n"
            "Ensure OsdFileReader.py is present alongside osd_overlay.py,\n"
            "or set the O3_OverlayTool directory in Settings.",
            flush=True,
        )
        sys.exit(1)

    # ── Validate inputs ───────────────────────────────────────────────────────
    if not Path(args.osd).exists():
        print(f"Error: OSD file not found: {args.osd}", flush=True)
        sys.exit(1)
    if not Path(args.video).exists():
        print(f"Error: Video file not found: {args.video}", flush=True)
        sys.exit(1)

    font_path = resolve_font(tool_path, args.font)

    # ── Load OSD ──────────────────────────────────────────────────────────────
    print(f"Loading OSD: {args.osd}", flush=True)
    try:
        osd_reader = OsdFileReader(args.osd, framerate=args.fps)
    except Exception as exc:
        print(f"Error reading OSD file: {exc}", flush=True)
        sys.exit(1)

    print(
        f"OSD frames: {osd_reader.get_frame_count()}, "
        f"duration: {osd_reader.get_duration():.1f}s",
        flush=True,
    )

    # ── Detect video dimensions ───────────────────────────────────────────────
    # Done before building the tile renderer so we can render the OSD at
    # exactly the video resolution (avoids piping 10–20× more data than needed).
    video_w, video_h = get_video_size(args.ffmpeg, args.video)
    video_duration = get_video_duration(args.ffmpeg, args.video)
    if video_w:
        print(f"Video resolution: {video_w}×{video_h}", flush=True)
    else:
        print("Warning: could not detect video resolution – using font-native OSD size.", flush=True)
    if video_duration:
        print(f"Video duration: {video_duration:.2f}s", flush=True)

    # ── Build tile renderer ───────────────────────────────────────────────────
    from PIL import Image  # noqa: F811

    font_image = Image.open(font_path).convert("RGBA")
    # Use the FULL output canvas size (including any 16:9 pillarbox) so the OSD
    # covers the entire goggles viewport — mirroring the TypeScript VideoWorker
    # which renders on a 1280×720 frameCanvas with the video centred inside it.
    _pad_w = _compute_16x9_pad_width(video_w, video_h)
    _output_w = _pad_w if _pad_w else video_w
    target_size = (_output_w, video_h) if _output_w and video_h else None
    resolution, render_frame = build_tile_renderer(font_image, osd_reader, target_size=target_size)
    print(f"OSD render resolution: {resolution[0]}×{resolution[1]}", flush=True)

    # ── Parse DJI FPV SRT (optional) ──────────────────────────────────────────
    srt_frames = None
    if args.srt and Path(args.srt).exists():
        print(f"Parsing SRT telemetry: {args.srt}", flush=True)
        srt_frames = parse_dji_fpv_srt(args.srt)
        if srt_frames:
            print(f"  {len(srt_frames)} DJI FPV SRT entries parsed.", flush=True)
        else:
            print("  SRT file is not in DJI FPV goggle format – skipping SRT overlay.", flush=True)
            srt_frames = None

    if args.osd_start_offset is not None:
        osd_start_offset = max(0.0, float(args.osd_start_offset))
        print(
            f"OSD start offset: {osd_start_offset:.2f}s (explicit override)",
            flush=True,
        )
    else:
        osd_start_offset, offset_source = infer_segment_start_offset(
            args.ffmpeg,
            args.video,
            args.osd,
            srt_frames=srt_frames,
        )
        if offset_source == "exact-match OSD":
            print("OSD start offset: 0.00s (exact-match OSD)", flush=True)
        elif offset_source:
            print(
                f"OSD start offset: {osd_start_offset:.2f}s "
                f"({offset_source})",
                flush=True,
            )
        else:
            print(
                "Warning: reusing an earlier OSD file but could not infer the "
                "segment offset; rendering from the OSD start.",
                flush=True,
            )

    # ── Run two-pass pipeline ─────────────────────────────────────────────────
    tmp_dir = Path(args.output).parent
    tmp_dir.mkdir(parents=True, exist_ok=True)
    tmp_fd, tmp_path = tempfile.mkstemp(suffix="_osd_overlay.mov", dir=tmp_dir)
    os.close(tmp_fd)

    try:
        pass1_render_osd(
            osd_reader,
            render_frame,
            resolution,
            args.fps,
            args.ffmpeg,
            tmp_path,
            srt_frames=srt_frames,
            start_offset_sec=osd_start_offset,
            output_duration_sec=video_duration,
        )
        pass2_composite(args.ffmpeg, args.video, tmp_path, args.output, video_w, video_h)
    finally:
        if Path(tmp_path).exists():
            os.unlink(tmp_path)

    print("✅ Process completed successfully.", flush=True)


if __name__ == "__main__":
    main()
