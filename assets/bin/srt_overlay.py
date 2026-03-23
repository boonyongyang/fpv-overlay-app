#!/usr/bin/env python3
"""
srt_overlay.py -- DJI SRT Telemetry HUD Overlay
=================================================
Parses a DJI O3 .srt telemetry file and renders a HUD overlay onto the source
video using ffmpeg drawtext filters, matching the output format of the
wtfos-configurator osd-overlay tool.

Layout (mirrors wtfos-configurator worker.ts drawText positions, scaled to
the actual video resolution from the reference 1280×810 OSD canvas):
  Top-left   : Date / time
  Top-right  : GPS lat / lon
  Bottom-left: Altitude  H.Speed  V.Speed  Distance
  Bottom strip (above bottom-left): ISO  Shutter  F-stop  EV  CT

The output is always 16:9 with black pillarboxes for non-16:9 source clips,
exactly as the wtfos-configurator VideoWorker produces.

Usage:
    python3 srt_overlay.py --srt <file.srt> --video <file.mp4> \\
                           --output <out.mp4>                   \\
                           [--ffmpeg <ffmpeg_path>]

On success the last printed line is exactly:
    ✅ Process completed successfully.
"""

import argparse
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

_SCRIPT_DIR = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args():
    p = argparse.ArgumentParser(description="DJI SRT Telemetry HUD Overlay")
    p.add_argument("--srt",    required=True)
    p.add_argument("--video",  required=True)
    p.add_argument("--output", required=True)
    p.add_argument("--tool",   default="")   # kept for CLI compat, unused
    p.add_argument("--font",   default="")   # kept for CLI compat, unused
    p.add_argument("--ffmpeg", default="ffmpeg")
    p.add_argument("--fps",    type=float, default=30.0)
    return p.parse_args()


# ---------------------------------------------------------------------------
# Video size detection
# ---------------------------------------------------------------------------

def get_video_size(ffmpeg, video_path):
    probe = "ffprobe"
    if ffmpeg not in ("ffmpeg", "ffmpeg.exe"):
        candidate = str(Path(ffmpeg).parent / "ffprobe")
        if Path(candidate).exists():
            probe = candidate
    try:
        r = subprocess.run(
            [probe, "-v", "error", "-select_streams", "v:0",
             "-show_entries", "stream=width,height", "-of", "csv=p=0", video_path],
            capture_output=True, text=True, timeout=10)
        m = re.search(r"(\d{3,5}),(\d{3,5})", r.stdout)
        if m:
            w, h = int(m.group(1)), int(m.group(2))
            if w >= 320 and h >= 240:
                return w, h
    except Exception:
        pass
    try:
        r = subprocess.run([ffmpeg, "-i", video_path],
                           capture_output=True, text=True, timeout=10)
        for m in re.finditer(r"(\d{3,5})x(\d{3,5})", r.stderr):
            w, h = int(m.group(1)), int(m.group(2))
            if w >= 320 and h >= 240:
                return w, h
    except Exception:
        pass
    return None, None


# ---------------------------------------------------------------------------
# DJI SRT parser
# ---------------------------------------------------------------------------

def _find(pat, text, cast=None, default=None):
    m = re.search(pat, text, re.IGNORECASE)
    if not m:
        return default
    try:
        return cast(m.group(1).strip()) if cast else m.group(1).strip()
    except (ValueError, TypeError):
        return default


def ts_to_sec(ts):
    ts = ts.strip().replace(",", ".")
    h, m, s = ts.split(":")
    return int(h) * 3600 + int(m) * 60 + float(s)


def parse_dji_srt(srt_path):
    """Return list of dicts: start/end (float seconds) + telemetry fields."""
    raw = Path(srt_path).read_text(encoding="utf-8", errors="replace")
    raw = re.sub(r"<[^>]+>", "", raw)
    raw = re.sub(r"\[/?font[^\]]*\]", "", raw)
    frames = []
    for block in re.split(r"\n{2,}", raw.strip()):
        lines = [ln.strip() for ln in block.splitlines() if ln.strip()]
        if len(lines) < 2:
            continue
        ti = next((i for i, ln in enumerate(lines) if "-->" in ln), None)
        if ti is None:
            continue
        parts = lines[ti].split("-->")
        if len(parts) < 2:
            continue
        try:
            start, end = ts_to_sec(parts[0]), ts_to_sec(parts[1])
        except Exception:
            continue
        body = " ".join(lines[ti + 1:])
        fr = {"start": start, "end": end}
        fr["lat"] = _find(r"latitude\s*[:\s]\s*([-\d.]+)", body, float)
        fr["lon"] = _find(r"longitude\s*[:\s]\s*([-\d.]+)", body, float)
        if fr["lat"] is None:
            gm = re.search(r"GPS\s*\(\s*([-\d.]+)\s*,\s*([-\d.]+)", body, re.I)
            if gm:
                fr["lon"], fr["lat"] = float(gm.group(1)), float(gm.group(2))
        fr["rel_alt"] = (
            _find(r"rel_alt\s*[:\s]\s*([-\d.]+)", body, float)
            or _find(r"altitude_above_seaLevel\s*[:\s]\s*([-\d.]+)", body, float)
            or _find(r"\bH\s*[:\s]\s*([\d.]+)\s*m\b", body, float)
        )
        fr["abs_alt"]  = _find(r"abs_alt\s*[:\s]\s*([-\d.]+)", body, float)
        fr["h_speed"]  = (
            _find(r"H\.S\s*[:\s]\s*([\d.]+)\s*m/s", body, float)
            or _find(r"H\.S\s+([\d.]+)m/s", body, float)
            or _find(r"speed_all\s*[:\s]\s*([\d.]+)", body, float)
        )
        fr["v_speed"]  = (
            _find(r"V\.S\s*[:\s]\s*([-\d.]+)\s*m/s", body, float)
            or _find(r"V\.S\s+([-\d.]+)m/s", body, float)
        )
        fr["distance"] = _find(r"\bD\s*[:\s]\s*([\d.]+)\s*m\b", body, float)
        fr["iso"]     = _find(r"\biso\s*[:\s]\s*(\d+)", body, int) or _find(r"\bISO\s+(\d+)", body, int)
        fr["shutter"] = _find(r"shutter\s*[:\s]\s*([\d/]+)", body)
        fr["fnum"]    = _find(r"fnum\s*[:\s]\s*([\d.]+)", body, float)
        fr["ev"]      = _find(r"\bev\s*[:\s]\s*([-\d.]+)", body, float)
        fr["ct"]      = _find(r"\bct\s*[:\s]\s*(\d+)", body, int)
        dtm = re.search(r"(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})", body)
        fr["datetime_str"] = dtm.group(1) if dtm else None
        frames.append(fr)
    return frames


# ---------------------------------------------------------------------------
# SRT → timed subtitle file for ffmpeg drawtext sendcmd
#
# We use the ffmpeg `subtitles` filter approach: write each telemetry field as
# a separate ASS subtitle track that ffmpeg renders as styled text.
# But the cleanest approach for pixel-perfect positioning is to write a
# per-frame drawtext command file (sendcmd).  However, the most compatible
# approach that doesn't require font files is to build a single ASS file where
# each dialogue line is styled and positioned using ASS override tags.
# ---------------------------------------------------------------------------

def _esc_ass(text):
    """Escape special characters for ASS subtitle text."""
    return text.replace("\\", "\\\\").replace("{", "\\{").replace("}", "\\}")


def _fmt(v, unit="", dec=1, fb="---"):
    return fb if v is None else f"{v:.{dec}f}{unit}"


def _ass_ts(seconds):
    """Convert float seconds to ASS timestamp H:MM:SS.cc"""
    cs = int(round(seconds * 100))
    h = cs // 360000; cs %= 360000
    m = cs // 6000;   cs %= 6000
    s = cs // 100;    cs %= 100
    return f"{h}:{m:02d}:{s:02d}.{cs:02d}"


# ASS alignment codes (numpad layout): 1=BL 2=BC 3=BR 7=TL 8=TC 9=TR
_ALIGN_BL = 1
_ALIGN_TR = 3
_ALIGN_TL = 7


def build_ass(frames, out_w, out_h, margin=28):
    """
    Build an ASS subtitle document that renders DJI O3 telemetry as styled
    text positioned to match the wtfos-configurator osd-overlay layout.

    The wtfos worker.ts draws SRT elements on the OSD canvas (1280×810 in
    full-canvas coords).  We replicate the same visual zones:

      Top-left  (align 7): date-time
      Top-right (align 3): GPS lat/lon
      Bottom-left (align 1): ALT / H.Speed / V.Speed / Distance (big)
      Second-from-bottom-left (align 1): ISO / Shutter / F-stop / EV / CT
    """
    big_size   = max(18, int(out_h * 30 / 810))   # ~30px on 810 h reference
    small_size = max(14, int(out_h * 26 / 810))   # ~26px on 810 h reference
    mx = margin
    my = margin

    # Build stroke style: dark outline + white fill (mirrors wtfos drawText)
    def style(size):
        # ASS style string embedded inline via override tags
        return f"{{\\fs{size}\\c&HFFFFFF&\\3c&H333333&\\bord2\\shad0}}"

    big   = style(big_size)
    small = style(small_size)

    lines = []
    lines.append("[Script Info]")
    lines.append("ScriptType: v4.00+")
    lines.append(f"PlayResX: {out_w}")
    lines.append(f"PlayResY: {out_h}")
    lines.append("WrapStyle: 0")
    lines.append("")
    lines.append("[V4+ Styles]")
    lines.append(
        "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, "
        "OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, "
        "ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, "
        "Alignment, MarginL, MarginR, MarginV, Encoding"
    )
    # Base style – we override everything per-line with inline tags anyway
    lines.append(
        f"Style: Default,Arial,{big_size},&H00FFFFFF,&H000000FF,"
        f"&H00333333,&H00000000,0,0,0,0,100,100,0,0,1,2,0,7,{mx},{mx},{my},1"
    )
    lines.append("")
    lines.append("[Events]")
    lines.append(
        "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text"
    )

    def dialogue(start, end, alignment, marginv, text):
        return (
            f"Dialogue: 0,{_ass_ts(start)},{_ass_ts(end)},Default,,"
            f"{mx},{mx},{marginv},,{{\\an{alignment}}}{text}"
        )

    for fr in frames:
        s, e = fr["start"], fr["end"]

        # ── Top-left: date/time ─────────────────────────────────────────────
        if fr.get("datetime_str"):
            t = _esc_ass(fr["datetime_str"])
            lines.append(dialogue(s, e, _ALIGN_TL, my, f"{small}{t}"))

        # ── Top-right: GPS ──────────────────────────────────────────────────
        lat, lon = fr.get("lat"), fr.get("lon")
        if lat is not None and lon is not None:
            ns = "N" if lat >= 0 else "S"
            ew = "E" if lon >= 0 else "W"
            gps = _esc_ass(f"{abs(lat):.5f}°{ns}  {abs(lon):.5f}°{ew}")
            lines.append(dialogue(s, e, _ALIGN_TR, my, f"{small}{gps}"))

        # ── Second row from bottom: camera settings ─────────────────────────
        cam_parts = []
        if fr.get("iso")     is not None: cam_parts.append(f"ISO {fr['iso']}")
        if fr.get("shutter"):
            sh = str(fr["shutter"])
            cam_parts.append(sh if "/" in sh else f"1/{sh}")
        if fr.get("fnum")    is not None: cam_parts.append(f"f/{fr['fnum']:.1f}")
        if fr.get("ev")      is not None: cam_parts.append(f"EV {fr['ev']:+.1f}")
        if fr.get("ct")      is not None: cam_parts.append(f"{fr['ct']}K")
        if cam_parts:
            cam_text = _esc_ass("   ".join(cam_parts))
            # Place camera row above the main telemetry row
            cam_mv = my + big_size + 6
            lines.append(dialogue(s, e, _ALIGN_BL, cam_mv, f"{small}{cam_text}"))

        # ── Bottom-left: main telemetry bar ─────────────────────────────────
        tele_parts = []
        if fr.get("rel_alt") is not None:
            tele_parts.append(f"ALT {_fmt(fr['rel_alt'], 'm')}")
        if fr.get("h_speed") is not None:
            tele_parts.append(f"HS {_fmt(fr['h_speed'], 'm/s')}")
        if fr.get("v_speed") is not None:
            tele_parts.append(f"VS {_fmt(fr['v_speed'], 'm/s')}")
        if fr.get("distance") is not None:
            tele_parts.append(f"D {_fmt(fr['distance'], 'm', 0)}")
        if tele_parts:
            tele_text = _esc_ass("   ".join(tele_parts))
            lines.append(dialogue(s, e, _ALIGN_BL, my, f"{big}{tele_text}"))

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# 16:9 pillarbox helper (mirrors wtfos VideoWorker black-fill + centre logic)
# ---------------------------------------------------------------------------

def _compute_16x9_pad_width(vw, vh):
    """Return 16:9 canvas width or None if source is already 16:9 or wider."""
    if not vw or not vh:
        return None
    target_w = int(vh * 16 / 9)
    if target_w % 2:
        target_w += 1
    return target_w if target_w > vw else None


# ---------------------------------------------------------------------------
# Composite: burn ASS subtitles + pillarbox via a single ffmpeg pass
# ---------------------------------------------------------------------------

def composite(ffmpeg, video, ass_path, out, vw=None, vh=None):
    """
    Single-pass ffmpeg render:
      1. (Optional) pad source to 16:9 with black pillarboxes.
      2. Burn ASS subtitle HUD via the `ass` filter.

    Mirrors the wtfos-configurator VideoWorker output format.
    """
    print("Rendering SRT HUD onto video...", flush=True)

    pad_w = _compute_16x9_pad_width(vw, vh)

    # Escape backslashes in path for ffmpeg filter string (Windows safe too)
    ass_esc = ass_path.replace("\\", "/").replace(":", "\\:")

    if vw and vh:
        if pad_w:
            pad_x = (pad_w - vw) // 2
            filter_complex = (
                f"[0:v]pad={pad_w}:{vh}:{pad_x}:0:color=black[padded];"
                f"[padded]ass='{ass_esc}'[out]"
            )
            map_arg = "[out]"
        else:
            filter_complex = f"[0:v]ass='{ass_esc}'[out]"
            map_arg = "[out]"
    else:
        filter_complex = f"[0:v]ass='{ass_esc}'[out]"
        map_arg = "[out]"

    cmd = [
        ffmpeg, "-y",
        "-i", video,
        "-filter_complex", filter_complex,
        "-map", map_arg,
        "-map", "0:a?",
        "-c:v", "libx264", "-crf", "23", "-preset", "medium",
        "-c:a", "aac",
        out,
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
                        print(f"  Rendering: {pct}%", flush=True)
                        pct_last = pct
        process.wait()
    except Exception:
        process.kill()
        raise

    if process.returncode != 0:
        detail = "".join(stderr_tail)[-800:]
        print(
            f"Error: Render failed (exit {process.returncode}):\n{detail}",
            flush=True,
        )
        sys.exit(process.returncode)

    out_w = pad_w if pad_w else vw
    print(
        f"Render complete – output: {out_w}×{vh}"
        f"{f' (pillarboxed from {vw}×{vh})' if pad_w else ''}.",
        flush=True,
    )


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

def main():
    args = parse_args()

    if not Path(args.srt).exists():
        print(f"Error: SRT file not found: {args.srt}", flush=True)
        sys.exit(1)
    if not Path(args.video).exists():
        print(f"Error: Video file not found: {args.video}", flush=True)
        sys.exit(1)

    print(f"Parsing SRT telemetry: {args.srt}", flush=True)
    frames = parse_dji_srt(args.srt)
    if not frames:
        print(
            "Error: No telemetry frames found.\n"
            "Ensure this is a DJI telemetry SRT (not a plain subtitle file).",
            flush=True,
        )
        sys.exit(1)
    print(f"  {len(frames)} entries parsed.", flush=True)

    vw, vh = get_video_size(args.ffmpeg, args.video)
    if vw:
        print(f"Video: {vw}x{vh}", flush=True)
    else:
        print("Warning: could not detect video size; using default HUD layout.", flush=True)
        vw, vh = 1280, 720

    # Determine output canvas dimensions (may be pillarboxed)
    pad_w = _compute_16x9_pad_width(vw, vh)
    canvas_w = pad_w if pad_w else vw
    canvas_h = vh

    print(f"Building ASS subtitle HUD ({canvas_w}×{canvas_h})...", flush=True)
    ass_content = build_ass(frames, canvas_w, canvas_h)

    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    tmp_fd, ass_path = tempfile.mkstemp(
        suffix="_srt_hud.ass", dir=Path(args.output).parent
    )
    try:
        with os.fdopen(tmp_fd, "w", encoding="utf-8") as f:
            f.write(ass_content)

        composite(args.ffmpeg, args.video, ass_path, args.output, vw, vh)
    finally:
        try:
            if Path(ass_path).exists():
                os.unlink(ass_path)
        except OSError:
            pass

    print("\u2705 Process completed successfully.", flush=True)


if __name__ == "__main__":
    main()
