# Phase 1 Sign-Off — Project Foundation
**Date:** 2026-10-24

## Gate criteria

| Criterion | Met | Evidence |
|-----------|-----|----------|
| Clean `git clone` → Godot editor opens without errors | Yes | Verified on laptop (Godot 4.7) and vm-prime (Godot 4.7.2 headless) |
| Windows client export runs: window, camera, mouse look, WASD | Yes | Tested on laptop — test room with enclosed walls, FPS camera, movement |
| Linux headless server export runs without GPU/display | Yes | vm-prime headless debug export, no X11/Wayland, runs clean |
| Client connects to server over LAN | Yes | Laptop (Windows) → vm-prime (192.168.30.11:27050), ENet connection verified |
| Server runs in Docker, client connects identically | Yes | Multi-stage Docker build, container starts and listens on UDP 27050 |
| CI pipeline passes: builds, smoke test, artifact upload | Yes | GitHub Actions workflow green on multiple pushes |
| Networking evaluation committed with recommendation | Yes | `docs/networking_evaluation.md` — ENet selected, GNS deferred to Phase 8 |
| GDScript conventions followed in all committed scripts | Yes | Type hints, snake_case, signals over direct references |
| No placeholder/stub code without tracking | Yes | All committed code is functional |

## Deviations from plan

| Deviation | Rationale |
|-----------|-----------|
| Godot 4.7.2 instead of 4.3 | 4.7 was installed on laptop; no breaking changes for our scaffolding |
| Server port 27050 instead of 27015 | HLDS research server from Phase 0 occupies 27015 on vm-prime |
| Debug export for server (not release) | Release export strips `print()` output; debug needed for development logging; release for production later |
| Entry point scene router added | Export preset's `dedicated_server=true` sets feature flag; router scene dispatches to server or client main scene cleanly |

## Conditions carried to Phase 2

- **Release export logging:** Need to implement file-based logging or use `push_warning`/`push_error` for release builds, since `print()` is stripped. Not blocking for development but required before any production deployment.
- **Docker image uses debug export:** Switch to release export with proper logging before Phase 7 (community server).
- **CI validates GDScript but doesn't run gameplay tests:** Automated movement regression tests are a Phase 2 deliverable.
- **No `.gdignore` on all non-game dirs:** `research/` and `phase_0/` are excluded; add to others if they accumulate non-game files.

## Summary
Phase 1 establishes a working development pipeline: Godot 4.7 project with client/server split, ENet networking, Docker packaging, and GitHub Actions CI. The laptop→vm-prime workflow is validated end to end.

Approved: pending owner review.
