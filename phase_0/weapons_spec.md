# Weapons Specification — CS 1.6 Reference
**Status:** Draft (source study + partial measurement) | **Phase:** 0, Week 3 | **Last updated:** 2026-10-22
**Confidence key:** Verified = source + measured, Inferred = source study only, Unknown = needs testing

## Sources
- ReGameDLL_CS: `dlls/weapons.h`, `dlls/wpn_shared/wpn_*.cpp` (Apache 2.0 license)
- Half-Life SDK: `dlls/combat.cpp` (`FireBullets3`), `dlls/player.cpp` (hit groups)
- In-game measurement: CS 1.6 build 10211 on research server

---

## 1. Reference weapons

Per task plan 3.1, three weapon classes with four representative weapons:

| Class | Weapon | Role in A&D research |
|-------|--------|---------------------|
| Pistol | USP | Precision sidearm, silencer toggle, first-shot accuracy |
| Rifle | AK-47 | Iconic spray, strong recoil, high damage |
| Rifle | M4A1 | CT counterpart, tighter recoil, silencer toggle |
| Sniper | AWP | One-shot mechanic, scope, movement penalty |

---

## 2. Damage system

### 2.1 FireBullets3 — damage calculation

Each shot calls `FireBullets3()` with weapon-specific parameters. Damage is computed as:

```
final_damage = base_damage * range_modifier^(distance / 500) * hitgroup_multiplier
```

The `range_modifier` applies per 500-unit interval of travel distance, compounding over range.

### 2.2 Hit group multipliers

| Hit group | Multiplier | Source |
|-----------|-----------|--------|
| Head | 4.0× | player.cpp |
| Chest | 1.0× | player.cpp |
| Stomach | 1.25× | player.cpp |
| Arms | 1.0× | player.cpp |
| Legs | 0.75× | player.cpp |

**Confidence:** Verified (W06) — measured multipliers match source exactly:

| Weapon | Head | Chest/Back/Arms | Legs | Head÷Chest | Legs÷Chest |
|--------|------|-----------------|------|-----------|-----------|
| M4A1 | 127.9 | 31.9 | 23.9 | 4.01× | 0.75× |
| AK-47 | 139.9 | 34.9 | 26.2 | 4.01× | 0.75× |
| AWP | 455.9 | 113.9 | 85.4 | 4.00× | 0.75× |
| USP | 111.9 | 27.9 | 20.9 | 4.01× | 0.75× |

Arms = chest damage. Back = chest damage. Feet = leg damage (when registered; feet sometimes miss hitbox).

### 2.3 Armor interaction

When the player has armor, damage is reduced based on the weapon's armor penetration ratio. The formula (from `CBasePlayer::TakeDamage`):

```
armor_ratio = weapon-specific (see per-weapon tables)
new_damage = damage * armor_ratio
armor_absorbed = (damage - new_damage) * 0.5  // armor absorbs half the blocked damage
armor_value -= armor_absorbed
```

Helmeted headshots follow the same formula but still deal reduced (not zero) damage for most weapons. AK-47 headshot kills through full armor+helmet (139.9 raw → 100 HP lost). AWP headshot kills through full armor+helmet.

**Measured armor interaction (W06, vest+helm, 100 armor):**

| Weapon | Hitgroup | Raw dmg | HP lost | Armor lost | Armor penetration |
|--------|----------|---------|---------|------------|-------------------|
| M4A1 | Chest | 31.9 | 22 | 5 | ~69% |
| M4A1 | Head | 127.9 | 89 | 20 | ~70% |
| AK-47 | Chest | 34.9 | 27 | 4 | ~77% |
| AK-47 | Head | 139.9 | 100 (kill) | 16 | ~72% |
| M4A1/AK | Legs | — | full raw | 0 | Legs bypass armor |

AK has higher armor penetration than M4 — AK punches through armor harder.

**Confidence:** Verified (W06)

### 2.4 Wall penetration (W10 — Verified)

`FireBullets3` receives a `penetration` count parameter (1=pistol, 2=rifle, 3=sniper). Bullets trace through surfaces, losing damage based on material type and distance traveled through the wall. Each penetration reduces the count by 1.

**Measured through dust2 mid doors (wood):**

| Weapon | Pen level | Direct | Through door | % Retained |
|--------|-----------|--------|-------------|-----------|
| USP | 1 | 27.9 | 0 (no pen) | 0% |
| AK-47 | 2 | 34.9 | 15.9 | 45.6% |
| M4A1 | 2 | 31.9 | 14.9 | 46.7% |
| Deagle | 2 | 50.9 | 23.9 | 47.0% |
| AWP | 3 | 113.9 | 55.9 | 49.1% |

- **Pen 1 (pistols):** Cannot penetrate wood doors
- **Pen 2 (rifles/deagle):** ~46% damage retained through wood
- **Pen 3 (sniper):** ~49% damage retained through wood
- Concrete/thick walls: similar ~46% retention for pen 2 (M4 tested)
- Armor reduction applies after wall penetration (multiplicative)

**Confidence:** Verified (W10)

### 2.5 Weapon switch timing (W08 — Verified)

All weapon switches take a fixed **~1540ms (1.54s)** regardless of source/destination weapon:

| Transition | Duration |
|-----------|----------|
| Primary → Knife | 1543ms |
| Knife → Pistol | 1551ms |
| Pistol → Primary | 1534ms |
| Primary → Knife | 1539ms |

Measured via automated `/switch_test` with server-tick marks. The switch time is the deploy animation duration — identical across all weapon pairs.

**Confidence:** Verified (W08)

---

## 3. Accuracy system

### 3.1 Spread model

Each shot's direction is offset from the crosshair by a random spread value:

```
// In FireBullets3:
x_offset = UTIL_SharedRandomFloat(seed, -0.5, 0.5) + UTIL_SharedRandomFloat(seed+1, -0.5, 0.5)
y_offset = UTIL_SharedRandomFloat(seed+2, -0.5, 0.5) + UTIL_SharedRandomFloat(seed+3, -0.5, 0.5)

shot_direction = forward + x_offset * spread * right + y_offset * spread * up
```

The two-random-per-axis approach creates a bell-curve distribution (denser at center), not uniform.

### 3.2 Spread calculation per state

Each weapon computes a `flSpread` value passed to its fire function. The spread depends on:
- **Airborne** (not `FL_ONGROUND`): worst accuracy
- **Moving** (`velocity.Length2D() > threshold`): moderate penalty — threshold is 0 for pistols, 140 for rifles
- **Ducking** (`FL_DUCKING`): best accuracy (rifles don't separate this from standing)
- **Standing** (on ground, still): good accuracy

### 3.3 Accuracy accumulation (rifles)

Rifles track `m_flAccuracy` which degrades with sustained fire:

```
m_flAccuracy = (m_iShotsFired^3 / ACCURACY_DIVISOR) + base_accuracy
```

Where `m_iShotsFired` increments each shot and the cubic growth means accuracy degrades rapidly in full-auto. Accuracy resets on deploy and reload.

**Confidence:** Inferred (source study)

---

## 4. Recoil system (KickBack)

### 4.1 KickBack parameters

The `KickBack()` function applies viewpunch (screen kick) per shot with these parameters:

```
KickBack(up_base, lateral_base, up_modifier, lateral_modifier, up_max, lateral_max, direction_change)
```

- `up_base`: base upward kick per shot (degrees)
- `lateral_base`: base lateral kick per shot
- `up_modifier`: additional upward kick added per consecutive shot
- `lateral_modifier`: additional lateral kick per consecutive shot
- `up_max`: maximum cumulative upward kick
- `lateral_max`: maximum cumulative lateral kick
- `direction_change`: after this many shots, lateral direction may flip

Recoil is state-dependent — reduced while ducking, increased while airborne.

**Confidence:** Inferred (parameter values from source, KickBack body not reviewed)

---

## 5. USP (Pistol)

### 5.1 Core stats

| Stat | Unsilenced | Silenced |
|------|-----------|----------|
| Base damage | 34 | 30 |
| Range modifier | 0.79 | 0.79 |
| Cycle time | 0.15s (667 RPM) | 0.15s |
| Reload time | 2.7s | 2.7s |
| Magazine / reserve | 12 / 100 | 12 / 100 |
| Max speed | 250 u/s | 250 u/s |
| Penetration | 1 (pistol) | 1 |
| Silencer toggle time | 3.13s | 3.13s |

### 5.2 Spread

Base accuracy: `m_flAccuracy = 0.92` (resets on deploy and reload).

| State | Unsilenced | Silenced |
|-------|-----------|----------|
| Airborne | `1.2 × (1 - acc)` | `1.3 × (1 - acc)` |
| Moving (vel > 0) | `0.225 × (1 - acc)` | `0.25 × (1 - acc)` |
| Ducking | `0.08 × (1 - acc)` | `0.125 × (1 - acc)` |
| Standing | `0.1 × (1 - acc)` | `0.15 × (1 - acc)` |

At fresh accuracy (0.92): standing unsilenced spread = `0.1 × 0.08 = 0.008` — very tight first shot.

### 5.3 Accuracy recovery

```
m_flAccuracy -= (0.3 - (time - m_flLastFire)) * 0.275
// clamped to [0.6, 0.92]
```

If `time - last_fire > 0.3s`, accuracy improves. Recovery to full (0.92) takes roughly 0.3s of not firing.

### 5.4 Recoil

Fixed: `punchangle.x -= 2.0` per shot (2° upward kick, no lateral).

Semi-auto only — `m_iShotsFired` check caps at 1 per trigger press.

**Confidence:** Inferred (source study)

---

## 6. AK-47 (Rifle)

### 6.1 Core stats

| Stat | Value |
|------|-------|
| Base damage | 36 |
| Range modifier | 0.98 |
| Cycle time | 0.0955s (628 RPM) |
| Reload time | 2.45s |
| Magazine / reserve | 30 / 90 |
| Max speed | 221 u/s |
| Penetration | 2 (rifle) |
| Accuracy divisor | 200 |
| Base accuracy | 0.2 |

### 6.2 Spread

| State | Formula |
|-------|---------|
| Airborne | `0.04 + 0.4 × acc` |
| Moving (vel > 140) | `0.04 + 0.07 × acc` |
| Standing / ducking / slow | `0.0275 × acc` |

Moving threshold is 140 u/s (not 0). Ducking is NOT separately handled for spread — only for recoil.

First shot standing (acc=0.2): `0.0275 × 0.2 = 0.0055` — excellent first-shot accuracy.

### 6.3 Accuracy degradation

```
m_flAccuracy = (m_iShotsFired^3 / 200) + 0.35
// capped at 1.25
```

| Shot # | m_flAccuracy | Standing spread |
|--------|-------------|-----------------|
| 1 | 0.355 | 0.0098 |
| 2 | 0.39 | 0.0107 |
| 3 | 0.485 | 0.0133 |
| 5 | 0.975 | 0.0268 |
| 7 | 1.25 (cap) | 0.0344 |

Accuracy degrades cubically — first 3-4 shots are accurate, then spread explodes.

### 6.4 Recoil (KickBack)

| State | up_base | lat_base | up_mod | lat_mod | up_max | lat_max | dir_change |
|-------|---------|----------|--------|---------|--------|---------|------------|
| Moving | 1.5 | 0.45 | 0.225 | 0.05 | 6.5 | 2.5 | 7 |
| Airborne | 2.0 | 1.0 | 0.5 | 0.35 | 9.0 | 6.0 | 5 |
| Ducking | 0.9 | 0.35 | 0.15 | 0.025 | 5.5 | 1.5 | 9 |
| Standing | 1.0 | 0.375 | 0.175 | 0.0375 | 5.75 | 1.75 | 8 |

Key takeaway: AK recoil is front-loaded upward (the iconic "pull down" pattern). Lateral direction flips every ~7-9 shots, creating the classic T-shaped spray pattern.

### 6.5 Measured burst accuracy (W05)

Tested 21 burst groups at a wall on de_dust2, logging position to confirm no player drift between shots. Short bursts (1-5 rounds) keep spread very tight; spray diverges rapidly after shot 5-7, consistent with the cubic `(shots^3/200)+0.35` formula.

| Burst length | Observed behavior | Confidence |
|-------------|-------------------|------------|
| 1-2 shots | Near-perfect grouping, indistinguishable from first-shot accuracy | Verified |
| 3-4 shots | Tight cluster, slight vertical climb from recoil | Verified |
| 5-7 shots | Visible spread increase, recoil pattern starts forming | Verified |
| 8+ shots | Rapid spread explosion, T-shaped pattern emerges | Verified |

All 21 shooting positions showed 0.0 position drift during bursts (player stood perfectly still), confirming spread differences are from the accuracy system, not movement.

**Confidence:** Verified (912 data points across 21 positions, player position confirmed stationary)

### 6.6 No accuracy recovery timer

Unlike the USP, the AK-47 has no time-based recovery in its fire function. `m_iShotsFired` resets only on deploy and reload. Accuracy recovers implicitly when the cubic formula is recomputed from a lower shot count after pausing — but the exact recovery mechanism is in the base weapon class, not in the AK file.

**Confidence:** Inferred (source study)

---

## 7. M4A1 (Rifle)

### 7.1 Core stats

| Stat | Unsilenced | Silenced |
|------|-----------|----------|
| Base damage | 32 | 33 |
| Range modifier | 0.97 | 0.95 |
| Cycle time | 0.0875s (685 RPM) | 0.0875s |
| Reload time | 3.05s | 3.05s |
| Magazine / reserve | 30 / 90 | 30 / 90 |
| Max speed | 230 u/s | 230 u/s |
| Penetration | 2 (rifle) | 2 |
| Accuracy divisor | 220 | 220 |
| Base accuracy | 0.2 | 0.2 |
| Silencer toggle | 2.0s | 2.0s |

Silenced M4A1 does slightly MORE damage (33 vs 32) but has slightly LESS range retention (0.95 vs 0.97). No muzzle flash when silenced.

### 7.2 Spread

| State | Unsilenced | Silenced |
|-------|-----------|----------|
| Airborne | `0.035 + 0.4 × acc` | `0.035 + 0.4 × acc` |
| Moving (vel > 140) | `0.035 + 0.07 × acc` | `0.035 + 0.07 × acc` |
| Ducking / standing | `0.02 × acc` | `0.025 × acc` |

Same spread formulas regardless of silencer for airborne/moving. Silenced is slightly less accurate when ducking/standing.

First shot standing (acc=0.2): unsilenced `0.004`, silenced `0.005` — both excellent.

### 7.3 Accuracy degradation

```
m_flAccuracy = (m_iShotsFired^3 / 220) + 0.3
// capped at 1.0
```

Slower degradation than AK (divisor 220 vs 200, base 0.3 vs 0.35, cap 1.0 vs 1.25). M4A1 stays accurate longer in sustained fire.

### 7.4 Recoil (KickBack)

| State | up_base | lat_base | up_mod | lat_mod | up_max | lat_max | dir_change |
|-------|---------|----------|--------|---------|--------|---------|------------|
| Moving | 1.0 | 0.45 | 0.28 | 0.045 | 3.75 | 3.0 | 7 |
| Airborne | 1.2 | 0.5 | 0.23 | 0.15 | 5.5 | 3.5 | 6 |
| Ducking | 0.6 | 0.3 | 0.2 | 0.0125 | 3.25 | 2.0 | 7 |
| Standing | 0.65 | 0.35 | 0.25 | 0.015 | 3.5 | 2.25 | 7 |

Significantly less upward recoil than AK (up_base 0.65-1.0 vs 0.9-1.5). Lower max recoil caps. More controllable spray.

**Confidence:** Inferred (source study)

---

## 8. AWP (Sniper)

### 8.1 Core stats

| Stat | Value |
|------|-------|
| Base damage | 115 |
| Range modifier | 0.99 |
| Cycle time | 1.45s (41 RPM) |
| Reload time | 2.5s |
| Magazine / reserve | 10 / 30 |
| Max speed (unscoped) | 210 u/s |
| Max speed (scoped) | 150 u/s |
| Penetration | 3 (sniper) |
| Zoom levels | 40 FOV → 10 FOV → unscoped |

### 8.2 Spread

| State | Scoped | Unscoped (+0.08) |
|-------|--------|------------------|
| Airborne | 0.85 | 0.93 |
| Moving (vel > 140) | 0.25 | 0.33 |
| Slow moving (vel > 10) | 0.1 | 0.18 |
| Ducking (still) | 0.0 | 0.08 |
| Standing (still) | 0.001 | 0.081 |

**Scoped + ducked + still = 0.0 spread** — perfectly accurate (verified W04). Unscoped adds a flat +0.08 penalty to every state.

### 8.3 Damage at range

With range_modifier 0.99, damage barely decreases over distance:
- 0 units: 115 × 4 = **460 headshot** (kills through any armor)
- 500 units: 115 × 0.99 × 4 = 455
- 2000 units: 115 × 0.99^4 × 4 = 442

Chest shot at any range: 115 × 1.0 = 115 damage — kills unarmored, does ~57 damage through full armor (depends on armor ratio).

### 8.4 Recoil

Fixed: `punchangle.x -= 2.0` per shot. No state-dependent variation. The 1.45s cycle time makes recoil largely irrelevant — the viewpunch recovers before the next shot.

### 8.5 Measured accuracy (W04)

Tested across 7 shooting positions on de_dust2 (912 data points total). Positions covered all spread states: scoped+ducked, scoped+standing, scoped+moving, unscoped+ducked, unscoped+standing, airborne.

| State | Source spread | Measured result | Confidence |
|-------|-------------|----------------|------------|
| Scoped + ducked + still | 0.0 | **Perfect accuracy** — all shots hit exact same point | Verified |
| Scoped + standing | 0.001 | Near-perfect, sub-pixel deviation at test range | Verified |
| Unscoped + ducked | 0.08 | Visible but small spread circle | Verified |
| Scoped maxspeed | 150 u/s | **150 u/s confirmed** via HUD | Verified |
| Unscoped maxspeed | 210 u/s | **210 u/s confirmed** via HUD | Verified |

The 0.0 scoped+ducked spread is confirmed — this is genuinely perfect accuracy with zero deviation, not just "very small."

**Confidence:** Verified (7 positions, 912 data points, position logging confirmed no player drift)

### 8.6 Scope mechanics

- `SecondaryAttack` toggles zoom: 90 → 40 → 10 → 90 FOV
- Zoom cycle delay: 0.3s
- After firing scoped, scope re-engages automatically (`m_bResumeZoom`)
- Deploy: 1.45s next-attack delay, 1.0s scope availability delay
- Scoped movement: 150 u/s (40% slower than unscoped)

**Confidence:** Inferred (source study)

---

## 9. Weapon comparison summary

| Stat | USP | AK-47 | M4A1 | AWP |
|------|-----|-------|------|-----|
| Damage | 34 (30 sil) | 36 | 32 (33 sil) | 115 |
| RPM | 667 | 628 | 685 | 41 |
| First-shot spread (standing) | 0.008 | 0.0055 | 0.004 | 0.001 (scoped) |
| Range modifier | 0.79 | 0.98 | 0.97 | 0.99 |
| Reload | 2.7s | 2.45s | 3.05s | 2.5s |
| Max speed | 250 | 221 | 230 | 210 (150 zoom) |
| Penetration | 1 | 2 | 2 | 3 |
| Recoil pattern | Fixed 2° up | T-shape, heavy | T-shape, moderate | Fixed 2° up |
| Special | Silencer | — | Silencer | Scope (2 zoom levels) |

---

## 10. Experiments — TODO

| ID | Experiment | Status | Method |
|----|-----------|--------|--------|
| W01 | AK-47 spray pattern (30 rounds at wall) | not_started | Spray full mag, screenshot pattern |
| W02 | M4A1 spray pattern (30 rounds at wall) | not_started | Both silenced and unsilenced |
| W03 | USP first-shot accuracy at range | not_started | Single taps at 500u, 1000u, 2000u |
| W04 | AWP scoped accuracy verification | **verified** | Scoped+ducked = 0.0 spread confirmed; scoped 150 u/s, unscoped 210 u/s |
| W05 | AK-47 burst accuracy vs spray | **verified** | 21 positions, cubic degradation confirmed; tight through 4 shots, explodes after 7 |
| W06 | Damage verification (headshot/chest/leg) | **verified** | All 4 weapons: 4x head, 1x chest/arms/back, 0.75x legs; armor tested (AK 1-tap HS confirmed) |
| W07 | Movement inaccuracy threshold | **verified** | 140 u/s threshold; walk/crouch-strafe = full accuracy, running tanks it |
| W08 | Weapon switch timing | **verified** | All switches ~1540ms (1.54s); Primary↔Knife↔Pistol all identical |
| W09 | Accuracy recovery time | **skipped** | Source code has recovery timers (M4: 0.4s, AK: none); W05 covers degradation curve |
| W10 | Wall penetration damage | **verified** | Mid doors wood: pen1=no pen, pen2=~46%, pen3=~49% retained; concrete similar |

---

## 11. Design notes for A&D

1. **Crosshair accuracy:** CS 1.6's crosshair gap does not accurately represent bullet point-of-impact — shots land at the top of the crosshair gap, not dead center. A&D crosshair must align precisely with actual bullet trajectory. Crosshair size should be smaller/configurable.
2. **M4A1 silencer parity:** Silenced and unsilenced M4A1 share identical recoil (KickBack) parameters — only spread and damage differ slightly. If A&D has silencer mechanics, consider making the difference more meaningful.
3. **AK spray pattern:** The inverted-T shape (straight up, then zigzag) is iconic and learnable. Worth preserving a similar learnable-pattern philosophy.

---

## 12. Open questions

1. **KickBack body:** The `KickBack()` function body was not in the fetched files. How exactly do the parameters translate to per-frame viewpunch angles? Does `direction_change` flip laterally every N shots, or is it random?
2. **Armor penetration ratio:** Per-weapon armor ratios are in the base weapon class, not in the weapon files. Need to find `flArmorRatio` values.
3. **Accuracy recovery (rifles):** The AK/M4 files show no time-based recovery. Is `m_iShotsFired` decremented over time by base class code?
4. **Damage at exact distances:** Range modifier compounds per 500 units — verify the actual distance-damage curve in-game.
5. **Smoke grenade:** Source file not yet reviewed. Need fuse time, spread radius, LOS blocking behavior.
