# ANGELS AND DEMONS — Phase 0: CS 1.6 Mechanics Research
**Status:** Research plan | **Goal:** measurable specification before implementation

## Research objective
Build an evidence-backed, legally clean reference specification for the *behavior* of Counter-Strike 1.6, especially movement, gunplay, grenades, and network simulation. This phase produces no production gameplay code.

## Time-box
**4 weeks maximum.** Hard checkpoint at the end of week 4: anything not documented to "verified" confidence is marked as an explicit TODO with a plan to resolve during Phase 2–3 implementation. The bar is "good enough to prototype," not "complete encyclopedia of GoldSrc." If a workstream is blocked (e.g., waiting on legal clarification), document what is known and move on.

## Source hierarchy
1. Reproducible behavior measured in a legally obtained reference CS 1.6 client/server with documented build, settings, FPS, and network conditions.
2. Publicly available official GoldSrc/Half-Life SDK source for study of concepts and algorithms, subject to its license.
3. ReGameDLL_CS for game rules, weapons, grenades, and known compatibility/bugfix distinctions.
4. ReHLDS for server behavior and engine compatibility observations.
5. Disassembly/debugging only for unresolved questions, where legally permitted and necessary.

**References:**
- https://github.com/ValveSoftware/halflife
- https://github.com/rehlds/ReGameDLL_CS
- https://github.com/rehlds/ReHLDS

## Legal/IP boundary
- Do not assume publicly viewable source code can be copied into a standalone commercial game.
- Record licenses, redistribution restrictions, provenance, and attribution obligations for every source.
- Extract factual measurements and independently implement mechanics; do not redistribute original maps, textures, models, sounds, trademarks, or proprietary code.
- If uncertainty remains, seek qualified legal review before code or assets are incorporated.

## Workstreams
### A. Reference environment
- Record CS 1.6 version/build, server binary, configuration, FPS limits, tick/update behavior, latency, and test map.
- Maintain reproducible startup scripts, test commands, video captures, and telemetry files where permitted.
- Define whether behavior is based on original stock settings or an intentionally selected classic server configuration.

### B. Movement specification (top priority)
- Ground acceleration, friction, stopping, counter-strafing, max speed, gravity, jump impulse, air acceleration, air control, bunny hopping, duck/crouch, collision hulls, ladders, stairs, slopes, weapon speed penalties.
- Derive equations, order of operations, update frequencies, rounding and edge-case handling.
- Measure outcomes with scripted/repeatable input traces and compare predicted vs observed displacement and velocity.

### C. Weapons and damage
- Select reference pistol, rifle, and sniper first.
- Document cadence, recoil patterns, accuracy/spread, movement/stance effects, reload/switch times, damage, armor, penetration, and hit zones.
- Record source vs observed evidence and configuration-dependent differences.

### D. Grenades
- HE, flash, smoke: equip/throw timing, trajectories, bounce response, fuse, blast/flash effects, smoke duration, and collision.
- Holy Hand Grenade is cosmetic/theme concept; preserve selected classic grenade rules in baseline mode.

### E. Networking
- Observe input timing, simulation frequency, interpolation, prediction, lag compensation, packet loss and jitter behavior.
- Do not copy protocol details merely for compatibility; prioritize game-feel equivalence.

## Evidence format
Each mechanic entry must include: reference build/config; question; source location or measurement method; equation/parameter or behavioral description; confidence (verified/inferred/unknown); test case; observed values; target tolerance; open questions.

## Deliverables
- `reference_environment.md`
- `movement_spec.md`
- `weapons_spec.md`
- `grenades_spec.md`
- `network_behavior.md`
- `mechanics_test_matrix.csv`
- `source_license_register.md`
- `research_decisions.md`

## Suggested validation experiments
- Hold forward for fixed durations and measure displacement/velocity.
- Release movement key and measure stopping distance/time.
- Reverse direction and measure counter-strafe delay.
- Compare single jump height/duration and successive jump speed.
- Repeat air-strafe input at controlled starting speeds.
- Test duck-jump clearance, stairs, slopes, ladders and collision corners.
- Test recoil and accuracy with repeatable fire sequences.
- Measure grenade flight/bounce/detonation from fixed launch states.
- Repeat representative scenarios at controlled ping, jitter, and packet loss.

## Exit criteria
- Reference environment is reproducible.
- Major movement parameters and edge cases are documented with confidence and test tolerances.
- Initial weapon/grenade behaviors are specified well enough to build a prototype.
- Legal/source-use boundaries are documented.
- Unknowns and deliberate deviations are explicit and approved.

## Claude Code working instructions
Research before coding. Cite file paths, commits, functions, and experiment artifacts for every claim. Never invent numerical constants. Mark unresolved findings as TODO. Keep all research files version controlled. Request owner approval before accepting a deviation from CS 1.6 baseline behavior.
