# ANGELS AND DEMONS — General Development Roadmap
**Status:** Phase-level plan | **Version:** 0.1

## Operating approach
Use short, testable iterations. Each phase gets its own detailed technical plan only when that phase begins. Claude Code proposes implementation and tests; project owner reviews decisions, plays builds, and approves phase gates. Preserve a runnable build throughout development.

## Phase 0 — Reference research and feasibility
**Goal:** establish the reference CS 1.6 behavior, source/license register, mechanics specifications, and Godot suitability risks.
**Time-box:** 4 weeks. Hard checkpoint: unverified items become explicit TODOs for Phase 2–3.
**Output:** research pack and test matrix.
**Gate:** owner approves baseline and measurable fidelity targets.

## Phase 1 — Project foundation
**Goal:** establish Git repository, engine prototype, project conventions, native/headless builds, Docker packaging, CI smoke tests, and documentation workflow.
**Output:** reproducible empty client/server project, a simple connection test, and a networking library evaluation (ENet, GameNetworkingSockets, raw UDP with custom reliability, etc.) with a recommendation.
**Gate:** clean checkout builds, server runs native and containerized, logs and tests work, networking library selected with documented rationale.

## Phase 2 — Movement laboratory
**Goal:** implement movement and collision in a gray-box environment with instrumented tests.
**Output:** first-person movement range with speed, position, input and timing telemetry.
**Gate:** approved movement comparison against Phase 0 reference; no unresolved critical deviations.

## Phase 3 — Gunplay and grenades laboratory
**Goal:** implement representative firearms, authoritative damage, recoil/accuracy, HE/flash/smoke and initial visual feedback.
**Output:** playable combat test range.
**Gate:** weapon/grenade behavior validated to agreed tolerances and no client-authoritative hits.

## Phase 4 — Dedicated multiplayer vertical slice
**Goal:** server-authoritative multiplayer, prediction/reconciliation, interpolation, lag compensation, basic scoreboard and reconnect handling.
**Output:** two-to-ten player LAN/remote match prototype.
**Gate:** acceptable hit registration, latency behavior, server tick stability and disconnect recovery.

## Phase 5 — Classic competitive rules
**Goal:** teams, objective rounds, economy, buying, spawn flow, spectating, win conditions and match lifecycle.
**Output:** complete playable match on one gray-box map.
**Gate:** a full 5v5 session completes without manual intervention; gameplay rules are configurable and tested.

## Phase 6 — Visual identity and content
**Goal:** original Angels/Demons models, recognizable original firearm art, one production-quality map, sounds, HUD, stylized blood, ragdolls and comedic death effects.
**Output:** representative vertical slice matching design overview.
**Gate:** art readable, performant, and mechanically neutral; gore settings functional.

## Phase 7 — Community server foundation
**Goal:** public/private hosting, direct IP/LAN, server listing, configuration, map rotation, administrator roles, bans, logging and installation guides.
**Output:** self-hostable dedicated-server release candidate.
**Gate:** outside tester can deploy and administer server from docs; offline/private operation verified.

## Phase 8 — Steam and content distribution
**Goal:** integrate Steam authentication/discovery, game and free dedicated-server distribution; plan community map/mod packaging and later Workshop support.
**Output:** Steam-enabled playtest build, subject to partner onboarding.
**Gate:** Steam and standalone paths behave as documented; no accidental central-service dependency.

## Phase 9 — Modding SDK and community tools
**Goal:** versioned safe plugin API, community map authoring/packaging, samples, documentation, modded-rule labeling.
**Output:** sample plugin, sample map and creator guides.
**Gate:** third party can create/install content without altering core engine; security tests pass.

## Phase 10 — Closed alpha and optimization
**Goal:** playtests, anti-abuse hardening, balancing, network profiling, server scalability, accessibility, crash fixes and regression coverage.
**Output:** stable community alpha.
**Gate:** agreed stability/performance targets met under representative load; high-priority defects resolved.

## Phase 11 — Launch preparation
**Goal:** store assets, pricing review, release process, server operations, support/moderation policies, backups, documentation and rollback plan.
**Output:** release candidate and operational checklist.
**Gate:** explicit go/no-go approval; release readiness verified.

## Phase approval mechanism
Each phase concludes with a sign-off file committed to the repository: `PHASE_X_SIGNOFF.md`. The file contains: date, gate criteria met (yes/no per item), known deviations accepted with rationale, and any conditions carried forward to subsequent phases. Committing the sign-off file constitutes approval. If a gate criterion is not met, it is either resolved before sign-off or explicitly accepted as a deviation with documented rationale.

## Cross-phase practices
- Every change to movement, recoil, collision or networking runs reference regression tests.
- Document design decisions and known deviations.
- Track performance on modest hardware.
- Avoid building matchmaking, progression, skins or infrastructure before core gameplay is fun.
- Keep native server, Docker image, and community documentation synchronized.
- Conduct threat modeling before introducing downloadable content or server plugins.

## Owner learning track
- Phase 0: read source, learn game-loop physics and evidence-based reverse engineering.
- Phase 1: learn Godot scenes/resources, builds, Git/CI and container packaging.
- Phases 2–3: implement and tune movement equations, recoil, and repeatable tests.
- Phase 4: learn UDP, prediction, reconciliation, interpolation, lag compensation and packet captures.
- Phases 7–9: learn Steamworks, Linux operations, safe scripting interfaces, plugin lifecycle and content security.
- At each phase, Claude should explain major commands and architecture choices, propose a hands-on exercise, and record what was learned.

## Phase planning template
For each upcoming phase create: scope/non-goals; decisions required; architecture sketch; work breakdown; test plan; benchmarks; risks; dependencies; rollback; owner training exercises; acceptance checklist; demo instructions. Do not detail future phases prematurely.

## Immediate next step
Approve these five documents, then expand **Phase 0 only** into an actionable Claude Code research task plan. Do not begin production engine implementation until the reference baseline and legal constraints are reviewed.
