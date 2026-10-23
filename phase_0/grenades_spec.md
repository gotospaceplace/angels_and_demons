# Grenades Specification — CS 1.6 Reference
**Status:** Draft (source study + partial measurement) | **Phase:** 0, Week 3 | **Last updated:** 2026-10-22
**Confidence key:** Verified = source + measured, Inferred = source study only, Unknown = needs testing

## Sources
- ReGameDLL_CS: `dlls/wpn_shared/wpn_hegrenade.cpp`, `wpn_flashbang.cpp`, `wpn_smokegrenade.cpp` (Apache 2.0)
- In-game measurement: CS 1.6 build 10211 on research server

---

## 1. Shared grenade mechanics

### 1.1 Throw velocity

All three grenade types use the same throw formula:

```
// Pitch adjustment (maps view angle to throw angle)
if angThrow.x < 0:
    angThrow.x = -10 + angThrow.x * ((90 - 10) / 90.0)    // looking up
else:
    angThrow.x = -10 + angThrow.x * ((90 + 10) / 90.0)    // looking down

flVel = (90.0 - angThrow.x) * 6.0
flVel = min(flVel, 750.0)                                   // cap at 750 u/s

vecThrow = forward * flVel + player_velocity                 // inherits player speed
```

**Key observations:**
- Looking straight up (~-89°): throw angle = -10 + (-89) × (80/90) ≈ -89.1° → velocity = (90 - (-89.1)) × 6 = 1074, capped to **750 u/s**
- Looking level (0°): throw angle = -10 → velocity = (90 - (-10)) × 6 = **600 u/s**
- Looking down (~89°): throw angle = -10 + 89 × (100/90) ≈ 88.9° → velocity = (90 - 88.9) × 6 ≈ **6.7 u/s** (drop at feet)
- **Grenade inherits player velocity** — running forward + throwing adds ~250 u/s to the grenade

### 1.2 Spawn origin

```
vecSrc = player_origin + view_offset + forward * 16
```

Grenade spawns 16 units in front of the player's eye position.

### 1.3 Throw timing (shared)

| Phase | Duration | Notes |
|-------|----------|-------|
| Pin pull | 0.5s | `PrimaryAttack` → idle |
| Throw animation | 0.75s | After release in `WeaponIdle` |
| Next attack delay | 0.5s | Can't throw again for 0.5s |
| Holster delay | 0.5s | Switching away from grenade |

The throw is a two-stage process:
1. **PrimaryAttack** starts the pin pull animation, sets `m_flStartThrow`
2. **WeaponIdle** detects pin is pulled, plays throw animation, calls `ThrowGrenade()`
3. If you hold the button, the grenade isn't released until you let go (cook time is NOT a thing in CS 1.6 — the fuse starts on throw, not on pin pull)

### 1.4 Fuse time

All three grenades: **1.5 seconds** from the moment of throw (the `ThrowGrenade()` call).

**Important:** CS 1.6 has no grenade cooking. The fuse starts when the grenade leaves your hand, not when you pull the pin. Holding the throw button longer does NOT reduce time before detonation.

### 1.5 Bounce physics

Bounce behavior is handled by the grenade entity's `MOVETYPE_BOUNCE` with `sv_bounce` (default 1). Grenades bounce off surfaces with reduced velocity. The coefficient of restitution and friction on the grenade entity are set in the `ThrowGrenade` function (not in the weapon files).

**Confidence:** Inferred (bounce parameters not in fetched source — needs grenade entity code or in-game measurement)

### 1.6 Measured throw distances (G07)

Tested on fy_snow with smoke grenades. Player walked to landing spot and marked position for distance measurement.

| Throw condition | 2D distance | Notes |
|----------------|-------------|-------|
| Stationary, level (0°) | **675u** | Matches ~600 u/s throw velocity |
| Stationary, angled up (~30-45°) | **1173-1260u** | Higher angle = more distance |
| Stationary, straight up (~90°) | **0u** | Grenade returns to feet (hit skybox) |
| Running forward (250 u/s), level | **979u** | +304u from velocity inheritance |
| Running forward, angled up | **1539u** | Hit fy_snow skybox ceiling |
| Jump throw (airborne) | **1065u** | 44u elevation at throw |

**Key observations:**
- **Velocity inheritance confirmed:** Running adds ~250 u/s (knife maxspeed) to grenade velocity — level throw goes from 675u to 979u (+45%)
- **Straight-up throw:** Grenade velocity caps at 750 u/s but goes nearly vertical; lands at feet after 1.5s fuse
- **Skybox limitation:** fy_snow has a low skybox — angled running/jumping throws hit the ceiling. Distances would be greater on maps with higher skyboxes
- **Jump throws** add both height and horizontal distance vs standing throws

**Confidence:** Verified (distances measured from player position marks, ±5u precision from walking to landing spot)

---

## 2. HE Grenade

### 2.1 Core stats

| Stat | Value | Source |
|------|-------|--------|
| Fuse time | 1.5s | wpn_hegrenade.cpp |
| Max throw velocity | 750 u/s | wpn_hegrenade.cpp |
| `pev->dmg` | 4 | Spawn() — purpose unclear, damage likely set elsewhere |
| Max speed (holding) | `HEGRENADE_MAX_SPEED` | Header (value not fetched) |

### 2.2 Explosion mechanics (G01/G02 — Verified)

| Stat | Value | Confidence |
|------|-------|------------|
| Base damage | **~100** (96.9 self at 9.6u) | Verified |
| Blast radius | **~350 units** | Verified |
| Damage falloff | **Linear:** `dmg = 100 × (1 - dist/350)` | Verified |
| Armor penetration | **50%** (armor absorbs half) | Verified |
| Self-damage | Yes, same formula | Verified |
| Team damage | Follows `mp_friendlyfire` | Inferred |

**Measured HE damage vs distance (no armor):**

| Grenade-to-victim | Raw damage | HP lost |
|-------------------|-----------|---------|
| 32u | 90.6 | 90 |
| 135u | 61.3 | 61 |
| 234u | 33.2 | 33 |
| 332u | 5.1 | 5 |

Formula fit: predicted vs measured within ±0.3 across all distances. With vest+helm, damage is halved (50% armor penetration — lower than rifles).

---

## 3. Flashbang

### 3.1 Core stats

| Stat | Value | Source |
|------|-------|--------|
| Fuse time | 1.5s | wpn_flashbang.cpp |
| Max throw velocity | 750 u/s | wpn_flashbang.cpp |
| Max carry | 2 | Standard CS 1.6 |

### 3.2 Flash mechanics (G03/G04 — Verified)

**Flash duration by viewing angle (point-blank self-flash):**

| Angle to flash | Full blind | Fade | Total effect |
|----------------|-----------|------|--------------|
| 0° (facing) | **3.0s** | 5.7s | 10.0s |
| 45° | 2.3s | 4.5s | 6.8s |
| 90° | 1.9s | 2.8s | 4.7s |
| 180° (away) | **0s** (no white screen) | ~4.7s minor tint | ~4.7s |

**Key findings:**
- Flash effect scales roughly linearly with angle
- Turning fully away (180°) eliminates the full blind entirely — only a slight screen tint
- Self-flash confirmed — same effect as being flashed by an enemy
- Fuse time ~1.7s from throw to detonation (consistent with 1.5s fuse + travel time)

Flash intensity depends on:
1. **Angle** — most significant factor; 180° turn negates full blind
2. **Distance** — closer = stronger (not yet measured independently)
3. **Line of sight** — walls block flash entirely (inferred, not tested)

---

## 4. Smoke Grenade

### 4.1 Core stats

| Stat | Value | Source |
|------|-------|--------|
| Fuse time | 1.5s | wpn_smokegrenade.cpp |
| Max throw velocity | 750 u/s | wpn_smokegrenade.cpp |
| Max carry | 1 | Standard CS 1.6 |

### 4.2 Smoke mechanics

The smoke cloud behavior is in the `createsmoke` event and grenade entity code, not in the weapon file. Known from community documentation:

| Stat | Value | Confidence |
|------|-------|------------|
| Smoke duration | **25.3s** | Verified (G05) |
| Cloud diameter | **~204 units** (radius ~102u) | Verified (G06) |
| Visibility blocking | Very light — slight brown tint, can see through | Verified (G06) |
| Damage | None | Inferred |
| Blocks flashbang LOS | Unknown | Unknown |

### 4.3 Measured values (G05)

| Stat | Measured value | Confidence |
|------|---------------|------------|
| Throw → cloud visible | 2.7s | Verified |
| Smoke visible duration | **25.3s** | Verified |
| Total throw → clear | 28.0s | Verified |

The measured 25.3s smoke duration is significantly longer than community estimates of 18-20s. Fuse time (1.5s source) plus ~1.2s cloud spread animation accounts for the 2.7s throw-to-visible delay.

### 4.3a Design decision: A&D smoke upgrade

CS 1.6 smoke is nearly useless — thin, transparent, small radius (204u). **A&D will use CS2-style smokes:** a defined volume (~300u diameter) with reliable vision blocking via screen-space post-process fog. This is the single biggest tactical upgrade from 1.6 and makes smokes worth buying. Implementation: Phase 1+, medium complexity.

---

## 5. Experiments — TODO

| ID | Experiment | Status | Method |
|----|-----------|--------|--------|
| G01 | HE grenade damage at distances | **verified** | Linear falloff: `100 × (1 - dist/350)`, measured at 32/135/234/332u |
| G02 | HE grenade blast radius | **verified** | ~350u (derived from G01 formula, 5.1 dmg at 332u) |
| G03 | Flashbang full-flash duration | **verified** | Point-blank: 3.0s blind, 5.7s fade, 10.0s total |
| G04 | Flashbang angle test (0°/45°/90°/180°) | **verified** | Linear reduction; 180° eliminates full blind entirely |
| G05 | Smoke duration (start to dissipate) | **verified** | Throw→visible 2.7s, visible duration 25.3s, total 28.0s |
| G06 | Smoke radius | **verified** | ~204u diameter (102u radius), very light/transparent |
| G07 | Throw distance at various angles | **verified** | Level=675u, angled=1173-1260u, running=979u, jump=1065u |
| G08 | Bounce behavior (off walls/floor) | **skipped** | CS 1.6 bounce is quirky; A&D will design better bounce physics |

---

## 6. Open questions

1. **Grenade entity code:** The detonation, blast damage, flash effect, and smoke cloud code was not in the weapon files. Need to find `CGrenade` class implementation in ReGameDLL.
2. ~~**Bounce coefficient:**~~ Skipped — A&D will design its own bounce physics (G08 skipped).
3. ~~**Smoke visibility:**~~ Measured (G06): simple radius ~102u, very light particle effect. A&D will use CS2-style volumetric.
4. ~~**Flash angle formula:**~~ Measured (G04): roughly linear with angle, 180° negates full blind.
5. **Underhand throw:** CS 1.6 has right-click throw (short toss). The weapon files show only `PrimaryAttack` — is the underhand throw a separate mechanism or just a lower-velocity variant?

## 7. A&D Design Decisions

| Topic | CS 1.6 behavior | A&D decision | Rationale |
|-------|-----------------|-------------|-----------|
| Smoke opacity | Thin, see-through | CS2-style opaque volume | Smoke must reliably block vision to be tactically useful |
| Smoke radius | ~204u diameter | ~300u diameter | Needs to cover common choke points |
| Smoke implementation | Billboard particles | Screen-space post-process fog | Reliable, moderate complexity |
| Bounce physics | Quirky/inconsistent | Custom design (TBD) | CS 1.6 bounce not worth replicating |
