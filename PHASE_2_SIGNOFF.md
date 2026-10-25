# Phase 2 Sign-Off — Movement Laboratory
**Date:** 2026-10-25

## Gate criteria

| Criterion | Met | Evidence |
|-----------|-----|----------|
| All Phase 0 reference measurements pass within tolerance | Yes | 9/9 automated regression tests pass: ground speed 250 u/s, jump height 1.132m (±0.011 of 1.143m target), friction decel, air accel, bhop preserve/degrade, step-up, duck hull |
| Movement feels comparable to CS 1.6 reference | Yes | Owner tested all movement range sections: stairs, ramps, gaps, crouch tunnel, ladders, bhop corridor, height walls — approved |
| A&D modifications work as designed | Yes | Bhop progressive degradation after 2 free hops (automated test confirms), ladder 200 u/s cap, no angle exploits |
| Telemetry HUD shows accurate real-time data | Yes | Speed, VSpeed, State, Bhop count, Position, Jump height/air peak displayed; debug instrumentation cleaned up |
| Regression tests pass headless on vm-prime | Yes | `godot --headless --path . -- --test` → 9/9 ALL PASSED, exit code 0 |
| CI runs regression tests on push | No | Deferred — see deviations below |
| No move_and_slide() in movement code | Yes | Fully custom `move_and_collide()` simulation loop in `player_movement.gd` |
| All movement constants configurable | Yes | `movement_constants.gd` — all GoldSrc-scaled constants in one file |
| Duck-jump clears the gap jump | Yes | 4.5m gap + 0.5m lip: regular jump fails, duck-jump clears with ~7cm margin |
| Counter-strafing produces zero-velocity windows | Yes | GoldSrc-faithful friction with stopspeed threshold; velocity zeroes within 1-2 frames of counter-strafe |

## Automated test results (9/9)

| Test | Result | Value |
|------|--------|-------|
| test_ground_speed | PASS | 250.0 u/s (expected ~250) |
| test_ground_speed_clamp | PASS | Clamped to 250.0 u/s |
| test_jump_height | PASS | 1.132m (expected ~1.143) |
| test_friction_decel | PASS | Lost 159 u/s in 0.25s from 250 |
| test_air_acceleration | PASS | Gained 30.0 u/s over 0.5s |
| test_bhop_preserves_speed | PASS | 250 → 250 u/s (first hop) |
| test_bhop_degradation | PASS | 250 → 0 u/s after 6 hops |
| test_step_up | PASS | Stepped smoothly |
| test_duck_hull_shrink | PASS | 0.914m (expected 0.914) |

## Movement range sections tested

| Section | Status | Notes |
|---------|--------|-------|
| Small stairs (16u/0.406m) | Working | Fixed: CSG normal threshold, ducked step-up, idle jitter, narrow-tread multi-collision |
| Big stairs (18u/0.457m = step limit) | Working | At STEP_SIZE boundary |
| 30° ramp | Working | Walkable, speed preserved |
| 50° ramp | Working | Too steep, player slides off |
| 2.8m gap jump | Working | Regular running jump clears it |
| 4.5m gap + 0.5m lip | Working | Requires duck-jump (widened from 4.0m — capsule radius made original too easy) |
| Height walls (1.0m, 1.5m, 2.0m) | Working | Regular jump, duck-jump only, impassable — as designed |
| Crouch tunnel (1.0m) | Working | Must duck to enter |
| Bhop corridor (50m) | Working | Speed markers for bhop testing |
| Ladders (5m + 7m) | Working | Climb, dismount, jump-off all work |
| Edge/ledge (3m drop) | Working | Edge friction triggers near edges |

## Deviations from plan

| Deviation | Rationale |
|-----------|-----------|
| CI regression test integration deferred | Tests run headless locally and on vm-prime; GitHub Actions integration will be added in Phase 3 when the test suite expands with weapon tests |
| Bullet tagging stub not implemented | Requires Phase 3 damage system — carried forward |
| Speed graph HUD not implemented | Optional item; current HUD provides sufficient telemetry for development |
| Per-weapon maxspeed framework | Constants defined (knife, AK, pistol speeds) but only knife speed active — weapon selection is Phase 3 |
| Movement inaccuracy speed threshold (140 u/s flag) | Constant defined in `movement_constants.gd` but not actively checked — Phase 3 weapon accuracy system will consume it |
| Duck-jump gap widened from 4.0m to 4.5m | Original 4.0m was clearable with regular jump due to capsule radius (0.35m) shortening effective gap; 4.5m properly requires duck-jump |

## Conditions carried to Phase 3

- **CI regression tests:** Add `godot --headless --path . -- --test` to GitHub Actions workflow
- **Bullet tagging:** Implement speed reduction when shot while bhopping (requires damage events)
- **Per-weapon maxspeed:** Activate weapon-specific speeds when weapon selection is implemented
- **Movement inaccuracy flag:** Wire 140 u/s threshold to weapon accuracy system
- **Speed graph HUD:** Optional; add if useful for weapon recoil/accuracy tuning

## Key bug fixes during Phase 2

| Commit | Fix |
|--------|-----|
| `e8d1a53` | Fix step-up on small stairs: widen collision normal threshold (CSG trimesh blended normals at edges) |
| `f84546e` | Fix ducked step-up: attempt step on any collision, not just steep normals (hemisphere-dominated capsule) |
| `daba5e0` | Fix stair jitter: relax on_slope threshold (0.99→0.93) and add height-gain check (>0.02m) |
| `84675a5` | Fix idle stair jitter: skip lift-snap cycle when not moving (sub-mm collision probe variance) |
| `d121580` | Fix ducked stair climb: use max_collisions=4 on step-down probe (narrow-tread next-step face) |
| `31b5350` | Widen duck-jump gap from 4.0m to 4.5m (capsule radius made original too easy) |

## Summary

Phase 2 delivers a complete GoldSrc-faithful movement system in Godot 4.7, with A&D-specific modifications (progressive bhop degradation, capped ladders). All movement runs through a custom `move_and_collide()` simulation loop — no `move_and_slide()`. Nine automated regression tests validate core movement values. A 10-section gray-box movement range provides manual testing coverage for stairs, ramps, gaps, tunnels, ladders, edges, and bhop corridors. Five stair/collision bugs were found and fixed through owner playtesting.

Approved: pending owner review.
