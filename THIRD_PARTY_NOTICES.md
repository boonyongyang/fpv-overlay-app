# Third-Party Notices

This project includes or is informed by third-party tooling and reference implementations.

## Renderer references

- The OSD layout and rendering behavior were informed by the upstream `wtfos-configurator` `osd-overlay` implementation:
  - https://github.com/fpv-wtf/wtfos-configurator/tree/master/src/osd-overlay

- `assets/bin/OsdFileReader.py` is derived from the O3_OverlayTool project:
  - https://github.com/xNuclearSquirrel/O3_OverlayTool/releases

## Bundled assets and runtime notes

- The `assets/bin/fonts/` directory contains bundled renderer font sprite sheets used by the overlay runtime.
- FFmpeg binaries are not committed to this repository, but packaging scripts download and bundle FFmpeg during desktop release preparation.

## Maintainer follow-up before broad binary distribution

Before publishing public binary releases, confirm and document:

- redistribution rights for every committed font sprite sheet
- attribution requirements for derived renderer components
- FFmpeg license notice obligations for the chosen binary distribution source

This repository currently documents provenance, but it does not claim that every binary-release redistribution requirement has been fully validated yet.
