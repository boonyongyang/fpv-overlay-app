# Privacy Policy

FPV Overlay Toolbox is a desktop application for processing flight videos on the
user's machine.

## What the app processes

- local video files such as `.mp4` and `.mov`
- local telemetry files such as `.srt` and `.osd`
- local output paths chosen by the user

The overlay rendering pipeline runs locally. Flight media is not uploaded to a
server as part of normal app usage.

## Local overlay stats

The app stores local overlay statistics on the device to power the in-app
`Stats & Settings` view.

This local data can include:

- completed, failed, and cancelled overlay counts
- overlay-type counts for SRT, OSD, and combined renders
- total and average render time
- a bounded recent-run history with timestamps, source names, statuses, and
  short failure summaries

This information remains on the local machine unless the user manually copies,
exports, or shares it outside the app.

## Contact

Use the public issue tracker for non-sensitive privacy questions related to the
desktop app's local-only behavior and stored stats.
