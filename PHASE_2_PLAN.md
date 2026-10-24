# PHASE 2 — Movement Laboratory
**Status:** Planning | **Version:** 1.0 | **Date:** 2026-10-24

## Scope
Implement the CS 1.6 movement system in Godot with A&D modifications, in a gray-box test environment with telemetry for validation against Phase 0 reference measurements.

### In scope
- Full GoldSrc-style movement simulation loop (PM_PlayerMove equivalent)
- Ground movement: friction, acceleration, stair stepping, edge friction
- Air movement: air acceleration with air-strafing mechanics
- Jumping: jump velocity, anti-pogo, duck-jump clearance
- Bunny hopping with A&D progressive degradation (not CS 1.6 hard cap)
- Ducking: hull change, input scaling, transition timing, crouch spam
- Ladders: A&D capped at 200 u/s, no angle exploits
- Per-weapon maxspeed framework (knife, pistol, rifle speeds)
- Movement inaccuracy speed threshold (140 u/s flag for Phase 3)
- Debug telemetry HUD: speed, position, ground state, input visualization
- Automated regression test scenes
- Movement test range (expanded gray-box with stairs, ramps, ledges, ladders, gaps)

### Not in scope
- Weapons, damage, recoil (Phase 3)
- Networked multiplayer movement sync (Phase 4 — all testing is local/single-player)
- Art, textures, character models (Phase 6)
- Sound effects for footsteps, jumping, landing (Phase 6, placeholder sounds OK)
- Water movement (not in base GDD)

---

## Key decision: Unit scaling

GoldSrc uses approximately 1 unit ≈ 1 inch (39.37 units/meter). Godot uses meters. We need a consistent mapping.

**Decision: work in Godot meters, convert all GoldSrc constants at definition time.**

Scale factor: `1 Godot unit = 39.37 GoldSrc units`

| GoldSrc | Value | Godot equivalent | Notes |
|---------|-------|-------------------|-------|
| Standing hull height | 72 u | 1.829 m | Matches existing 1.8m capsule |
| Ducked hull height | 36 u | 0.914 m | |
| Standing eye height | 28 u | 0.711 m | Offset from hull center |
| Ducked eye height | 12 u | 0.305 m | |
| sv_gravity | 800 u/s² | 20.32 m/s² | project.godot has 20.0 — close enough, use 20.32 |
| Knife maxspeed | 250 u/s | 6.35 m/s | |
| AK maxspeed | 221 u/s | 5.61 m/s | |
| Jump upward velocity | 268.33 u/s | 6.81 m/s | |
| Jump height | 45 u | 1.143 m | |
| Duck-jump clearance | 63 u | 1.600 m | |
| sv_stopspeed | 75 u/s | 1.905 m/s | |
| sv_stepsize | 18 u | 0.457 m | |
| Air wishspd cap | 30 u/s | 0.762 m/s | |
| sv_friction | 4 | 4 | Dimensionless — no conversion |
| sv_accelerate | 10 | 10 | Dimensionless — no conversion |
| sv_airaccelerate | 10 | 10 | Dimensionless — no conversion |
| BUNNYJUMP_MAX_SPEED_FACTOR | 1.2 | 1.2 | Ratio — no conversion |
| PLAYER_DUCKING_MULTIPLIER | 0.333 | 0.333 | Ratio — no conversion |
| Movement inaccuracy threshold | 140 u/s | 3.556 m/s | |

All constants live in a single `shared/scripts/movement_constants.gd` resource. Phase 0 GoldSrc values are documented in comments alongside the Godot-scaled values.

---

## Architecture

### Movement system design

Replace the current `player_controller.gd` (Godot's `CharacterBody3D.move_and_slide()`) with a custom physics implementation that faithfully reproduces the GoldSrc simulation loop.

```
CharacterBody3D (Player)
├── CollisionShape3D (standing hull)
├── CollisionShape3D (ducked hull — toggled)
├── Head (Node3D)
│   └── Camera3D
├── PlayerMovement (script)
│   ├── _physics_process(): runs sim loop each tick
│   ├── apply_friction()
│   ├── apply_ground_acceleration()
│   ├── apply_air_acceleration()
│   ├── apply_gravity()
│   ├── handle_jump()
│   ├── handle_duck()
│   ├── handle_ladder()
│   ├── apply_bhop_cap()        # A&D modified
│   ├── stair_step()
│   └── categorize_position()   # ground detection
└── MovementTelemetry (debug overlay)
```

**Key principle:** We do NOT use `move_and_slide()`. Instead we use `move_and_collide()` in a custom loop that replicates the GoldSrc slide/step algorithm. This gives us full control over the collision response.

### Why not move_and_slide()
- `move_and_slide()` handles slope sliding, step-up, and floor snapping with its own logic that doesn't match GoldSrc
- No control over the order of operations (gravity split, friction before accel, etc.)
- Can't implement the "try flat vs try step-up, pick whichever goes farther" stair algorithm
- Snap-to-floor behavior differs from GoldSrc's ground categorization

### Simulation loop (per _physics_process tick)

```
1. Read input (forward, side, jump, duck, view angles)
2. Set maxspeed based on weapon
3. Reduce timers (duck transition)
4. Compute wishdir and wishspeed from input + view angles
5. Categorize position (on ground? on ladder?)
6. Handle duck state (hull swap, input scaling)
7. If on ladder → ladder_move()
8. If on ground:
   a. Apply half gravity (pre-move)
   b. Zero vertical velocity
   c. Handle jump (if pressed and was released)
   d. Apply friction
   e. Apply ground acceleration
   f. Walk move with stair stepping (move_and_collide + slide)
9. If in air:
   a. Apply half gravity (pre-move)
   b. Apply air acceleration (with 30 u/s wishspd cap)
   c. Fly move (move_and_collide + slide)
10. Categorize position (re-check ground)
11. Apply second half gravity (post-move)
12. If on ground: zero vertical velocity
13. Check falling (fall damage threshold)
14. Update telemetry
```

---

## Work breakdown

### WB1: Movement constants and framework (laptop)
- [ ] Create `shared/scripts/movement_constants.gd` — all GoldSrc constants with Godot-scaled values
- [ ] Create `shared/scripts/player_movement.gd` — skeleton class with the simulation loop structure
- [ ] Remove Godot default gravity from `project.godot`, use our constant
- [ ] Physics tick rate: 128 per second (`physics_ticks_per_second=128` in project.godot)
- **Owner:** laptop

### WB2: Ground movement (laptop)
- [ ] `apply_friction()` — GoldSrc friction with stopspeed threshold and edge friction
- [ ] `apply_ground_acceleration()` — PM_Accelerate with wishdir/wishspeed
- [ ] `walk_move()` — move_and_collide with slide, stair step-up algorithm
- [ ] `categorize_position()` — ground detection via downward raycast/shapecast
- [ ] Validate: acceleration from standstill to maxspeed matches Phase 0 (0.4-0.5s with knife)
- [ ] Validate: stopping distance matches Phase 0 (723ms / ~1.87m from knife speed)
- [ ] Validate: counter-strafe stopping matches Phase 0 (~15% faster than release)
- **Owner:** laptop

### WB3: Air movement and jumping (laptop)
- [ ] `apply_air_acceleration()` — PM_AirAccelerate with 30 u/s wishspd cap
- [ ] `handle_jump()` — jump velocity, anti-pogo (must release and re-press)
- [ ] `apply_gravity()` — split gravity (half pre-move, half post-move)
- [ ] Air strafing works: turning + strafe gains speed
- [ ] Validate: jump height matches Phase 0 (1.143m / 45 GoldSrc units)
- [ ] Validate: air strafe speed gain matches Phase 0 (+50-70 u/s per jump equivalent)
- **Owner:** laptop

### WB4: Ducking (laptop)
- [ ] `handle_duck()` — state machine: start, transition (0.4s ground, instant air), complete
- [ ] Hull swap: standing (1.83m) ↔ ducked (0.914m)
- [ ] Eye height interpolation: standing (0.711m offset) → ducked (0.305m offset)
- [ ] Input scaling: `PLAYER_DUCKING_MULTIPLIER` (0.333) on forward/side move
- [ ] Duck-jump: instant duck in air, +0.457m foot clearance from hull shrink
- [ ] Crouch spam: no horizontal speed penalty on rapid toggle
- [ ] Validate: duck-jump clears 1.6m gaps
- [ ] Validate: ducked speed is ~1/3 of standing (~2.11 m/s with knife)
- **Owner:** laptop

### WB5: Bunny hopping — A&D modified (laptop)
- [ ] Implement A&D bhop system (NOT CS 1.6 hard cap):
  - First 2-3 hops: full speed preservation
  - Subsequent hops: progressive speed degradation per hop
  - Configurable: `bhop_free_hops`, `bhop_degradation_rate`, `bhop_min_speed_factor`
- [ ] Bullet tagging stub: flag for Phase 3 (significant speed reduction when shot while bhopping)
- [ ] Hop counter: tracks consecutive hops, resets on ground stand-still
- [ ] All bhop parameters exposed as server-configurable vars
- [ ] Validate: first 2 hops preserve air-strafe speed gain
- [ ] Validate: after ~5 hops, speed converges back toward maxspeed
- **Owner:** laptop

### WB6: Ladders — A&D modified (laptop)
- [ ] Ladder detection (area trigger or surface property)
- [ ] Climb speed capped at `MAX_CLIMB_SPEED` (200 u/s / 5.08 m/s)
- [ ] No angled-climb speed stacking (unlike CS 1.6's 626 u/s exploit)
- [ ] Clean dismount: no velocity conversion exploit
- [ ] Jump off ladder: detach and push away from surface
- [ ] Ducking on ladder reduces speed by 0.333
- **Owner:** laptop

### WB7: Movement test range (laptop)
- [ ] Expand test room or create `maps/movement_range.tscn`:
  - Flat ground section (acceleration/stopping tests)
  - Staircase (16u/0.406m and 18u/0.457m step heights)
  - Ramp at ~30° and ~45° (walkable slope threshold)
  - Ledge with drop (edge friction testing)
  - Gap jump (requires duck-jump to cross, ~4.5m)
  - Ladder section (vertical + angled surfaces)
  - Crouch tunnel (requires ducking, ~1.0m clearance)
  - Speed measurement corridor with distance markers
- **Owner:** laptop

### WB8: Telemetry HUD (laptop)
- [ ] Debug overlay toggled with a key (F3 or backtick):
  - Current speed (horizontal, vertical, 3D)
  - Position (X, Y, Z)
  - Ground state (grounded / airborne / ladder)
  - Input visualization (WASD + mouse direction)
  - Bhop hop counter and speed cap status
  - Duck state and hull dimensions
  - Frametime / physics tick rate
- [ ] Optional: speed graph (last 2 seconds of horizontal speed)
- **Owner:** laptop

### WB9: Regression tests (laptop + vm-prime)
- [ ] Automated test scenes that validate movement against Phase 0 tolerances:
  - Acceleration time from standstill
  - Stopping distance (release and counter-strafe)
  - Jump height and duck-jump clearance
  - Air strafe speed gain per jump
  - Bhop speed after N hops
  - Stair step-up (no vertical velocity)
  - Slope speed preservation
  - Ladder speed cap
- [ ] Each test: set initial conditions, run simulation, compare output to expected ±tolerance
- [ ] Tests runnable headless on vm-prime (`godot --headless --script`)
- [ ] CI integration: fail build if regression tests fail
- **Owner:** laptop creates tests, vm-prime runs in CI

---

## Test plan

### Reference comparison tolerances

| Measurement | Phase 0 reference | Tolerance | Test method |
|-------------|-------------------|-----------|-------------|
| Accel 0→max (knife) | 0.4-0.5s | ±0.1s | Timed simulation from standstill |
| Stop distance (release) | 1.87m (73.5u) | ±0.1m | Measure displacement after key release |
| Counter-strafe stop | ~15% faster than release | ±5% | Compare to release-stop time |
| Jump height | 1.143m (45u) | ±0.02m | Peak Y position during jump |
| Duck-jump clearance | 1.600m (63u) | ±0.02m | Obstacle clearance test |
| Air strafe gain/jump | ~1.5m/s (50-70u/s) | ±0.5m/s | Speed delta from jump start to landing |
| Bhop peak (2 hops) | Preserves air strafe speed | ±10% | Speed after 2nd hop |
| Bhop degradation (5+ hops) | Returns toward maxspeed | Converging | Speed curve over 8 hops |
| Stair step-up | Zero vertical velocity | ±0.01 m/s | Measure vspeed during step |
| Slope speed (grounded) | Zero speed loss | ±2% | Speed on 30° ramp vs flat |
| Ladder climb | ≤5.08 m/s (200u/s) | +0 / -0.5 m/s | Max speed while on ladder |
| Ducked speed (knife) | ~2.11 m/s (83u/s) | ±0.15 m/s | Steady-state ducked speed |
| Movement inaccuracy threshold | 3.556 m/s (140u/s) | exact | Boolean flag at threshold |

### Play-feel tests (manual, on laptop)
- [ ] Counter-strafing feels crisp — instant direction reversal
- [ ] Air strafing feels smooth — continuous speed gain with rotation
- [ ] Bunny hopping feels rewarding for first 2-3 hops, then bleeds off
- [ ] Duck-jump gap crossing feels skill-expressive
- [ ] Stair climbing is smooth (no camera bob from vertical velocity)
- [ ] Ladder movement feels predictable and capped
- [ ] Crouch spam works at full run speed

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| move_and_collide doesn't match GoldSrc slide behavior | Medium | High | Start with simplest implementation; GoldSrc slide is well-documented (clip velocity against plane normal); iterate |
| 128 tick physics at high CPU cost | Low | Medium | Profile early; Godot physics tick is lightweight without full physics engine; our movement is kinematic |
| Stair step algorithm edge cases | Medium | Medium | Test with multiple step heights; the "try both paths" approach is well-understood from Quake |
| A&D bhop degradation feels bad | Medium | Medium | Make all parameters tunable; iterate during playtesting |
| Ducking hull swap causes stuck/clip-through | Medium | High | Check for obstruction before unduck; keep ducked if standing hull would overlap geometry |

---

## Dependencies
- Phase 1 project foundation — **done**
- Phase 0 movement spec — **done** (all major measurements verified)
- Godot 4.7 on laptop with editor — **done**
- Godot 4.7.2 headless on vm-prime for CI — **done**

---

## Owner training exercises

### E1: GoldSrc movement math
- Read through `phase_0/movement_spec.md` sections 3-5 (friction, acceleration, air acceleration)
- Trace through one frame of ground acceleration by hand with knife maxspeed:
  - Start at 100 u/s, frametime 0.0078125 (128 tick)
  - Compute friction drop, then acceleration gain
- **Goal:** understand why counter-strafing stops faster than releasing keys

### E2: Godot collision system
- Experiment with `move_and_collide()` vs `move_and_slide()`
- Create a test: move a CharacterBody3D into a wall at an angle, observe the collision normal and remainder
- Implement a simple "slide along wall" using the collision normal
- **Goal:** comfortable with Godot's `KinematicCollision3D` result object

### E3: Air strafing intuition
- After WB3 is working, practice air strafing in the movement range
- Try to cross the gap jump without duck-jump (should be impossible)
- Cross it with duck-jump (should be tight)
- **Goal:** feel why the 30 u/s wishspd cap creates the air-strafe mechanic

---

## Acceptance checklist (gate criteria)

- [ ] All Phase 0 reference measurements pass within tolerance (see test plan table)
- [ ] Movement feels comparable to CS 1.6 reference (subjective owner approval)
- [ ] A&D modifications work as designed: bhop degradation, ladder cap, no exploits
- [ ] Telemetry HUD shows accurate real-time movement data
- [ ] Regression tests pass headless on vm-prime
- [ ] CI runs regression tests on push
- [ ] No `move_and_slide()` in movement code — fully custom sim loop
- [ ] All movement constants are configurable (not hardcoded in logic)
- [ ] Duck-jump clears the gap jump in the movement range
- [ ] Counter-strafing produces zero-velocity windows for accurate shooting (flag only — shooting is Phase 3)

---

## Demo instructions
1. Open project in Godot on laptop, press F5
2. Connect to local (or just run single-player test scene)
3. Toggle telemetry HUD (F3)
4. Walk around the movement range:
   - Sprint to wall, observe acceleration curve on HUD
   - Counter-strafe, observe instant stop
   - Jump, observe 1.14m height on HUD
   - Air strafe through a turn, observe speed climbing above maxspeed
   - Bhop across flat ground: first 2-3 hops fast, then degradation
   - Duck-jump across the gap
   - Climb ladder, observe 5.08 m/s cap
   - Run through crouch tunnel
5. On vm-prime: `godot --headless --script tests/movement_regression.gd` — all pass

---

## Immediate next steps
1. **Laptop:** Start with WB1 (constants file) and WB2 (ground movement) — these are the foundation
2. **vm-prime:** Prepare CI integration for regression tests (WB9) once laptop has testable movement
3. **Key order:** Ground movement → jumping → air movement → ducking → bhop → ladders → test range → telemetry → regression tests
