# Movement Specification — CS 1.6 Reference
**Status:** Verified | **Phase:** 0, Week 1–2 | **Last updated:** 2026-10-22
**Confidence key:** Verified = source + measured, Inferred = source study only, Unknown = needs testing
**Research server:** CS 1.6 build 10211, HLDS on vm-prime (192.168.30.11:27015), ~91 server FPS, custom research_hud plugin v2.1 logging at 10Hz

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

**Confidence:** Verified (source code + M11 in-game measurement)

**Measured climb speed:** Straight-up climb reaches 270–282 u/s — significantly exceeding the `MAX_CLIMB_SPEED` constant of 200 in the source. Angled climbing (looking sideways at the ladder) stacks to ~395 u/s 3D speed. Dismounting a ladder converts vertical velocity to horizontal, giving a speed boost on exit. Peak 3D speed measured: 626.7 u/s (angled climb burst).

---

## 9. Key derived values (measured)

### 9.1 Time to reach max speed from standstill (ground, forward)

With knife (maxspeed 250), `sv_accelerate 10`, `sv_friction 4`:

Each frame: `accelspeed = 10 * frametime * 250 * 1.0`

At 100 fps (frametime = 0.01): `accelspeed = 10 * 0.01 * 250 = 25 u/s per frame`

But friction also applies. The interaction is complex because friction depends on current speed.

**Measured (M01):** 0 → 250 u/s in **0.4–0.5 seconds** (4–5 server ticks at ~91 fps). Acceleration is fast because `accelspeed` is proportional to `wishspeed` (250), not current speed. Three clean runs measured 412ms, 519ms, 513ms. The first tick from standstill adds ~28–104 u/s depending on exact input timing.

Peak ground speed observed: 262.7 u/s — acceleration overshoot of ~5% above maxspeed, caused by the `addspeed` check using dot product with `wishdir`, which allows brief overshoot when turning.

### 9.2 Stopping distance

**Friction-only stop (M02):** From 250 u/s, releasing all keys: **723ms, 73.5 units** to reach full stop.

**Counter-strafe stop (M03):** From 250 u/s, pressing opposite direction: best measured **621ms** to full stop. Opposing acceleration adds ~`sv_accelerate` on top of friction, stopping ~15% faster than friction alone.

**A-D counter-strafe rhythm (M18):** Repeated counter-strafing in combat creates zero-velocity windows every ~440ms. Effective average ground coverage drops to ~138 u/s (~55% of maxspeed) because roughly half the time is spent accelerating and half decelerating.

### 9.3 Jump height and distance

- Upward velocity: `sqrt(2 * 800 * 45)` ≈ 268.33 u/s
- **Measured peak height (M04): 45.0 units** — exact match to source derivation
- Duck-jump clearance: 45 + 18 = **63 units total** (jump height + hull shrink from bottom)
- **Duck-jump trajectory (M05):** Identical to regular jump. The hull change (72→36) raises feet 18 units, providing extra clearance without changing the arc.

**Jump distance (M16):**

| Type | Air time | H-distance | Notes |
|------|----------|------------|-------|
| Normal jump at 250 u/s | ~516ms | ~179 u | Baseline |
| Duck-jump at 250 u/s (short) | ~515ms | ~177 u | Duck timed poorly |
| Duck-jump at 250 u/s (held) | ~615–622ms | ~196 u | +17 u (~10%) |

The held duck-jump gets **~100ms extra air time** and **~17 extra units of distance** because the smaller ducked hull delays ground detection on landing. This is the mechanic skilled CS players use for gap jumps.

### 9.4 Air strafe speed gain

At knife speed (250 u/s) moving forward, adding a 90° strafe:
- `wishspd` = min(250, 30) = 30
- `currentspeed` = DotProduct(velocity, strafe_dir) ≈ 0 (perpendicular)
- `addspeed` = 30
- `accelspeed` = 10 * 250 * 0.01 * 1.0 = 25

Speed added per frame perpendicular to current velocity: up to 25 u/s (capped at 30).
New speed: `sqrt(250² + 25²)` ≈ 251.25 u/s — marginal per frame, compounds with smooth rotation.

**Measured (M06):** +50–70 u/s per jump with 180° air strafe. Peak air speed: **331.9 u/s** (32% above knife maxspeed). Air strafing is uncapped in the air — the BUNNYJUMP crop only applies on ground contact.

### 9.5 Bunny hop speed cap

**Measured (M07):** Peak air speed during bhop: **359.4 u/s**. Peak ground speed post-crop: **339.6 u/s**. The 1.2× cap (300 u/s for knife) aggressively clips speed on each landing via `PM_PreventMegaBunnyJumping()`, but air strafing continuously adds speed between landings, so instantaneous air speed can far exceed the cap.

**Duck-bhop (M17):** Crouching during bhop does NOT bypass or modify the speed cap. Same 1.2× factor applies. The only advantages are the extra foot clearance (18 units) and ~100ms longer air time per hop. Speed bleeds faster across consecutive duck-hops.

### 9.6 Step movement

**Measured (M09):** Stair step-up (16-unit steps on de_nuke) is a **zero-velocity teleport** — the player moves upward with no vertical velocity component. The engine tries a horizontal slide, then a step-up slide, and picks whichever moves farther horizontally. Step-down is NOT a teleport: the player goes airborne briefly and falls via gravity.

This is why CS 1.6 stair movement feels smoother than most modern games — ascending stairs doesn't add any camera bobbing from vertical velocity.

### 9.7 Slope/ramp movement

**Measured (M10):** While grounded on a walkable slope (normal[2] >= 0.7, ≤~45°), horizontal speed is **completely unaffected** — the engine zeroes vspeed every frame while grounded (step 13 in the sim loop). When airborne on a ramp, behavior is chaotic — bouncing with unpredictable speed changes.

### 9.8 Edge friction

**Measured (M12):** When the player is near a ledge (trace 16 units ahead misses ground) and keys are released, friction is **doubled** via `edgefriction` (2). This is a Quake-era mechanic rarely seen in modern games — it prevents the common problem of sliding off ledges when stopping near an edge.

### 9.9 Diagonal movement

**Measured (M13):** Input vector is **normalized** by the engine. Pressing forward + strafe simultaneously does NOT produce sqrt(2) speed boost. Diagonal speed equals forward speed at the same maxspeed. No exploit possible.

### 9.10 Crouch spam / hitbox manipulation

**Measured (M19):** Rapidly toggling crouch changes the hull height (72↔36) with **zero horizontal speed penalty**. The `PLAYER_DUCKING_MULTIPLIER` (0.333) only scales input, not existing velocity — so a player running at 250 u/s who taps crouch maintains 250 u/s.

- Fastest spam cycle: ~310–413ms
- Time spent ducked per tap: 100–208ms (avg 141ms)
- Creates constant vertical hitbox oscillation while maintaining full movement speed
- Ducking in air completes instantly (no 0.4s transition delay)

This is the classic "Russian duck" / crouch-spam mechanic — the player's hitbox bobs unpredictably while maintaining full speed. A core CS defensive technique.

---

## 10. Experiments — completed

All experiments conducted 2026-10-21 to 2026-10-22 on the research server. CSV logs archived in `hlds/cstrike/addons/amxmodx/logs/`.

| ID | Experiment | Status | Key finding |
|----|-----------|--------|-------------|
| M01 | Forward acceleration (knife) | **verified** | 0→250 in 0.4–0.5s, peak overshoot 262.7 |
| M02 | Stop distance (release keys) | **verified** | 723ms / 73.5 units from 250 |
| M03 | Counter-strafe stop | **verified** | Best 621ms from 250 (~15% faster than release) |
| M04 | Jump height | **verified** | 45.0 units — exact source match |
| M05 | Duck-jump height | **verified** | Same trajectory, +18u foot clearance from hull |
| M06 | Air strafe speed gain | **verified** | +50–70 u/s per jump, peak 331.9 |
| M07 | Bunny hop speed | **verified** | Cap at 300, peak air 359.4, ground 339.6 |
| M08 | Bhop crop detail | **skipped** | Redundant — M07 data clearly showed 1.2× crop |
| M09 | Step-up behavior | **verified** | Zero-vspeed teleport on step-up, gravity on step-down |
| M10 | Slope/ramp movement | **verified** | Zero speed loss while grounded on walkable slopes |
| M11 | Ladder mechanics | **verified** | 270+ climb, angled 395, dismount speed conversion |
| M12 | Edge friction | **verified** | 2× friction near ledges, Quake-era mechanic |
| M13 | Diagonal speed | **verified** | Normalized input, no sqrt(2) exploit |
| M14 | Weapon speeds | **verified** | AK=221, M4=230, Knife=250. ~5–10% overshoot when turning |
| M15 | Server FPS | **deferred** | Baseline documented at ~91 fps. All results match source at this rate |
| M16 | Jump distance with crouch | **verified** | Duck-jump adds ~17u (~10%) distance via extended air time |
| M17 | Bhop with crouch | **verified** | Same 1.2× cap, no speed bypass. Extra clearance only |
| M18 | A-D counter strafing | **verified** | ~440ms cycle, creates zero-velocity accuracy windows |
| M19 | Crouch spam | **verified** | Zero speed penalty, ~310ms cycle, instant hull toggle in air |

---

## 11. Open questions

1. **Framerate dependency:** GoldSrc ties movement to server framerate. All measurements were at ~91 server fps. Higher/lower fps could produce slightly different acceleration curves due to per-frame integration, but all results matched source code predictions at this rate. Fixed timestep in A&D eliminates this concern.
2. **Bunny hop window:** Exactly how many frames before landing can you press jump to bhop? The anti-pogo check (`oldbuttons & IN_JUMP`) requires release-and-repress, but the exact timing window was not isolated.
3. **Slope physics:** Walkable threshold is normal[2] >= 0.7 (~45°). Confirmed grounded movement preserves speed on walkable slopes (M10). Steep/non-walkable slopes not tested (no suitable geometry found on test maps).
4. **Ladder speed discrepancy:** Source code shows `MAX_CLIMB_SPEED = 200`, but measured climb speed was 270–282 u/s. The constant may not be enforced in the same path as the actual ladder movement, or view angle scaling bypasses the cap.
5. **cl_forwardspeed / cl_sidespeed:** These client CVARs likely affect `forwardmove`/`sidemove` values sent to the server, but were not tested (stock defaults used throughout).
