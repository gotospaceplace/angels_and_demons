# Phase 6 Sign-Off — Competitive Polish & UI
**Date:** 2026-11-06

## Gate criteria

| Criterion | Met | Evidence |
|-----------|-----|----------|
| Headshot geometry v3: AABB head hitbox with pose-following blend | Yes | PR #20 — AABB sized to visible head mesh, blends using `duck_fraction` from lag comp snapshots |
| Knife mechanics: backstab detection, slash/stab attack types | Yes | PR #21 — slash (40/65 front/back), stab (55/180), dot-product backstab detection; renamed to Melee in PR #34 (CR-01) |
| Death report card: damage given/taken on death | Yes | PR #22 — server-tracked damage events, `EVT_DEATH_REPORT` reliable channel, redesigned layout in PR #52 |
| Kill feed enhancements: team colors, wallbang/smoke/flash tags | Yes | PR #23 — team-colored names, ▮ wallbang, ☁ smoke, ✦ flash icons; star icon fix in PR #49 |
| Round history icons replace text codes | Yes | PR #24 — skull/portal/book/hourglass icons replace E/P/R/T letters |
| FFA Deathmatch scoreboard layout | Yes | PR #25 — single sorted list, K/D/A/KDR/HS%/DMG/Score; live update fix in PR #50 |
| Team Deathmatch scoreboard layout | Yes | PR #26 — two-team, 6 per side, K/D/A/KDR/DMG columns |
| Casual 10v10 scoreboard layout | Yes | PR #27 — two-team, compact 22px rows, 10 per side with scroll |
| Key bindings UI: rebindable controls with persistence | Yes | PR #28 — ConfigFile save/load, click-to-rebind, duplicate detection, reset; layout fixes in PR #53 |
| Regression tests for all new Phase 6 systems | Yes | PR #29 — headshot geometry, knife mechanics, death report, kill feed tests added to CI |
| All 19 test suites passing | Yes | CI green on all suites at Phase 6 completion |
| Art readable, performant, and mechanically neutral | Yes | Icons and UI elements are functional placeholders; no gameplay advantage from visuals |
| Gore settings functional | N/A | Deferred — stylized blood and ragdolls not in Phase 6 scope (listed in roadmap gate but Phase 6 plan scoped to competitive polish only) |

## Phase 6 work blocks (PRs #20–#29)

| WB | Title | PR |
|----|-------|----|
| WB1 | Headshot geometry v3 | #20 |
| WB2 | Knife mechanics — backstab/stab | #21 |
| WB3 | Death report card | #22 |
| WB4 | Kill feed enhancements | #23 |
| WB5 | Round history icons | #24 |
| WB6 | FFA Deathmatch scoreboard | #25 |
| WB7 | Team Deathmatch scoreboard | #26 |
| WB8 | Casual 10v10 scoreboard | #27 |
| WB9 | Key bindings UI | #28 |
| WB10 | Phase 6 regression tests | #29 |

## Post-Phase-6 playtesting and fixes (PRs #30–#75)

Build 4 was the first real multiplayer playtesting session after Phase 6. It produced 6 bugs and 8 change requests, all resolved across PRs #30–#44. Additional playtesting through Build 7 produced further fixes across PRs #45–#75.

### Bug fixes from playtesting

| Bug | Fix | PR |
|-----|-----|----|
| BUG-01/02/03: Grenade networking (damage, flash, visibility) | Server-authoritative grenades with client prediction | #30 |
| BUG-04: Cannot walk up ramp | Project walk move onto ground plane for slopes | #31 |
| BUG-05: Ladder pushes player backward at top | Fix dismount direction logic | #33 |
| BUG-06: Stair camera too jarring | Step offset decay smoothing | #36 |
| HE grenade LOS hitting target's own body | Fix raycast origin | #45 |
| Ramp top collision stuck point | Fix surface transition | #46, #62 |
| Ladder zone height / ledge mount | Fix detection bounds | #47 |
| Stair step-up horizontal speed | Reduce horizontal velocity | #48 |
| Kill feed wrong weapon names | Fix weapon index lookup | #58 |
| Scoreboard showing no players | Fix player list population | #59 |
| Death report panel not appearing | Fix display trigger | #60 |
| Team select buttons no effect | Fix button signal wiring | #61 |
| Ladder descent ledge mount | Prevent mount when descending | #63 |
| Movement speed mismatch | Reduce to CS 1.6 reference values | #64 |
| Input passthrough when menus open | Block game input during UI focus | #68 |
| TDM spectator spawn/team switching | Fix spawn flow | #69 |
| Spectator on TDM join | Fix client-side spectator mode | #71 |
| New client not loading server map | Fix map sync on connect | #73 |
| Server crash on map switch | Fix segfault in map change | #74 |
| Map sync during loading race | Intercept EVT_MAP_CHANGE in autoload | #75 |

### Change requests from playtesting

| CR | Change | PR |
|----|--------|----|
| CR-01: Knife → Melee rename | Codebase-wide rename | #34 |
| CR-02: In-game ESC menu | Options + Quit menu; buttons fixed in #65 | #35 |
| CR-03: Map loading screen | Splash art loading screen; resource fix #43, sync fix #44 | #37 |
| CR-04: Chat commands | /mode, /map, /restart commands | #38 |
| CR-05: Map naming convention | MAP_GAMETYPE_MAPNAME format | #39 |
| CR-06: Screenshot bind | F12 bind; flash overlay fix in #56 | #42 |
| CR-07: Move boxes near stairs | Crate clusters toward center | #40 |
| CR-08: Add boxes at ramp bases | Cover crates added | #41 |

### Additional improvements from playtesting

| Feature/Fix | PR |
|-------------|----|
| BSP aim_map prototype import with collision validation | #32 |
| Death report card redesign | #52 |
| Key bindings UI layout fixes | #53 |
| ESC menu centering and layering | #54 |
| Team select panel centering | #55 |
| Screenshot feedback improvements | #56 |
| TDM/Casual mode plugins with /mode switching | #57 |
| Kill feed star icon fix | #49 |
| FFA scoreboard live update fix | #50 |
| Spectator freecam fix | #51 |
| TDM spectator spawn default | #66 |
| HUD chatbox cleanup | #67 |
| Chat position adjustment | #70 |
| Runtime map switching (/map, /listmaps) | #72 |
| MAP_TD_CSAIMMAP rename and import path updates | HEAD |

## Deviations from plan

| Deviation | Rationale |
|-----------|-----------|
| Gore settings / stylized blood / ragdolls not implemented | Roadmap gate mentioned these but Phase 6 plan scoped to competitive polish and UI only; visual identity deferred to future phase |
| TDM and Casual mode plugins implemented during playtesting | Originally listed as deferred to Phase 7, but playtesting needed them for scoreboard validation; added as CR-08 / PR #57 |
| Melee rename (Knife → Melee/Fists) | Playtesting feedback; codebase-wide rename in CR-01 |
| Significant post-Phase-6 bug fixing (46 PRs beyond the 10 WBs) | First real multiplayer playtesting revealed networking, collision, and UI issues that required immediate resolution |

## Conditions carried forward

- **Visual identity:** Stylized blood, ragdolls, comedic death effects, original character/weapon models — the art side of the Phase 6 roadmap gate. Current assets are functional gray-box placeholders.
- **Portal objective tuning:** Needs 5v5 competitive playtesting data before adjusting activation/seal times and site balance.
- **Combat balance tuning:** Weapon damage/accuracy/economy numbers need more playtesting matches to identify specific problems.
- **Remaining weapons:** Only 5 of the planned 11 weapons implemented (Melee/USP/AK-47/M4A1/AWP). Additional weapons deferred until core balance is validated.
- **Bullet decals and volumetric smoke fog:** Visual polish items with no gameplay impact.
- **Bot AI:** Needed for testing with fewer human players; not yet started.
- **Grenade throw/bounce tuning:** Functional but may need adjustments based on competitive play.

## Summary

Phase 6 delivers competitive polish across 10 work blocks (PRs #20–#29): headshot geometry v3 with pose-following AABB, melee attack types with backstab detection, death report card, enhanced kill feed with contextual tags, round history icons, three mode-specific scoreboard layouts (FFA/TDM/Casual 10v10), and rebindable key bindings. All 19 test suites pass in CI.

The first real multiplayer playtesting after Phase 6 (Build 4 through Build 7) produced an additional 46 PRs (#30–#75) fixing critical networking bugs (grenade replication), collision issues (ramps, ladders, stairs), and UI problems, plus adding runtime map switching, mode plugins, loading screens, chat commands, and ESC menu functionality. The game is now playable in multiplayer with TDM as the default mode.

Approved: pending owner review.
