# ANGELS AND DEMONS — Game Design Document
**Status:** Phase 0 verified, design decisions locked | **Version:** 1.0

## 1. Core loop
Join server → select Angels or Demons → buy equipment during freeze/buy period → coordinate and execute objective → resolve round → award economy → repeat. Spectate after death in standard competitive mode. Prioritize readable, fast rounds and strong player skill expression.

## 2. Default competitive mode
- Team-based, 5v5, no supernatural powers or classes.
- **MR12** format: first to 13 rounds wins, max 24 rounds (12 per half), side switch at halftime.
- Bomb-based attack/defense objective with faction-specific lore items (see section 8).
- Friendly fire on, team collision on.
- Round time, freeze time, buy time, starting money, economy rewards, and side switching are configurable; defaults specified in section 11.
- Round wins: objective completion, elimination, or timer expiry.
- No respawn within standard rounds. Separate community modes may allow respawn.

## 3. Movement

Baseline values derived from CS 1.6 GoldSrc engine (Phase 0 verified). Movement is the highest fidelity requirement.

### 3.1 Ground movement
| Parameter | Value | Source |
|-----------|-------|--------|
| Base maxspeed | 250 u/s (weapon-dependent) | Verified |
| Acceleration | `sv_accelerate` × frametime × maxspeed × friction | Verified |
| Friction | `sv_friction` = 4.0 (ground only) | Verified |
| Stop speed | `sv_stopspeed` = 100 u/s | Verified |
| Gravity | `sv_gravity` = 800 u/s² | Verified |
| Counter-strafe | Instant direction reversal via opposing input; deceleration follows friction model | Verified |
| Duck speed | 0.333× maxspeed | Verified |
| Duck-walk accuracy | Same as standing still (below 140 u/s threshold) | Verified (W07) |

### 3.2 Air movement
| Parameter | Value |
|-----------|-------|
| Air acceleration | `sv_airaccelerate` = 10 |
| Air strafe | Preserved — turning + strafe key gains speed up to maxspeed |
| Jump height | ~45 units (266 u/s upward velocity) |
| Duck-jump height | ~63 units |

### 3.3 Bunny hopping — A&D MODIFIED
CS 1.6 clips velocity on landing. A&D modifies this:

- **First 2-3 hops:** Full speed preservation (skill-rewarding gap crossing)
- **Subsequent hops:** Progressive speed degradation per hop
- **Bullet tagging:** Getting shot while bunny hopping applies significant speed reduction (much more than normal movement tagging)
- **All bhop parameters are tunable** — degradation curve, max hops before penalty, and tagging multiplier are server-configurable
- No sprint meter, slide, mantle, wall run, double jump, dash, or flight

### 3.4 Ladders — A&D MODIFIED
- CS 1.6 allowed 626 u/s via angled climbing exploit (measured Phase 0)
- **A&D caps ladder speed** to the intended MAX_CLIMB_SPEED (200 u/s)
- No angled-climb speed stacking
- Dismount behavior: clean exit, no velocity conversion exploit

### 3.5 Movement inaccuracy
| Threshold | Effect | Source |
|-----------|--------|--------|
| 0–140 u/s | Full accuracy (standing, walking, crouch-moving) | Verified (W07) |
| 140+ u/s | Degraded accuracy (running) | Verified (W07) |

Movement speed thresholds are per-weapon tunable.

## 4. Weapons

### 4.1 Roster (10 weapons)

| Slot | Weapon | Role | Side |
|------|--------|------|------|
| Pistol | Starter (Offense) | Default sidearm, accurate, low damage | Attack |
| Pistol | Starter (Defense) | Default sidearm, silenced option | Defense |
| Pistol | Heavy Pistol | High damage, low fire rate (Deagle archetype) | Both |
| Rifle | Assault Rifle | High damage, strong recoil, one-tap HS (AK archetype) | Attack |
| Rifle | Carbine | Moderate damage, tighter recoil, silencer toggle (M4 archetype) | Defense |
| Sniper | Scout | Low damage, mobile, cheap, fast scope | Both |
| Sniper | Heavy Sniper | One-shot body/head, expensive, slow (AWP archetype) | Both |
| SMG | Fast SMG | High fire rate, low damage, cheap | Both |
| SMG | Heavy SMG | Lower fire rate, higher damage, moderate price | Both |
| Melee | Knife | Always available, fastest switch, highest move speed | Both |

If 10 weapons is too many for launch, SMGs are cut first.

### 4.2 Damage model

#### Hit group multipliers (verified Phase 0)
| Hit group | Multiplier |
|-----------|-----------|
| Head | 4.0× |
| Chest | 1.0× |
| Stomach | 1.25× |
| Arms | 1.0× |
| Legs | 0.75× |

#### Key damage rules
- **AK archetype one-tap headshot through helmet:** Preserved. Base damage tuned so head × 4.0 ≥ 100 HP through armor.
- **Range falloff:** Per-weapon `range_modifier` applied per 500u of distance (compounding). Rifles ~0.97-0.98, pistols ~0.79, snipers ~0.99.
- **Hitboxes match visual model exactly.** No CS 1.6-style foot hitbox gaps.

#### Armor interaction (verified Phase 0)
- Per-weapon armor penetration ratio determines how much damage passes through armor
- Legs bypass armor entirely — rewards aim discipline
- Helmet protects head but does not prevent one-tap from high-damage weapons (AK archetype)
- Armor absorbs a percentage of blocked damage from its own pool

**Measured CS 1.6 reference values:**
| Weapon class | Armor penetration |
|-------------|-------------------|
| AK archetype | ~77% (high pen) |
| M4 archetype | ~69% (moderate) |
| HE grenade | ~50% (low) |

#### Wall penetration (verified Phase 0)
Three penetration levels per weapon:
| Level | Behavior | Weapons |
|-------|----------|---------|
| 1 | Cannot penetrate surfaces | Pistols (except heavy) |
| 2 | ~46% damage through thin cover | Rifles, Heavy Pistol, SMGs |
| 3 | ~49% damage through thin cover | Snipers |

Penetration and armor reduction stack multiplicatively.

### 4.3 Accuracy model
- Two-random-per-axis spread creates bell curve distribution (denser at center)
- Per-weapon spread values for: standing, crouching, moving, jumping, sustained fire
- Movement inaccuracy threshold: 140 u/s (tunable per weapon)
- **Burst degradation:** Accuracy degrades with sustained fire (cubic curve for rifles — tight through 4 shots, explodes after 7)
- **Recovery:** Per-weapon timer (e.g., M4: 0.4s to reset, AK: no passive recovery — must stop firing)

### 4.4 Silencer mechanic — A&D MODIFIED
CS 1.6 silencer changes nothing meaningful. A&D makes it a real tradeoff:

| Property | Silenced | Unsilenced |
|----------|----------|------------|
| Damage | Slightly reduced | Full |
| Spread | Tighter | Wider |
| Tracers | None | Visible |
| Sound | Suppressed | Full |
| Muzzle flash | None | Visible |
| Magazine size | Reduced (e.g., 25) | Full (e.g., 30) |

### 4.5 Weapon switch timing — A&D MODIFIED
CS 1.6 uses a fixed 1.54s for all switches. A&D makes switch time weapon-dependent:

| Weapon | Draw time (approximate) |
|--------|----------------------|
| Knife | ~0.5s |
| Pistol | ~0.8s |
| SMG | ~1.0s |
| Rifle | ~1.2s |
| Heavy Sniper | ~1.5s |

Exact values tunable per weapon. Rewards weapon discipline and quick-switch skill.

## 5. Grenades

### 5.1 Inventory
| Grenade | Max carry | Notes |
|---------|----------|-------|
| HE Grenade | 1 | Area damage |
| Flashbang | 2 | Vision denial |
| Smoke Grenade | 1 | Area denial |

Incendiary grenades are not in base competitive mode; possible future mod/arcade addition.

### 5.2 Shared mechanics
| Parameter | Value | Source |
|-----------|-------|--------|
| Max throw velocity | 750 u/s | Verified |
| Velocity inheritance | Adds player velocity to throw | Verified (+45% from running) |
| Spawn origin | 16u in front of player eyes | Verified |

#### Throw distances (verified Phase 0)
| Condition | Distance |
|-----------|----------|
| Standing, level | 675u |
| Standing, angled up | 1173-1260u |
| Running forward, level | 979u |
| Jump throw | 1065u |

### 5.3 Grenade cooking — A&D MODIFIED
CS 1.6 has no cooking (fuse starts on throw). **A&D starts the fuse on pin pull.**

- Pin pull initiates a fixed fuse timer (e.g., 3.5s)
- The grenade detonates when the timer expires regardless of where it is — in hand, in flight, or on ground
- Holding too long kills you
- Creates high skill ceiling: precise timing for air-burst flashes and pop-HE grenades
- Faking a throw costs real fuse time

### 5.4 HE Grenade (verified Phase 0)
| Stat | Value |
|------|-------|
| Base damage | ~100 |
| Blast radius | ~350 units |
| Damage falloff | Linear: `dmg = 100 × (1 - dist/350)` |
| Armor penetration | 50% |
| Self-damage | Yes, same formula |
| Team damage | Follows friendly fire setting |

### 5.5 Flashbang (verified Phase 0)
| Stat | Value |
|------|-------|
| Full blind (facing, 0°) | 3.0s |
| Full blind (45°) | 2.3s |
| Full blind (90°) | 1.9s |
| Full blind (180°, back turned) | 0s (no white screen) |
| Fade duration | 2.8–5.7s (scales with angle) |
| Total effect (facing) | ~10s |

Flash effect scales linearly with viewing angle. Turning away is a core skill mechanic — preserved in A&D.

### 5.6 Smoke Grenade — A&D MODIFIED
CS 1.6 smoke is nearly useless (204u diameter, transparent). A&D redesigns smoke completely:

| Stat | CS 1.6 (measured) | A&D target |
|------|-------------------|------------|
| Cloud diameter | 204u | ~300u |
| Opacity | Thin, see-through | Fully opaque (CS2-style) |
| Duration | 25.3s | ~18-20s |
| Implementation | Billboard particles | Screen-space post-process fog |

Smoke must reliably block vision through the entire cloud. This is the single largest tactical upgrade from CS 1.6.

### 5.7 Bounce physics — A&D MODIFIED
CS 1.6 grenade bounce is quirky and inconsistent. A&D designs bounce from scratch:
- Readable, consistent angle of reflection
- Predictable energy loss per bounce
- Players can learn reliable bank shots
- Exact parameters TBD during Phase 3 playtesting

## 6. Factions and character design
**Angels:** playful celestial infantry, imperfect halos, feather accents, exaggerated faces. Primary team color: blue.
**Demons:** mischievous infernal infantry, expressive horns, tails, embers. Primary team color: red.
- Comparable visibility, silhouettes, collision hulls, and animation timing for both factions.
- No faction-specific gameplay advantages or abilities.
- Original character models; faction differences are visual/audio only.
- Faction readability must work through shape and silhouette, not color alone (see section 9, colorblind modes).

## 7. Combat presentation and gore
- Stylized blood impact particles and surface decals, expressive death animations, physics ragdolls, optional detachable elements.
- Comedy cues: halo falls off, feathers scatter, horns bounce, theatrical overreactions.
- Gore intensity and blood persistence adjustable locally; provide lower-effects setting for visibility/performance.
- Cosmetic effects do not modify collision, hitboxes, server damage, or player input.
- Avoid gore particles obscuring critical player visibility in official competitive settings.

## 8. Maps and level design
- Start with a small gray-box mechanics range, then one original competitive map.
- **Bomb-based objective:** Attack team plants an explosive device, defense team prevents or defuses it.
- **Faction-specific objective lore:** Each map features a unique lore item that contextualizes the attack/defense.
  - Example: Angels defend the Ark of the Covenant; Demons try to destroy it.
  - Example: Angels attack the Book of the Dead; Demons defend it.
  - The defending faction's sacred item is the objective — attacking team plants to destroy it.
  - Exact items per map are creative decisions during Phase 6.
- Heaven/Hell motifs are visual themes, not mandatory traversal gimmicks.
- Map packaging, spawn definitions, objective entities, navigation hooks, and version compatibility documented for community creators.
- Later community archetypes: surf, deathmatch, gun game, obstacle/deathrun, infection/survival.

## 9. UX and accessibility
- Fast launch, keyboard/mouse-first controls, rebindable keys, sensitivity, crosshair settings, audio sliders, color/contrast settings, configurable gore, basic subtitles for essential cues.
- Colorblind modes: protanopia, deuteranopia, and tritanopia presets that shift team colors while preserving contrast. Consider user-customizable team highlight colors.
- Server browser with favorites, ping, player count, map, mods/rules indicator, and direct connect.
- Buy menu, scoreboard, spectator UI, kill feed, admin notices, and console.

## 10. Networking and server
- **Tick rate: 128** (competitive standard)
- Authoritative server resolves all hits and damage; clients predict permissible presentation only.
- Server-side hit registration with lag compensation.
- Prediction and reconciliation for movement.
- Interpolation for remote player rendering.
- Engine: Godot (per roadmap).

## 11. Economy
**Format:** MR12 (first to 13 rounds, 12 per half, side switch at halftime).

Economy details TBD — to be designed and playtested in Phase 3/5. Key decisions needed:
- Starting money
- Round win/loss rewards
- Loss bonus escalation curve
- Kill rewards per weapon type
- Weapon and equipment pricing
- Buy zone rules and timing

**Design goal:** MR12's tighter round count should create more force-buy situations and less pure save rounds, making the full weapon roster (especially SMGs and scout) relevant in the meta.

## 12. Server and community
- Public and private community servers, password support, configurable rules, map rotation, administrator roles, kick/mute/ban, persistent audit logs.
- Servers clearly mark modifications to movement/weapon baseline.
- Community ban lists stay local by default; cross-server lists require opt-in.

## 13. Quality bar
- Mechanical tests pass against reference tolerances from Phase 0.
- Hitboxes match visual models exactly — no phantom misses.
- No client-authoritative damage or position acceptance.
- Reliable 5v5 match on a headless dedicated server at 128 tick.
- Competitive visuals remain legible at low settings.
- Community deployment and direct-IP joining work without official matchmaking.

## 14. Not decided yet
- Economy numbers (section 11)
- Exact weapon stats (base damage, fire rate, price per weapon)
- Objective item names and lore per map
- Art production pipeline
- Ranking/matchmaking system (post-launch)
- Spectator restrictions for competitive
- Bhop exact tuning (degradation curve, max hops, tagging values)
- Grenade fuse timer duration
- Smoke exact implementation details
