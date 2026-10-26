# PHASE 3 — Gunplay and Grenades Laboratory
**Status:** Not started | **Version:** 1.0 | **Date:** 2026-10-25

## Scope
Implement representative firearms with authoritative hitscan damage, GoldSrc-faithful recoil and accuracy systems, armor interaction, wall penetration, all three grenade types (HE, flashbang, smoke), weapon switching, and A&D modifications — in a gray-box combat test range with telemetry for validation against Phase 0 reference measurements.

### In scope
- Four representative weapons: USP (pistol), AK-47 (rifle), M4A1 (rifle), AWP (sniper)
- Knife (melee, always equipped, fastest switch)
- Hitscan damage system with hit group multipliers (head 4×, stomach 1.25×, legs 0.75×)
- Armor and helmet system with per-weapon penetration ratios
- Wall penetration (3-tier: pistol/rifle/sniper)
- GoldSrc accuracy model: two-random-per-axis spread, state-dependent (standing/moving/airborne/ducking)
- Accuracy degradation on sustained fire (cubic curve for rifles)
- Recoil system (KickBack: viewpunch per shot, state-dependent, directional)
- Per-weapon maxspeed (knife 250, M4 230, AK 221, AWP 210/150 scoped)
- Movement inaccuracy: 140 u/s threshold wired to spread
- Weapon switching with A&D per-weapon draw times (not CS 1.6's fixed 1.54s)
- Silencer toggle for USP and M4A1 with A&D meaningful tradeoffs
- AWP scope (two zoom levels: 40 FOV → 10 FOV)
- Reload mechanics (per-weapon timing, magazine/reserve ammo)
- Three grenades: HE, flashbang, smoke
- HE: linear damage falloff, blast radius ~350u, 50% armor penetration
- Flashbang: angle-dependent blind duration, LOS check
- Smoke: A&D redesign — ~300u diameter, fully opaque, screen-space post-process fog
- Grenade cooking: A&D modification — fuse starts on pin pull, not on throw
- Grenade throw velocity with player velocity inheritance
- Grenade bounce physics (A&D custom — readable, consistent)
- Bullet tagging: speed reduction when hit (enhanced penalty while bhopping)
- Combat test range with target dummies and damage readouts
- Automated regression tests for damage, accuracy, recoil
- CI integration: GitHub Actions running `godot --headless --path . -- --test`
- Weapon/combat telemetry on debug HUD

### Not in scope
- Networked multiplayer hit registration or lag compensation (Phase 4)
- Economy, buy menu, weapon purchasing (Phase 5)
- Art models, textures, muzzle flash VFX, weapon animations (Phase 6 — use placeholder geometry)
- Sound effects (Phase 6 — placeholder or silent)
- SMGs, heavy pistol, scout (6 of the 10 weapons deferred to later phases)
- Incendiary grenades (not in base competitive mode)
- Inventory management or equipment slots beyond weapon switching

---

## Key decisions

### Decision 1: Weapon architecture — composition over inheritance
Each weapon is a Resource that configures a shared WeaponSystem node, rather than individual weapon scripts extending a base class. This keeps weapon data separate from behavior, makes adding new weapons trivial (new resource file, no new script), and avoids deep inheritance hierarchies.

```
WeaponData (Resource)
├── name, slot, side
├── damage, range_modifier, cycle_time, reload_time
├── magazine_size, reserve_ammo
├── max_speed, scoped_max_speed
├── penetration_level (1/2/3)
├── armor_penetration_ratio
├── spread_values (per state: standing, crouching, moving, airborne)
├── accuracy_divisor, base_accuracy, accuracy_cap
├── recoil_params (per state: KickBack parameters)
├── draw_time (A&D per-weapon)
├── has_silencer, silenced_overrides
├── has_scope, zoom_levels[]
```

### Decision 2: Damage authority
All damage calculation runs on the server (or the authority in single-player). The shooting client performs a raycast and sends a shot event (origin, direction, timestamp). The server re-simulates the ray with lag compensation (Phase 4) and computes damage. In Phase 3 (local only), both happen on the same machine, but the code path is structured for the Phase 4 split.

### Decision 3: Hitbox approach
Use Godot's built-in collision shapes organized as hitbox areas on the player model skeleton. Each hitbox area is tagged with its hit group (head, chest, stomach, arms, legs). Raycasts query these areas. Hitboxes match visual model geometry exactly (GDD requirement).

### Decision 4: A&D weapon switch timing
CS 1.6 uses fixed 1.54s for all switches. A&D makes draw time weapon-dependent:

| Weapon | Draw time | Rationale |
|--------|-----------|-----------|
| Knife | 0.5s | Fastest — rewards quick-switch skill |
| USP | 0.8s | Sidearm — fast fallback |
| AK-47 | 1.2s | Heavy rifle — slower deploy |
| M4A1 | 1.2s | Comparable to AK |
| AWP | 1.5s | Heaviest — punishes missed shots |

Holster time is separate and shorter (0.3s for all weapons). Total switch = holster + draw.

### Decision 5: A&D grenade cooking
CS 1.6 fuse starts on throw (1.5s). A&D starts fuse on pin pull with a longer timer (3.5s default, tunable). This creates skill expression: precise air-burst flashes, pop-HE grenades, and risk/reward for holding too long.

### Decision 6: A&D smoke redesign
CS 1.6 smoke is 204u diameter, thin, see-through. A&D uses ~300u diameter, fully opaque via screen-space post-process fog (similar to CS2). This is the single largest tactical upgrade from CS 1.6 and makes smoke worth buying. Implementation via a shader applied in a spherical region.

---

## Architecture

### Weapon system design

```
CharacterBody3D (Player)
├── PlayerMovement (existing)
├── WeaponSystem (new)
│   ├── _process(): handles input (fire, reload, switch, scope, silencer)
│   ├── fire(): hitscan ray + apply spread + recoil
│   ├── reload(): timer + ammo management
│   ├── switch_weapon(): holster → draw with per-weapon timing
│   ├── toggle_scope(): FOV change for AWP
│   ├── toggle_silencer(): swap weapon overrides for USP/M4A1
│   ├── get_spread(): state-dependent spread calculation
│   ├── apply_recoil(): KickBack viewpunch
│   └── current_weapon: WeaponData resource
├── DamageSystem (new)
│   ├── process_hit(): hitgroup lookup + damage formula
│   ├── apply_armor(): armor penetration calculation
│   ├── apply_wall_penetration(): trace through surfaces
│   └── apply_bullet_tag(): speed reduction on hit
├── ArmorSystem (new)
│   ├── armor_value: int (0-100)
│   ├── has_helmet: bool
│   └── take_damage(): reduce armor, compute HP loss
├── GrenadeSystem (new)
│   ├── throw_grenade(): velocity + inheritance + spawn
│   ├── cook_timer: fuse countdown from pin pull
│   └── inventory: {he: 0-1, flash: 0-2, smoke: 0-1}
├── Head (existing)
│   └── Camera3D
│       └── RayCast3D (hitscan ray, max range)
└── HitboxRoot (new)
    ├── HitboxHead (Area3D, tagged "head")
    ├── HitboxChest (Area3D, tagged "chest")
    ├── HitboxStomach (Area3D, tagged "stomach")
    ├── HitboxArmL/R (Area3D, tagged "arms")
    └── HitboxLegL/R (Area3D, tagged "legs")
```

### Grenade entity

```
RigidBody3D (Grenade)
├── CollisionShape3D (sphere)
├── GrenadeData (Resource: type, fuse_time, damage, radius, etc.)
├── fuse_timer: countdown from pin pull
├── _physics_process(): bounce, fuse tick
└── detonate():
    ├── HE → sphere overlap query, linear damage falloff
    ├── Flash → LOS + angle check per player, apply blind
    └── Smoke → spawn smoke volume (post-process fog region)
```

### Smoke volume

```
Node3D (SmokeCloud)
├── Area3D (detection sphere, ~300u diameter)
├── MeshInstance3D (debug sphere visualization)
├── ShaderMaterial (screen-space fog when camera inside/looking through)
├── duration_timer: 18-20s
└── fade_in/fade_out animation
```

### Shot processing flow

```
1. Player presses fire
2. WeaponSystem checks: can_fire? (cycle time, ammo, not reloading, not switching)
3. Compute spread: get_spread(weapon_data, player_state)
4. Apply two-random-per-axis to forward direction
5. Cast ray from camera origin in spread direction
6. If hit:
   a. Identify hit group from collision layer/metadata
   b. Compute raw damage: base_damage × range_modifier^(dist/500u) × hitgroup_multiplier
   c. If target has armor: apply armor penetration
   d. Apply damage to target HP
   e. Apply bullet tag to target movement
7. If wall hit and penetration_level > 0:
   a. Continue ray through surface (material-dependent thickness)
   b. Reduce penetration_level, reduce damage
   c. Repeat from step 6 with reduced damage
8. Decrement ammo, increment shots_fired
9. Apply recoil (KickBack viewpunch)
10. Update accuracy degradation
11. Spawn tracer/decal (visual only, Phase 6 polish)
```

---

## Work breakdown

### WB1: Weapon data framework (laptop)
- [ ] Create `shared/scripts/weapon_data.gd` — Resource class with all per-weapon stats
- [ ] Create `shared/scripts/weapon_constants.gd` — shared constants (hit group multipliers, wall pen thresholds)
- [ ] Create weapon resource files: `res://shared/weapons/knife.tres`, `usp.tres`, `ak47.tres`, `m4a1.tres`, `awp.tres`
- [ ] Populate all stats from Phase 0 measurements (section 2 reference values)
- [ ] Add A&D modifications: per-weapon draw times, silencer tradeoff overrides
- [ ] Per-weapon maxspeed: wire `weapon_data.max_speed` into `player_movement.gd` (framework exists from Phase 2)
- **Owner:** laptop

### WB2: Hitscan and hit detection (laptop)
- [ ] Add `RayCast3D` to camera for hitscan (max range: configurable, default ~4096u / ~104m)
- [ ] Create hitbox Area3D nodes on the player with hit group metadata
- [ ] Implement `fire()` in WeaponSystem: spread application, raycast, hit detection
- [ ] Hit group identification from collision metadata
- [ ] Debug: draw hit markers and damage numbers on screen
- **Owner:** laptop

### WB3: Damage system (laptop)
- [ ] Implement `FireBullets3`-equivalent damage formula:
  ```
  final_damage = base_damage × range_modifier^(distance / 500u) × hitgroup_multiplier
  ```
- [ ] Distance calculation in GoldSrc units (multiply Godot meters × 39.37)
- [ ] Hit group multipliers: head 4×, chest 1×, stomach 1.25×, arms 1×, legs 0.75×
- [ ] Player HP system: 100 HP, damage application, death state
- [ ] Target dummy entity for combat range: takes damage, shows hitgroup + damage value, auto-resets
- **Owner:** laptop

### WB4: Armor system (laptop)
- [ ] Implement armor (0-100) and helmet (bool) on player
- [ ] Damage reduction formula:
  ```
  new_damage = damage × armor_penetration_ratio
  armor_absorbed = (damage - new_damage) × 0.5
  armor_value -= armor_absorbed
  ```
- [ ] Legs bypass armor entirely
- [ ] Helmet protects head but AK/AWP headshot still kills through full armor+helmet
- [ ] Validate against Phase 0 measured values:
  - AK chest: 34.9 raw → 27 HP lost, 4 armor lost (~77% pen)
  - M4 chest: 31.9 raw → 22 HP lost, 5 armor lost (~69% pen)
  - AK head: 139.9 raw → 100 HP (kill) through armor+helmet
- **Owner:** laptop

### WB5: Wall penetration (laptop)
- [ ] Three penetration tiers: 1 (pistol, no pen), 2 (rifle, ~46%), 3 (sniper, ~49%)
- [ ] After hitting a surface, continue ray through with reduced damage
- [ ] Material-based thickness (simplified: thin cover = standard pen, thick = blocks)
- [ ] Armor reduction stacks multiplicatively with wall pen reduction
- [ ] Penetration count decrements per surface traversed
- [ ] Add penetrable cover sections to combat test range
- **Owner:** laptop

### WB6: Accuracy system (laptop)
- [ ] Two-random-per-axis spread (bell curve distribution):
  ```
  x = rand(-0.5, 0.5) + rand(-0.5, 0.5)
  y = rand(-0.5, 0.5) + rand(-0.5, 0.5)
  direction = forward + x × spread × right + y × spread × up
  ```
- [ ] State-dependent spread calculation per weapon:
  - Airborne: worst accuracy
  - Moving (vel > 140 u/s): moderate penalty
  - Standing: good accuracy
  - Ducking: best accuracy (rifles don't separate from standing)
- [ ] Wire movement inaccuracy threshold: 140 u/s (3.556 m/s) from `movement_constants.gd`
- [ ] Accuracy degradation on sustained fire (rifles):
  ```
  accuracy = (shots_fired^3 / accuracy_divisor) + base_accuracy
  ```
  - AK: divisor 200, base 0.35, cap 1.25
  - M4: divisor 220, base 0.3, cap 1.0
- [ ] Accuracy recovery:
  - USP: `accuracy -= (0.3 - time_since_fire) × 0.275`, clamped [0.6, 0.92]
  - Rifles: `shots_fired` resets on deploy and reload (exact recovery TBD)
- [ ] Validate: first-shot accuracy (AK standing: spread 0.0055, M4: 0.004)
- [ ] Validate: burst degradation matches Phase 0 (tight through 4 shots, explodes after 7)
- **Owner:** laptop

### WB7: Recoil system (laptop)
- [ ] Implement `KickBack()` viewpunch function:
  ```
  KickBack(up_base, lateral_base, up_modifier, lateral_modifier, up_max, lateral_max, direction_change)
  ```
- [ ] Per-shot: add `up_base + shots × up_modifier` (capped at `up_max`) upward viewpunch
- [ ] Lateral: `lateral_base + shots × lateral_modifier` (capped), direction flips every `direction_change` shots
- [ ] State-dependent recoil parameters (standing/crouching/moving/airborne) per weapon
- [ ] USP/AWP: fixed 2° upward kick per shot (no lateral)
- [ ] AK-47: T-shaped pattern (heavy upward, lateral flip at ~7-9 shots)
- [ ] M4A1: lower recoil than AK (up_base 0.65 vs 1.0 standing)
- [ ] Viewpunch recovery over time (natural spring-back)
- [ ] Validate: spray pattern produces recognizable shape on wall
- **Owner:** laptop

### WB8: Weapon switching (laptop)
- [ ] Weapon inventory: slots (knife, pistol, primary, grenade)
- [ ] Input mapping: 1-5 keys for slots, scroll wheel, Q for last weapon
- [ ] Switch sequence: holster current (0.3s) → draw new (per-weapon draw time)
- [ ] Cannot fire during switch animation
- [ ] A&D draw times: knife 0.5s, USP 0.8s, AK/M4 1.2s, AWP 1.5s
- [ ] Per-weapon maxspeed activates on draw complete
- [ ] Weapon HUD: current weapon name, ammo count
- **Owner:** laptop

### WB9: Silencer and scope (laptop)
- [ ] Silencer toggle for USP and M4A1:
  - Toggle time: USP 3.13s, M4A1 2.0s
  - Swap weapon stats to silenced overrides (damage, range_modifier, spread)
  - A&D tradeoff: silenced = less damage, tighter spread, no tracers/flash, reduced magazine
- [ ] AWP scope:
  - Two zoom levels: 90 → 40 → 10 → 90 FOV
  - Zoom cycle delay: 0.3s
  - Scoped movement speed: 150 u/s (3.81 m/s)
  - Scoped + ducked + still = 0.0 spread (perfect accuracy)
  - Unscoped: +0.08 spread penalty to all states
  - Scope overlay (simple crosshair change, no art needed yet)
- [ ] Reload cancels scope
- **Owner:** laptop

### WB10: Grenade system (laptop)
- [ ] GrenadeData resource: type, fuse_time, damage, radius, throw_velocity
- [ ] Throw mechanics:
  - Velocity from view angle: `flVel = (90 - throw_angle) × 6.0`, capped at 750 u/s (19.05 m/s)
  - Inherit player velocity
  - Spawn 16u (0.406m) in front of eye position
- [ ] A&D cooking: fuse timer starts on pin pull (3.5s default), not on throw
  - Hold too long → detonates in hand (self-damage)
  - Right-click: short toss (lower velocity)
- [ ] Bounce physics:
  - A&D custom: readable angle of reflection, consistent energy loss per bounce
  - Configurable restitution coefficient (~0.45), friction on ground contact
  - Sound cue on bounce (placeholder)
- [ ] Grenade inventory: HE ×1, flash ×2, smoke ×1
- [ ] Quick-throw input (e.g., 4 cycles grenade types, or dedicated keys)
- **Owner:** laptop

### WB11: HE grenade (laptop)
- [ ] On detonate: sphere overlap query for all players within blast radius
- [ ] Linear damage falloff: `damage = 100 × (1 - dist / 350u)`
  - Convert: 350 GoldSrc units = 8.89m Godot
- [ ] 50% armor penetration (lower than rifles)
- [ ] Self-damage: same formula, no reduction
- [ ] Team damage: follows friendly fire setting
- [ ] Validate against Phase 0:
  - 32u → 90 HP, 135u → 61 HP, 234u → 33 HP, 332u → 5 HP
- **Owner:** laptop

### WB12: Flashbang (laptop)
- [ ] On detonate: check each player's angle to flash and LOS
- [ ] Angle-based blind duration:
  - 0° (facing): 3.0s full blind, 5.7s fade
  - 45°: 2.3s blind, 4.5s fade
  - 90°: 1.9s blind, 2.8s fade
  - 180° (away): 0s blind (no white screen), minor tint
- [ ] Linear interpolation between angle thresholds
- [ ] LOS check: walls block flash entirely
- [ ] Screen effect: white overlay with fade-out (shader or CanvasLayer)
- [ ] Self-flash: same rules as enemy flash
- [ ] Validate: turning away at 180° produces no full blind
- **Owner:** laptop

### WB13: Smoke grenade (laptop)
- [ ] On detonate: spawn SmokeCloud node at grenade position
- [ ] Cloud properties:
  - Diameter: ~300u (7.62m Godot)
  - Fully opaque (A&D redesign — NOT CS 1.6 transparent)
  - Duration: 18-20s (configurable)
  - Fade-in: ~1s, fade-out: ~2s
- [ ] Implementation: screen-space post-process fog in spherical region
  - When camera ray passes through smoke volume → fog shader applied
  - Density based on ray distance through volume
  - Players inside smoke see reduced visibility in all directions
- [ ] Smoke does NOT block flash LOS (design decision — can revisit)
- [ ] Performance: test with multiple simultaneous smokes (up to 5)
- **Owner:** laptop

### WB14: Bullet tagging (laptop)
- [ ] When a player is hit by a bullet: reduce their current speed
- [ ] Standard tagging: reduce to weapon's `max_speed` if faster (minor slowdown)
- [ ] Bhop tagging (A&D): significantly larger speed reduction when hit while bhopping
  - Configurable multiplier (e.g., 0.5× — halve speed when tagged mid-bhop)
  - Makes bhopping risky under fire (design intent from GDD)
- [ ] Wire into `player_movement.gd`: `apply_bullet_tag(speed_reduction)` method
- [ ] Bullet tag decays over time (configurable recovery, ~0.5s)
- **Owner:** laptop

### WB15: Combat test range (laptop)
- [ ] Create `shared/scenes/combat_range.tscn` (or extend movement_range):
  - Firing range with target dummies at 5m, 15m, 30m, 50m distances
  - Target dummies display: hitgroup hit, raw damage, HP lost, armor lost
  - Target dummies with armor+helmet option (toggle)
  - Wall penetration section: thin wood cover, concrete wall
  - Grenade test area: open space with distance markers (every 5m out to 30m)
  - Smoke test corridor: narrow choke point to test smoke blocking
  - Flash test room: enclosed space with corners for angle testing
  - Weapon rack: interact to switch weapons / toggle armor / refill ammo
  - Spray wall: flat surface for recoil pattern visualization (bullet decals)
- [ ] Spawn with all weapons and grenades
- [ ] Teleport points between sections
- **Owner:** laptop

### WB16: Combat telemetry HUD (laptop)
- [ ] Extend existing telemetry HUD with weapon data:
  - Current weapon name, fire mode
  - Ammo: magazine / reserve
  - Current spread value (numerical)
  - Accuracy accumulation (shots_fired, current accuracy)
  - Recoil: current viewpunch values
  - Last hit: hitgroup, raw damage, distance, armor absorbed
  - DPS calculator: damage dealt over last N seconds
  - Grenade: cook timer remaining
- **Owner:** laptop

### WB17: Regression tests (laptop + vm-prime)
- [ ] Extend `tests/movement_tests.gd` or create `tests/combat_tests.gd`:
  - test_ak_headshot_damage: 36 × 4.0 = 144 raw
  - test_ak_headshot_kills_through_armor: 100 HP → 0 with vest+helmet
  - test_m4_chest_armor_damage: 31.9 raw → 22 HP lost
  - test_legs_bypass_armor: full raw damage to legs regardless of armor
  - test_range_falloff: AK at 500u deals ~35.2 (36 × 0.98)
  - test_wall_pen_pistol_blocked: USP cannot penetrate wall
  - test_wall_pen_rifle: AK through thin cover retains ~46% damage
  - test_he_damage_falloff: linear falloff matches formula
  - test_flash_angle_180: no full blind when facing away
  - test_weapon_switch_time: knife draw 0.5s, AWP draw 1.5s
  - test_accuracy_first_shot: AK standing spread ≈ 0.0055
  - test_accuracy_degradation: 7+ shots caps accuracy
  - test_per_weapon_maxspeed: AK limits to 221 u/s (5.61 m/s)
  - test_movement_inaccuracy: moving above 140 u/s increases spread
  - test_bullet_tag_reduces_speed: hit player slows down
- [ ] All tests runnable headless: `godot --headless --path . -- --test`
- **Owner:** laptop

### WB18: CI integration (laptop)
- [ ] Create `.github/workflows/test.yml`:
  - Trigger on push to main and pull requests
  - Install Godot headless on Ubuntu runner
  - Run `godot --headless --path . -- --test`
  - Fail build on non-zero exit
- [ ] Verify all Phase 2 movement tests + Phase 3 combat tests pass in CI
- [ ] Carried from Phase 2: this was deferred because the test suite was small
- **Owner:** laptop

---

## Test plan

### Reference comparison tolerances

| Measurement | Phase 0 reference | Tolerance | Test method |
|-------------|-------------------|-----------|-------------|
| AK headshot damage (raw) | 144 (36 × 4.0) | exact | Raycast at head hitbox, no armor |
| AK headshot kills through armor | 100 HP lost | ±1 HP | Full vest+helm target |
| M4 chest damage (armored) | 22 HP lost | ±1 HP | Vest+helm, chest hit |
| M4 chest armor absorbed | 5 armor | ±1 | Vest+helm, chest hit |
| AK armor penetration | ~77% | ±3% | Derived from damage values |
| Legs bypass armor | 100% raw damage | exact | Leg hit with full armor |
| AK range falloff at 500u | ~35.2 (36 × 0.98) | ±0.5 | Raycast at 12.7m (500u) |
| AWP range falloff at 2000u | ~442 headshot | ±5 | Raycast at 50.8m (2000u) |
| Wall pen (rifle through wood) | ~46% retained | ±3% | Through thin cover |
| Wall pen (pistol) | 0% (blocked) | exact | USP through same cover |
| HE at 32u | 90 HP | ±2 HP | Grenade at 0.81m |
| HE at 135u | 61 HP | ±2 HP | Grenade at 3.43m |
| Flash 0° duration | 3.0s full blind | ±0.3s | Self-flash facing grenade |
| Flash 180° duration | 0s full blind | exact | Back to grenade |
| AK first-shot spread | 0.0055 | ±0.001 | Standing, fresh accuracy |
| AK spray degradation | cap at shot 7 | ±1 shot | Continuous fire, measure spread |
| Weapon switch (knife draw) | 0.5s | ±0.05s | Timer from holster start |
| Weapon switch (AWP draw) | 1.5s | ±0.05s | Timer from holster start |
| Per-weapon maxspeed (AK) | 221 u/s (5.61 m/s) | ±0.05 m/s | Steady-state with AK equipped |
| Movement inaccuracy threshold | 140 u/s (3.556 m/s) | exact | Boolean spread penalty at threshold |
| Bullet tag speed reduction | configurable | responds to hit | Hit during bhop, measure speed |

### Play-feel tests (manual, on laptop)
- [ ] Tapping with AK feels precise — first 2-3 shots land tight
- [ ] Full AK spray produces recognizable T-pattern on wall
- [ ] M4A1 noticeably easier to control than AK
- [ ] AWP scoped + crouched feels laser-accurate
- [ ] AWP unscoped feels unreliable (can't noscope reliably)
- [ ] Counter-strafe → tap feels crisp (velocity drops below 140 u/s → accurate shot)
- [ ] Weapon switching feels appropriately sluggish for heavy weapons
- [ ] Silencer toggle feels like a real tradeoff (can notice damage/accuracy difference)
- [ ] HE grenade kills at close range, tickles at edge of blast
- [ ] Flashbang looking away works — turning is a skill
- [ ] Smoke reliably blocks vision through entire cloud
- [ ] Grenade cooking feels high-skill (can air-burst a flash)
- [ ] Getting tagged while bhopping feels punishing

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Screen-space smoke fog is complex to implement | High | High | Start with simple sphere fog (WorldEnvironment fog density in region); upgrade to proper post-process if needed |
| Hitbox alignment with placeholder geometry | Medium | Medium | Use simple capsule sub-shapes initially; refine when character models arrive (Phase 6) |
| KickBack viewpunch feels wrong without exact formula | Medium | Medium | Phase 0 has parameters but not the full KickBack body; implement best-effort, tune by feel |
| Accuracy recovery for rifles (exact mechanism unknown) | Medium | Low | Source study shows no explicit timer in AK/M4; implement time-based `shots_fired` decay as sensible default |
| Grenade cooking creates balance issues | Low | Medium | All timing configurable; 3.5s fuse is a starting point |
| Wall penetration raycasting through angled surfaces | Medium | Medium | Use simple thickness check (entry-exit ray distance); complex geometry cases iterated on |
| Performance with multiple smoke volumes | Low | Medium | Profile early; cap at 5 simultaneous smokes |
| Godot RayCast3D accuracy at very long range | Low | Low | Test AWP accuracy at max range; switch to ShapeCast if needed |

---

## Dependencies
- Phase 2 movement system — **done** (signed off 2026-10-25)
- Phase 0 weapons spec — **done** (4 weapons measured)
- Phase 0 grenades spec — **done** (all 3 grenade types measured)
- Godot 4.7.2 on laptop with editor — **done**
- Godot 4.7.2 headless on vm-prime — **done**
- Phase 2 conditions carried forward:
  - CI integration (WB18)
  - Bullet tagging (WB14)
  - Per-weapon maxspeed (WB1)
  - Movement inaccuracy threshold (WB6)

---

## Owner training exercises

### E1: Damage math by hand
Trace a single AK-47 shot through the full damage pipeline:
1. Base damage: 36
2. Distance: 750u (19.05m) → range_modifier: 0.98^(750/500) = 0.98^1.5 ≈ 0.970
3. Hit group: head → multiplier: 4.0
4. Raw damage: 36 × 0.970 × 4.0 = **139.7**
5. Armor (77% pen): HP lost = 139.7 × 0.77 = **107.6** → kill
6. Armor absorbed: (139.7 - 107.6) × 0.5 = **16.1** armor lost
- **Goal:** understand why AK one-taps through helmet at any realistic range

### E2: Spread visualization
After WB6 is working:
1. Stand still, fire 30 AK rounds at a wall (full spray)
2. Observe the pattern — tight first 4, then T-shape
3. Crouch and repeat — should be tighter
4. Run and repeat — should be wider
5. Compare M4A1 spray to AK spray
- **Goal:** feel the cubic accuracy degradation and state-dependent spread

### E3: Grenade cooking skill
After WB10 is working:
1. Pull pin on HE, count mentally, throw at 2s → detonates 1.5s after throw
2. Pull pin, hold to 3s, throw → detonates 0.5s after throw (pop grenade)
3. Pull pin, hold to 3.4s → barely makes it before detonation
4. Pull pin, hold too long → self-kill
- **Goal:** feel the risk/reward of A&D cooking vs CS 1.6's safe throws

### E4: Counter-strafe shooting
After WB6 + movement system:
1. Run left, counter-strafe right, immediately tap AK
2. Watch telemetry: speed crosses below 140 u/s → spread snaps tight
3. Compare: running tap (above 140 u/s) vs counter-strafe tap
- **Goal:** understand why counter-strafing is the core shooting skill

---

## Acceptance checklist (gate criteria)

- [ ] Four weapons (USP, AK-47, M4A1, AWP) + knife implemented with correct stats
- [ ] Damage values match Phase 0 measurements within tolerances
- [ ] Armor interaction matches Phase 0 (AK one-tap headshot, legs bypass armor)
- [ ] Wall penetration works: pistol blocked, rifle ~46%, sniper ~49%
- [ ] Accuracy system produces correct state-dependent spread values
- [ ] Recoil produces recognizable spray patterns (AK T-shape, M4 tighter)
- [ ] Per-weapon maxspeed limits movement (AK 221 u/s, AWP 210/150 scoped)
- [ ] Movement inaccuracy threshold (140 u/s) wired to spread system
- [ ] Weapon switching uses A&D per-weapon draw times
- [ ] Silencer toggle works with meaningful A&D tradeoffs
- [ ] AWP scope works (two zoom levels, scoped accuracy, speed penalty)
- [ ] All three grenades functional: HE damage, flash blind, smoke blocks vision
- [ ] Grenade cooking works (A&D fuse on pin pull)
- [ ] Smoke is fully opaque and covers ~300u diameter (A&D redesign)
- [ ] Bullet tagging reduces speed on hit (enhanced for bhop)
- [ ] No client-authoritative damage (code structured for server authority)
- [ ] Combat test range provides damage validation tools
- [ ] Regression tests pass headless on vm-prime
- [ ] CI runs tests on push (GitHub Actions)
- [ ] All weapon/grenade constants are configurable (not hardcoded)

---

## Demo instructions
1. Open project in Godot on laptop, load `combat_range.tscn`, press F5
2. Toggle telemetry HUD (F3) — now shows weapon stats alongside movement
3. Walk to weapon rack, pick up AK-47:
   - Observe maxspeed drop to 221 u/s on HUD
   - Tap-fire at 15m target: note tight grouping, damage numbers
   - Full spray at wall: observe T-shaped recoil pattern
   - Counter-strafe, then tap: notice accuracy snap
4. Switch to AWP (note 1.5s draw time on HUD):
   - Scope in (right-click): FOV narrows, speed drops to 150 u/s
   - Crouch + scope: note "0.0" spread on HUD — perfect accuracy
   - Shoot target: one-shot kill
5. Switch to M4A1, toggle silencer:
   - Compare spray tightness to AK (noticeably easier)
   - Note damage difference on telemetry
6. Test grenades:
   - Pull HE pin, cook for 2s, throw at dummy cluster: observe damage falloff
   - Pull flash, throw at wall, turn away: no full blind
   - Throw smoke in corridor: walk through, confirm fully opaque
7. Test armor:
   - Toggle armor on target dummy, shoot with AK: compare HP/armor lost to reference
   - Shoot legs: observe full damage bypassing armor
8. Test wall penetration:
   - Shoot thin cover with USP: no damage passes through
   - Shoot same cover with AK: ~46% damage on the other side
9. On vm-prime: `godot --headless --path . -- --test` — all movement + combat tests pass
10. Push to GitHub: CI workflow runs, all tests green

---

## Suggested work order
1. **WB1** (weapon data framework) — foundation for everything
2. **WB2** (hitscan) + **WB3** (damage) — core shooting loop
3. **WB4** (armor) — complete damage pipeline
4. **WB6** (accuracy) + **WB7** (recoil) — shooting feel
5. **WB8** (weapon switching) + **WB9** (silencer/scope) — weapon variety
6. **WB5** (wall penetration) — completes weapon system
7. **WB14** (bullet tagging) — carried from Phase 2
8. **WB10-13** (grenades) — HE first, then flash, then smoke (hardest last)
9. **WB15** (combat test range) — can start early as a shell, populate as features land
10. **WB16** (combat HUD) — extend incrementally alongside features
11. **WB17** (regression tests) — write tests as features are implemented
12. **WB18** (CI) — set up early, add tests to pipeline as they're written

---

## Immediate next steps
1. **Laptop:** Start with WB1 (weapon data) and WB2+WB3 (hitscan + damage) — get a bullet hitting a target with correct damage as fast as possible
2. **vm-prime:** Set up GitHub Actions workflow (WB18) early so every push validates
3. **Key milestone:** AK-47 shooting a target dummy showing correct headshot/chest/leg damage numbers with armor — this validates the entire damage pipeline
