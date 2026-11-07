# PHASE 7 — Character Models & Animation Integration
**Status:** Not started | **Version:** 1.0 | **Date:** 2026-11-06

## Scope
Replace all placeholder geometry (capsules, spheres, boxes) with production-ready character models, weapon models, first-person arms, and grenade visuals. Integrate the shared 23-bone rig from the Character Production Draft 0.1 into the game, wire up animations for all core gameplay states, and ensure the models work with the existing server-authoritative hit detection, lag compensation, and networking systems.

### In scope
- Third-person character models: A1 Templar (Angels) and D1 Brute (Demons) on shared rig
- First-person arms rig with weapon attachment point
- Third-person weapon models for the current 5 weapons (Melee/USP/AK-47/M4A1/AWP)
- First-person viewmodels for each weapon (hold, fire, reload, equip/switch)
- Grenade models replacing the placeholder sphere (HE, flash, smoke)
- AnimationTree-driven third-person character animations (idle, move, crouch, jump, death)
- First-person animation system (weapon bob, fire, reload, switch, melee)
- Integration with existing server lag comp (head AABB must follow animated skeleton)
- Integration with existing networking (skeleton state replication for remote players)
- Team-colored materials (Angels blue/ivory, Demons red/charcoal)

### Not in scope (deferred)
- Additional weapons beyond the current 5
- Ragdoll physics on death (placeholder death animation is sufficient)
- Hit reactions / flinch animations
- Ladder-specific animations
- Cosmetic skins or lore-specific accessories beyond base A1/D1
- Bullet decals, muzzle flash particles, or shell casings
- Voice lines or character-specific audio

---

## Current state

All player visuals are procedural placeholder geometry with no skeleton or animation:

| Element | Current | Target |
|---------|---------|--------|
| Third-person body | `CapsuleMesh` (0.35r, 1.829m) in `remote_player.gd:15-24` | Skinned A1/D1 mesh on Skeleton3D |
| Third-person head | `SphereMesh` (0.15r) on Head node in `remote_player.gd:31-39` | Part of character skeleton, head bone |
| Third-person weapon | `BoxMesh` (0.08x0.08x0.35) on Head in `remote_player.gd:41-49` | Weapon model attached to `hand_r` bone |
| First-person view | No viewmodel — camera only in `player_controller.gd` | First-person arms + weapon viewmodel |
| Grenade projectile | `SphereMesh` (radius 0.05) in `grenade_projectile.gd:36-44` | Grenade model (HE/flash/smoke variants) |
| Server hit detection | Ray-AABB (head) + ray-capsule (body) in `server_lag_comp.gd` | Must align with skeleton pose |
| Team color | `set_team_color()` on capsule material | Material swap or shader parameter on character mesh |

### Prototype history
Character prototypes v0.1–v0.4 explored mannequin proportions, the 23-bone shared skeleton hierarchy, and damage zone visualization. The v0.4 prototype has the final symmetrical low crouch, hitbox groups, and non-targetable cosmetics (halo/horns). None of these prototypes are integrated into the actual game — they are standalone Godot projects under `Prototypes/Characters/`.

### Reference: Character Production Draft 0.1
The ChatGPT-produced document establishes:
- **Shared rig:** 23 bones (root > pelvis > spine_01 > spine_02 > chest > neck > head; clavicle/arm/hand per side; thigh/shin/foot/toe per side)
- **Proportions:** 1.750m A-pose, 1.728m standing gameplay, 1.270m crouched, 0.700m capsule diameter
- **Eye heights:** 1.346m standing, 0.762m crouched (matches `movement_constants.gd`)
- **Triangle budget:** 3,000–5,500 per character
- **Textures:** 1024x1024 baseline, albedo + roughness-led stylization
- **Attachments:** `weapon_r` on `hand_r`, support-hand target, halo/horns on head
- **Animation clips:** idle, stand/crouch locomotion, airborne, weapon hold/fire/reload/equip/switch, death
- **Export format:** .glb/.gltf, meters, +Y up, -Z forward

---

## Key decisions

### Decision 1: Asset pipeline — Blender to Godot

Models are authored in Blender and exported as `.glb` (binary glTF). Godot 4.7 imports `.glb` natively with skeleton, mesh, and animation support. The workflow:

1. Model + rig in Blender using the shared 23-bone hierarchy
2. Animations authored in Blender (or retargeted from mixamo/other sources with matching bone names)
3. Export as `.glb` with embedded animations
4. Godot import settings: skeleton naming matches code expectations, animation clips split by name
5. `AnimationTree` in Godot drives blending (state machine for locomotion, one-shot for fire/reload)

Asset directory structure:
```
assets/
├── characters/
│   ├── shared_skeleton.glb          # Reference rig only (no mesh)
│   ├── angel_templar/
│   │   ├── angel_templar.glb        # Third-person mesh + skeleton
│   │   └── angel_templar_fp.glb     # First-person arms
│   └── demon_brute/
│       ├── demon_brute.glb          # Third-person mesh + skeleton
│       └── demon_brute_fp.glb       # First-person arms
├── weapons/
│   ├── melee/
│   │   ├── melee_world.glb          # Third-person (attached to hand_r)
│   │   └── melee_view.glb           # First-person viewmodel
│   ├── usp/
│   │   ├── usp_world.glb
│   │   └── usp_view.glb
│   ├── ak47/
│   │   ├── ak47_world.glb
│   │   └── ak47_view.glb
│   ├── m4a1/
│   │   ├── m4a1_world.glb
│   │   └── m4a1_view.glb
│   └── awp/
│       ├── awp_world.glb
│       └── awp_view.glb
└── grenades/
    ├── he_grenade.glb
    ├── flash_grenade.glb
    └── smoke_grenade.glb
```

### Decision 2: Third-person character system

Replace the procedural mesh in `remote_player.gd` with a scene-based character:

```
RemotePlayer (Node3D)
├── Skeleton3D (shared 23-bone rig)
│   ├── MeshInstance3D (character mesh, skinned)
│   ├── BoneAttachment3D "weapon_r" (on hand_r bone)
│   │   └── WeaponModel (swapped per equipped weapon)
│   └── BoneAttachment3D "head_attach" (on head bone)
│       └── Cosmetic (halo or horns, non-targetable)
├── AnimationPlayer
├── AnimationTree (state machine)
└── Label3D (name label)
```

Both A1 and D1 share the same skeleton bone names so animations are interchangeable. The character scene is instantiated based on team assignment. On team change, the mesh is swapped but the skeleton and animation tree stay.

### Decision 3: First-person viewmodel system

The local player never sees their own third-person model. Instead, a separate first-person arms rig renders on a dedicated viewport layer (or uses Godot's render layers to avoid self-occlusion):

```
ViewmodelContainer (Node3D, render layer 2)
├── Skeleton3D (arms-only rig: shoulder → upper_arm → forearm → hand, both sides)
│   ├── MeshInstance3D (arms mesh)
│   └── BoneAttachment3D "weapon_r"
│       └── ViewmodelWeapon (swapped per equipped weapon)
├── AnimationPlayer
└── Camera-relative positioning (follows camera, offset for weapon)
```

Viewmodel animations are separate from third-person animations — different FOV, different timing, different poses. The viewmodel camera uses a narrower FOV (typically 54° vs 90° world FOV) to prevent weapon distortion.

### Decision 4: Lag compensation alignment

The server's `server_lag_comp.gd` currently uses geometric ray-AABB (head) and ray-capsule (body) tests. With skeletal characters:

- **Head AABB** must track the head bone position from the skeleton pose, interpolated by `duck_fraction` as it already does
- **Body capsule** stays the same — it's the physics collision shape, not the visual mesh
- The visual skeleton pose is cosmetic for hit detection purposes; the server uses the same AABB/capsule math

This means the existing lag comp system does not need to change. The head bone's position in the animation must match the gameplay eye offset that `server_lag_comp.gd` already uses. Any animation that moves the head (idle sway, breathing) must stay within the existing AABB tolerance.

### Decision 5: Network replication of animation state

Remote players need to show correct animations. Rather than replicating skeleton bone transforms (expensive), replicate animation state:

| Data | Bits | Description |
|------|------|-------------|
| `move_state` | 3 | idle, walk_fwd, walk_back, strafe_l, strafe_r, jump, falling, landing |
| `is_ducked` | 1 | Crouched or standing |
| `weapon_idx` | 4 | Which weapon is equipped |
| `fire_event` | 1 | Fired this tick (trigger one-shot fire animation) |
| `reload_event` | 1 | Started reload |
| `switch_event` | 1 | Switching weapon |
| `death_event` | 1 | Died this tick |

Most of this is already in the snapshot (`duck_fraction`, velocity for movement, weapon index). Fire/reload/switch events are sent via the existing event system. The client's `AnimationTree` on each remote player reads these values to drive the state machine.

### Decision 6: Grenade models

Replace the sphere in `grenade_projectile.gd` with a weapon-specific grenade model:

| Grenade | Visual |
|---------|--------|
| HE | Olive drab cylinder with ridges |
| Flash | Silver cylinder, smooth |
| Smoke | Dark gray canister with pin ring |

Each `.glb` is a simple static mesh (no skeleton needed). The grenade type index is already networked; the visual swaps based on it.

---

## Work breakdown

### WB1: Asset directory and import pipeline
- [ ] Create `assets/characters/`, `assets/weapons/`, `assets/grenades/` directory structure
- [ ] Create or source placeholder `.glb` files for one character (A1 Templar) using the shared 23-bone rig
  - Standing A-pose mesh, skinned to skeleton, 3,000–5,500 triangles
  - Team-colored material (albedo + roughness, blue/ivory palette)
- [ ] Verify Godot 4.7.2 imports the `.glb` correctly: skeleton names match, mesh renders, no transform issues
- [ ] Document the import settings that work (scale, bone naming, animation settings)
- [ ] Create `.import` override if needed for consistent reimport

### WB2: Third-person character scene
- [ ] Create `client/scenes/character_model.tscn` — reusable character scene
  - Skeleton3D with the shared rig
  - MeshInstance3D for the skinned character mesh
  - BoneAttachment3D on `hand_r` for weapon mount
  - BoneAttachment3D on `head` for cosmetic mount
  - AnimationPlayer (initially with just idle)
- [ ] Create `client/scripts/character_model.gd` — manages mesh swapping (A1 vs D1) and weapon attachment
  - `set_faction(faction: String)` — swaps character mesh
  - `set_weapon_model(weapon_idx: int)` — swaps weapon on hand_r
  - `set_team_color(color: Color)` — sets material parameter
- [ ] Update `remote_player.gd` to instantiate `character_model.tscn` instead of procedural capsule/sphere/box
- [ ] Verify remote players render with the new model in multiplayer
- [ ] Verify team colors work on the new model
- [ ] Verify head position from skeleton matches existing `MC.VIEW_OFFSET_STANDING` / `MC.VIEW_OFFSET_DUCKING`

### WB3: Third-person animations — locomotion
- [ ] Create or source animation clips for the shared rig:
  - `idle_stand` — weapon-ready standing idle (loop)
  - `idle_crouch` — weapon-ready crouched idle (loop)
  - `walk_forward` / `walk_backward` / `strafe_left` / `strafe_right` — standing (loop)
  - `crouch_forward` / `crouch_backward` / `crouch_strafe_left` / `crouch_strafe_right` — crouched (loop)
  - `jump_start` / `jump_loop` / `jump_land` — airborne sequence
  - `stand_to_crouch` / `crouch_to_stand` — transitions
- [ ] Set up `AnimationTree` with blend tree / state machine:
  - Movement blend space: idle ↔ directional movement based on velocity
  - Crouch layer: blend between standing and crouched animation sets via `duck_fraction`
  - Airborne state: jump start → loop → land
- [ ] Wire AnimationTree parameters to remote player state (velocity, duck_fraction, on_ground)
- [ ] Verify animations play correctly at gameplay speed (250 u/s walking)
- [ ] Verify no foot sliding at normal movement speed

### WB4: Third-person animations — combat
- [ ] Create or source animation clips:
  - `rifle_hold` — AK/M4 idle pose overlay
  - `rifle_fire` — single shot recoil (one-shot, ~0.1s)
  - `rifle_reload` — magazine swap (~2.5s)
  - `pistol_hold` / `pistol_fire` / `pistol_reload`
  - `melee_slash` / `melee_stab` — melee attacks
  - `awp_hold` / `awp_fire` / `awp_reload` — bolt-action specific
  - `weapon_switch` — lower current → raise new (~0.5s)
  - `grenade_throw` — wind up → release
- [ ] Add weapon pose layer to AnimationTree:
  - Upper body overrides locomotion with weapon-specific pose
  - Fire/reload/switch are one-shot animations that play over the hold pose
- [ ] Wire fire/reload/switch events from snapshot data to trigger animations on remote players
- [ ] Verify weapon model stays aligned to hand during all animations

### WB5: Third-person weapon models
- [ ] Create or source `.glb` models for each weapon:
  - Melee (fists/knife shape), USP (pistol), AK-47 (rifle), M4A1 (rifle), AWP (sniper)
  - Low poly (500–1,500 triangles each), simple materials
- [ ] Implement weapon model swapping in `character_model.gd`:
  - On `EVT_WEAPON_SWITCH` or when weapon index changes in snapshot
  - Instantiate the correct weapon `.glb` scene under the `weapon_r` BoneAttachment3D
  - Free the previous weapon model
- [ ] Verify weapon models appear correctly on remote players for all 5 weapons
- [ ] Verify weapon model tracks hand position during movement animations

### WB6: First-person viewmodel system
- [ ] Create `client/scripts/viewmodel.gd` — first-person weapon renderer
  - Positioned relative to camera (child of Camera3D or offset node)
  - Render layer separation so viewmodel doesn't clip with world geometry
  - Separate FOV (54°) for viewmodel rendering, or use `SubViewport` approach
- [ ] Create `client/scenes/viewmodel.tscn`:
  - Arms skeleton (simplified: upper_arm → forearm → hand, both sides)
  - Arms mesh (faction-specific or generic)
  - Weapon mount point on right hand
- [ ] Create first-person arm models (or use simplified geometry initially)
- [ ] Wire viewmodel into `player_controller.gd`:
  - Show viewmodel when alive, hide when dead/spectating
  - Update weapon on switch
  - Trigger fire/reload/switch animations from weapon_system events

### WB7: First-person viewmodel animations
- [ ] Create or source viewmodel animation clips per weapon:
  - `idle` — slight weapon sway/bob (loop)
  - `fire` — recoil kick (one-shot, weapon-specific timing)
  - `reload` — magazine swap / bolt pull (one-shot, weapon-specific duration)
  - `equip` — weapon raise into view on switch
  - `melee_slash` / `melee_stab` — fist/knife swings
  - `grenade_pull_pin` / `grenade_throw` — grenade sequence
- [ ] AnimationPlayer or AnimationTree on viewmodel:
  - Idle plays by default
  - Fire/reload/equip are one-shot interrupts
  - Walk bob blended with idle based on player velocity
- [ ] Wire to weapon_system.gd events:
  - `_on_fire()` → play fire animation
  - `_on_reload_start()` → play reload animation
  - `_on_switch()` → play equip animation
- [ ] Match animation durations to gameplay timing (reload time, switch time, fire rate)

### WB8: Grenade models
- [ ] Create or source `.glb` models for each grenade type:
  - HE grenade, flash grenade, smoke grenade
  - Simple geometry (~200–500 triangles each)
- [ ] Update `grenade_projectile.gd` to load model instead of `SphereMesh`:
  - Replace `SphereMesh.new()` with scene instantiation based on grenade type
  - Grenade type is already tracked; use it to select the correct model
- [ ] Verify grenade models appear correctly in multiplayer for all three types
- [ ] Verify grenade trajectory/rotation looks natural

### WB9: Death animation
- [ ] Create or source a simple death animation clip:
  - Upper body collapses forward/backward (one-shot, no loop)
  - Not ragdoll — just a canned animation
  - ~0.5–1.0s duration, transitions to lying pose
- [ ] Trigger death animation on remote players when death event is received
- [ ] Dead player model stays visible for deathcam duration (2s) then removed
- [ ] Verify death animation doesn't interfere with spectator camera transition

### WB10: D1 Brute character model
- [ ] Create or source D1 Brute `.glb` on the same shared skeleton:
  - Same proportions and bone positions as A1 Templar
  - Different costume: charcoal/red/ember palette, horns instead of halo
  - Same triangle budget (3,000–5,500)
- [ ] Create D1 first-person arms variant (charcoal sleeves)
- [ ] Verify D1 uses all the same animations as A1 (shared rig guarantee)
- [ ] Verify team assignment correctly swaps between A1 and D1 models
- [ ] Verify cosmetic attachments (halo vs horns) render on correct faction

### WB11: Integration testing and CI
- [ ] Verify server lag compensation still works:
  - Head AABB aligns with skeleton head bone position
  - Headshots register correctly on animated characters (standing, crouched, transitioning)
  - Existing lag comp tests pass without changes
- [ ] Verify networking:
  - Animation state replicates correctly to remote players
  - Weapon models swap on remote players when they switch weapons
  - Fire/reload animations play on remote players at correct timing
- [ ] Performance profiling:
  - 10-player match with full character models, measure frame time
  - Compare against capsule baseline
  - Target: <16ms frame time (60fps) on modest hardware with 10 players
- [ ] Add visual regression markers (not automated — manual play test checklist):
  - All 5 weapons visible in first person and third person
  - Both factions distinguishable at engagement distance
  - Grenade models match type
  - Death animation plays correctly
- [ ] Verify CI still passes with new asset files (import, script validation)

---

## Test plan

### Integration tests (automated)

| Test | Method | Pass condition |
|------|--------|---------------|
| Lag comp headshot with model | Existing `lag_comp_tests.gd` | All headshot tests still pass — head AABB unchanged |
| Lag comp duck transition | Existing `lag_comp_tests.gd` | Mid-duck headshot resolves correctly |
| Network snapshot | Existing `network_tests.gd` | Snapshot encode/decode still works with any new fields |
| Script validation | CI `--validate-scripts` | All new scripts parse without errors |

### Manual play tests

| Scenario | Expected behavior |
|----------|-------------------|
| Join as Angel | A1 Templar model visible to other players, blue/ivory materials |
| Join as Demon | D1 Brute model visible to other players, charcoal/red materials |
| Walk around | Third-person locomotion animations play, no foot sliding |
| Crouch | Crouch animation plays, head drops to correct height |
| Fire AK-47 | First-person: recoil animation; Third-person: fire pose |
| Reload | First-person: magazine swap animation; Third-person: reload pose |
| Switch weapons | First-person: lower → raise; Third-person: weapon model swaps |
| Melee slash/stab | First-person: swing animations; Third-person: attack poses |
| Throw grenade | First-person: pull pin + throw; Grenade model visible in air |
| Die | Third-person: death animation; First-person: viewmodel hidden |
| 10-player match | All players render with correct models, animations, and weapons |
| Performance | 60fps maintained with 10 animated characters on screen |

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Model authoring bottleneck (Blender skills) | High | High | Start with CC0/open-source placeholder models that fit the rig; iterate art quality separately |
| Skeleton bone names don't match between Blender export and Godot import | Medium | Medium | Document exact naming convention; test import early in WB1 |
| First-person viewmodel clipping with world geometry | Medium | Medium | Render layer separation or SubViewport approach |
| Animation quality insufficient for gameplay feel | Medium | Medium | Functional animations first, polish later; CS 1.6 used simple animations |
| Head bone position in animation doesn't match lag comp AABB | Low | High | Constrain head animation amplitude; validate in WB11 |
| Performance regression with 10+ skinned characters | Low | Medium | Profile in WB11; reduce bone count or LOD if needed |
| Godot 4.7 AnimationTree complexity | Medium | Medium | Start simple (state machine, one-shot), add blend trees incrementally |

---

## Dependencies
- Phase 6 complete — **done** (sign-off committed)
- Character Production Draft 0.1 (rig spec, proportions, bone hierarchy) — **available** (ChatGPT PDF)
- Prototype v0.4 (crouched pose, hitbox zones, shared rig validation) — **done**
- Blender (or other DCC) for model/animation authoring — **required, owner must have access**
- Placeholder `.glb` models — **must be created or sourced before WB2**
- Existing lag comp, networking, weapon system — **stable, no changes expected**

---

## Rollback
Each WB is committed independently:
- WB1 (pipeline) is directory structure only — safe to revert
- WB2 (3P character) can fall back to capsule by reverting `remote_player.gd`
- WB3–WB4 (animations) are additive — characters work without animations (static pose)
- WB5 (weapon models) falls back to box mesh in `remote_player.gd`
- WB6–WB7 (viewmodel) is additive — game works without first-person viewmodel (camera only)
- WB8 (grenade models) falls back to sphere mesh in `grenade_projectile.gd`
- WB9 (death) falls back to instant removal
- WB10 (D1) falls back to A1 for both teams
- WB11 (testing) is validation only

---

## Asset sourcing notes

Models and animations can come from several sources:
1. **Original Blender work** — highest quality, full control, requires 3D modeling skill
2. **Open-source assets** (CC0/MIT) — Kenney, Quaternius, Mixamo skeletons — may need retargeting to shared rig
3. **AI-assisted generation** — tools like Meshy, Tripo, Rodin — can produce starting meshes that need cleanup
4. **Mixamo animations** — free animation library, retargetable to custom skeletons via Blender

For the initial integration (WB1–WB2), low-poly placeholder models are acceptable. Art quality can be iterated once the pipeline is proven.

---

## Suggested work order
1. **WB1** (asset pipeline) — prove `.glb` → Godot import works with shared rig
2. **WB2** (3P character scene) — replace capsule with real model, biggest visual impact
3. **WB5** (weapon models) — get weapons visible on characters
4. **WB3** (locomotion animations) — characters move believably
5. **WB6** (viewmodel system) — first-person arms and weapon rendering
6. **WB7** (viewmodel animations) — first-person fire/reload/switch feel
7. **WB4** (combat animations) — third-person fire/reload visible to others
8. **WB8** (grenade models) — replace sphere with real grenades
9. **WB9** (death animation) — death looks intentional, not instant vanish
10. **WB10** (D1 Brute) — second faction model
11. **WB11** (integration testing) — verify everything works together

---

## Immediate next steps
1. Decide how models will be sourced: original Blender work, open-source assets, AI-assisted, or a mix
2. Set up the `assets/` directory structure (WB1)
3. Get one character `.glb` imported into Godot with the shared skeleton and verify it works
