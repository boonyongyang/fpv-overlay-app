"""
OsdFileReader.py – Bundled copy of the O3_OverlayTool OSD parser.
Original source: https://github.com/xNuclearSquirrel/O3_OverlayTool
Trimmed for embedded use: tkinter GUI helpers removed.
"""

import struct
import pandas as pd


class OsdFileReader:
    def __init__(self, file_path, framerate=60):
        self.file_path = file_path
        self.header = {}
        self.frame_data = pd.DataFrame(
            columns=["timestamp", "frameNumber", "frameSize", "frameContent"]
        )
        self.parsed_data_df = None
        self.frame_rate = framerate
        self.duration = None
        self.load_file()

    # ── File loading ──────────────────────────────────────────────────────────

    def load_file(self):
        with open(self.file_path, "rb") as file:
            header_bytes = file.read(40)
            if len(header_bytes) < 40:
                file.seek(0)
                self._parse_old_format(file)
            elif header_bytes[:7] == b"MSPOSD\x00":
                file.seek(0)
                self._parse_old_format(file)
            else:
                self._parse_djo3_format(file, header_bytes)

        # Always normalise: fill timestamps from frame numbers (or vice-versa)
        # if one of the two is missing.  This is required for MSPOSD v2 files
        # which store only frameNumber and have timestamp=None.
        self.generate_pseudo_frames(self.frame_rate)

    def _parse_djo3_format(self, file, header_bytes):
        firmware_part = header_bytes[:4]
        header_part = header_bytes[4:36]
        signature = header_bytes[36:40]

        self.header["magic"] = firmware_part.decode("utf-8", errors="ignore").strip("\x00")
        self.header["version"] = 99

        if signature == b"DJO3":
            numCols = 53
            numRows = 20
        else:
            numCols = header_bytes[0x24]
            numRows = header_bytes[0x26]

        framesize = numCols * numRows
        print(framesize, numCols, numRows)

        self.header["config"] = {
            "charWidth": numCols,
            "charHeight": numRows,
            "fontWidth": 0,
            "fontHeight": 0,
            "xOffset": 0,
            "yOffset": 0,
            "fontVariant": "",
            "headerPart": header_part.decode("utf-8", errors="ignore"),
            "signature": signature.decode("utf-8", errors="ignore"),
        }

        frames = []
        while True:
            time_data = file.read(4)
            if len(time_data) < 4:
                break
            (delta_time_ms,) = struct.unpack("<I", time_data)
            timestamp_sec = float(delta_time_ms) / 1000.0

            frame_bytes = file.read(framesize * 2)
            if len(frame_bytes) < framesize * 2:
                break

            frame_content = []
            for i in range(0, len(frame_bytes), 2):
                val = struct.unpack("<H", frame_bytes[i : i + 2])[0]
                frame_content.append(val)

            frames.append(
                {
                    "timestamp": timestamp_sec,
                    "frameNumber": None,
                    "frameSize": framesize,
                    "frameContent": frame_content,
                }
            )

        self.frame_data = pd.DataFrame(frames)

    def _parse_old_format(self, file):
        self.header["magic"] = file.read(7).decode("utf-8")
        (self.header["version"],) = struct.unpack("<H", file.read(2))

        self.header["config"] = {
            "charWidth": struct.unpack("<B", file.read(1))[0],
            "charHeight": struct.unpack("<B", file.read(1))[0],
            "fontWidth": struct.unpack("<B", file.read(1))[0],
            "fontHeight": struct.unpack("<B", file.read(1))[0],
            "xOffset": struct.unpack("<H", file.read(2))[0],
            "yOffset": struct.unpack("<H", file.read(2))[0],
            "fontVariant": file.read(5).decode("utf-8").strip("\x00"),
        }

        frames = []
        height = self.header["config"]["charHeight"]

        while True:
            try:
                if self.header["version"] == 3:
                    (timestamp,) = struct.unpack("<d", file.read(8))
                    (frame_size,) = struct.unpack("<I", file.read(4))
                    frame_data = file.read(frame_size)
                    if len(frame_data) < frame_size:
                        break
                    frame_data = list(frame_data)
                    frames.append(
                        {
                            "timestamp": timestamp,
                            "frameNumber": None,
                            "frameSize": frame_size,
                            "frameContent": frame_data,
                        }
                    )
                elif self.header["version"] == 2:
                    frame_number, frame_size = struct.unpack("<II", file.read(8))
                    raw_data = file.read(2 * frame_size)
                    if len(raw_data) < (2 * frame_size):
                        break
                    frame_data = []
                    for i in range(0, len(raw_data), 2):
                        val = struct.unpack("<H", raw_data[i : i + 2])[0]
                        frame_data.append(val)
                    frame_data = [
                        frame_data[i * height + j]
                        for j in range(height)
                        for i in range(len(frame_data) // height)
                    ]
                    frames.append(
                        {
                            "timestamp": None,
                            "frameNumber": frame_number,
                            "frameSize": frame_size,
                            "frameContent": frame_data,
                        }
                    )
                else:
                    print(f"Unsupported version: {self.header['version']}")
                    break
            except (struct.error, EOFError):
                break

        self.frame_data = pd.DataFrame(frames)

    # ── Helpers ───────────────────────────────────────────────────────────────

    def generate_pseudo_frames(self, frame_rate):
        self.frame_rate = frame_rate
        if (
            "timestamp" in self.frame_data.columns
            and self.frame_data["timestamp"].isnull().all()
        ):
            if (
                "frameNumber" in self.frame_data.columns
                and not self.frame_data["frameNumber"].isnull().all()
            ):
                self.frame_data["timestamp"] = (
                    self.frame_data["frameNumber"] / frame_rate
                )
        elif (
            "frameNumber" in self.frame_data.columns
            and self.frame_data["frameNumber"].isnull().all()
        ):
            if (
                "timestamp" in self.frame_data.columns
                and not self.frame_data["timestamp"].isnull().all()
            ):
                self.frame_data["frameNumber"] = (
                    self.frame_data["timestamp"] * frame_rate
                ).astype(int)

    def get_frame_count(self):
        return len(self.frame_data)

    def get_duration(self):
        if (
            "timestamp" in self.frame_data.columns
            and not self.frame_data["timestamp"].isnull().all()
        ):
            self.duration = self.frame_data["timestamp"].max()
        elif self.frame_rate:
            self.duration = self.get_frame_count() / self.frame_rate
        return self.duration

    def calculate_frame_rate(self):
        if (
            "timestamp" in self.frame_data.columns
            and not self.frame_data["timestamp"].isnull().all()
        ):
            timestamps = self.frame_data["timestamp"].dropna()
            if len(timestamps) > 1:
                diffs = timestamps.diff().dropna()
                avg_dt = diffs.mean()
                if avg_dt > 0:
                    self.frame_rate = 1.0 / avg_dt
        return self.frame_rate

    def print_info(self):
        print("Header Information:")
        for key, val in self.header.items():
            print(f"  {key}: {val}")
        print(f"\nTotal Frames: {self.get_frame_count()}")
        print(f"Duration: {self.get_duration()} seconds")
        print(f"Frame Rate: {self.calculate_frame_rate()} fps")
