# Movement Specification — CS 1.6 Reference
**Status:** Draft | **Phase:** 0, Week 1–2 | **Confidence key:** Verified = source + measured, Inferred = source study only, Unknown = needs testing

## Sources
- Half-Life SDK: `pm_shared/pm_shared.c` (Valve, Half-Life SDK license — non-commercial use)
- ReGameDLL_CS: `pm_shared/pm_shared.cpp`, `dlls/weapons.h` (Apache 2.0 license)
- In-game measurement: CS 1.6 build 10211 on research server (vm-prime)

---

## 1. Simulation loop order

From `PM_PlayerMove()` (MOVETYPE_WALK, not in water, not on ladder):

```
1. PM_CheckParameters()       — clamp input, set maxspeed
2. frametime = cmd.msec * 0.001
3. PM_ReduceTimers()          — decay duck time, swim time, etc.
4. AngleVectors()             — convert view angles to forward/right/up
5. PM_CheckStuck()            — unstick if embedded in geometry
6. PM_CatagorizePosition()    — determine onground, waterlevel
7. PM_Duck()                  — handle crouch state (modifies cmd.forwardmove/sidemove)
8. PM_LadderMove() if on ladder
9. IF on ground:
   a. PM_AddCorrectGravity()  — subtract half-gravity (pre-move)
   b. velocity[2] = 0
   c. PM_Jump() if jump pressed
   d. PM_Friction()
   e. PM_WalkMove()           — calls PM_Accelerate(), then collision
10. IF in air:
    a. PM_AddCorrectGravity()
    b. PM_Jump() if jump pressed (no effect — already in air)
    c. PM_AirMove()           — calls PM_AirAccelerate(), then PM_FlyMove()
11. PM_CatagorizePosition()   — re-check ground after move
12. PM_FixupGravityVelocity() — subtract second half-gravity (post-move)
13. IF on ground: velocity[2] = 0
14. PM_CheckFalling()         — fall damage, landing sounds
```

**Gravity split:** gravity is applied in two halves — `PM_AddCorrectGravity()` before the move, `PM_FixupGravityVelocity()` after. This is a Verlet-like integration that improves accuracy over simple Euler.

**Confidence:** Verified (source code, lines 2954–3207)

---

## 2. Constants

### 2.1 Movement CVARs (stock defaults)

| CVAR | Default | Source | Notes |
|------|---------|--------|-------|
| `sv_maxspeed` | 320 | movevars | Capped by per-weapon maxspeed |
| `sv_gravity` | 800 | movevars | units/s² |
| `sv_friction` | 4 | movevars | Ground friction multiplier |
| `sv_stopspeed` | 75 | movevars | Below this, friction uses stopspeed instead of actual speed |
| `sv_accelerate` | 10 | movevars | Ground acceleration multiplier |
| `sv_airaccelerate` | 10 | movevars | Air acceleration multiplier |
| `sv_stepsize` | 18 | movevars | Max step-up height (units) |
| `sv_bounce` | 1 | movevars | Bounce multiplier for MOVETYPE_BOUNCE |
| `edgefriction` | 2 | movevars | Extra friction at edges (near drops) |

### 2.2 Hardcoded constants

| Constant | Value | Source file | Notes |
|----------|-------|-------------|-------|
| `TIME_TO_DUCK` | 0.4 s | pm_shared.c:77 | Time to transition to ducked |
| `VEC_HULL_MIN` | -36 | pm_shared.c:85 | Standing hull Z min |
| `VEC_HULL_MAX` | 36 | pm_shared.c:86 | Standing hull Z max |
| `VEC_DUCK_HULL_MIN` | -18 | pm_shared.c:78 | Ducked hull Z min |
| `VEC_DUCK_HULL_MAX` | 18 | pm_shared.c:79 | Ducked hull Z max |
| `VEC_VIEW` | 28 | pm_shared.c:87 | Standing eye height offset |
| `VEC_DUCK_VIEW` | 12 | pm_shared.c:80 | Ducked eye height offset |
| `STOP_EPSILON` | 0.1 | pm_shared.c:88 | Velocity threshold for zeroing |
| `MAX_CLIMB_SPEED` | 200 | pm_shared.c:82 | Ladder speed cap |
| `PLAYER_DUCKING_MULTIPLIER` | 0.333 | pm_shared.c:123 | Input scaling while ducked |
| `BUNNYJUMP_MAX_SPEED_FACTOR` | **1.2** (CS) / 1.7 (HL) | ReGameDLL:pm_shared.h:74 / SDK:pm_shared.c:2436 | **CS uses 1.2, not 1.7** |
| Air speed cap in `PM_AirAccelerate` | 30 | pm_shared.c:1292 | `wishspd` clamped to 30 |

**Confidence:** Verified (source code)

### 2.3 Player collision hulls

| State | Width (X/Y) | Height (Z) | Hull index |
|-------|-------------|------------|------------|
| Standing | 32 × 32 | 72 (from -36 to 36) | 0 |
| Ducking | 32 × 32 | 36 (from -18 to 18) | 1 |

Hull is axis-aligned bounding box, centered on player origin. Origin is at hull center vertically.

**Confidence:** Verified (source constants)

---

## 3. Ground movement

### 3.1 PM_Friction (line 1202)

Applied every frame while on ground, before acceleration.

```
speed = |velocity|                              // 3D length
if speed < 0.1: return                          // too slow, skip

// Edge friction check: trace 16 units ahead at foot level
// If trace falls off edge, friction *= edgefriction (2)

control = max(speed, sv_stopspeed)              // 75 if speed < 75
drop = control * sv_friction * frametime        // when speed < stopspeed, braking is stronger

newspeed = max(0, speed - drop)
velocity *= (newspeed / speed)                  // scale velocity proportionally
```

**Key insight:** When `speed < sv_stopspeed (75)`, friction uses `sv_stopspeed` as the control value instead of actual speed. This makes low-speed braking much stronger — the player snaps to a stop rather than sliding forever. This is what makes counter-strafing feel crisp.

**Edge friction:** If the player is near a ledge (trace 16 units ahead in movement direction misses ground), friction is doubled via `edgefriction`. This prevents sliding off edges.

**Confidence:** Verified (source code, lines 1202–1277)

### 3.2 PM_Accelerate (line 990) — ground acceleration

```
currentspeed = DotProduct(velocity, wishdir)    // speed along desired direction
addspeed = wishspeed - currentspeed             // how much to add
if addspeed <= 0: return                        // already at or past wish speed

accelspeed = sv_accelerate * frametime * wishspeed * player_friction
accelspeed = min(accelspeed, addspeed)          // don't overshoot

velocity += accelspeed * wishdir
```

Where:
- `wishdir` = normalized desired movement direction (from input + view angles)
- `wishspeed` = desired speed (capped at `pmove->maxspeed`, which is per-weapon)
- `player_friction` = typically 1.0 (can be modified by entities)

**Note:** `accelspeed` depends on `wishspeed`, not current speed. This means acceleration is constant until you approach maxspeed, then the `addspeed` cap kicks in.

**Confidence:** Verified (source code, lines 990–1025)

### 3.3 PM_WalkMove (line 1034) — ground collision

After friction and acceleration:
1. Try to move directly to `origin + velocity * frametime`.
2. If blocked, try stepping up by `sv_stepsize` (18 units), sliding, then stepping back down.
3. Compare which path (flat slide vs step-up slide) moved farther horizontally — use that one.
4. Step-down requires landing on a surface with `normal[2] >= 0.7` (≤~45° slope).

This is the classic Quake stair-stepping algorithm.

**Confidence:** Verified (source code, lines 1034–1193)

---

## 4. Air movement

### 4.1 PM_AirAccelerate (line 1279)

```
wishspd = min(wishspeed, 30)                    // *** HARD CAP AT 30 ***
currentspeed = DotProduct(velocity, wishdir)
addspeed = wishspd - currentspeed
if addspeed <= 0: return

accelspeed = sv_airaccelerate * wishspeed * frametime * player_friction
                                                // note: uses original wishspeed, not capped wishspd
accelspeed = min(accelspeed, addspeed)

velocity += accelspeed * wishdir
```

**Critical difference from ground:** The `wishspd` (used for `addspeed` check) is capped at 30, but the `accelspeed` calculation uses the original uncapped `wishspeed`. This asymmetry is what enables air strafing:

- When moving diagonally in the air (forward + strafe), the dot product of velocity with the new wishdir may be less than 30, even at high speeds.
- This allows small incremental speed additions per frame.
- By smoothly rotating the view + strafe input, the player can continuously add speed in the air.
- The 30 u/s cap on `wishspd` limits how much speed is added per frame, keeping it subtle.

**Confidence:** Verified (source code, lines 1279–1313)

### 4.2 PM_AirMove (line 1417)

```
wishvel = forward * forwardmove + right * sidemove  // (z components zeroed)
wishdir = normalize(wishvel)
wishspeed = |wishvel|                               // clamped to maxspeed

PM_AirAccelerate(wishdir, wishspeed, sv_airaccelerate)
velocity += basevelocity                            // conveyor belts etc.
PM_FlyMove()                                        // collision/slide
```

No friction is applied in the air. Speed is preserved except through collision with surfaces.

**Confidence:** Verified (source code, lines 1417–1461)

---

## 5. Jumping

### 5.1 PM_Jump (line 2474)

```
// Must be on ground and jump not held from previous frame
if onground == -1: return           // can't jump in air
if oldbuttons & IN_JUMP: return     // must release and re-press (anti-pogo)

onground = -1                       // now in air

PM_PreventMegaBunnyJumping()        // speed cap before jump

// Jump velocity:
velocity[2] = sqrt(2 * 800 * 45.0) // = sqrt(72000) ≈ 268.33 u/s

PM_FixupGravityVelocity()           // apply remaining half-gravity
oldbuttons |= IN_JUMP               // mark jump consumed
```

**Jump height derivation:** `sqrt(2 * gravity * height)` = `sqrt(2 * 800 * 45)` ≈ 268.33 u/s upward. This produces a jump height of exactly 45 units at `sv_gravity 800`.

**Duck-jump:** Same jump velocity. The clearance gain comes from the hull shrinking from 72 to 36 units tall, giving 18 additional units of head clearance (from hull min changing from -36 to -18).

**Anti-pogo:** Jump requires the key to be released and re-pressed between jumps (`oldbuttons & IN_JUMP` check). Holding jump does NOT auto-jump.

**Confidence:** Verified (source code, lines 2474–2609)

### 5.2 PM_PreventMegaBunnyJumping (line 2444)

```
maxscaledspeed = BUNNYJUMP_MAX_SPEED_FACTOR * maxspeed  // CS: 1.2 * maxspeed
spd = |velocity|

if spd <= maxscaledspeed: return    // under threshold, no crop

fraction = (maxscaledspeed / spd) * 0.65
velocity *= fraction                // aggressive crop
```

**CS 1.6 behavior:** With knife (maxspeed 250), the cap is `1.2 * 250 = 300 u/s`. If speed exceeds 300, it's cropped by factor `(300/speed) * 0.65`. This is very aggressive — at 350 u/s it would crop to `(300/350) * 0.65 * 350 ≈ 195 u/s`.

**Half-Life difference:** HL uses factor 1.7, allowing much more bunny hop speed accumulation. CS intentionally limits this.

**When it runs:** Called inside `PM_Jump()`, right before the upward velocity is set. So the horizontal speed is cropped, then vertical impulse is added.

**Confidence:** Verified (source code, lines 2444–2467; ReGameDLL pm_shared.h:74 confirms CS factor is 1.2)

---

## 6. Ducking

### 6.1 PM_Duck (line 1964)

**State machine:**
1. **Start duck:** `IN_DUCK` pressed → set `flDuckTime = 1000`, `bInDuck = true`
2. **Transition:** Over `TIME_TO_DUCK` (0.4s), view height interpolates from 28 to 12 via spline
3. **Complete duck:** When `flDuckTime/1000 <= 0.6` (i.e., 0.4s elapsed) OR in air: immediately finish duck
4. **Ducking in air:** Completes instantly (no transition delay)

**Movement while ducked:**
```
cmd.forwardmove *= PLAYER_DUCKING_MULTIPLIER  // 0.333
cmd.sidemove    *= PLAYER_DUCKING_MULTIPLIER
cmd.upmove      *= PLAYER_DUCKING_MULTIPLIER
```

This means ducked movement input is 1/3 of normal. With knife (maxspeed 250), ducked effective wish speed is ~83 u/s.

**Hull change:** Standing hull 0 (72 tall) → ducked hull 1 (36 tall). When ducking on the ground, origin shifts down by the hull min difference to keep feet on the ground.

**Confidence:** Verified (source code, lines 1920–2057)

---

## 7. Per-weapon maxspeed

Player `maxspeed` is set by the currently held weapon, capped by `sv_maxspeed` (320). These values come from ReGameDLL `weapons.h`:

| Weapon | Maxspeed (u/s) | BHop cap (1.2×) |
|--------|---------------|-----------------|
| Knife | 250 | 300 |
| USP / Glock / P228 / Deagle / Fiveseven / Elites | 250 | 300 |
| MP5 / MAC-10 / TMP / UMP-45 | 250 | 300 |
| Scout | 260 | 312 |
| P90 | 245 | 294 |
| Galil / FAMAS / AUG / XM1014 | 240 | 288 |
| SG552 | 235 | 282 |
| M4A1 / M3 | 230 | 276 |
| AK-47 | 221 | 265.2 |
| M249 | 220 | 264 |
| AWP / G3SG1 / SG550 | 210 | 252 |
| AWP/G3/SG550 (zoomed) | 150 | 180 |
| HE / Flash / Smoke / C4 | 250 | 300 |

**Note:** `sv_maxspeed` (320) is higher than any weapon maxspeed, so it never clips in practice. The per-weapon value is the effective cap.

**Confidence:** Verified (ReGameDLL source, `dlls/weapons.h`)

---

## 8. Ladder movement

### PM_LadderMove (line 2059)

- Speed capped at `MAX_CLIMB_SPEED` (200 u/s)
- Movement is along the ladder's face normal
- Looking up + forward = climb up; looking down + forward = climb down
- Jump while on ladder = detach and jump away from ladder face
- Ducking on a ladder reduces speed by `PLAYER_DUCKING_MULTIPLIER` (0.333)
- Player movetype set to `MOVETYPE_FLY` while on ladder

**Confidence:** Inferred (source study only, not yet measured in-game)

---

## 9. Key derived values

### 9.1 Time to reach max speed from standstill (ground, forward)

With knife (maxspeed 250), `sv_accelerate 10`, `sv_friction 4`:

Each frame: `accelspeed = 10 * frametime * 250 * 1.0`

At 100 fps (frametime = 0.01): `accelspeed = 10 * 0.01 * 250 = 25 u/s per frame`

But friction also applies. The interaction is complex because friction depends on current speed. Approximate time to 250 u/s: **TODO — measure in-game.**

### 9.2 Stopping distance (counter-strafe)

From 250 u/s, releasing all keys:
- Friction: `drop = max(speed, 75) * 4 * frametime`
- At 250 u/s: `drop = 250 * 4 * 0.01 = 10 u/s per frame` (at 100 fps)
- Below 75 u/s: `drop = 75 * 4 * 0.01 = 3 u/s per frame` (constant)

Approximate stop time from 250: **TODO — measure in-game.**

Counter-strafing (pressing opposite direction) adds reverse acceleration ON TOP of friction, making stops significantly faster.

### 9.3 Jump height

- Upward velocity: `sqrt(2 * 800 * 45)` ≈ 268.33 u/s
- Peak height: 45 units (by derivation)
- Duck-jump clearance: 45 + 18 = 63 units total (jump height + hull shrink from bottom)

**TODO:** Measure actual jump height and duck-jump clearance in-game to verify.

### 9.4 Air strafe speed gain

At knife speed (250 u/s) moving forward, adding a 90° strafe:
- `wishspd` = min(250, 30) = 30
- `currentspeed` = DotProduct(velocity, strafe_dir) ≈ 0 (perpendicular)
- `addspeed` = 30
- `accelspeed` = 10 * 250 * 0.01 * 1.0 = 25

Speed added per frame perpendicular to current velocity: up to 25 u/s (capped at 30).
New speed: `sqrt(250² + 25²)` ≈ 251.25 u/s — marginal per frame, compounds with smooth rotation.

**TODO:** Measure actual speed gain curves with controlled air strafing.

---

## 10. Experiments — TODO

| ID | Experiment | Status |
|----|-----------|--------|
| M01 | Forward acceleration to max speed (knife, 100fps) | not_started |
| M02 | Stop distance from max speed (release keys) | not_started |
| M03 | Counter-strafe stop time (250 u/s, press opposite) | not_started |
| M04 | Jump height (standing, measure with cl_showpos) | not_started |
| M05 | Duck-jump clearance | not_started |
| M06 | Air strafe speed gain per 180° turn | not_started |
| M07 | Bunny hop speed with frame-perfect jumps | not_started |
| M08 | Bunny hop crop behavior at various speeds | not_started |
| M09 | Step-up threshold (ramp heights) | not_started |
| M10 | Slope sliding behavior (steep vs walkable) | not_started |
| M11 | Ladder attach/detach/speed | not_started |
| M12 | Edge friction near drops | not_started |
| M13 | Diagonal speed vs forward speed | not_started |
| M14 | AK-47 vs knife speed difference | not_started |
| M15 | Server FPS effect on movement precision | not_started |

---

## 11. Open questions

1. **Framerate dependency:** GoldSrc ties movement to server framerate. At ~91 fps (our server), does movement feel/measure differently than at 100 fps or 1000 fps (sys_ticrate)? What is the actual simulation rate?
2. **Bunny hop window:** Exactly how many frames before landing can you press jump to bhop? Is there a ground-check window?
3. **Slope physics:** At what angle do slopes become non-walkable? The 0.7 normal[2] check implies ~45°, but is this the actual threshold?
4. **Speed rounding:** Are there float precision or rounding effects that accumulate over long movements?
5. **cl_forwardspeed / cl_sidespeed:** Do these client CVARs affect the forwardmove/sidemove values sent to the server?
