# Phase 7 Prompt — Character Models & Animation Integration

Use this prompt when starting a Claude Code session to work on Phase 7.

---

## Prompt

You are working on **Angels and Demons**, a competitive FPS built in Godot 4.7.2. The project is at `C:\Users\pro.anon\Documents\Nextcloud\Angels_and_Demons\github-repo\angels_and_demons`. Read `PHASE_7_PLAN.md` for the full plan, and `05_DEVELOPMENT_ROADMAP.md` for project context.

### What Phase 7 is

Phase 7 replaces all placeholder geometry with real character models, weapon models, first-person viewmodels, grenade models, and animations. The game currently uses procedural capsules, spheres, and boxes for all player and weapon visuals (see `client/scripts/remote_player.gd`). Your job is to integrate production-ready `.glb` assets into the game, wire up AnimationTree-driven animations, and build a first-person viewmodel system — all while keeping the existing gameplay systems (movement, combat, networking, lag compensation) working exactly as they are.

### What you must know before changing anything

**Read these files first — they are your ground truth:**

1. `PHASE_7_PLAN.md` — the full work breakdown (WB1–WB11), decisions, and test plan
2. `client/scripts/remote_player.gd` — current third-person player rendering (capsule + sphere + box)
3. `shared/scripts/player_movement.gd` — movement system with duck_fraction, hull heights
4. `shared/scripts/movement_constants.gd` — HULL_STANDING_HEIGHT, VIEW_OFFSET_STANDING, VIEW_OFFSET_DUCKING, etc.
5. `server/scripts/server_lag_comp.gd` — head AABB and body capsule hit detection (DO NOT CHANGE the hit detection math)
6. `shared/scripts/weapon_system.gd` — fire, reload, switch, grenade throw logic
7. `shared/scripts/weapon_registry.gd` — weapon definitions (melee, USP, AK-47, M4A1, AWP)
8. `shared/scripts/grenade_projectile.gd` — grenade visual and physics (currently SphereMesh)
9. `client/scripts/player_controller.gd` — local player (first-person camera, no viewmodel yet)
10. `client/scripts/client_game.gd` — snapshot handling, remote player creation/updates
11. `.github/workflows/build.yml` — CI pipeline (ALL checks must pass)

### Critical constraints

**Server-authoritative architecture — do not break it:**
- The server owns all hit detection via `server_lag_comp.gd`. It uses ray-AABB for head hits and ray-capsule for body hits. These are geometric tests against stored snapshot positions, NOT against visual meshes or skeleton bones.
- DO NOT change the lag comp hit detection math. The visual skeleton must align with the existing AABB/capsule positions, not the other way around.
- Head bone position in animation must match `MC.VIEW_OFFSET_STANDING` (1.346m) and `MC.VIEW_OFFSET_DUCKING` (0.762m). Any idle sway or breathing animation must keep the head within the existing AABB tolerance.
- `duck_fraction` drives the visual crouch blend AND the lag comp head position interpolation. These must stay in sync.

**Networking — do not add unnecessary bandwidth:**
- Remote player animations are driven by state already in the snapshot: position, velocity (derive movement direction), `duck_fraction`, weapon index.
- Fire/reload/switch events are already sent via the event system. Use these to trigger one-shot animations on remote players.
- DO NOT replicate skeleton bone transforms over the network. Replicate animation state (which state machine node is active), not poses.

**Movement constants — do not change them:**
- `HULL_STANDING_HEIGHT = 1.829` — this is the physics capsule, not the visual model height
- `HULL_DUCKING_HEIGHT = 1.270` — crouched physics capsule (note: differs from the 0.914m in some prototype READMEs; the code value is authoritative)
- `VIEW_OFFSET_STANDING = 1.346` — camera/eye height standing
- `VIEW_OFFSET_DUCKING = 0.762` — camera/eye height crouched
- `CAPSULE_RADIUS = 0.35` — collision radius
- The visual model is 1.750m in A-pose / 1.728m in gameplay standing. The physics capsule is 1.829m. The model fits INSIDE the capsule. Do not resize the capsule to fit the model.

### GitHub Actions CI — every PR must pass ALL of these

The CI pipeline (`.github/workflows/build.yml`) runs on every PR and push to main. Every single check must pass. Here is what CI does:

**1. Validate job:**
- `godot --headless --import` — imports the project; fails on SCRIPT ERROR, Failed to load, Cannot preload, or Parse Error
- `godot --headless --path . -- --validate-scripts` — compiles every `.gd` file in the project (excluding `Prototypes/`); fails on any compilation error
- Missing resource scan — greps all `.tscn`, `.tres`, and `.gd` files for `res://` paths and checks each file exists on disk. If you reference a `.glb`, `.tscn`, or any resource in code/scenes, that file MUST exist in the repo.

**2. Test job (19 test suites):**
- `--test` (movement), `--test-network`, `--test-combat`, `--test-lagcomp`, `--test-economy`, `--test-round`, `--test-spawn`, `--test-objective`, `--test-buymenu`, `--test-hud`, `--test-match`, `--test-validation`, `--test-killfeed`, `--test-roundicon`, `--test-ffa`, `--test-tdm`, `--test-casual`, `--test-keybindings`, `--test-aimmap`
- `--bench` (performance benchmark)
- ALL existing tests must continue to pass. Do not modify existing test files unless a test is genuinely wrong due to your changes (and explain why in the PR).

**3. Canary job:**
- Verifies CI correctly detects broken scripts and missing resources (meta-test of the CI itself)

**4. Export job:**
- Exports the Linux server binary and runs a smoke test
- Server export must not fail due to missing resources or broken scripts

### Rules for every work block

1. **Branch per WB:** Create a branch named `feature/wb{N}-{short-description}` (e.g., `feature/wb1-asset-pipeline`). One PR per WB.
2. **CI must pass:** Before marking a WB done, ALL CI checks must be green. If you add new `.gd` files, they must compile. If you add new `.tscn` or `.tres` files, all `res://` references inside them must resolve. If you add `.glb` files, their `.import` files will be auto-generated by Godot on import — include the `.import` files in the commit.
3. **No breaking existing tests:** Run the full test suite before pushing. If a test fails, fix the issue in your code, not in the test.
4. **Commit messages:** Use the format: `Short description of change (WB{N})`. End with `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`.
5. **PR descriptions:** Include what changed, which WB it covers, what to test manually, and any known limitations.
6. **New scripts must validate:** Any new `.gd` file must pass `--validate-scripts`. Use proper GDScript type hints, `extends` declarations, and avoid referencing nodes that don't exist in the scene tree at script compilation time.
7. **Resource references:** Every `preload("res://...")` or `load("res://...")` in your code must point to a file that exists. Every `[ext_resource]` in `.tscn` files must resolve. The CI resource scanner will catch any broken references.
8. **Assets in repo:** All `.glb`, texture, and material files must be committed to the repo under `assets/`. Do not use external URLs or paths outside the project.
9. **No Prototype/ changes:** The `Prototypes/` directory contains standalone Godot projects. Do not modify them. They are excluded from CI validation.
10. **entry_point.gd:** If you add a new test suite, register it in `shared/scripts/entry_point.gd` with a `--test-{name}` flag, create the corresponding test scene, and add the step to `.github/workflows/build.yml`.

### Shared rig specification (from Character Production Draft 0.1)

The character rig is a 23-bone hierarchy. Both factions (A1 Templar / D1 Brute) use identical bone names, parent links, and rest transforms so one animation set works for both.

```
root
└── pelvis
    ├── spine_01
    │   └── spine_02
    │       └── chest
    │           ├── neck
    │           │   └── head
    │           ├── clavicle_l
    │           │   └── upper_arm_l
    │           │       └── forearm_l
    │           │           └── hand_l
    │           └── clavicle_r
    │               └── upper_arm_r
    │                   └── forearm_r
    │                       └── hand_r
    └── thigh_l / thigh_r
        └── shin_l / shin_r
            └── foot_l / foot_r
                └── toe_l / toe_r
```

**Coordinates:** meters, +Y up, -Z forward, floor-level art root.
**Authoring pose:** neutral A-pose, arms ~30° from vertical.
**Attachments:** `weapon_r` attachment on `hand_r`; halo/horns on `head`.
**Triangle budget:** 3,000–5,500 per character, ~500–1,500 per weapon.
**Textures:** 1024x1024 baseline.
**Export:** `.glb` (binary glTF), embedded animations.

### Asset directory structure

```
assets/
├── characters/
│   ├── angel_templar/
│   │   ├── angel_templar.glb        # Third-person mesh + skeleton
│   │   └── angel_templar_fp.glb     # First-person arms (optional, WB6)
│   └── demon_brute/
│       ├── demon_brute.glb
│       └── demon_brute_fp.glb
├── weapons/
│   ├── melee/
│   │   ├── melee_world.glb          # Third-person weapon
│   │   └── melee_view.glb           # First-person viewmodel weapon
│   ├── usp/
│   ├── ak47/
│   ├── m4a1/
│   └── awp/
└── grenades/
    ├── he_grenade.glb
    ├── flash_grenade.glb
    └── smoke_grenade.glb
```

### Current visual representations to replace

| What | Current code | Current visual | File |
|------|-------------|---------------|------|
| Third-person body | `CapsuleMesh.new()` | Blue capsule (0.35r × 1.829m) | `remote_player.gd:15-24` |
| Third-person head | `SphereMesh.new()` | Skin-colored sphere (0.15r) | `remote_player.gd:31-39` |
| Third-person weapon | `BoxMesh.new()` | Dark gray box (0.08×0.08×0.35) | `remote_player.gd:41-49` |
| First-person weapon | None — camera only | Nothing visible | `player_controller.gd` |
| Grenade projectile | `SphereMesh.new()` | Small sphere per type color | `grenade_projectile.gd:36-44` |
| Team color | `set_team_color()` on capsule mat | Material albedo swap | `remote_player.gd:61-65` |

### Work order

Follow the suggested order in `PHASE_7_PLAN.md`:

1. WB1 — Asset pipeline (prove .glb import works)
2. WB2 — Third-person character scene (replace capsule)
3. WB5 — Third-person weapon models
4. WB3 — Locomotion animations
5. WB6 — First-person viewmodel system
6. WB7 — First-person viewmodel animations
7. WB4 — Third-person combat animations
8. WB8 — Grenade models
9. WB9 — Death animation
10. WB10 — D1 Brute (second faction)
11. WB11 — Integration testing

### How to verify your work

Before pushing any WB:

1. **Scripts compile:** `godot --headless --path . -- --validate-scripts` must exit 0
2. **Import clean:** `godot --headless --import` must show no SCRIPT ERROR or Parse Error lines
3. **Resources exist:** Every `res://` path in your `.gd`, `.tscn`, and `.tres` files must point to a real file
4. **Existing tests pass:** Run the full suite — movement, network, combat, lagcomp, economy, round, spawn, objective, buymenu, hud, match, validation, killfeed, roundicon, ffa, tdm, casual, keybindings, aimmap, bench
5. **Manual check:** Join a local multiplayer session. Verify character models, weapon models, and animations render correctly for both local and remote players.
6. **Server export:** `godot --headless --export-release "Linux Server" build/server/angels_and_demons_server.x86_64` must succeed

### What NOT to do

- Do not modify `server_lag_comp.gd` hit detection math
- Do not change movement constants or physics capsule dimensions
- Do not add bone transform replication to the network protocol
- Do not modify existing test files unless your changes genuinely require it (explain in PR)
- Do not touch anything in `Prototypes/`
- Do not add dependencies on external tools or packages not already in the project
- Do not create files with `res://` references to assets that don't exist in the repo
- Do not merge without CI green
