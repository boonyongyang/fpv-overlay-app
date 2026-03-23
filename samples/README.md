## Samples

This directory keeps lightweight metadata for the regression sample pack used by FPV Overlay Toolbox.

The raw DJI media files are intentionally not committed to the source repository. They are large enough to make a normal clone unnecessarily heavy, and they are better distributed as release assets.

See [manifest.json](manifest.json) for the expected sample pack contents.

### Why the sample pack exists

The pack is useful for validating:

- exact-match video + SRT + OSD pairing
- split DJI recordings where a later clip reuses an earlier `.osd`
- queue behavior when later clips need inferred OSD offsets

### Expected files

- `DJIG0024.mp4`
- `DJIG0024.osd`
- `DJIG0024.srt`
- `DJIG0025.mp4`
- `DJIG0025.srt`

Generated renders, previews, and temporary outputs remain ignored by git.
