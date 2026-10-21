# PHASE 0 — Task Plan: CS 1.6 Mechanics Research
**Time-box:** 4 weeks | **Start:** TBD | **Status:** Not started

## Scope
Build an evidence-backed reference specification for CS 1.6 movement, gunplay, grenades, and networking behavior. Produce measurable fidelity targets that Phase 2–5 implementation will validate against.

## Non-goals
- No production game code, engine setup, or Godot work.
- No full weapon roster — only representative prototypes (pistol, rifle, sniper).
- No complete GoldSrc reimplementation study — only behaviors that affect gameplay feel.
- No art, sound, or asset creation.
- No networking library selection (deferred to Phase 1).

## Decisions required before starting
1. **CS 1.6 acquisition method** — Steam purchase is the cleanest legal path. Confirm owner has or will purchase.
2. **Reference server configuration** — stock defaults vs. competitive community config (e.g., 100 tick, sv_airaccelerate 10). Recommendation: document stock first, note competitive deviations.
3. **Test environment** — local dedicated server on LAN, or a VM? Local LAN with controlled latency is simplest.
4. **Recording tools** — demo recording (built-in), screen capture, and `cl_showpos 1` / `net_graph 3` for telemetry. Confirm no external tools are needed initially.

## File structure
```
phase_0/
├── reference_environment.md     # Build, config, startup, reproduction steps
├── movement_spec.md             # Equations, parameters, edge cases, tolerances
├── weapons_spec.md              # Reference pistol/rifle/sniper mechanics
├── grenades_spec.md             # HE/flash/smoke physics and effects
├── network_behavior.md          # Tick, interpolation, prediction observations
├── mechanics_test_matrix.csv    # Experiment → expected → observed → status
├── source_license_register.md   # Every source reviewed, its license, what was used
├── research_decisions.md        # Decisions made, deviations accepted, open questions
└── experiments/
    ├── movement/                # Demo files, screenshots, measurement logs
    ├── weapons/                 # Recoil traces, damage tables
    └── grenades/                # Trajectory/timing captures
```

---

## Week 1 — Reference environment + movement foundations

### 1.1 Acquire and document reference build
- Purchase CS 1.6 on Steam (if not owned).
- Record exact build version, Steam app ID, client and server binary hashes.
- Document default `server.cfg`, `listenserver.cfg`, and relevant CVARs.
- **Deliverable:** draft `reference_environment.md` with version, config, and reproduction steps.

### 1.2 Set up local test server
- Run a local dedicated server with known settings.
- Create startup script with fixed config (tick rate, max players, gravity, air accelerate, etc.).
- Confirm `cl_showpos 1`, `sv_cheats 1` (for testing), demo recording, and `host_timescale` work for measurement.
- Load a flat test map (e.g., `de_dust2` for familiarity, or a community aim/test map with open space).
- **Deliverable:** reproducible local server startup documented in `reference_environment.md`.

### 1.3 Begin source study — movement code
- Read `pm_shared.c` from the Half-Life SDK (`PM_PlayerMove`, `PM_WalkMove`, `PM_AirMove`, `PM_Jump`, `PM_Duck`, `PM_Friction`, `PM_Accelerate`).
- Cross-reference with ReGameDLL_CS for any CS-specific overrides or fixes.
- Document the simulation loop order: input → categorize movement mode → apply friction → apply acceleration → collision → finalize position.
- Record key constants: `sv_maxspeed`, `sv_gravity`, `sv_friction`, `sv_stopspeed`, `sv_accelerate`, `sv_airaccelerate`, `sv_stepsize`, player hull dimensions.
- **Deliverable:** initial equations and constants in draft `movement_spec.md`.

### 1.4 Source license register — initial entries
- Document licenses for: Half-Life SDK, ReGameDLL_CS, ReHLDS.
- Record what each permits (study, modification, redistribution) and what it prohibits.
- Note: we extract behavioral measurements and independently implement — no code copying.
- **Deliverable:** draft `source_license_register.md`.

### Owner exercise — Week 1
- Read `pm_shared.c` focusing on `PM_Accelerate` and `PM_Friction`. Understand how `wishspeed`, `currentspeed`, `addspeed`, and `accelspeed` interact.
- Play CS 1.6 with `cl_showpos 1` and observe velocity values during walking, stopping, jumping, and air strafing.

---

## Week 2 — Movement deep dive and measurement

### 2.1 Ground movement
- **Acceleration:** measure time and distance to reach max speed from standstill (forward, diagonal).
- **Friction and stopping:** release movement key, measure frames/distance to stop. Test `sv_friction` and `sv_stopspeed` interaction.
- **Counter-strafing:** press opposite direction, measure how quickly velocity reverses. This is the core "crisp stopping" feel.
- **Diagonal movement:** confirm whether diagonal speed exceeds forward speed and by how much (classic Quake-engine behavior).
- **Weapon speed penalties:** measure max ground speed with knife, pistol, rifle, AWP. Document per-weapon `maxspeed` values.
- Record all experiments in `mechanics_test_matrix.csv`.

### 2.2 Air movement
- **Jump:** measure jump height, jump duration, initial upward velocity (`sqrt(2 * gravity * 45)` expected).
- **Air acceleration:** document `sv_airaccelerate` effect. Measure speed gain per air strafe at various starting velocities.
- **Bunny hopping:** test repeated jumps with strafing. Measure speed accumulation. Document the frame-perfect window and auto-bhop vs manual behavior.
- **Duck-jump:** measure clearance difference between normal jump and duck-jump. Record crouch hull vs standing hull.

### 2.3 Collision and terrain
- **Stairs/steps:** test `sv_stepsize` (default 18). Walk into steps of various heights, confirm step-up threshold.
- **Slopes:** test slope sliding behavior, speed changes on ramps, whether steep slopes block movement.
- **Ladders:** document ladder attachment, speed, detach behavior.
- **Collision hulls:** standing (32x32x72), ducking (32x32x36) — verify in source, test with tight gaps in-game.
- **Edge cases:** ceiling duck-jump clearance, getting stuck in geometry, ramp jumps.

### 2.4 Movement spec consolidation
- Write equations with variable names matching source code for traceability.
- Assign confidence levels: verified (measured + matches source), inferred (source study only), unknown.
- Define target tolerances: e.g., "ground acceleration must reach 250 u/s within ±2 frames of reference."
- **Deliverable:** substantive `movement_spec.md` with equations, parameters, confidence, and tolerances.

### Owner exercise — Week 2
- Run the measurement experiments yourself. Use demo playback with `host_timescale 0.25` to count frames.
- Practice counter-strafing and bunny hopping — feel the difference between crisp and sluggish stopping.

---

## Week 3 — Weapons, grenades, and initial networking

### 3.1 Select reference weapons
Choose one from each class for initial specification:
- **Pistol:** USP (CT default) or Glock (T default) — recommend USP for precision testing.
- **Rifle:** AK-47 (iconic, strong recoil pattern) and/or M4A1 (compare silenced vs unsilenced).
- **Sniper:** AWP (one-shot mechanic, scope, movement penalty).

### 3.2 Weapon mechanics — per reference weapon
- **Recoil:** fire full magazine at wall, capture spray pattern. Document per-shot angle offsets from source (`RecoilTable` arrays in ReGameDLL).
- **Spread/accuracy:** standing, crouching, moving, jumping. Document base inaccuracy and recovery time.
- **Firing cadence:** measure rounds per minute, burst behavior if applicable.
- **Reload/switch timing:** measure reload animation length, weapon switch delay, scope-in time (AWP).
- **Damage:** headshot, chest, stomach, arm, leg multipliers. Base damage, armor penetration ratio, range falloff.
- **Movement inaccuracy:** quantify accuracy penalty at various speeds.
- **Deliverable:** draft `weapons_spec.md` with per-weapon data tables and source references.

### 3.3 Grenade mechanics
- **Equip/throw:** measure equip time, throw delay, release timing.
- **Trajectory:** throw velocity (overhand, underhand, medium), arc under gravity.
- **Bounce:** coefficient of restitution on various surfaces, friction on ground.
- **HE grenade:** fuse time, blast radius, damage falloff curve, armor interaction.
- **Flashbang:** fuse time, flash exposure calculation (angle, distance, obstacles), duration curve.
- **Smoke:** fuse time, spread duration, visibility reduction, total lifetime.
- **Deliverable:** draft `grenades_spec.md`.

### 3.4 Networking observation — initial
- Set up two clients connecting to a local dedicated server.
- Observe with `net_graph 3`: cmdrate, updaterate, interp, loss, choke.
- Document default values for `cl_cmdrate`, `cl_updaterate`, `cl_interp`, `ex_interp`, server `sys_ticrate`.
- Note visible differences between 0ms and 50ms+ artificial latency (movement smoothness, hit feedback delay).
- **Deliverable:** begin `network_behavior.md` with defaults and initial observations.

### Owner exercise — Week 3
- Fire AK-47 spray patterns at a wall and compare to documented recoil tables.
- Throw each grenade type in a controlled setting — count seconds for fuse, observe bounce behavior.
- Play with `rate`, `cl_cmdrate`, `cl_updaterate` set to low values and feel the degradation.

---

## Week 4 — Networking, legal register, consolidation, and sign-off prep

### 4.1 Networking deep dive
- **Tick/simulation rate:** confirm server `sys_ticrate` default (typically ~1000 Hz internal, but gameplay sim is framerate-bound in GoldSrc — document this distinction).
- **Client prediction:** observe client-side prediction behavior. When does the client predict movement? When does it correct?
- **Interpolation:** test `cl_interp` values. Document visual smoothness vs responsiveness tradeoff.
- **Lag compensation:** if observable, note how the server rewinds for hit detection. (This may be partially inferred from source.)
- **Packet loss behavior:** introduce artificial loss, document degradation (rubber-banding, shot registration failures).
- **Key finding for Phase 4:** document what "feels right" at various latencies — this informs our implementation targets.
- **Deliverable:** complete `network_behavior.md`.

### 4.2 Complete source license register
- Review all sources consulted during the phase.
- For each: name, URL, license type, what we extracted (behavioral measurements only vs. studied algorithms), any attribution obligations.
- Confirm no code was copied — only factual measurements and independent algorithm understanding.
- Flag any areas where legal review would be prudent before Phase 2 implementation.
- **Deliverable:** complete `source_license_register.md`.

### 4.3 Consolidation and gap analysis
- Review all spec documents for completeness against Phase 0 deliverable list.
- Update `mechanics_test_matrix.csv` with final status for each experiment.
- In `research_decisions.md`, document:
  - Decisions made (e.g., "baseline is stock CS 1.6 with these specific CVARs").
  - Deliberate deviations planned (e.g., "we will not replicate bug X because...").
  - Unknowns carried forward as TODOs with plan to resolve in Phase 2–3.
- Assign final confidence levels to all spec entries.
- **Deliverable:** complete `research_decisions.md`, updated all spec docs.

### 4.4 Sign-off preparation
- Compile gate criteria checklist (from below).
- Identify any blockers or conditions to carry forward.
- Prepare `PHASE_0_SIGNOFF.md` template for owner review.
- **Deliverable:** sign-off-ready research pack.

### Owner exercise — Week 4
- Review all spec documents. For each "verified" finding, confirm you understand the measurement and why it matters.
- Play CS 1.6 one more time with the specs in mind — validate that the documented behavior matches what you feel in-game.
- Make go/no-go decision on Phase 0 sign-off.

---

## Test plan
All experiments follow this format in `mechanics_test_matrix.csv`:

| ID | Workstream | Experiment | Method | Expected (from source) | Observed | Tolerance | Status | Notes |
|----|-----------|------------|--------|----------------------|----------|-----------|--------|-------|
| M01 | Movement | Forward acceleration to max speed | Hold W, measure frames to 250 u/s | ~X frames at 100fps | | ±2 frames | | |
| M02 | Movement | Stop distance from max speed | Release W at 250 u/s, measure distance | ~X units | | ±1 unit | | |

Status values: `not_started`, `in_progress`, `verified`, `inferred`, `blocked`, `todo_phase2`.

## Risks
| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| CS 1.6 measurement is ambiguous or build-dependent | Medium | High | Document exact build; test multiple configs; cross-reference source |
| GoldSrc movement has undocumented quirks not in SDK source | Medium | Medium | Use ReGameDLL/ReHLDS as secondary source; flag unknowns explicitly |
| Research expands beyond 4 weeks | Medium | Medium | Hard checkpoint at week 4; "good enough to prototype" bar; carry TODOs forward |
| Legal uncertainty on algorithm reimplementation | Low | High | We measure behavior, not copy code; flag concerns for legal review |
| Owner availability for exercises/review | Medium | Low | Exercises are optional but recommended; sign-off is the hard gate |

## Dependencies
- CS 1.6 purchased on Steam.
- A machine capable of running CS 1.6 client and local dedicated server (minimal requirements).
- Git repo set up (done).
- No external services or infrastructure required.

## Acceptance checklist (gate criteria)
- [ ] Reference environment is reproducible (version, config, startup documented).
- [ ] Ground movement parameters documented with confidence and tolerances (acceleration, friction, stopping, counter-strafe, diagonal, weapon penalties).
- [ ] Air movement parameters documented (jump, air accel, bunny hop, duck-jump).
- [ ] Collision behaviors documented (stairs, slopes, ladders, hulls).
- [ ] At least one pistol, one rifle, and one sniper weapon specified (recoil, spread, damage, timing).
- [ ] HE, flash, and smoke grenade behaviors specified (trajectory, fuse, effects).
- [ ] Networking defaults and behavior observed and documented.
- [ ] Source license register complete with no unresolved IP concerns.
- [ ] All unknowns and planned deviations explicitly listed in `research_decisions.md`.
- [ ] `mechanics_test_matrix.csv` has entries for all major experiments with status.
- [ ] Owner has reviewed specs and confirmed they match in-game feel.

## Immediate next step
Confirm the decisions listed at the top of this document, then begin Week 1 tasks.
