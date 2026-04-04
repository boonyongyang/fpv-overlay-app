# Contributing

## Working Style

- Prefer focused pull requests with one clear behavioral goal.
- Keep queue logic, shell/workspace state, and platform/runtime concerns separated.
- Preserve the local-only product posture. Do not introduce analytics or cloud behavior casually.
- When changing packaging scripts or runtime resolution, document the change in the relevant script comments or README section.
- Read [ARCHITECTURE.md](ARCHITECTURE.md) before changing queue flow, render orchestration, or release packaging.

## Setup

The repo pins Flutter with `.fvmrc`.

```bash
fvm flutter pub get
```

Useful commands:

```bash
make pub-get
make bootstrap
make analyze
make test
```

## Contribution Targets

High-value areas:

- queue workflow improvements
- desktop UX polish
- renderer/runtime diagnostics
- packaging and installer polish
- edge cases around file matching and relinking

## Pull Requests

- Describe the user-visible change and the implementation approach.
- Call out platform-specific assumptions when touching `android/`, `ios/`, `macos/`, `windows/`, or packaging scripts.
- If you skip verification, say so explicitly in the PR description.

## Scope Notes

- Desktop is the public support target for this repo.
- Dart package naming remains `fpv_overlay_app` even though the public product name is FPV Overlay Toolbox.
- Third-party renderer assets require care. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) before redistributing new bundled assets.
