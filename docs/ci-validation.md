# CI Validation Guide

## Overview

GitHub Actions runs automated validation on every pull request to `main` and on manual dispatch. The workflow validates GDScript syntax, checks for missing resources, runs all test suites, and exports a Linux server binary.

## Local Validation Commands

Run these from the project root using Godot 4.7.2.

### GDScript syntax check (single file)

```
godot --headless --check-only --script res://shared/scripts/player_movement.gd
```

### Import project (regenerates .godot/imported/)

```
godot --headless --import
```

### Test suites

| Suite | Command | What it covers |
|---|---|---|
| Movement | `godot --headless --path . -- --test` | Ground speed, jump height, friction, air accel, bhop, ducking |
| Combat | `godot --headless --path . -- --test-combat` | Damage formulas, armor, range falloff, wall pen, grenades, accuracy |
| Network | `godot --headless --path . -- --test-network` | Serialization roundtrips, delta compression, packet sizes |
| Validation | `godot --headless --path . -- --test-validation` | Collision dimensions, hitbox exclusions, physics config |
| Benchmark | `godot --headless --path . -- --bench` | Server tick time, bandwidth, prediction replay, lag comp |

### Run all tests locally

```
godot --headless --path . -- --test-network
godot --headless --path . -- --test
godot --headless --path . -- --test-combat
godot --headless --path . -- --test-validation
```

## Reading GitHub Actions Failures

1. Open the failed PR check on GitHub → click "Details"
2. Each job has named steps. Look for the red X:
   - **Validate all GDScript files** — a script has a parse error. The log shows which `res://` path failed.
   - **Check for missing resources** — a `.tscn`, `.tres`, or `.gd` file references a `res://` path that doesn't exist. Warnings list each missing path.
   - **Movement/Combat/Network/Validation tests** — a test assertion failed. Look for `FAIL` lines in the output. The test name and expected vs actual values are printed.
   - **Export server** — the Godot export preset "Linux Server" couldn't build. Check `export_presets.cfg`.
   - **Smoke test server** — the exported binary crashed on startup (exit code != 124 timeout).

3. If the **Install Godot** step fails, the download URL may have changed. Check that `GODOT_VERSION` in the workflow matches an available release at `github.com/godotengine/godot/releases`.

## Workflow Triggers

- **Pull request to main** — runs automatically
- **Push to main** — runs automatically
- **Manual dispatch** — go to Actions → "Build and Test" → "Run workflow"

## PHASE_X_SIGNOFF.md Workflow

The CI pipeline does not replace the existing phase signoff process. Phase signoff documents (`PHASE_1_SIGNOFF.md`, `PHASE_2_SIGNOFF.md`, etc.) remain the authoritative approval mechanism for major milestones. CI validates code correctness; signoffs validate design intent.
